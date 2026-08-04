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
    IRadIAToolExecutor
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
    procedure TestToolCallThenComplete;
    [Test]
    procedure TestMutationRequiresSuccessfulBuildBeforeCompletion;
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
    procedure TestCancelRequestedByExecutingTool;
    [Test]
    procedure TestFileStoreRejectsUnsafeSessionId;
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
  System.SyncObjs,
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
    Assert.Contains(LResult.Message, 'token limit');
    Assert.AreEqual(0, LExecutorObject.CallCount);
    Assert.Contains(LRuntime.SnapshotJson, '"totalTokens":6');
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
begin
  Assert.WillRaise(
    procedure
    begin
      TRadIAAgentServiceDecisionProvider.ParseDecision(
        '{"kind":"unknown"}'
      );
    end,
    EConvertError
  );
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
    TRadIAAgentDecision.CallTool('ApplyPatch', '{"previewId":"p1"}'),
    TRadIAAgentDecision.Complete('Too early.'),
    TRadIAAgentDecision.CallTool('BuildProject', '{"mode":"make"}'),
    TRadIAAgentDecision.Complete('Correction validated.')
  ]);
  LStore := TRadIAMemoryAgentCheckpointStore.Create;
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
