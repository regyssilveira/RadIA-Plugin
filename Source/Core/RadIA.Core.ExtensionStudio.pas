unit RadIA.Core.ExtensionStudio;

interface

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
    property Kind: TRadIAExtensionStudioKind read FKind;
    property ExtensionId: string read FExtensionId;
    property Version: string read FVersion;
    property Name: string read FName;
    property Description: string read FDescription;
    property TriggerOrTarget: string read FTriggerOrTarget;
    property Content: string read FContent;
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
    class procedure ValidateOutputFileName(
      const AOutputFileName: string
    ); static;
  public
    class function ExportUnsigned(
      const AManifest: string;
      const AOutputFileName: string
    ): string; static;
  end;

  TRadIAExtensionStudioSandbox = class
  public
    class function TestManifest(
      const AManifest: string;
      const AReservedCommands: TArray<string>
    ): string; static;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.RegularExpressions,
  System.SysUtils,
  System.Zip,
  RadIA.Core.DeclarativeExtensionPackages,
  RadIA.Core.DeclarativeExtensions;

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
        LCapability.AddPair('prompt', ADraft.Content);
      end;
    eskSkill:
      begin
        TJSONObject(ARoot).AddPair('skills', LArray);
        LCapability.AddPair('command', ADraft.TriggerOrTarget);
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
  if ADraft.Content = '' then
    raise EArgumentException.Create('Capability content cannot be empty.');
end;

{ TRadIAExtensionStudioPackager }

class function TRadIAExtensionStudioPackager.ExportUnsigned(
  const AManifest: string;
  const AOutputFileName: string
): string;
var
  LArchive: TZipFile;
  LFile: TJSONObject;
  LFiles: TJSONArray;
  LId: string;
  LManifestBytes: TArray<Byte>;
  LManifestFileName: string;
  LManifestJson: TJSONObject;
  LMetadata: TJSONObject;
  LMetadataFileName: string;
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
  Result := LowerCase(THashSHA2.GetHashString(AManifest));
  LManifestFileName := LId + '.radia.json';
  LRoot := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-ExtensionStudio-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LRoot);
  try
    TFile.WriteAllBytes(
      TPath.Combine(LRoot, LManifestFileName),
      LManifestBytes
    );
    LMetadata := TJSONObject.Create;
    try
      LMetadata.AddPair('schemaVersion', TJSONNumber.Create(1));
      LMetadata.AddPair('id', LId);
      LMetadata.AddPair('version', LVersion);
      LMetadata.AddPair('manifest', LManifestFileName);
      LFiles := TJSONArray.Create;
      LFile := TJSONObject.Create;
      LFile.AddPair('path', LManifestFileName);
      LFile.AddPair('size', TJSONNumber.Create(Length(LManifestBytes)));
      LFile.AddPair('sha256', Result);
      LFiles.AddElement(LFile);
      LMetadata.AddPair('files', LFiles);
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
  const AReservedCommands: TArray<string>
): string;
var
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
  LExtensionId: string;
  LManager: TRadIADeclarativeExtensionManager;
  LMessage: string;
  LRoot: string;
  LSourceFileName: string;
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
    LSourceFileName := TPath.Combine(LRoot, 'draft.radia.json');
    TFile.WriteAllText(LSourceFileName, AManifest, TEncoding.UTF8);
    if not LManager.InstallOrUpdate(
      LSourceFileName,
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
