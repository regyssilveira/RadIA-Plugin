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
    function ApplyBreakpointAction(
      const AFileName: string;
      const ALineNumber: Integer;
      out AAction: string;
      out AError: TRadIAToolResult
    ): Boolean;
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

  TRadIADebuggerBreakpointCapabilitiesTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FDebugger: IRadIADebuggerBreakpointFacade;
  public
    constructor Create(const ADebugger: IRadIADebuggerBreakpointFacade);
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIAConfigureBreakpointTool = class(TInterfacedObject, IRadIATool)
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FDebugger: IRadIADebuggerBreakpointFacade;
    FWorkspace: IRadIAWorkspaceFacade;
    function ResolveFile(
      const AFileName: string;
      out AResolved: string;
      out AError: TRadIAToolResult
    ): Boolean;
  public
    constructor Create(
      const ADebugger: IRadIADebuggerBreakpointFacade;
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
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
  CConfigureInputSchema =
    '{"type":"object","required":["fileName","lineNumber"],' +
    '"properties":{"fileName":{"type":"string"},' +
    '"lineNumber":{"type":"integer","minimum":1},' +
    '"condition":{"type":"string","maxLength":4096},' +
    '"hitCount":{"type":"integer","minimum":0},' +
    '"break":{"type":"boolean"},' +
    '"logMessage":{"type":"string","maxLength":4096},' +
    '"evaluateExpression":{"type":"string","maxLength":4096},' +
    '"logResult":{"type":"boolean"},' +
    '"stackFrames":{"type":"integer","minimum":0,"maximum":100},' +
    '"threadCondition":{"type":"string","maxLength":256}},' +
    '"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

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
  ARegistry.RegisterTool(
    TRadIADebuggerBreakpointCapabilitiesTool.Create(ADebugger)
  );
  ARegistry.RegisterTool(
    TRadIAConfigureBreakpointTool.Create(
      ADebugger,
      AWorkspace,
      ABoundary
    )
  );
end;

function ConfigurationToJson(
  const AConfiguration: TRadIABreakpointConfiguration
): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('condition', AConfiguration.Condition);
  Result.AddPair('hitCount', TJSONNumber.Create(AConfiguration.HitCount));
  Result.AddPair('break', TJSONBool.Create(AConfiguration.DoBreak));
  Result.AddPair('logMessage', AConfiguration.LogMessage);
  Result.AddPair('evaluateExpression', AConfiguration.EvaluateExpression);
  Result.AddPair('logResult', TJSONBool.Create(AConfiguration.LogResult));
  Result.AddPair(
    'stackFrames',
    TJSONNumber.Create(AConfiguration.StackFramesToLog)
  );
  Result.AddPair('threadCondition', AConfiguration.ThreadCondition);
end;

procedure MergeConfiguration(
  const AArguments: TJSONObject;
  var AConfiguration: TRadIABreakpointConfiguration
);
begin
  if Assigned(AArguments.GetValue('condition')) then
    AConfiguration.Condition := AArguments.GetValue<string>('condition');
  if Assigned(AArguments.GetValue('hitCount')) then
    AConfiguration.HitCount := AArguments.GetValue<Integer>('hitCount');
  if Assigned(AArguments.GetValue('break')) then
    AConfiguration.DoBreak := AArguments.GetValue<Boolean>('break');
  if Assigned(AArguments.GetValue('logMessage')) then
    AConfiguration.LogMessage := AArguments.GetValue<string>('logMessage');
  if Assigned(AArguments.GetValue('evaluateExpression')) then
    AConfiguration.EvaluateExpression :=
      AArguments.GetValue<string>('evaluateExpression');
  if Assigned(AArguments.GetValue('logResult')) then
    AConfiguration.LogResult := AArguments.GetValue<Boolean>('logResult');
  if Assigned(AArguments.GetValue('stackFrames')) then
    AConfiguration.StackFramesToLog :=
      AArguments.GetValue<Integer>('stackFrames');
  if Assigned(AArguments.GetValue('threadCondition')) then
    AConfiguration.ThreadCondition :=
      AArguments.GetValue<string>('threadCondition');
end;

function ConfigurationIsValid(
  const AConfiguration: TRadIABreakpointConfiguration;
  out AError: string
): Boolean;
begin
  Result := False;
  if (AConfiguration.HitCount < 0) or
    (AConfiguration.StackFramesToLog < 0) or
    (AConfiguration.StackFramesToLog > 100) then
  begin
    AError := 'Hit count and stack frame limits are outside the supported range.';
    Exit;
  end;
  if (Length(AConfiguration.Condition) > 4096) or
    (Length(AConfiguration.LogMessage) > 4096) or
    (Length(AConfiguration.EvaluateExpression) > 4096) or
    (Length(AConfiguration.ThreadCondition) > 256) then
  begin
    AError := 'A breakpoint text field exceeds its bounded limit.';
    Exit;
  end;
  Result := True;
end;

{ TRadIADebuggerBreakpointCapabilitiesTool }

constructor TRadIADebuggerBreakpointCapabilitiesTool.Create(
  const ADebugger: IRadIADebuggerBreakpointFacade
);
begin
  inherited Create;
  if not Assigned(ADebugger) then
    raise EArgumentNilException.Create('ADebugger');
  FDebugger := ADebugger;
end;

function TRadIADebuggerBreakpointCapabilitiesTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCapabilities: TRadIADebuggerBreakpointCapabilities;
  LRoot: TJSONObject;
  LTargets: TJSONArray;
begin
  LCapabilities := FDebugger.GetBreakpointCapabilities;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('available', TJSONBool.Create(LCapabilities.Available));
    LRoot.AddPair('condition', TJSONBool.Create(LCapabilities.Condition));
    LRoot.AddPair('hitCount', TJSONBool.Create(LCapabilities.HitCount));
    LRoot.AddPair('logpoint', TJSONBool.Create(LCapabilities.Logpoint));
    LRoot.AddPair('stackFrames', TJSONBool.Create(LCapabilities.StackFrames));
    LRoot.AddPair(
      'threadCondition',
      TJSONBool.Create(LCapabilities.ThreadCondition)
    );
    LRoot.AddPair(
      'exceptionFilters',
      TJSONBool.Create(LCapabilities.ExceptionFilters)
    );
    LRoot.AddPair(
      'exceptionFilterStatus',
      'Unavailable: Delphi OTA does not expose a reliable global exception filter API.'
    );
    LTargets := TJSONArray.Create;
    LTargets.Add('23.0');
    LTargets.Add('37.0');
    LRoot.AddPair('verifiedDelphiTargets', LTargets);
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIADebuggerBreakpointCapabilitiesTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetAdvancedBreakpointCapabilities',
    '1.0.0',
    'Reports reliable advanced breakpoint capabilities for Delphi 12 and 13.',
    '{"type":"object","additionalProperties":false}',
    CObjectOutputSchema,
    trReadOnly
  );
end;

{ TRadIAConfigureBreakpointTool }

constructor TRadIAConfigureBreakpointTool.Create(
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
  FDebugger := ADebugger;
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
end;

function TRadIAConfigureBreakpointTool.ResolveFile(
  const AFileName: string;
  out AResolved: string;
  out AError: TRadIAToolResult
): Boolean;
var
  LProject: TRadIAProjectSnapshot;
  LValidation: TRadIAPathValidation;
begin
  LProject := FWorkspace.GetActiveProject;
  LValidation := FBoundary.ValidatePath(LProject.RootPath, AFileName);
  Result := LValidation.Allowed;
  if Result then
    AResolved := LValidation.ResolvedPath
  else
    AError := TRadIAToolResult.Failed(
      LValidation.ErrorCode,
      LValidation.ErrorMessage
    );
end;

function TRadIAConfigureBreakpointTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArguments: TJSONObject;
  LConfiguration: TRadIABreakpointConfiguration;
  LError: string;
  LFileName: string;
  LLineNumber: Integer;
  LInverseArguments: TJSONObject;
  LPrevious: TRadIABreakpointConfiguration;
  LResolvedFile: string;
  LResultError: TRadIAToolResult;
  LRoot: TJSONObject;
begin
  LArguments := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LArguments) then
    Exit(TRadIAToolResult.Failed('invalid_request', 'Arguments must be a JSON object.'));
  try
    LFileName := LArguments.GetValue<string>('fileName', '');
    LLineNumber := LArguments.GetValue<Integer>('lineNumber', 0);
    if (LLineNumber < 1) or not ResolveFile(
      LFileName,
      LResolvedFile,
      LResultError
    ) then
    begin
      if LLineNumber < 1 then
        Exit(TRadIAToolResult.Failed('invalid_request', 'A positive line is required.'));
      Exit(LResultError);
    end;
    LFileName := LResolvedFile;
    if not FDebugger.GetSourceBreakpointConfiguration(
      LFileName,
      LLineNumber,
      LConfiguration,
      LError
    ) then
      Exit(TRadIAToolResult.Failed('breakpoint_not_found', LError));
    MergeConfiguration(LArguments, LConfiguration);
    if not ConfigurationIsValid(LConfiguration, LError) then
      Exit(TRadIAToolResult.Failed('invalid_breakpoint_configuration', LError));
    if not FDebugger.ConfigureSourceBreakpoint(
      LFileName,
      LLineNumber,
      LConfiguration,
      LPrevious,
      LError
    ) then
      Exit(TRadIAToolResult.Failed('breakpoint_configuration_failed', LError));
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('action', 'configured');
      LRoot.AddPair('fileName', LFileName);
      LRoot.AddPair('lineNumber', TJSONNumber.Create(LLineNumber));
      LRoot.AddPair('configuration', ConfigurationToJson(LConfiguration));
      LRoot.AddPair('previousConfiguration', ConfigurationToJson(LPrevious));
      LRoot.AddPair('inverseTool', 'ConfigureBreakpoint');
      LInverseArguments := ConfigurationToJson(LPrevious);
      LInverseArguments.AddPair('fileName', LFileName);
      LInverseArguments.AddPair(
        'lineNumber',
        TJSONNumber.Create(LLineNumber)
      );
      LRoot.AddPair('inverseArguments', LInverseArguments);
      Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
    finally
      LRoot.Free;
    end;
  finally
    LArguments.Free;
  end;
end;

function TRadIAConfigureBreakpointTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ConfigureBreakpoint',
    '1.0.0',
    'Configures a conditional breakpoint, hit count, logpoint, or thread filter.',
    CConfigureInputSchema,
    CObjectOutputSchema,
    trReversibleWrite
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

function TRadIADebuggerBreakpointTool.ApplyBreakpointAction(
  const AFileName: string;
  const ALineNumber: Integer;
  out AAction: string;
  out AError: TRadIAToolResult
): Boolean;
begin
  Result := False;
  case FKind of
    dbptkAdd:
    begin
      if FDebugger.HasSourceBreakpoint(AFileName, ALineNumber) then
      begin
        AError := TRadIAToolResult.Failed(
          'breakpoint_exists',
          'A source breakpoint already exists at this location.'
        );
        Exit;
      end;
      if not FDebugger.AddSourceBreakpoint(AFileName, ALineNumber) then
      begin
        AError := TRadIAToolResult.Failed(
          'breakpoint_add_failed',
          'The IDE rejected the source breakpoint.'
        );
        Exit;
      end;
      AAction := 'added';
    end;
    dbptkRemove:
    begin
      if not FDebugger.HasSourceBreakpoint(AFileName, ALineNumber) then
      begin
        AError := TRadIAToolResult.Failed(
          'breakpoint_not_found',
          'No source breakpoint exists at this location.'
        );
        Exit;
      end;
      if not FDebugger.RemoveSourceBreakpoint(AFileName, ALineNumber) then
      begin
        AError := TRadIAToolResult.Failed(
          'breakpoint_remove_failed',
          'The IDE rejected removal of the source breakpoint.'
        );
        Exit;
      end;
      AAction := 'removed';
    end;
  else
    AError := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Debugger breakpoint tool kind is not supported.'
    );
    Exit;
  end;
  Result := True;
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
  LToolError: TRadIAToolResult;
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

  if not ApplyBreakpointAction(
    LFileName,
    LLineNumber,
    LAction,
    LToolError
  ) then
    Exit(LToolError);

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
