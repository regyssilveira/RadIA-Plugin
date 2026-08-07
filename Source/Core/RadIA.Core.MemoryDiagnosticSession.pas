unit RadIA.Core.MemoryDiagnosticSession;

interface

uses
  System.SysUtils,
  RadIA.Core.Build,
  RadIA.Core.Debugger,
  RadIA.Core.MemoryInstrumentation,
  RadIA.Core.Patches,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIAMemoryDiagnosticSessionState = (
    mdssIdle,
    mdssPrepared,
    mdssInstrumenting,
    mdssBuilding,
    mdssStarting,
    mdssWarmingUp,
    mdssRunning,
    mdssStopping,
    mdssCollecting,
    mdssSucceeded,
    mdssFailed,
    mdssCancelled
  );

  TRadIAMemoryDiagnosticSessionDependencies = record
  private
    FBuild: IRadIABuildFacade;
    FDebugControl: IRadIADebuggerControlFacade;
    FDebugSession: IRadIADebuggerSessionFacade;
    FInstrumentation: IRadIAMemoryInstrumentationCoordinator;
    FRuntimeSession: IRadIARuntimeDebugSessionCoordinator;
    FScenario: IRadIARuntimeScenarioCoordinator;
    FWorkspace: IRadIAWorkspaceFacade;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AInstrumentation: IRadIAMemoryInstrumentationCoordinator;
      const ABuild: IRadIABuildFacade;
      const ADebugSession: IRadIADebuggerSessionFacade;
      const ADebugControl: IRadIADebuggerControlFacade;
      const ARuntimeSession: IRadIARuntimeDebugSessionCoordinator;
      const AScenario: IRadIARuntimeScenarioCoordinator
    );
    property Build: IRadIABuildFacade read FBuild;
    property DebugControl: IRadIADebuggerControlFacade read FDebugControl;
    property DebugSession: IRadIADebuggerSessionFacade read FDebugSession;
    property Instrumentation: IRadIAMemoryInstrumentationCoordinator
      read FInstrumentation;
    property RuntimeSession: IRadIARuntimeDebugSessionCoordinator
      read FRuntimeSession;
    property Scenario: IRadIARuntimeScenarioCoordinator read FScenario;
    property Workspace: IRadIAWorkspaceFacade read FWorkspace;
  end;

  IRadIAMemoryDiagnosticSessionCoordinator = interface
    ['{199E198C-41F9-45B8-9D0B-845F82163344}']
    function Prepare(
      const AScenario: TRadIARuntimeScenario;
      const AWarmupRepetitions: Integer
    ): TRadIAToolResult;
    function Run(
      const APreviewId: string;
      const ACancellationToken: IRadIAToolCancellationToken
    ): TRadIAToolResult;
    function Cancel: Boolean;
    function GetStatus: string;
  end;

  TRadIAMemoryDiagnosticSessionCoordinator = class(
    TInterfacedObject,
    IRadIAMemoryDiagnosticSessionCoordinator
  )
  private
    FCancelRequested: Boolean;
    FDependencies: TRadIAMemoryDiagnosticSessionDependencies;
    FEditorMutation: IRadIAEditorMutationFacade;
    FEditorPersistence: IRadIAEditorPersistenceFacade;
    FInstrumentationPreviewId: string;
    FLock: TObject;
    FOriginalSourceBytes: TBytes;
    FOriginalSourceTimestampUtc: TDateTime;
    FPreviewId: string;
    FProjectSourceFile: string;
    FSourceRestored: Boolean;
    FScenario: TRadIARuntimeScenario;
    FState: TRadIAMemoryDiagnosticSessionState;
    FStatusMessage: string;
    FWarmupRepetitions: Integer;
    function BuildEvidence(
      const AParseJson: string;
      const ASession: TRadIARuntimeSessionIdentity;
      const AScenarioFingerprint: string;
      const ATermination: string;
      const ABaselineSnapshot: string;
      const AFinalSnapshot: string
    ): string;
    function BuildPreviewJson(
      const AInstrumentationJson: string;
      const AScenarioFingerprint: string
    ): string;
    function CaptureSnapshot(
      const ALabel: string;
      const AProcessId: LongWord
    ): string;
    function CancellationRequested(
      const ACancellationToken: IRadIAToolCancellationToken
    ): Boolean;
    procedure FinalizeRun(
      const ACancellationToken: IRadIAToolCancellationToken;
      var AResult: TRadIAToolResult
    );
    function ParseInstrumentationPreviewId(
      const AContentJson: string
    ): string;
    function ParseInstrumentationSourceFile(
      const AContentJson: string
    ): string;
    function ProcessIsRunning(const AProcessId: LongWord): Boolean;
    function PrepareExecutable(
      out AFailure: TRadIAToolResult
    ): Boolean;
    function RestoreProjectSource(
      out AResult: TRadIAMemoryInstrumentationResult
    ): Boolean;
    function RunScenario(
      const ASession: TRadIARuntimeSessionIdentity;
      const ARepetitions: Integer;
      const ACancellationToken: IRadIAToolCancellationToken
    ): TRadIARuntimeScenarioStatus;
    function RunWarmup(
      const ASession: TRadIARuntimeSessionIdentity;
      const ACancellationToken: IRadIAToolCancellationToken;
      out AStatus: TRadIARuntimeScenarioStatus
    ): Boolean;
    function ScenarioFingerprint: string;
    function SourceMatchesSavedFile(
      const AInstrumentationJson: string
    ): Boolean;
    function StageInstrumentedSource: Boolean;
    procedure SetStatus(
      const AState: TRadIAMemoryDiagnosticSessionState;
      const AMessage: string
    );
    function WaitForLog(
      const ALogPath: string;
      const ATimeoutMs: Cardinal;
      const ACancellationToken: IRadIAToolCancellationToken
    ): Boolean;
    function WaitForProcessExit(
      const AProcessId: LongWord;
      const ATimeoutMs: Cardinal;
      const ACancellationToken: IRadIAToolCancellationToken
    ): Boolean;
  public
    constructor Create(
      const ADependencies: TRadIAMemoryDiagnosticSessionDependencies
    );
    destructor Destroy; override;
    function Prepare(
      const AScenario: TRadIARuntimeScenario;
      const AWarmupRepetitions: Integer
    ): TRadIAToolResult;
    function Run(
      const APreviewId: string;
      const ACancellationToken: IRadIAToolCancellationToken
    ): TRadIAToolResult;
    function Cancel: Boolean;
    function GetStatus: string;
  end;

procedure RegisterRadIAMemoryDiagnosticSessionTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIAMemoryDiagnosticSessionCoordinator;
  const ARuntimeSession: IRadIARuntimeDebugSessionCoordinator;
  const AWorkspace: IRadIAWorkspaceFacade
);

implementation

uses
  System.Classes,
  System.DateUtils,
  System.Hash,
  System.IOUtils,
  System.JSON,
  Winapi.PsAPI,
  Winapi.Windows,
  RadIA.Core.FastMM5,
  RadIA.Core.FastMM5LogParser,
  RadIA.Core.Logger,
  RadIA.Core.MemoryDiagnostics,
  RadIA.Core.RuntimeScenarioTools;

type
  TRadIAMemoryDiagnosticSessionToolKind = (
    mdstkPrepare,
    mdstkRun,
    mdstkCancel,
    mdstkStatus
  );

  TRadIAMemoryDiagnosticSessionTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FCoordinator: IRadIAMemoryDiagnosticSessionCoordinator;
    FKind: TRadIAMemoryDiagnosticSessionToolKind;
    FRuntimeSession: IRadIARuntimeDebugSessionCoordinator;
    FWorkspace: IRadIAWorkspaceFacade;
    function ExecutePrepare(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteRun(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIAMemoryDiagnosticSessionToolKind;
      const ACoordinator: IRadIAMemoryDiagnosticSessionCoordinator;
      const ARuntimeSession: IRadIARuntimeDebugSessionCoordinator;
      const AWorkspace: IRadIAWorkspaceFacade
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CPrepareInputSchema =
    '{"type":"object","required":["scenario"],"properties":{' +
    '"scenario":{"type":"object"},"warmupRepetitions":{"type":"integer",' +
    '"minimum":0,"maximum":10}},"additionalProperties":false}';
  CRunInputSchema =
    '{"type":"object","required":["previewId"],"properties":{' +
    '"previewId":{"type":"string","minLength":32,"maxLength":32}},' +
    '"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

function SizeValueToString(const AValue: SIZE_T): string;
begin
  Result := Format('%u', [AValue]);
end;

function MemorySessionStateName(
  const AState: TRadIAMemoryDiagnosticSessionState
): string;
begin
  case AState of
    mdssIdle:
      Result := 'idle';
    mdssPrepared:
      Result := 'prepared';
    mdssInstrumenting:
      Result := 'instrumenting';
    mdssBuilding:
      Result := 'building';
    mdssStarting:
      Result := 'starting';
    mdssWarmingUp:
      Result := 'warmingUp';
    mdssRunning:
      Result := 'running';
    mdssStopping:
      Result := 'stopping';
    mdssCollecting:
      Result := 'collecting';
    mdssSucceeded:
      Result := 'succeeded';
    mdssFailed:
      Result := 'failed';
    mdssCancelled:
      Result := 'cancelled';
  else
    Result := 'unknown';
  end;
end;

{ TRadIAMemoryDiagnosticSessionDependencies }

constructor TRadIAMemoryDiagnosticSessionDependencies.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AInstrumentation: IRadIAMemoryInstrumentationCoordinator;
  const ABuild: IRadIABuildFacade;
  const ADebugSession: IRadIADebuggerSessionFacade;
  const ADebugControl: IRadIADebuggerControlFacade;
  const ARuntimeSession: IRadIARuntimeDebugSessionCoordinator;
  const AScenario: IRadIARuntimeScenarioCoordinator
);
begin
  FWorkspace := AWorkspace;
  FInstrumentation := AInstrumentation;
  FBuild := ABuild;
  FDebugSession := ADebugSession;
  FDebugControl := ADebugControl;
  FRuntimeSession := ARuntimeSession;
  FScenario := AScenario;
end;

{ TRadIAMemoryDiagnosticSessionCoordinator }

constructor TRadIAMemoryDiagnosticSessionCoordinator.Create(
  const ADependencies: TRadIAMemoryDiagnosticSessionDependencies
);
begin
  inherited Create;
  if not Assigned(ADependencies.Workspace) or
    not Assigned(ADependencies.Instrumentation) or
    not Assigned(ADependencies.Build) or
    not Assigned(ADependencies.DebugSession) or
    not Assigned(ADependencies.DebugControl) or
    not Assigned(ADependencies.RuntimeSession) or
    not Assigned(ADependencies.Scenario) then
    raise EArgumentNilException.Create('ADependencies');
  if not Supports(
    ADependencies.Workspace,
    IRadIAEditorMutationFacade,
    FEditorMutation
  ) or not Supports(
    ADependencies.Workspace,
    IRadIAEditorPersistenceFacade,
    FEditorPersistence
  ) then
    raise EArgumentException.Create(
      'Workspace does not support editor persistence.'
    );
  FDependencies := ADependencies;
  FLock := TObject.Create;
  FState := mdssIdle;
end;

destructor TRadIAMemoryDiagnosticSessionCoordinator.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.BuildEvidence(
  const AParseJson: string;
  const ASession: TRadIARuntimeSessionIdentity;
  const AScenarioFingerprint: string;
  const ATermination: string;
  const ABaselineSnapshot: string;
  const AFinalSnapshot: string
): string;
var
  LEvidence: TJSONObject;
  LGroups: TJSONArray;
  LLimits: TRadIAMemoryDiagnosticsLimits;
  LParsed: TJSONObject;
  LSession: TJSONObject;
  LSettings: TRadIAFastMM5Settings;
  LSettingsStore: TRadIAFastMM5SettingsStore;
  LSnapshots: TJSONArray;
begin
  LParsed := TJSONObject.ParseJSONValue(AParseJson) as TJSONObject;
  if not Assigned(LParsed) then
    raise EConvertError.Create('FastMM5 evidence is not valid JSON.');
  LEvidence := TJSONObject.Create;
  LSession := TJSONObject.Create;
  LSnapshots := TJSONArray.Create;
  try
    LSettingsStore := TRadIAFastMM5SettingsStore.Create;
    try
      LSettings := LSettingsStore.Load;
    finally
      LSettingsStore.Free;
    end;
    LLimits := LSettings.Limits;
    LEvidence.AddPair('schemaVersion', 1);
    LEvidence.AddPair(
      'evidenceId',
      LowerCase(
        THashMD5.GetHashString(
          ASession.SessionId + AScenarioFingerprint + DateToISO8601(Now, True)
        )
      )
    );
    LEvidence.AddPair('capturedAtUtc', DateToISO8601(Now, True));
    LSession.AddPair('sessionId', ASession.SessionId);
    LSession.AddPair('projectPath', ASession.ProjectPath);
    LSession.AddPair('executablePath', ASession.ExecutablePath);
    LSession.AddPair('buildId', ASession.BuildId);
    LSession.AddPair(
      'targetPlatform',
      FDependencies.Workspace.GetActiveProject.Platform
    );
    LSession.AddPair('backend', 'fastmm5');
    LSession.AddPair('backendVersion', '5.07');
    LSession.AddPair('processId', TJSONNumber.Create(ASession.ProcessId));
    LSession.AddPair('scenarioFingerprint', AScenarioFingerprint);
    LSession.AddPair(
      'limits',
      TJSONObject.Create
        .AddPair('maxDurationMs', TJSONNumber.Create(LLimits.MaxDurationMs))
        .AddPair('maxLogBytes', TJSONNumber.Create(LLimits.MaxLogBytes))
        .AddPair('maxRepetitions', TJSONNumber.Create(LLimits.MaxRepetitions))
    );
    LEvidence.AddPair('session', LSession);
    LEvidence.AddPair('termination', ATermination);
    LGroups := LParsed.RemovePair('events').JsonValue as TJSONArray;
    LEvidence.AddPair('groups', LGroups);
    LSnapshots.AddElement(TJSONObject.ParseJSONValue(ABaselineSnapshot));
    LSnapshots.AddElement(TJSONObject.ParseJSONValue(AFinalSnapshot));
    LEvidence.AddPair('snapshots', LSnapshots);
    LEvidence.AddPair(
      'fingerprint',
      LowerCase(
        THashSHA2.GetHashString(AParseJson + AScenarioFingerprint)
      )
    );
    Result := LEvidence.ToJSON;
  finally
    LParsed.Free;
    LEvidence.Free;
  end;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.BuildPreviewJson(
  const AInstrumentationJson: string;
  const AScenarioFingerprint: string
): string;
var
  LInstrumentation: TJSONValue;
  LRoot: TJSONObject;
begin
  LInstrumentation := TJSONObject.ParseJSONValue(AInstrumentationJson);
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('previewId', FPreviewId);
    LRoot.AddPair('scenarioFingerprint', AScenarioFingerprint);
    LRoot.AddPair('warmupRepetitions', FWarmupRepetitions);
    LRoot.AddPair('repetitions', FScenario.Limits.MaxRepetitions);
    LRoot.AddPair('instrumentation', LInstrumentation);
    LRoot.AddPair('consentRequired', TJSONBool.Create(True));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.Cancel: Boolean;
var
  LState: TRadIAMemoryDiagnosticSessionState;
begin
  TMonitor.Enter(FLock);
  try
    LState := FState;
    Result := FState in [
      mdssInstrumenting,
      mdssBuilding,
      mdssStarting,
      mdssWarmingUp,
      mdssRunning,
      mdssStopping,
      mdssCollecting
    ];
    FCancelRequested := Result;
  finally
    TMonitor.Exit(FLock);
  end;
  if Result then
  begin
    FDependencies.Build.Cancel;
    FDependencies.Scenario.Cancel;
    if LState in [
      mdssStarting,
      mdssWarmingUp,
      mdssRunning,
      mdssStopping,
      mdssCollecting
    ] then
      FDependencies.DebugControl.ExecuteAction(daStop);
  end;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.CancellationRequested(
  const ACancellationToken: IRadIAToolCancellationToken
): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FCancelRequested;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := Result or
    (Assigned(ACancellationToken) and
    ACancellationToken.CancellationRequested);
end;

function TRadIAMemoryDiagnosticSessionCoordinator.CaptureSnapshot(
  const ALabel: string;
  const AProcessId: LongWord
): string;
var
  LCounters: PROCESS_MEMORY_COUNTERS_EX;
  LHandle: THandle;
  LRoot: TJSONObject;
begin
  FillChar(LCounters, SizeOf(LCounters), 0);
  LCounters.cb := SizeOf(LCounters);
  LHandle := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_VM_READ, False, AProcessId);
  if LHandle <> 0 then
  try
    GetProcessMemoryInfo(
      LHandle,
      PPROCESS_MEMORY_COUNTERS(@LCounters),
      SizeOf(LCounters)
    );
  finally
    CloseHandle(LHandle);
  end;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('label', ALabel);
    LRoot.AddPair('capturedAtUtc', DateToISO8601(Now, True));
    LRoot.AddPair(
      'allocatedBytes',
      TJSONNumber.Create(SizeValueToString(LCounters.PrivateUsage))
    );
    LRoot.AddPair(
      'committedBytes',
      TJSONNumber.Create(SizeValueToString(LCounters.WorkingSetSize))
    );
    LRoot.AddPair('liveBlocks', 0);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.GetStatus: string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    TMonitor.Enter(FLock);
    try
      LRoot.AddPair('state', MemorySessionStateName(FState));
      LRoot.AddPair('message', FStatusMessage);
      LRoot.AddPair('previewId', FPreviewId);
      LRoot.AddPair('cancelRequested', TJSONBool.Create(FCancelRequested));
    finally
      TMonitor.Exit(FLock);
    end;
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

procedure TRadIAMemoryDiagnosticSessionCoordinator.FinalizeRun(
  const ACancellationToken: IRadIAToolCancellationToken;
  var AResult: TRadIAToolResult
);
var
  LRevertResult: TRadIAMemoryInstrumentationResult;
begin
  if CancellationRequested(ACancellationToken) then
    SetStatus(mdssCancelled, 'Memory diagnostic session was cancelled.')
  else if not (FState in [mdssSucceeded, mdssCancelled]) then
    SetStatus(mdssFailed, 'Memory diagnostic session failed.');
  if FSourceRestored then
    LRevertResult := TRadIAMemoryInstrumentationResult.Succeeded('{}')
  else
    RestoreProjectSource(LRevertResult);
  if LRevertResult.Success then
    Exit;
  SetStatus(
    mdssFailed,
    'Memory diagnostic completed but project restoration failed.'
  );
  AResult := TRadIAToolResult.Failed(
    'memory_instrumentation_revert_failed',
    LRevertResult.ErrorMessage
  );
end;

function TRadIAMemoryDiagnosticSessionCoordinator.ParseInstrumentationPreviewId(
  const AContentJson: string
): string;
var
  LRoot: TJSONObject;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AContentJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    Result := LRoot.GetValue<string>('previewId', '');
  finally
    LRoot.Free;
  end;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.ParseInstrumentationSourceFile(
  const AContentJson: string
): string;
var
  LRoot: TJSONObject;
begin
  Result := '';
  LRoot := TJSONObject.ParseJSONValue(AContentJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    Result := LRoot.GetValue<string>('fileName', '');
  finally
    LRoot.Free;
  end;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.Prepare(
  const AScenario: TRadIARuntimeScenario;
  const AWarmupRepetitions: Integer
): TRadIAToolResult;
var
  LInstrumentation: TRadIAMemoryInstrumentationResult;
  LScenarioFingerprint: string;
begin
  if not AScenario.IsExecutable then
    Exit(
      TRadIAToolResult.Failed(
        'invalid_memory_scenario',
        'The memory diagnostic scenario is not executable.'
      )
    );
  if (AWarmupRepetitions < 0) or (AWarmupRepetitions > 10) then
    Exit(
      TRadIAToolResult.Failed(
        'invalid_warmup_repetitions',
        'Warmup repetitions must be between zero and ten.'
      )
    );
  LInstrumentation := FDependencies.Instrumentation.Prepare(mimSession);
  if not LInstrumentation.Success then
    Exit(
      TRadIAToolResult.Failed(
        LInstrumentation.ErrorCode,
        LInstrumentation.ErrorMessage
      )
    );
  FInstrumentationPreviewId := ParseInstrumentationPreviewId(
    LInstrumentation.ContentJson
  );
  if FInstrumentationPreviewId.IsEmpty then
    Exit(
      TRadIAToolResult.Failed(
        'instrumentation_preview_invalid',
        'Memory instrumentation did not return a preview identifier.'
      )
    );
  FProjectSourceFile := ParseInstrumentationSourceFile(
    LInstrumentation.ContentJson
  );
  if not SourceMatchesSavedFile(LInstrumentation.ContentJson) then
    Exit(
      TRadIAToolResult.Failed(
        'memory_project_source_unsaved',
        'Save the project source before preparing a composed memory diagnostic.'
      )
    );
  FOriginalSourceBytes := TFile.ReadAllBytes(FProjectSourceFile);
  FOriginalSourceTimestampUtc :=
    TFile.GetLastWriteTimeUtc(FProjectSourceFile);
  FSourceRestored := False;
  FScenario := AScenario;
  FWarmupRepetitions := AWarmupRepetitions;
  LScenarioFingerprint := ScenarioFingerprint;
  FPreviewId := LowerCase(
    THashMD5.GetHashString(
      FInstrumentationPreviewId + LScenarioFingerprint +
      IntToStr(AWarmupRepetitions)
    )
  );
  FCancelRequested := False;
  SetStatus(mdssPrepared, 'Memory diagnostic session is ready for consent.');
  Result := TRadIAToolResult.Succeeded(
    BuildPreviewJson(
      LInstrumentation.ContentJson,
      LScenarioFingerprint
    )
  );
end;

function TRadIAMemoryDiagnosticSessionCoordinator.ProcessIsRunning(
  const AProcessId: LongWord
): Boolean;
var
  LHandle: THandle;
begin
  Result := False;
  LHandle := OpenProcess(SYNCHRONIZE, False, AProcessId);
  if LHandle = 0 then
    Exit;
  try
    Result := WaitForSingleObject(LHandle, 0) = WAIT_TIMEOUT;
  finally
    CloseHandle(LHandle);
  end;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.PrepareExecutable(
  out AFailure: TRadIAToolResult
): Boolean;
var
  LBuildResult: TRadIABuildResult;
  LInstrumentation: TRadIAMemoryInstrumentationResult;
begin
  Result := False;
  SetStatus(mdssInstrumenting, 'Applying reversible FastMM5 instrumentation.');
  LInstrumentation := FDependencies.Instrumentation.Apply(
    FInstrumentationPreviewId
  );
  if not LInstrumentation.Success then
  begin
    AFailure := TRadIAToolResult.Failed(
      LInstrumentation.ErrorCode,
      LInstrumentation.ErrorMessage
    );
    Exit;
  end;
  if not StageInstrumentedSource then
  begin
    AFailure := TRadIAToolResult.Failed(
      'memory_instrumentation_save_failed',
      'The instrumented project source could not be staged for the build.'
    );
    Exit;
  end;
  if Assigned(FEditorPersistence) and
     not FEditorPersistence.ReloadFile(FProjectSourceFile) then
  begin
    AFailure := TRadIAToolResult.Failed(
      'memory_instrumentation_reload_failed',
      'The IDE could not reload the staged project source safely.'
    );
    Exit;
  end;
  SetStatus(mdssBuilding, 'Building the active project in Debug mode.');
  LBuildResult := FDependencies.Build.Execute(
    TRadIABuildRequest.Create(bmBuild, 300000, True)
  );
  if not LBuildResult.Success then
  begin
    AFailure := TRadIAToolResult.Failed(
      'memory_diagnostic_build_failed',
      'The instrumented Debug build failed.'
    );
    Exit;
  end;
  if not RestoreProjectSource(LInstrumentation) then
  begin
    AFailure := TRadIAToolResult.Failed(
      LInstrumentation.ErrorCode,
      LInstrumentation.ErrorMessage
    );
    Exit;
  end;
  Result := True;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.Run(
  const APreviewId: string;
  const ACancellationToken: IRadIAToolCancellationToken
): TRadIAToolResult;
var
  LBaselineSnapshot: string;
  LBuildId: string;
  LCreatedAtUtc: TDateTime;
  LDebugResult: TRadIADebuggerActionResult;
  LExecutablePath: string;
  LFailure: TRadIAToolResult;
  LFinalSnapshot: string;
  LLogPath: string;
  LParseResult: TRadIAMemoryLogParseResult;
  LParser: TRadIAFastMM5LogParser;
  LProcessId: LongWord;
  LProject: TRadIAProjectSnapshot;
  LScenarioStatus: TRadIARuntimeScenarioStatus;
  LSession: TRadIARuntimeSessionIdentity;
  LSessionId: string;
  LSettings: TRadIAFastMM5Settings;
  LSettingsStore: TRadIAFastMM5SettingsStore;
  LTermination: string;
begin
  if not SameText(APreviewId, FPreviewId) or (FState <> mdssPrepared) then
    Exit(
      TRadIAToolResult.Failed(
        'memory_preview_conflict',
        'The memory diagnostic preview is missing, stale, or already used.'
      )
    );
  LProject := FDependencies.Workspace.GetActiveProject;
  LLogPath := TPath.Combine(
    TPath.Combine(LProject.RootPath, '.radia\memory'),
    'latest-fastmm5.log'
  );
  LTermination := 'exceptional';
  LBaselineSnapshot := '';
  LFinalSnapshot := '';
  try
    if TFile.Exists(LLogPath) then
      TFile.Delete(LLogPath);
    if not PrepareExecutable(LFailure) then
      Exit(LFailure);
    if CancellationRequested(ACancellationToken) then
      Exit(TRadIAToolResult.Failed('cancelled', 'Memory diagnostic cancelled.'));
    SetStatus(mdssStarting, 'Starting the instrumented runtime process.');
    LDebugResult := FDependencies.DebugSession.StartRuntimeProcess(
      LProcessId,
      LCreatedAtUtc,
      LExecutablePath,
      LBuildId
    );
    if not LDebugResult.Accepted then
      Exit(
        TRadIAToolResult.Failed(
          LDebugResult.ErrorCode,
          LDebugResult.Message
        )
      );
    LSessionId := FDependencies.RuntimeSession.BeginSession(
      LProject.FileName
    );
    if not FDependencies.RuntimeSession.AttachProcess(
      LSessionId,
      LProcessId,
      LCreatedAtUtc,
      LExecutablePath,
      LBuildId
    ) then
      Exit(
        TRadIAToolResult.Failed(
          'runtime_session_attach_failed',
          'The instrumented process could not be correlated safely.'
        )
      );
    LSession := FDependencies.RuntimeSession.GetCurrentSession;
    if not RunWarmup(
      LSession,
      ACancellationToken,
      LScenarioStatus
    ) then
      Exit(
        TRadIAToolResult.Failed(
          LScenarioStatus.ErrorCode,
          LScenarioStatus.Message
        )
      );
    LBaselineSnapshot := CaptureSnapshot('baseline', LSession.ProcessId);
    SetStatus(mdssRunning, 'Running measured memory diagnostic repetitions.');
    LScenarioStatus := RunScenario(
      LSession,
      FScenario.Limits.MaxRepetitions,
      ACancellationToken
    );
    if LScenarioStatus.State <> rssSucceeded then
      Exit(
        TRadIAToolResult.Failed(
          LScenarioStatus.ErrorCode,
          LScenarioStatus.Message
        )
      );
    LFinalSnapshot := CaptureSnapshot('final', LSession.ProcessId);
    SetStatus(mdssStopping, 'Stopping the runtime process in a controlled way.');
    if ProcessIsRunning(LSession.ProcessId) and not WaitForProcessExit(
      LSession.ProcessId,
      10000,
      ACancellationToken
    ) then
    begin
      FDependencies.DebugSession.StopRuntimeProcess(LSession.ProcessId);
      Exit(
        TRadIAToolResult.Failed(
          'runtime_graceful_stop_timeout',
          'The instrumented runtime process did not finish cleanly.'
        )
      );
    end;
    LTermination := 'controlled';
    SetStatus(mdssCollecting, 'Collecting and parsing bounded FastMM5 evidence.');
    if not WaitForLog(LLogPath, 10000, ACancellationToken) then
      Exit(
        TRadIAToolResult.Failed(
          'memory_log_timeout',
          'FastMM5 did not produce the expected diagnostic log.'
        )
      );
    LSettingsStore := TRadIAFastMM5SettingsStore.Create;
    try
      LSettings := LSettingsStore.Load;
    finally
      LSettingsStore.Free;
    end;
    LParser := TRadIAFastMM5LogParser.Create;
    try
      LParseResult := LParser.Parse(
        TFile.ReadAllText(LLogPath),
        LSettings.Limits.MaxLogBytes
      );
    finally
      LParser.Free;
    end;
    SetStatus(mdssSucceeded, 'Memory diagnostic evidence is ready.');
    Result := TRadIAToolResult.Succeeded(
      BuildEvidence(
        LParseResult.ContentJson,
        LSession,
        ScenarioFingerprint,
        LTermination,
        LBaselineSnapshot,
        LFinalSnapshot
      ),
      LParseResult.Truncated
    );
  finally
    FinalizeRun(ACancellationToken, Result);
  end;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.RestoreProjectSource(
  out AResult: TRadIAMemoryInstrumentationResult
): Boolean;
begin
  AResult := FDependencies.Instrumentation.Revert(
    FInstrumentationPreviewId
  );
  try
    TFile.WriteAllBytes(FProjectSourceFile, FOriginalSourceBytes);
    TFile.SetLastWriteTimeUtc(
      FProjectSourceFile,
      FOriginalSourceTimestampUtc
    );
    if AResult.Success and
      not FEditorPersistence.ReloadFile(FProjectSourceFile) then
      AResult := TRadIAMemoryInstrumentationResult.Failed(
        'memory_source_reload_failed',
        'The original project source was restored but the IDE could not reload it.'
      );
  except
    on E: Exception do
      AResult := TRadIAMemoryInstrumentationResult.Failed(
        'memory_source_restore_failed',
        E.Message
      );
  end;
  Result := AResult.Success;
  FSourceRestored := Result;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.StageInstrumentedSource:
  Boolean;
var
  LSnapshot: TRadIAEditorContent;
begin
  Result := False;
  LSnapshot := FEditorMutation.ReadContent(
    FProjectSourceFile,
    2 * 1024 * 1024
  );
  if LSnapshot.Content.IsEmpty or LSnapshot.Truncated then
    Exit;
  try
    TFile.WriteAllText(
      FProjectSourceFile,
      LSnapshot.Content,
      TEncoding.UTF8
    );
    Result := True;
  except
    Result := False;
  end;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.SourceMatchesSavedFile(
  const AInstrumentationJson: string
): Boolean;
var
  LDiskContent: string;
  LFingerprint: string;
  LNormalizedContent: string;
  LRoot: TJSONObject;
begin
  Result := False;
  if FProjectSourceFile.IsEmpty or not TFile.Exists(FProjectSourceFile) then
    Exit;
  LRoot := TJSONObject.ParseJSONValue(AInstrumentationJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    LFingerprint := LRoot.GetValue<string>('normalizedFingerprint', '');
    if LFingerprint.IsEmpty then
      LFingerprint := LRoot.GetValue<string>('fingerprint', '');
  finally
    LRoot.Free;
  end;
  LDiskContent := TFile.ReadAllText(FProjectSourceFile, TEncoding.UTF8);
  LNormalizedContent := StringReplace(
    LDiskContent,
    #13#10,
    #10,
    [rfReplaceAll]
  );
  LNormalizedContent := StringReplace(
    LNormalizedContent,
    #13,
    #10,
    [rfReplaceAll]
  );
  if (LNormalizedContent <> '') and
     (LNormalizedContent[Low(LNormalizedContent)] = #$FEFF) then
    Delete(LNormalizedContent, Low(LNormalizedContent), 1);
  Result := SameText(
    LFingerprint,
    THashSHA2.GetHashString(LNormalizedContent)
  );
end;

function TRadIAMemoryDiagnosticSessionCoordinator.RunScenario(
  const ASession: TRadIARuntimeSessionIdentity;
  const ARepetitions: Integer;
  const ACancellationToken: IRadIAToolCancellationToken
): TRadIARuntimeScenarioStatus;
var
  LLimits: TRadIARuntimeScenarioLimits;
  LPreview: TRadIARuntimeScenarioPreview;
  LScenario: TRadIARuntimeScenario;
begin
  LLimits := TRadIARuntimeScenarioLimits.Create(
    FScenario.Limits.MaxActions,
    FScenario.Limits.MaxDurationMs,
    ARepetitions
  );
  LScenario := TRadIARuntimeScenario.Create(
    FScenario.Name,
    ASession,
    LLimits,
    FScenario.Actions
  );
  LPreview := FDependencies.Scenario.Prepare(LScenario);
  Result := FDependencies.Scenario.Run(
    LPreview.PreviewId,
    ASession,
    ACancellationToken
  );
end;

function TRadIAMemoryDiagnosticSessionCoordinator.RunWarmup(
  const ASession: TRadIARuntimeSessionIdentity;
  const ACancellationToken: IRadIAToolCancellationToken;
  out AStatus: TRadIARuntimeScenarioStatus
): Boolean;
begin
  Result := True;
  if FWarmupRepetitions = 0 then
    Exit;
  SetStatus(mdssWarmingUp, 'Running memory diagnostic warmup.');
  AStatus := RunScenario(
    ASession,
    FWarmupRepetitions,
    ACancellationToken
  );
  Result := AStatus.State = rssSucceeded;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.ScenarioFingerprint: string;
var
  LAction: TRadIARuntimeScenarioAction;
  LMaterial: TStringBuilder;
begin
  LMaterial := TStringBuilder.Create;
  try
    LMaterial.Append(FScenario.Name);
    LMaterial.Append('|');
    LMaterial.Append(FScenario.Limits.MaxRepetitions);
    for LAction in FScenario.Actions do
    begin
      LMaterial.Append('|');
      LMaterial.Append(Ord(LAction.Kind));
      LMaterial.Append('|');
      LMaterial.Append(LAction.Selector.ControlName);
      LMaterial.Append('|');
      LMaterial.Append(LAction.Selector.ClassName);
      LMaterial.Append('|');
      LMaterial.Append(LAction.Selector.Text);
      LMaterial.Append('|');
      LMaterial.Append(LAction.Value);
    end;
    Result := LowerCase(THashSHA2.GetHashString(LMaterial.ToString));
  finally
    LMaterial.Free;
  end;
end;

procedure TRadIAMemoryDiagnosticSessionCoordinator.SetStatus(
  const AState: TRadIAMemoryDiagnosticSessionState;
  const AMessage: string
);
begin
  TMonitor.Enter(FLock);
  try
    FState := AState;
    FStatusMessage := AMessage;
  finally
    TMonitor.Exit(FLock);
  end;
  TLogger.Log(
    MemorySessionStateName(AState) + ': ' + AMessage,
    'MemoryDiagnostic'
  );
end;

function TRadIAMemoryDiagnosticSessionCoordinator.WaitForLog(
  const ALogPath: string;
  const ATimeoutMs: Cardinal;
  const ACancellationToken: IRadIAToolCancellationToken
): Boolean;
var
  LStarted: UInt64;
begin
  LStarted := GetTickCount64;
  repeat
    if CancellationRequested(ACancellationToken) then
      Exit(False);
    if TFile.Exists(ALogPath) and (TFile.GetSize(ALogPath) > 0) then
      Exit(True);
    TThread.Sleep(50);
  until GetTickCount64 - LStarted >= ATimeoutMs;
  Result := False;
end;

function TRadIAMemoryDiagnosticSessionCoordinator.WaitForProcessExit(
  const AProcessId: LongWord;
  const ATimeoutMs: Cardinal;
  const ACancellationToken: IRadIAToolCancellationToken
): Boolean;
var
  LStarted: UInt64;
begin
  LStarted := GetTickCount64;
  repeat
    if not ProcessIsRunning(AProcessId) then
      Exit(True);
    if CancellationRequested(ACancellationToken) then
      Exit(False);
    TThread.Sleep(50);
  until GetTickCount64 - LStarted >= ATimeoutMs;
  Result := not ProcessIsRunning(AProcessId);
end;

{ TRadIAMemoryDiagnosticSessionTool }

constructor TRadIAMemoryDiagnosticSessionTool.Create(
  const AKind: TRadIAMemoryDiagnosticSessionToolKind;
  const ACoordinator: IRadIAMemoryDiagnosticSessionCoordinator;
  const ARuntimeSession: IRadIARuntimeDebugSessionCoordinator;
  const AWorkspace: IRadIAWorkspaceFacade
);
begin
  inherited Create;
  if not Assigned(ACoordinator) or
    not Assigned(ARuntimeSession) or
    not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('Memory diagnostic tool dependencies');
  FKind := AKind;
  FCoordinator := ACoordinator;
  FRuntimeSession := ARuntimeSession;
  FWorkspace := AWorkspace;
end;

function TRadIAMemoryDiagnosticSessionTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  case FKind of
    mdstkPrepare:
      Result := ExecutePrepare(ARequest);
    mdstkRun:
      Result := ExecuteRun(ARequest);
    mdstkCancel:
      Result := TRadIAToolResult.Succeeded(
        '{"cancelRequested":' +
        LowerCase(BoolToStr(FCoordinator.Cancel, True)) + '}'
      );
    mdstkStatus:
      Result := TRadIAToolResult.Succeeded(FCoordinator.GetStatus);
  else
    Result := TRadIAToolResult.Failed(
      'unsupported_memory_diagnostic_tool',
      'Memory diagnostic session tool is unsupported.'
    );
  end;
end;

function TRadIAMemoryDiagnosticSessionTool.ExecutePrepare(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LPlaceholder: TRadIARuntimeSessionIdentity;
  LProject: TRadIAProjectSnapshot;
  LScenario: TRadIARuntimeScenario;
  LScenarioJson: TJSONValue;
  LWarmupRepetitions: Integer;
begin
  LJson := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed('invalid_request', 'Arguments must be a JSON object.'));
  try
    LScenarioJson := LJson.GetValue('scenario');
    if not (LScenarioJson is TJSONObject) then
      Exit(
        TRadIAToolResult.Failed(
          'invalid_memory_scenario',
          'A runtime scenario object is required.'
        )
      );
    LProject := FWorkspace.GetActiveProject;
    LPlaceholder := TRadIARuntimeSessionIdentity.Create(
      'memory-diagnostic-preview',
      1,
      Now,
      'memory-diagnostic-preview.exe',
      LProject.FileName,
      'memory-diagnostic-preview'
    );
    if not TryParseRadIARuntimeScenarioDefinition(
      LScenarioJson,
      LPlaceholder,
      LScenario
    ) then
      Exit(
        TRadIAToolResult.Failed(
          'invalid_memory_scenario',
          'The runtime scenario definition is invalid.'
        )
      );
    LWarmupRepetitions := LJson.GetValue<Integer>('warmupRepetitions', 1);
    Result := FCoordinator.Prepare(LScenario, LWarmupRepetitions);
  finally
    LJson.Free;
  end;
end;

function TRadIAMemoryDiagnosticSessionTool.ExecuteRun(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
  LPreviewId: string;
begin
  LJson := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed('invalid_request', 'Arguments must be a JSON object.'));
  try
    LPreviewId := LJson.GetValue<string>('previewId', '');
    Result := FCoordinator.Run(LPreviewId, ARequest.CancellationToken);
  finally
    LJson.Free;
  end;
end;

function TRadIAMemoryDiagnosticSessionTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    mdstkPrepare:
      Result := TRadIAToolDescriptor.Create(
        'PrepareMemoryDiagnosticSession',
        '1.0.0',
        'Previews an instrumented FastMM5 runtime scenario with warmup and measured repetitions.',
        CPrepareInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    mdstkRun:
      Result := TRadIAToolDescriptor.Create(
        'RunMemoryDiagnosticSession',
        '1.0.0',
        'Builds, debugs, reproduces, stops, parses, and reverts a prepared memory diagnostic.',
        CRunInputSchema,
        CObjectOutputSchema,
        trExecution
      ).WithExecutionOptions(1800000, False).WithConsentEveryTime;
    mdstkCancel:
      Result := TRadIAToolDescriptor.Create(
        'CancelMemoryDiagnosticSession',
        '1.0.0',
        'Cancels the active memory diagnostic, debugger, build, and runtime scenario.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trExecution
      ).WithExecutionOptions(30000, False);
    mdstkStatus:
      Result := TRadIAToolDescriptor.Create(
        'GetMemoryDiagnosticSessionStatus',
        '1.0.0',
        'Returns the current composed memory diagnostic phase and cancellation state.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
  end;
end;

procedure RegisterRadIAMemoryDiagnosticSessionTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIAMemoryDiagnosticSessionCoordinator;
  const ARuntimeSession: IRadIARuntimeDebugSessionCoordinator;
  const AWorkspace: IRadIAWorkspaceFacade
);
var
  LKind: TRadIAMemoryDiagnosticSessionToolKind;
begin
  if not Assigned(ARegistry) or
    not Assigned(ACoordinator) or
    not Assigned(ARuntimeSession) or
    not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('Memory diagnostic registration dependencies');
  for LKind := Low(TRadIAMemoryDiagnosticSessionToolKind) to
    High(TRadIAMemoryDiagnosticSessionToolKind) do
    ARegistry.RegisterTool(
      TRadIAMemoryDiagnosticSessionTool.Create(
        LKind,
        ACoordinator,
        ARuntimeSession,
        AWorkspace
      )
    );
end;

end.
