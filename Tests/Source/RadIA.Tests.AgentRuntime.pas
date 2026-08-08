unit RadIA.Tests.AgentRuntime;

interface

uses
  System.Generics.Collections,
  System.SysUtils,
  DUnitX.TestFramework,
  RadIA.Core.AgentRuntime,
  RadIA.Core.Interfaces,
  RadIA.Core.TokenUsage,
  RadIA.Core.Types,
  RadIA.Core.Tools;

type
  TRadIAMockAgentDecisionProvider = class(
    TInterfacedObject,
    IRadIAAgentDecisionProvider
  )
  private
    FDecisions: TQueue<TRadIAAgentDecision>;
    FContextJson: string;
    FDelayMilliseconds: Cardinal;
  public
    constructor Create(const ADecisions: array of TRadIAAgentDecision);
    destructor Destroy; override;
    function NextDecision(
      const AContextJson: string
    ): TRadIAAgentDecision;
    property ContextJson: string read FContextJson;
    property DelayMilliseconds: Cardinal read FDelayMilliseconds
      write FDelayMilliseconds;
  end;

  TRadIAMockAgentToolExecutor = class(
    TInterfacedObject,
    IRadIAToolExecutor,
    IRadIAToolDescriptorProvider
  )
  private
    FCallCount: Integer;
    FResult: TRadIAToolResult;
    FOnExecute: TProc;
  public
    constructor Create(const AResult: TRadIAToolResult);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function TryGetToolDescriptor(
      const AName: string;
      out ADescriptor: TRadIAToolDescriptor
    ): Boolean;
    property CallCount: Integer read FCallCount;
    property OnExecute: TProc read FOnExecute write FOnExecute;
    property ToolResult: TRadIAToolResult read FResult write FResult;
  end;

  TRadIAMemoryAgentCheckpointStore = class(
    TInterfacedObject,
    IRadIAAgentCheckpointStore
  )
  private
    FSessionId: string;
    FSnapshotJson: string;
  public
    procedure Save(
      const ASessionId: string;
      const ASnapshotJson: string
    );
    function TryLoad(
      const ASessionId: string;
      out ASnapshotJson: string
    ): Boolean;
    procedure Delete(const ASessionId: string);
    property SnapshotJson: string read FSnapshotJson;
  end;

  TRadIAPausingAgentObserver = class(
    TInterfacedObject,
    IRadIAAgentObserver
  )
  private
    FRuntime: TRadIAAgentRuntime;
    FPauseOnToolStep: Boolean;
  public
    procedure AgentStateChanged(const ASnapshotJson: string);
    property Runtime: TRadIAAgentRuntime read FRuntime write FRuntime;
    property PauseOnToolStep: Boolean read FPauseOnToolStep
      write FPauseOnToolStep;
  end;

  TRadIAMockAgentService = class(TInterfacedObject, IRadIAService)
  private
    FResponse: string;
    FError: string;
    FPrompt: string;
    FCancelled: Boolean;
    FUsage: TTokenUsage;
  public
    constructor Create(
      const AResponse: string;
      const AError: string = ''
    );
    function GetEffectiveSystemPrompt: string;
    procedure ResolveParameters(
      const AProviderName: string;
      const AProfile: TAIRequestProfile;
      out ATemperature: Double;
      out AMaxTokens: Integer
    );
    function CreateActiveProvider: IRadIAProvider;
    function TrimHistory(
      const AHistory: TArray<IRadIAChatMessage>
    ): TArray<IRadIAChatMessage>;
    procedure SendPrompt(
      const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback;
      const AProfile: TAIRequestProfile = rpGeneralChat
    );
    procedure SendPromptStream(
      const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback;
      const AProfile: TAIRequestProfile = rpGeneralChat
    );
    procedure CancelCurrentRequest;
    procedure ClearCache;
    property Prompt: string read FPrompt;
    property Cancelled: Boolean read FCancelled;
    property Usage: TTokenUsage read FUsage write FUsage;
  end;

  [TestFixture]
  TTestRadIAAgentRuntime = class
  private
    function NewRuntime(
      const AExecutor: IRadIAToolExecutor;
      const AProvider: IRadIAAgentDecisionProvider;
      const AStore: IRadIAAgentCheckpointStore;
      const AObserver: IRadIAAgentObserver = nil
    ): TRadIAAgentRuntime;
  public
    [Test]
    procedure TestLocalDiagnosticPersistsPauseAndResume;
    [Test]
    procedure TestToolCallThenComplete;
    [Test]
    procedure TestMutationRequiresSuccessfulBuildBeforeCompletion;
    [Test]
    procedure TestValidationSnapshotIncludesBuildDUnitXAndCoverageEvidence;
    [Test]
    procedure TestFailedBuildRequiresCorrectionAndSuccessfulRebuild;
    [Test]
    procedure TestToolFailureIsAddedToDecisionContext;
    [Test]
    procedure TestStopsAtStepLimit;
    [Test]
    procedure TestStopsRepeatedToolCalls;
    [Test]
    procedure TestPauseAndResumeFromCheckpoint;
    [Test]
    procedure TestReplayStepAppendsAuditedPausedResult;
    [Test]
    procedure TestCancelRequestedByExecutingTool;
    [Test]
    procedure TestFileStoreRejectsUnsafeSessionId;
    [Test]
    procedure TestFileStoreSearchesSafeCheckpointSummaries;
    [Test]
    procedure TestFileStoreFiltersApprovedCompletedHistoryByProject;
    [Test]
    procedure TestFileStoreUpdatesOnlyPendingValidatedPlan;
    [Test]
    procedure TestProviderParsesToolDecision;
    [Test]
    procedure TestProviderParsesFencedCompletion;
    [Test]
    procedure TestProviderParsesPlan;
    [Test]
    procedure TestProviderRejectsInvalidDecision;
    [Test]
    procedure TestProviderBuildsDecisionFromService;
    [Test]
    procedure TestControllerRunsAgentAsynchronously;
    [Test]
    procedure TestControllerCancellationUnblocksProviderWait;
    [Test]
    procedure TestTokenBudgetStopsBeforePlanExecution;
    [Test]
    procedure TestZeroTokenBudgetAllowsUnlimitedRun;
    [Test]
    procedure TestDurationBudgetStopsAfterSlowDecision;
    [Test]
    procedure TestCostBudgetStopsBeforePlanExecution;
    [Test]
    procedure TestPricingCatalogResolvesWildcardModel;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SyncObjs,
  RadIA.Core.AgentDiagnostic,
  RadIA.Core.AgentController,
  RadIA.Core.AgentPricing,
  RadIA.Core.AgentProvider;

{ TRadIAMockAgentDecisionProvider }

constructor TRadIAMockAgentDecisionProvider.Create(
  const ADecisions: array of TRadIAAgentDecision
);
var
  LDecision: TRadIAAgentDecision;
begin
  inherited Create;
  FDecisions := TQueue<TRadIAAgentDecision>.Create;
  for LDecision in ADecisions do
    FDecisions.Enqueue(LDecision);
end;

destructor TRadIAMockAgentDecisionProvider.Destroy;
begin
  FDecisions.Free;
  inherited Destroy;
end;

function TRadIAMockAgentDecisionProvider.NextDecision(
  const AContextJson: string
): TRadIAAgentDecision;
begin
  FContextJson := AContextJson;
  if FDelayMilliseconds > 0 then
    TThread.Sleep(FDelayMilliseconds);
  if FDecisions.Count = 0 then
    Exit(TRadIAAgentDecision.Fail('No mock decision is available.'));
  Result := FDecisions.Dequeue;
end;

{ TRadIAMockAgentToolExecutor }

constructor TRadIAMockAgentToolExecutor.Create(
  const AResult: TRadIAToolResult
);
begin
  inherited Create;
  FResult := AResult;
end;

function TRadIAMockAgentToolExecutor.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Inc(FCallCount);
  if Assigned(FOnExecute) then
    FOnExecute;
  Result := FResult;
end;

function TRadIAMockAgentToolExecutor.TryGetToolDescriptor(
  const AName: string;
  out ADescriptor: TRadIAToolDescriptor
): Boolean;
var
  LRisk: TRadIAToolRisk;
begin
  Result := Trim(AName) <> '';
  if SameText(AName, 'ApplyPatch') then
    LRisk := trReversibleWrite
  else if SameText(AName, 'BuildProject') or
    SameText(AName, 'RunDUnitXTests') then
    LRisk := trExecution
  else
    LRisk := trReadOnly;
  ADescriptor := TRadIAToolDescriptor.Create(
    AName,
    '1.0.0',
    'Mock agent tool.',
    '{}',
    '{}',
    LRisk
  );
end;

{ TRadIAMemoryAgentCheckpointStore }

procedure TRadIAMemoryAgentCheckpointStore.Delete(
  const ASessionId: string
);
begin
  if FSessionId = ASessionId then
  begin
    FSessionId := '';
    FSnapshotJson := '';
  end;
end;

procedure TRadIAMemoryAgentCheckpointStore.Save(
  const ASessionId: string;
  const ASnapshotJson: string
);
begin
  FSessionId := ASessionId;
  FSnapshotJson := ASnapshotJson;
end;

function TRadIAMemoryAgentCheckpointStore.TryLoad(
  const ASessionId: string;
  out ASnapshotJson: string
): Boolean;
begin
  Result := (FSessionId = ASessionId) and (FSnapshotJson <> '');
  if Result then
    ASnapshotJson := FSnapshotJson
  else
    ASnapshotJson := '';
end;

{ TRadIAPausingAgentObserver }

procedure TRadIAPausingAgentObserver.AgentStateChanged(
  const ASnapshotJson: string
);
begin
  if FPauseOnToolStep and ASnapshotJson.Contains('"index":1') then
  begin
    FPauseOnToolStep := False;
    FRuntime.RequestPause;
  end;
end;

{ TRadIAMockAgentService }

constructor TRadIAMockAgentService.Create(
  const AResponse: string;
  const AError: string
);
begin
  inherited Create;
  FResponse := AResponse;
  FError := AError;
end;

procedure TRadIAMockAgentService.CancelCurrentRequest;
begin
  FCancelled := True;
end;

procedure TRadIAMockAgentService.ClearCache;
begin
  if True then ; // The mock does not maintain a response cache.
end;

function TRadIAMockAgentService.CreateActiveProvider: IRadIAProvider;
begin
  Result := nil;
end;

function TRadIAMockAgentService.GetEffectiveSystemPrompt: string;
begin
  Result := '';
end;

procedure TRadIAMockAgentService.ResolveParameters(
  const AProviderName: string;
  const AProfile: TAIRequestProfile;
  out ATemperature: Double;
  out AMaxTokens: Integer
);
begin
  ATemperature := 0;
  AMaxTokens := 100;
end;

procedure TRadIAMockAgentService.SendPrompt(
  const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TCompletionCallback;
  const AProfile: TAIRequestProfile
);
begin
  FPrompt := APrompt;
  if FResponse = '__wait__' then
    Exit;
  ACallback(
    FResponse,
    FError,
    False,
    FUsage
  );
end;

procedure TRadIAMockAgentService.SendPromptStream(
  const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TStreamChunkCallback;
  const AProfile: TAIRequestProfile
);
begin
  ACallback(FResponse, True, FError);
end;

function TRadIAMockAgentService.TrimHistory(
  const AHistory: TArray<IRadIAChatMessage>
): TArray<IRadIAChatMessage>;
begin
  Result := Copy(AHistory);
end;

{ TTestRadIAAgentRuntime }

procedure TTestRadIAAgentRuntime.TestLocalDiagnosticPersistsPauseAndResume;
var
  LCheckpointDirectory: string;
  LCheckpointPath: string;
  LExecutor: IRadIAToolExecutor;
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LSnapshot: string;
begin
  LCheckpointDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-AgentDiagnostic-' + TGUID.NewGuid.ToString
  );
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded(
      '{"version":"Delphi Test","platform":"Win32"}'
    )
  );
  LExecutor := LExecutorObject;
  try
    RunRadIAAgentRuntimeDiagnostic(
      LExecutor,
      LCheckpointDirectory
    );
    Assert.AreEqual(1, LExecutorObject.CallCount);
    LCheckpointPath := TPath.Combine(
      LCheckpointDirectory,
      'radia-agent-runtime-smoke.json'
    );
    Assert.IsTrue(TFile.Exists(LCheckpointPath));
    LSnapshot := TFile.ReadAllText(LCheckpointPath, TEncoding.UTF8);
    Assert.Contains(LSnapshot, '"status":"completed"');
    Assert.Contains(LSnapshot, '"toolName":"GetIDEState"');
  finally
    LExecutor := nil;
    if TDirectory.Exists(LCheckpointDirectory) then
      TDirectory.Delete(LCheckpointDirectory, True);
  end;
end;

function TTestRadIAAgentRuntime.NewRuntime(
  const AExecutor: IRadIAToolExecutor;
  const AProvider: IRadIAAgentDecisionProvider;
  const AStore: IRadIAAgentCheckpointStore;
  const AObserver: IRadIAAgentObserver
): TRadIAAgentRuntime;
begin
  Result := TRadIAAgentRuntime.Create(
    AExecutor,
    AProvider,
    AStore,
    AObserver
  );
end;

procedure TTestRadIAAgentRuntime.TestCancelRequestedByExecutingTool;
var
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LStore: IRadIAAgentCheckpointStore;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
begin
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LExecutor := LExecutorObject;
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Approve cancellation plan.',
      '[{"title":"Run cancellable tool"}]'
    ),
    TRadIAAgentDecision.CallTool('ReadFile', '{}'),
    TRadIAAgentDecision.Complete('Unexpected completion.')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Cancel safely.',
      'cancel-session',
      'project',
      TRadIAAgentLimits.Default
    );
    Assert.AreEqual(asAwaitingApproval, LResult.Status);
    LExecutorObject.OnExecute :=
      procedure
      begin
        LRuntime.RequestCancel;
      end;
    LResult := LRuntime.Resume('cancel-session');
    Assert.AreEqual(asCancelled, LResult.Status);
    Assert.AreEqual(1, LResult.StepCount);
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestFileStoreRejectsUnsafeSessionId;
var
  LDirectory: string;
  LStore: IRadIAAgentCheckpointStore;
begin
  LDirectory := TPath.Combine(TPath.GetTempPath, 'radia-agent-tests');
  LStore := TRadIAAgentFileCheckpointStore.Create(LDirectory);
  Assert.WillRaise(
    procedure
    begin
      LStore.Save('../unsafe', '{}');
    end,
    EArgumentException
  );
end;

procedure TTestRadIAAgentRuntime.TestFileStoreSearchesSafeCheckpointSummaries;
var
  LDirectory: string;
  LRuns: TArray<TRadIAAgentCheckpointSummary>;
  LStore: TRadIAAgentFileCheckpointStore;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'radia-agent-search-' + TGUID.NewGuid.ToString
  );
  LStore := TRadIAAgentFileCheckpointStore.Create(LDirectory);
  try
    LStore.Save(
      'build-session',
      '{"sessionId":"build-session","objective":"Repair build",' +
      '"projectId":"C:\\Work\\Sample.dproj","planApproved":true,' +
      '"status":"completed","steps":[{"arguments":"secret"}]}'
    );
    LStore.Save(
      'review-session',
      '{"sessionId":"review-session","objective":"Review source",' +
      '"status":"paused","steps":[]}'
    );
    TFile.WriteAllText(
      TPath.Combine(LDirectory, 'corrupt.json'),
      'not-json',
      TEncoding.UTF8
    );

    LRuns := LStore.Search('BUILD');

    Assert.AreEqual<Integer>(1, Length(LRuns));
    Assert.AreEqual('build-session', LRuns[0].SessionId);
    Assert.AreEqual('Repair build', LRuns[0].Objective);
    Assert.AreEqual('completed', LRuns[0].Status);
    Assert.AreEqual('C:\Work\Sample.dproj', LRuns[0].ProjectId);
    Assert.IsTrue(LRuns[0].PlanApproved);
    Assert.AreEqual(1, LRuns[0].StepCount);
    Assert.IsNotEmpty(LRuns[0].UpdatedAtUtc);
  finally
    LStore.Free;
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestRadIAAgentRuntime.
  TestFileStoreFiltersApprovedCompletedHistoryByProject;
var
  LDirectory: string;
  LRuns: TArray<TRadIAAgentCheckpointSummary>;
  LStore: TRadIAAgentFileCheckpointStore;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'radia-approved-history-' + TGUID.NewGuid.ToString
  );
  LStore := TRadIAAgentFileCheckpointStore.Create(LDirectory);
  try
    LStore.Save(
      'approved-complete',
      '{"sessionId":"approved-complete","projectId":"project-a",' +
      '"objective":"Repair approved build","status":"completed",' +
      '"planApproved":true,"steps":[]}'
    );
    LStore.Save(
      'unapproved-complete',
      '{"sessionId":"unapproved-complete","projectId":"project-a",' +
      '"objective":"Unapproved","status":"completed",' +
      '"planApproved":false,"steps":[]}'
    );
    LStore.Save(
      'approved-paused',
      '{"sessionId":"approved-paused","projectId":"project-a",' +
      '"objective":"Paused","status":"paused",' +
      '"planApproved":true,"steps":[]}'
    );
    LStore.Save(
      'other-project',
      '{"sessionId":"other-project","projectId":"project-b",' +
      '"objective":"Other project","status":"completed",' +
      '"planApproved":true,"steps":[]}'
    );

    LRuns := LStore.SearchApproved('project-a', 10);

    Assert.AreEqual<Integer>(1, Length(LRuns));
    Assert.AreEqual('approved-complete', LRuns[0].SessionId);
    Assert.AreEqual('Repair approved build', LRuns[0].Objective);
    Assert.AreEqual('project-a', LRuns[0].ProjectId);
    Assert.IsTrue(LRuns[0].PlanApproved);
    Assert.AreEqual<Integer>(
      0,
      Length(LStore.SearchApproved('project-b', 0))
    );
  finally
    LStore.Free;
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestRadIAAgentRuntime.TestFileStoreUpdatesOnlyPendingValidatedPlan;
var
  LDirectory: string;
  LInvalidRejected: Boolean;
  LRoot: TJSONObject;
  LSnapshot: string;
  LStore: TRadIAAgentFileCheckpointStore;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'radia-agent-plan-' + TGUID.NewGuid.ToString
  );
  LStore := TRadIAAgentFileCheckpointStore.Create(LDirectory);
  try
    LStore.Save(
      'plan-session',
      '{"schemaVersion":1,"sessionId":"plan-session",' +
      '"status":"awaitingApproval","planApproved":false,' +
      '"message":"Approve","plan":[{"title":"Old"}],"steps":[]}'
    );

    LSnapshot := LStore.UpdatePlan(
      'plan-session',
      '[{"title":"Inspect","description":"Read active project"},' +
      '{"title":"Validate","description":"Build and test"}]'
    );
    LRoot := TJSONObject.ParseJSONValue(LSnapshot) as TJSONObject;
    try
      Assert.AreEqual(
        'Plan updated and awaiting approval.',
        LRoot.GetValue<string>('message')
      );
      Assert.AreEqual<Integer>(
        2,
        LRoot.GetValue<TJSONArray>('plan').Count
      );
      Assert.IsFalse(LRoot.GetValue<Boolean>('planApproved'));
    finally
      LRoot.Free;
    end;

    LInvalidRejected := False;
    try
      LStore.UpdatePlan('plan-session', '[{"title":""}]');
    except
      on EArgumentException do
        LInvalidRejected := True;
    end;
    Assert.IsTrue(LInvalidRejected);
  finally
    LStore.Free;
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestRadIAAgentRuntime.TestDurationBudgetStopsAfterSlowDecision;
var
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LExecutor: IRadIAToolExecutor;
  LProviderObject: TRadIAMockAgentDecisionProvider;
  LProvider: IRadIAAgentDecisionProvider;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
  LStore: IRadIAAgentCheckpointStore;
begin
  LProviderObject := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Slow plan.',
      '[{"title":"Inspect"}]'
    )
  ]);
  LProviderObject.DelayMilliseconds := 1050;
  LProvider := LProviderObject;
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LExecutor := LExecutorObject;
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Respect duration budget.',
      'duration-budget-session',
      'project',
      TRadIAAgentLimits.Create(10, 3, 1000, 1000)
    );

    Assert.AreEqual(asFailed, LResult.Status);
    Assert.Contains(LResult.Message, 'duration limit');
    Assert.AreEqual(0, LExecutorObject.CallCount);
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestCostBudgetStopsBeforePlanExecution;
var
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LExecutor: IRadIAToolExecutor;
  LPricing: TRadIAAgentPricing;
  LProvider: IRadIAAgentDecisionProvider;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
  LServiceObject: TRadIAMockAgentService;
  LService: IRadIAService;
  LStore: IRadIAAgentCheckpointStore;
  LUsage: TTokenUsage;
begin
  LServiceObject := TRadIAMockAgentService.Create(
    '{"kind":"plan","message":"Plan.",' +
    '"steps":[{"title":"Inspect"}]}'
  );
  LUsage := TTokenUsage.Empty;
  LUsage.PromptTokens := 4;
  LUsage.CompletionTokens := 2;
  LUsage.TotalTokens := 6;
  LServiceObject.Usage := LUsage;
  LService := LServiceObject;
  LPricing := TRadIAAgentPricing.Create(
    'TestProvider',
    'test-model',
    1,
    1
  );
  LProvider := TRadIAAgentServiceDecisionProvider.Create(
    LService,
    [],
    TRadIAAgentProviderSettings.WithPricing('[]', LPricing)
  );
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LExecutor := LExecutorObject;
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Respect cost budget.',
      'cost-budget-session',
      'project',
      TRadIAAgentLimits.Create(10, 3, 60000, 1000, 5)
    );

    Assert.AreEqual(asFailed, LResult.Status);
    Assert.Contains(LResult.Message, 'cost limit');
    Assert.AreEqual(0, LExecutorObject.CallCount);
    Assert.Contains(LRuntime.SnapshotJson, '"estimatedCostMicros":6');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestPricingCatalogResolvesWildcardModel;
var
  LCatalog: TRadIAAgentPricingCatalog;
  LDirectory: string;
  LFileName: string;
  LPricing: TRadIAAgentPricing;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'radia-pricing-' + TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '')
  );
  LFileName := TPath.Combine(LDirectory, 'agent-pricing.json');
  TDirectory.CreateDirectory(LDirectory);
  try
    TFile.WriteAllText(
      LFileName,
      '{"schemaVersion":1,"currency":"USD","defaultRunBudgetUsd":2.5,' +
      '"prices":[{"provider":"TestProvider","model":"*",' +
      '"inputUsdPerMillionTokens":1.5,' +
      '"outputUsdPerMillionTokens":3.0},' +
      '{"provider":"TestProvider","model":"any-model",' +
      '"inputUsdPerMillionTokens":4.0,' +
      '"outputUsdPerMillionTokens":5.0}]}',
      TEncoding.UTF8
    );
    LCatalog := TRadIAAgentPricingCatalog.Create(LFileName);
    try
      Assert.IsTrue(
        LCatalog.TryResolve('TestProvider', 'any-model', LPricing)
      );
      Assert.AreEqual(Int64(2500000), LCatalog.DefaultRunBudgetMicros);
      Assert.AreEqual(Int64(18), LPricing.EstimateCostMicros(2, 2));
      Assert.IsTrue(
        LCatalog.TryResolve('TestProvider', 'other-model', LPricing)
      );
      Assert.AreEqual(Int64(9), LPricing.EstimateCostMicros(2, 2));
    finally
      LCatalog.Free;
    end;
  finally
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestRadIAAgentRuntime.TestControllerRunsAgentAsynchronously;
var
  LController: IRadIAAgentRunController;
  LDecisionProvider: IRadIAAgentDecisionProvider;
  LEvent: TEvent;
  LExecutor: IRadIAToolExecutor;
  LResult: TRadIAAgentRunResult;
  LService: IRadIAService;
  LStateJson: string;
  LStore: IRadIAAgentCheckpointStore;
begin
  LEvent := TEvent.Create(nil, True, False, '');
  try
    LService := TRadIAMockAgentService.Create(
      '{"kind":"complete","message":"Async objective completed."}'
    );
    LDecisionProvider := TRadIAAgentServiceDecisionProvider.Create(
      LService,
      [],
      TRadIAAgentProviderSettings.Default('[]')
    );
    LExecutor := TRadIAMockAgentToolExecutor.Create(
      TRadIAToolResult.Succeeded('{}')
    );
    LStore := TRadIAMemoryAgentCheckpointStore.Create;
    LController := TRadIAAgentRunController.Create(
      LExecutor,
      LDecisionProvider,
      LStore,
      procedure(const ASnapshotJson: string)
      begin
        LStateJson := ASnapshotJson;
      end,
      procedure(const ARunResult: TRadIAAgentRunResult)
      begin
        LResult := ARunResult;
        LEvent.SetEvent;
      end
    );

    LController.Start(
      'Complete asynchronously.',
      'async-session',
      'project',
      TRadIAAgentLimits.Default
    );

    Assert.AreEqual(wrSignaled, LEvent.WaitFor(5000));
    Assert.AreEqual(asCompleted, LResult.Status);
    Assert.AreEqual('Async objective completed.', LResult.Message);
    Assert.Contains(LStateJson, '"status":"completed"');
  finally
    LController := nil;
    LEvent.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestControllerCancellationUnblocksProviderWait;
var
  LController: IRadIAAgentRunController;
  LDecisionProvider: IRadIAAgentDecisionProvider;
  LEvent: TEvent;
  LExecutor: IRadIAToolExecutor;
  LResult: TRadIAAgentRunResult;
  LServiceObject: TRadIAMockAgentService;
  LService: IRadIAService;
  LStore: IRadIAAgentCheckpointStore;
  LWaitCount: Integer;
begin
  LEvent := TEvent.Create(nil, True, False, '');
  try
    LServiceObject := TRadIAMockAgentService.Create('__wait__');
    LService := LServiceObject;
    LDecisionProvider := TRadIAAgentServiceDecisionProvider.Create(
      LService,
      [],
      TRadIAAgentProviderSettings.Default('[]')
    );
    LExecutor := TRadIAMockAgentToolExecutor.Create(
      TRadIAToolResult.Succeeded('{}')
    );
    LStore := TRadIAMemoryAgentCheckpointStore.Create;
    LController := TRadIAAgentRunController.Create(
      LExecutor,
      LDecisionProvider,
      LStore,
      nil,
      procedure(const ARunResult: TRadIAAgentRunResult)
      begin
        LResult := ARunResult;
        LEvent.SetEvent;
      end
    );
    LController.Start(
      'Wait for cancellation.',
      'cancel-wait-session',
      'project',
      TRadIAAgentLimits.Default
    );
    LWaitCount := 0;
    while (LServiceObject.Prompt = '') and (LWaitCount < 100) do
    begin
      TThread.Sleep(10);
      Inc(LWaitCount);
    end;

    LController.Cancel;

    Assert.AreEqual(wrSignaled, LEvent.WaitFor(5000));
    Assert.AreEqual(asCancelled, LResult.Status);
    Assert.IsTrue(LServiceObject.Cancelled);
  finally
    LController := nil;
    LEvent.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestTokenBudgetStopsBeforePlanExecution;
var
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
  LServiceObject: TRadIAMockAgentService;
  LService: IRadIAService;
  LStore: IRadIAAgentCheckpointStore;
  LUsage: TTokenUsage;
begin
  LServiceObject := TRadIAMockAgentService.Create(
    '{"kind":"plan","message":"Plan.",' +
    '"steps":[{"title":"Inspect"}]}'
  );
  LUsage := TTokenUsage.Empty;
  LUsage.PromptTokens := 4;
  LUsage.CompletionTokens := 2;
  LUsage.TotalTokens := 6;
  LServiceObject.Usage := LUsage;
  LService := LServiceObject;
  LProvider := TRadIAAgentServiceDecisionProvider.Create(
    LService,
    [],
    TRadIAAgentProviderSettings.Default('[]')
  );
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LExecutor := LExecutorObject;
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Respect token budget.',
      'token-budget-session',
      'project',
      TRadIAAgentLimits.Create(10, 3, 60000, 5)
    );

    Assert.AreEqual(asFailed, LResult.Status);
    Assert.Contains(LResult.Message, 'local run token budget');
    Assert.AreEqual(0, LExecutorObject.CallCount);
    Assert.Contains(LRuntime.SnapshotJson, '"totalTokens":6');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestZeroTokenBudgetAllowsUnlimitedRun;
var
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LResult: TRadIAAgentRunResult;
  LRuntime: TRadIAAgentRuntime;
  LServiceObject: TRadIAMockAgentService;
  LStore: IRadIAAgentCheckpointStore;
  LUsage: TTokenUsage;
begin
  LServiceObject := TRadIAMockAgentService.Create(
    '{"kind":"plan","message":"Plan ready.",' +
    '"steps":[{"title":"Inspect"}]}'
  );
  LUsage := TTokenUsage.Empty;
  LUsage.PromptTokens := 150000;
  LUsage.CompletionTokens := 50000;
  LUsage.TotalTokens := 200000;
  LServiceObject.Usage := LUsage;
  LProvider := TRadIAAgentServiceDecisionProvider.Create(
    LServiceObject,
    [],
    TRadIAAgentProviderSettings.Default('[]')
  );
  LExecutor := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Run without a local token budget.',
      'unlimited-token-session',
      'project',
      TRadIAAgentLimits.Create(10, 3, 60000, 0)
    );

    Assert.AreEqual(asAwaitingApproval, LResult.Status);
    Assert.Contains(LRuntime.SnapshotJson, '"maxTotalTokens":0');
    Assert.Contains(LRuntime.SnapshotJson, '"totalTokens":200000');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestPauseAndResumeFromCheckpoint;
var
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LStore: IRadIAAgentCheckpointStore;
  LObserverObject: TRadIAPausingAgentObserver;
  LObserver: IRadIAAgentObserver;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
begin
  LExecutor := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{"value":1}')
  );
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Approve pause plan.',
      '[{"title":"Read current state"}]'
    ),
    TRadIAAgentDecision.CallTool('ReadFile', '{}'),
    TRadIAAgentDecision.Complete('Resumed.')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LObserverObject := TRadIAPausingAgentObserver.Create;
  LObserver := LObserverObject;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore, LObserver);
  try
    LObserverObject.Runtime := LRuntime;
    LObserverObject.PauseOnToolStep := True;
    LResult := LRuntime.Start(
      'Pause and resume.',
      'pause-session',
      'project',
      TRadIAAgentLimits.Default
    );
    Assert.AreEqual(asAwaitingApproval, LResult.Status);

    LResult := LRuntime.Resume('pause-session');
    Assert.AreEqual(asPaused, LResult.Status);
    Assert.AreEqual(1, LResult.StepCount);

    LResult := LRuntime.Resume('pause-session');
    Assert.AreEqual(asCompleted, LResult.Status);
    Assert.AreEqual(1, LResult.StepCount);
  finally
    LObserverObject.Runtime := nil;
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestReplayStepAppendsAuditedPausedResult;
var
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LExecutor: IRadIAToolExecutor;
  LInvalidStateRejected: Boolean;
  LProvider: IRadIAAgentDecisionProvider;
  LResult: TRadIAAgentRunResult;
  LRuntime: TRadIAAgentRuntime;
  LSnapshot: string;
  LStoreObject: TRadIAMemoryAgentCheckpointStore;
  LStore: IRadIAAgentCheckpointStore;
begin
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{"value":"fresh"}')
  );
  LExecutor := LExecutorObject;
  LProvider := TRadIAMockAgentDecisionProvider.Create([]);
  LStoreObject := TRadIAMemoryAgentCheckpointStore.Create;
  LStore := LStoreObject;
  LStore.Save(
    'replay-session',
    '{"schemaVersion":1,"sessionId":"replay-session",' +
    '"projectId":"project","objective":"Inspect","status":"paused",' +
    '"message":"Paused","planApproved":true,' +
    '"plan":[{"title":"Inspect"}],"maxSteps":20,' +
    '"maxRepeatedCalls":3,"maxDurationMilliseconds":900000,' +
    '"maxTotalTokens":100000,"maxEstimatedCostMicros":0,' +
    '"elapsedMilliseconds":10,"promptTokens":0,' +
    '"completionTokens":0,"estimatedCostMicros":0,' +
    '"steps":[{"index":1,"toolName":"ReadFile","arguments":"{}",' +
    '"correlationId":"original","success":true,"result":"{}",' +
    '"errorCode":"","errorMessage":"","mutation":false}]}'
  );
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.ReplayStep('replay-session', 1);

    Assert.AreEqual(asPaused, LResult.Status);
    Assert.AreEqual(2, LResult.StepCount);
    Assert.AreEqual(1, LExecutorObject.CallCount);
    Assert.IsTrue(LStoreObject.TryLoad('replay-session', LSnapshot));
    Assert.Contains(LSnapshot, '"replayOfStepIndex":1');
    Assert.Contains(LSnapshot, 'replayed successfully');
    LStore.Save(
      'replay-session',
      LSnapshot.Replace('"status":"paused"', '"status":"running"')
    );
    LInvalidStateRejected := False;
    try
      LRuntime.ReplayStep('replay-session', 1);
    except
      on EInvalidOp do
        LInvalidStateRejected := True;
    end;
    Assert.IsTrue(LInvalidStateRejected);
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestProviderBuildsDecisionFromService;
var
  LDecision: TRadIAAgentDecision;
  LProvider: IRadIAAgentDecisionProvider;
  LServiceObject: TRadIAMockAgentService;
  LService: IRadIAService;
begin
  LServiceObject := TRadIAMockAgentService.Create(
    '{"kind":"tool","tool":"ReadFile","arguments":{"path":"unit.pas"}}'
  );
  LService := LServiceObject;
  LProvider := TRadIAAgentServiceDecisionProvider.Create(
    LService,
    [],
    TRadIAAgentProviderSettings.Default('[]')
  );

  LDecision := LProvider.NextDecision('{"objective":"Inspect"}');

  Assert.AreEqual(adToolCall, LDecision.Kind);
  Assert.AreEqual('ReadFile', LDecision.ToolName);
  Assert.Contains(LDecision.ArgumentsJson, '"path":"unit.pas"');
  Assert.Contains(LServiceObject.Prompt, 'CURRENT_STATE:');
  Assert.Contains(LServiceObject.Prompt, '{"objective":"Inspect"}');
end;

procedure TTestRadIAAgentRuntime.TestProviderParsesFencedCompletion;
var
  LDecision: TRadIAAgentDecision;
begin
  LDecision := TRadIAAgentServiceDecisionProvider.ParseDecision(
    '```json' + sLineBreak +
    '{"kind":"complete","message":"Finished safely."}' + sLineBreak +
    '```'
  );

  Assert.AreEqual(adComplete, LDecision.Kind);
  Assert.AreEqual('Finished safely.', LDecision.Message);
end;

procedure TTestRadIAAgentRuntime.TestProviderParsesPlan;
var
  LDecision: TRadIAAgentDecision;
begin
  LDecision := TRadIAAgentServiceDecisionProvider.ParseDecision(
    '{"kind":"plan","message":"Review first.",' +
    '"steps":[{"title":"Inspect","description":"Read project state"}]}'
  );

  Assert.AreEqual(adPlan, LDecision.Kind);
  Assert.AreEqual('Review first.', LDecision.Message);
  Assert.Contains(LDecision.PlanJson, '"title":"Inspect"');
end;

procedure TTestRadIAAgentRuntime.TestProviderParsesToolDecision;
var
  LDecision: TRadIAAgentDecision;
begin
  LDecision := TRadIAAgentServiceDecisionProvider.ParseDecision(
    '{"kind":"tool","tool":"BuildProject","arguments":{"wait":true}}'
  );

  Assert.AreEqual(adToolCall, LDecision.Kind);
  Assert.AreEqual('BuildProject', LDecision.ToolName);
  Assert.AreEqual('{"wait":true}', LDecision.ArgumentsJson);
end;

procedure TTestRadIAAgentRuntime.TestProviderRejectsInvalidDecision;
var
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TRadIAAgentServiceDecisionProvider.ParseDecision(
      '{"kind":"unknown"}'
    );
  except
    on EConvertError do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised);
end;

procedure TTestRadIAAgentRuntime.TestStopsAtStepLimit;
var
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LStore: IRadIAAgentCheckpointStore;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
begin
  LExecutor := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Approve limited plan.',
      '[{"title":"Run first tool"},{"title":"Run second tool"}]'
    ),
    TRadIAAgentDecision.CallTool('FirstTool', '{}'),
    TRadIAAgentDecision.CallTool('SecondTool', '{}')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Respect the limit.',
      'limit-session',
      'project',
      TRadIAAgentLimits.Create(1, 3)
    );
    Assert.AreEqual(asAwaitingApproval, LResult.Status);
    LResult := LRuntime.Resume('limit-session');
    Assert.AreEqual(asFailed, LResult.Status);
    Assert.AreEqual(1, LResult.StepCount);
    Assert.Contains(LResult.Message, 'step limit');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestStopsRepeatedToolCalls;
var
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LStore: IRadIAAgentCheckpointStore;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
begin
  LExecutor := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Approve repeated calls.',
      '[{"title":"Read twice"}]'
    ),
    TRadIAAgentDecision.CallTool('ReadFile', '{}'),
    TRadIAAgentDecision.CallTool('ReadFile', '{}')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Detect a loop.',
      'repeat-session',
      'project',
      TRadIAAgentLimits.Create(10, 1)
    );
    Assert.AreEqual(asAwaitingApproval, LResult.Status);
    LResult := LRuntime.Resume('repeat-session');
    Assert.AreEqual(asFailed, LResult.Status);
    Assert.AreEqual(1, LResult.StepCount);
    Assert.Contains(LResult.Message, 'repeated too many times');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestToolCallThenComplete;
var
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LStoreObject: TRadIAMemoryAgentCheckpointStore;
  LStore: IRadIAAgentCheckpointStore;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
begin
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{"text":"content"}')
  );
  LExecutor := LExecutorObject;
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Approve read plan.',
      '[{"title":"Read unit"}]'
    ),
    TRadIAAgentDecision.CallTool('ReadFile', '{"path":"unit.pas"}'),
    TRadIAAgentDecision.Complete('Objective completed.')
  ]);
  LStoreObject := TRadIAMemoryAgentCheckpointStore.Create;
  LStore := LStoreObject;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Read the unit.',
      'complete-session',
      'project',
      TRadIAAgentLimits.Default
    );
    Assert.AreEqual(asAwaitingApproval, LResult.Status);
    Assert.AreEqual(0, LExecutorObject.CallCount);
    LResult := LRuntime.Resume('complete-session');
    Assert.AreEqual(asCompleted, LResult.Status);
    Assert.AreEqual('Objective completed.', LResult.Message);
    Assert.AreEqual(1, LExecutorObject.CallCount);
    Assert.Contains(LStoreObject.SnapshotJson, '"status":"completed"');
    Assert.Contains(
      LStoreObject.SnapshotJson,
      '"startedElapsedMilliseconds":'
    );
    Assert.Contains(LStoreObject.SnapshotJson, '"durationMilliseconds":');
    Assert.Contains(LStoreObject.SnapshotJson, '"mutation":false');
    Assert.Contains(LStoreObject.SnapshotJson, '"risk":"readOnly"');
    Assert.Contains(LStoreObject.SnapshotJson, '"affectedFiles":[]');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.
  TestMutationRequiresSuccessfulBuildBeforeCompletion;
var
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LStoreObject: TRadIAMemoryAgentCheckpointStore;
  LStore: IRadIAAgentCheckpointStore;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
begin
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{"status":"succeeded"}')
  );
  LExecutor := LExecutorObject;
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Approve correction plan.',
      '[{"title":"Correct and validate"}]'
    ),
    TRadIAAgentDecision.CallTool(
      'ApplyPatch',
      '{"previewId":"p1","targetFile":"Source/Unit1.pas"}'
    ),
    TRadIAAgentDecision.Complete('Too early.'),
    TRadIAAgentDecision.CallTool('BuildProject', '{"mode":"make"}'),
    TRadIAAgentDecision.Complete('Correction validated.')
  ]);
  LStoreObject := TRadIAMemoryAgentCheckpointStore.Create;
  LStore := LStoreObject;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Correct the source and validate it.',
      'validation-gate-session',
      'project',
      TRadIAAgentLimits.Default
    );
    Assert.AreEqual(asAwaitingApproval, LResult.Status);
    LResult := LRuntime.Resume('validation-gate-session');
    Assert.AreEqual(asCompleted, LResult.Status);
    Assert.AreEqual('Correction validated.', LResult.Message);
    Assert.AreEqual(2, LExecutorObject.CallCount);
    Assert.Contains(LStoreObject.SnapshotJson, '"risk":"reversibleWrite"');
    Assert.Contains(LStoreObject.SnapshotJson, '"buildStatus":"succeeded"');
    Assert.Contains(
      LStoreObject.SnapshotJson.Replace('\/', '/'),
      '"affectedFiles":["Source/Unit1.pas"]'
    );
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.
  TestValidationSnapshotIncludesBuildDUnitXAndCoverageEvidence;
var
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LResult: TRadIAAgentRunResult;
  LRuntime: TRadIAAgentRuntime;
  LStoreObject: TRadIAMemoryAgentCheckpointStore;
  LStore: IRadIAAgentCheckpointStore;
begin
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{}')
  );
  LExecutorObject.OnExecute :=
    procedure
    begin
      case LExecutorObject.CallCount of
        2:
          LExecutorObject.ToolResult := TRadIAToolResult.Succeeded(
            '{"status":"succeeded","durationMs":1250,' +
            '"messages":[{"text":"Hint"}]}'
          );
        3:
          LExecutorObject.ToolResult := TRadIAToolResult.Succeeded(
            '{"status":"succeeded","durationMs":2400,"report":{' +
            '"total":12,"passed":11,"failed":0,"errors":0,' +
            '"ignored":1}}'
          );
        4:
          LExecutorObject.ToolResult := TRadIAToolResult.Succeeded(
            '{"reportPath":"Output/Coverage/CodeCoverage_Summary.xml",' +
            '"summary":{"sourceFiles":16,"sourceLines":1000,' +
            '"coveredLines":815,"coveredPercent":81}}'
          );
        5:
          LExecutorObject.ToolResult := TRadIAToolResult.Succeeded(
            '{"state":"succeeded","completedActions":2}'
          );
        6:
          LExecutorObject.ToolResult := TRadIAToolResult.Succeeded(
            '{"phase":"verification","debuggerState":"stopped",' +
            '"eventSequence":41}'
          );
        7:
          LExecutorObject.ToolResult := TRadIAToolResult.Succeeded(
            '{"lastSequence":42,"events":[]}'
          );
      else
        LExecutorObject.ToolResult := TRadIAToolResult.Succeeded('{}');
      end;
    end;
  LExecutor := LExecutorObject;
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Approve validation plan.',
      '[{"title":"Change, build, and test"}]'
    ),
    TRadIAAgentDecision.CallTool('ApplyPatch', '{"previewId":"p1"}'),
    TRadIAAgentDecision.CallTool('BuildProject', '{"mode":"make"}'),
    TRadIAAgentDecision.CallTool(
      'RunDUnitXTests',
      '{"executablePath":"tests.exe"}'
    ),
    TRadIAAgentDecision.CallTool('GetCoverageSummary', '{}'),
    TRadIAAgentDecision.CallTool(
      'RunRuntimeScenario',
      '{"previewId":"runtime-preview"}'
    ),
    TRadIAAgentDecision.CallTool(
      'CaptureRuntimeEvidence',
      '{"phase":"verification"}'
    ),
    TRadIAAgentDecision.CallTool('GetDebugTimeline', '{}'),
    TRadIAAgentDecision.Complete('Validation evidence captured.')
  ]);
  LStoreObject := TRadIAMemoryAgentCheckpointStore.Create;
  LStore := LStoreObject;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Capture build and test evidence.',
      'validation-evidence-session',
      'project',
      TRadIAAgentLimits.Default
    );
    Assert.AreEqual(asAwaitingApproval, LResult.Status);
    LResult := LRuntime.Resume('validation-evidence-session');
    Assert.AreEqual(asCompleted, LResult.Status);
    Assert.Contains(LStoreObject.SnapshotJson, '"buildDurationMilliseconds":1250');
    Assert.Contains(LStoreObject.SnapshotJson, '"buildMessageCount":1');
    Assert.Contains(LStoreObject.SnapshotJson, '"testStatus":"succeeded"');
    Assert.Contains(LStoreObject.SnapshotJson, '"testDurationMilliseconds":2400');
    Assert.Contains(LStoreObject.SnapshotJson, '"testTotal":12');
    Assert.Contains(LStoreObject.SnapshotJson, '"testPassed":11');
    Assert.Contains(LStoreObject.SnapshotJson, '"testIgnored":1');
    Assert.Contains(LStoreObject.SnapshotJson, '"coverageAvailable":true');
    Assert.Contains(LStoreObject.SnapshotJson, '"coverageSourceFiles":16');
    Assert.Contains(LStoreObject.SnapshotJson, '"coverageCoveredLines":815');
    Assert.Contains(LStoreObject.SnapshotJson, '"coveragePercent":81');
    Assert.Contains(LStoreObject.SnapshotJson, '"executionRun":true');
    Assert.Contains(LStoreObject.SnapshotJson, '"executionPassed":true');
    Assert.Contains(
      LStoreObject.SnapshotJson,
      '"executionTool":"RunRuntimeScenario"'
    );
    Assert.Contains(LStoreObject.SnapshotJson, '"debugObserved":true');
    Assert.Contains(LStoreObject.SnapshotJson, '"debugState":"stopped"');
    Assert.Contains(LStoreObject.SnapshotJson, '"debugLastSequence":42');
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.
  TestFailedBuildRequiresCorrectionAndSuccessfulRebuild;
var
  LExecutorObject: TRadIAMockAgentToolExecutor;
  LExecutor: IRadIAToolExecutor;
  LProvider: IRadIAAgentDecisionProvider;
  LStore: IRadIAAgentCheckpointStore;
  LRuntime: TRadIAAgentRuntime;
  LResult: TRadIAAgentRunResult;
begin
  LExecutorObject := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Succeeded('{"status":"succeeded"}')
  );
  LExecutorObject.OnExecute :=
    procedure
    begin
      if LExecutorObject.CallCount = 2 then
        LExecutorObject.ToolResult :=
          TRadIAToolResult.Succeeded('{"status":"failed"}')
      else
        LExecutorObject.ToolResult :=
          TRadIAToolResult.Succeeded('{"status":"succeeded"}');
    end;
  LExecutor := LExecutorObject;
  LProvider := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Approve correction plan.',
      '[{"title":"Correct and validate"}]'
    ),
    TRadIAAgentDecision.CallTool('ApplyPatch', '{"previewId":"p1"}'),
    TRadIAAgentDecision.CallTool('BuildProject', '{"mode":"make"}'),
    TRadIAAgentDecision.Complete('Build still failed.'),
    TRadIAAgentDecision.CallTool('ApplyPatch', '{"previewId":"p2"}'),
    TRadIAAgentDecision.CallTool('BuildProject', '{"mode":"make"}'),
    TRadIAAgentDecision.Complete('Correction validated after rebuild.')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LResult := LRuntime.Start(
      'Correct the source after a failed build.',
      'failed-build-session',
      'project',
      TRadIAAgentLimits.Default
    );
    Assert.AreEqual(asAwaitingApproval, LResult.Status);
    LResult := LRuntime.Resume('failed-build-session');
    Assert.AreEqual(asCompleted, LResult.Status);
    Assert.AreEqual(
      'Correction validated after rebuild.',
      LResult.Message
    );
    Assert.AreEqual(4, LExecutorObject.CallCount);
  finally
    LRuntime.Free;
  end;
end;

procedure TTestRadIAAgentRuntime.TestToolFailureIsAddedToDecisionContext;
var
  LExecutor: IRadIAToolExecutor;
  LProviderObject: TRadIAMockAgentDecisionProvider;
  LProvider: IRadIAAgentDecisionProvider;
  LStore: IRadIAAgentCheckpointStore;
  LRuntime: TRadIAAgentRuntime;
begin
  LExecutor := TRadIAMockAgentToolExecutor.Create(
    TRadIAToolResult.Failed('read_failed', 'File is unavailable.')
  );
  LProviderObject := TRadIAMockAgentDecisionProvider.Create([
    TRadIAAgentDecision.Plan(
      'Approve failure handling.',
      '[{"title":"Try reading file"}]'
    ),
    TRadIAAgentDecision.CallTool('ReadFile', '{}'),
    TRadIAAgentDecision.Complete('Handled failure.')
  ]);
  LProvider := LProviderObject;
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
  LRuntime := NewRuntime(LExecutor, LProvider, LStore);
  try
    LRuntime.Start(
      'Handle tool failure.',
      'failure-session',
      'project',
      TRadIAAgentLimits.Default
    );
    LRuntime.Resume('failure-session');
    Assert.Contains(LProviderObject.ContextJson, '"errorCode":"read_failed"');
    Assert.Contains(LProviderObject.ContextJson, 'File is unavailable.');
  finally
    LRuntime.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAAgentRuntime);

end.
