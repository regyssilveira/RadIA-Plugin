unit RadIA.Tests.MemoryDiagnosticSession;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Build,
  RadIA.Core.Debugger,
  RadIA.Core.MemoryDiagnosticSession,
  RadIA.Core.MemoryInstrumentation,
  RadIA.Core.Patches,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIAMemorySessionWorkspaceMock = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade,
    IRadIAEditorMutationFacade,
    IRadIAEditorPersistenceFacade
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
    function ApplyContent(
      const AFileName: string;
      const AExpectedRevision: string;
      const ANewContent: string;
      out AAppliedRevision: string
    ): Boolean;
    function ReadContent(
      const AFileName: string;
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
    function ReloadFile(const AFileName: string): Boolean;
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
      const AMode: TRadIAMemoryInstrumentationMode;
      const ABreakAllocationNumber: Int64 = 0
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
    function StartRuntimeProcess(
      out AProcessId: LongWord;
      out ACreatedAtUtc: TDateTime;
      out AExecutablePath: string;
      out ABuildId: string
    ): TRadIADebuggerActionResult;
    function StopRuntimeProcess(const AProcessId: LongWord): Boolean;
    function ExecuteAction(
      const AAction: TRadIADebuggerAction
    ): TRadIADebuggerActionResult;
  end;

  TRadIAMemorySessionRuntimeMock = class(
    TInterfacedObject,
    IRadIARuntimeDebugSessionCoordinator
  )
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
    procedure PrepareRecoversInterruptedInstrumentation;
    [Test]
    procedure SuccessfulRunReturnsStructuredEvidence;
  end;

implementation

uses
  System.DateUtils,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils;

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

function TRadIAMemorySessionWorkspaceMock.ApplyContent(
  const AFileName: string;
  const AExpectedRevision: string;
  const ANewContent: string;
  out AAppliedRevision: string
): Boolean;
begin
  AAppliedRevision := '';
  Result := False;
end;

function TRadIAMemorySessionWorkspaceMock.ReadContent(
  const AFileName: string;
  const AMaxCharacters: Integer
): TRadIAEditorContent;
var
  LContent: string;
begin
  LContent := 'program Demo; begin end.';
  Result := TRadIAEditorContent.Create(
    'Demo',
    AFileName,
    LContent,
    THashSHA2.GetHashString(LContent),
    Length(LContent),
    False
  );
end;

function TRadIAMemorySessionWorkspaceMock.ReloadFile(
  const AFileName: string
): Boolean;
begin
  Result := SameText(
    AFileName,
    TPath.Combine(MemorySessionFixtureRoot, 'Demo.dpr')
  );
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
  TFile.WriteAllText(
    TPath.Combine(
      TPath.Combine(MemorySessionFixtureRoot, '.radia\memory'),
      'latest-fastmm5.log.ready'
    ),
    'ready'
  );
  Result := TRadIAMemoryInstrumentationResult.Succeeded(
    '{"previewId":"instrumentation","state":"applied"}'
  );
end;

function TRadIAMemorySessionInstrumentationMock.Prepare(
  const AMode: TRadIAMemoryInstrumentationMode;
  const ABreakAllocationNumber: Int64
): TRadIAMemoryInstrumentationResult;
begin
  Result := TRadIAMemoryInstrumentationResult.Succeeded(
    '{"previewId":"instrumentation","state":"prepared",' +
    '"fileName":"' +
    StringReplace(
      TPath.Combine(MemorySessionFixtureRoot, 'Demo.dpr'),
      '\',
      '\\',
      [rfReplaceAll]
    ) +
    '","fingerprint":"' +
    THashSHA2.GetHashString('program Demo; begin end.') +
    '","normalizedFingerprint":"' +
    THashSHA2.GetHashString('program Demo; begin end.') + '"}'
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

function TRadIAMemorySessionDebuggerMock.StartRuntimeProcess(
  out AProcessId: LongWord;
  out ACreatedAtUtc: TDateTime;
  out AExecutablePath: string;
  out ABuildId: string
): TRadIADebuggerActionResult;
begin
  AProcessId := 1;
  ACreatedAtUtc := Now;
  AExecutablePath := 'D:\Demo\Demo.exe';
  ABuildId := 'build';
  Result := TRadIADebuggerActionResult.Succeeded(
    'Started.',
    'no_process',
    'running'
  );
end;

function TRadIAMemorySessionDebuggerMock.StopRuntimeProcess(
  const AProcessId: LongWord
): Boolean;
begin
  Result := AProcessId > 0;
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
  Result :=
    SameText(ASessionId, 'runtime-session') and
    (AProcessId = 1) and
    SameText(AExecutablePath, 'D:\Demo\Demo.exe') and
    SameText(ABuildId, 'build');
end;

function TRadIAMemorySessionRuntimeMock.BeginSession(
  const AProjectPath: string
): string;
begin
  Result := 'runtime-session';
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
  Result := TRadIARuntimeSessionIdentity.Create(
    'runtime-session',
    1,
    Now,
    'D:\Demo\Demo.exe',
    TPath.Combine(MemorySessionFixtureRoot, 'Demo.dproj'),
    'build'
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
  TDirectory.CreateDirectory(MemorySessionFixtureRoot);
  TFile.WriteAllText(
    TPath.Combine(MemorySessionFixtureRoot, 'Demo.dpr'),
    'program Demo; begin end.',
    TEncoding.UTF8
  );
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

procedure TRadIAMemoryDiagnosticSessionTests.
  PrepareRecoversInterruptedInstrumentation;
var
  LDirectory: string;
  LManifest: TJSONObject;
  LOriginalContent: string;
  LResult: TRadIAToolResult;
  LSourceFile: string;
  LStagedContent: string;
begin
  LOriginalContent := 'program Demo; begin end.';
  LStagedContent := 'program Demo; uses FastMM5; begin end.';
  LSourceFile := TPath.Combine(MemorySessionFixtureRoot, 'Demo.dpr');
  LDirectory := TPath.Combine(
    MemorySessionFixtureRoot,
    '.radia\memory\recovery'
  );
  TDirectory.CreateDirectory(LDirectory);
  TFile.WriteAllText(
    TPath.Combine(LDirectory, 'instrumentation-original.bin'),
    LOriginalContent,
    TEncoding.UTF8
  );
  TFile.WriteAllText(
    TPath.Combine(LDirectory, 'instrumentation-staged.bin'),
    LStagedContent,
    TEncoding.UTF8
  );
  TFile.WriteAllText(LSourceFile, LStagedContent, TEncoding.UTF8);
  LManifest := TJSONObject.Create;
  try
    LManifest.AddPair('schemaVersion', 1);
    LManifest.AddPair('sourceFile', LSourceFile);
    LManifest.AddPair(
      'timestampUtc',
      DateToISO8601(TFile.GetLastWriteTimeUtc(LSourceFile), True)
    );
    TFile.WriteAllText(
      TPath.Combine(LDirectory, 'instrumentation-recovery.json'),
      LManifest.ToJSON,
      TEncoding.UTF8
    );
  finally
    LManifest.Free;
  end;
  LResult := FCoordinator.Prepare(ExecutableScenario, 1);
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.AreEqual(
    LOriginalContent,
    TFile.ReadAllText(LSourceFile, TEncoding.UTF8)
  );
  Assert.IsFalse(TDirectory.Exists(LDirectory));
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
