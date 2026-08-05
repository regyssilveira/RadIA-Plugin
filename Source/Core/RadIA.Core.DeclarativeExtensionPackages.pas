unit RadIA.Core.DeclarativeExtensionPackages;

interface

uses
  System.JSON,
  RadIA.Core.DeclarativeExtensions;

const
  CRadIADeclarativeExtensionPackageSchemaVersion = 2;

type
  TRadIADeclarativeExtensionPublisher = record
  private
    FExponent: string;
    FFingerprint: string;
    FId: string;
    FModulus: string;
    FName: string;
    FSignature: string;
  public
    constructor Create(
      const AId: string;
      const AName: string;
      const AModulus: string;
      const AExponent: string;
      const ASignature: string
    );
    property Exponent: string read FExponent;
    property Fingerprint: string read FFingerprint;
    property Id: string read FId;
    property Modulus: string read FModulus;
    property Name: string read FName;
    property Signature: string read FSignature;
  end;

  TRadIADeclarativeExtensionPackage = record
  private
    FExtensionId: string;
    FManifestContent: TArray<Byte>;
    FManifestName: string;
    FPublisher: TRadIADeclarativeExtensionPublisher;
    FSchemaVersion: Integer;
    FVersion: string;
    function GetIsSigned: Boolean;
  public
    constructor Create(
      const ASchemaVersion: Integer;
      const AExtensionId: string;
      const AVersion: string;
      const AManifestName: string;
      const AManifestContent: TArray<Byte>;
      const APublisher: TRadIADeclarativeExtensionPublisher
    );
    property ExtensionId: string read FExtensionId;
    property IsSigned: Boolean read GetIsSigned;
    property ManifestContent: TArray<Byte> read FManifestContent;
    property ManifestName: string read FManifestName;
    property Publisher: TRadIADeclarativeExtensionPublisher read FPublisher;
    property SchemaVersion: Integer read FSchemaVersion;
    property Version: string read FVersion;
  end;

  TRadIADeclarativeExtensionPackageMetadata = record
  private
    FExtensionId: string;
    FHash: string;
    FManifestName: string;
    FPublisher: TRadIADeclarativeExtensionPublisher;
    FSchemaVersion: Integer;
    FSize: Int64;
    FVersion: string;
  public
    constructor Create(
      const ASchemaVersion: Integer;
      const AExtensionId: string;
      const AVersion: string;
      const AManifestName: string;
      const ASize: Int64;
      const AHash: string
    );
    function WithPublisher(
      const APublisher: TRadIADeclarativeExtensionPublisher
    ): TRadIADeclarativeExtensionPackageMetadata;
    property ExtensionId: string read FExtensionId;
    property Hash: string read FHash;
    property ManifestName: string read FManifestName;
    property Publisher: TRadIADeclarativeExtensionPublisher read FPublisher;
    property SchemaVersion: Integer read FSchemaVersion;
    property Size: Int64 read FSize;
    property Version: string read FVersion;
  end;

  TRadIADeclarativeExtensionPackageReader = class
  private
    class function IsSafeRootFileName(const AFileName: string): Boolean; static;
    class function BuildSignaturePayload(
      const AMetadata: TRadIADeclarativeExtensionPackageMetadata
    ): string; static;
    class function ParseMetadata(
      const AContent: TArray<Byte>
    ): TRadIADeclarativeExtensionPackageMetadata; static;
    class function ParsePublisher(
      const AJson: TJSONObject;
      const ASchemaVersion: Integer
    ): TRadIADeclarativeExtensionPublisher; static;
    class function ReadArchiveEntry(
      const APackageFileName: string;
      const AEntryName: string
    ): TArray<Byte>; static;
    class function ReadMetadata(
      const APackageFileName: string
    ): TArray<Byte>; static;
    class procedure ValidateIntegrity(
      const AContent: TArray<Byte>;
      const ASize: Int64;
      const AHash: string
    ); static;
    class procedure ValidateEmbeddedManifest(
      const APackage: TRadIADeclarativeExtensionPackage
    ); static;
    class procedure ValidatePublisher(
      const AMetadata: TRadIADeclarativeExtensionPackageMetadata
    ); static;
  public
    class function Read(
      const AFileName: string
    ): TRadIADeclarativeExtensionPackage; static;
  end;

  TRadIADeclarativeExtensionPackageInstaller = class
  public
    class function Install(
      const APackageFileName: string;
      const AManager: TRadIADeclarativeExtensionManager;
      const AReservedCommands: TArray<string>;
      out AExtensionId: string;
      out AMessage: string
    ): Boolean; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.RegularExpressions,
  System.SysUtils,
  System.Zip,
  RadIA.Core.RsaSignature;

const
  CMaximumArchiveBytes = 4 * 1024 * 1024;
  CMaximumEntryBytes = 1024 * 1024;
  CMaximumEntryCount = 2;
  CMetadataFileName = 'package.json';

{ TRadIADeclarativeExtensionPublisher }

constructor TRadIADeclarativeExtensionPublisher.Create(
  const AId: string;
  const AName: string;
  const AModulus: string;
  const AExponent: string;
  const ASignature: string
);
begin
  FId := AId;
  FName := AName;
  FModulus := AModulus;
  FExponent := AExponent;
  FSignature := ASignature;
  if (AModulus <> '') and (AExponent <> '') then
    FFingerprint := TRadIARsaSignature.Fingerprint(
      AModulus,
      AExponent
    );
end;

{ TRadIADeclarativeExtensionPackage }

constructor TRadIADeclarativeExtensionPackage.Create(
  const ASchemaVersion: Integer;
  const AExtensionId: string;
  const AVersion: string;
  const AManifestName: string;
  const AManifestContent: TArray<Byte>;
  const APublisher: TRadIADeclarativeExtensionPublisher
);
begin
  FSchemaVersion := ASchemaVersion;
  FExtensionId := AExtensionId;
  FVersion := AVersion;
  FManifestName := AManifestName;
  FManifestContent := Copy(AManifestContent);
  FPublisher := APublisher;
end;

function TRadIADeclarativeExtensionPackage.GetIsSigned: Boolean;
begin
  Result := FSchemaVersion >= 2;
end;

{ TRadIADeclarativeExtensionPackageMetadata }

constructor TRadIADeclarativeExtensionPackageMetadata.Create(
  const ASchemaVersion: Integer;
  const AExtensionId: string;
  const AVersion: string;
  const AManifestName: string;
  const ASize: Int64;
  const AHash: string
);
begin
  FSchemaVersion := ASchemaVersion;
  FExtensionId := AExtensionId;
  FVersion := AVersion;
  FManifestName := AManifestName;
  FSize := ASize;
  FHash := AHash;
end;

function TRadIADeclarativeExtensionPackageMetadata.WithPublisher(
  const APublisher: TRadIADeclarativeExtensionPublisher
): TRadIADeclarativeExtensionPackageMetadata;
begin
  Result := Self;
  Result.FPublisher := APublisher;
end;

{ TRadIADeclarativeExtensionPackageReader }

class function
  TRadIADeclarativeExtensionPackageReader.BuildSignaturePayload(
  const AMetadata: TRadIADeclarativeExtensionPackageMetadata
): string;
begin
  Result :=
    'schemaVersion=' + AMetadata.SchemaVersion.ToString + #10 +
    'id=' + AMetadata.ExtensionId + #10 +
    'version=' + AMetadata.Version + #10 +
    'manifest=' + AMetadata.ManifestName + #10 +
    'size=' + AMetadata.Size.ToString + #10 +
    'sha256=' + LowerCase(AMetadata.Hash) + #10 +
    'publisherId=' + AMetadata.Publisher.Id + #10 +
    'publisherName=' + AMetadata.Publisher.Name + #10 +
    'modulus=' + AMetadata.Publisher.Modulus + #10 +
    'exponent=' + AMetadata.Publisher.Exponent;
end;

class function TRadIADeclarativeExtensionPackageReader.IsSafeRootFileName(
  const AFileName: string
): Boolean;
begin
  Result := (AFileName <> '') and
    (ExtractFileName(AFileName) = AFileName) and
    not AFileName.Contains('/') and
    not AFileName.Contains('\') and
    not AFileName.Contains(':') and
    not SameText(AFileName, '.') and
    not SameText(AFileName, '..');
end;

class function TRadIADeclarativeExtensionPackageReader.Read(
  const AFileName: string
): TRadIADeclarativeExtensionPackage;
var
  LManifestContent: TArray<Byte>;
  LMetadata: TRadIADeclarativeExtensionPackageMetadata;
  LMetadataContent: TArray<Byte>;
begin
  if not TFile.Exists(AFileName) then
    raise EFileNotFoundException.Create('The extension package does not exist.');
  if TFile.GetSize(AFileName) > CMaximumArchiveBytes then
    raise EArgumentException.Create(
      'The extension package exceeds the 4 MiB size limit.'
    );
  LMetadataContent := ReadMetadata(AFileName);
  LMetadata := ParseMetadata(LMetadataContent);
  LManifestContent := ReadArchiveEntry(
    AFileName,
    LMetadata.ManifestName
  );
  ValidateIntegrity(
    LManifestContent,
    LMetadata.Size,
    LMetadata.Hash
  );
  Result := TRadIADeclarativeExtensionPackage.Create(
    LMetadata.SchemaVersion,
    LMetadata.ExtensionId,
    LMetadata.Version,
    LMetadata.ManifestName,
    LManifestContent,
    LMetadata.Publisher
  );
  ValidateEmbeddedManifest(Result);
  ValidatePublisher(LMetadata);
end;

class function TRadIADeclarativeExtensionPackageReader.ParseMetadata(
  const AContent: TArray<Byte>
): TRadIADeclarativeExtensionPackageMetadata;
var
  LDeclaredFile: TJSONObject;
  LDeclaredFiles: TJSONArray;
  LExtensionId: string;
  LHash: string;
  LManifestName: string;
  LMetadata: TJSONObject;
  LPublisher: TRadIADeclarativeExtensionPublisher;
  LSchemaVersion: Integer;
  LSize: Int64;
  LVersion: string;
begin
  LMetadata := TJSONObject.ParseJSONValue(
    TEncoding.UTF8.GetString(AContent)
  ) as TJSONObject;
  if not Assigned(LMetadata) then
    raise EArgumentException.Create('Package metadata must be a JSON object.');
  try
    LSchemaVersion := LMetadata.GetValue<Integer>('schemaVersion', 0);
    if (LSchemaVersion < 1) or
      (LSchemaVersion > CRadIADeclarativeExtensionPackageSchemaVersion) then
      raise EArgumentException.Create(
        'Unsupported extension package schema version.'
      );
    LExtensionId := Trim(LMetadata.GetValue<string>('id', ''));
    LVersion := Trim(LMetadata.GetValue<string>('version', ''));
    LManifestName := Trim(LMetadata.GetValue<string>('manifest', ''));
    if not IsSafeRootFileName(LManifestName) or
      not LManifestName.EndsWith('.radia.json', True) then
      raise EArgumentException.Create('Package manifest name is invalid.');
    LDeclaredFiles := LMetadata.GetValue('files') as TJSONArray;
    if not Assigned(LDeclaredFiles) or (LDeclaredFiles.Count <> 1) or
      not (LDeclaredFiles[0] is TJSONObject) then
      raise EArgumentException.Create(
        'Package must declare exactly one manifest file.'
      );
    LDeclaredFile := TJSONObject(LDeclaredFiles[0]);
    if not SameText(
      LDeclaredFile.GetValue<string>('path', ''),
      LManifestName
    ) then
      raise EArgumentException.Create(
        'Declared package path does not match the manifest.'
      );
    LSize := LDeclaredFile.GetValue<Int64>('size', -1);
    LHash := LowerCase(
      Trim(LDeclaredFile.GetValue<string>('sha256', ''))
    );
    LPublisher := ParsePublisher(LMetadata, LSchemaVersion);
    Result := TRadIADeclarativeExtensionPackageMetadata.Create(
      LSchemaVersion,
      LExtensionId,
      LVersion,
      LManifestName,
      LSize,
      LHash
    ).WithPublisher(LPublisher);
  finally
    LMetadata.Free;
  end;
end;

class function TRadIADeclarativeExtensionPackageReader.ParsePublisher(
  const AJson: TJSONObject;
  const ASchemaVersion: Integer
): TRadIADeclarativeExtensionPublisher;
var
  LPublisher: TJSONObject;
begin
  Result := Default(TRadIADeclarativeExtensionPublisher);
  if ASchemaVersion < 2 then
    Exit;
  LPublisher := AJson.GetValue('publisher') as TJSONObject;
  if not Assigned(LPublisher) then
    raise EArgumentException.Create(
      'Signed package publisher metadata is missing.'
    );
  if not SameText(
    LPublisher.GetValue<string>('algorithm', ''),
    'RSA-SHA256'
  ) then
    raise EArgumentException.Create(
      'Signed package algorithm must be RSA-SHA256.'
    );
  Result := TRadIADeclarativeExtensionPublisher.Create(
    Trim(LPublisher.GetValue<string>('id', '')),
    Trim(LPublisher.GetValue<string>('name', '')),
    Trim(LPublisher.GetValue<string>('modulus', '')),
    Trim(LPublisher.GetValue<string>('exponent', '')),
    Trim(LPublisher.GetValue<string>('signature', ''))
  );
end;

class function
  TRadIADeclarativeExtensionPackageReader.ReadArchiveEntry(
  const APackageFileName: string;
  const AEntryName: string
): TArray<Byte>;
var
  LArchive: TZipFile;
  LEntryIndex: Integer;
begin
  LArchive := TZipFile.Create;
  try
    LArchive.Open(APackageFileName, zmRead);
    LEntryIndex := LArchive.IndexOf(AEntryName);
    if LEntryIndex < 0 then
      raise EArgumentException.Create(
        'Declared manifest is absent from the package.'
      );
    if LArchive.FileInfo[LEntryIndex].UncompressedSize >
      CMaximumEntryBytes then
      raise EArgumentException.Create(
        'Package entry exceeds the 1 MiB size limit.'
      );
    LArchive.Read(LEntryIndex, Result);
    if Length(Result) > CMaximumEntryBytes then
      raise EArgumentException.Create(
        'Package entry exceeds the 1 MiB size limit.'
      );
  finally
    LArchive.Free;
  end;
end;

class function TRadIADeclarativeExtensionPackageReader.ReadMetadata(
  const APackageFileName: string
): TArray<Byte>;
var
  LArchive: TZipFile;
  LEntryContent: TArray<Byte>;
  LEntryIndex: Integer;
  LEntryName: string;
  LNames: TDictionary<string, Boolean>;
begin
  Result := nil;
  LArchive := TZipFile.Create;
  LNames := TDictionary<string, Boolean>.Create;
  try
    LArchive.Open(APackageFileName, zmRead);
    if LArchive.FileCount <> CMaximumEntryCount then
      raise EArgumentException.Create(
        'Package must contain exactly package.json and one manifest.'
      );
    for LEntryIndex := 0 to LArchive.FileCount - 1 do
    begin
      LEntryName := LArchive.FileNames[LEntryIndex];
      if not IsSafeRootFileName(LEntryName) then
        raise EArgumentException.Create(
          'Package entries must be safe root file names.'
        );
      if LNames.ContainsKey(LowerCase(LEntryName)) then
        raise EArgumentException.Create(
          'Package contains duplicate file names.'
        );
      LNames.Add(LowerCase(LEntryName), True);
      if LArchive.FileInfo[LEntryIndex].UncompressedSize >
        CMaximumEntryBytes then
        raise EArgumentException.Create(
          'Package entry exceeds the 1 MiB size limit.'
        );
      LArchive.Read(LEntryIndex, LEntryContent);
      if Length(LEntryContent) > CMaximumEntryBytes then
        raise EArgumentException.Create(
          'Package entry exceeds the 1 MiB size limit.'
        );
      if SameText(LEntryName, CMetadataFileName) then
        Result := Copy(LEntryContent);
    end;
    if Length(Result) = 0 then
      raise EArgumentException.Create('Package metadata is missing.');
  finally
    LNames.Free;
    LArchive.Free;
  end;
end;

class procedure
  TRadIADeclarativeExtensionPackageReader.ValidateIntegrity(
  const AContent: TArray<Byte>;
  const ASize: Int64;
  const AHash: string
);
begin
  if Length(AContent) <> ASize then
    raise EArgumentException.Create('Manifest size does not match metadata.');
  if not SameText(
    THashSHA2.GetHashString(
      TEncoding.UTF8.GetString(AContent)
    ),
    AHash
  ) then
    raise EArgumentException.Create(
      'Manifest SHA-256 does not match package metadata.'
    );
end;

class procedure TRadIADeclarativeExtensionPackageReader.ValidatePublisher(
  const AMetadata: TRadIADeclarativeExtensionPackageMetadata
);
begin
  if AMetadata.SchemaVersion < 2 then
    Exit;
  if not TRegEx.IsMatch(
    AMetadata.Publisher.Id,
    '^[A-Za-z0-9][A-Za-z0-9.-]{1,63}$'
  ) then
    raise EArgumentException.Create('Package publisher ID is invalid.');
  if (AMetadata.Publisher.Name = '') or
    (Length(AMetadata.Publisher.Name) > 100) then
    raise EArgumentException.Create('Package publisher name is invalid.');
  if AMetadata.Publisher.Signature = '' then
    raise EArgumentException.Create('Package publisher signature is missing.');
  if not TRadIARsaSignature.VerifySha256(
    BuildSignaturePayload(AMetadata),
    AMetadata.Publisher.Modulus,
    AMetadata.Publisher.Exponent,
    AMetadata.Publisher.Signature
  ) then
    raise EArgumentException.Create(
      'Package publisher signature is invalid.'
    );
end;

class procedure
  TRadIADeclarativeExtensionPackageReader.ValidateEmbeddedManifest(
  const APackage: TRadIADeclarativeExtensionPackage
);
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(
    TEncoding.UTF8.GetString(APackage.ManifestContent)
  ) as TJSONObject;
  if not Assigned(LJson) then
    raise EArgumentException.Create(
      'Embedded manifest must be a JSON object.'
    );
  try
    if not SameText(
      LJson.GetValue<string>('id', ''),
      APackage.ExtensionId
    ) then
      raise EArgumentException.Create(
        'Package ID does not match the embedded manifest.'
      );
    if not SameText(
      LJson.GetValue<string>('version', ''),
      APackage.Version
    ) then
      raise EArgumentException.Create(
        'Package version does not match the embedded manifest.'
      );
  finally
    LJson.Free;
  end;
end;

{ TRadIADeclarativeExtensionPackageInstaller }

class function TRadIADeclarativeExtensionPackageInstaller.Install(
  const APackageFileName: string;
  const AManager: TRadIADeclarativeExtensionManager;
  const AReservedCommands: TArray<string>;
  out AExtensionId: string;
  out AMessage: string
): Boolean;
var
  LPackage: TRadIADeclarativeExtensionPackage;
  LTemporaryDirectory: string;
  LTemporaryManifest: string;
begin
  Result := False;
  AExtensionId := '';
  AMessage := '';
  try
    LPackage := TRadIADeclarativeExtensionPackageReader.Read(
      APackageFileName
    );
    LTemporaryDirectory := TPath.Combine(
      TPath.GetTempPath,
      'RadIA-PackageInstall-' + TGUID.NewGuid.ToString
    );
    TDirectory.CreateDirectory(LTemporaryDirectory);
    try
      LTemporaryManifest := TPath.Combine(
        LTemporaryDirectory,
        LPackage.ManifestName
      );
      TFile.WriteAllBytes(
        LTemporaryManifest,
        LPackage.ManifestContent
      );
      Result := AManager.InstallOrUpdate(
        LTemporaryManifest,
        AReservedCommands,
        AExtensionId,
        AMessage
      );
      if Result and not SameText(AExtensionId, LPackage.ExtensionId) then
        raise EInvalidOpException.Create(
          'Installed extension ID does not match the package.'
        );
    finally
      if TDirectory.Exists(LTemporaryDirectory) then
        TDirectory.Delete(LTemporaryDirectory, True);
    end;
  except
    on E: Exception do
      AMessage := 'Package rejected: ' + E.Message;
  end;
end;

end.
