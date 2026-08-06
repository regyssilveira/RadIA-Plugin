unit RadIA.Core.ExtensionPublisherTrust;

interface

uses
  System.Generics.Collections,
  RadIA.Core.DeclarativeExtensionPackages,
  RadIA.Core.DeclarativeExtensions;

type
  TRadIAExtensionPackageTrustDecision = record
  private
    FAllowUnsigned: Boolean;
    FPackageHash: string;
  public
    constructor Create(
      const AAllowUnsigned: Boolean;
      const APackageHash: string
    );
    property AllowUnsigned: Boolean read FAllowUnsigned;
    property PackageHash: string read FPackageHash;
  end;

  TRadIATrustedExtensionPublisher = record
  private
    FFingerprint: string;
    FId: string;
    FName: string;
  public
    constructor Create(
      const AId: string;
      const AName: string;
      const AFingerprint: string
    );
    property Fingerprint: string read FFingerprint;
    property Id: string read FId;
    property Name: string read FName;
  end;

  TRadIAExtensionPublisherTrustStore = class
  private
    FFileName: string;
    FPublishers: TList<TRadIATrustedExtensionPublisher>;
    procedure AtomicSave(const AContent: string);
    class procedure ValidateEntry(
      const AEntry: TRadIATrustedExtensionPublisher
    ); static;
    function FindById(
      const AId: string;
      out AIndex: Integer
    ): Boolean;
  public
    constructor Create(const AFileName: string);
    destructor Destroy; override;
    function GetPublishers: TArray<TRadIATrustedExtensionPublisher>;
    function IsTrusted(
      const APublisher: TRadIADeclarativeExtensionPublisher
    ): Boolean;
    procedure Load;
    function Revoke(const AId: string): Boolean;
    procedure Save;
    procedure Trust(
      const APublisher: TRadIADeclarativeExtensionPublisher
    );
  end;

  TRadIATrustedExtensionPackageInstaller = class
  public
    class function Install(
      const APackageFileName: string;
      const AManager: TRadIADeclarativeExtensionManager;
      const AReservedCommands: TArray<string>;
      const ATrustStore: TRadIAExtensionPublisherTrustStore;
      const ADecision: TRadIAExtensionPackageTrustDecision;
      out AExtensionId: string;
      out AMessage: string
    ): Boolean; static;
  end;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.RegularExpressions,
  System.SysUtils,
  Winapi.Windows;

const
  CMaximumTrustStoreBytes = 1048576;
  CTrustStoreSchemaVersion = 1;

{ TRadIAExtensionPackageTrustDecision }

constructor TRadIAExtensionPackageTrustDecision.Create(
  const AAllowUnsigned: Boolean;
  const APackageHash: string
);
begin
  FAllowUnsigned := AAllowUnsigned;
  FPackageHash := LowerCase(Trim(APackageHash));
end;

{ TRadIATrustedExtensionPublisher }

constructor TRadIATrustedExtensionPublisher.Create(
  const AId: string;
  const AName: string;
  const AFingerprint: string
);
begin
  FId := AId;
  FName := AName;
  FFingerprint := AFingerprint;
end;

{ TRadIAExtensionPublisherTrustStore }

procedure TRadIAExtensionPublisherTrustStore.AtomicSave(
  const AContent: string
);
var
  LTemporaryFileName: string;
begin
  if TFile.Exists(FFileName) and
    ((GetFileAttributes(PChar(FFileName)) and
    FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then
    raise EArgumentException.Create(
      'Publisher trust store reparse points are not allowed.'
    );
  TDirectory.CreateDirectory(ExtractFilePath(FFileName));
  LTemporaryFileName := FFileName + '.' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '') + '.tmp';
  try
    TFile.WriteAllText(
      LTemporaryFileName,
      AContent,
      TEncoding.UTF8
    );
    if not MoveFileEx(
      PChar(LTemporaryFileName),
      PChar(FFileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH
    ) then
      RaiseLastOSError;
  finally
    if TFile.Exists(LTemporaryFileName) then
      TFile.Delete(LTemporaryFileName);
  end;
end;

constructor TRadIAExtensionPublisherTrustStore.Create(
  const AFileName: string
);
begin
  inherited Create;
  if Trim(AFileName) = '' then
    raise EArgumentException.Create(
      'Publisher trust store file name cannot be empty.'
    );
  FFileName := TPath.GetFullPath(AFileName);
  FPublishers := TList<TRadIATrustedExtensionPublisher>.Create;
end;

destructor TRadIAExtensionPublisherTrustStore.Destroy;
begin
  FPublishers.Free;
  inherited Destroy;
end;

function TRadIAExtensionPublisherTrustStore.FindById(
  const AId: string;
  out AIndex: Integer
): Boolean;
var
  LIndex: Integer;
begin
  for LIndex := 0 to FPublishers.Count - 1 do
    if SameText(FPublishers[LIndex].Id, AId) then
    begin
      AIndex := LIndex;
      Exit(True);
    end;
  AIndex := -1;
  Result := False;
end;

class procedure TRadIAExtensionPublisherTrustStore.ValidateEntry(
  const AEntry: TRadIATrustedExtensionPublisher
);
begin
  if not TRegEx.IsMatch(
    AEntry.Id,
    '^[A-Za-z0-9][A-Za-z0-9.-]{1,63}$'
  ) then
    raise EArgumentException.Create(
      'Trusted publisher ID is invalid.'
    );
  if (Trim(AEntry.Name) = '') or (Length(AEntry.Name) > 100) then
    raise EArgumentException.Create(
      'Trusted publisher name is invalid.'
    );
  if not TRegEx.IsMatch(AEntry.Fingerprint, '^[0-9a-fA-F]{64}$') then
    raise EArgumentException.Create(
      'Trusted publisher fingerprint is invalid.'
    );
end;

function TRadIAExtensionPublisherTrustStore.GetPublishers:
  TArray<TRadIATrustedExtensionPublisher>;
begin
  Result := FPublishers.ToArray;
end;

function TRadIAExtensionPublisherTrustStore.IsTrusted(
  const APublisher: TRadIADeclarativeExtensionPublisher
): Boolean;
var
  LIndex: Integer;
begin
  Result := FindById(APublisher.Id, LIndex) and
    SameText(
      FPublishers[LIndex].Fingerprint,
      APublisher.Fingerprint
    );
end;

procedure TRadIAExtensionPublisherTrustStore.Load;
var
  LArray: TJSONArray;
  LEntry: TRadIATrustedExtensionPublisher;
  LIndex: Integer;
  LJson: TJSONObject;
  LLoadedPublishers: TList<TRadIATrustedExtensionPublisher>;
  LPublisher: TJSONObject;
  LPublisherIds: TStringList;
begin
  FPublishers.Clear;
  if not TFile.Exists(FFileName) then
    Exit;
  if (GetFileAttributes(PChar(FFileName)) and
    FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
    raise EArgumentException.Create(
      'Publisher trust store reparse points are not allowed.'
    );
  if TFile.GetSize(FFileName) > CMaximumTrustStoreBytes then
    raise EArgumentException.Create(
      'Publisher trust store exceeds the 1 MiB size limit.'
    );
  LJson := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(FFileName, TEncoding.UTF8)
  ) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create(
      'Publisher trust store must be a JSON object.'
    );
  LLoadedPublishers := TList<TRadIATrustedExtensionPublisher>.Create;
  LPublisherIds := TStringList.Create;
  try
    LPublisherIds.CaseSensitive := False;
    if LJson.GetValue<Integer>('schemaVersion', 0) <>
      CTrustStoreSchemaVersion then
      raise EArgumentException.Create(
        'Publisher trust store schema is unsupported.'
      );
    LArray := LJson.GetValue('publishers') as TJSONArray;
    if not Assigned(LArray) then
      raise EArgumentException.Create(
        'Publisher trust store entries are missing.'
      );
    for LIndex := 0 to LArray.Count - 1 do
    begin
      if not (LArray[LIndex] is TJSONObject) then
        raise EArgumentException.Create(
          'Publisher trust store entry must be an object.'
        );
      LPublisher := TJSONObject(LArray[LIndex]);
      LEntry := TRadIATrustedExtensionPublisher.Create(
        Trim(LPublisher.GetValue<string>('id', '')),
        Trim(LPublisher.GetValue<string>('name', '')),
        LowerCase(Trim(LPublisher.GetValue<string>('fingerprint', '')))
      );
      ValidateEntry(LEntry);
      if LPublisherIds.IndexOf(LEntry.Id) >= 0 then
        raise EArgumentException.Create(
          'Publisher trust store contains duplicate IDs.'
        );
      LPublisherIds.Add(LEntry.Id);
      LLoadedPublishers.Add(LEntry);
    end;
    for LEntry in LLoadedPublishers do
      FPublishers.Add(LEntry);
  finally
    LPublisherIds.Free;
    LLoadedPublishers.Free;
    LJson.Free;
  end;
end;

function TRadIAExtensionPublisherTrustStore.Revoke(
  const AId: string
): Boolean;
var
  LIndex: Integer;
begin
  Result := FindById(AId, LIndex);
  if not Result then
    Exit;
  FPublishers.Delete(LIndex);
  Save;
end;

procedure TRadIAExtensionPublisherTrustStore.Save;
var
  LArray: TJSONArray;
  LJson: TJSONObject;
  LObject: TJSONObject;
  LPublisher: TRadIATrustedExtensionPublisher;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair(
      'schemaVersion',
      TJSONNumber.Create(CTrustStoreSchemaVersion)
    );
    LJson.AddPair(
      'updatedAt',
      DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True)
    );
    LArray := TJSONArray.Create;
    for LPublisher in FPublishers do
    begin
      LObject := TJSONObject.Create;
      LObject.AddPair('id', LPublisher.Id);
      LObject.AddPair('name', LPublisher.Name);
      LObject.AddPair('fingerprint', LPublisher.Fingerprint);
      LArray.AddElement(LObject);
    end;
    LJson.AddPair('publishers', LArray);
    AtomicSave(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAExtensionPublisherTrustStore.Trust(
  const APublisher: TRadIADeclarativeExtensionPublisher
);
var
  LEntry: TRadIATrustedExtensionPublisher;
  LExisting: TRadIATrustedExtensionPublisher;
  LFound: Boolean;
  LIndex: Integer;
begin
  LEntry := TRadIATrustedExtensionPublisher.Create(
    APublisher.Id,
    APublisher.Name,
    APublisher.Fingerprint
  );
  ValidateEntry(LEntry);
  LFound := FindById(APublisher.Id, LIndex);
  if LFound then
  begin
    LExisting := FPublishers[LIndex];
    FPublishers[LIndex] := LEntry;
  end
  else
    FPublishers.Add(LEntry);
  try
    Save;
  except
    if LFound then
      FPublishers[LIndex] := LExisting
    else
      FPublishers.Delete(FPublishers.Count - 1);
    raise;
  end;
end;

{ TRadIATrustedExtensionPackageInstaller }

class function TRadIATrustedExtensionPackageInstaller.Install(
  const APackageFileName: string;
  const AManager: TRadIADeclarativeExtensionManager;
  const AReservedCommands: TArray<string>;
  const ATrustStore: TRadIAExtensionPublisherTrustStore;
  const ADecision: TRadIAExtensionPackageTrustDecision;
  out AExtensionId: string;
  out AMessage: string
): Boolean;
var
  LPackage: TRadIADeclarativeExtensionPackage;
begin
  Result := False;
  AExtensionId := '';
  AMessage := '';
  try
    LPackage := TRadIADeclarativeExtensionPackageReader.Read(
      APackageFileName
    );
    if LPackage.IsSigned then
    begin
      if not Assigned(ATrustStore) or
        not ATrustStore.IsTrusted(LPackage.Publisher) then
      begin
        AMessage := 'Package publisher is not trusted.';
        Exit;
      end;
    end
    else if not ADecision.AllowUnsigned then
    begin
      AMessage := 'Unsigned integrity-only package requires confirmation.';
      Exit;
    end;
    if not LPackage.IsSigned and not SameText(
      ADecision.PackageHash,
      LowerCase(
        THashSHA2.GetHashStringFromFile(APackageFileName)
      )
    ) then
    begin
      AMessage := 'Unsigned package changed after confirmation.';
      Exit;
    end;
    Result := TRadIADeclarativeExtensionPackageInstaller.Install(
      APackageFileName,
      AManager,
      AReservedCommands,
      AExtensionId,
      AMessage
    );
  except
    on E: Exception do
      AMessage := 'Package rejected: ' + E.Message;
  end;
end;

end.
