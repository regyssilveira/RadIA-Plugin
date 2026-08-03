unit RadIA.Core.DebuggerBreakpointTools;

interface

uses
  RadIA.Core.Debugger,
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

procedure RegisterRadIADebuggerBreakpointTools(
  const ARegistry: IRadIAToolRegistry;
  const ADebugger: IRadIADebuggerBreakpointFacade;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils;

type
  TRadIADebuggerBreakpointToolKind = (
    dbptkAdd,
    dbptkRemove
  );

  TRadIADebuggerBreakpointTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FDebugger: IRadIADebuggerBreakpointFacade;
    FKind: TRadIADebuggerBreakpointToolKind;
    FWorkspace: IRadIAWorkspaceFacade;
    function GetDescriptor: TRadIAToolDescriptor;
    function IsSupportedSourceFile(
      const AFileName: string
    ): Boolean;
  public
    constructor Create(
      const AKind: TRadIADebuggerBreakpointToolKind;
      const ADebugger: IRadIADebuggerBreakpointFacade;
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

const
  CInputSchema =
    '{"type":"object","required":["fileName","lineNumber"],' +
    '"properties":{"fileName":{"type":"string"},' +
    '"lineNumber":{"type":"integer","minimum":1,"maximum":2147483647}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["action","fileName","lineNumber"],' +
    '"properties":{"action":{"type":"string"},"fileName":{"type":"string"},' +
    '"lineNumber":{"type":"integer"},"inverseTool":{"type":"string"}}}';

procedure RegisterRadIADebuggerBreakpointTools(
  const ARegistry: IRadIAToolRegistry;
  const ADebugger: IRadIADebuggerBreakpointFacade;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);
var
  LKind: TRadIADebuggerBreakpointToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(ADebugger) then
    raise EArgumentNilException.Create('ADebugger');
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');

  for LKind := Low(TRadIADebuggerBreakpointToolKind) to
    High(TRadIADebuggerBreakpointToolKind) do
    ARegistry.RegisterTool(
      TRadIADebuggerBreakpointTool.Create(
        LKind,
        ADebugger,
        AWorkspace,
        ABoundary
      )
    );
end;

{ TRadIADebuggerBreakpointTool }

constructor TRadIADebuggerBreakpointTool.Create(
  const AKind: TRadIADebuggerBreakpointToolKind;
  const ADebugger: IRadIADebuggerBreakpointFacade;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);
begin
  inherited Create;
  if not Assigned(ADebugger) then
    raise EArgumentNilException.Create('ADebugger');
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  FKind := AKind;
  FDebugger := ADebugger;
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
end;

function TRadIADebuggerBreakpointTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LAction: string;
  LFileName: string;
  LJson: TJSONObject;
  LLineNumber: Integer;
  LProject: TRadIAProjectSnapshot;
  LResultJson: TJSONObject;
  LValidation: TRadIAPathValidation;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Breakpoint arguments must be a JSON object.'
    ));
  try
    LFileName := LJson.GetValue<string>('fileName', '');
    LLineNumber := LJson.GetValue<Integer>('lineNumber', 0);
  finally
    LJson.Free;
  end;
  if Trim(LFileName) = '' then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Breakpoint file name must not be empty.'
    ));
  if LLineNumber <= 0 then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Breakpoint line number must be greater than zero.'
    ));

  LProject := FWorkspace.GetActiveProject;
  LValidation := FBoundary.ValidatePath(
    LProject.RootPath,
    LFileName
  );
  if not LValidation.Allowed then
    Exit(TRadIAToolResult.Failed(
      LValidation.ErrorCode,
      LValidation.ErrorMessage
    ));
  LFileName := LValidation.ResolvedPath;
  if not IsSupportedSourceFile(LFileName) then
    Exit(TRadIAToolResult.Failed(
      'unsupported_source_file',
      'Breakpoints are limited to Pascal source files.'
    ));

  case FKind of
    dbptkAdd:
    begin
      if FDebugger.HasSourceBreakpoint(
        LFileName,
        LLineNumber
      ) then
        Exit(TRadIAToolResult.Failed(
          'breakpoint_exists',
          'A source breakpoint already exists at this location.'
        ));
      if not FDebugger.AddSourceBreakpoint(
        LFileName,
        LLineNumber
      ) then
        Exit(TRadIAToolResult.Failed(
          'breakpoint_add_failed',
          'The IDE rejected the source breakpoint.'
        ));
      LAction := 'added';
    end;
    dbptkRemove:
    begin
      if not FDebugger.HasSourceBreakpoint(
        LFileName,
        LLineNumber
      ) then
        Exit(TRadIAToolResult.Failed(
          'breakpoint_not_found',
          'No source breakpoint exists at this location.'
        ));
      if not FDebugger.RemoveSourceBreakpoint(
        LFileName,
        LLineNumber
      ) then
        Exit(TRadIAToolResult.Failed(
          'breakpoint_remove_failed',
          'The IDE rejected removal of the source breakpoint.'
        ));
      LAction := 'removed';
    end;
  else
    Exit(TRadIAToolResult.Failed(
      'unsupported_tool',
      'Debugger breakpoint tool kind is not supported.'
    ));
  end;

  LResultJson := TJSONObject.Create;
  try
    LResultJson.AddPair('action', LAction);
    LResultJson.AddPair('fileName', LFileName);
    LResultJson.AddPair(
      'lineNumber',
      TJSONNumber.Create(LLineNumber)
    );
    if FKind = dbptkAdd then
      LResultJson.AddPair('inverseTool', 'RemoveBreakpoint')
    else
      LResultJson.AddPair('inverseTool', 'AddBreakpoint');
    Result := TRadIAToolResult.Succeeded(LResultJson.ToJSON);
  finally
    LResultJson.Free;
  end;
end;

function TRadIADebuggerBreakpointTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  if FKind = dbptkAdd then
    Result := TRadIAToolDescriptor.Create(
      'AddBreakpoint',
      '1.0',
      'Adds a reviewed source breakpoint inside the active workspace.',
      CInputSchema,
      COutputSchema,
      trReversibleWrite
    )
  else
    Result := TRadIAToolDescriptor.Create(
      'RemoveBreakpoint',
      '1.0',
      'Removes an existing source breakpoint after explicit confirmation.',
      CInputSchema,
      COutputSchema,
      trDestructive
    );
end;

function TRadIADebuggerBreakpointTool.IsSupportedSourceFile(
  const AFileName: string
): Boolean;
var
  LExtension: string;
begin
  LExtension := LowerCase(TPath.GetExtension(AFileName));
  Result := (LExtension = '.pas') or
    (LExtension = '.dpr') or
    (LExtension = '.dpk') or
    (LExtension = '.inc');
end;

end.
