unit RadIA.Core.ExtensionStudio;

interface

uses
  System.JSON,
  System.Zip;

type
  TRadIAExtensionStudioKind = (
    eskCommand,
    eskSkill,
    eskAlias,
    eskJourney,
    eskWorkflow
  );

  TRadIAExtensionStudioDraft = record
  private
    FKind: TRadIAExtensionStudioKind;
    FExtensionId: string;
    FVersion: string;
    FName: string;
    FDescription: string;
    FTriggerOrTarget: string;
    FContent: string;
    FContentFile: string;
  public
    constructor Create(
      const AKind: TRadIAExtensionStudioKind;
      const AExtensionId: string;
      const AVersion: string;
      const AName: string;
      const ADescription: string;
      const ATriggerOrTarget: string;
      const AContent: string
    );
    function WithContentFile(
      const AContentFile: string
    ): TRadIAExtensionStudioDraft;
    property Kind: TRadIAExtensionStudioKind read FKind;
    property ExtensionId: string read FExtensionId;
    property Version: string read FVersion;
    property Name: string read FName;
    property Description: string read FDescription;
    property TriggerOrTarget: string read FTriggerOrTarget;
    property Content: string read FContent;
    property ContentFile: string read FContentFile;
  end;

  TRadIAExtensionStudioBuilder = class
  private
    class procedure AddCapability(
      const ARoot: TObject;
      const ADraft: TRadIAExtensionStudioDraft
    ); static;
    class procedure Validate(
      const ADraft: TRadIAExtensionStudioDraft
    ); static;
    class procedure ValidateIdentity(
      const ADraft: TRadIAExtensionStudioDraft
    ); static;
    class procedure ValidateNamespacedCapability(
      const ADraft: TRadIAExtensionStudioDraft
    ); static;
    class procedure ValidatePromptCapability(
      const ADraft: TRadIAExtensionStudioDraft
    ); static;
  public
    class function BuildManifest(
      const ADraft: TRadIAExtensionStudioDraft
    ): string; static;
    class function BuildAudit(
      const ADraft: TRadIAExtensionStudioDraft
    ): string; static;
  end;

  TRadIAExtensionStudioPackager = class
  private
    type
      TRadIAResource = record
        SourceFileName: string;
        PackagePath: string;
        Size: Int64;
        Hash: string;
      end;
    class function CollectResources(
      const AResourcesPath: string;
      const AManifestSize: Int64
    ): TArray<TRadIAResource>; static;
    class function CreateMetadata(
      const AId: string;
      const AVersion: string;
      const AManifestName: string;
      const AManifestSize: Int64;
      const AManifestHash: string;
      const AResources: TArray<TRadIAResource>
    ): TJSONObject; static;
    class function IsAllowedResourcePath(
      const APath: string
    ): Boolean; static;
    class procedure AddResourcesToArchive(
      const AArchive: TZipFile;
      const AResources: TArray<TRadIAResource>
    ); static;
    class procedure ValidateOutputFileName(
      const AOutputFileName: string
    ); static;
  public
    class function ExportUnsigned(
      const AManifest: string;
      const AOutputFileName: string;
      const AResourcesPath: string = ''
    ): string; static;
  end;

  TRadIAExtensionStudioSandbox = class
  public
    class function TestManifest(
      const AManifest: string;
      const AReservedCommands: TArray<string>;
      const AResourcesPath: string = ''
    ): string; static;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.RegularExpressions,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.DeclarativeExtensionPackages,
  RadIA.Core.DeclarativeExtensions;

function HashExtensionStudioBytes(const ABytes: TArray<Byte>): string;
var
  LByte: Byte;
  LHash: TBytes;
  LStream: TBytesStream;
begin
  Result := '';
  LStream := TBytesStream.Create(ABytes);
  try
    LHash := THashSHA2.GetHashBytes(LStream);
  finally
    LStream.Free;
  end;
  for LByte in LHash do
    Result := Result + Format('%.2x', [LByte]);
end;

{ TRadIAExtensionStudioDraft }

constructor TRadIAExtensionStudioDraft.Create(
  const AKind: TRadIAExtensionStudioKind;
  const AExtensionId: string;
  const AVersion: string;
  const AName: string;
  const ADescription: string;
  const ATriggerOrTarget: string;
  const AContent: string
);
begin
  FKind := AKind;
  FExtensionId := Trim(AExtensionId);
  FVersion := Trim(AVersion);
  FName := Trim(AName);
  FDescription := Trim(ADescription);
  FTriggerOrTarget := Trim(ATriggerOrTarget);
  FContent := Trim(AContent);
  FContentFile := '';
end;

function TRadIAExtensionStudioDraft.WithContentFile(
  const AContentFile: string
): TRadIAExtensionStudioDraft;
begin
  Result := Self;
  Result.FContentFile := Trim(AContentFile);
end;

{ TRadIAExtensionStudioBuilder }

class function TRadIAExtensionStudioBuilder.BuildAudit(
  const ADraft: TRadIAExtensionStudioDraft
): string;
const
  CKindNames: array[TRadIAExtensionStudioKind] of string = (
    'chat command',
    'skill',
    'tool alias',
    'journey',
    'audited workflow'
  );
  CPermissions: array[TRadIAExtensionStudioKind] of string = (
    'chat.prompt',
    'chat.prompt',
    'tool.alias',
    'chat.prompt',
    'tool.workflow'
  );
begin
  Validate(ADraft);
  Result :=
    'Extension: ' + ADraft.ExtensionId + ' ' + ADraft.Version + sLineBreak +
    'Capability: ' + CKindNames[ADraft.Kind] + sLineBreak +
    'Permission: ' + CPermissions[ADraft.Kind] + sLineBreak +
    'Enabled after install: yes' + sLineBreak +
    'Arbitrary process execution: no' + sLineBreak +
    'Credential fields allowed: no' + sLineBreak +
    'Runtime policy: central consent and audit apply' + sLineBreak +
    'Package signature: unsigned export requires install-time confirmation';
end;

class procedure TRadIAExtensionStudioBuilder.AddCapability(
  const ARoot: TObject;
  const ADraft: TRadIAExtensionStudioDraft
);
var
  LArray: TJSONArray;
  LCapability: TJSONObject;
  LSteps: TJSONArray;
begin
  LArray := TJSONArray.Create;
  LCapability := TJSONObject.Create;
  LArray.AddElement(LCapability);
  LCapability.AddPair('name', ADraft.Name);
  LCapability.AddPair('description', ADraft.Description);
  case ADraft.Kind of
    eskCommand:
      begin
        TJSONObject(ARoot).AddPair('commands', LArray);
        LCapability.AddPair('command', ADraft.TriggerOrTarget);
        if ADraft.ContentFile <> '' then
          LCapability.AddPair('contentFile', ADraft.ContentFile)
        else
          LCapability.AddPair('prompt', ADraft.Content);
      end;
    eskSkill:
      begin
        TJSONObject(ARoot).AddPair('skills', LArray);
        LCapability.AddPair('command', ADraft.TriggerOrTarget);
        if ADraft.ContentFile <> '' then
          LCapability.AddPair('contentFile', ADraft.ContentFile)
        else
          LCapability.AddPair('instructions', ADraft.Content);
      end;
    eskAlias:
      begin
        TJSONObject(ARoot).AddPair('tools', LArray);
        LCapability.AddPair('targetTool', ADraft.TriggerOrTarget);
      end;
    eskJourney:
      begin
        TJSONObject(ARoot).AddPair('journeys', LArray);
        LCapability.AddPair('command', ADraft.TriggerOrTarget);
        if ADraft.ContentFile <> '' then
          LCapability.AddPair('contentFile', ADraft.ContentFile)
        else
          LCapability.AddPair('objective', ADraft.Content);
      end;
    eskWorkflow:
      begin
        TJSONObject(ARoot).AddPair('workflows', LArray);
        LSteps := TJSONObject.ParseJSONValue(ADraft.Content) as TJSONArray;
        if not Assigned(LSteps) then
          raise EArgumentException.Create(
            'Workflow steps must be a JSON array.'
          );
        LCapability.AddPair('steps', LSteps);
      end;
  end;
end;

class function TRadIAExtensionStudioBuilder.BuildManifest(
  const ADraft: TRadIAExtensionStudioDraft
): string;
var
  LPermissions: TJSONArray;
  LRoot: TJSONObject;
begin
  Validate(ADraft);
  LRoot := TJSONObject.Create;
  try
    if ADraft.ContentFile <> '' then
      LRoot.AddPair('schemaVersion', TJSONNumber.Create(6))
    else
      LRoot.AddPair('schemaVersion', TJSONNumber.Create(5));
    LRoot.AddPair('id', ADraft.ExtensionId);
    LRoot.AddPair('version', ADraft.Version);
    LRoot.AddPair('enabled', TJSONBool.Create(True));
    LPermissions := TJSONArray.Create;
    if ADraft.Kind = eskAlias then
      LPermissions.Add('tool.alias')
    else if ADraft.Kind = eskWorkflow then
      LPermissions.Add('tool.workflow')
    else
      LPermissions.Add('chat.prompt');
    LRoot.AddPair('permissions', LPermissions);
    AddCapability(LRoot, ADraft);
    Result := LRoot.Format(2);
  finally
    LRoot.Free;
  end;
end;

class procedure TRadIAExtensionStudioBuilder.Validate(
  const ADraft: TRadIAExtensionStudioDraft
);
begin
  ValidateIdentity(ADraft);
  if ADraft.Kind in [eskCommand, eskSkill, eskJourney] then
    ValidatePromptCapability(ADraft);
  if ADraft.Kind in [eskAlias, eskWorkflow] then
    ValidateNamespacedCapability(ADraft);
end;

class procedure TRadIAExtensionStudioBuilder.ValidateIdentity(
  const ADraft: TRadIAExtensionStudioDraft
);
begin
  if not TRegEx.IsMatch(ADraft.ExtensionId, '^[A-Za-z][A-Za-z0-9]{2,63}$') then
    raise EArgumentException.Create(
      'Extension ID must contain 3-64 letters or digits and start with a letter.'
    );
  if not TRegEx.IsMatch(ADraft.Version, '^\d+\.\d+\.\d+$') then
    raise EArgumentException.Create('Version must use semantic X.Y.Z format.');
  if (ADraft.Name = '') or (Length(ADraft.Name) > 100) then
    raise EArgumentException.Create('Capability name must contain 1-100 characters.');
  if (ADraft.Description = '') or (Length(ADraft.Description) > 500) then
    raise EArgumentException.Create(
      'Description must contain 1-500 characters.'
    );
end;

class procedure TRadIAExtensionStudioBuilder.ValidateNamespacedCapability(
  const ADraft: TRadIAExtensionStudioDraft
);
begin
  if not ADraft.Name.StartsWith(ADraft.ExtensionId, True) then
    raise EArgumentException.Create(
      'Alias and workflow names must start with the extension ID.'
    );
  if (ADraft.Kind = eskAlias) and (ADraft.TriggerOrTarget = '') then
    raise EArgumentException.Create('Alias target tool cannot be empty.');
  if (ADraft.Kind = eskWorkflow) and (ADraft.Content = '') then
    raise EArgumentException.Create('Workflow steps cannot be empty.');
end;

class procedure TRadIAExtensionStudioBuilder.ValidatePromptCapability(
  const ADraft: TRadIAExtensionStudioDraft
);
begin
  if not TRegEx.IsMatch(
    ADraft.TriggerOrTarget,
    '^/[a-z0-9][a-z0-9-]{1,62}$'
  ) then
    raise EArgumentException.Create(
      'Slash command must use lowercase letters, digits, and hyphens.'
    );
  if (ADraft.Content = '') and (ADraft.ContentFile = '') then
    raise EArgumentException.Create(
      'Capability content or content file cannot be empty.'
    );
  if (ADraft.Content <> '') and (ADraft.ContentFile <> '') then
    raise EArgumentException.Create(
      'Capability must use inline content or one content file.'
    );
  if (ADraft.ContentFile <> '') and
    (
      ADraft.ContentFile.Contains('\') or
      ADraft.ContentFile.Contains(':') or
      ADraft.ContentFile.StartsWith('/') or
      ADraft.ContentFile.EndsWith('/') or
      TRegEx.IsMatch(ADraft.ContentFile, '(^|/)\.\.?(/|$)') or
      not (
        ADraft.ContentFile.StartsWith('references/', True) or
        ADraft.ContentFile.StartsWith('templates/', True) or
        ADraft.ContentFile.StartsWith('knowledge/', True)
      )
    ) then
    raise EArgumentException.Create(
      'Content file must be under references, templates, or knowledge.'
    );
end;

{ TRadIAExtensionStudioPackager }

class procedure TRadIAExtensionStudioPackager.AddResourcesToArchive(
  const AArchive: TZipFile;
  const AResources: TArray<TRadIAResource>
);
var
  LResource: TRadIAResource;
begin
  for LResource in AResources do
    AArchive.Add(LResource.SourceFileName, LResource.PackagePath);
end;

class function TRadIAExtensionStudioPackager.CollectResources(
  const AResourcesPath: string;
  const AManifestSize: Int64
): TArray<TRadIAResource>;
var
  LBytes: TArray<Byte>;
  LFileName: string;
  LPackagePath: string;
  LResource: TRadIAResource;
  LResources: TList<TRadIAResource>;
  LRoot: string;
  LTotalSize: Int64;
begin
  Result := [];
  if Trim(AResourcesPath) = '' then
    Exit;
  LRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(AResourcesPath));
  if not TDirectory.Exists(LRoot) then
    raise EDirectoryNotFoundException.Create(
      'Resources directory was not found.'
    );
  LResources := TList<TRadIAResource>.Create;
  try
    LTotalSize := AManifestSize;
    for LFileName in TDirectory.GetFiles(
      LRoot,
      '*',
      TSearchOption.soAllDirectories
    ) do
    begin
      if (GetFileAttributes(PChar(LFileName)) and
        FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
        raise EArgumentException.Create(
          'Resource reparse points are not allowed.'
        );
      LPackagePath := LFileName.Substring(
        Length(LRoot)
      ).Replace(PathDelim, '/');
      if not IsAllowedResourcePath(LPackagePath) then
        raise EArgumentException.Create(
          'Resources must be under references, templates, knowledge, or assets.'
        );
      LBytes := TFile.ReadAllBytes(LFileName);
      if Length(LBytes) > 1024 * 1024 then
        raise EArgumentException.Create(
          'Each resource must not exceed 1 MiB.'
        );
      LResource.SourceFileName := LFileName;
      LResource.PackagePath := LPackagePath;
      LResource.Size := Length(LBytes);
      LResource.Hash := HashExtensionStudioBytes(LBytes);
      LResources.Add(LResource);
      Inc(LTotalSize, Length(LBytes));
    end;
    if LResources.Count > 128 then
      raise EArgumentException.Create(
        'A package supports at most 128 resources.'
      );
    if LTotalSize > 16 * 1024 * 1024 then
      raise EArgumentException.Create(
        'Package content exceeds the 16 MiB total size limit.'
      );
    Result := LResources.ToArray;
  finally
    LResources.Free;
  end;
end;

class function TRadIAExtensionStudioPackager.IsAllowedResourcePath(
  const APath: string
): Boolean;
begin
  Result :=
    (Length(APath) <= 240) and
    not APath.Contains('\') and
    not APath.Contains(':') and
    not APath.StartsWith('/') and
    not APath.EndsWith('/') and
    not TRegEx.IsMatch(APath, '(^|/)\.\.?(/|$)') and
    (
      APath.StartsWith('references/', True) or
      APath.StartsWith('templates/', True) or
      APath.StartsWith('knowledge/', True) or
      APath.StartsWith('assets/', True)
    );
end;

class function TRadIAExtensionStudioPackager.CreateMetadata(
  const AId: string;
  const AVersion: string;
  const AManifestName: string;
  const AManifestSize: Int64;
  const AManifestHash: string;
  const AResources: TArray<TRadIAResource>
): TJSONObject;
var
  LFile: TJSONObject;
  LFiles: TJSONArray;
  LResource: TRadIAResource;
begin
  Result := TJSONObject.Create;
  if Length(AResources) = 0 then
    Result.AddPair('schemaVersion', TJSONNumber.Create(1))
  else
    Result.AddPair('schemaVersion', TJSONNumber.Create(3));
  Result.AddPair('id', AId);
  Result.AddPair('version', AVersion);
  Result.AddPair('manifest', AManifestName);
  LFiles := TJSONArray.Create;
  LFile := TJSONObject.Create;
  LFile.AddPair('path', AManifestName);
  LFile.AddPair('size', TJSONNumber.Create(AManifestSize));
  LFile.AddPair('sha256', AManifestHash);
  LFiles.AddElement(LFile);
  for LResource in AResources do
  begin
    LFile := TJSONObject.Create;
    LFile.AddPair('path', LResource.PackagePath);
    LFile.AddPair('size', TJSONNumber.Create(LResource.Size));
    LFile.AddPair('sha256', LResource.Hash);
    LFiles.AddElement(LFile);
  end;
  Result.AddPair('files', LFiles);
end;

class function TRadIAExtensionStudioPackager.ExportUnsigned(
  const AManifest: string;
  const AOutputFileName: string;
  const AResourcesPath: string
): string;
var
  LArchive: TZipFile;
  LId: string;
  LManifestBytes: TArray<Byte>;
  LManifestFileName: string;
  LManifestJson: TJSONObject;
  LMetadata: TJSONObject;
  LMetadataFileName: string;
  LResources: TArray<TRadIAResource>;
  LRoot: string;
  LVersion: string;
begin
  ValidateOutputFileName(AOutputFileName);
  LManifestJson := TJSONObject.ParseJSONValue(AManifest) as TJSONObject;
  if not Assigned(LManifestJson) then
    raise EArgumentException.Create('Manifest must be a JSON object.');
  try
    LId := LManifestJson.GetValue<string>('id', '');
    LVersion := LManifestJson.GetValue<string>('version', '');
  finally
    LManifestJson.Free;
  end;
  LManifestBytes := TEncoding.UTF8.GetBytes(AManifest);
  if Length(LManifestBytes) > 1024 * 1024 then
    raise EArgumentException.Create('Manifest exceeds the 1 MiB size limit.');
  Result := HashExtensionStudioBytes(LManifestBytes);
  LManifestFileName := LId + '.radia.json';
  LRoot := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-ExtensionStudio-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LRoot);
  try
    LResources := CollectResources(AResourcesPath, Length(LManifestBytes));
    TFile.WriteAllBytes(
      TPath.Combine(LRoot, LManifestFileName),
      LManifestBytes
    );
    LMetadata := CreateMetadata(
      LId,
      LVersion,
      LManifestFileName,
      Length(LManifestBytes),
      Result,
      LResources
    );
    try
      LMetadataFileName := TPath.Combine(LRoot, 'package.json');
      TFile.WriteAllText(
        LMetadataFileName,
        LMetadata.Format(2),
        TEncoding.UTF8
      );
    finally
      LMetadata.Free;
    end;
    try
      if TFile.Exists(AOutputFileName) then
        TFile.Delete(AOutputFileName);
      LArchive := TZipFile.Create;
      try
        LArchive.Open(AOutputFileName, zmWrite);
        LArchive.Add(LMetadataFileName, 'package.json');
        LArchive.Add(
          TPath.Combine(LRoot, LManifestFileName),
          LManifestFileName
        );
        AddResourcesToArchive(LArchive, LResources);
      finally
        LArchive.Free;
      end;
      TRadIADeclarativeExtensionPackageReader.Read(AOutputFileName);
    except
      if TFile.Exists(AOutputFileName) then
        TFile.Delete(AOutputFileName);
      raise;
    end;
  finally
    TDirectory.Delete(LRoot, True);
  end;
end;

class procedure TRadIAExtensionStudioPackager.ValidateOutputFileName(
  const AOutputFileName: string
);
begin
  if Trim(AOutputFileName) = '' then
    raise EArgumentException.Create('Package output file cannot be empty.');
  if not SameText(ExtractFileExt(AOutputFileName), '.radiaext') then
    raise EArgumentException.Create(
      'Package output file must use the .radiaext extension.'
    );
end;

{ TRadIAExtensionStudioSandbox }

class function TRadIAExtensionStudioSandbox.TestManifest(
  const AManifest: string;
  const AReservedCommands: TArray<string>;
  const AResourcesPath: string
): string;
var
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
  LExtensionId: string;
  LManager: TRadIADeclarativeExtensionManager;
  LMessage: string;
  LRoot: string;
  LPackageFileName: string;
begin
  LRoot := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-ExtensionSandbox-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LRoot);
  LManager := TRadIADeclarativeExtensionManager.Create(
    TPath.Combine(LRoot, 'installed')
  );
  try
    LPackageFileName := TPath.Combine(LRoot, 'draft.radiaext');
    TRadIAExtensionStudioPackager.ExportUnsigned(
      AManifest,
      LPackageFileName,
      AResourcesPath
    );
    if not TRadIADeclarativeExtensionPackageInstaller.Install(
      LPackageFileName,
      LManager,
      AReservedCommands,
      LExtensionId,
      LMessage
    ) then
      Exit(
        'Sandbox result: rejected' + sLineBreak +
        'Diagnostic: ' + LMessage
      );
    LDiagnostics := LManager.GetDiagnostics;
    Result :=
      'Sandbox result: activated' + sLineBreak +
      'Extension: ' + LExtensionId + sLineBreak +
      'Commands and journeys: ' +
      Length(LManager.GetCommands).ToString + sLineBreak +
      'Tool aliases: ' + Length(LManager.GetTools).ToString + sLineBreak +
      'Audited workflows: ' +
      Length(LManager.GetWorkflows).ToString + sLineBreak +
      'Diagnostics: ' + Length(LDiagnostics).ToString + sLineBreak +
      'Persistent changes: none';
  finally
    LManager.Free;
    TDirectory.Delete(LRoot, True);
  end;
end;

end.
