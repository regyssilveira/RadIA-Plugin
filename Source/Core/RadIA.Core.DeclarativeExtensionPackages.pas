unit RadIA.Core.DeclarativeExtensionPackages;

interface

uses
  System.Generics.Collections,
  System.JSON,
  System.Zip,
  RadIA.Core.DeclarativeExtensions;

const
  CRadIADeclarativeExtensionPackageSchemaVersion = 3;

type
  TRadIADeclarativeExtensionPackageFile = record
  private
    FContent: TArray<Byte>;
    FHash: string;
    FPath: string;
    FSize: Int64;
  public
    constructor Create(
      const APath: string;
      const ASize: Int64;
      const AHash: string;
      const AContent: TArray<Byte>
    );
    function WithContent(
      const AContent: TArray<Byte>
    ): TRadIADeclarativeExtensionPackageFile;
    property Content: TArray<Byte> read FContent;
    property Hash: string read FHash;
    property Path: string read FPath;
    property Size: Int64 read FSize;
  end;

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
    FResources: TArray<TRadIADeclarativeExtensionPackageFile>;
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
      const APublisher: TRadIADeclarativeExtensionPublisher;
      const AResources: TArray<TRadIADeclarativeExtensionPackageFile>
    );
    property ExtensionId: string read FExtensionId;
    property IsSigned: Boolean read GetIsSigned;
    property ManifestContent: TArray<Byte> read FManifestContent;
    property ManifestName: string read FManifestName;
    property Publisher: TRadIADeclarativeExtensionPublisher read FPublisher;
    property Resources: TArray<TRadIADeclarativeExtensionPackageFile>
      read FResources;
    property SchemaVersion: Integer read FSchemaVersion;
    property Version: string read FVersion;
  end;

  TRadIADeclarativeExtensionPackageMetadata = record
  private
    FExtensionId: string;
    FHash: string;
    FManifestName: string;
    FPublisher: TRadIADeclarativeExtensionPublisher;
    FFiles: TArray<TRadIADeclarativeExtensionPackageFile>;
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
      const AHash: string;
      const AFiles: TArray<TRadIADeclarativeExtensionPackageFile>
    );
    function WithPublisher(
      const APublisher: TRadIADeclarativeExtensionPublisher
    ): TRadIADeclarativeExtensionPackageMetadata;
    property ExtensionId: string read FExtensionId;
    property Files: TArray<TRadIADeclarativeExtensionPackageFile>
      read FFiles;
    property Hash: string read FHash;
    property ManifestName: string read FManifestName;
    property Publisher: TRadIADeclarativeExtensionPublisher read FPublisher;
    property SchemaVersion: Integer read FSchemaVersion;
    property Size: Int64 read FSize;
    property Version: string read FVersion;
  end;

  TRadIAParsedPackageFiles = record
  private
    FFiles: TArray<TRadIADeclarativeExtensionPackageFile>;
    FManifestHash: string;
    FManifestSize: Int64;
  public
    constructor Create(
      const AFiles: TArray<TRadIADeclarativeExtensionPackageFile>;
      const AManifestSize: Int64;
      const AManifestHash: string
    );
    property Files: TArray<TRadIADeclarativeExtensionPackageFile>
      read FFiles;
    property ManifestHash: string read FManifestHash;
    property ManifestSize: Int64 read FManifestSize;
  end;

  TRadIADeclarativeExtensionPackageReader = class
  private
    class function HashBytes(
      const AContent: TArray<Byte>
    ): string; static;
    class function IsSafeRootFileName(const AFileName: string): Boolean; static;
    class function IsSafeResourcePath(const APath: string): Boolean; static;
    class function NormalizeArchivePath(const APath: string): string; static;
    class function BuildSignaturePayload(
      const AMetadata: TRadIADeclarativeExtensionPackageMetadata
    ): string; static;
    class function ParseMetadata(
      const AContent: TArray<Byte>
    ): TRadIADeclarativeExtensionPackageMetadata; static;
    class function ParseDeclaredFile(
      const AJson: TJSONObject;
      const ASchemaVersion: Integer;
      const AManifestName: string;
      const ANames: TDictionary<string, Boolean>;
      var ATotalSize: Int64
    ): TRadIADeclarativeExtensionPackageFile; static;
    class function ParseDeclaredFiles(
      const AFiles: TJSONArray;
      const ASchemaVersion: Integer;
      const AManifestName: string
    ): TRadIAParsedPackageFiles; static;
    class function ParsePublisher(
      const AJson: TJSONObject;
      const ASchemaVersion: Integer
    ): TRadIADeclarativeExtensionPublisher; static;
    class function ReadArchiveEntry(
      const APackageFileName: string;
      const AEntryName: string
    ): TArray<Byte>; static;
    class function ReadResources(
      const APackageFileName: string;
      const AMetadata: TRadIADeclarativeExtensionPackageMetadata
    ): TArray<TRadIADeclarativeExtensionPackageFile>; static;
    class function ReadMetadata(
      const APackageFileName: string
    ): TArray<Byte>; static;
    class function ReadValidatedMetadataEntry(
      const AArchive: TZipFile;
      const AEntryIndex: Integer;
      const ANames: TDictionary<string, Boolean>;
      var ATotalBytes: Int64;
      out AEntryName: string
    ): TArray<Byte>; static;
    class procedure ValidateIntegrity(
      const AContent: TArray<Byte>;
      const ASize: Int64;
      const AHash: string
    ); static;
    class procedure ValidateArchiveEntries(
      const APackageFileName: string;
      const AMetadata: TRadIADeclarativeExtensionPackageMetadata
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
  private
    type
      TRadIAResourceInstallState = record
        BackupDirectory: string;
        Installed: Boolean;
        TargetDirectory: string;
      end;
    class procedure CommitResources(
      const AState: TRadIAResourceInstallState
    ); static;
    class function PrepareResources(
      const APackage: TRadIADeclarativeExtensionPackage;
      const AManager: TRadIADeclarativeExtensionManager;
      const ATemporaryDirectory: string
    ): TRadIAResourceInstallState; static;
    class function ResourceDirectory(
      const AManager: TRadIADeclarativeExtensionManager;
      const AExtensionId: string
    ): string; static;
    class procedure WriteResources(
      const ARootDirectory: string;
      const AResources: TArray<TRadIADeclarativeExtensionPackageFile>
    ); static;
    class procedure RollbackResources(
      const AState: TRadIAResourceInstallState;
      const AManager: TRadIADeclarativeExtensionManager;
      const AReservedCommands: TArray<string>
    ); static;
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
  System.Classes,
  System.Hash,
  System.IOUtils,
  System.Math,
  System.RegularExpressions,
  System.SysUtils,
  RadIA.Core.RsaSignature;

const
  CMaximumArchiveBytes = 20 * 1024 * 1024;
  CMaximumEntryBytes = 1024 * 1024;
  CMaximumEntryCount = 130;
  CMaximumTotalEntryBytes = 16 * 1024 * 1024;
  CMetadataFileName = 'package.json';

{ TRadIADeclarativeExtensionPackageFile }

constructor TRadIADeclarativeExtensionPackageFile.Create(
  const APath: string;
  const ASize: Int64;
  const AHash: string;
  const AContent: TArray<Byte>
);
begin
  FPath := APath;
  FSize := ASize;
  FHash := AHash;
  FContent := Copy(AContent);
end;

function TRadIADeclarativeExtensionPackageFile.WithContent(
  const AContent: TArray<Byte>
): TRadIADeclarativeExtensionPackageFile;
begin
  Result := Self;
  Result.FContent := Copy(AContent);
end;

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
  const APublisher: TRadIADeclarativeExtensionPublisher;
  const AResources: TArray<TRadIADeclarativeExtensionPackageFile>
);
begin
  FSchemaVersion := ASchemaVersion;
  FExtensionId := AExtensionId;
  FVersion := AVersion;
  FManifestName := AManifestName;
  FManifestContent := Copy(AManifestContent);
  FPublisher := APublisher;
  FResources := Copy(AResources);
end;

function TRadIADeclarativeExtensionPackage.GetIsSigned: Boolean;
begin
  Result := FPublisher.Signature <> '';
end;

{ TRadIADeclarativeExtensionPackageMetadata }

constructor TRadIADeclarativeExtensionPackageMetadata.Create(
  const ASchemaVersion: Integer;
  const AExtensionId: string;
  const AVersion: string;
  const AManifestName: string;
  const ASize: Int64;
  const AHash: string;
  const AFiles: TArray<TRadIADeclarativeExtensionPackageFile>
);
begin
  FSchemaVersion := ASchemaVersion;
  FExtensionId := AExtensionId;
  FVersion := AVersion;
  FManifestName := AManifestName;
  FSize := ASize;
  FHash := AHash;
  FFiles := Copy(AFiles);
end;

function TRadIADeclarativeExtensionPackageMetadata.WithPublisher(
  const APublisher: TRadIADeclarativeExtensionPublisher
): TRadIADeclarativeExtensionPackageMetadata;
begin
  Result := Self;
  Result.FPublisher := APublisher;
end;

{ TRadIAParsedPackageFiles }

constructor TRadIAParsedPackageFiles.Create(
  const AFiles: TArray<TRadIADeclarativeExtensionPackageFile>;
  const AManifestSize: Int64;
  const AManifestHash: string
);
begin
  FFiles := Copy(AFiles);
  FManifestSize := AManifestSize;
  FManifestHash := AManifestHash;
end;

{ TRadIADeclarativeExtensionPackageReader }

class function TRadIADeclarativeExtensionPackageReader.HashBytes(
  const AContent: TArray<Byte>
): string;
var
  LByte: Byte;
  LHash: TBytes;
  LStream: TBytesStream;
begin
  Result := '';
  LStream := TBytesStream.Create(AContent);
  try
    LHash := THashSHA2.GetHashBytes(LStream);
  finally
    LStream.Free;
  end;
  for LByte in LHash do
    Result := Result + Format('%.2x', [LByte]);
end;

class function
  TRadIADeclarativeExtensionPackageReader.BuildSignaturePayload(
  const AMetadata: TRadIADeclarativeExtensionPackageMetadata
): string;
var
  LFile: TRadIADeclarativeExtensionPackageFile;
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
  if AMetadata.SchemaVersion < 3 then
    Exit;
  Result := Result + #10;
  for LFile in AMetadata.Files do
    Result := Result +
      'file=' + LFile.Path + '|' + LFile.Size.ToString + '|' +
      LowerCase(LFile.Hash) + #10;
  Result := Result.TrimRight;
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

class function TRadIADeclarativeExtensionPackageReader.IsSafeResourcePath(
  const APath: string
): Boolean;
var
  LNormalized: string;
  LSegment: string;
begin
  LNormalized := APath.Trim;
  Result := (LNormalized <> '') and
    (Length(LNormalized) <= 240) and
    not LNormalized.Contains('\') and
    not LNormalized.Contains(':') and
    not LNormalized.StartsWith('/') and
    not LNormalized.EndsWith('/');
  if not Result then
    Exit;
  Result := LNormalized.StartsWith('references/', True) or
    LNormalized.StartsWith('templates/', True) or
    LNormalized.StartsWith('knowledge/', True) or
    LNormalized.StartsWith('assets/', True);
  if not Result then
    Exit;
  for LSegment in LNormalized.Split(['/']) do
    if (LSegment = '') or SameText(LSegment, '.') or
      SameText(LSegment, '..') then
      Exit(False);
end;

class function TRadIADeclarativeExtensionPackageReader.NormalizeArchivePath(
  const APath: string
): string;
begin
  Result := APath.Replace('\', '/');
end;

class function TRadIADeclarativeExtensionPackageReader.Read(
  const AFileName: string
): TRadIADeclarativeExtensionPackage;
var
  LManifestContent: TArray<Byte>;
  LMetadata: TRadIADeclarativeExtensionPackageMetadata;
  LMetadataContent: TArray<Byte>;
  LResources: TArray<TRadIADeclarativeExtensionPackageFile>;
begin
  if not TFile.Exists(AFileName) then
    raise EFileNotFoundException.Create('The extension package does not exist.');
  if TFile.GetSize(AFileName) > CMaximumArchiveBytes then
    raise EArgumentException.Create(
      'The extension package exceeds the 20 MiB size limit.'
    );
  LMetadataContent := ReadMetadata(AFileName);
  LMetadata := ParseMetadata(LMetadataContent);
  ValidateArchiveEntries(AFileName, LMetadata);
  LManifestContent := ReadArchiveEntry(
    AFileName,
    LMetadata.ManifestName
  );
  ValidateIntegrity(
    LManifestContent,
    LMetadata.Size,
    LMetadata.Hash
  );
  LResources := ReadResources(AFileName, LMetadata);
  Result := TRadIADeclarativeExtensionPackage.Create(
    LMetadata.SchemaVersion,
    LMetadata.ExtensionId,
    LMetadata.Version,
    LMetadata.ManifestName,
    LManifestContent,
    LMetadata.Publisher,
    LResources
  );
  ValidateEmbeddedManifest(Result);
  ValidatePublisher(LMetadata);
end;

class function TRadIADeclarativeExtensionPackageReader.ParseMetadata(
  const AContent: TArray<Byte>
): TRadIADeclarativeExtensionPackageMetadata;
var
  LDeclaredFiles: TJSONArray;
  LExtensionId: string;
  LManifestName: string;
  LMetadata: TJSONObject;
  LParsedFiles: TRadIAParsedPackageFiles;
  LPublisher: TRadIADeclarativeExtensionPublisher;
  LSchemaVersion: Integer;
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
    if not Assigned(LDeclaredFiles) or
      (LDeclaredFiles.Count < 1) or
      (LDeclaredFiles.Count >= CMaximumEntryCount) then
      raise EArgumentException.Create('Package file list is invalid.');
    if (LSchemaVersion < 3) and (LDeclaredFiles.Count <> 1) then
      raise EArgumentException.Create(
        'Legacy package must declare exactly one manifest file.'
      );
    LParsedFiles := ParseDeclaredFiles(
      LDeclaredFiles,
      LSchemaVersion,
      LManifestName
    );
    LPublisher := ParsePublisher(LMetadata, LSchemaVersion);
    Result := TRadIADeclarativeExtensionPackageMetadata.Create(
      LSchemaVersion,
      LExtensionId,
      LVersion,
      LManifestName,
      LParsedFiles.ManifestSize,
      LParsedFiles.ManifestHash,
      LParsedFiles.Files
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
  if ASchemaVersion = 1 then
    Exit;
  LPublisher := AJson.GetValue('publisher') as TJSONObject;
  if not Assigned(LPublisher) then
  begin
    if ASchemaVersion >= 3 then
      Exit;
    raise EArgumentException.Create(
      'Signed package publisher metadata is missing.'
    );
  end;
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
    LEntryIndex := -1;
    while LEntryIndex + 1 < LArchive.FileCount do
    begin
      Inc(LEntryIndex);
      if SameText(
        NormalizeArchivePath(LArchive.FileNames[LEntryIndex]),
        AEntryName
      ) then
        Break;
    end;
    if (LEntryIndex >= LArchive.FileCount) or not SameText(
      NormalizeArchivePath(LArchive.FileNames[LEntryIndex]),
      AEntryName
    ) then
      LEntryIndex := -1;
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

class function TRadIADeclarativeExtensionPackageReader.ParseDeclaredFile(
  const AJson: TJSONObject;
  const ASchemaVersion: Integer;
  const AManifestName: string;
  const ANames: TDictionary<string, Boolean>;
  var ATotalSize: Int64
): TRadIADeclarativeExtensionPackageFile;
var
  LHash: string;
  LPath: string;
  LSize: Int64;
begin
  LPath := Trim(AJson.GetValue<string>('path', ''));
  LSize := AJson.GetValue<Int64>('size', -1);
  LHash := LowerCase(Trim(AJson.GetValue<string>('sha256', '')));
  if ANames.ContainsKey(LowerCase(LPath)) then
    raise EArgumentException.Create(
      'Package declares a duplicate file path.'
    );
  ANames.Add(LowerCase(LPath), True);
  if (LSize < 0) or (LSize > CMaximumEntryBytes) or
    not TRegEx.IsMatch(LHash, '^[a-f0-9]{64}$') then
    raise EArgumentException.Create(
      'Declared package file integrity is invalid.'
    );
  Inc(ATotalSize, LSize);
  if ATotalSize > CMaximumTotalEntryBytes then
    raise EArgumentException.Create(
      'Package declared content exceeds the total size limit.'
    );
  if not SameText(LPath, AManifestName) and
    ((ASchemaVersion < 3) or not IsSafeResourcePath(LPath)) then
    raise EArgumentException.Create('Package resource path is invalid.');
  Result := TRadIADeclarativeExtensionPackageFile.Create(
    LPath,
    LSize,
    LHash,
    nil
  );
end;

class function TRadIADeclarativeExtensionPackageReader.ParseDeclaredFiles(
  const AFiles: TJSONArray;
  const ASchemaVersion: Integer;
  const AManifestName: string
): TRadIAParsedPackageFiles;
var
  LFile: TRadIADeclarativeExtensionPackageFile;
  LFiles: TArray<TRadIADeclarativeExtensionPackageFile>;
  LIndex: Integer;
  LManifestHash: string;
  LManifestSize: Int64;
  LNames: TDictionary<string, Boolean>;
  LTotalSize: Int64;
begin
  SetLength(LFiles, AFiles.Count);
  LManifestSize := -1;
  LManifestHash := '';
  LTotalSize := 0;
  LNames := TDictionary<string, Boolean>.Create;
  try
    for LIndex := 0 to AFiles.Count - 1 do
    begin
      if not (AFiles[LIndex] is TJSONObject) then
        raise EArgumentException.Create(
          'Every declared package file must be an object.'
        );
      LFile := ParseDeclaredFile(
        TJSONObject(AFiles[LIndex]),
        ASchemaVersion,
        AManifestName,
        LNames,
        LTotalSize
      );
      LFiles[LIndex] := LFile;
      if SameText(LFile.Path, AManifestName) then
      begin
        LManifestSize := LFile.Size;
        LManifestHash := LFile.Hash;
      end;
    end;
  finally
    LNames.Free;
  end;
  if LManifestSize < 0 then
    raise EArgumentException.Create(
      'Declared package paths do not include the manifest.'
    );
  Result := TRadIAParsedPackageFiles.Create(
    LFiles,
    LManifestSize,
    LManifestHash
  );
end;

class function TRadIADeclarativeExtensionPackageReader.ReadResources(
  const APackageFileName: string;
  const AMetadata: TRadIADeclarativeExtensionPackageMetadata
): TArray<TRadIADeclarativeExtensionPackageFile>;
var
  LContent: TArray<Byte>;
  LFile: TRadIADeclarativeExtensionPackageFile;
  LResultIndex: Integer;
begin
  SetLength(Result, Max(0, Length(AMetadata.Files) - 1));
  LResultIndex := 0;
  for LFile in AMetadata.Files do
  begin
    if SameText(LFile.Path, AMetadata.ManifestName) then
      Continue;
    LContent := ReadArchiveEntry(APackageFileName, LFile.Path);
    ValidateIntegrity(LContent, LFile.Size, LFile.Hash);
    Result[LResultIndex] := LFile.WithContent(LContent);
    Inc(LResultIndex);
  end;
  SetLength(Result, LResultIndex);
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
  LTotalBytes: Int64;
begin
  Result := nil;
  LArchive := TZipFile.Create;
  LNames := TDictionary<string, Boolean>.Create;
  try
    LArchive.Open(APackageFileName, zmRead);
    if (LArchive.FileCount < 2) or
      (LArchive.FileCount > CMaximumEntryCount) then
      raise EArgumentException.Create(
        'Package entry count is outside the supported limit.'
      );
    LTotalBytes := 0;
    for LEntryIndex := 0 to LArchive.FileCount - 1 do
    begin
      LEntryContent := ReadValidatedMetadataEntry(
        LArchive,
        LEntryIndex,
        LNames,
        LTotalBytes,
        LEntryName
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

class function
  TRadIADeclarativeExtensionPackageReader.ReadValidatedMetadataEntry(
  const AArchive: TZipFile;
  const AEntryIndex: Integer;
  const ANames: TDictionary<string, Boolean>;
  var ATotalBytes: Int64;
  out AEntryName: string
): TArray<Byte>;
begin
  AEntryName := NormalizeArchivePath(AArchive.FileNames[AEntryIndex]);
  if not IsSafeRootFileName(AEntryName) and
    not IsSafeResourcePath(AEntryName) then
    raise EArgumentException.Create(
      'Package contains an unsafe entry path.'
    );
  if ANames.ContainsKey(LowerCase(AEntryName)) then
    raise EArgumentException.Create(
      'Package contains duplicate file names.'
    );
  ANames.Add(LowerCase(AEntryName), True);
  if AArchive.FileInfo[AEntryIndex].UncompressedSize >
    CMaximumEntryBytes then
    raise EArgumentException.Create(
      'Package entry exceeds the 1 MiB size limit.'
    );
  Inc(ATotalBytes, AArchive.FileInfo[AEntryIndex].UncompressedSize);
  if ATotalBytes > CMaximumTotalEntryBytes then
    raise EArgumentException.Create(
      'Package content exceeds the total size limit.'
    );
  AArchive.Read(AEntryIndex, Result);
  if Length(Result) > CMaximumEntryBytes then
    raise EArgumentException.Create(
      'Package entry exceeds the 1 MiB size limit.'
    );
end;

class procedure
  TRadIADeclarativeExtensionPackageReader.ValidateArchiveEntries(
  const APackageFileName: string;
  const AMetadata: TRadIADeclarativeExtensionPackageMetadata
);
var
  LArchive: TZipFile;
  LDeclared: TDictionary<string, Boolean>;
  LEntryIndex: Integer;
  LEntryName: string;
  LFile: TRadIADeclarativeExtensionPackageFile;
begin
  LArchive := TZipFile.Create;
  LDeclared := TDictionary<string, Boolean>.Create;
  try
    for LFile in AMetadata.Files do
      LDeclared.Add(LowerCase(LFile.Path), True);
    LArchive.Open(APackageFileName, zmRead);
    if LArchive.FileCount <> Length(AMetadata.Files) + 1 then
      raise EArgumentException.Create(
        'Package archive does not match its closed file list.'
      );
    for LEntryIndex := 0 to LArchive.FileCount - 1 do
    begin
      LEntryName := NormalizeArchivePath(
        LArchive.FileNames[LEntryIndex]
      );
      if SameText(LEntryName, CMetadataFileName) then
        Continue;
      if not LDeclared.ContainsKey(LowerCase(LEntryName)) then
        raise EArgumentException.Create(
          'Package contains an undeclared archive entry.'
        );
    end;
  finally
    LDeclared.Free;
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
    raise EArgumentException.Create(
      'Package file size does not match metadata.'
    );
  if not SameText(HashBytes(AContent), AHash) then
    raise EArgumentException.Create(
      'Package file SHA-256 does not match metadata.'
    );
end;

class procedure TRadIADeclarativeExtensionPackageReader.ValidatePublisher(
  const AMetadata: TRadIADeclarativeExtensionPackageMetadata
);
begin
  if AMetadata.Publisher.Signature = '' then
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

class procedure TRadIADeclarativeExtensionPackageInstaller.CommitResources(
  const AState: TRadIAResourceInstallState
);
begin
  if TDirectory.Exists(AState.BackupDirectory) then
    TDirectory.Delete(AState.BackupDirectory, True);
end;

class function TRadIADeclarativeExtensionPackageInstaller.PrepareResources(
  const APackage: TRadIADeclarativeExtensionPackage;
  const AManager: TRadIADeclarativeExtensionManager;
  const ATemporaryDirectory: string
): TRadIAResourceInstallState;
var
  LStagedResources: string;
begin
  Result := Default(TRadIAResourceInstallState);
  LStagedResources := TPath.Combine(ATemporaryDirectory, 'resources');
  WriteResources(LStagedResources, APackage.Resources);
  Result.TargetDirectory := ResourceDirectory(
    AManager,
    APackage.ExtensionId
  );
  Result.BackupDirectory := Result.TargetDirectory + '.backup-' +
    TGUID.NewGuid.ToString;
  TDirectory.CreateDirectory(ExtractFilePath(Result.TargetDirectory));
  if TDirectory.Exists(Result.TargetDirectory) then
    TDirectory.Move(Result.TargetDirectory, Result.BackupDirectory);
  if Length(APackage.Resources) > 0 then
  begin
    TDirectory.Move(LStagedResources, Result.TargetDirectory);
    Result.Installed := True;
  end;
end;

class procedure TRadIADeclarativeExtensionPackageInstaller.RollbackResources(
  const AState: TRadIAResourceInstallState;
  const AManager: TRadIADeclarativeExtensionManager;
  const AReservedCommands: TArray<string>
);
begin
  if AState.Installed and
    TDirectory.Exists(AState.TargetDirectory) then
    TDirectory.Delete(AState.TargetDirectory, True);
  if TDirectory.Exists(AState.BackupDirectory) and
    not TDirectory.Exists(AState.TargetDirectory) then
    TDirectory.Move(AState.BackupDirectory, AState.TargetDirectory);
  if AState.TargetDirectory <> '' then
    AManager.Reload(AReservedCommands);
end;

class function
  TRadIADeclarativeExtensionPackageInstaller.ResourceDirectory(
  const AManager: TRadIADeclarativeExtensionManager;
  const AExtensionId: string
): string;
begin
  Result := TPath.Combine(
    TPath.Combine(AManager.Directory, '.resources'),
    AExtensionId
  );
end;

class procedure TRadIADeclarativeExtensionPackageInstaller.WriteResources(
  const ARootDirectory: string;
  const AResources: TArray<TRadIADeclarativeExtensionPackageFile>
);
var
  LDestination: string;
  LResource: TRadIADeclarativeExtensionPackageFile;
  LRoot: string;
begin
  LRoot := IncludeTrailingPathDelimiter(
    TPath.GetFullPath(ARootDirectory)
  );
  TDirectory.CreateDirectory(LRoot);
  for LResource in AResources do
  begin
    LDestination := TPath.GetFullPath(
      TPath.Combine(
        LRoot,
        LResource.Path.Replace('/', PathDelim)
      )
    );
    if not LDestination.StartsWith(LRoot, True) then
      raise EArgumentException.Create(
        'Package resource escaped its installation directory.'
      );
    TDirectory.CreateDirectory(ExtractFilePath(LDestination));
    TFile.WriteAllBytes(LDestination, LResource.Content);
  end;
end;

class function TRadIADeclarativeExtensionPackageInstaller.Install(
  const APackageFileName: string;
  const AManager: TRadIADeclarativeExtensionManager;
  const AReservedCommands: TArray<string>;
  out AExtensionId: string;
  out AMessage: string
): Boolean;
var
  LPackage: TRadIADeclarativeExtensionPackage;
  LResourceState: TRadIAResourceInstallState;
  LTemporaryDirectory: string;
  LTemporaryManifest: string;
begin
  Result := False;
  AExtensionId := '';
  AMessage := '';
  LResourceState := Default(TRadIAResourceInstallState);
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
      LResourceState := PrepareResources(
        LPackage,
        AManager,
        LTemporaryDirectory
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
      if not Result then
        RollbackResources(LResourceState, AManager, AReservedCommands)
      else
        CommitResources(LResourceState);
    finally
      if TDirectory.Exists(LTemporaryDirectory) then
        TDirectory.Delete(LTemporaryDirectory, True);
    end;
  except
    on E: Exception do
    begin
      try
        RollbackResources(LResourceState, AManager, AReservedCommands);
      except
        on ECleanup: Exception do
          AMessage := 'Resource rollback failed: ' + ECleanup.Message;
      end;
      if AMessage = '' then
        AMessage := 'Package rejected: ' + E.Message;
    end;
  end;
end;

end.
