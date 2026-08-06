unit RadIA.Core.RuntimeDebugTools;

interface

uses
  RadIA.Core.Debugger,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.Tools;

procedure RegisterRadIARuntimeDebugTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const ADebugger: IRadIADebuggerFacade
);

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.RuntimeAutomation;

type
  IRadIARuntimeDebugToolService = interface
    ['{856FC4E1-E4C7-4865-9184-0F77A95F38C4}']
    function CancelWait: Boolean;
    function GetSessionResult: TRadIAToolResult;
    function WaitForEvent(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

  TRadIARuntimeDebugToolService = class(
    TInterfacedObject,
    IRadIARuntimeDebugToolService
  )
  private
    FActiveWait: IRadIARuntimeDebugWait;
    FCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FDebugger: IRadIADebuggerFacade;
    FLock: TObject;
    function BuildWaitResult(
      const AResult: TRadIARuntimeDebugWaitResult
    ): TRadIAToolResult;
    function ParseKinds(
      const AJson: TJSONObject;
      out AKinds: TRadIARuntimeDebugEventKinds
    ): Boolean;
  public
    constructor Create(
      const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
      const ADebugger: IRadIADebuggerFacade
    );
    destructor Destroy; override;
    function CancelWait: Boolean;
    function GetSessionResult: TRadIAToolResult;
    function WaitForEvent(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  end;

  TRadIARuntimeDebugToolKind = (
    rdtkGetSession,
    rdtkWaitForEvent,
    rdtkCancelWait
  );

  TRadIARuntimeDebugTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIARuntimeDebugToolKind;
    FService: IRadIARuntimeDebugToolService;
  public
    constructor Create(
      const AKind: TRadIARuntimeDebugToolKind;
      const AService: IRadIARuntimeDebugToolService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CWaitInputSchema =
    '{"type":"object","required":["kinds"],"properties":{' +
    '"sessionId":{"type":"string"},' +
    '"sinceSequence":{"type":"integer","minimum":0},' +
    '"timeoutMs":{"type":"integer","minimum":1,"maximum":300000},' +
    '"kinds":{"type":"array","minItems":1,"uniqueItems":true,' +
    '"items":{"enum":["running","stopped","exception","processExited",' +
    '"windowAvailable"]}}},"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

function AddKindByName(
  const AName: string;
  var AKinds: TRadIARuntimeDebugEventKinds
): Boolean;
begin
  Result := True;
  if SameText(AName, 'running') then
    Include(AKinds, rdekRunning)
  else if SameText(AName, 'stopped') then
    Include(AKinds, rdekStopped)
  else if SameText(AName, 'exception') then
    Include(AKinds, rdekException)
  else if SameText(AName, 'processExited') then
    Include(AKinds, rdekProcessExited)
  else if SameText(AName, 'windowAvailable') then
    Include(AKinds, rdekWindowAvailable)
  else
    Result := False;
end;

procedure AddCallStack(
  const ADebugger: IRadIADebuggerFacade;
  const ARoot: TJSONObject
);
var
  LArray: TJSONArray;
  LFrame: TRadIACallStackFrame;
  LItem: TJSONObject;
  LStack: TRadIACallStackSnapshot;
begin
  LStack := ADebugger.GetCallStack(100);
  ARoot.AddPair('stackAccessible', TJSONBool.Create(LStack.Accessible));
  ARoot.AddPair('stackStatus', LStack.Status);
  LArray := TJSONArray.Create;
  ARoot.AddPair('frames', LArray);
  for LFrame in LStack.Frames do
  begin
    LItem := TJSONObject.Create;
    LItem.AddPair('index', TJSONNumber.Create(LFrame.Index));
    LItem.AddPair('header', LFrame.Header);
    LItem.AddPair('fileName', LFrame.FileName);
    LItem.AddPair('lineNumber', TJSONNumber.Create(LFrame.LineNumber));
    LArray.AddElement(LItem);
  end;
end;

function WaitReasonName(
  const AReason: TRadIARuntimeDebugWaitReason
): string;
begin
  case AReason of
    rdwrMatched: Result := 'matched';
    rdwrTimeout: Result := 'timeout';
    rdwrCancelled: Result := 'cancelled';
  else
    Result := 'sessionChanged';
  end;
end;

{ TRadIARuntimeDebugToolService }

function TRadIARuntimeDebugToolService.BuildWaitResult(
  const AResult: TRadIARuntimeDebugWaitResult
): TRadIAToolResult;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('reason', WaitReasonName(AResult.Reason));
    if AResult.Reason = rdwrMatched then
    begin
      LRoot.AddPair(
        'sequence',
        TJSONNumber.Create(AResult.Event.Sequence)
      );
      LRoot.AddPair('sessionId', AResult.Event.SessionId);
      LRoot.AddPair(
        'processId',
        TJSONNumber.Create(AResult.Event.ProcessId)
      );
      LRoot.AddPair(
        'kind',
        RadIARuntimeDebugEventKindName(AResult.Event.Kind)
      );
      LRoot.AddPair('state', AResult.Event.State);
      LRoot.AddPair('details', AResult.Event.Details);
      LRoot.AddPair(
        'timestampUtc',
        DateToISO8601(AResult.Event.TimestampUtc, True)
      );
      if AResult.Event.Kind in [rdekStopped, rdekException] then
        AddCallStack(FDebugger, LRoot);
    end;
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimeDebugToolService.CancelWait: Boolean;
var
  LWait: IRadIARuntimeDebugWait;
begin
  TMonitor.Enter(FLock);
  try
    LWait := FActiveWait;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := Assigned(LWait);
  if Result then
    LWait.Cancel;
end;

constructor TRadIARuntimeDebugToolService.Create(
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const ADebugger: IRadIADebuggerFacade
);
begin
  inherited Create;
  if not Assigned(ACoordinator) then
    raise EArgumentNilException.Create('ACoordinator');
  if not Assigned(ADebugger) then
    raise EArgumentNilException.Create('ADebugger');
  FCoordinator := ACoordinator;
  FDebugger := ADebugger;
  FLock := TObject.Create;
end;

destructor TRadIARuntimeDebugToolService.Destroy;
begin
  CancelWait;
  FLock.Free;
  inherited Destroy;
end;

function TRadIARuntimeDebugToolService.GetSessionResult:
  TRadIAToolResult;
var
  LRoot: TJSONObject;
  LSession: TRadIARuntimeSessionIdentity;
begin
  LSession := FCoordinator.GetCurrentSession;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('complete', TJSONBool.Create(LSession.IsComplete));
    LRoot.AddPair('sessionId', LSession.SessionId);
    LRoot.AddPair(
      'processId',
      TJSONNumber.Create(LSession.ProcessId)
    );
    LRoot.AddPair('executablePath', LSession.ExecutablePath);
    LRoot.AddPair('projectPath', LSession.ProjectPath);
    LRoot.AddPair('buildId', LSession.BuildId);
    LRoot.AddPair(
      'createdAtUtc',
      DateToISO8601(LSession.CreatedAtUtc, True)
    );
    LRoot.AddPair(
      'lastSequence',
      TJSONNumber.Create(FCoordinator.GetLastSequence)
    );
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimeDebugToolService.ParseKinds(
  const AJson: TJSONObject;
  out AKinds: TRadIARuntimeDebugEventKinds
): Boolean;
var
  LArray: TJSONArray;
  LItem: TJSONValue;
begin
  AKinds := [];
  LArray := AJson.GetValue<TJSONArray>('kinds');
  Result := Assigned(LArray) and (LArray.Count > 0);
  if not Result then
    Exit;
  for LItem in LArray do
    if not AddKindByName(LItem.Value, AKinds) then
      Exit(False);
end;

function TRadIARuntimeDebugToolService.WaitForEvent(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCancellationNotifier: IRadIAToolCancellationNotifier;
  LFilter: TRadIARuntimeDebugWaitFilter;
  LJson: TJSONObject;
  LKinds: TRadIARuntimeDebugEventKinds;
  LSession: TRadIARuntimeSessionIdentity;
  LSessionId: string;
  LWait: IRadIARuntimeDebugWait;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Runtime debug wait arguments must be a JSON object.'
    ));
  try
    LSession := FCoordinator.GetCurrentSession;
    LSessionId := LJson.GetValue<string>(
      'sessionId',
      LSession.SessionId
    );
    if not LSession.IsComplete or
      not SameText(LSessionId, LSession.SessionId) then
      Exit(TRadIAToolResult.Failed(
        'runtime_session_unavailable',
        'The requested runtime debug session is not active.'
      ));
    if not ParseKinds(LJson, LKinds) then
      Exit(TRadIAToolResult.Failed(
        'invalid_event_kinds',
        'At least one supported debugger event kind is required.'
      ));
    LFilter := TRadIARuntimeDebugWaitFilter.Create(
      LSessionId,
      LSession.ProcessId,
      LJson.GetValue<Int64>('sinceSequence', 0),
      LKinds,
      LJson.GetValue<Cardinal>('timeoutMs', 30000)
    );
    if not LFilter.IsValid then
      Exit(TRadIAToolResult.Failed(
        'invalid_wait_filter',
        'Runtime debug wait limits are invalid.'
      ));
    LWait := FCoordinator.CreateWait(LFilter);
    TMonitor.Enter(FLock);
    try
      if Assigned(FActiveWait) then
        Exit(TRadIAToolResult.Failed(
          'debug_wait_active',
          'Another debugger wait is already active.'
        ));
      FActiveWait := LWait;
    finally
      TMonitor.Exit(FLock);
    end;
    try
      if Supports(
        ARequest.CancellationToken,
        IRadIAToolCancellationNotifier,
        LCancellationNotifier
      ) then
        LCancellationNotifier.SetCancellationCallback(
          procedure
          begin
            LWait.Cancel;
          end
        )
      else if Assigned(ARequest.CancellationToken) and
        ARequest.CancellationToken.CancellationRequested then
        LWait.Cancel;
      Result := BuildWaitResult(LWait.Wait);
    finally
      if Assigned(LCancellationNotifier) then
        LCancellationNotifier.ClearCancellationCallback;
      TMonitor.Enter(FLock);
      try
        FActiveWait := nil;
      finally
        TMonitor.Exit(FLock);
      end;
    end;
  finally
    LJson.Free;
  end;
end;

{ TRadIARuntimeDebugTool }

constructor TRadIARuntimeDebugTool.Create(
  const AKind: TRadIARuntimeDebugToolKind;
  const AService: IRadIARuntimeDebugToolService
);
begin
  inherited Create;
  FKind := AKind;
  FService := AService;
end;

function TRadIARuntimeDebugTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCancelled: Boolean;
  LRoot: TJSONObject;
begin
  case FKind of
    rdtkGetSession:
      Result := FService.GetSessionResult;
    rdtkWaitForEvent:
      Result := FService.WaitForEvent(ARequest);
    rdtkCancelWait:
    begin
      LCancelled := FService.CancelWait;
      LRoot := TJSONObject.Create;
      try
        LRoot.AddPair('cancelled', TJSONBool.Create(LCancelled));
        Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
      finally
        LRoot.Free;
      end;
    end;
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_tool',
      'Runtime debugger tool kind is unsupported.'
    );
  end;
end;

function TRadIARuntimeDebugTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    rdtkGetSession:
      Result := TRadIAToolDescriptor.Create(
        'GetRuntimeDebugSession',
        '1.0.0',
        'Return the correlated project, build, and debug process identity.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    rdtkWaitForEvent:
      Result := TRadIAToolDescriptor.Create(
        'WaitForDebuggerEvent',
        '1.0.0',
        'Wait for a correlated debugger event and capture its call stack.',
        CWaitInputSchema,
        CObjectOutputSchema,
        trReadOnly
      ).WithExecutionOptions(305000, True);
    rdtkCancelWait:
      Result := TRadIAToolDescriptor.Create(
        'CancelDebuggerWait',
        '1.0.0',
        'Cancel the active debugger event wait immediately.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trExecution
      ).WithExecutionOptions(5000, True);
  end;
end;

procedure RegisterRadIARuntimeDebugTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const ADebugger: IRadIADebuggerFacade
);
var
  LKind: TRadIARuntimeDebugToolKind;
  LService: IRadIARuntimeDebugToolService;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  LService := TRadIARuntimeDebugToolService.Create(
    ACoordinator,
    ADebugger
  );
  for LKind := Low(TRadIARuntimeDebugToolKind) to
    High(TRadIARuntimeDebugToolKind) do
    ARegistry.RegisterTool(TRadIARuntimeDebugTool.Create(LKind, LService));
end;

end.
