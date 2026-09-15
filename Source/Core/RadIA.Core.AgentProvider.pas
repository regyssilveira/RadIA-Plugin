unit RadIA.Core.AgentProvider;

interface

uses
  System.SysUtils,
  RadIA.Core.AgentPricing,
  RadIA.Core.AgentRuntime,
  RadIA.Core.Interfaces;

type
  ERadIAAgentProviderTimeout = class(Exception);

  IRadIAAgentDecisionCancellation = interface
    ['{CB162130-D8A7-4F00-8365-60F829B47625}']
    procedure CancelDecision;
  end;

  TRadIAAgentProviderSettings = record
  private
    FToolCatalogJson: string;
    FTimeoutMilliseconds: Cardinal;
    FPricing: TRadIAAgentPricing;
  public
    constructor Create(
      const AToolCatalogJson: string;
      const ATimeoutMilliseconds: Cardinal
    );
    class function Default(
      const AToolCatalogJson: string
    ): TRadIAAgentProviderSettings; static;
    class function WithPricing(
      const AToolCatalogJson: string;
      const APricing: TRadIAAgentPricing
    ): TRadIAAgentProviderSettings; static;
    property ToolCatalogJson: string read FToolCatalogJson;
    property TimeoutMilliseconds: Cardinal read FTimeoutMilliseconds;
    property Pricing: TRadIAAgentPricing read FPricing;
  end;

  TRadIAAgentServiceDecisionProvider = class(
    TInterfacedObject,
    IRadIAAgentDecisionProvider,
    IRadIAAgentDecisionCancellation,
    IRadIAAgentUsageProvider
  )
  private
    FService: IRadIAService;
    FHistory: TArray<IRadIAChatMessage>;
    FSettings: TRadIAAgentProviderSettings;
    FActiveWaitState: IInterface;
    FPromptTokens: Integer;
    FCompletionTokens: Integer;
    FDecisionIndex: Integer;
    FRunId: string;
    function BuildDecisionPrompt(
      const AContextJson: string;
      const AToolCatalogJson: string;
      const APlanApproved: Boolean;
      const AProjectCreation: Boolean
    ): string;
    function BuildRelevantToolCatalog(const AContextJson: string): string;
    class function IsProjectCreationTool(const AName: string): Boolean; static;
  public
    constructor Create(
      const AService: IRadIAService;
      const AHistory: TArray<IRadIAChatMessage>;
      const ASettings: TRadIAAgentProviderSettings
    );
    function NextDecision(
      const AContextJson: string
    ): TRadIAAgentDecision;
    procedure CancelDecision;
    function GetPromptTokens: Integer;
    function GetCompletionTokens: Integer;
    function GetTotalTokens: Integer;
    function GetEstimatedCostMicros: Int64;
    function GetPricingConfigured: Boolean;
    class function ParseDecision(
      const AResponse: string
    ): TRadIAAgentDecision; static;
  end;

implementation

uses
  Winapi.Windows,
  System.Diagnostics,
  System.Hash,
  System.JSON,
  System.StrUtils,
  System.SyncObjs,
  RadIA.Core.Logger,
  RadIA.Core.TokenUsage,
  RadIA.Core.Types;

type
  IRadIAAgentProviderWaitState = interface
    ['{6239853D-E4F3-4DB3-8FF0-063831374028}']
    procedure Complete(
      const AResponse: string;
      const AError: string;
      const AUsage: TTokenUsage;
      const AFromCache: Boolean
    );
    function WaitFor(const ATimeout: Cardinal): TWaitResult;
    function GetResponse: string;
    function GetError: string;
    function GetUsage: TTokenUsage;
    function WasCached: Boolean;
  end;

  TRadIAAgentProviderWaitState = class(
    TInterfacedObject,
    IRadIAAgentProviderWaitState
  )
  private
    FEvent: TEvent;
    FResponse: string;
    FError: string;
    FCompleted: Integer;
    FUsage: TTokenUsage;
    FFromCache: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Complete(
      const AResponse: string;
      const AError: string;
      const AUsage: TTokenUsage;
      const AFromCache: Boolean
    );
    function WaitFor(const ATimeout: Cardinal): TWaitResult;
    function GetResponse: string;
    function GetError: string;
    function GetUsage: TTokenUsage;
    function WasCached: Boolean;
  end;

  TRadIAAgentDecisionMetric = record
    RunId: string;
    DecisionIndex: Integer;
    StepCount: Integer;
    ContextCharacters: Integer;
    CatalogCharacters: Integer;
    PromptCharacters: Integer;
    HistoryCharacters: Integer;
    HistoryMessages: Integer;
    DurationMilliseconds: Int64;
    Usage: TTokenUsage;
    FromCache: Boolean;
    Outcome: string;
    DecisionKind: string;
  end;

function RadIAAgentDecisionKindName(
  const AKind: TRadIAAgentDecisionKind
): string;
begin
  case AKind of
    adPlan: Result := 'plan';
    adToolCall: Result := 'tool';
    adComplete: Result := 'complete';
    adFail: Result := 'fail';
  else
    Result := 'unknown';
  end;
end;

procedure LogRadIAAgentDecisionMetric(
  const AMetric: TRadIAAgentDecisionMetric
);
var
  LEvent: TJSONObject;
  LUsageStatus: string;
begin
  LUsageStatus := 'unknown';
  if AMetric.FromCache then
    LUsageStatus := 'cached'
  else if (AMetric.Usage.PromptTokens > 0) or
    (AMetric.Usage.CompletionTokens > 0) or
    (AMetric.Usage.TotalTokens > 0) then
    LUsageStatus := 'reported';
  LEvent := TJSONObject.Create;
  try
    LEvent.AddPair('schemaVersion', TJSONNumber.Create(1));
    LEvent.AddPair('event', 'agentDecision');
    LEvent.AddPair('runId', AMetric.RunId);
    LEvent.AddPair('decisionIndex', TJSONNumber.Create(AMetric.DecisionIndex));
    LEvent.AddPair('stepCount', TJSONNumber.Create(AMetric.StepCount));
    LEvent.AddPair('contextCharacters', TJSONNumber.Create(AMetric.ContextCharacters));
    LEvent.AddPair('catalogCharacters', TJSONNumber.Create(AMetric.CatalogCharacters));
    LEvent.AddPair('promptCharacters', TJSONNumber.Create(AMetric.PromptCharacters));
    LEvent.AddPair('historyCharactersSupplied', TJSONNumber.Create(AMetric.HistoryCharacters));
    LEvent.AddPair('historyMessagesSupplied', TJSONNumber.Create(AMetric.HistoryMessages));
    LEvent.AddPair('durationMilliseconds', TJSONNumber.Create(AMetric.DurationMilliseconds));
    LEvent.AddPair('promptTokens', TJSONNumber.Create(AMetric.Usage.PromptTokens));
    LEvent.AddPair('completionTokens', TJSONNumber.Create(AMetric.Usage.CompletionTokens));
    LEvent.AddPair('usageStatus', LUsageStatus);
    LEvent.AddPair('outcome', AMetric.Outcome);
    LEvent.AddPair('decisionKind', AMetric.DecisionKind);
    TLogger.Log(LEvent.ToJSON, 'AgentMetrics');
  finally
    LEvent.Free;
  end;
end;

{ TRadIAAgentProviderSettings }

constructor TRadIAAgentProviderSettings.Create(
  const AToolCatalogJson: string;
  const ATimeoutMilliseconds: Cardinal
);
begin
  if Trim(AToolCatalogJson) = '' then
    raise EArgumentException.Create(
      'Agent tool catalog must not be empty.'
    );
  if (ATimeoutMilliseconds < 1000) or
    (ATimeoutMilliseconds > 600000) then
    raise EArgumentOutOfRangeException.Create(
      'Agent decision timeout must be between 1000 and 600000 ms.'
    );
  FToolCatalogJson := AToolCatalogJson;
  FTimeoutMilliseconds := ATimeoutMilliseconds;
  FPricing := TRadIAAgentPricing.Create('', '', 0, 0);
end;

class function TRadIAAgentProviderSettings.WithPricing(
  const AToolCatalogJson: string;
  const APricing: TRadIAAgentPricing
): TRadIAAgentProviderSettings;
begin
  Result := TRadIAAgentProviderSettings.Default(AToolCatalogJson);
  if not APricing.IsConfigured then
    raise EArgumentException.Create(
      'Agent pricing must be configured before it is applied.'
    );
  Result.FPricing := APricing;
end;

class function TRadIAAgentProviderSettings.Default(
  const AToolCatalogJson: string
): TRadIAAgentProviderSettings;
begin
  Result := TRadIAAgentProviderSettings.Create(
    AToolCatalogJson,
    120000
  );
end;

{ TRadIAAgentProviderWaitState }

constructor TRadIAAgentProviderWaitState.Create;
begin
  inherited Create;
  FEvent := TEvent.Create(nil, True, False, '');
end;

destructor TRadIAAgentProviderWaitState.Destroy;
begin
  FEvent.Free;
  inherited Destroy;
end;

procedure TRadIAAgentProviderWaitState.Complete(
  const AResponse: string;
  const AError: string;
  const AUsage: TTokenUsage;
  const AFromCache: Boolean
);
begin
  if TInterlocked.CompareExchange(FCompleted, 1, 0) <> 0 then
    Exit;
  FResponse := AResponse;
  FError := AError;
  FUsage := AUsage;
  FFromCache := AFromCache;
  FEvent.SetEvent;
end;

function TRadIAAgentProviderWaitState.GetError: string;
begin
  Result := FError;
end;

function TRadIAAgentProviderWaitState.GetResponse: string;
begin
  Result := FResponse;
end;

function TRadIAAgentProviderWaitState.GetUsage: TTokenUsage;
begin
  Result := FUsage;
end;

function TRadIAAgentProviderWaitState.WasCached: Boolean;
begin
  Result := FFromCache;
end;

function TRadIAAgentProviderWaitState.WaitFor(
  const ATimeout: Cardinal
): TWaitResult;
begin
  Result := FEvent.WaitFor(ATimeout);
end;

{ TRadIAAgentServiceDecisionProvider }

constructor TRadIAAgentServiceDecisionProvider.Create(
  const AService: IRadIAService;
  const AHistory: TArray<IRadIAChatMessage>;
  const ASettings: TRadIAAgentProviderSettings
);
begin
  inherited Create;
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FService := AService;
  FHistory := Copy(AHistory);
  FSettings := ASettings;
  FRunId := TGUID.NewGuid.ToString;
end;

function TRadIAAgentServiceDecisionProvider.BuildDecisionPrompt(
  const AContextJson: string;
  const AToolCatalogJson: string;
  const APlanApproved: Boolean;
  const AProjectCreation: Boolean
): string;
begin
  Result :=
    'You are the RadIA agent planner running inside RAD Studio. ' +
    'Choose exactly one next action for the objective and current state. ' +
    'Use only a tool from the supplied catalog. Never invent a tool. ' +
    'Return one JSON object and no markdown. Valid responses are: ' +
    '{"kind":"tool","tool":"ToolName","arguments":{}}, ' +
    '{"kind":"complete","message":"summary"}, or ' +
    '{"kind":"fail","message":"reason"}. ' +
    'Prefer read-only inspection before mutation. Mutating and execution tools ' +
    'remain subject to RadIA consent and audit policies. After any source, ' +
    'project, or Designer mutation, inspect structured diagnostics and run ' +
    'BuildProject. For a mutation that requires build, never complete while ' +
    'CURRENT_STATE.validation.buildPassed is false. Read-only objectives do ' +
    'not require BuildProject. Call StartDebugging or runtime scenario tools ' +
    'only when the ' +
    'objective contains runtimeValidation="required". Keep a runtime failure ' +
    'separate from successful build evidence. Run RunDUnitXTests after a ' +
    'successful build only when CURRENT_STATE.executionContract.requireTests ' +
    'is true or the objective explicitly requests tests. Request ' +
    'GetCoverageSummary only when coverage is explicitly required and an ' +
    'authoritative report is available. If build or tests fail, ' +
    'inspect their structured ' +
    'result, prepare the smallest reviewable correction, request consent, ' +
    'apply it, and repeat. Do not repeat an unchanged patch or tool call. ' +
    'When GetToolResultRange returns hasMore=false, the requested range is ' +
    'complete. Do not request that artifact range again; continue with the ' +
    'next functional validation step. Each tool call must answer an unmet ' +
    'requirement or required validation gate. Reuse successful evidence in ' +
    'CURRENT_STATE; do not repeat read-only inspection unless state changed ' +
    'or the earlier result was incomplete. When the objective and required ' +
    'gates are satisfied, return complete without optional tool calls.';
  if not APlanApproved then
    Result := Result +
      'Before the first tool call, return a concise, objective-specific plan for approval. ' +
      'If CURRENT_STATE.plan is empty, return kind plan with a steps array. ' +
      'Cover the requested outcome, inspection, implementation, and validation. ' +
      'Preserve every explicit functional requirement from CURRENT_STATE.objective. ' +
      'Do not return a generic inspection-only plan for a creation or modification objective. ';
  if AProjectCreation then
    Result := Result +
      'For project creation, a successful build is the default final gate. ' +
      'After PreviewProjectTemplate, CreateProjectFromTemplate, OpenCreatedProject, ' +
      'and a successful BuildProject, complete immediately. ' +
      'Do not list, navigate to, read, or audit generated template files merely ' +
      'to reconfirm content already guaranteed by the reviewed template. ' +
      'Continue only for explicit tests, runtime validation, or another unmet result. ';
  Result := Result +
    sLineBreak +
    'TOOLS:' + sLineBreak + AToolCatalogJson + sLineBreak +
    'CURRENT_STATE:' + sLineBreak + AContextJson;
end;

function TRadIAAgentServiceDecisionProvider.BuildRelevantToolCatalog(
  const AContextJson: string
): string;
var
  LFiltered: TJSONArray;
  LIndex: Integer;
  LItem: TJSONObject;
  LName: string;
  LPair: TJSONPair;
  LParsed: TJSONValue;
  LSource: TJSONArray;
  LValue: TJSONValue;
begin
  Result := FSettings.ToolCatalogJson;
  LParsed := TJSONObject.ParseJSONValue(FSettings.ToolCatalogJson);
  if not (LParsed is TJSONArray) then
  begin
    LParsed.Free;
    Exit;
  end;
  LSource := TJSONArray(LParsed);
  LFiltered := TJSONArray.Create;
  try
    for LIndex := 0 to LSource.Count - 1 do
    begin
      if not (LSource[LIndex] is TJSONObject) then
        Continue;
      LItem := TJSONObject(LSource[LIndex]);
      LName := LItem.GetValue<string>('name', '');
      if AContextJson.Contains(
        'Create a Delphi project from the user requirements.'
      ) and not IsProjectCreationTool(LName) then
        Continue;
      LValue := TJSONObject.ParseJSONValue(LItem.ToJSON);
      LPair := TJSONObject(LValue).RemovePair('version');
      LPair.Free;
      LFiltered.AddElement(LValue);
    end;
    if LFiltered.Count > 0 then
      Result := LFiltered.ToJSON;
  finally
    LFiltered.Free;
    LSource.Free;
  end;
end;

class function TRadIAAgentServiceDecisionProvider.IsProjectCreationTool(
  const AName: string
): Boolean;
begin
  Result := IndexText(AName, [
    'GetActiveProject', 'GetIDEState', 'GetGitStatus', 'ListOpenFiles',
    'GetInstallationHealth', 'DiagnoseDelphiDependencies',
    'GetKnowledgeStatus', 'SearchKnowledge', 'RetrieveKnowledge',
    'GetKnowledgeDocument', 'PreviewProjectTemplate',
    'CreateProjectFromTemplate', 'OpenCreatedProject',
    'ValidateCreatedProject', 'BuildProject', 'GetBuildStatus',
    'GetCompilerMessages', 'RunDUnitXTests', 'GetCoverageSummary',
    'StartDebugging', 'StopDebugging', 'GetDebuggerState',
    'GetRuntimeWindows', 'GetRuntimeControlTree',
    'PreviewRuntimeScenario', 'RunRuntimeScenario',
    'GetRuntimeScenarioStatus', 'CancelRuntimeScenario',
    'GetProjectHealth', 'GetToolResultRange'
  ]) >= 0;
end;

procedure TRadIAAgentServiceDecisionProvider.CancelDecision;
var
  LState: IRadIAAgentProviderWaitState;
begin
  TMonitor.Enter(Self);
  try
    Supports(
      FActiveWaitState,
      IRadIAAgentProviderWaitState,
      LState
    );
  finally
    TMonitor.Exit(Self);
  end;
  if Assigned(LState) then
    LState.Complete(
      '',
      'Agent decision was cancelled.',
      TTokenUsage.Empty,
      False
    );
  FService.CancelCurrentRequest;
end;

function TRadIAAgentServiceDecisionProvider.GetCompletionTokens: Integer;
begin
  Result := TInterlocked.CompareExchange(FCompletionTokens, 0, 0);
end;

function TRadIAAgentServiceDecisionProvider.GetPromptTokens: Integer;
begin
  Result := TInterlocked.CompareExchange(FPromptTokens, 0, 0);
end;

function TRadIAAgentServiceDecisionProvider.GetEstimatedCostMicros: Int64;
begin
  Result := FSettings.Pricing.EstimateCostMicros(
    GetPromptTokens,
    GetCompletionTokens
  );
end;

function TRadIAAgentServiceDecisionProvider.GetPricingConfigured: Boolean;
begin
  Result := FSettings.Pricing.IsConfigured;
end;

function TRadIAAgentServiceDecisionProvider.GetTotalTokens: Integer;
begin
  Result := GetPromptTokens + GetCompletionTokens;
end;

function TRadIAAgentServiceDecisionProvider.NextDecision(
  const AContextJson: string
): TRadIAAgentDecision;
var
  LCatalog: string;
  LContextValue: TJSONValue;
  LError: string;
  LHistoryMessage: IRadIAChatMessage;
  LMetric: TRadIAAgentDecisionMetric;
  LPlanApproved: Boolean;
  LPrompt: string;
  LState: IRadIAAgentProviderWaitState;
  LStepsValue: TJSONValue;
  LWaitResult: TWaitResult;
  LWatch: TStopwatch;
begin
  LMetric := Default(TRadIAAgentDecisionMetric);
  LMetric.RunId := FRunId;
  LMetric.DecisionIndex := TInterlocked.Increment(FDecisionIndex);
  LMetric.ContextCharacters := Length(AContextJson);
  LMetric.HistoryMessages := Length(FHistory);
  LMetric.Usage := TTokenUsage.Empty;
  LMetric.Outcome := 'providerError';
  LMetric.DecisionKind := 'unknown';
  LPlanApproved := False;
  for LHistoryMessage in FHistory do
    if Assigned(LHistoryMessage) then
      Inc(LMetric.HistoryCharacters, Length(LHistoryMessage.Content));
  LContextValue := TJSONObject.ParseJSONValue(AContextJson);
  try
    if LContextValue is TJSONObject then
    begin
      LMetric.RunId := TJSONObject(LContextValue).GetValue<string>('sessionId', '');
      if LMetric.RunId <> '' then
        LMetric.RunId := Copy(THashSHA2.GetHashString(LMetric.RunId), 1, 16)
      else
        LMetric.RunId := FRunId;
      LStepsValue := TJSONObject(LContextValue).GetValue('steps');
      LPlanApproved := TJSONObject(LContextValue).GetValue<Boolean>(
        'planApproved', False
      );
      if LStepsValue is TJSONArray then
        LMetric.StepCount := TJSONArray(LStepsValue).Count;
    end;
  finally
    LContextValue.Free;
  end;
  LCatalog := BuildRelevantToolCatalog(AContextJson);
  LPrompt := BuildDecisionPrompt(
    AContextJson,
    LCatalog,
    LPlanApproved,
    AContextJson.Contains('Create a Delphi project from the user requirements.')
  );
  LMetric.CatalogCharacters := Length(LCatalog);
  LMetric.PromptCharacters := Length(LPrompt);
  LWatch := TStopwatch.StartNew;
  LState := TRadIAAgentProviderWaitState.Create;
  TMonitor.Enter(Self);
  try
    FActiveWaitState := LState;
  finally
    TMonitor.Exit(Self);
  end;
  try
    FService.SendPrompt(
      LPrompt,
      FHistory,
      procedure(
        const AResponse: string;
        const AError: string;
        AFromCache: Boolean;
        const AUsage: TTokenUsage
      )
      begin
        TInterlocked.Add(FPromptTokens, AUsage.PromptTokens);
        TInterlocked.Add(
          FCompletionTokens,
          AUsage.CompletionTokens
        );
        LState.Complete(AResponse, AError, AUsage, AFromCache);
      end,
      rpGeneralChat
    );
    LWaitResult := LState.WaitFor(FSettings.TimeoutMilliseconds);
    if LWaitResult <> wrSignaled then
    begin
      LMetric.Outcome := 'timeout';
      FService.CancelCurrentRequest;
      raise ERadIAAgentProviderTimeout.Create(
        'Agent decision timed out while waiting for the AI provider.'
      );
    end;
    LMetric.Usage := LState.GetUsage;
    LMetric.FromCache := LState.WasCached;
    LError := LState.GetError;
    if LError <> '' then
    begin
      if SameText(LError, 'Agent decision was cancelled.') then
        LMetric.Outcome := 'cancelled';
      raise Exception.Create('Agent provider failed: ' + LError);
    end;
    try
      Result := ParseDecision(LState.GetResponse);
    except
      LMetric.Outcome := 'parseError';
      raise;
    end;
    LMetric.Outcome := 'success';
    LMetric.DecisionKind := RadIAAgentDecisionKindName(Result.Kind);
  finally
    LMetric.DurationMilliseconds := LWatch.ElapsedMilliseconds;
    try
      LogRadIAAgentDecisionMetric(LMetric);
    except
      OutputDebugString(PChar('RadIA agent decision metrics logging failed.'));
    end;
    TMonitor.Enter(Self);
    try
      FActiveWaitState := nil;
    finally
      TMonitor.Exit(Self);
    end;
  end;
end;

class function TRadIAAgentServiceDecisionProvider.ParseDecision(
  const AResponse: string
): TRadIAAgentDecision;
var
  LArguments: TJSONValue;
  LFirstBrace: Integer;
  LJson: TJSONObject;
  LJsonText: string;
  LKind: string;
  LLastBrace: Integer;
  LMessage: string;
  LPlan: TJSONValue;
  LToolName: string;
begin
  LFirstBrace := Pos('{', AResponse);
  LLastBrace := LastDelimiter('}', AResponse);
  if (LFirstBrace = 0) or (LLastBrace < LFirstBrace) then
    raise EConvertError.Create(
      'Agent provider did not return a JSON decision.'
    );
  LJsonText := Copy(
    AResponse,
    LFirstBrace,
    LLastBrace - LFirstBrace + 1
  );
  LJson := TJSONObject.ParseJSONValue(LJsonText) as TJSONObject;
  if not Assigned(LJson) then
    raise EConvertError.Create(
      'Agent provider returned an invalid JSON decision.'
    );
  try
    LKind := LowerCase(Trim(LJson.GetValue<string>('kind', '')));
    if LKind = 'plan' then
    begin
      LPlan := LJson.GetValue('steps');
      if not Assigned(LPlan) or not (LPlan is TJSONArray) then
        raise EConvertError.Create(
          'Agent plan decision does not contain a steps array.'
        );
      LMessage := Trim(LJson.GetValue<string>('message', ''));
      Exit(TRadIAAgentDecision.Plan(LMessage, LPlan.ToJSON));
    end;
    if LKind = 'tool' then
    begin
      LToolName := Trim(LJson.GetValue<string>('tool', ''));
      LArguments := LJson.GetValue('arguments');
      if not Assigned(LArguments) then
        raise EConvertError.Create(
          'Agent tool decision does not contain arguments.'
        );
      Exit(TRadIAAgentDecision.CallTool(LToolName, LArguments.ToJSON));
    end;

    LMessage := Trim(LJson.GetValue<string>('message', ''));
    if LKind = 'complete' then
      Exit(TRadIAAgentDecision.Complete(LMessage));
    if LKind = 'fail' then
      Exit(TRadIAAgentDecision.Fail(LMessage));
    raise EConvertError.Create(
      'Agent provider returned an unsupported decision kind.'
    );
  finally
    LJson.Free;
  end;
end;

end.
