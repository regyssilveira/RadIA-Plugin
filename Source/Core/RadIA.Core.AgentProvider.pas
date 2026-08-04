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
    function BuildDecisionPrompt(const AContextJson: string): string;
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
  System.JSON,
  System.SyncObjs,
  RadIA.Core.TokenUsage,
  RadIA.Core.Types;

type
  IRadIAAgentProviderWaitState = interface
    ['{6239853D-E4F3-4DB3-8FF0-063831374028}']
    procedure Complete(
      const AResponse: string;
      const AError: string
    );
    function WaitFor(const ATimeout: Cardinal): TWaitResult;
    function GetResponse: string;
    function GetError: string;
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
  public
    constructor Create;
    destructor Destroy; override;
    procedure Complete(
      const AResponse: string;
      const AError: string
    );
    function WaitFor(const ATimeout: Cardinal): TWaitResult;
    function GetResponse: string;
    function GetError: string;
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
  const AError: string
);
begin
  if TInterlocked.CompareExchange(FCompleted, 1, 0) <> 0 then
    Exit;
  FResponse := AResponse;
  FError := AError;
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
end;

function TRadIAAgentServiceDecisionProvider.BuildDecisionPrompt(
  const AContextJson: string
): string;
begin
  Result :=
    'You are the RadIA agent planner running inside RAD Studio. ' +
    'Choose exactly one next action for the objective and current state. ' +
    'Use only a tool from the supplied catalog. Never invent a tool. ' +
    'Before the first tool call, return a concise plan for user approval. ' +
    'If CURRENT_STATE.plan is empty, the only valid response is: ' +
    '{"kind":"plan","message":"Approve this plan to continue.",' +
    '"steps":[{"title":"Inspect","description":"Read current state"}]}. ' +
    'After CURRENT_STATE.planApproved is true, choose the next action. ' +
    'Return one JSON object and no markdown. Valid responses are: ' +
    '{"kind":"tool","tool":"ToolName","arguments":{}}, ' +
    '{"kind":"complete","message":"summary"}, or ' +
    '{"kind":"fail","message":"reason"}. ' +
    'Prefer read-only inspection before mutation. Mutating and execution tools ' +
    'remain subject to RadIA consent and audit policies. After any source, ' +
    'project, or Designer mutation, inspect structured diagnostics and run ' +
    'BuildProject. Never complete while CURRENT_STATE.validation.buildPassed ' +
    'is false. When DUnitX tests are available, run RunDUnitXTests after a ' +
    'successful build. If build or tests fail, inspect their structured ' +
    'result, prepare the smallest reviewable correction, request consent, ' +
    'apply it, and repeat. Do not repeat an unchanged patch or tool call.' +
    sLineBreak +
    'TOOLS:' + sLineBreak + FSettings.ToolCatalogJson + sLineBreak +
    'CURRENT_STATE:' + sLineBreak + AContextJson;
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
    LState.Complete('', 'Agent decision was cancelled.');
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
  LError: string;
  LState: IRadIAAgentProviderWaitState;
  LWaitResult: TWaitResult;
begin
  LState := TRadIAAgentProviderWaitState.Create;
  TMonitor.Enter(Self);
  try
    FActiveWaitState := LState;
  finally
    TMonitor.Exit(Self);
  end;
  try
    FService.SendPrompt(
      BuildDecisionPrompt(AContextJson),
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
        LState.Complete(AResponse, AError);
      end,
      rpGeneralChat
    );
    LWaitResult := LState.WaitFor(FSettings.TimeoutMilliseconds);
    if LWaitResult <> wrSignaled then
    begin
      FService.CancelCurrentRequest;
      raise ERadIAAgentProviderTimeout.Create(
        'Agent decision timed out while waiting for the AI provider.'
      );
    end;
    LError := LState.GetError;
    if LError <> '' then
      raise Exception.Create('Agent provider failed: ' + LError);
    Result := ParseDecision(LState.GetResponse);
  finally
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
