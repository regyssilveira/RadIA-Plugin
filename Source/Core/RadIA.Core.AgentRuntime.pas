unit RadIA.Core.AgentRuntime;

interface

uses
  System.Generics.Collections,
  System.JSON,
  RadIA.Core.AgentResultStore,
  RadIA.Core.ResultCompactor,
  RadIA.Core.Tools;

type
  TRadIAAgentCompactionMetrics = record
    AppliedCount: Integer;
    CompactedCharacters: Int64;
    DurationMicroseconds: Int64;
    OriginalCharacters: Int64;
    RecoverableCount: Integer;
  end;

  TRadIAAgentStatus = (
    asIdle,
    asRunning,
    asAwaitingApproval,
    asPaused,
    asCompleted,
    asFailed,
    asCancelled
  );

  TRadIAAgentDecisionKind = (
    adPlan,
    adToolCall,
    adComplete,
    adFail
  );

  TRadIAAgentDecision = record
  private
    FKind: TRadIAAgentDecisionKind;
    FToolName: string;
    FArgumentsJson: string;
    FMessage: string;
    FPlanJson: string;
  public
    class function Plan(
      const AMessage: string;
      const APlanJson: string
    ): TRadIAAgentDecision; static;
    class function CallTool(
      const AToolName: string;
      const AArgumentsJson: string
    ): TRadIAAgentDecision; static;
    class function Complete(
      const AMessage: string
    ): TRadIAAgentDecision; static;
    class function Fail(
      const AMessage: string
    ): TRadIAAgentDecision; static;
    property Kind: TRadIAAgentDecisionKind read FKind;
    property ToolName: string read FToolName;
    property ArgumentsJson: string read FArgumentsJson;
    property Message: string read FMessage;
    property PlanJson: string read FPlanJson;
  end;

  TRadIAAgentLimits = record
  private
    FMaxSteps: Integer;
    FMaxRepeatedCalls: Integer;
    FMaxDurationMilliseconds: Integer;
    FMaxTotalTokens: Integer;
    FMaxEstimatedCostMicros: Int64;
    FMaxDecisionContextCharacters: Integer;
  public
    constructor Create(
      const AMaxSteps: Integer;
      const AMaxRepeatedCalls: Integer
    ); overload;
    constructor Create(
      const AMaxSteps: Integer;
      const AMaxRepeatedCalls: Integer;
      const AMaxDurationMilliseconds: Integer;
      const AMaxTotalTokens: Integer
    ); overload;
    constructor Create(
      const AMaxSteps: Integer;
      const AMaxRepeatedCalls: Integer;
      const AMaxDurationMilliseconds: Integer;
      const AMaxTotalTokens: Integer;
      const AMaxEstimatedCostMicros: Int64
    ); overload;
    constructor Create(
      const AMaxSteps: Integer;
      const AMaxRepeatedCalls: Integer;
      const AMaxDurationMilliseconds: Integer;
      const AMaxTotalTokens: Integer;
      const AMaxEstimatedCostMicros: Int64;
      const AMaxDecisionContextCharacters: Integer
    ); overload;
    class function Default: TRadIAAgentLimits; static;
    property MaxSteps: Integer read FMaxSteps;
    property MaxRepeatedCalls: Integer read FMaxRepeatedCalls;
    property MaxDurationMilliseconds: Integer
      read FMaxDurationMilliseconds;
    property MaxTotalTokens: Integer read FMaxTotalTokens;
    property MaxEstimatedCostMicros: Int64
      read FMaxEstimatedCostMicros;
    property MaxDecisionContextCharacters: Integer
      read FMaxDecisionContextCharacters;
  end;

  TRadIAAgentRunResult = record
  private
    FStatus: TRadIAAgentStatus;
    FMessage: string;
    FStepCount: Integer;
  public
    constructor Create(
      const AStatus: TRadIAAgentStatus;
      const AMessage: string;
      const AStepCount: Integer
    );
    property Status: TRadIAAgentStatus read FStatus;
    property Message: string read FMessage;
    property StepCount: Integer read FStepCount;
  end;

  IRadIAAgentDecisionProvider = interface
    ['{B49ECA68-48A9-43AA-B515-4492713F86D7}']
    function NextDecision(
      const AContextJson: string
    ): TRadIAAgentDecision;
  end;

  IRadIAAgentUsageProvider = interface
    ['{29701872-59EA-46F2-A585-B76D485B9778}']
    function GetPromptTokens: Integer;
    function GetCompletionTokens: Integer;
    function GetTotalTokens: Integer;
    function GetEstimatedCostMicros: Int64;
    function GetPricingConfigured: Boolean;
  end;

  IRadIAAgentObserver = interface
    ['{0B396732-A83F-4675-A1C0-C4B2364DDAEE}']
    procedure AgentStateChanged(
      const ASnapshotJson: string
    );
  end;

  IRadIAAgentCheckpointStore = interface
    ['{9240630A-E571-4C08-98C6-0DA67FF1450D}']
    procedure Save(
      const ASessionId: string;
      const ASnapshotJson: string
    );
    function TryLoad(
      const ASessionId: string;
      out ASnapshotJson: string
    ): Boolean;
    procedure Delete(const ASessionId: string);
  end;

  IRadIAAgentCancellationControl = interface(
    IRadIAToolCancellationNotifier
  )
    ['{8B64F959-1A49-4BB0-9424-8B2EE0AC4B27}']
    procedure Request;
  end;

  TRadIAAgentCheckpointSummary = record
  private
    FPlanApproved: Boolean;
    FProjectId: string;
    FSessionId: string;
    FObjective: string;
    FStatus: string;
    FStepCount: Integer;
    FUpdatedAtUtc: string;
  public
    constructor Create(
      const ASessionId: string;
      const AObjective: string;
      const AStatus: string;
      const AStepCount: Integer;
      const AUpdatedAtUtc: string;
      const AProjectId: string;
      const APlanApproved: Boolean
    );
    property ProjectId: string read FProjectId;
    property PlanApproved: Boolean read FPlanApproved;
    property SessionId: string read FSessionId;
    property Objective: string read FObjective;
    property Status: string read FStatus;
    property StepCount: Integer read FStepCount;
    property UpdatedAtUtc: string read FUpdatedAtUtc;
  end;

  TRadIAAgentFileCheckpointStore = class(
    TInterfacedObject,
    IRadIAAgentCheckpointStore
  )
  private
    FDirectory: string;
    function CheckpointPath(const ASessionId: string): string;
    function ParseEditablePlan(const APlanJson: string): TJSONArray;
    procedure ValidateSessionId(const ASessionId: string);
  public
    constructor Create(const ADirectory: string);
    procedure Save(
      const ASessionId: string;
      const ASnapshotJson: string
    );
    function TryLoad(
      const ASessionId: string;
      out ASnapshotJson: string
    ): Boolean;
    function Search(
      const AQuery: string
    ): TArray<TRadIAAgentCheckpointSummary>;
    function SearchApproved(
      const AProjectId: string;
      const AMaxCount: Integer
    ): TArray<TRadIAAgentCheckpointSummary>;
    function UpdatePlan(
      const ASessionId: string;
      const APlanJson: string
    ): string;
    procedure Delete(const ASessionId: string);
  end;

  TRadIAAgentRuntime = class
  private type
    TRadIAAgentStep = record
      Index: Integer;
      ToolName: string;
      ArgumentsJson: string;
      CorrelationId: string;
      Success: Boolean;
      ResultJson: string;
      ResultArtifactId: string;
      ResultArtifactHash: string;
      ResultArtifactCharacters: Integer;
      ErrorCode: string;
      ErrorMessage: string;
      StartedElapsedMilliseconds: Int64;
      DurationMilliseconds: Int64;
      Mutation: Boolean;
      ReplayOfStepIndex: Integer;
      Risk: string;
      AffectedFiles: TArray<string>;
    end;
    TRadIAAgentValidationState = record
      MutationPending: Boolean;
      BuildPassed: Boolean;
      BuildStatus: string;
      BuildDurationMilliseconds: Int64;
      BuildMessageCount: Integer;
      TestsRun: Boolean;
      TestsPassed: Boolean;
      TestStatus: string;
      TestDurationMilliseconds: Int64;
      TestTotal: Integer;
      TestPassed: Integer;
      TestFailed: Integer;
      TestErrors: Integer;
      TestIgnored: Integer;
      CoverageAvailable: Boolean;
      CoverageReportPath: string;
      CoverageSourceFiles: Integer;
      CoverageSourceLines: Integer;
      CoverageCoveredLines: Integer;
      CoveragePercent: Integer;
      ExecutionRun: Boolean;
      ExecutionPassed: Boolean;
      ExecutionTool: string;
      ExecutionDurationMilliseconds: Int64;
      DebugObserved: Boolean;
      DebugState: string;
      DebugLastSequence: Int64;
    end;
  private
    FToolExecutor: IRadIAToolExecutor;
    FDescriptorProvider: IRadIAToolDescriptorProvider;
    FDecisionProvider: IRadIAAgentDecisionProvider;
    FUsageProvider: IRadIAAgentUsageProvider;
    FCheckpointStore: IRadIAAgentCheckpointStore;
    FObserver: IRadIAAgentObserver;
    FResultCompactor: IRadIAResultCompactor;
    FResultStore: IRadIAAgentResultStore;
    FCancellationToken: IRadIAAgentCancellationControl;
    FSteps: TList<TRadIAAgentStep>;
    FStatus: TRadIAAgentStatus;
    FObjective: string;
    FSessionId: string;
    FProjectId: string;
    FMessage: string;
    FPlanJson: string;
    FPlanApproved: Boolean;
    FLimits: TRadIAAgentLimits;
    FPauseRequested: Integer;
    FCancelRequested: Integer;
    FLastCallSignature: string;
    FRepeatedCallCount: Integer;
    FElapsedBeforeRunMilliseconds: Int64;
    FRunStartedTimestamp: Int64;
    FPromptTokensBeforeRun: Integer;
    FCompletionTokensBeforeRun: Integer;
    FEstimatedCostMicrosBeforeRun: Int64;
    FValidationRejectionCount: Integer;
    FReplayOfStepIndex: Integer;
    function ExecuteLoop: TRadIAAgentRunResult;
    function ExecuteDecision(
      const ADecision: TRadIAAgentDecision
    ): Boolean;
    function ExecuteToolDecision(
      const ADecision: TRadIAAgentDecision
    ): Boolean;
    function CanContinueLoop: Boolean;
    procedure ExecuteNextDecision;
    procedure HandleCompletionDecision(
      const ADecision: TRadIAAgentDecision
    );
    procedure HandleDecisionException(const AMessage: string);
    procedure HandlePlanDecision(
      const ADecision: TRadIAAgentDecision
    );
    function BuildSnapshotJson(const ACompactResults: Boolean): string;
    function BuildDecisionContextJson: string;
    function BuildValidationJson: TJSONObject;
    function BuildStepsJson(
      const ACompactResults: Boolean;
      const AProfile: TRadIACompactionProfile;
      out AMetrics: TRadIAAgentCompactionMetrics
    ): TJSONArray;
    function BuildStepJson(
      const AStep: TRadIAAgentStep;
      const ACompactResults: Boolean;
      const AProfile: TRadIACompactionProfile;
      const AResultBudget: Integer;
      var AMetrics: TRadIAAgentCompactionMetrics
    ): TJSONObject;
    function BuildCompactedStepResult(
      const AStep: TRadIAAgentStep;
      const AProfile: TRadIACompactionProfile;
      const AResultBudget: Integer;
      out ACompaction: TRadIAResultCompaction;
      out ARuleName: string
    ): string;
    procedure AddCompactionDetails(
      const AStepJson: TJSONObject;
      const AStep: TRadIAAgentStep;
      const ACompaction: TRadIAResultCompaction;
      const ACompactedResult: string;
      const ARuleName: string
    );
    function BuildCallSignature(
      const ADecision: TRadIAAgentDecision
    ): string;
    function CheckRepeatedCall(
      const ADecision: TRadIAAgentDecision
    ): Boolean;
    procedure AddToolStep(
      const ADecision: TRadIAAgentDecision;
      const ACorrelationId: string;
      const AResult: TRadIAToolResult;
      const AStartedElapsedMilliseconds: Int64;
      const ADurationMilliseconds: Int64
    );
    procedure ChangeStatus(
      const AStatus: TRadIAAgentStatus;
      const AMessage: string
    );
    procedure NotifyAndCheckpoint;
    procedure LoadSnapshot(const ASnapshotJson: string);
    function LoadStep(
      const AStepJson: TJSONObject;
      const ADefaultIndex: Integer
    ): TRadIAAgentStep;
    function LoadAffectedFiles(
      const AStepJson: TJSONObject
    ): TArray<string>;
    procedure ResetRun;
    procedure ValidateStart(
      const AObjective: string;
      const ASessionId: string
    );
    function HasValidPlan: Boolean;
    function ElapsedMilliseconds: Int64;
    function CheckBudgets: Boolean;
    function EffectivePromptTokens: Integer;
    function EffectiveCompletionTokens: Integer;
    function EffectiveTotalTokens: Integer;
    function EffectiveEstimatedCostMicros: Int64;
    function AnalyzeValidationState: TRadIAAgentValidationState;
    procedure ResetValidationForMutation(
      var AValidation: TRadIAAgentValidationState
    );
    procedure ApplyValidationEvidence(
      const AStep: TRadIAAgentStep;
      var AValidation: TRadIAAgentValidationState
    );
    procedure ApplyBuildEvidence(
      const AStep: TRadIAAgentStep;
      var AValidation: TRadIAAgentValidationState
    );
    procedure ApplyTestEvidence(
      const AStep: TRadIAAgentStep;
      var AValidation: TRadIAAgentValidationState
    );
    procedure ApplyExecutionEvidence(
      const AStep: TRadIAAgentStep;
      var AValidation: TRadIAAgentValidationState
    );
    procedure ApplyDebugEvidence(
      const AStep: TRadIAAgentStep;
      var AValidation: TRadIAAgentValidationState
    );
    procedure ApplyCoverageEvidence(
      const AStep: TRadIAAgentStep;
      var AValidation: TRadIAAgentValidationState
    );
    function IsMutationTool(const AToolName: string): Boolean;
    function ResolveRiskName(const AToolName: string): string;
    function ExtractAffectedFiles(
      const AArgumentsJson: string;
      const AResultJson: string
    ): TArray<string>;
    procedure CollectFilePaths(
      const AValue: TJSONValue;
      const AKey: string;
      const APaths: TList<string>
    );
    procedure AddUniqueFilePath(
      const APath: string;
      const APaths: TList<string>
    );
    function IsFilePathKey(const AKey: string): Boolean;
    function ValidationAllowsCompletion(
      out AMessage: string
    ): Boolean;
  public
    constructor Create(
      const AToolExecutor: IRadIAToolExecutor;
      const ADecisionProvider: IRadIAAgentDecisionProvider;
      const ACheckpointStore: IRadIAAgentCheckpointStore;
      const AObserver: IRadIAAgentObserver
    ); overload;
    constructor Create(
      const AToolExecutor: IRadIAToolExecutor;
      const ADecisionProvider: IRadIAAgentDecisionProvider;
      const ACheckpointStore: IRadIAAgentCheckpointStore;
      const AObserver: IRadIAAgentObserver;
      const AResultCompactor: IRadIAResultCompactor;
      const AResultStore: IRadIAAgentResultStore
    ); overload;
    destructor Destroy; override;
    function Start(
      const AObjective: string;
      const ASessionId: string;
      const AProjectId: string;
      const ALimits: TRadIAAgentLimits
    ): TRadIAAgentRunResult;
    function Resume(
      const ASessionId: string
    ): TRadIAAgentRunResult;
    function ReplayStep(
      const ASessionId: string;
      const AStepIndex: Integer
    ): TRadIAAgentRunResult;
    procedure RequestPause;
    procedure RequestCancel;
    function SnapshotJson: string;
  end;

function RadIAAgentStatusName(
  const AStatus: TRadIAAgentStatus
): string;

implementation

uses
  System.DateUtils,
  System.Diagnostics,
  System.Generics.Defaults,
  System.IOUtils,
  System.Math,
  System.StrUtils,
  System.SyncObjs,
  System.SysUtils;

type
  TRadIAAgentCancellationToken = class(
    TInterfacedObject,
    IRadIAAgentCancellationControl,
    IRadIAToolCancellationToken,
    IRadIAToolCancellationNotifier
  )
  private
    FCancellationCallback: TRadIAToolCancellationCallback;
    FRequested: Integer;
  public
    procedure ClearCancellationCallback;
    function GetCancellationRequested: Boolean;
    procedure Request;
    procedure SetCancellationCallback(
      const ACallback: TRadIAToolCancellationCallback
    );
  end;

function RadIAAgentStatusName(
  const AStatus: TRadIAAgentStatus
): string;
begin
  case AStatus of
    asIdle:
      Result := 'idle';
    asRunning:
      Result := 'running';
    asAwaitingApproval:
      Result := 'awaitingApproval';
    asPaused:
      Result := 'paused';
    asCompleted:
      Result := 'completed';
    asFailed:
      Result := 'failed';
    asCancelled:
      Result := 'cancelled';
  else
    Result := 'unknown';
  end;
end;

{ TRadIAAgentDecision }

class function TRadIAAgentDecision.Plan(
  const AMessage: string;
  const APlanJson: string
): TRadIAAgentDecision;
begin
  Result := Default(TRadIAAgentDecision);
  Result.FKind := adPlan;
  Result.FMessage := AMessage;
  Result.FPlanJson := APlanJson;
end;

class function TRadIAAgentDecision.CallTool(
  const AToolName: string;
  const AArgumentsJson: string
): TRadIAAgentDecision;
begin
  Result := Default(TRadIAAgentDecision);
  Result.FKind := adToolCall;
  Result.FToolName := AToolName;
  Result.FArgumentsJson := AArgumentsJson;
end;

class function TRadIAAgentDecision.Complete(
  const AMessage: string
): TRadIAAgentDecision;
begin
  Result := Default(TRadIAAgentDecision);
  Result.FKind := adComplete;
  Result.FMessage := AMessage;
end;

class function TRadIAAgentDecision.Fail(
  const AMessage: string
): TRadIAAgentDecision;
begin
  Result := Default(TRadIAAgentDecision);
  Result.FKind := adFail;
  Result.FMessage := AMessage;
end;

{ TRadIAAgentLimits }

constructor TRadIAAgentLimits.Create(
  const AMaxSteps: Integer;
  const AMaxRepeatedCalls: Integer
);
begin
  Self := TRadIAAgentLimits.Create(
    AMaxSteps,
    AMaxRepeatedCalls,
    15 * 60 * 1000,
    100000,
    0,
    120000
  );
end;

constructor TRadIAAgentLimits.Create(
  const AMaxSteps: Integer;
  const AMaxRepeatedCalls: Integer;
  const AMaxDurationMilliseconds: Integer;
  const AMaxTotalTokens: Integer
);
begin
  Self := TRadIAAgentLimits.Create(
    AMaxSteps,
    AMaxRepeatedCalls,
    AMaxDurationMilliseconds,
    AMaxTotalTokens,
    0,
    120000
  );
end;

constructor TRadIAAgentLimits.Create(
  const AMaxSteps: Integer;
  const AMaxRepeatedCalls: Integer;
  const AMaxDurationMilliseconds: Integer;
  const AMaxTotalTokens: Integer;
  const AMaxEstimatedCostMicros: Int64
);
begin
  Self := TRadIAAgentLimits.Create(
    AMaxSteps,
    AMaxRepeatedCalls,
    AMaxDurationMilliseconds,
    AMaxTotalTokens,
    AMaxEstimatedCostMicros,
    120000
  );
end;

constructor TRadIAAgentLimits.Create(
  const AMaxSteps: Integer;
  const AMaxRepeatedCalls: Integer;
  const AMaxDurationMilliseconds: Integer;
  const AMaxTotalTokens: Integer;
  const AMaxEstimatedCostMicros: Int64;
  const AMaxDecisionContextCharacters: Integer
);
begin
  if (AMaxSteps < 1) or (AMaxSteps > 100) then
    raise EArgumentOutOfRangeException.Create(
      'Agent max steps must be between 1 and 100.'
    );
  if (AMaxRepeatedCalls < 1) or (AMaxRepeatedCalls > 10) then
    raise EArgumentOutOfRangeException.Create(
      'Agent repeated call limit must be between 1 and 10.'
    );
  if (AMaxDurationMilliseconds < 1000) or
    (AMaxDurationMilliseconds > 3600000) then
    raise EArgumentOutOfRangeException.Create(
      'Agent duration limit must be between 1000 and 3600000 ms.'
    );
  if (AMaxTotalTokens < 0) or (AMaxTotalTokens > 1000000) then
    raise EArgumentOutOfRangeException.Create(
      'Agent token limit must be between 0 and 1000000; zero disables the limit.'
    );
  if (AMaxEstimatedCostMicros < 0) or
    (AMaxEstimatedCostMicros > Int64(10000) * 1000000) then
    raise EArgumentOutOfRangeException.Create(
      'Agent cost limit must be between USD 0 and 10000.'
    );
  if (AMaxDecisionContextCharacters < 16000) or
    (AMaxDecisionContextCharacters > 1000000) then
    raise EArgumentOutOfRangeException.Create(
      'Agent decision context must be between 16000 and 1000000 characters.'
    );
  FMaxSteps := AMaxSteps;
  FMaxRepeatedCalls := AMaxRepeatedCalls;
  FMaxDurationMilliseconds := AMaxDurationMilliseconds;
  FMaxTotalTokens := AMaxTotalTokens;
  FMaxEstimatedCostMicros := AMaxEstimatedCostMicros;
  FMaxDecisionContextCharacters := AMaxDecisionContextCharacters;
end;

class function TRadIAAgentLimits.Default: TRadIAAgentLimits;
begin
  Result := TRadIAAgentLimits.Create(20, 3);
end;

{ TRadIAAgentRunResult }

constructor TRadIAAgentRunResult.Create(
  const AStatus: TRadIAAgentStatus;
  const AMessage: string;
  const AStepCount: Integer
);
begin
  FStatus := AStatus;
  FMessage := AMessage;
  FStepCount := AStepCount;
end;

{ TRadIAAgentCheckpointSummary }

constructor TRadIAAgentCheckpointSummary.Create(
  const ASessionId: string;
  const AObjective: string;
  const AStatus: string;
  const AStepCount: Integer;
  const AUpdatedAtUtc: string;
  const AProjectId: string;
  const APlanApproved: Boolean
);
begin
  FPlanApproved := APlanApproved;
  FProjectId := AProjectId;
  FSessionId := ASessionId;
  FObjective := AObjective;
  FStatus := AStatus;
  FStepCount := AStepCount;
  FUpdatedAtUtc := AUpdatedAtUtc;
end;

{ TRadIAAgentFileCheckpointStore }

constructor TRadIAAgentFileCheckpointStore.Create(
  const ADirectory: string
);
begin
  inherited Create;
  if Trim(ADirectory) = '' then
    raise EArgumentException.Create(
      'Agent checkpoint directory must not be empty.'
    );
  FDirectory := TPath.GetFullPath(ADirectory);
end;

function TRadIAAgentFileCheckpointStore.CheckpointPath(
  const ASessionId: string
): string;
begin
  ValidateSessionId(ASessionId);
  Result := TPath.Combine(FDirectory, ASessionId + '.json');
end;

procedure TRadIAAgentFileCheckpointStore.Delete(
  const ASessionId: string
);
var
  LPath: string;
begin
  LPath := CheckpointPath(ASessionId);
  if TFile.Exists(LPath) then
    TFile.Delete(LPath);
end;

function TRadIAAgentFileCheckpointStore.ParseEditablePlan(
  const APlanJson: string
): TJSONArray;
const
  MAX_DESCRIPTION_LENGTH = 2000;
  MAX_PLAN_STEPS = 50;
  MAX_TITLE_LENGTH = 200;
var
  LDescription: string;
  LIndex: Integer;
  LPlan: TJSONArray;
  LStep: TJSONObject;
  LTitle: string;
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(APlanJson);
  if not (LValue is TJSONArray) then
  begin
    LValue.Free;
    raise EArgumentException.Create(
      'Agent plan must be a JSON array.'
    );
  end;
  LPlan := TJSONArray(LValue);
  try
    if (LPlan.Count < 1) or (LPlan.Count > MAX_PLAN_STEPS) then
      raise EArgumentException.Create(
        'Agent plan must contain between 1 and 50 steps.'
      );
    for LIndex := 0 to LPlan.Count - 1 do
    begin
      if not (LPlan[LIndex] is TJSONObject) then
        raise EArgumentException.Create(
          'Every agent plan step must be a JSON object.'
        );
      LStep := TJSONObject(LPlan[LIndex]);
      LTitle := Trim(LStep.GetValue<string>('title', ''));
      LDescription := LStep.GetValue<string>('description', '');
      if (LTitle = '') or (Length(LTitle) > MAX_TITLE_LENGTH) then
        raise EArgumentException.Create(
          'Agent plan step titles must contain between 1 and 200 characters.'
        );
      if Length(LDescription) > MAX_DESCRIPTION_LENGTH then
        raise EArgumentException.Create(
          'Agent plan step descriptions must not exceed 2000 characters.'
        );
    end;
  except
    LPlan.Free;
    raise;
  end;
  Result := LPlan;
end;

procedure TRadIAAgentFileCheckpointStore.Save(
  const ASessionId: string;
  const ASnapshotJson: string
);
var
  LPath: string;
begin
  LPath := CheckpointPath(ASessionId);
  TDirectory.CreateDirectory(FDirectory);
  TFile.WriteAllText(
    LPath,
    ASnapshotJson,
    TEncoding.UTF8
  );
end;

function TRadIAAgentFileCheckpointStore.Search(
  const AQuery: string
): TArray<TRadIAAgentCheckpointSummary>;
var
  LFileName: string;
  LFiles: TArray<string>;
  LList: TList<TRadIAAgentCheckpointSummary>;
  LObjective: string;
  LPlanApproved: Boolean;
  LProjectId: string;
  LQuery: string;
  LRoot: TJSONObject;
  LSessionId: string;
  LSnapshot: string;
  LStatus: string;
  LSteps: TJSONArray;
  LSummary: TRadIAAgentCheckpointSummary;
  LValue: TJSONValue;
begin
  Result := [];
  if not TDirectory.Exists(FDirectory) then
    Exit;
  LQuery := Trim(AQuery);
  LFiles := TDirectory.GetFiles(FDirectory, '*.json');
  LList := TList<TRadIAAgentCheckpointSummary>.Create;
  try
    for LFileName in LFiles do
    begin
      LSnapshot := TFile.ReadAllText(LFileName, TEncoding.UTF8);
      LValue := TJSONObject.ParseJSONValue(LSnapshot);
      if not (LValue is TJSONObject) then
      begin
        LValue.Free;
        Continue;
      end;
      LRoot := TJSONObject(LValue);
      try
        LSessionId := LRoot.GetValue<string>(
          'sessionId',
          TPath.GetFileNameWithoutExtension(LFileName)
        );
        LObjective := LRoot.GetValue<string>('objective', '');
        LPlanApproved := LRoot.GetValue<Boolean>('planApproved', False);
        LProjectId := LRoot.GetValue<string>('projectId', '');
        LStatus := LRoot.GetValue<string>('status', 'unknown');
        if (LQuery <> '') and
          not ContainsText(LSessionId, LQuery) and
          not ContainsText(LObjective, LQuery) and
          not ContainsText(LStatus, LQuery) then
          Continue;
        LSteps := LRoot.GetValue('steps') as TJSONArray;
        if Assigned(LSteps) then
          LSummary := TRadIAAgentCheckpointSummary.Create(
            LSessionId,
            LObjective,
            LStatus,
            LSteps.Count,
            DateToISO8601(TFile.GetLastWriteTimeUtc(LFileName), True),
            LProjectId,
            LPlanApproved
          )
        else
          LSummary := TRadIAAgentCheckpointSummary.Create(
            LSessionId,
            LObjective,
            LStatus,
            0,
            DateToISO8601(TFile.GetLastWriteTimeUtc(LFileName), True),
            LProjectId,
            LPlanApproved
          );
        LList.Add(LSummary);
      finally
        LRoot.Free;
      end;
    end;
    LList.Sort(
      TComparer<TRadIAAgentCheckpointSummary>.Construct(
        function(
          const ALeft: TRadIAAgentCheckpointSummary;
          const ARight: TRadIAAgentCheckpointSummary
        ): Integer
        begin
          Result := CompareText(ARight.UpdatedAtUtc, ALeft.UpdatedAtUtc);
        end
      )
    );
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TRadIAAgentFileCheckpointStore.SearchApproved(
  const AProjectId: string;
  const AMaxCount: Integer
): TArray<TRadIAAgentCheckpointSummary>;
var
  LList: TList<TRadIAAgentCheckpointSummary>;
  LSummary: TRadIAAgentCheckpointSummary;
begin
  Result := [];
  if (Trim(AProjectId) = '') or
    (AMaxCount < 1) or
    (AMaxCount > 200) then
    Exit;
  LList := TList<TRadIAAgentCheckpointSummary>.Create;
  try
    for LSummary in Search('') do
    begin
      if LSummary.PlanApproved and
        SameText(LSummary.Status, 'completed') and
        SameText(LSummary.ProjectId, AProjectId) then
        LList.Add(LSummary);
      if LList.Count >= AMaxCount then
        Break;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TRadIAAgentFileCheckpointStore.UpdatePlan(
  const ASessionId: string;
  const APlanJson: string
): string;
var
  LPair: TJSONPair;
  LPlan: TJSONArray;
  LRoot: TJSONObject;
  LSnapshot: string;
  LSteps: TJSONArray;
  LValue: TJSONValue;
begin
  if not TryLoad(ASessionId, LSnapshot) then
    raise EArgumentException.Create(
      'Agent checkpoint was not found for the requested session.'
    );
  LValue := TJSONObject.ParseJSONValue(LSnapshot);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EArgumentException.Create('Agent checkpoint is not valid JSON.');
  end;
  LRoot := TJSONObject(LValue);
  LPlan := nil;
  try
    if LRoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
      raise EArgumentException.Create(
        'Agent checkpoint schema is not supported.'
      );
    if LRoot.GetValue<string>('sessionId', '') <> ASessionId then
      raise EArgumentException.Create(
        'Agent checkpoint session does not match the requested session.'
      );
    if not SameText(
      LRoot.GetValue<string>('status', ''),
      'awaitingApproval'
    ) or LRoot.GetValue<Boolean>('planApproved', False) then
      raise EInvalidOp.Create(
        'Agent plan can only be edited while awaiting approval.'
      );
    LSteps := LRoot.GetValue('steps') as TJSONArray;
    if Assigned(LSteps) and (LSteps.Count > 0) then
      raise EInvalidOp.Create(
        'Agent plan cannot be edited after tool execution has started.'
      );
    LPlan := ParseEditablePlan(APlanJson);
    LPair := LRoot.RemovePair('plan');
    LPair.Free;
    LRoot.AddPair('plan', LPlan);
    LPlan := nil;
    LPair := LRoot.RemovePair('message');
    LPair.Free;
    LRoot.AddPair('message', 'Plan updated and awaiting approval.');
    Result := LRoot.ToJSON;
    Save(ASessionId, Result);
  finally
    LPlan.Free;
    LRoot.Free;
  end;
end;

function TRadIAAgentFileCheckpointStore.TryLoad(
  const ASessionId: string;
  out ASnapshotJson: string
): Boolean;
var
  LPath: string;
begin
  LPath := CheckpointPath(ASessionId);
  Result := TFile.Exists(LPath);
  if Result then
    ASnapshotJson := TFile.ReadAllText(LPath, TEncoding.UTF8)
  else
    ASnapshotJson := '';
end;

procedure TRadIAAgentFileCheckpointStore.ValidateSessionId(
  const ASessionId: string
);
var
  LChar: Char;
begin
  if (ASessionId = '') or (Length(ASessionId) > 80) then
    raise EArgumentException.Create(
      'Agent session id must contain between 1 and 80 characters.'
    );
  for LChar in ASessionId do
  begin
    if not CharInSet(
      LChar,
      ['A'..'Z', 'a'..'z', '0'..'9', '-', '_']
    ) then
      raise EArgumentException.Create(
        'Agent session id contains unsupported characters.'
      );
  end;
end;

{ TRadIAAgentCancellationToken }

function TRadIAAgentCancellationToken.GetCancellationRequested: Boolean;
begin
  Result := TInterlocked.CompareExchange(FRequested, 0, 0) <> 0;
end;

procedure TRadIAAgentCancellationToken.Request;
var
  LCallback: TRadIAToolCancellationCallback;
begin
  TInterlocked.Exchange(FRequested, 1);
  TMonitor.Enter(Self);
  try
    LCallback := FCancellationCallback;
  finally
    TMonitor.Exit(Self);
  end;
  if Assigned(LCallback) then
    LCallback();
end;

procedure TRadIAAgentCancellationToken.ClearCancellationCallback;
begin
  TMonitor.Enter(Self);
  try
    FCancellationCallback := nil;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIAAgentCancellationToken.SetCancellationCallback(
  const ACallback: TRadIAToolCancellationCallback
);
var
  LInvokeNow: Boolean;
begin
  TMonitor.Enter(Self);
  try
    FCancellationCallback := ACallback;
    LInvokeNow := GetCancellationRequested;
  finally
    TMonitor.Exit(Self);
  end;
  if LInvokeNow and Assigned(ACallback) then
    ACallback();
end;

{ TRadIAAgentRuntime }

constructor TRadIAAgentRuntime.Create(
  const AToolExecutor: IRadIAToolExecutor;
  const ADecisionProvider: IRadIAAgentDecisionProvider;
  const ACheckpointStore: IRadIAAgentCheckpointStore;
  const AObserver: IRadIAAgentObserver
);
begin
  Create(
    AToolExecutor,
    ADecisionProvider,
    ACheckpointStore,
    AObserver,
    nil,
    nil
  );
end;

constructor TRadIAAgentRuntime.Create(
  const AToolExecutor: IRadIAToolExecutor;
  const ADecisionProvider: IRadIAAgentDecisionProvider;
  const ACheckpointStore: IRadIAAgentCheckpointStore;
  const AObserver: IRadIAAgentObserver;
  const AResultCompactor: IRadIAResultCompactor;
  const AResultStore: IRadIAAgentResultStore
);
begin
  inherited Create;
  if not Assigned(AToolExecutor) then
    raise EArgumentNilException.Create('AToolExecutor');
  if not Assigned(ADecisionProvider) then
    raise EArgumentNilException.Create('ADecisionProvider');
  if not Assigned(ACheckpointStore) then
    raise EArgumentNilException.Create('ACheckpointStore');

  FToolExecutor := AToolExecutor;
  Supports(
    AToolExecutor,
    IRadIAToolDescriptorProvider,
    FDescriptorProvider
  );
  FDecisionProvider := ADecisionProvider;
  Supports(ADecisionProvider, IRadIAAgentUsageProvider, FUsageProvider);
  FCheckpointStore := ACheckpointStore;
  FObserver := AObserver;
  FResultCompactor := AResultCompactor;
  if not Assigned(FResultCompactor) then
    FResultCompactor := TRadIAResultCompactor.Create;
  FResultStore := AResultStore;
  FSteps := TList<TRadIAAgentStep>.Create;
  FStatus := asIdle;
  FLimits := TRadIAAgentLimits.Default;
end;

destructor TRadIAAgentRuntime.Destroy;
begin
  FSteps.Free;
  inherited Destroy;
end;

procedure TRadIAAgentRuntime.AddToolStep(
  const ADecision: TRadIAAgentDecision;
  const ACorrelationId: string;
  const AResult: TRadIAToolResult;
  const AStartedElapsedMilliseconds: Int64;
  const ADurationMilliseconds: Int64
);
var
  LArtifact: TRadIAAgentResultArtifact;
  LStep: TRadIAAgentStep;
begin
  LStep := Default(TRadIAAgentStep);
  LStep.Index := 1;
  if FSteps.Count > 0 then
    LStep.Index := FSteps.Last.Index + 1;
  LStep.ToolName := ADecision.ToolName;
  LStep.ArgumentsJson := ADecision.ArgumentsJson;
  LStep.CorrelationId := ACorrelationId;
  LStep.Success := AResult.Success;
  LStep.ResultJson := AResult.ContentJson;
  if Assigned(FResultStore) and (LStep.ResultJson <> '') then
  begin
    LArtifact := FResultStore.Store(
      FSessionId,
      LStep.Index,
      LStep.ResultJson
    );
    LStep.ResultArtifactId := LArtifact.ArtifactId;
    LStep.ResultArtifactHash := LArtifact.Hash;
    LStep.ResultArtifactCharacters := LArtifact.CharacterCount;
  end;
  LStep.ErrorCode := AResult.ErrorCode;
  LStep.ErrorMessage := AResult.ErrorMessage;
  LStep.StartedElapsedMilliseconds := AStartedElapsedMilliseconds;
  LStep.DurationMilliseconds := Max(0, ADurationMilliseconds);
  LStep.Mutation := IsMutationTool(ADecision.ToolName);
  LStep.ReplayOfStepIndex := FReplayOfStepIndex;
  LStep.Risk := ResolveRiskName(ADecision.ToolName);
  if LStep.Mutation and LStep.Success then
    LStep.AffectedFiles := ExtractAffectedFiles(
      ADecision.ArgumentsJson,
      AResult.ContentJson
    )
  else
    LStep.AffectedFiles := [];
  FSteps.Add(LStep);
end;

function TRadIAAgentRuntime.AnalyzeValidationState:
  TRadIAAgentValidationState;
var
  LStep: TRadIAAgentStep;
begin
  Result := Default(TRadIAAgentValidationState);
  Result.BuildStatus := 'notRun';
  Result.TestStatus := 'notRun';
  for LStep in FSteps do
  begin
    if IsMutationTool(LStep.ToolName) and LStep.Success then
    begin
      ResetValidationForMutation(Result);
      Continue;
    end;
    if not Result.MutationPending then
      Continue;
    ApplyValidationEvidence(LStep, Result);
  end;
end;

procedure TRadIAAgentRuntime.ResetValidationForMutation(
  var AValidation: TRadIAAgentValidationState
);
begin
  AValidation := Default(TRadIAAgentValidationState);
  AValidation.MutationPending := True;
  AValidation.BuildStatus := 'notRun';
  AValidation.TestStatus := 'notRun';
end;

procedure TRadIAAgentRuntime.ApplyValidationEvidence(
  const AStep: TRadIAAgentStep;
  var AValidation: TRadIAAgentValidationState
);
begin
  if SameText(AStep.ToolName, 'BuildProject') then
    ApplyBuildEvidence(AStep, AValidation)
  else if SameText(AStep.ToolName, 'RunDUnitXTests') then
    ApplyTestEvidence(AStep, AValidation)
  else if SameText(AStep.ToolName, 'GetCoverageSummary') then
    ApplyCoverageEvidence(AStep, AValidation)
  else if SameText(AStep.ToolName, 'StartDebugging') or
    SameText(AStep.ToolName, 'RunRuntimeScenario') then
    ApplyExecutionEvidence(AStep, AValidation)
  else if SameText(AStep.ToolName, 'GetDebuggerState') or
    SameText(AStep.ToolName, 'GetDebugTimeline') or
    SameText(AStep.ToolName, 'WaitForDebuggerEvent') or
    SameText(AStep.ToolName, 'GetRuntimeScenarioStatus') or
    SameText(AStep.ToolName, 'CaptureRuntimeEvidence') or
    SameText(AStep.ToolName, 'CompareRuntimeEvidence') then
    ApplyDebugEvidence(AStep, AValidation);
end;

procedure TRadIAAgentRuntime.ApplyDebugEvidence(
  const AStep: TRadIAAgentStep;
  var AValidation: TRadIAAgentValidationState
);
var
  LRoot: TJSONObject;
begin
  if not AStep.Success then
    Exit;
  LRoot := TJSONObject.ParseJSONValue(AStep.ResultJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    AValidation.DebugObserved := True;
    if SameText(AStep.ToolName, 'GetDebugTimeline') then
      AValidation.DebugLastSequence := LRoot.GetValue<Int64>(
        'lastSequence',
        0
      )
    else
    begin
      AValidation.DebugState := LRoot.GetValue<string>(
        'state',
        LRoot.GetValue<string>(
          'debuggerState',
          LRoot.GetValue<string>('outcome', 'observed')
        )
      );
      AValidation.DebugLastSequence := LRoot.GetValue<Int64>(
        'eventSequence',
        AValidation.DebugLastSequence
      );
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TRadIAAgentRuntime.ApplyExecutionEvidence(
  const AStep: TRadIAAgentStep;
  var AValidation: TRadIAAgentValidationState
);
begin
  AValidation.ExecutionRun := True;
  AValidation.ExecutionPassed := AStep.Success;
  AValidation.ExecutionTool := AStep.ToolName;
  AValidation.ExecutionDurationMilliseconds := AStep.DurationMilliseconds;
end;

procedure TRadIAAgentRuntime.ApplyCoverageEvidence(
  const AStep: TRadIAAgentStep;
  var AValidation: TRadIAAgentValidationState
);
var
  LRoot: TJSONObject;
  LSummary: TJSONObject;
  LValue: TJSONValue;
begin
  if not AStep.Success then
    Exit;
  LRoot := TJSONObject.ParseJSONValue(AStep.ResultJson) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    LValue := LRoot.GetValue('summary');
    if not (LValue is TJSONObject) then
      Exit;
    LSummary := TJSONObject(LValue);
    AValidation.CoverageAvailable := True;
    AValidation.CoverageReportPath := LRoot.GetValue<string>(
      'reportPath',
      ''
    );
    AValidation.CoverageSourceFiles := LSummary.GetValue<Integer>(
      'sourceFiles',
      0
    );
    AValidation.CoverageSourceLines := LSummary.GetValue<Integer>(
      'sourceLines',
      0
    );
    AValidation.CoverageCoveredLines := LSummary.GetValue<Integer>(
      'coveredLines',
      0
    );
    AValidation.CoveragePercent := LSummary.GetValue<Integer>(
      'coveredPercent',
      0
    );
  finally
    LRoot.Free;
  end;
end;

procedure TRadIAAgentRuntime.ApplyBuildEvidence(
  const AStep: TRadIAAgentStep;
  var AValidation: TRadIAAgentValidationState
);
var
  LMessages: TJSONArray;
  LRoot: TJSONObject;
  LValue: TJSONValue;
begin
  AValidation.BuildStatus := 'failed';
  AValidation.BuildDurationMilliseconds := AStep.DurationMilliseconds;
  AValidation.BuildMessageCount := 0;
  LRoot := TJSONObject.ParseJSONValue(AStep.ResultJson) as TJSONObject;
  if not Assigned(LRoot) then
  begin
    AValidation.BuildPassed := False;
    Exit;
  end;
  try
    AValidation.BuildStatus := LRoot.GetValue<string>('status', 'failed');
    AValidation.BuildDurationMilliseconds := LRoot.GetValue<Int64>(
      'durationMs',
      AStep.DurationMilliseconds
    );
    LValue := LRoot.GetValue('messages');
    if LValue is TJSONArray then
    begin
      LMessages := TJSONArray(LValue);
      AValidation.BuildMessageCount := LMessages.Count;
    end;
    AValidation.BuildPassed := AStep.Success and
      SameText(AValidation.BuildStatus, 'succeeded');
  finally
    LRoot.Free;
  end;
end;

procedure TRadIAAgentRuntime.ApplyTestEvidence(
  const AStep: TRadIAAgentStep;
  var AValidation: TRadIAAgentValidationState
);
var
  LReport: TJSONObject;
  LRoot: TJSONObject;
  LValue: TJSONValue;
begin
  AValidation.TestsRun := True;
  AValidation.TestStatus := 'failed';
  AValidation.TestDurationMilliseconds := AStep.DurationMilliseconds;
  LRoot := TJSONObject.ParseJSONValue(AStep.ResultJson) as TJSONObject;
  if not Assigned(LRoot) then
  begin
    AValidation.TestsPassed := False;
    Exit;
  end;
  try
    AValidation.TestStatus := LRoot.GetValue<string>('status', 'failed');
    AValidation.TestDurationMilliseconds := LRoot.GetValue<Int64>(
      'durationMs',
      AStep.DurationMilliseconds
    );
    LValue := LRoot.GetValue('report');
    if LValue is TJSONObject then
    begin
      LReport := TJSONObject(LValue);
      AValidation.TestTotal := LReport.GetValue<Integer>('total', 0);
      AValidation.TestPassed := LReport.GetValue<Integer>('passed', 0);
      AValidation.TestFailed := LReport.GetValue<Integer>('failed', 0);
      AValidation.TestErrors := LReport.GetValue<Integer>('errors', 0);
      AValidation.TestIgnored := LReport.GetValue<Integer>('ignored', 0);
    end;
    AValidation.TestsPassed := AStep.Success and
      SameText(AValidation.TestStatus, 'succeeded');
  finally
    LRoot.Free;
  end;
end;

function TRadIAAgentRuntime.BuildCallSignature(
  const ADecision: TRadIAAgentDecision
): string;
begin
  Result := LowerCase(Trim(ADecision.ToolName)) + #10 +
    Trim(ADecision.ArgumentsJson);
end;

function TRadIAAgentRuntime.BuildDecisionContextJson: string;
begin
  Result := BuildSnapshotJson(True);
end;

procedure TRadIAAgentRuntime.AddCompactionDetails(
  const AStepJson: TJSONObject;
  const AStep: TRadIAAgentStep;
  const ACompaction: TRadIAResultCompaction;
  const ACompactedResult: string;
  const ARuleName: string
);
var
  LCompactionJson: TJSONObject;
begin
  LCompactionJson := TJSONObject.Create;
  LCompactionJson.AddPair('applied', TJSONBool.Create(True));
  LCompactionJson.AddPair(
    'originalCharacters',
    TJSONNumber.Create(ACompaction.OriginalCharacters)
  );
  LCompactionJson.AddPair(
    'compactedCharacters',
    TJSONNumber.Create(Length(ACompactedResult))
  );
  LCompactionJson.AddPair('rule', ARuleName);
  LCompactionJson.AddPair(
    'durationMicroseconds',
    TJSONNumber.Create(ACompaction.DurationMicroseconds)
  );
  if AStep.ResultArtifactId <> '' then
  begin
    LCompactionJson.AddPair('fullResultAvailable', TJSONBool.Create(True));
    LCompactionJson.AddPair('artifactId', AStep.ResultArtifactId);
    LCompactionJson.AddPair('artifactHash', AStep.ResultArtifactHash);
    LCompactionJson.AddPair('recoveryTool', 'GetToolResultRange');
  end;
  AStepJson.AddPair('resultCompaction', LCompactionJson);
end;

function TRadIAAgentRuntime.BuildCompactedStepResult(
  const AStep: TRadIAAgentStep;
  const AProfile: TRadIACompactionProfile;
  const AResultBudget: Integer;
  out ACompaction: TRadIAResultCompaction;
  out ARuleName: string
): string;
var
  LEnvelopeJson: TJSONObject;
begin
  ACompaction := FResultCompactor.CompactResult(
    AStep.ToolName,
    AStep.ResultJson,
    AProfile
  );
  Result := ACompaction.CompactedJson;
  ARuleName := ACompaction.RuleName;
  if (AProfile = cpOff) or (Length(Result) <= AResultBudget) or
    (AStep.ResultArtifactId = '') then
    Exit;
  LEnvelopeJson := TJSONObject.Create;
  try
    LEnvelopeJson.AddPair('compactedHistory', TJSONBool.Create(True));
    LEnvelopeJson.AddPair('toolName', AStep.ToolName);
    LEnvelopeJson.AddPair('success', TJSONBool.Create(AStep.Success));
    LEnvelopeJson.AddPair('artifactId', AStep.ResultArtifactId);
    LEnvelopeJson.AddPair('artifactHash', AStep.ResultArtifactHash);
    LEnvelopeJson.AddPair(
      'originalCharacters',
      TJSONNumber.Create(Length(AStep.ResultJson))
    );
    Result := LEnvelopeJson.ToJSON;
    ARuleName := 'context-budget';
  finally
    LEnvelopeJson.Free;
  end;
end;

function TRadIAAgentRuntime.BuildStepJson(
  const AStep: TRadIAAgentStep;
  const ACompactResults: Boolean;
  const AProfile: TRadIACompactionProfile;
  const AResultBudget: Integer;
  var AMetrics: TRadIAAgentCompactionMetrics
): TJSONObject;
var
  LCompactedResult: string;
  LCompaction: TRadIAResultCompaction;
  LFile: string;
  LFileArray: TJSONArray;
  LRuleName: string;
begin
  Result := TJSONObject.Create;
  Result.AddPair('index', TJSONNumber.Create(AStep.Index));
  Result.AddPair('toolName', AStep.ToolName);
  Result.AddPair('arguments', AStep.ArgumentsJson);
  Result.AddPair('correlationId', AStep.CorrelationId);
  Result.AddPair('success', TJSONBool.Create(AStep.Success));
  if ACompactResults then
  begin
    LCompactedResult := BuildCompactedStepResult(
      AStep,
      AProfile,
      AResultBudget,
      LCompaction,
      LRuleName
    );
    if SameText(LRuleName, 'context-budget') then
    begin
      Inc(AMetrics.AppliedCount);
      Inc(AMetrics.OriginalCharacters, Length(AStep.ResultJson));
      Inc(AMetrics.CompactedCharacters, Length(LCompactedResult));
      Inc(AMetrics.DurationMicroseconds, LCompaction.DurationMicroseconds);
      Inc(AMetrics.RecoverableCount);
      Result.Free;
      Result := TJSONObject.Create;
      Result.AddPair('index', TJSONNumber.Create(AStep.Index));
      Result.AddPair('toolName', AStep.ToolName);
      Result.AddPair('success', TJSONBool.Create(AStep.Success));
      Result.AddPair('compactedHistory', TJSONBool.Create(True));
      Result.AddPair('artifactId', AStep.ResultArtifactId);
      Exit;
    end;
    Result.AddPair('result', LCompactedResult);
    if LCompaction.Compacted or
      (LCompactedResult <> LCompaction.CompactedJson) then
    begin
      Inc(AMetrics.AppliedCount);
      Inc(AMetrics.OriginalCharacters, Length(AStep.ResultJson));
      Inc(AMetrics.CompactedCharacters, Length(LCompactedResult));
      Inc(AMetrics.DurationMicroseconds, LCompaction.DurationMicroseconds);
      if AStep.ResultArtifactId <> '' then
        Inc(AMetrics.RecoverableCount);
      AddCompactionDetails(
        Result,
        AStep,
        LCompaction,
        LCompactedResult,
        LRuleName
      );
    end;
  end
  else
  begin
    Result.AddPair('result', AStep.ResultJson);
    if AStep.ResultArtifactId <> '' then
    begin
      Result.AddPair('resultArtifactId', AStep.ResultArtifactId);
      Result.AddPair('resultArtifactHash', AStep.ResultArtifactHash);
      Result.AddPair(
        'resultArtifactCharacters',
        TJSONNumber.Create(AStep.ResultArtifactCharacters)
      );
    end;
  end;
  Result.AddPair('errorCode', AStep.ErrorCode);
  Result.AddPair('errorMessage', AStep.ErrorMessage);
  Result.AddPair(
    'startedElapsedMilliseconds',
    TJSONNumber.Create(AStep.StartedElapsedMilliseconds)
  );
  Result.AddPair(
    'durationMilliseconds',
    TJSONNumber.Create(AStep.DurationMilliseconds)
  );
  Result.AddPair('mutation', TJSONBool.Create(AStep.Mutation));
  Result.AddPair(
    'replayOfStepIndex',
    TJSONNumber.Create(AStep.ReplayOfStepIndex)
  );
  Result.AddPair('risk', AStep.Risk);
  LFileArray := TJSONArray.Create;
  for LFile in AStep.AffectedFiles do
    LFileArray.Add(LFile);
  Result.AddPair('affectedFiles', LFileArray);
end;

function TRadIAAgentRuntime.BuildStepsJson(
  const ACompactResults: Boolean;
  const AProfile: TRadIACompactionProfile;
  out AMetrics: TRadIAAgentCompactionMetrics
): TJSONArray;
var
  LResultBudget: Integer;
  LStep: TRadIAAgentStep;
  LStepCount: Integer;
begin
  AMetrics := Default(TRadIAAgentCompactionMetrics);
  LStepCount := 0;
  for LStep in FSteps do
    Inc(LStepCount);
  LResultBudget := Min(
    24000,
    Max(
      512,
      (FLimits.MaxDecisionContextCharacters - 40000) div
        Max(1, LStepCount)
    )
  );
  if AProfile = cpBalanced then
    LResultBudget := Max(512, LResultBudget div 2);
  Result := TJSONArray.Create;
  for LStep in FSteps do
    Result.AddElement(
      BuildStepJson(
        LStep,
        ACompactResults,
        AProfile,
        LResultBudget,
        AMetrics
      )
    );
end;

function TRadIAAgentRuntime.BuildValidationJson: TJSONObject;
var
  LValidation: TRadIAAgentValidationState;
begin
  LValidation := AnalyzeValidationState;
  Result := TJSONObject.Create;
  Result.AddPair(
    'mutationPending',
    TJSONBool.Create(LValidation.MutationPending)
  );
  Result.AddPair('buildPassed', TJSONBool.Create(LValidation.BuildPassed));
  Result.AddPair('buildStatus', LValidation.BuildStatus);
  Result.AddPair(
    'buildDurationMilliseconds',
    TJSONNumber.Create(LValidation.BuildDurationMilliseconds)
  );
  Result.AddPair(
    'buildMessageCount',
    TJSONNumber.Create(LValidation.BuildMessageCount)
  );
  Result.AddPair('testsRun', TJSONBool.Create(LValidation.TestsRun));
  Result.AddPair('testsPassed', TJSONBool.Create(LValidation.TestsPassed));
  Result.AddPair('testStatus', LValidation.TestStatus);
  Result.AddPair(
    'testDurationMilliseconds',
    TJSONNumber.Create(LValidation.TestDurationMilliseconds)
  );
  Result.AddPair('testTotal', TJSONNumber.Create(LValidation.TestTotal));
  Result.AddPair('testPassed', TJSONNumber.Create(LValidation.TestPassed));
  Result.AddPair('testFailed', TJSONNumber.Create(LValidation.TestFailed));
  Result.AddPair('testErrors', TJSONNumber.Create(LValidation.TestErrors));
  Result.AddPair('testIgnored', TJSONNumber.Create(LValidation.TestIgnored));
  Result.AddPair(
    'coverageAvailable',
    TJSONBool.Create(LValidation.CoverageAvailable)
  );
  Result.AddPair('coverageReportPath', LValidation.CoverageReportPath);
  Result.AddPair(
    'coverageSourceFiles',
    TJSONNumber.Create(LValidation.CoverageSourceFiles)
  );
  Result.AddPair(
    'coverageSourceLines',
    TJSONNumber.Create(LValidation.CoverageSourceLines)
  );
  Result.AddPair(
    'coverageCoveredLines',
    TJSONNumber.Create(LValidation.CoverageCoveredLines)
  );
  Result.AddPair(
    'coveragePercent',
    TJSONNumber.Create(LValidation.CoveragePercent)
  );
  Result.AddPair('executionRun', TJSONBool.Create(LValidation.ExecutionRun));
  Result.AddPair(
    'executionPassed',
    TJSONBool.Create(LValidation.ExecutionPassed)
  );
  Result.AddPair('executionTool', LValidation.ExecutionTool);
  Result.AddPair(
    'executionDurationMilliseconds',
    TJSONNumber.Create(LValidation.ExecutionDurationMilliseconds)
  );
  Result.AddPair('debugObserved', TJSONBool.Create(LValidation.DebugObserved));
  Result.AddPair('debugState', LValidation.DebugState);
  Result.AddPair(
    'debugLastSequence',
    TJSONNumber.Create(LValidation.DebugLastSequence)
  );
end;

function TRadIAAgentRuntime.BuildSnapshotJson(
  const ACompactResults: Boolean
): string;
var
  LMetricsJson: TJSONObject;
  LMetrics: TRadIAAgentCompactionMetrics;
  LProfile: TRadIACompactionProfile;
  LRoot: TJSONObject;
  LStepArray: TJSONArray;
begin
  if ACompactResults then
    LProfile := RadIAResolveCompactionProfile
  else
    LProfile := cpOff;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('schemaVersion', TJSONNumber.Create(1));
    LRoot.AddPair('sessionId', FSessionId);
    LRoot.AddPair('projectId', FProjectId);
    LRoot.AddPair('objective', FObjective);
    LRoot.AddPair('status', RadIAAgentStatusName(FStatus));
    LRoot.AddPair('message', FMessage);
    LRoot.AddPair('planApproved', TJSONBool.Create(FPlanApproved));
    if HasValidPlan then
      LRoot.AddPair(
        'plan',
        TJSONObject.ParseJSONValue(FPlanJson)
      )
    else
      LRoot.AddPair('plan', TJSONArray.Create);
    LRoot.AddPair('maxSteps', TJSONNumber.Create(FLimits.MaxSteps));
    LRoot.AddPair(
      'maxRepeatedCalls',
      TJSONNumber.Create(FLimits.MaxRepeatedCalls)
    );
    LRoot.AddPair(
      'maxDurationMilliseconds',
      TJSONNumber.Create(FLimits.MaxDurationMilliseconds)
    );
    LRoot.AddPair(
      'maxTotalTokens',
      TJSONNumber.Create(FLimits.MaxTotalTokens)
    );
    LRoot.AddPair(
      'maxEstimatedCostMicros',
      TJSONNumber.Create(FLimits.MaxEstimatedCostMicros)
    );
    LRoot.AddPair(
      'maxDecisionContextCharacters',
      TJSONNumber.Create(FLimits.MaxDecisionContextCharacters)
    );
    LRoot.AddPair(
      'elapsedMilliseconds',
      TJSONNumber.Create(ElapsedMilliseconds)
    );
    LRoot.AddPair(
      'promptTokens',
      TJSONNumber.Create(EffectivePromptTokens)
    );
    LRoot.AddPair(
      'completionTokens',
      TJSONNumber.Create(EffectiveCompletionTokens)
    );
    LRoot.AddPair(
      'totalTokens',
      TJSONNumber.Create(EffectiveTotalTokens)
    );
    LRoot.AddPair(
      'estimatedCostMicros',
      TJSONNumber.Create(EffectiveEstimatedCostMicros)
    );
    LRoot.AddPair(
      'pricingConfigured',
      TJSONBool.Create(
        Assigned(FUsageProvider) and
        FUsageProvider.GetPricingConfigured
      )
    );
    LRoot.AddPair('validation', BuildValidationJson);
    LStepArray := BuildStepsJson(ACompactResults, LProfile, LMetrics);
    LRoot.AddPair('steps', LStepArray);
    if ACompactResults then
    begin
      LMetricsJson := TJSONObject.Create;
      LMetricsJson.AddPair('profile', RadIACompactionProfileName(LProfile));
      LMetricsJson.AddPair(
        'appliedCount',
        TJSONNumber.Create(LMetrics.AppliedCount)
      );
      LMetricsJson.AddPair(
        'originalCharacters',
        TJSONNumber.Create(LMetrics.OriginalCharacters)
      );
      LMetricsJson.AddPair(
        'compactedCharacters',
        TJSONNumber.Create(LMetrics.CompactedCharacters)
      );
      LMetricsJson.AddPair(
        'durationMicroseconds',
        TJSONNumber.Create(LMetrics.DurationMicroseconds)
      );
      LMetricsJson.AddPair(
        'maximumContextCharacters',
        TJSONNumber.Create(FLimits.MaxDecisionContextCharacters)
      );
      if LMetrics.RecoverableCount > 0 then
      begin
        LMetricsJson.AddPair('historyRule', 'context-budget');
        LMetricsJson.AddPair('fullResultAvailable', TJSONBool.Create(True));
        LMetricsJson.AddPair('recoveryTool', 'GetToolResultRange');
      end;
      LRoot.AddPair('resultCompactionMetrics', LMetricsJson);
    end;
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

procedure TRadIAAgentRuntime.ChangeStatus(
  const AStatus: TRadIAAgentStatus;
  const AMessage: string
);
begin
  if (AStatus <> asRunning) and (FRunStartedTimestamp > 0) then
  begin
    FElapsedBeforeRunMilliseconds := ElapsedMilliseconds;
    FRunStartedTimestamp := 0;
  end;
  FStatus := AStatus;
  FMessage := AMessage;
  NotifyAndCheckpoint;
end;

function TRadIAAgentRuntime.CheckBudgets: Boolean;
begin
  Result := False;
  if ElapsedMilliseconds >= FLimits.MaxDurationMilliseconds then
  begin
    ChangeStatus(
      asFailed,
      'Agent stopped after reaching the configured duration limit.'
    );
    Exit;
  end;
  if (FLimits.MaxTotalTokens > 0) and
    (EffectiveTotalTokens >= FLimits.MaxTotalTokens) then
  begin
    ChangeStatus(
      asFailed,
      'Agent stopped after reaching the configured local run token budget.'
    );
    Exit;
  end;
  if FLimits.MaxEstimatedCostMicros > 0 then
  begin
    if not Assigned(FUsageProvider) or
      not FUsageProvider.GetPricingConfigured then
    begin
      ChangeStatus(
        asFailed,
        'Agent cost budget requires pricing for the active provider and model.'
      );
      Exit;
    end;
    if EffectiveEstimatedCostMicros >=
      FLimits.MaxEstimatedCostMicros then
    begin
      ChangeStatus(
        asFailed,
        'Agent stopped after reaching the configured cost limit.'
      );
      Exit;
    end;
  end;
  Result := True;
end;

function TRadIAAgentRuntime.EffectiveEstimatedCostMicros: Int64;
begin
  Result := FEstimatedCostMicrosBeforeRun;
  if Assigned(FUsageProvider) then
    Result := Max(
      Result,
      FUsageProvider.GetEstimatedCostMicros
    );
end;

function TRadIAAgentRuntime.EffectiveCompletionTokens: Integer;
begin
  Result := FCompletionTokensBeforeRun;
  if Assigned(FUsageProvider) then
    Result := Max(Result, FUsageProvider.GetCompletionTokens);
end;

function TRadIAAgentRuntime.EffectivePromptTokens: Integer;
begin
  Result := FPromptTokensBeforeRun;
  if Assigned(FUsageProvider) then
    Result := Max(Result, FUsageProvider.GetPromptTokens);
end;

function TRadIAAgentRuntime.EffectiveTotalTokens: Integer;
begin
  Result := EffectivePromptTokens + EffectiveCompletionTokens;
end;

function TRadIAAgentRuntime.CheckRepeatedCall(
  const ADecision: TRadIAAgentDecision
): Boolean;
var
  LSignature: string;
begin
  LSignature := BuildCallSignature(ADecision);
  if LSignature = FLastCallSignature then
    Inc(FRepeatedCallCount)
  else
  begin
    FLastCallSignature := LSignature;
    FRepeatedCallCount := 1;
  end;
  Result := FRepeatedCallCount <= FLimits.MaxRepeatedCalls;
end;

function TRadIAAgentRuntime.CanContinueLoop: Boolean;
begin
  Result := False;
  if not CheckBudgets then
    Exit;
  if TInterlocked.CompareExchange(FCancelRequested, 0, 0) <> 0 then
  begin
    ChangeStatus(asCancelled, 'Agent run was cancelled.');
    Exit;
  end;
  if TInterlocked.CompareExchange(FPauseRequested, 0, 0) <> 0 then
  begin
    ChangeStatus(asPaused, 'Agent run was paused.');
    Exit;
  end;
  if FSteps.Count >= FLimits.MaxSteps then
  begin
    ChangeStatus(
      asFailed,
      'Agent stopped after reaching the configured step limit.'
    );
    Exit;
  end;
  Result := True;
end;

function TRadIAAgentRuntime.ExecuteDecision(
  const ADecision: TRadIAAgentDecision
): Boolean;
begin
  Result := False;
  case ADecision.Kind of
    adPlan:
      HandlePlanDecision(ADecision);
    adToolCall:
      if not FPlanApproved or not HasValidPlan then
        ChangeStatus(
          asFailed,
          'Agent must present an approved plan before calling tools.'
        )
      else
        Result := ExecuteToolDecision(ADecision);
    adComplete:
      HandleCompletionDecision(ADecision);
    adFail:
      ChangeStatus(asFailed, ADecision.Message);
  else
    ChangeStatus(asFailed, 'Agent returned an unsupported decision.');
  end;
end;

procedure TRadIAAgentRuntime.ExecuteNextDecision;
var
  LDecision: TRadIAAgentDecision;
begin
  try
    LDecision := FDecisionProvider.NextDecision(BuildDecisionContextJson);
    if CheckBudgets then
      ExecuteDecision(LDecision);
  except
    on E: Exception do
      HandleDecisionException(E.Message);
  end;
end;

function TRadIAAgentRuntime.ExecuteLoop: TRadIAAgentRunResult;
begin
  ChangeStatus(asRunning, 'Agent run started.');
  while FStatus = asRunning do
  begin
    if not CanContinueLoop then
      Break;
    ExecuteNextDecision;
  end;

  Result := TRadIAAgentRunResult.Create(
    FStatus,
    FMessage,
    FSteps.Count
  );
end;

procedure TRadIAAgentRuntime.HandleCompletionDecision(
  const ADecision: TRadIAAgentDecision
);
begin
  if ValidationAllowsCompletion(FMessage) then
  begin
    ChangeStatus(asCompleted, ADecision.Message);
    Exit;
  end;
  Inc(FValidationRejectionCount);
  if FValidationRejectionCount >= 3 then
    ChangeStatus(
      asFailed,
      'Agent repeatedly attempted to finish without validation.'
    )
  else
    ChangeStatus(asRunning, FMessage);
end;

procedure TRadIAAgentRuntime.HandleDecisionException(
  const AMessage: string
);
begin
  if TInterlocked.CompareExchange(FCancelRequested, 0, 0) <> 0 then
    ChangeStatus(asCancelled, 'Agent run was cancelled.')
  else if TInterlocked.CompareExchange(FPauseRequested, 0, 0) <> 0 then
    ChangeStatus(asPaused, 'Agent run was paused.')
  else
    ChangeStatus(asFailed, 'Agent decision failed: ' + AMessage);
end;

procedure TRadIAAgentRuntime.HandlePlanDecision(
  const ADecision: TRadIAAgentDecision
);
begin
  if FPlanApproved or HasValidPlan then
  begin
    ChangeStatus(asFailed, 'Agent returned more than one plan.');
    Exit;
  end;
  FPlanJson := ADecision.PlanJson;
  if not HasValidPlan then
    ChangeStatus(asFailed, 'Agent returned an invalid plan.')
  else
    ChangeStatus(asAwaitingApproval, ADecision.Message);
end;

function TRadIAAgentRuntime.ElapsedMilliseconds: Int64;
var
  LCurrentRunMilliseconds: Int64;
begin
  LCurrentRunMilliseconds := 0;
  if FRunStartedTimestamp > 0 then
    LCurrentRunMilliseconds := Round(
      (TStopwatch.GetTimeStamp - FRunStartedTimestamp) *
      1000 / TStopwatch.Frequency
    );
  Result := FElapsedBeforeRunMilliseconds + LCurrentRunMilliseconds;
end;

function TRadIAAgentRuntime.ExecuteToolDecision(
  const ADecision: TRadIAAgentDecision
): Boolean;
var
  LCorrelationId: string;
  LDurationMilliseconds: Int64;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
  LStartedElapsedMilliseconds: Int64;
begin
  Result := False;
  if Trim(ADecision.ToolName) = '' then
  begin
    ChangeStatus(asFailed, 'Agent selected an empty tool name.');
    Exit;
  end;
  if not CheckRepeatedCall(ADecision) then
  begin
    ChangeStatus(
      asFailed,
      'Agent stopped because the same tool call repeated too many times.'
    );
    Exit;
  end;

  LCorrelationId := TGUID.NewGuid.ToString;
  LRequest := TRadIAToolRequest.Create(
    ADecision.ToolName,
    ADecision.ArgumentsJson,
    LCorrelationId,
    'chat-agent',
    FSessionId,
    FProjectId,
    'workspace'
  ).WithCancellation(FCancellationToken);
  LStartedElapsedMilliseconds := ElapsedMilliseconds;
  LResult := FToolExecutor.Execute(LRequest);
  LDurationMilliseconds := ElapsedMilliseconds -
    LStartedElapsedMilliseconds;
  AddToolStep(
    ADecision,
    LCorrelationId,
    LResult,
    LStartedElapsedMilliseconds,
    LDurationMilliseconds
  );
  NotifyAndCheckpoint;
  Result := True;
end;

procedure TRadIAAgentRuntime.AddUniqueFilePath(
  const APath: string;
  const APaths: TList<string>
);
const
  MAX_AFFECTED_FILES = 100;
  MAX_FILE_PATH_LENGTH = 1024;
var
  LExisting: string;
  LPath: string;
begin
  if APaths.Count >= MAX_AFFECTED_FILES then
    Exit;
  LPath := Trim(APath);
  if (LPath = '') or (Length(LPath) > MAX_FILE_PATH_LENGTH) then
    Exit;
  for LExisting in APaths do
  begin
    if SameText(LExisting, LPath) then
      Exit;
  end;
  APaths.Add(LPath);
end;

procedure TRadIAAgentRuntime.CollectFilePaths(
  const AValue: TJSONValue;
  const AKey: string;
  const APaths: TList<string>
);
var
  LArray: TJSONArray;
  LIndex: Integer;
  LObject: TJSONObject;
  LPair: TJSONPair;
begin
  if not Assigned(AValue) then
    Exit;
  if (AValue is TJSONString) and IsFilePathKey(AKey) then
  begin
    AddUniqueFilePath(TJSONString(AValue).Value, APaths);
    Exit;
  end;
  if AValue is TJSONArray then
  begin
    LArray := TJSONArray(AValue);
    for LIndex := 0 to LArray.Count - 1 do
      CollectFilePaths(LArray[LIndex], AKey, APaths);
    Exit;
  end;
  if not (AValue is TJSONObject) then
    Exit;
  LObject := TJSONObject(AValue);
  for LIndex := 0 to LObject.Count - 1 do
  begin
    LPair := LObject.Pairs[LIndex];
    CollectFilePaths(
      LPair.JsonValue,
      LPair.JsonString.Value,
      APaths
    );
  end;
end;

function TRadIAAgentRuntime.ExtractAffectedFiles(
  const AArgumentsJson: string;
  const AResultJson: string
): TArray<string>;
var
  LPaths: TList<string>;
  LValue: TJSONValue;
begin
  LPaths := TList<string>.Create;
  try
    LValue := TJSONObject.ParseJSONValue(AArgumentsJson);
    try
      CollectFilePaths(LValue, '', LPaths);
    finally
      LValue.Free;
    end;
    LValue := TJSONObject.ParseJSONValue(AResultJson);
    try
      CollectFilePaths(LValue, '', LPaths);
    finally
      LValue.Free;
    end;
    Result := LPaths.ToArray;
  finally
    LPaths.Free;
  end;
end;

function TRadIAAgentRuntime.IsFilePathKey(
  const AKey: string
): Boolean;
begin
  Result :=
    SameText(AKey, 'path') or
    SameText(AKey, 'file') or
    SameText(AKey, 'files') or
    SameText(AKey, 'fileName') or
    SameText(AKey, 'filePath') or
    SameText(AKey, 'targetFile') or
    SameText(AKey, 'targetFiles') or
    SameText(AKey, 'projectFile') or
    SameText(AKey, 'changedFiles') or
    SameText(AKey, 'affectedFiles') or
    SameText(AKey, 'createdFiles') or
    SameText(AKey, 'removedFiles');
end;

function TRadIAAgentRuntime.IsMutationTool(
  const AToolName: string
): Boolean;
begin
  Result :=
    SameText(AToolName, 'ApplyPatch') or
    SameText(AToolName, 'ApplyMultiFilePatch') or
    SameText(AToolName, 'ApplyDevelopmentTransaction') or
    SameText(AToolName, 'RevertDevelopmentTransaction') or
    SameText(AToolName, 'RevertDevelopmentTransactionStep') or
    SameText(AToolName, 'CommitProjectFile') or
    SameText(AToolName, 'RemoveProjectFile') or
    SameText(AToolName, 'CommitProjectTemplate') or
    SameText(AToolName, 'CreateProjectFromTemplate') or
    SameText(AToolName, 'RevertCreatedProject') or
    SameText(AToolName, 'ApplyDesignerLayout') or
    SameText(AToolName, 'ApplyDesignerProperty') or
    SameText(AToolName, 'AddDesignerComponent') or
    SameText(AToolName, 'RemoveDesignerComponent') or
    SameText(AToolName, 'ApplyDesignerEvent');
end;

function TRadIAAgentRuntime.ResolveRiskName(
  const AToolName: string
): string;
var
  LDescriptor: TRadIAToolDescriptor;
begin
  if Assigned(FDescriptorProvider) and
    FDescriptorProvider.TryGetToolDescriptor(AToolName, LDescriptor) then
    Exit(RadIAToolRiskName(LDescriptor.Risk));
  if IsMutationTool(AToolName) then
    Result := RadIAToolRiskName(trReversibleWrite)
  else
    Result := RadIAToolRiskName(trReadOnly);
end;

procedure TRadIAAgentRuntime.LoadSnapshot(
  const ASnapshotJson: string
);
var
  LRoot: TJSONObject;
  LPlan: TJSONValue;
  LStepArray: TJSONArray;
  LStepJson: TJSONObject;
  LIndex: Integer;
begin
  LRoot := TJSONObject.ParseJSONValue(ASnapshotJson) as TJSONObject;
  if not Assigned(LRoot) then
    raise EArgumentException.Create('Agent checkpoint is not valid JSON.');
  try
    if LRoot.GetValue<Integer>('schemaVersion', 0) <> 1 then
      raise EArgumentException.Create(
        'Agent checkpoint schema is not supported.'
      );
    FSessionId := LRoot.GetValue<string>('sessionId', '');
    FProjectId := LRoot.GetValue<string>('projectId', '');
    FObjective := LRoot.GetValue<string>('objective', '');
    FMessage := LRoot.GetValue<string>('message', '');
    FPlanApproved := LRoot.GetValue<Boolean>('planApproved', False);
    LPlan := LRoot.GetValue('plan');
    if Assigned(LPlan) and
      ((LPlan is TJSONObject) or (LPlan is TJSONArray)) then
      FPlanJson := LPlan.ToJSON
    else
      FPlanJson := '';
    FLimits := TRadIAAgentLimits.Create(
      LRoot.GetValue<Integer>('maxSteps', 20),
      LRoot.GetValue<Integer>('maxRepeatedCalls', 3),
      LRoot.GetValue<Integer>(
        'maxDurationMilliseconds',
        15 * 60 * 1000
      ),
      LRoot.GetValue<Integer>('maxTotalTokens', 100000),
      LRoot.GetValue<Int64>('maxEstimatedCostMicros', 0),
      LRoot.GetValue<Integer>('maxDecisionContextCharacters', 120000)
    );
    FElapsedBeforeRunMilliseconds := LRoot.GetValue<Int64>(
      'elapsedMilliseconds',
      0
    );
    FPromptTokensBeforeRun := LRoot.GetValue<Integer>(
      'promptTokens',
      0
    );
    FCompletionTokensBeforeRun := LRoot.GetValue<Integer>(
      'completionTokens',
      0
    );
    FEstimatedCostMicrosBeforeRun := LRoot.GetValue<Int64>(
      'estimatedCostMicros',
      0
    );
    FSteps.Clear;
    LStepArray := LRoot.GetValue<TJSONArray>('steps');
    if Assigned(LStepArray) then
    begin
      for LIndex := 0 to LStepArray.Count - 1 do
      begin
        if not (LStepArray[LIndex] is TJSONObject) then
          Continue;
        LStepJson := TJSONObject(LStepArray[LIndex]);
        FSteps.Add(LoadStep(LStepJson, LIndex + 1));
      end;
    end;
  finally
    LRoot.Free;
  end;
end;

function TRadIAAgentRuntime.LoadAffectedFiles(
  const AStepJson: TJSONObject
): TArray<string>;
var
  LFileArray: TJSONArray;
  LFileIndex: Integer;
  LValue: TJSONValue;
begin
  Result := nil;
  LValue := AStepJson.GetValue('affectedFiles');
  if not (LValue is TJSONArray) then
    Exit;
  LFileArray := TJSONArray(LValue);
  SetLength(Result, LFileArray.Count);
  for LFileIndex := 0 to LFileArray.Count - 1 do
    Result[LFileIndex] := LFileArray[LFileIndex].Value;
end;

function TRadIAAgentRuntime.LoadStep(
  const AStepJson: TJSONObject;
  const ADefaultIndex: Integer
): TRadIAAgentStep;
begin
  Result := Default(TRadIAAgentStep);
  Result.Index := AStepJson.GetValue<Integer>('index', ADefaultIndex);
  Result.ToolName := AStepJson.GetValue<string>('toolName', '');
  Result.ArgumentsJson := AStepJson.GetValue<string>('arguments', '{}');
  Result.CorrelationId := AStepJson.GetValue<string>('correlationId', '');
  Result.Success := AStepJson.GetValue<Boolean>('success', False);
  Result.ResultJson := AStepJson.GetValue<string>('result', '');
  Result.ResultArtifactId := AStepJson.GetValue<string>(
    'resultArtifactId',
    ''
  );
  Result.ResultArtifactHash := AStepJson.GetValue<string>(
    'resultArtifactHash',
    ''
  );
  Result.ResultArtifactCharacters := AStepJson.GetValue<Integer>(
    'resultArtifactCharacters',
    0
  );
  Result.ErrorCode := AStepJson.GetValue<string>('errorCode', '');
  Result.ErrorMessage := AStepJson.GetValue<string>('errorMessage', '');
  Result.StartedElapsedMilliseconds := AStepJson.GetValue<Int64>(
    'startedElapsedMilliseconds',
    0
  );
  Result.DurationMilliseconds := AStepJson.GetValue<Int64>(
    'durationMilliseconds',
    0
  );
  Result.Mutation := AStepJson.GetValue<Boolean>(
    'mutation',
    IsMutationTool(Result.ToolName)
  );
  Result.ReplayOfStepIndex := AStepJson.GetValue<Integer>(
    'replayOfStepIndex',
    0
  );
  Result.Risk := AStepJson.GetValue<string>(
    'risk',
    ResolveRiskName(Result.ToolName)
  );
  Result.AffectedFiles := LoadAffectedFiles(AStepJson);
end;

procedure TRadIAAgentRuntime.NotifyAndCheckpoint;
var
  LSnapshot: string;
begin
  LSnapshot := BuildSnapshotJson(False);
  FCheckpointStore.Save(FSessionId, LSnapshot);
  if Assigned(FObserver) then
    FObserver.AgentStateChanged(LSnapshot);
end;

procedure TRadIAAgentRuntime.RequestCancel;
begin
  TInterlocked.Exchange(FCancelRequested, 1);
  if Assigned(FCancellationToken) then
    FCancellationToken.Request;
end;

procedure TRadIAAgentRuntime.RequestPause;
begin
  TInterlocked.Exchange(FPauseRequested, 1);
end;

procedure TRadIAAgentRuntime.ResetRun;
begin
  FSteps.Clear;
  FStatus := asIdle;
  FObjective := '';
  FSessionId := '';
  FProjectId := '';
  FMessage := '';
  FPlanJson := '';
  FPlanApproved := False;
  TInterlocked.Exchange(FPauseRequested, 0);
  TInterlocked.Exchange(FCancelRequested, 0);
  FLastCallSignature := '';
  FRepeatedCallCount := 0;
  FElapsedBeforeRunMilliseconds := 0;
  FRunStartedTimestamp := 0;
  FPromptTokensBeforeRun := 0;
  FCompletionTokensBeforeRun := 0;
  FEstimatedCostMicrosBeforeRun := 0;
  FValidationRejectionCount := 0;
  FReplayOfStepIndex := 0;
  FCancellationToken := TRadIAAgentCancellationToken.Create;
end;

function TRadIAAgentRuntime.ValidationAllowsCompletion(
  out AMessage: string
): Boolean;
var
  LValidation: TRadIAAgentValidationState;
begin
  LValidation := AnalyzeValidationState;
  if LValidation.MutationPending and not LValidation.BuildPassed then
  begin
    AMessage :=
      'Validation gate rejected completion: run BuildProject successfully ' +
      'after the latest source or Designer mutation.';
    Exit(False);
  end;
  if LValidation.TestsRun and not LValidation.TestsPassed then
  begin
    AMessage :=
      'Validation gate rejected completion: the latest DUnitX run failed. ' +
      'Inspect the report, correct the cause, rebuild, and rerun tests.';
    Exit(False);
  end;
  AMessage := '';
  Result := True;
end;

function TRadIAAgentRuntime.Resume(
  const ASessionId: string
): TRadIAAgentRunResult;
var
  LSnapshot: string;
begin
  ResetRun;
  if not FCheckpointStore.TryLoad(ASessionId, LSnapshot) then
    raise EArgumentException.Create(
      'Agent checkpoint was not found for the requested session.'
    );
  LoadSnapshot(LSnapshot);
  if FSessionId <> ASessionId then
    raise EArgumentException.Create(
      'Agent checkpoint session does not match the requested session.'
    );
  if HasValidPlan and not FPlanApproved then
    FPlanApproved := True;
  TInterlocked.Exchange(FPauseRequested, 0);
  TInterlocked.Exchange(FCancelRequested, 0);
  if FSteps.Count > 0 then
  begin
    FLastCallSignature := LowerCase(Trim(FSteps.Last.ToolName)) + #10 +
      Trim(FSteps.Last.ArgumentsJson);
    FRepeatedCallCount := 1;
  end;
  FStatus := asRunning;
  FRunStartedTimestamp := TStopwatch.GetTimeStamp;
  Result := ExecuteLoop;
end;

function TRadIAAgentRuntime.ReplayStep(
  const ASessionId: string;
  const AStepIndex: Integer
): TRadIAAgentRunResult;
var
  LDecision: TRadIAAgentDecision;
  LFound: Boolean;
  LOriginalStep: TRadIAAgentStep;
  LRoot: TJSONObject;
  LSnapshot: string;
  LStep: TRadIAAgentStep;
  LValue: TJSONValue;
begin
  ResetRun;
  if not FCheckpointStore.TryLoad(ASessionId, LSnapshot) then
    raise EArgumentException.Create(
      'Agent checkpoint was not found for the requested session.'
    );
  LValue := TJSONObject.ParseJSONValue(LSnapshot);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EArgumentException.Create('Agent checkpoint is not valid JSON.');
  end;
  LRoot := TJSONObject(LValue);
  try
    if not SameText(LRoot.GetValue<string>('status', ''), 'paused') then
      raise EInvalidOp.Create(
        'Agent steps can only be replayed while the run is paused.'
      );
  finally
    LRoot.Free;
  end;
  LoadSnapshot(LSnapshot);
  if FSessionId <> ASessionId then
    raise EArgumentException.Create(
      'Agent checkpoint session does not match the requested session.'
    );
  if FSteps.Count >= FLimits.MaxSteps then
    raise EInvalidOp.Create(
      'Agent step replay would exceed the configured step limit.'
    );
  LFound := False;
  for LStep in FSteps do
  begin
    if LStep.Index = AStepIndex then
    begin
      LOriginalStep := LStep;
      LFound := True;
      Break;
    end;
  end;
  if not LFound then
    raise EArgumentException.Create(
      'The requested agent step was not found.'
    );
  FStatus := asPaused;
  FRunStartedTimestamp := TStopwatch.GetTimeStamp;
  FReplayOfStepIndex := AStepIndex;
  try
    LDecision := TRadIAAgentDecision.CallTool(
      LOriginalStep.ToolName,
      LOriginalStep.ArgumentsJson
    );
    ExecuteToolDecision(LDecision);
  finally
    FReplayOfStepIndex := 0;
  end;
  if FSteps.Last.Success then
    ChangeStatus(
      asPaused,
      Format('Step %d replayed successfully; review before resuming.', [
        AStepIndex
      ])
    )
  else
    ChangeStatus(
      asPaused,
      Format('Step %d replay failed; review the result before resuming.', [
        AStepIndex
      ])
    );
  Result := TRadIAAgentRunResult.Create(
    FStatus,
    FMessage,
    FSteps.Count
  );
end;

function TRadIAAgentRuntime.HasValidPlan: Boolean;
var
  LPlan: TJSONValue;
begin
  LPlan := TJSONObject.ParseJSONValue(FPlanJson);
  try
    Result := Assigned(LPlan) and
      ((LPlan is TJSONArray) or (LPlan is TJSONObject));
  finally
    LPlan.Free;
  end;
end;

function TRadIAAgentRuntime.SnapshotJson: string;
begin
  Result := BuildSnapshotJson(False);
end;

function TRadIAAgentRuntime.Start(
  const AObjective: string;
  const ASessionId: string;
  const AProjectId: string;
  const ALimits: TRadIAAgentLimits
): TRadIAAgentRunResult;
begin
  ValidateStart(AObjective, ASessionId);
  ResetRun;
  FObjective := Trim(AObjective);
  FSessionId := ASessionId;
  FProjectId := AProjectId;
  FLimits := ALimits;
  FRunStartedTimestamp := TStopwatch.GetTimeStamp;
  Result := ExecuteLoop;
end;

procedure TRadIAAgentRuntime.ValidateStart(
  const AObjective: string;
  const ASessionId: string
);
begin
  if Trim(AObjective) = '' then
    raise EArgumentException.Create(
      'Agent objective must not be empty.'
    );
  if Trim(ASessionId) = '' then
    raise EArgumentException.Create(
      'Agent session id must not be empty.'
    );
end;

end.
