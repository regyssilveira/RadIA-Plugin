unit RadIA.Core.WorkspaceTools;

interface

uses
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.Patches;

procedure RegisterRadIAWorkspaceTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAWorkspaceToolKind = (
    wtkGetIDEState,
    wtkGetActiveProject,
    wtkGetActiveUnit,
    wtkListOpenFiles,
    wtkListProjectUnits,
    wtkGetEditorContent,
    wtkSaveActiveFile,
    wtkGetEditorSelection,
    wtkGetCursorPosition,
    wtkGetCompilerMessages
  );

  TRadIAWorkspaceTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIAWorkspaceToolKind;
    FWorkspace: IRadIAWorkspaceFacade;
    function BuildDescriptor(
      const AName: string;
      const ADescription: string;
      const AInputSchema: string;
      const ARisk: TRadIAToolRisk = trReadOnly
    ): TRadIAToolDescriptor;
    function ExecuteGetIDEState: TRadIAToolResult;
    function ExecuteGetActiveProject: TRadIAToolResult;
    function ExecuteGetActiveUnit: TRadIAToolResult;
    function ExecuteListOpenFiles: TRadIAToolResult;
    function ExecuteListProjectUnits: TRadIAToolResult;
    function ExecuteGetEditorContent(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteSaveActiveFile: TRadIAToolResult;
    function ExecuteGetEditorSelection: TRadIAToolResult;
    function ExecuteGetCursorPosition: TRadIAToolResult;
    function ExecuteGetCompilerMessages(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetIntegerArgument(
      const AArgumentsJson: string;
      const AName: string;
      const ADefault: Integer;
      const AMinimum: Integer;
      const AMaximum: Integer
    ): Integer;
    function StringArrayToJson(
      const AValues: TArray<string>
    ): string;
    function GetDescriptor: TRadIAToolDescriptor;
  public
    constructor Create(
      const AKind: TRadIAWorkspaceToolKind;
      const AWorkspace: IRadIAWorkspaceFacade
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';
  CEditorInputSchema =
    '{"type":"object","properties":{"maxCharacters":{"type":"integer","minimum":1,' +
    '"maximum":1048576}},"additionalProperties":false}';
  CMessagesInputSchema =
    '{"type":"object","properties":{"maxCount":{"type":"integer","minimum":1,' +
    '"maximum":1000}},"additionalProperties":false}';

function SeverityToString(
  const ASeverity: TRadIACompilerMessageSeverity
): string;
begin
  case ASeverity of
    cmsInfo:
      Result := 'info';
    cmsWarning:
      Result := 'warning';
    cmsError:
      Result := 'error';
    cmsFatal:
      Result := 'fatal';
  else
    Result := 'info';
  end;
end;

procedure RegisterRadIAWorkspaceTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade
);
var
  LKind: TRadIAWorkspaceToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');

  for LKind := Low(TRadIAWorkspaceToolKind) to
    High(TRadIAWorkspaceToolKind) do
    ARegistry.RegisterTool(
      TRadIAWorkspaceTool.Create(LKind, AWorkspace)
    );
end;

{ TRadIAWorkspaceTool }

constructor TRadIAWorkspaceTool.Create(
  const AKind: TRadIAWorkspaceToolKind;
  const AWorkspace: IRadIAWorkspaceFacade
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  FKind := AKind;
  FWorkspace := AWorkspace;
end;

function TRadIAWorkspaceTool.BuildDescriptor(
  const AName: string;
  const ADescription: string;
  const AInputSchema: string;
  const ARisk: TRadIAToolRisk
): TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    AName,
    '1.0',
    ADescription,
    AInputSchema,
    CObjectOutputSchema,
    ARisk
  );
end;

function TRadIAWorkspaceTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  case FKind of
    wtkGetIDEState:
      Result := ExecuteGetIDEState;
    wtkGetActiveProject:
      Result := ExecuteGetActiveProject;
    wtkGetActiveUnit:
      Result := ExecuteGetActiveUnit;
    wtkListOpenFiles:
      Result := ExecuteListOpenFiles;
    wtkListProjectUnits:
      Result := ExecuteListProjectUnits;
    wtkGetEditorContent:
      Result := ExecuteGetEditorContent(ARequest);
    wtkSaveActiveFile:
      Result := ExecuteSaveActiveFile;
    wtkGetEditorSelection:
      Result := ExecuteGetEditorSelection;
    wtkGetCursorPosition:
      Result := ExecuteGetCursorPosition;
    wtkGetCompilerMessages:
      Result := ExecuteGetCompilerMessages(ARequest);
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Workspace tool kind is not supported.'
    );
  end;
end;

function TRadIAWorkspaceTool.ExecuteGetActiveProject:
  TRadIAToolResult;
var
  LJson: TJSONObject;
  LProject: TRadIAProjectSnapshot;
begin
  LProject := FWorkspace.GetActiveProject;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('name', LProject.Name);
    LJson.AddPair('fileName', LProject.FileName);
    LJson.AddPair('rootPath', LProject.RootPath);
    LJson.AddPair('configuration', LProject.Configuration);
    LJson.AddPair('platform', LProject.Platform);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAWorkspaceTool.ExecuteGetActiveUnit:
  TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('unitName', FWorkspace.GetActiveUnit);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAWorkspaceTool.ExecuteGetCompilerMessages(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LJson: TJSONObject;
  LMaxCount: Integer;
  LMessage: TRadIACompilerMessage;
  LMessages: TArray<TRadIACompilerMessage>;
  LRoot: TJSONObject;
begin
  LMaxCount := GetIntegerArgument(
    ARequest.ArgumentsJson,
    'maxCount',
    100,
    1,
    1000
  );
  LMessages := FWorkspace.GetCompilerMessages(LMaxCount);
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LRoot.AddPair('messages', LArray);
    for LMessage in LMessages do
    begin
      LJson := TJSONObject.Create;
      LJson.AddPair('severity', SeverityToString(LMessage.Severity));
      LJson.AddPair('text', LMessage.Text);
      LJson.AddPair('fileName', LMessage.FileName);
      LJson.AddPair('line', TJSONNumber.Create(LMessage.Line));
      LJson.AddPair('column', TJSONNumber.Create(LMessage.Column));
      LArray.AddElement(LJson);
    end;
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAWorkspaceTool.ExecuteGetCursorPosition:
  TRadIAToolResult;
var
  LJson: TJSONObject;
  LPosition: TRadIAEditorPosition;
begin
  LPosition := FWorkspace.GetCursorPosition;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('line', TJSONNumber.Create(LPosition.Line));
    LJson.AddPair('column', TJSONNumber.Create(LPosition.Column));
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAWorkspaceTool.ExecuteGetEditorContent(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LContent: TRadIAEditorContent;
  LJson: TJSONObject;
  LMaxCharacters: Integer;
begin
  LMaxCharacters := GetIntegerArgument(
    ARequest.ArgumentsJson,
    'maxCharacters',
    32768,
    1,
    1048576
  );
  LContent := FWorkspace.GetEditorContent(LMaxCharacters);
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('unitName', LContent.UnitName);
    LJson.AddPair('fileName', LContent.FileName);
    LJson.AddPair('content', LContent.Content);
    LJson.AddPair('revision', LContent.Revision);
    LJson.AddPair(
      'originalLength',
      TJSONNumber.Create(LContent.OriginalLength)
    );
    LJson.AddPair('truncated', TJSONBool.Create(LContent.Truncated));
    Result := TRadIAToolResult.Succeeded(
      LJson.ToJSON,
      LContent.Truncated
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAWorkspaceTool.ExecuteGetEditorSelection:
  TRadIAToolResult;
var
  LJson: TJSONObject;
  LSelection: TRadIAEditorSelection;
begin
  LSelection := FWorkspace.GetEditorSelection;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('content', LSelection.Content);
    LJson.AddPair('line', TJSONNumber.Create(LSelection.Line));
    LJson.AddPair('column', TJSONNumber.Create(LSelection.Column));
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAWorkspaceTool.ExecuteSaveActiveFile: TRadIAToolResult;
var
  LContent: TRadIAEditorContent;
  LJson: TJSONObject;
  LPersistence: IRadIAEditorPersistenceFacade;
begin
  if not Supports(FWorkspace, IRadIAEditorPersistenceFacade, LPersistence) then
    Exit(TRadIAToolResult.Failed(
      'editor_persistence_unavailable',
      'The active workspace cannot save editor files.'
    ));
  LContent := FWorkspace.GetEditorContent(1);
  if LContent.FileName = '' then
    Exit(TRadIAToolResult.Failed(
      'active_file_unavailable',
      'No active editor file is available to save.'
    ));
  if not LPersistence.SaveFile(LContent.FileName) then
    Exit(TRadIAToolResult.Failed(
      'editor_save_failed',
      'The Delphi IDE could not save the active editor file.'
    ));
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('fileName', LContent.FileName);
    LJson.AddPair('saved', TJSONBool.Create(True));
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAWorkspaceTool.ExecuteGetIDEState:
  TRadIAToolResult;
var
  LCapability: string;
  LCapabilities: TJSONArray;
  LJson: TJSONObject;
  LState: TRadIAIDEState;
begin
  LState := FWorkspace.GetIDEState;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('versionName', LState.VersionName);
    LJson.AddPair('platform', LState.Platform);
    LJson.AddPair(
      'shuttingDown',
      TJSONBool.Create(LState.ShuttingDown)
    );
    LCapabilities := TJSONArray.Create;
    LJson.AddPair('capabilities', LCapabilities);
    for LCapability in LState.Capabilities do
      LCapabilities.Add(LCapability);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAWorkspaceTool.ExecuteListOpenFiles:
  TRadIAToolResult;
begin
  Result := TRadIAToolResult.Succeeded(
    StringArrayToJson(FWorkspace.ListOpenFiles)
  );
end;

function TRadIAWorkspaceTool.ExecuteListProjectUnits:
  TRadIAToolResult;
begin
  Result := TRadIAToolResult.Succeeded(
    StringArrayToJson(FWorkspace.ListProjectUnits)
  );
end;

function TRadIAWorkspaceTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    wtkGetIDEState:
      Result := BuildDescriptor(
        'GetIDEState',
        'Returns the active Delphi IDE version and capabilities.',
        CEmptyInputSchema
      );
    wtkGetActiveProject:
      Result := BuildDescriptor(
        'GetActiveProject',
        'Returns metadata for the active Delphi project.',
        CEmptyInputSchema
      );
    wtkGetActiveUnit:
      Result := BuildDescriptor(
        'GetActiveUnit',
        'Returns the active Delphi unit name.',
        CEmptyInputSchema
      );
    wtkListOpenFiles:
      Result := BuildDescriptor(
        'ListOpenFiles',
        'Lists files currently open in the Delphi IDE.',
        CEmptyInputSchema
      );
    wtkListProjectUnits:
      Result := BuildDescriptor(
        'ListProjectUnits',
        'Lists units owned by the active Delphi project.',
        CEmptyInputSchema
      );
    wtkGetEditorContent:
      Result := BuildDescriptor(
        'GetEditorContent',
        'Returns the live active editor content with a revision.',
        CEditorInputSchema
      );
    wtkSaveActiveFile:
      Result := BuildDescriptor(
        'SaveActiveFile',
        'Saves the active Delphi editor buffer through the IDE.',
        CEmptyInputSchema,
        trReversibleWrite
      );
    wtkGetEditorSelection:
      Result := BuildDescriptor(
        'GetEditorSelection',
        'Returns the active editor selection and cursor position.',
        CEmptyInputSchema
      );
    wtkGetCursorPosition:
      Result := BuildDescriptor(
        'GetCursorPosition',
        'Returns the active editor cursor position.',
        CEmptyInputSchema
      );
    wtkGetCompilerMessages:
      Result := BuildDescriptor(
        'GetCompilerMessages',
        'Returns structured compiler messages from the IDE.',
        CMessagesInputSchema
      );
  else
    Result := Default(TRadIAToolDescriptor);
  end;
end;

function TRadIAWorkspaceTool.GetIntegerArgument(
  const AArgumentsJson: string;
  const AName: string;
  const ADefault: Integer;
  const AMinimum: Integer;
  const AMaximum: Integer
): Integer;
var
  LJson: TJSONValue;
  LNumber: TJSONNumber;
  LObject: TJSONObject;
  LValue: TJSONValue;
begin
  Result := ADefault;
  LJson := TJSONObject.ParseJSONValue(AArgumentsJson);
  try
    if not (LJson is TJSONObject) then
      raise EArgumentException.Create(
        'Tool arguments must be a JSON object.'
      );
    LObject := TJSONObject(LJson);
    LValue := LObject.GetValue(AName);
    if not Assigned(LValue) then
      Exit;
    if not (LValue is TJSONNumber) then
      raise EArgumentException.CreateFmt(
        'Argument "%s" must be an integer.',
        [AName]
      );

    LNumber := TJSONNumber(LValue);
    Result := LNumber.AsInt;
    if (Result < AMinimum) or (Result > AMaximum) then
      raise EArgumentOutOfRangeException.CreateFmt(
        'Argument "%s" must be between %d and %d.',
        [AName, AMinimum, AMaximum]
      );
  finally
    LJson.Free;
  end;
end;

function TRadIAWorkspaceTool.StringArrayToJson(
  const AValues: TArray<string>
): string;
var
  LArray: TJSONArray;
  LRoot: TJSONObject;
  LValue: string;
begin
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LRoot.AddPair('items', LArray);
    for LValue in AValues do
      LArray.Add(LValue);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

end.
