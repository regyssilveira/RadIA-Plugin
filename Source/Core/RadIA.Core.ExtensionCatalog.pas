unit RadIA.Core.ExtensionCatalog;

interface

uses
  System.Net.HttpClient,
  RadIA.Core.DeclarativeExtensionPackages;

const
  CRadIAExtensionCatalogSchemaVersion = 1;

type
  IRadIAExtensionCatalogTransport = interface
    ['{C6759BA2-3D7C-4E8A-A982-D43547565346}']
    function GetBytes(
      const AUrl: string;
      const AMaximumBytes: Integer
    ): TArray<Byte>;
    function GetText(
      const AUrl: string;
      const AMaximumBytes: Integer
    ): string;
  end;

  TRadIAExtensionCatalogEntry = record
  private
    FDescription: string;
    FExtensionId: string;
    FName: string;
    FPackageHash: string;
    FPackageSize: Integer;
    FPackageUrl: string;
    FPublisherFingerprint: string;
    FPublisherId: string;
    FPublisherName: string;
    FVersion: string;
  public
    constructor Create(
      const AExtensionId: string;
      const AName: string;
      const ADescription: string;
      const AVersion: string;
      const APackageUrl: string;
      const APackageSize: Integer;
      const APackageHash: string
    );
    function WithPublisher(
      const AId: string;
      const AName: string;
      const AFingerprint: string
    ): TRadIAExtensionCatalogEntry;
    property Description: string read FDescription;
    property ExtensionId: string read FExtensionId;
    property Name: string read FName;
    property PackageHash: string read FPackageHash;
    property PackageSize: Integer read FPackageSize;
    property PackageUrl: string read FPackageUrl;
    property PublisherFingerprint: string read FPublisherFingerprint;
    property PublisherId: string read FPublisherId;
    property PublisherName: string read FPublisherName;
    property Version: string read FVersion;
  end;

  TRadIAExtensionCatalog = record
  private
    FEntries: TArray<TRadIAExtensionCatalogEntry>;
    FName: string;
  public
    constructor Create(
      const AName: string;
      const AEntries: TArray<TRadIAExtensionCatalogEntry>
    );
    property Entries: TArray<TRadIAExtensionCatalogEntry> read FEntries;
    property Name: string read FName;
  end;

  TRadIAHttpsExtensionCatalogTransport = class(
    TInterfacedObject,
    IRadIAExtensionCatalogTransport
  )
  private
    FHttpClient: THTTPClient;
    function Download(
      const AUrl: string;
      const AMaximumBytes: Integer
    ): TArray<Byte>;
  public
    constructor Create;
    destructor Destroy; override;
    function GetBytes(
      const AUrl: string;
      const AMaximumBytes: Integer
    ): TArray<Byte>;
    function GetText(
      const AUrl: string;
      const AMaximumBytes: Integer
    ): string;
  end;

  TRadIAExtensionCatalogClient = class
  private
    FTransport: IRadIAExtensionCatalogTransport;
    class procedure AtomicWrite(
      const AFileName: string;
      const AContent: TArray<Byte>
    ); static;
    class function ParseEntry(
      const AJson: TObject
    ): TRadIAExtensionCatalogEntry; static;
    class procedure ValidateHttpsUrl(const AUrl: string); static;
    class procedure ValidateEntryIdentity(
      const AId: string;
      const AName: string;
      const ADescription: string;
      const AVersion: string
    ); static;
    class procedure ValidatePackage(
      const AEntry: TRadIAExtensionCatalogEntry;
      const APackage: TRadIADeclarativeExtensionPackage
    ); static;
    class procedure ValidatePublisher(
      const AEntry: TRadIAExtensionCatalogEntry
    ); static;
  public
    constructor Create(
      const ATransport: IRadIAExtensionCatalogTransport = nil
    );
    function DownloadAndVerify(
      const AEntry: TRadIAExtensionCatalogEntry;
      const AOutputFileName: string
    ): TRadIADeclarativeExtensionPackage;
    function Load(const AUrl: string): TRadIAExtensionCatalog;
    class function Parse(
      const AContent: string
    ): TRadIAExtensionCatalog; static;
  end;

  TRadIAExtensionCatalogPreferences = class
  private
    FFileName: string;
  public
    constructor Create(const AFileName: string);
    function LoadUrl: string;
    procedure SaveUrl(const AUrl: string);
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.Net.URLClient,
  System.RegularExpressions,
  System.SysUtils,
  Winapi.Windows;

const
  CMaximumCatalogBytes = 1024 * 1024;
  CMaximumCatalogEntries = 500;
  CMaximumPackageBytes = 4 * 1024 * 1024;

type
  TRadIALimitedMemoryStream = class(TMemoryStream)
  private
    FMaximumBytes: Int64;
  public
    constructor Create(const AMaximumBytes: Int64);
    function Write(
      const ABuffer;
      ACount: LongInt
    ): LongInt; override;
  end;

{ TRadIALimitedMemoryStream }

constructor TRadIALimitedMemoryStream.Create(
  const AMaximumBytes: Int64
);
begin
  inherited Create;
  FMaximumBytes := AMaximumBytes;
end;

function TRadIALimitedMemoryStream.Write(
  const ABuffer;
  ACount: LongInt
): LongInt;
begin
  if (ACount < 0) or (Size + ACount > FMaximumBytes) then
    raise EArgumentException.Create(
      'Remote extension content exceeds the configured size limit.'
    );
  Result := inherited Write(ABuffer, ACount);
end;

{ TRadIAExtensionCatalogEntry }

constructor TRadIAExtensionCatalogEntry.Create(
  const AExtensionId: string;
  const AName: string;
  const ADescription: string;
  const AVersion: string;
  const APackageUrl: string;
  const APackageSize: Integer;
  const APackageHash: string
);
begin
  FExtensionId := AExtensionId;
  FName := AName;
  FDescription := ADescription;
  FVersion := AVersion;
  FPackageUrl := APackageUrl;
  FPackageSize := APackageSize;
  FPackageHash := APackageHash;
end;

function TRadIAExtensionCatalogEntry.WithPublisher(
  const AId: string;
  const AName: string;
  const AFingerprint: string
): TRadIAExtensionCatalogEntry;
begin
  Result := Self;
  Result.FPublisherId := AId;
  Result.FPublisherName := AName;
  Result.FPublisherFingerprint := AFingerprint;
end;

{ TRadIAExtensionCatalog }

constructor TRadIAExtensionCatalog.Create(
  const AName: string;
  const AEntries: TArray<TRadIAExtensionCatalogEntry>
);
begin
  FName := AName;
  FEntries := Copy(AEntries);
end;

{ TRadIAHttpsExtensionCatalogTransport }

constructor TRadIAHttpsExtensionCatalogTransport.Create;
begin
  inherited Create;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := 10000;
  FHttpClient.ResponseTimeout := 30000;
  FHttpClient.SendTimeout := 30000;
  FHttpClient.HandleRedirects := False;
  FHttpClient.AcceptCharSet := 'utf-8';
end;

destructor TRadIAHttpsExtensionCatalogTransport.Destroy;
begin
  FHttpClient.Free;
  inherited Destroy;
end;

function TRadIAHttpsExtensionCatalogTransport.Download(
  const AUrl: string;
  const AMaximumBytes: Integer
): TArray<Byte>;
var
  LResponse: IHTTPResponse;
  LStream: TRadIALimitedMemoryStream;
begin
  LStream := TRadIALimitedMemoryStream.Create(AMaximumBytes);
  try
    LResponse := FHttpClient.Get(AUrl, LStream);
    if LResponse.StatusCode <> 200 then
      raise EArgumentException.CreateFmt(
        'Extension catalog request failed with HTTP %d.',
        [LResponse.StatusCode]
      );
    SetLength(Result, Integer(LStream.Size));
    if LStream.Size > 0 then
    begin
      LStream.Position := 0;
      LStream.ReadBuffer(Result[0], Integer(LStream.Size));
    end;
  finally
    LStream.Free;
  end;
end;

function TRadIAHttpsExtensionCatalogTransport.GetBytes(
  const AUrl: string;
  const AMaximumBytes: Integer
): TArray<Byte>;
begin
  Result := Download(AUrl, AMaximumBytes);
end;

function TRadIAHttpsExtensionCatalogTransport.GetText(
  const AUrl: string;
  const AMaximumBytes: Integer
): string;
begin
  Result := TEncoding.UTF8.GetString(
    Download(AUrl, AMaximumBytes)
  );
end;

{ TRadIAExtensionCatalogClient }

class procedure TRadIAExtensionCatalogClient.AtomicWrite(
  const AFileName: string;
  const AContent: TArray<Byte>
);
var
  LTemporaryFileName: string;
begin
  if TFile.Exists(AFileName) and
    ((GetFileAttributes(PChar(AFileName)) and
    FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then
    raise EArgumentException.Create(
      'Extension package destination cannot be a reparse point.'
    );
  TDirectory.CreateDirectory(ExtractFilePath(AFileName));
  LTemporaryFileName := AFileName + '.' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '') + '.tmp';
  try
    TFile.WriteAllBytes(LTemporaryFileName, AContent);
    if not MoveFileEx(
      PChar(LTemporaryFileName),
      PChar(AFileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH
    ) then
      RaiseLastOSError;
  finally
    if TFile.Exists(LTemporaryFileName) then
      TFile.Delete(LTemporaryFileName);
  end;
end;

constructor TRadIAExtensionCatalogClient.Create(
  const ATransport: IRadIAExtensionCatalogTransport
);
begin
  inherited Create;
  if Assigned(ATransport) then
    FTransport := ATransport
  else
    FTransport := TRadIAHttpsExtensionCatalogTransport.Create;
end;

function TRadIAExtensionCatalogClient.DownloadAndVerify(
  const AEntry: TRadIAExtensionCatalogEntry;
  const AOutputFileName: string
): TRadIADeclarativeExtensionPackage;
var
  LContent: TArray<Byte>;
  LHash: string;
  LStagedFileName: string;
begin
  if not SameText(ExtractFileExt(AOutputFileName), '.radiaext') then
    raise EArgumentException.Create(
      'Extension package destination must use .radiaext.'
    );
  ValidateHttpsUrl(AEntry.PackageUrl);
  LContent := FTransport.GetBytes(
    AEntry.PackageUrl,
    CMaximumPackageBytes
  );
  if Length(LContent) <> AEntry.PackageSize then
    raise EArgumentException.Create(
      'Downloaded extension package size does not match the catalog.'
    );
  LStagedFileName := TPath.Combine(
    ExtractFilePath(AOutputFileName),
    TGUID.NewGuid.ToString + '.radiaext'
  );
  AtomicWrite(LStagedFileName, LContent);
  try
    LHash := LowerCase(
      THashSHA2.GetHashStringFromFile(LStagedFileName)
    );
    if not SameText(LHash, AEntry.PackageHash) then
      raise EArgumentException.Create(
        'Downloaded extension package SHA-256 does not match the catalog.'
      );
    Result := TRadIADeclarativeExtensionPackageReader.Read(
      LStagedFileName
    );
    ValidatePackage(AEntry, Result);
    if TFile.Exists(AOutputFileName) and
      ((GetFileAttributes(PChar(AOutputFileName)) and
      FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then
      raise EArgumentException.Create(
        'Extension package destination cannot be a reparse point.'
      );
    if not MoveFileEx(
      PChar(LStagedFileName),
      PChar(AOutputFileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH
    ) then
      RaiseLastOSError;
  except
    if TFile.Exists(LStagedFileName) then
      TFile.Delete(LStagedFileName);
    raise;
  end;
end;

function TRadIAExtensionCatalogClient.Load(
  const AUrl: string
): TRadIAExtensionCatalog;
begin
  ValidateHttpsUrl(AUrl);
  Result := Parse(FTransport.GetText(AUrl, CMaximumCatalogBytes));
end;

class function TRadIAExtensionCatalogClient.Parse(
  const AContent: string
): TRadIAExtensionCatalog;
var
  LEntries: TList<TRadIAExtensionCatalogEntry>;
  LEntry: TRadIAExtensionCatalogEntry;
  LExtensions: TJSONArray;
  LIds: TStringList;
  LIndex: Integer;
  LJson: TJSONObject;
  LName: string;
begin
  if TEncoding.UTF8.GetByteCount(AContent) > CMaximumCatalogBytes then
    raise EArgumentException.Create(
      'Extension catalog exceeds the 1 MiB size limit.'
    );
  LJson := TJSONObject.ParseJSONValue(AContent) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create(
      'Extension catalog must be a JSON object.'
    );
  LEntries := TList<TRadIAExtensionCatalogEntry>.Create;
  LIds := TStringList.Create;
  try
    LIds.CaseSensitive := False;
    if LJson.GetValue<Integer>('schemaVersion', 0) <>
      CRadIAExtensionCatalogSchemaVersion then
      raise EArgumentException.Create(
        'Extension catalog schema is unsupported.'
      );
    LName := Trim(LJson.GetValue<string>('name', ''));
    if (LName = '') or (Length(LName) > 100) then
      raise EArgumentException.Create(
        'Extension catalog name must contain 1-100 characters.'
      );
    LExtensions := LJson.GetValue('extensions') as TJSONArray;
    if not Assigned(LExtensions) or
      (LExtensions.Count > CMaximumCatalogEntries) then
      raise EArgumentException.Create(
        'Extension catalog must contain at most 500 entries.'
      );
    for LIndex := 0 to LExtensions.Count - 1 do
    begin
      LEntry := ParseEntry(LExtensions[LIndex]);
      if LIds.IndexOf(LEntry.ExtensionId) >= 0 then
        raise EArgumentException.Create(
          'Extension catalog contains duplicate IDs.'
        );
      LIds.Add(LEntry.ExtensionId);
      LEntries.Add(LEntry);
    end;
    Result := TRadIAExtensionCatalog.Create(
      LName,
      LEntries.ToArray
    );
  finally
    LIds.Free;
    LEntries.Free;
    LJson.Free;
  end;
end;

class function TRadIAExtensionCatalogClient.ParseEntry(
  const AJson: TObject
): TRadIAExtensionCatalogEntry;
var
  LDescription: string;
  LHash: string;
  LId: string;
  LName: string;
  LPackage: TJSONObject;
  LPublisher: TJSONObject;
  LSize: Integer;
  LUrl: string;
  LVersion: string;
begin
  if not (AJson is TJSONObject) then
    raise EArgumentException.Create(
      'Extension catalog entry must be an object.'
    );
  LId := Trim(TJSONObject(AJson).GetValue<string>('id', ''));
  LName := Trim(TJSONObject(AJson).GetValue<string>('name', ''));
  LDescription := Trim(
    TJSONObject(AJson).GetValue<string>('description', '')
  );
  LVersion := Trim(
    TJSONObject(AJson).GetValue<string>('version', '')
  );
  ValidateEntryIdentity(LId, LName, LDescription, LVersion);
  LPackage := TJSONObject(AJson).GetValue('package') as TJSONObject;
  LPublisher := TJSONObject(AJson).GetValue('publisher') as TJSONObject;
  if not Assigned(LPackage) or not Assigned(LPublisher) then
    raise EArgumentException.Create(
      'Catalog package and publisher metadata are required.'
    );
  LUrl := Trim(LPackage.GetValue<string>('url', ''));
  LSize := LPackage.GetValue<Integer>('size', -1);
  LHash := LowerCase(Trim(LPackage.GetValue<string>('sha256', '')));
  ValidateHttpsUrl(LUrl);
  if (LSize <= 0) or (LSize > CMaximumPackageBytes) then
    raise EArgumentException.Create('Catalog package size is invalid.');
  if not TRegEx.IsMatch(LHash, '^[0-9a-f]{64}$') then
    raise EArgumentException.Create('Catalog package hash is invalid.');
  Result := TRadIAExtensionCatalogEntry.Create(
    LId,
    LName,
    LDescription,
    LVersion,
    LUrl,
    LSize,
    LHash
  ).WithPublisher(
    Trim(LPublisher.GetValue<string>('id', '')),
    Trim(LPublisher.GetValue<string>('name', '')),
    LowerCase(Trim(LPublisher.GetValue<string>('fingerprint', '')))
  );
  ValidatePublisher(Result);
end;

class procedure TRadIAExtensionCatalogClient.ValidateEntryIdentity(
  const AId: string;
  const AName: string;
  const ADescription: string;
  const AVersion: string
);
begin
  if not TRegEx.IsMatch(AId, '^[A-Z][A-Za-z0-9]*$') then
    raise EArgumentException.Create('Catalog extension ID is invalid.');
  if (AName = '') or (Length(AName) > 100) then
    raise EArgumentException.Create('Catalog extension name is invalid.');
  if (ADescription = '') or (Length(ADescription) > 1000) then
    raise EArgumentException.Create(
      'Catalog extension description is invalid.'
    );
  if not TRegEx.IsMatch(AVersion, '^\d+\.\d+\.\d+$') then
    raise EArgumentException.Create(
      'Catalog extension version is invalid.'
    );
end;

class procedure TRadIAExtensionCatalogClient.ValidateHttpsUrl(
  const AUrl: string
);
var
  LUri: TURI;
begin
  try
    LUri := TURI.Create(AUrl);
  except
    on E: Exception do
      raise EArgumentException.Create('Extension catalog URL is invalid.');
  end;
  if not SameText(LUri.Scheme, TURI.SCHEME_HTTPS) or
    (Trim(LUri.Host) = '') or
    (LUri.Username <> '') or
    (LUri.Password <> '') or
    (LUri.Fragment <> '') then
    raise EArgumentException.Create(
      'Extension catalog URLs must use HTTPS without credentials or fragments.'
    );
end;

class procedure TRadIAExtensionCatalogClient.ValidatePackage(
  const AEntry: TRadIAExtensionCatalogEntry;
  const APackage: TRadIADeclarativeExtensionPackage
);
begin
  if not APackage.IsSigned then
    raise EArgumentException.Create(
      'Catalog packages must use signed schema version 2.'
    );
  if not SameText(AEntry.ExtensionId, APackage.ExtensionId) or
    not SameText(AEntry.Version, APackage.Version) then
    raise EArgumentException.Create(
      'Downloaded package identity does not match the catalog.'
    );
  if not SameText(AEntry.PublisherId, APackage.Publisher.Id) or
    not SameText(
      AEntry.PublisherFingerprint,
      APackage.Publisher.Fingerprint
    ) then
    raise EArgumentException.Create(
      'Downloaded package publisher does not match the catalog.'
    );
end;

class procedure TRadIAExtensionCatalogClient.ValidatePublisher(
  const AEntry: TRadIAExtensionCatalogEntry
);
begin
  if not TRegEx.IsMatch(
    AEntry.PublisherId,
    '^[A-Za-z0-9][A-Za-z0-9.-]{1,63}$'
  ) then
    raise EArgumentException.Create('Catalog publisher ID is invalid.');
  if (AEntry.PublisherName = '') or
    (Length(AEntry.PublisherName) > 100) then
    raise EArgumentException.Create('Catalog publisher name is invalid.');
  if not TRegEx.IsMatch(
    AEntry.PublisherFingerprint,
    '^[0-9a-f]{64}$'
  ) then
    raise EArgumentException.Create(
      'Catalog publisher fingerprint is invalid.'
    );
end;

{ TRadIAExtensionCatalogPreferences }

constructor TRadIAExtensionCatalogPreferences.Create(
  const AFileName: string
);
begin
  inherited Create;
  if Trim(AFileName) = '' then
    raise EArgumentException.Create(
      'Extension catalog preferences file name cannot be empty.'
    );
  FFileName := TPath.GetFullPath(AFileName);
end;

function TRadIAExtensionCatalogPreferences.LoadUrl: string;
var
  LJson: TJSONObject;
begin
  Result := '';
  if not TFile.Exists(FFileName) then
    Exit;
  if (GetFileAttributes(PChar(FFileName)) and
    FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
    raise EArgumentException.Create(
      'Extension catalog preferences cannot be a reparse point.'
    );
  if TFile.GetSize(FFileName) > 65536 then
    raise EArgumentException.Create(
      'Extension catalog preferences exceed the size limit.'
    );
  LJson := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(FFileName, TEncoding.UTF8)
  ) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create(
      'Extension catalog preferences must be a JSON object.'
    );
  try
    if LJson.GetValue<Integer>('schemaVersion', 0) <> 1 then
      raise EArgumentException.Create(
        'Extension catalog preferences schema is unsupported.'
      );
    Result := Trim(LJson.GetValue<string>('url', ''));
    if Result <> '' then
      TRadIAExtensionCatalogClient.ValidateHttpsUrl(Result);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAExtensionCatalogPreferences.SaveUrl(
  const AUrl: string
);
var
  LContent: TArray<Byte>;
  LJson: TJSONObject;
begin
  TRadIAExtensionCatalogClient.ValidateHttpsUrl(AUrl);
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('schemaVersion', TJSONNumber.Create(1));
    LJson.AddPair('url', Trim(AUrl));
    LContent := TEncoding.UTF8.GetBytes(LJson.ToJSON);
    TRadIAExtensionCatalogClient.AtomicWrite(FFileName, LContent);
  finally
    LJson.Free;
  end;
end;

end.
