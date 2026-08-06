unit RadIA.Tests.RuntimeDebugTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Debugger,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.Tools;

type
  TRadIAFakeRuntimeDebugger = class(
    TInterfacedObject,
    IRadIADebuggerFacade
  )
  public
    function GetDebuggerState: TRadIADebuggerSnapshot;
    function ListBreakpoints(
      const AMaxCount: Integer
    ): TArray<TRadIABreakpointSnapshot>;
    function GetCallStack(
      const AMaxCount: Integer
    ): TRadIACallStackSnapshot;
  end;

  [TestFixture]
  TTestRadIARuntimeDebugTools = class
  private
    FCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FRegistry: IRadIAToolRegistry;
    FSessionId: string;
    function ExecuteTool(
      const AName: string;
      const AArguments: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure RegistersRuntimeDebugTools;
    [Test]
    procedure ReturnsCorrelatedSession;
    [Test]
    procedure WaitReturnsExceptionAndCallStack;
    [Test]
    procedure CancelReportsNoActiveWait;
    [Test]
    procedure CancellationTokenInterruptsWait;
  end;

implementation

uses
  System.Classes,
  System.SyncObjs,
  System.SysUtils,
  RadIA.Core.RuntimeDebugTools,
  RadIA.Core.ToolRegistry;

type
  TRadIATestCancellationToken = class(
    TInterfacedObject,
    IRadIAToolCancellationToken,
    IRadIAToolCancellationNotifier
  )
  private
    FCallback: TRadIAToolCancellationCallback;
    FCancelled: Boolean;
  public
    procedure Cancel;
    procedure ClearCancellationCallback;
    function GetCancellationRequested: Boolean;
    procedure SetCancellationCallback(
      const ACallback: TRadIAToolCancellationCallback
    );
  end;

  TRadIAToolExecutionThread = class(TThread)
  private
    FCompleted: TEvent;
    FRequest: TRadIAToolRequest;
    FResult: TRadIAToolResult;
    FTool: IRadIATool;
  protected
    procedure Execute; override;
  public
    constructor Create(
      const ATool: IRadIATool;
      const ARequest: TRadIAToolRequest
    );
    destructor Destroy; override;
    function AwaitCompletion: Boolean;
    property ToolResult: TRadIAToolResult read FResult;
  end;

{ TRadIATestCancellationToken }

procedure TRadIATestCancellationToken.Cancel;
var
  LCallback: TRadIAToolCancellationCallback;
begin
  TMonitor.Enter(Self);
  try
    FCancelled := True;
    LCallback := FCallback;
  finally
    TMonitor.Exit(Self);
  end;
  if Assigned(LCallback) then
    LCallback();
end;

procedure TRadIATestCancellationToken.ClearCancellationCallback;
begin
  TMonitor.Enter(Self);
  try
    FCallback := nil;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TRadIATestCancellationToken.GetCancellationRequested: Boolean;
begin
  TMonitor.Enter(Self);
  try
    Result := FCancelled;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIATestCancellationToken.SetCancellationCallback(
  const ACallback: TRadIAToolCancellationCallback
);
begin
  TMonitor.Enter(Self);
  try
    FCallback := ACallback;
  finally
    TMonitor.Exit(Self);
  end;
end;

{ TRadIAToolExecutionThread }

function TRadIAToolExecutionThread.AwaitCompletion: Boolean;
begin
  Result := FCompleted.WaitFor(3000) = wrSignaled;
end;

constructor TRadIAToolExecutionThread.Create(
  const ATool: IRadIATool;
  const ARequest: TRadIAToolRequest
);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FTool := ATool;
  FRequest := ARequest;
  FCompleted := TEvent.Create(nil, True, False, '');
end;

destructor TRadIAToolExecutionThread.Destroy;
begin
  FCompleted.Free;
  inherited Destroy;
end;

procedure TRadIAToolExecutionThread.Execute;
begin
  FResult := FTool.Execute(FRequest);
  FCompleted.SetEvent;
end;

{ TRadIAFakeRuntimeDebugger }

function TRadIAFakeRuntimeDebugger.GetCallStack(
  const AMaxCount: Integer
): TRadIACallStackSnapshot;
var
  LFrames: TArray<TRadIACallStackFrame>;
begin
  SetLength(LFrames, 1);
  LFrames[0] := TRadIACallStackFrame.Create(
    1,
    'TriggerDeterministicAccessViolation',
    'RadIA.RuntimeLab.TargetForm.pas',
    52
  );
  Result := TRadIACallStackSnapshot.Create(
    True,
    'accessible',
    LFrames
  );
end;

function TRadIAFakeRuntimeDebugger.GetDebuggerState:
  TRadIADebuggerSnapshot;
begin
  Result := TRadIADebuggerSnapshot.Create(
    True,
    'exception',
    1,
    'RadIARuntimeLab.exe',
    1,
    0
  );
end;

function TRadIAFakeRuntimeDebugger.ListBreakpoints(
  const AMaxCount: Integer
): TArray<TRadIABreakpointSnapshot>;
begin
  Result := nil;
end;

{ TTestRadIARuntimeDebugTools }

procedure TTestRadIARuntimeDebugTools.CancelReportsNoActiveWait;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('CancelDebuggerWait', '{}');

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"cancelled":false');
end;

procedure TTestRadIARuntimeDebugTools.CancellationTokenInterruptsWait;
var
  LCancellation: TRadIATestCancellationToken;
  LCancellationInterface: IRadIAToolCancellationToken;
  LRequest: TRadIAToolRequest;
  LThread: TRadIAToolExecutionThread;
begin
  LCancellation := TRadIATestCancellationToken.Create;
  LCancellationInterface :=
    LCancellation as IRadIAToolCancellationToken;
  LRequest := TRadIAToolRequest.Create(
    'WaitForDebuggerEvent',
    '{"timeoutMs":3000,"kinds":["exception"]}',
    'runtime-cancel-test'
  ).WithCancellation(LCancellationInterface);
  LThread := TRadIAToolExecutionThread.Create(
    FRegistry.Resolve('WaitForDebuggerEvent'),
    LRequest
  );
  try
    LThread.Start;
    Sleep(50);
    LCancellation.Cancel;
    Assert.IsTrue(LThread.AwaitCompletion);
    Assert.IsTrue(LThread.ToolResult.Success);
    Assert.Contains(LThread.ToolResult.ContentJson, '"reason":"cancelled"');
  finally
    LCancellation.Cancel;
    LThread.WaitFor;
    LThread.Free;
  end;
end;

function TTestRadIARuntimeDebugTools.ExecuteTool(
  const AName: string;
  const AArguments: string
): TRadIAToolResult;
begin
  Result := FRegistry.Resolve(AName).Execute(
    TRadIAToolRequest.Create(AName, AArguments, 'runtime-debug-test')
  );
end;

procedure TTestRadIARuntimeDebugTools.RegistersRuntimeDebugTools;
begin
  Assert.IsTrue(Assigned(FRegistry.Resolve('GetRuntimeDebugSession')));
  Assert.IsTrue(Assigned(FRegistry.Resolve('WaitForDebuggerEvent')));
  Assert.IsTrue(Assigned(FRegistry.Resolve('CancelDebuggerWait')));
  Assert.AreEqual(
    Ord(trReadOnly),
    Ord(FRegistry.Resolve('WaitForDebuggerEvent').Descriptor.Risk)
  );
end;

procedure TTestRadIARuntimeDebugTools.ReturnsCorrelatedSession;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('GetRuntimeDebugSession', '{}');

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"complete":true');
  Assert.Contains(LResult.ContentJson, '"processId":1234');
  Assert.Contains(LResult.ContentJson, '"buildId":"size:timestamp"');
end;

procedure TTestRadIARuntimeDebugTools.Setup;
var
  LDebugger: IRadIADebuggerFacade;
begin
  FCoordinator := TRadIARuntimeDebugSessionCoordinator.Create;
  FSessionId := FCoordinator.BeginSession(
    'C:\Workspace\RuntimeLab.dproj'
  );
  Assert.IsTrue(
    FCoordinator.AttachProcess(
      FSessionId,
      1234,
      Now,
      'C:\Workspace\RuntimeLab.exe',
      'size:timestamp'
    )
  );
  FRegistry := TRadIAToolRegistry.Create;
  LDebugger := TRadIAFakeRuntimeDebugger.Create;
  RegisterRadIARuntimeDebugTools(
    FRegistry,
    FCoordinator,
    LDebugger
  );
end;

procedure TTestRadIARuntimeDebugTools.WaitReturnsExceptionAndCallStack;
var
  LArguments: string;
  LResult: TRadIAToolResult;
begin
  Assert.IsTrue(
    FCoordinator.RecordEvent(
      FSessionId,
      rdekException,
      'exception',
      'Access violation'
    )
  );
  LArguments :=
    '{"sinceSequence":0,"timeoutMs":1000,"kinds":["exception"]}';

  LResult := ExecuteTool('WaitForDebuggerEvent', LArguments);

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"reason":"matched"');
  Assert.Contains(LResult.ContentJson, '"kind":"exception"');
  Assert.Contains(LResult.ContentJson, '"stackAccessible":true');
  Assert.Contains(
    LResult.ContentJson,
    'TriggerDeterministicAccessViolation'
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimeDebugTools);

end.
