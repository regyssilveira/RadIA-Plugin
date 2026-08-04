unit RadIA.Core.AgentRuntime;

interface

uses
  System.Generics.Collections,
  RadIA.Core.Tools;

type
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
    class function Default: TRadIAAgentLimits; static;
    property MaxSteps: Integer read FMaxSteps;
    property MaxRepeatedCalls: Integer read FMaxRepeatedCalls;
    property MaxDurationMilliseconds: Integer
      read FMaxDurationMilliseconds;
    property MaxTotalTokens: Integer read FMaxTotalTokens;
    property MaxEstimatedCostMicros: Int64
      read FMaxEstimatedCostMicros;
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

  IRadIAAgentCancellationControl = interface(IRadIAToolCancellationToken)
    ['{8B64F959-1A49-4BB0-9424-8B2EE0AC4B27}']
    procedure Request;
  end;

  TRadIAAgentFileCheckpointStore = class(
    TInterfacedObject,
    IRadIAAgentCheckpointStore
  )
  private
    FDirectory: string;
    function CheckpointPath(const ASessionId: string): string;
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
      ErrorCode: string;
      ErrorMessage: string;
    end;
    TRadIAAgentValidationState = record
      MutationPending: Boolean;
      BuildPassed: Boolean;
      TestsRun: Boolean;
      TestsPassed: Boolean;
    end;
  private
    FToolExecutor: IRadIAToolExecutor;
    FDecisionProvider: IRadIAAgentDecisionProvider;
    FUsageProvider: IRadIAAgentUsageProvider;
    FCheckpointStore: IRadIAAgentCheckpointStore;
    FObserver: IRadIAAgentObserver;
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
    function BuildSnapshotJson: string;
    function BuildDecisionContextJson: string;
    function BuildCallSignature(
      const ADecision: TRadIAAgentDecision
    ): string;
    function CheckRepeatedCall(
      const ADecision: TRadIAAgentDecision
    ): Boolean;
    procedure AddToolStep(
      const ADecision: TRadIAAgentDecision;
      const ACorrelationId: string;
      const AResult: TRadIAToolResult
    );
    procedure ChangeStatus(
      const AStatus: TRadIAAgentStatus;
      const AMessage: string
    );
    procedure NotifyAndCheckpoint;
    procedure LoadSnapshot(const ASnapshotJson: string);
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
    function IsMutationTool(const AToolName: string): Boolean;
    function ValidationAllowsCompletion(
      out AMessage: string
    ): Boolean;
  public
    constructor Create(
      const AToolExecutor: IRadIAToolExecutor;
      const ADecisionProvider: IRadIAAgentDecisionProvider;
      const ACheckpointStore: IRadIAAgentCheckpointStore;
      const AObserver: IRadIAAgentObserver = nil
    );
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
    procedure RequestPause;
    procedure RequestCancel;
    function SnapshotJson: string;
  end;

function RadIAAgentStatusName(
  const AStatus: TRadIAAgentStatus
): string;

implementation

uses
  System.Diagnostics,
  System.IOUtils,
  System.JSON,
  System.Math,
  System.SyncObjs,
  System.SysUtils;

type
  TRadIAAgentCancellationToken = class(
    TInterfacedObject,
    IRadIAAgentCancellationControl
  )
  private
    FRequested: Integer;
  public
    function GetCancellationRequested: Boolean;
    procedure Request;
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
    0
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
    0
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
  if (AMaxTotalTokens < 1) or (AMaxTotalTokens > 1000000) then
    raise EArgumentOutOfRangeException.Create(
      'Agent token limit must be between 1 and 1000000.'
    );
  if (AMaxEstimatedCostMicros < 0) or
    (AMaxEstimatedCostMicros > Int64(10000) * 1000000) then
    raise EArgumentOutOfRangeException.Create(
      'Agent cost limit must be between USD 0 and 10000.'
    );
  FMaxSteps := AMaxSteps;
  FMaxRepeatedCalls := AMaxRepeatedCalls;
  FMaxDurationMilliseconds := AMaxDurationMilliseconds;
  FMaxTotalTokens := AMaxTotalTokens;
  FMaxEstimatedCostMicros := AMaxEstimatedCostMicros;
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
begin
  TInterlocked.Exchange(FRequested, 1);
end;

{ TRadIAAgentRuntime }

constructor TRadIAAgentRuntime.Create(
  const AToolExecutor: IRadIAToolExecutor;
  const ADecisionProvider: IRadIAAgentDecisionProvider;
  const ACheckpointStore: IRadIAAgentCheckpointStore;
  const AObserver: IRadIAAgentObserver
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
  FDecisionProvider := ADecisionProvider;
  Supports(ADecisionProvider, IRadIAAgentUsageProvider, FUsageProvider);
  FCheckpointStore := ACheckpointStore;
  FObserver := AObserver;
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
  const AResult: TRadIAToolResult
);
var
  LStep: TRadIAAgentStep;
begin
  LStep := Default(TRadIAAgentStep);
  LStep.Index := FSteps.Count + 1;
  LStep.ToolName := ADecision.ToolName;
  LStep.ArgumentsJson := ADecision.ArgumentsJson;
  LStep.CorrelationId := ACorrelationId;
  LStep.Success := AResult.Success;
  LStep.ResultJson := AResult.ContentJson;
  LStep.ErrorCode := AResult.ErrorCode;
  LStep.ErrorMessage := AResult.ErrorMessage;
  FSteps.Add(LStep);
end;

function TRadIAAgentRuntime.AnalyzeValidationState:
  TRadIAAgentValidationState;
var
  LStep: TRadIAAgentStep;
begin
  Result := Default(TRadIAAgentValidationState);
  for LStep in FSteps do
  begin
    if IsMutationTool(LStep.ToolName) and LStep.Success then
    begin
      Result.MutationPending := True;
      Result.BuildPassed := False;
      Result.TestsRun := False;
      Result.TestsPassed := False;
      Continue;
    end;
    if not Result.MutationPending then
      Continue;
    if SameText(LStep.ToolName, 'BuildProject') then
      Result.BuildPassed := LStep.Success and
        LStep.ResultJson.Contains('"status":"succeeded"');
    if SameText(LStep.ToolName, 'RunDUnitXTests') then
    begin
      Result.TestsRun := True;
      Result.TestsPassed := LStep.Success and
        LStep.ResultJson.Contains('"status":"succeeded"');
    end;
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
  Result := BuildSnapshotJson;
end;

function TRadIAAgentRuntime.BuildSnapshotJson: string;
var
  LRoot: TJSONObject;
  LStepArray: TJSONArray;
  LStepJson: TJSONObject;
  LStep: TRadIAAgentStep;
  LValidation: TRadIAAgentValidationState;
  LValidationJson: TJSONObject;
begin
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
    LValidation := AnalyzeValidationState;
    LValidationJson := TJSONObject.Create;
    LValidationJson.AddPair(
      'mutationPending',
      TJSONBool.Create(LValidation.MutationPending)
    );
    LValidationJson.AddPair(
      'buildPassed',
      TJSONBool.Create(LValidation.BuildPassed)
    );
    LValidationJson.AddPair(
      'testsRun',
      TJSONBool.Create(LValidation.TestsRun)
    );
    LValidationJson.AddPair(
      'testsPassed',
      TJSONBool.Create(LValidation.TestsPassed)
    );
    LRoot.AddPair('validation', LValidationJson);
    LStepArray := TJSONArray.Create;
    LRoot.AddPair('steps', LStepArray);
    for LStep in FSteps do
    begin
      LStepJson := TJSONObject.Create;
      LStepJson.AddPair('index', TJSONNumber.Create(LStep.Index));
      LStepJson.AddPair('toolName', LStep.ToolName);
      LStepJson.AddPair('arguments', LStep.ArgumentsJson);
      LStepJson.AddPair('correlationId', LStep.CorrelationId);
      LStepJson.AddPair('success', TJSONBool.Create(LStep.Success));
      LStepJson.AddPair('result', LStep.ResultJson);
      LStepJson.AddPair('errorCode', LStep.ErrorCode);
      LStepJson.AddPair('errorMessage', LStep.ErrorMessage);
      LStepArray.AddElement(LStepJson);
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
  if EffectiveTotalTokens >= FLimits.MaxTotalTokens then
  begin
    ChangeStatus(
      asFailed,
      'Agent stopped after reaching the configured token limit.'
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
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
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
  LResult := FToolExecutor.Execute(LRequest);
  AddToolStep(ADecision, LCorrelationId, LResult);
  NotifyAndCheckpoint;
  Result := True;
end;

function TRadIAAgentRuntime.IsMutationTool(
  const AToolName: string
): Boolean;
begin
  Result :=
    SameText(AToolName, 'ApplyPatch') or
    SameText(AToolName, 'ApplyMultiFilePatch') or
    SameText(AToolName, 'ApplyDevelopmentTransaction') or
    SameText(AToolName, 'CommitProjectFile') or
    SameText(AToolName, 'RemoveProjectFile') or
    SameText(AToolName, 'CommitProjectTemplate') or
    SameText(AToolName, 'ApplyDesignerLayout') or
    SameText(AToolName, 'ApplyDesignerProperty') or
    SameText(AToolName, 'AddDesignerComponent') or
    SameText(AToolName, 'RemoveDesignerComponent') or
    SameText(AToolName, 'ApplyDesignerEvent');
end;

procedure TRadIAAgentRuntime.LoadSnapshot(
  const ASnapshotJson: string
);
var
  LRoot: TJSONObject;
  LPlan: TJSONValue;
  LStepArray: TJSONArray;
  LStepJson: TJSONObject;
  LStep: TRadIAAgentStep;
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
      LRoot.GetValue<Int64>('maxEstimatedCostMicros', 0)
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
        LStep := Default(TRadIAAgentStep);
        LStep.Index := LStepJson.GetValue<Integer>('index', LIndex + 1);
        LStep.ToolName := LStepJson.GetValue<string>('toolName', '');
        LStep.ArgumentsJson := LStepJson.GetValue<string>(
          'arguments',
          '{}'
        );
        LStep.CorrelationId := LStepJson.GetValue<string>(
          'correlationId',
          ''
        );
        LStep.Success := LStepJson.GetValue<Boolean>('success', False);
        LStep.ResultJson := LStepJson.GetValue<string>('result', '');
        LStep.ErrorCode := LStepJson.GetValue<string>('errorCode', '');
        LStep.ErrorMessage := LStepJson.GetValue<string>(
          'errorMessage',
          ''
        );
        FSteps.Add(LStep);
      end;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TRadIAAgentRuntime.NotifyAndCheckpoint;
var
  LSnapshot: string;
begin
  LSnapshot := BuildSnapshotJson;
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
  Result := BuildSnapshotJson;
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
