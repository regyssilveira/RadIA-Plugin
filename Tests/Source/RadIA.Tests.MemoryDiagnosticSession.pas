unit RadIA.Tests.MemoryDiagnosticSession;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Build,
  RadIA.Core.Debugger,
  RadIA.Core.MemoryDiagnosticSession,
  RadIA.Core.MemoryInstrumentation,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIAMemorySessionWorkspaceMock = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade
  )
  public
    function GetIDEState: TRadIAIDEState;
    function GetActiveProject: TRadIAProjectSnapshot;
    function GetActiveUnit: string;
    function ListOpenFiles: TArray<string>;
    function ListProjectUnits: TArray<string>;
    function GetEditorContent(
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
    function GetEditorSelection: TRadIAEditorSelection;
    function GetCursorPosition: TRadIAEditorPosition;
    function GetCompilerMessages(
      const AMaxCount: Integer
    ): TArray<TRadIACompilerMessage>;
  end;

  TRadIAMemorySessionInstrumentationMock = class(
    TInterfacedObject,
    IRadIAMemoryInstrumentationCoordinator
  )
  private
    FApplyCount: Integer;
    FRevertCount: Integer;
  public
    function Prepare(
      const AMode: TRadIAMemoryInstrumentationMode
    ): TRadIAMemoryInstrumentationResult;
    function Apply(
      const APreviewId: string
    ): TRadIAMemoryInstrumentationResult;
    function Revert(
      const APreviewId: string
    ): TRadIAMemoryInstrumentationResult;
    property ApplyCount: Integer read FApplyCount;
    property RevertCount: Integer read FRevertCount;
  end;

  TRadIAMemorySessionBuildMock = class(
    TInterfacedObject,
    IRadIABuildFacade
  )
  private
    FSucceed: Boolean;
  public
    function Execute(
      const ARequest: TRadIABuildRequest
    ): TRadIABuildResult;
    function Cancel: Boolean;
    function GetStatus: TRadIABuildStatus;
    property Succeed: Boolean read FSucceed write FSucceed;
  end;

  TRadIAMemorySessionDebuggerMock = class(
    TInterfacedObject,
    IRadIADebuggerSessionFacade,
    IRadIADebuggerControlFacade
  )
  public
    function StartDebugging: TRadIADebuggerActionResult;
    function ExecuteAction(
      const AAction: TRadIADebuggerAction
    ): TRadIADebuggerActionResult;
  end;

  TRadIAMemorySessionRuntimeMock = class(
    TInterfacedObject,
    IRadIARuntimeDebugSessionCoordinator
  )
  private
    FGetSessionCount: Integer;
  public
    function BeginSession(const AProjectPath: string): string;
    function AttachProcess(
      const ASessionId: string;
      const AProcessId: LongWord;
      const ACreatedAtUtc: TDateTime;
      const AExecutablePath: string;
      const ABuildId: string
    ): Boolean;
    function GetCurrentSession: TRadIARuntimeSessionIdentity;
    function GetLastSequence: Int64;
    function TryGetLastEvent(
      out AEvent: TRadIARuntimeDebugEvent
    ): Boolean;
    function RecordEvent(
      const ASessionId: string;
      const AKind: TRadIARuntimeDebugEventKind;
      const AState: string;
      const ADetails: string
    ): Boolean;
    function CreateWait(
      const AFilter: TRadIARuntimeDebugWaitFilter
    ): IRadIARuntimeDebugWait;
    function WaitForEvent(
      const AFilter: TRadIARuntimeDebugWaitFilter;
      const ACancellation: IRadIARuntimeDebugWaitCancellation
    ): TRadIARuntimeDebugWaitResult;
    procedure NotifyWaiters;
  end;

  TRadIAMemorySessionScenarioMock = class(
    TInterfacedObject,
    IRadIARuntimeScenarioCoordinator
  )
  public
    function Cancel: Boolean;
    function GetStatus: TRadIARuntimeScenarioStatus;
    function Prepare(
      const AScenario: TRadIARuntimeScenario
    ): TRadIARuntimeScenarioPreview;
    function Run(
      const APreviewId: string;
      const ACurrentSession: TRadIARuntimeSessionIdentity;
      const ACancellationToken: IRadIAToolCancellationToken
    ): TRadIARuntimeScenarioStatus;
  end;

  [TestFixture]
  TRadIAMemoryDiagnosticSessionTests = class
  private
    FBuild: TRadIAMemorySessionBuildMock;
    FCoordinator: IRadIAMemoryDiagnosticSessionCoordinator;
    FDebugger: TRadIAMemorySessionDebuggerMock;
    FInstrumentation: TRadIAMemorySessionInstrumentationMock;
    FRuntime: IRadIARuntimeDebugSessionCoordinator;
    FScenario: IRadIARuntimeScenarioCoordinator;
    FWorkspace: IRadIAWorkspaceFacade;
    function ExecutableScenario: TRadIARuntimeScenario;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure PrepareReturnsConsentPreview;
    [Test]
    procedure BuildFailureAlwaysRevertsInstrumentation;
    [Test]
    procedure SuccessfulRunReturnsStructuredEvidence;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows;

function MemorySessionFixtureRoot: string;
begin
  Result := TPath.Combine(TPath.GetTempPath, 'RadIAMemorySessionTest');
end;

{ TRadIAMemorySessionWorkspaceMock }

function TRadIAMemorySessionWorkspaceMock.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'Demo',
    TPath.Combine(MemorySessionFixtureRoot, 'Demo.dproj'),
    MemorySessionFixtureRoot,
    'Debug',
    'Win32'
  );
end;

function TRadIAMemorySessionWorkspaceMock.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIAMemorySessionWorkspaceMock.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIAMemorySessionWorkspaceMock.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIAMemorySessionWorkspaceMock.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIAMemorySessionWorkspaceMock.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIAMemorySessionWorkspaceMock.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Delphi 13', 'Win32', False, []);
end;

function TRadIAMemorySessionWorkspaceMock.ListOpenFiles: TArray<string>;
begin
  Result := [];
end;

function TRadIAMemorySessionWorkspaceMock.ListProjectUnits: TArray<string>;
begin
  Result := [];
end;

{ TRadIAMemorySessionInstrumentationMock }

function TRadIAMemorySessionInstrumentationMock.Apply(
  const APreviewId: string
): TRadIAMemoryInstrumentationResult;
begin
  Inc(FApplyCount);
  TDirectory.CreateDirectory(
    TPath.Combine(MemorySessionFixtureRoot, '.radia\memory')
  );
  TFile.WriteAllText(
    TPath.Combine(
      TPath.Combine(MemorySessionFixtureRoot, '.radia\memory'),
      'latest-fastmm5.log'
    ),
    'A memory block has been leaked. The size is: 16' + sLineBreak +
    'This block was allocated by thread 0x1, and the stack trace was:' +
    sLineBreak +
    '00401000 [Demo.pas] RunLeakCase' + sLineBreak +
    '--------------------------------'
  );
  Result := TRadIAMemoryInstrumentationResult.Succeeded(
    '{"previewId":"instrumentation","state":"applied"}'
  );
end;

function TRadIAMemorySessionInstrumentationMock.Prepare(
  const AMode: TRadIAMemoryInstrumentationMode
): TRadIAMemoryInstrumentationResult;
begin
  Result := TRadIAMemoryInstrumentationResult.Succeeded(
    '{"previewId":"instrumentation","state":"prepared"}'
  );
end;

function TRadIAMemorySessionInstrumentationMock.Revert(
  const APreviewId: string
): TRadIAMemoryInstrumentationResult;
begin
  Inc(FRevertCount);
  Result := TRadIAMemoryInstrumentationResult.Succeeded(
    '{"previewId":"instrumentation","state":"reverted"}'
  );
end;

{ TRadIAMemorySessionBuildMock }

function TRadIAMemorySessionBuildMock.Cancel: Boolean;
begin
  Result := True;
end;

function TRadIAMemorySessionBuildMock.Execute(
  const ARequest: TRadIABuildRequest
): TRadIABuildResult;
begin
  if FSucceed then
    Result := TRadIABuildResult.Completed(
      bsSucceeded,
      TRadIAProjectSnapshot.Create(
        'Demo',
        TPath.Combine(MemorySessionFixtureRoot, 'Demo.dproj'),
        MemorySessionFixtureRoot,
        'Debug',
        'Win32'
      ),
      10,
      []
    )
  else
    Result := TRadIABuildResult.Failed(
      bsFailed,
      'fixture_build_failed',
      'Fixture build failed.'
    );
end;

function TRadIAMemorySessionBuildMock.GetStatus: TRadIABuildStatus;
begin
  Result := bsIdle;
end;

{ TRadIAMemorySessionDebuggerMock }

function TRadIAMemorySessionDebuggerMock.ExecuteAction(
  const AAction: TRadIADebuggerAction
): TRadIADebuggerActionResult;
begin
  Result := TRadIADebuggerActionResult.Succeeded(
    'Stopped.',
    'running',
    'stopped'
  );
end;

function TRadIAMemorySessionDebuggerMock.StartDebugging:
  TRadIADebuggerActionResult;
begin
  Result := TRadIADebuggerActionResult.Succeeded(
    'Started.',
    'stopped',
    'running'
  );
end;

{ TRadIAMemorySessionRuntimeMock }

function TRadIAMemorySessionRuntimeMock.AttachProcess(
  const ASessionId: string;
  const AProcessId: LongWord;
  const ACreatedAtUtc: TDateTime;
  const AExecutablePath: string;
  const ABuildId: string
): Boolean;
begin
  Result := False;
end;

function TRadIAMemorySessionRuntimeMock.BeginSession(
  const AProjectPath: string
): string;
begin
  Result := '';
end;

function TRadIAMemorySessionRuntimeMock.CreateWait(
  const AFilter: TRadIARuntimeDebugWaitFilter
): IRadIARuntimeDebugWait;
begin
  Result := nil;
end;

function TRadIAMemorySessionRuntimeMock.GetCurrentSession:
  TRadIARuntimeSessionIdentity;
begin
  Inc(FGetSessionCount);
  if FGetSessionCount = 1 then
    Exit(Default(TRadIARuntimeSessionIdentity));
  Result := TRadIARuntimeSessionIdentity.Create(
    'runtime-session',
    GetCurrentProcessId,
    Now,
    TPath.Combine(MemorySessionFixtureRoot, 'Demo.exe'),
    TPath.Combine(MemorySessionFixtureRoot, 'Demo.dproj'),
    'fixture-build'
  );
end;

function TRadIAMemorySessionRuntimeMock.GetLastSequence: Int64;
begin
  Result := 0;
end;

procedure TRadIAMemorySessionRuntimeMock.NotifyWaiters;
begin
  // No waiters are used by this deterministic fixture.
end;

function TRadIAMemorySessionRuntimeMock.RecordEvent(
  const ASessionId: string;
  const AKind: TRadIARuntimeDebugEventKind;
  const AState: string;
  const ADetails: string
): Boolean;
begin
  Result := False;
end;

function TRadIAMemorySessionRuntimeMock.TryGetLastEvent(
  out AEvent: TRadIARuntimeDebugEvent
): Boolean;
begin
  AEvent := Default(TRadIARuntimeDebugEvent);
  Result := False;
end;

function TRadIAMemorySessionRuntimeMock.WaitForEvent(
  const AFilter: TRadIARuntimeDebugWaitFilter;
  const ACancellation: IRadIARuntimeDebugWaitCancellation
): TRadIARuntimeDebugWaitResult;
begin
  Result := Default(TRadIARuntimeDebugWaitResult);
end;

{ TRadIAMemorySessionScenarioMock }

function TRadIAMemorySessionScenarioMock.Cancel: Boolean;
begin
  Result := True;
end;

function TRadIAMemorySessionScenarioMock.GetStatus:
  TRadIARuntimeScenarioStatus;
begin
  Result := Default(TRadIARuntimeScenarioStatus);
end;

function TRadIAMemorySessionScenarioMock.Prepare(
  const AScenario: TRadIARuntimeScenario
): TRadIARuntimeScenarioPreview;
begin
  Result := TRadIARuntimeScenarioPreview.Create(
    StringOfChar('a', 32),
    StringOfChar('b', 64),
    AScenario.Name,
    AScenario.Session.SessionId,
    Length(AScenario.Actions),
    AScenario.Limits.MaxRepetitions
  );
end;

function TRadIAMemorySessionScenarioMock.Run(
  const APreviewId: string;
  const ACurrentSession: TRadIARuntimeSessionIdentity;
  const ACancellationToken: IRadIAToolCancellationToken
): TRadIARuntimeScenarioStatus;
begin
  Result := TRadIARuntimeScenarioStatus.Create(
    APreviewId,
    rssSucceeded,
    1,
    1,
    1,
    '',
    ''
  );
end;

{ TRadIAMemoryDiagnosticSessionTests }

function TRadIAMemoryDiagnosticSessionTests.ExecutableScenario:
  TRadIARuntimeScenario;
var
  LAction: TRadIARuntimeScenarioAction;
  LSelector: TRadIARuntimeSelector;
  LSession: TRadIARuntimeSessionIdentity;
begin
  LSelector := TRadIARuntimeSelector.Create('', '', '', '', '');
  LAction := TRadIARuntimeScenarioAction.Create(
    rakWait,
    LSelector,
    '',
    100
  );
  LSession := TRadIARuntimeSessionIdentity.Create(
    'preview',
    1,
    Now,
    'D:\Demo\Demo.exe',
    'D:\Demo\Demo.dproj',
    'build'
  );
  Result := TRadIARuntimeScenario.Create(
    'Memory fixture',
    LSession,
    TRadIARuntimeScenarioLimits.Create(1, 1000, 1),
    [LAction]
  );
end;

procedure TRadIAMemoryDiagnosticSessionTests.Setup;
var
  LDependencies: TRadIAMemoryDiagnosticSessionDependencies;
  LInstrumentationIntf: IRadIAMemoryInstrumentationCoordinator;
begin
  FWorkspace := TRadIAMemorySessionWorkspaceMock.Create;
  FInstrumentation := TRadIAMemorySessionInstrumentationMock.Create;
  LInstrumentationIntf := FInstrumentation;
  FBuild := TRadIAMemorySessionBuildMock.Create;
  FDebugger := TRadIAMemorySessionDebuggerMock.Create;
  FRuntime := TRadIAMemorySessionRuntimeMock.Create;
  FScenario := TRadIAMemorySessionScenarioMock.Create;
  LDependencies := TRadIAMemoryDiagnosticSessionDependencies.Create(
    FWorkspace,
    LInstrumentationIntf,
    FBuild,
    FDebugger,
    FDebugger,
    FRuntime,
    FScenario
  );
  FCoordinator := TRadIAMemoryDiagnosticSessionCoordinator.Create(
    LDependencies
  );
end;

procedure TRadIAMemoryDiagnosticSessionTests.TearDown;
begin
  FCoordinator := nil;
  FScenario := nil;
  FRuntime := nil;
  FBuild := nil;
  FWorkspace := nil;
  if TDirectory.Exists(MemorySessionFixtureRoot) then
    TDirectory.Delete(MemorySessionFixtureRoot, True);
end;

procedure TRadIAMemoryDiagnosticSessionTests.PrepareReturnsConsentPreview;
var
  LResult: TRadIAToolResult;
begin
  LResult := FCoordinator.Prepare(ExecutableScenario, 1);
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"consentRequired":true');
  Assert.Contains(LResult.ContentJson, '"warmupRepetitions":1');
end;

procedure TRadIAMemoryDiagnosticSessionTests.BuildFailureAlwaysRevertsInstrumentation;
var
  LPrepare: TRadIAToolResult;
  LPreviewId: string;
  LRoot: TJSONObject;
  LRun: TRadIAToolResult;
begin
  LPrepare := FCoordinator.Prepare(ExecutableScenario, 0);
  LRoot := TJSONObject.ParseJSONValue(
    LPrepare.ContentJson
  ) as TJSONObject;
  try
    LPreviewId := LRoot.GetValue<string>('previewId');
  finally
    LRoot.Free;
  end;
  LRun := FCoordinator.Run(LPreviewId, nil);
  Assert.IsFalse(LRun.Success);
  Assert.AreEqual('memory_diagnostic_build_failed', LRun.ErrorCode);
  Assert.AreEqual(1, FInstrumentation.ApplyCount);
  Assert.AreEqual(1, FInstrumentation.RevertCount);
end;

procedure TRadIAMemoryDiagnosticSessionTests.SuccessfulRunReturnsStructuredEvidence;
var
  LPrepare: TRadIAToolResult;
  LPreviewId: string;
  LRoot: TJSONObject;
  LRun: TRadIAToolResult;
begin
  FBuild.Succeed := True;
  LPrepare := FCoordinator.Prepare(ExecutableScenario, 1);
  LRoot := TJSONObject.ParseJSONValue(
    LPrepare.ContentJson
  ) as TJSONObject;
  try
    LPreviewId := LRoot.GetValue<string>('previewId');
  finally
    LRoot.Free;
  end;
  LRun := FCoordinator.Run(LPreviewId, nil);
  Assert.IsTrue(LRun.Success, LRun.ErrorMessage);
  Assert.Contains(LRun.ContentJson, '"schemaVersion":1');
  Assert.Contains(LRun.ContentJson, '"termination":"controlled"');
  Assert.Contains(LRun.ContentJson, '"groups":[');
  Assert.Contains(LRun.ContentJson, '"kind":"leak"');
  Assert.Contains(LRun.ContentJson, '"snapshots":[');
  Assert.AreEqual(1, FInstrumentation.RevertCount);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAMemoryDiagnosticSessionTests);

end.
