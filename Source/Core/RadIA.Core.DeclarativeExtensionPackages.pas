unit RadIA.Core.DeclarativeExtensionPackages;

interface

uses
  RadIA.Core.DeclarativeExtensions;

const
  CRadIADeclarativeExtensionPackageSchemaVersion = 1;

type
  TRadIADeclarativeExtensionPackage = record
  private
    FExtensionId: string;
    FManifestContent: TArray<Byte>;
    FManifestName: string;
    FVersion: string;
  public
    constructor Create(
      const AExtensionId: string;
      const AVersion: string;
      const AManifestName: string;
      const AManifestContent: TArray<Byte>
    );
    property ExtensionId: string read FExtensionId;
    property ManifestContent: TArray<Byte> read FManifestContent;
    property ManifestName: string read FManifestName;
    property Version: string read FVersion;
  end;

  TRadIADeclarativeExtensionPackageReader = class
  private
    class function IsSafeRootFileName(const AFileName: string): Boolean; static;
    class procedure ParseMetadata(
      const AContent: TArray<Byte>;
      out AExtensionId: string;
      out AVersion: string;
      out AManifestName: string;
      out ASize: Int64;
      out AHash: string
    ); static;
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
  System.JSON,
  System.SysUtils,
  System.Zip;

const
  CMaximumArchiveBytes = 4 * 1024 * 1024;
  CMaximumEntryBytes = 1024 * 1024;
  CMaximumEntryCount = 2;
  CMetadataFileName = 'package.json';

{ TRadIADeclarativeExtensionPackage }

constructor TRadIADeclarativeExtensionPackage.Create(
  const AExtensionId: string;
  const AVersion: string;
  const AManifestName: string;
  const AManifestContent: TArray<Byte>
);
begin
  FExtensionId := AExtensionId;
  FVersion := AVersion;
  FManifestName := AManifestName;
  FManifestContent := Copy(AManifestContent);
end;

{ TRadIADeclarativeExtensionPackageReader }

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
  LExtensionId: string;
  LHash: string;
  LManifestContent: TArray<Byte>;
  LManifestName: string;
  LMetadataContent: TArray<Byte>;
  LSize: Int64;
  LVersion: string;
begin
  if not TFile.Exists(AFileName) then
    raise EFileNotFoundException.Create('The extension package does not exist.');
  if TFile.GetSize(AFileName) > CMaximumArchiveBytes then
    raise EArgumentException.Create(
      'The extension package exceeds the 4 MiB size limit.'
    );
  LMetadataContent := ReadMetadata(AFileName);
  ParseMetadata(
    LMetadataContent,
    LExtensionId,
    LVersion,
    LManifestName,
    LSize,
    LHash
  );
  LManifestContent := ReadArchiveEntry(
    AFileName,
    LManifestName
  );
  ValidateIntegrity(LManifestContent, LSize, LHash);
  Result := TRadIADeclarativeExtensionPackage.Create(
    LExtensionId,
    LVersion,
    LManifestName,
    LManifestContent
  );
  ValidateEmbeddedManifest(Result);
end;

class procedure TRadIADeclarativeExtensionPackageReader.ParseMetadata(
  const AContent: TArray<Byte>;
  out AExtensionId: string;
  out AVersion: string;
  out AManifestName: string;
  out ASize: Int64;
  out AHash: string
);
var
  LDeclaredFile: TJSONObject;
  LDeclaredFiles: TJSONArray;
  LMetadata: TJSONObject;
  LSchemaVersion: Integer;
begin
  LMetadata := TJSONObject.ParseJSONValue(
    TEncoding.UTF8.GetString(AContent)
  ) as TJSONObject;
  if not Assigned(LMetadata) then
    raise EArgumentException.Create('Package metadata must be a JSON object.');
  try
    LSchemaVersion := LMetadata.GetValue<Integer>('schemaVersion', 0);
    if LSchemaVersion <> CRadIADeclarativeExtensionPackageSchemaVersion then
      raise EArgumentException.Create(
        'Unsupported extension package schema version.'
      );
    AExtensionId := Trim(LMetadata.GetValue<string>('id', ''));
    AVersion := Trim(LMetadata.GetValue<string>('version', ''));
    AManifestName := Trim(LMetadata.GetValue<string>('manifest', ''));
    if not IsSafeRootFileName(AManifestName) or
      not AManifestName.EndsWith('.radia.json', True) then
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
      AManifestName
    ) then
      raise EArgumentException.Create(
        'Declared package path does not match the manifest.'
      );
    ASize := LDeclaredFile.GetValue<Int64>('size', -1);
    AHash := LowerCase(
      Trim(LDeclaredFile.GetValue<string>('sha256', ''))
    );
  finally
    LMetadata.Free;
  end;
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
