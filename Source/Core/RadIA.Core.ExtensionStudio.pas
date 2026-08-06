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
  end;

implementation

uses
  System.JSON,
  System.RegularExpressions,
  System.SysUtils;

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

end.
