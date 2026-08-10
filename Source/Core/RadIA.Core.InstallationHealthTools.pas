unit RadIA.Core.InstallationHealthTools;

interface

uses
  System.JSON,
  RadIA.Core.Interfaces,
  RadIA.Core.ExternalMcpRuntime,
  RadIA.Core.Tools;

type
  TRadIAInstallationReadiness = record
  private
    FCliDetected: Boolean;
    FCliId: string;
    FCliPath: string;
    FCliRequired: Boolean;
    FExecutorKind: string;
    FExecutorId: string;
    FExternalMcpAvailable: Boolean;
    FExternalMcpStatus: TRadIAExternalMcpRuntimeStatus;
    FFirstToolReady: Boolean;
    FMcpBridgeAvailable: Boolean;
    FMcpConfigured: Boolean;
    FMcpReady: Boolean;
    FMcpRequired: Boolean;
    FProviderId: string;
    FProviderTransport: string;
    FProviderReady: Boolean;
    FTerminalReady: Boolean;
    FToolCount: Integer;
    FWebReady: Boolean;
  end;

  IRadIAInstallationHealthProbe = interface
    ['{8188E3A4-B0B1-4708-B310-060E9E961635}']
    function Diagnose: string;
    function DiagnoseDeep: string;
    function Status(
      const AFilter: string;
      const AAgentModeEnabled: Boolean
    ): string;
  end;

  TRadIAInstallationHealthProbe = class(
    TInterfacedObject,
    IRadIAInstallationHealthProbe
  )
  private
    FBridgePath: string;
    FConfig: IRadIAConfig;
    FExternalMcpRuntime: IRadIAExternalMcpRuntime;
    FRegistry: IRadIAToolRegistry;
    FWebDirectory: string;
    procedure AddIssues(
      const AReadiness: TRadIAInstallationReadiness;
      const AIssues: TJSONArray;
      const ARecommendations: TJSONArray
    );
    procedure AddReadiness(
      const ARoot: TJSONObject;
      const AReadiness: TRadIAInstallationReadiness
    );
    procedure AddDetailedChecks(
      const ARoot: TJSONObject;
      const AReadiness: TRadIAInstallationReadiness
    );
    procedure AddStatusSections(
      const ARoot: TJSONObject;
      const AReadiness: TRadIAInstallationReadiness;
      const AFilter: string;
      const AAgentModeEnabled: Boolean
    );
    function CollectReadiness: TRadIAInstallationReadiness;
    function IsProviderConfigured(const AProviderId: string): Boolean;
    function ProviderUsesCodex(const AProviderId: string): Boolean;
    function IsFirstToolReady: Boolean;
    procedure AddDeepCliChecks(
      const ARoot: TJSONObject;
      const AReadiness: TRadIAInstallationReadiness
    );
    procedure AddDeepExternalMcpChecks(const ARoot: TJSONObject);
    function NextAction(
      const AReadiness: TRadIAInstallationReadiness
    ): string;
  public
    constructor Create(
      const AConfig: IRadIAConfig;
      const ABridgePath: string;
      const AWebDirectory: string
    ); overload;
    constructor Create(
      const AConfig: IRadIAConfig;
      const ABridgePath: string;
      const AWebDirectory: string;
      const ARegistry: IRadIAToolRegistry
    ); overload;
    constructor Create(
      const AConfig: IRadIAConfig;
      const ABridgePath: string;
      const AWebDirectory: string;
      const ARegistry: IRadIAToolRegistry;
      const AExternalMcpRuntime: IRadIAExternalMcpRuntime
    ); overload;
    function Diagnose: string;
    function DiagnoseDeep: string;
    function Status(
      const AFilter: string;
      const AAgentModeEnabled: Boolean
    ): string;
  end;

procedure RegisterRadIAInstallationHealthTools(
  const ARegistry: IRadIAToolRegistry;
  const AProbe: IRadIAInstallationHealthProbe
);

implementation

uses
  System.IOUtils,
  System.SyncObjs,
  System.SysUtils,
  RadIA.Core.ResultCompactionSettings,
  RadIA.Core.ResultCompactor,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliManager,
  RadIA.Core.CliMcpSettings,
  RadIA.Core.CliProcess,
  RadIA.Core.ExternalMcp,
  RadIA.Core.PseudoTerminal;

type
  IRadIADeepProbeWaiter = interface
    ['{A68168D5-F19E-46EF-AD2C-EEC730151EDA}']
    procedure Complete(const AResult: TRadIACliProcessResult);
    function GetResult: TRadIACliProcessResult;
    function WaitFor(const ATimeoutMs: Cardinal): Boolean;
  end;

  TRadIADeepProbeWaiter = class(
    TInterfacedObject,
    IRadIADeepProbeWaiter
  )
  private
    FEvent: TEvent;
    FResult: TRadIACliProcessResult;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Complete(const AResult: TRadIACliProcessResult);
    function GetResult: TRadIACliProcessResult;
    function WaitFor(const ATimeoutMs: Cardinal): Boolean;
  end;

  TRadIAInstallationHealthTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FProbe: IRadIAInstallationHealthProbe;
  public
    constructor Create(const AProbe: IRadIAInstallationHealthProbe);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIAStatusTool = class(TInterfacedObject, IRadIATool)
  private
    FProbe: IRadIAInstallationHealthProbe;
  public
    constructor Create(const AProbe: IRadIAInstallationHealthProbe);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIADeepInstallationHealthTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FProbe: IRadIAInstallationHealthProbe;
  public
    constructor Create(const AProbe: IRadIAInstallationHealthProbe);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CExecutorKindNames: array[TRadIAAgentExecutorKind] of string = (
    'native',
    'external-cli'
  );
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CStatusInputSchema =
    '{"type":"object","additionalProperties":false,"properties":{' +
    '"filter":{"type":"string","enum":["all","provider","agent",' +
    '"cli","mcp","security","editor","project","tools","logging"]},' +
    '"agentModeEnabled":{"type":"boolean"}}}';
  CDeepProbeTimeoutMs = 10000;

constructor TRadIADeepProbeWaiter.Create;
begin
  inherited Create;
  FEvent := TEvent.Create(nil, True, False, '');
end;

destructor TRadIADeepProbeWaiter.Destroy;
begin
  FEvent.Free;
  inherited;
end;

procedure TRadIADeepProbeWaiter.Complete(
  const AResult: TRadIACliProcessResult
);
begin
  FResult := AResult;
  FEvent.SetEvent;
end;

function TRadIADeepProbeWaiter.GetResult: TRadIACliProcessResult;
begin
  Result := FResult;
end;

function TRadIADeepProbeWaiter.WaitFor(
  const ATimeoutMs: Cardinal
): Boolean;
begin
  Result := FEvent.WaitFor(ATimeoutMs) = wrSignaled;
end;

constructor TRadIAInstallationHealthProbe.Create(
  const AConfig: IRadIAConfig;
  const ABridgePath: string;
  const AWebDirectory: string
);
begin
  Create(AConfig, ABridgePath, AWebDirectory, nil, nil);
end;

constructor TRadIAInstallationHealthProbe.Create(
  const AConfig: IRadIAConfig;
  const ABridgePath: string;
  const AWebDirectory: string;
  const ARegistry: IRadIAToolRegistry
);
begin
  Create(AConfig, ABridgePath, AWebDirectory, ARegistry, nil);
end;

constructor TRadIAInstallationHealthProbe.Create(
  const AConfig: IRadIAConfig;
  const ABridgePath: string;
  const AWebDirectory: string;
  const ARegistry: IRadIAToolRegistry;
  const AExternalMcpRuntime: IRadIAExternalMcpRuntime
);
begin
  inherited Create;
  if not Assigned(AConfig) then
    raise EArgumentNilException.Create('AConfig');
  FConfig := AConfig;
  FBridgePath := TPath.GetFullPath(ABridgePath);
  FWebDirectory := TPath.GetFullPath(AWebDirectory);
  FRegistry := ARegistry;
  FExternalMcpRuntime := AExternalMcpRuntime;
end;

function TRadIAInstallationHealthProbe.IsFirstToolReady: Boolean;
var
  LTool: IRadIATool;
begin
  Result := Assigned(FRegistry) and
    FRegistry.TryResolve('GetIDEState', LTool);
end;

function TRadIAInstallationHealthProbe.IsProviderConfigured(
  const AProviderId: string
): Boolean;
begin
  if ProviderUsesCodex(AProviderId) then
    Exit(True);
  if SameText(AProviderId, 'Ollama') then
    Exit(not FConfig.OllamaBaseUrl.Trim.IsEmpty);
  if SameText(AProviderId, 'LMStudio') then
    Exit(not FConfig.GetProviderBaseUrl(AProviderId).Trim.IsEmpty);
  if FConfig.IsWebLoginProvider(AProviderId) or
    SameText(FConfig.GetProviderAuthType(AProviderId), 'oauth') then
    Exit(
      not FConfig.GetOAuthAccessToken(AProviderId).Trim.IsEmpty or
      not FConfig.GetOAuthRefreshToken(AProviderId).Trim.IsEmpty
    );
  Result := not FConfig.GetApiKey(AProviderId).Trim.IsEmpty;
end;

function TRadIAInstallationHealthProbe.ProviderUsesCodex(
  const AProviderId: string
): Boolean;
var
  LAuthType: string;
begin
  if not SameText(AProviderId, 'OpenAI') then
    Exit(False);
  LAuthType := FConfig.GetProviderAuthType(AProviderId);
  Result := SameText(LAuthType, 'oauth_cli') or
    SameText(LAuthType, 'oauth') or
    SameText(LAuthType, 'web_login');
end;

function RunSynchronousCliProbe(
  const AExecutablePath: string;
  const AArguments: TArray<string>;
  out AResult: TRadIACliProcessResult
): Boolean;
var
  LSession: IRadIACliProcessSession;
  LWaiter: IRadIADeepProbeWaiter;
begin
  AResult := Default(TRadIACliProcessResult);
  LWaiter := TRadIADeepProbeWaiter.Create;
  LSession := TRadIACliProcessRunner.Start(
    TRadIACliInvocation.Create(
      AExecutablePath,
      AArguments,
      GetCurrentDir,
      'text'
    ),
    CDeepProbeTimeoutMs,
    nil,
    nil,
    procedure(AProcessResult: TRadIACliProcessResult)
    begin
      LWaiter.Complete(AProcessResult);
    end
  );
  Result := LWaiter.WaitFor(CDeepProbeTimeoutMs + 1000);
  if not Result and Assigned(LSession) then
    LSession.Cancel;
  if Result then
    AResult := LWaiter.GetResult;
end;

procedure AddDeepCheck(
  const AChecks: TJSONArray;
  const AId: string;
  const AStatus: string;
  const AMessage: string;
  const AAction: string
);
var
  LCheck: TJSONObject;
begin
  LCheck := TJSONObject.Create;
  LCheck.AddPair('id', AId);
  LCheck.AddPair('status', AStatus);
  LCheck.AddPair('message', AMessage);
  LCheck.AddPair('action', AAction);
  if SameText(AStatus, 'failed') then
    LCheck.AddPair('severity', 'error')
  else
    LCheck.AddPair('severity', 'none');
  AChecks.AddElement(LCheck);
end;

procedure TRadIAInstallationHealthProbe.AddDeepCliChecks(
  const ARoot: TJSONObject;
  const AReadiness: TRadIAInstallationReadiness
);
var
  LActiveModel: string;
  LChecks: TJSONArray;
  LDefinition: TRadIACliDefinition;
  LResult: TRadIACliProcessResult;
  LVersion: string;
begin
  LChecks := ARoot.GetValue<TJSONArray>('activeChecks');
  if not AReadiness.FCliRequired then
  begin
    AddDeepCheck(
      LChecks,
      'cli-runtime',
      'not-required',
      'The effective route does not require a CLI.',
      ''
    );
    Exit;
  end;
  if not AReadiness.FCliDetected or
    not TRadIACliCatalog.FindById(AReadiness.FCliId, LDefinition) then
  begin
    AddDeepCheck(
      LChecks,
      'cli-runtime',
      'failed',
      'The effective CLI could not be executed.',
      '/settings'
    );
    Exit;
  end;
  if RunSynchronousCliProbe(AReadiness.FCliPath, ['--version'], LResult) and
    LResult.Succeeded then
  begin
    LVersion := TRadIACliHealth.NormalizeVersionOutput(
      LResult.StdOut,
      LResult.StdErr
    );
    LActiveModel := FConfig.GetActiveModel(AReadiness.FProviderId);
    if SameText(AReadiness.FCliId, 'codex') and
      SameText(AReadiness.FProviderTransport, 'codex-cli') and
      LActiveModel.StartsWith('gpt-5.6-', True) and
      not TRadIACliHealth.VersionMeetsMinimum(LVersion, '0.144.4') then
      AddDeepCheck(
        LChecks,
        'cli-version',
        'failed',
        'Codex CLI ' + LVersion + ' is too old for the selected ' +
          LActiveModel + ' model. Update to version 0.144.4 or newer, ' +
          'then run Diagnose and refresh the model list.',
        '/settings'
      )
    else
      AddDeepCheck(
        LChecks,
        'cli-version',
        'passed',
        'CLI version probe succeeded: ' + LVersion,
        ''
      );
  end
  else
    AddDeepCheck(
      LChecks,
      'cli-version',
      'failed',
      'The CLI was detected but its version probe failed.',
      '/settings'
    );
  if Length(LDefinition.AuthStatusArguments) = 0 then
  begin
    AddDeepCheck(
      LChecks,
      'cli-authentication',
      'not-supported',
      'This CLI requires a manual authentication check: ' +
        LDefinition.AuthLoginHint,
      ''
    );
    Exit;
  end;
  if RunSynchronousCliProbe(
    AReadiness.FCliPath,
    LDefinition.AuthStatusArguments,
    LResult
  ) and LResult.Succeeded then
    AddDeepCheck(
      LChecks,
      'cli-authentication',
      'passed',
      'CLI authentication is ready.',
      ''
    )
  else
    AddDeepCheck(
      LChecks,
      'cli-authentication',
      'failed',
      'CLI authentication is not ready. Login command: ' +
        LDefinition.AuthLoginHint,
      '/settings'
    );
end;

procedure TRadIAInstallationHealthProbe.AddDeepExternalMcpChecks(
  const ARoot: TJSONObject
);
var
  LChecks: TJSONArray;
  LEnabledCount: Integer;
  LError: string;
  LServer: TRadIAExternalMcpServerConfig;
  LServers: TArray<TRadIAExternalMcpServerConfig>;
  LStatus: TRadIAExternalMcpRuntimeStatus;
begin
  LChecks := ARoot.GetValue<TJSONArray>('activeChecks');
  if not Assigned(FExternalMcpRuntime) then
  begin
    AddDeepCheck(
      LChecks,
      'external-mcp-handshake',
      'not-required',
      'The external MCP runtime is not active.',
      ''
    );
    Exit;
  end;
  LServers := FExternalMcpRuntime.GetServers;
  LEnabledCount := 0;
  for LServer in LServers do
  begin
    if not LServer.Enabled then
      Continue;
    Inc(LEnabledCount);
    if FExternalMcpRuntime.TestServer(LServer, LStatus, LError) then
      AddDeepCheck(
        LChecks,
        'external-mcp-' + LServer.Id,
        'passed',
        Format(
          'MCP handshake succeeded with %d tools, %d resources, and %d prompts.',
          [LStatus.ToolCount, LStatus.ResourceCount, LStatus.PromptCount]
        ),
        ''
      )
    else
      AddDeepCheck(
        LChecks,
        'external-mcp-' + LServer.Id,
        'failed',
        'The MCP handshake failed. Details remain in the local RadIA log.',
        '/settings'
      );
  end;
  if LEnabledCount = 0 then
    AddDeepCheck(
      LChecks,
      'external-mcp-handshake',
      'not-required',
      'No external MCP server is configured.',
      ''
    );
end;

function TRadIAInstallationHealthProbe.DiagnoseDeep: string;
var
  LActiveChecks: TJSONArray;
  LBaseScore: Integer;
  LFailedCount: Integer;
  LIndex: Integer;
  LPair: TJSONPair;
  LReadiness: TRadIAInstallationReadiness;
  LRoot: TJSONObject;
begin
  LReadiness := CollectReadiness;
  LRoot := TJSONObject.ParseJSONValue(Diagnose) as TJSONObject;
  try
    LPair := LRoot.RemovePair('profile');
    LPair.Free;
    LRoot.AddPair('profile', 'deep-active');
    LPair := LRoot.RemovePair('diagnosticVersion');
    LPair.Free;
    LRoot.AddPair('diagnosticVersion', '2.2');
    LRoot.AddPair('consentRequired', TJSONBool.Create(True));
    LActiveChecks := TJSONArray.Create;
    LRoot.AddPair('activeChecks', LActiveChecks);
    AddDeepCliChecks(LRoot, LReadiness);
    AddDeepExternalMcpChecks(LRoot);
    LFailedCount := 0;
    for LIndex := 0 to LActiveChecks.Count - 1 do
      if SameText(
        LActiveChecks[LIndex].GetValue<string>('status'),
        'failed'
      ) then
        Inc(LFailedCount);
    LRoot.AddPair('activeCheckCount', LActiveChecks.Count);
    LRoot.AddPair('activeFailureCount', LFailedCount);
    if LFailedCount > 0 then
    begin
      LPair := LRoot.RemovePair('status');
      LPair.Free;
      LRoot.AddPair('status', 'attention');
      LPair := LRoot.RemovePair('summary');
      LPair.Free;
      LRoot.AddPair(
        'summary',
        Format('%d active diagnostic checks require attention.', [LFailedCount])
      );
      LPair := LRoot.RemovePair('nextAction');
      LPair.Free;
      LRoot.AddPair('nextAction', 'configure_cli');
      LBaseScore := LRoot.GetValue<Integer>('readinessScore', 0);
      LPair := LRoot.RemovePair('readinessScore');
      LPair.Free;
      if LBaseScore > 15 then
        Dec(LBaseScore, 15)
      else
        LBaseScore := 0;
      LRoot.AddPair('readinessScore', LBaseScore);
    end;
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAInstallationHealthProbe.Diagnose: string;
var
  LEvaluatedAreas: TJSONArray;
  LIssues: TJSONArray;
  LReadiness: TRadIAInstallationReadiness;
  LRecommendations: TJSONArray;
  LRoot: TJSONObject;
  LRoute: TJSONObject;
begin
  LReadiness := CollectReadiness;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('diagnosticVersion', '2.0');
    LRoot.AddPair('profile', 'full-local');
    LRoot.AddPair('sanitized', TJSONBool.Create(True));
    LEvaluatedAreas := TJSONArray.Create;
    LEvaluatedAreas.Add('provider');
    LEvaluatedAreas.Add('effectiveRoute');
    LEvaluatedAreas.Add('cli');
    LEvaluatedAreas.Add('mcp');
    LEvaluatedAreas.Add('terminal');
    LEvaluatedAreas.Add('chat');
    LEvaluatedAreas.Add('tools');
    LEvaluatedAreas.Add('externalMcp');
    LRoot.AddPair('evaluatedAreas', LEvaluatedAreas);
    LRoute := TJSONObject.Create;
    LRoute.AddPair('orchestration', LReadiness.FExecutorKind);
    LRoute.AddPair('providerTransport', LReadiness.FProviderTransport);
    LRoute.AddPair('effectiveCli', LReadiness.FCliId);
    LRoute.AddPair(
      'cliRequired',
      TJSONBool.Create(LReadiness.FCliRequired)
    );
    LRoute.AddPair(
      'mcpRequired',
      TJSONBool.Create(LReadiness.FMcpRequired)
    );
    LRoute.AddPair(
      'nonGitWorkspaceSupported',
      TJSONBool.Create(True)
    );
    LRoot.AddPair('effectiveRoute', LRoute);
    LIssues := TJSONArray.Create;
    LRecommendations := TJSONArray.Create;
    LRoot.AddPair('issues', LIssues);
    LRoot.AddPair('recommendations', LRecommendations);
    AddIssues(LReadiness, LIssues, LRecommendations);
    if LIssues.Count = 0 then
      LRoot.AddPair('status', 'ready')
    else
      LRoot.AddPair('status', 'attention');
    AddReadiness(LRoot, LReadiness);
    AddDetailedChecks(LRoot, LReadiness);
    LRoot.AddPair(
      'summary',
      Format(
        '%d of %d readiness checks passed.',
        [
          LRoot.GetValue<Integer>('readyCheckCount', 0),
          LRoot.GetValue<Integer>('totalCheckCount', 0)
        ]
      )
    );
    LRoot.AddPair('nextAction', NextAction(LReadiness));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAInstallationHealthProbe.Status(
  const AFilter: string;
  const AAgentModeEnabled: Boolean
): string;
var
  LFilter: string;
  LReadiness: TRadIAInstallationReadiness;
  LRoot: TJSONObject;
begin
  LFilter := LowerCase(Trim(AFilter));
  if LFilter = '' then
    LFilter := 'all';
  LReadiness := CollectReadiness;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('scope', LFilter);
    LRoot.AddPair('sanitized', TJSONBool.Create(True));
    if NextAction(LReadiness) = 'run_first_read_only_tool' then
      LRoot.AddPair('status', 'ready')
    else
      LRoot.AddPair('status', 'attention');
    AddStatusSections(LRoot, LReadiness, LFilter, AAgentModeEnabled);
    LRoot.AddPair('nextAction', NextAction(LReadiness));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

procedure TRadIAInstallationHealthProbe.AddStatusSections(
  const ARoot: TJSONObject;
  const AReadiness: TRadIAInstallationReadiness;
  const AFilter: string;
  const AAgentModeEnabled: Boolean
);
var
  LCompactionSettings: TRadIAResultCompactionSettings;
  LCompactionSettingsStore: TRadIAResultCompactionSettingsStore;
  LSection: TJSONObject;
  function Includes(const AName: string): Boolean;
  begin
    Result := SameText(AFilter, 'all') or SameText(AFilter, AName);
  end;
begin
  if Includes('provider') then
  begin
    LSection := TJSONObject.Create;
    LSection.AddPair('active', AReadiness.FProviderId);
    LSection.AddPair('configured', TJSONBool.Create(AReadiness.FProviderReady));
    LSection.AddPair('authType', FConfig.GetProviderAuthType(AReadiness.FProviderId));
    LSection.AddPair('model', FConfig.GetActiveModel(AReadiness.FProviderId));
    ARoot.AddPair('provider', LSection);
  end;
  if Includes('agent') then
  begin
    LCompactionSettingsStore :=
      TRadIAResultCompactionSettingsStore.Create;
    try
      LCompactionSettings := LCompactionSettingsStore.Load;
    finally
      LCompactionSettingsStore.Free;
    end;
    LSection := TJSONObject.Create;
    LSection.AddPair('modeEnabled', TJSONBool.Create(AAgentModeEnabled));
    LSection.AddPair('executorKind', AReadiness.FExecutorKind);
    LSection.AddPair('client', AReadiness.FExecutorId);
    LSection.AddPair(
      'resultCompactionProfile',
      RadIACompactionProfileName(RadIAResolveCompactionProfile)
    );
    LSection.AddPair('resultRecoveryAvailable', TJSONBool.Create(True));
    LSection.AddPair(
      'maximumDecisionContextCharacters',
      TJSONNumber.Create(
        LCompactionSettings.MaximumDecisionContextCharacters
      )
    );
    ARoot.AddPair('agent', LSection);
  end;
  if Includes('cli') then
  begin
    LSection := TJSONObject.Create;
    LSection.AddPair('required', TJSONBool.Create(AReadiness.FCliRequired));
    LSection.AddPair('client', AReadiness.FCliId);
    LSection.AddPair('detected', TJSONBool.Create(AReadiness.FCliDetected));
    LSection.AddPair('effectivePath', AReadiness.FCliPath);
    LSection.AddPair('guidedInstallAvailable', TJSONBool.Create(True));
    LSection.AddPair('manualFallbackAvailable', TJSONBool.Create(True));
    LSection.AddPair('diagnoseAction', 'Settings > CLI & MCP > Diagnose');
    LSection.AddPair(
      'setupHistoryAvailable',
      TJSONBool.Create(TFile.Exists(TRadIACliSetupHistory.FileName))
    );
    ARoot.AddPair('cli', LSection);
  end;
  if Includes('mcp') then
  begin
    LSection := TJSONObject.Create;
    LSection.AddPair('required', TJSONBool.Create(AReadiness.FMcpRequired));
    LSection.AddPair('bridgeAvailable', TJSONBool.Create(AReadiness.FMcpBridgeAvailable));
    LSection.AddPair('configured', TJSONBool.Create(AReadiness.FMcpConfigured));
    LSection.AddPair('ready', TJSONBool.Create(AReadiness.FMcpReady));
    LSection.AddPair('setupFlow', 'Preview > Connect / Repair > Test Handshake');
    if AReadiness.FExternalMcpAvailable then
    begin
      LSection.AddPair(
        'externalConfiguredServers',
        AReadiness.FExternalMcpStatus.ConfiguredServers
      );
      LSection.AddPair(
        'externalEnabledServers',
        AReadiness.FExternalMcpStatus.EnabledServers
      );
      LSection.AddPair(
        'externalConnectedServers',
        AReadiness.FExternalMcpStatus.ConnectedServers
      );
      LSection.AddPair(
        'externalGrantedTools',
        AReadiness.FExternalMcpStatus.GrantedTools
      );
      LSection.AddPair(
        'externalDiscoveredTools',
        AReadiness.FExternalMcpStatus.ToolCount
      );
      LSection.AddPair(
        'externalResources',
        AReadiness.FExternalMcpStatus.ResourceCount
      );
      LSection.AddPair(
        'externalPrompts',
        AReadiness.FExternalMcpStatus.PromptCount
      );
      LSection.AddPair(
        'externalErrors',
        AReadiness.FExternalMcpStatus.ErrorCount
      );
      LSection.AddPair(
        'externalRefreshWithoutRestart',
        TJSONBool.Create(True)
      );
    end;
    ARoot.AddPair('mcp', LSection);
  end;
  if Includes('security') then
  begin
    LSection := TJSONObject.Create;
    LSection.AddPair('consentTimeoutSeconds', FConfig.ConsentTimeoutSeconds);
    LSection.AddPair('showArguments', TJSONBool.Create(FConfig.ConsentShowArguments));
    LSection.AddPair('rememberReversible', TJSONBool.Create(FConfig.ConsentRememberReversible));
    LSection.AddPair('rememberStructural', TJSONBool.Create(FConfig.ConsentRememberStructural));
    LSection.AddPair('rememberExecution', TJSONBool.Create(FConfig.ConsentRememberExecution));
    ARoot.AddPair('security', LSection);
  end;
  if Includes('editor') then
  begin
    LSection := TJSONObject.Create;
    LSection.AddPair('inlineCompletion', TJSONBool.Create(FConfig.AutocompleteEnabled));
    LSection.AddPair('inlineProvider', FConfig.AutocompleteProvider);
    LSection.AddPair('inlineModel', FConfig.AutocompleteModel);
    LSection.AddPair('idleDelayMs', FConfig.AutocompleteDelay);
    LSection.AddPair('knowledgeLocal', TJSONBool.Create(FConfig.KnowledgeSemanticEnabled));
    LSection.AddPair('approvedRunHistory', TJSONBool.Create(FConfig.KnowledgeApprovedHistoryEnabled));
    ARoot.AddPair('editor', LSection);
  end;
  if Includes('tools') then
  begin
    LSection := TJSONObject.Create;
    LSection.AddPair('registered', AReadiness.FToolCount);
    LSection.AddPair('firstToolReady', TJSONBool.Create(AReadiness.FFirstToolReady));
    ARoot.AddPair('tools', LSection);
  end;
  if Includes('logging') then
  begin
    LSection := TJSONObject.Create;
    LSection.AddPair('enabled', TJSONBool.Create(FConfig.LogEnabled));
    LSection.AddPair('pathConfigured', TJSONBool.Create(not FConfig.LogPath.Trim.IsEmpty));
    LSection.AddPair('maxSizeKB', FConfig.LogMaxSizeKB);
    LSection.AddPair('quotaEnabled', TJSONBool.Create(FConfig.QuotaEnabled));
    LSection.AddPair('quotaLimit', TJSONNumber.Create(FConfig.QuotaLimit));
    LSection.AddPair('quotaUsed', TJSONNumber.Create(FConfig.QuotaUsed));
    ARoot.AddPair('logging', LSection);
  end;
  if Includes('project') then
  begin
    LSection := TJSONObject.Create;
    LSection.AddPair('activeSession', TJSONBool.Create(not FConfig.ActiveSessionId.Trim.IsEmpty));
    LSection.AddPair('detailedHealthCommand', '/health');
    ARoot.AddPair('project', LSection);
  end;
end;

procedure TRadIAInstallationHealthProbe.AddDetailedChecks(
  const ARoot: TJSONObject;
  const AReadiness: TRadIAInstallationReadiness
);
var
  LChecks: TJSONArray;
  LReadyCount: Integer;
  procedure AddCheck(
    const AId: string;
    const AReady: Boolean;
    const ARequired: Boolean;
    const AAction: string
  );
  var
    LCheck: TJSONObject;
  begin
    LCheck := TJSONObject.Create;
    LCheck.AddPair('id', AId);
    LCheck.AddPair('ready', TJSONBool.Create(AReady));
    LCheck.AddPair('required', TJSONBool.Create(ARequired));
    if AReady then
    begin
      LCheck.AddPair('message', 'Ready');
      if ARequired then
        LCheck.AddPair('status', 'passed')
      else
        LCheck.AddPair('status', 'not-required');
      LCheck.AddPair('severity', 'none');
    end
    else
    begin
      LCheck.AddPair('message', 'Attention required');
      LCheck.AddPair('status', 'failed');
      if ARequired then
        LCheck.AddPair('severity', 'error')
      else
        LCheck.AddPair('severity', 'warning');
    end;
    LCheck.AddPair('action', AAction);
    LChecks.AddElement(LCheck);
    if AReady then
      Inc(LReadyCount);
  end;
begin
  LReadyCount := 0;
  LChecks := TJSONArray.Create;
  ARoot.AddPair('checkDetails', LChecks);
  AddCheck('provider', AReadiness.FProviderReady, True, 'Open /settings.');
  AddCheck(
    'executor',
    not AReadiness.FCliRequired or AReadiness.FCliDetected,
    AReadiness.FCliRequired,
    'Open Settings > CLI & MCP.'
  );
  AddCheck('mcp', AReadiness.FMcpReady, AReadiness.FMcpRequired, 'Connect or repair MCP.');
  AddCheck('terminal', AReadiness.FTerminalReady, True, 'Use /terminal.');
  AddCheck('chat', AReadiness.FWebReady, True, 'Repair the installation.');
  AddCheck('firstTool', AReadiness.FFirstToolReady, True, 'Repair the package.');
  if AReadiness.FExternalMcpAvailable then
    AddCheck(
      'externalMcp',
      AReadiness.FExternalMcpStatus.ErrorCount = 0,
      AReadiness.FExternalMcpStatus.EnabledServers > 0,
      'Open Settings > CLI & MCP > External MCP Servers.'
    );
  ARoot.AddPair('readyCheckCount', LReadyCount);
  ARoot.AddPair(
    'totalCheckCount',
    6 + Ord(AReadiness.FExternalMcpAvailable)
  );
end;

function TRadIAInstallationHealthProbe.CollectReadiness:
  TRadIAInstallationReadiness;
var
  LCliDefinition: TRadIACliDefinition;
  LCliDetection: TRadIACliDetection;
  LCliDetector: TRadIACliDetector;
  LExecutorSettings: TRadIAAgentExecutorSettings;
  LExecutorStore: TRadIAAgentExecutorSettingsStore;
  LMcpSettings: TRadIACliMcpClientSettings;
  LMcpStore: TRadIACliMcpSettings;
  LProviderUsesCodex: Boolean;
begin
  Result.FProviderId := FConfig.GetActiveProvider;
  Result.FProviderReady := IsProviderConfigured(Result.FProviderId);
  LProviderUsesCodex := ProviderUsesCodex(Result.FProviderId);
  if LProviderUsesCodex then
    Result.FProviderTransport := 'codex-cli'
  else
    Result.FProviderTransport := 'provider-native';
  LExecutorStore := TRadIAAgentExecutorSettingsStore.Create;
  try
    LExecutorSettings := LExecutorStore.Load;
  finally
    LExecutorStore.Free;
  end;
  Result.FExecutorId := LExecutorSettings.CliClientId;
  Result.FExecutorKind := CExecutorKindNames[LExecutorSettings.Kind];
  Result.FCliRequired := LProviderUsesCodex or
    (LExecutorSettings.Kind = aekCli);
  if LProviderUsesCodex then
    Result.FCliId := 'codex'
  else
    Result.FCliId := LExecutorSettings.CliClientId;
  Result.FCliDetected := False;
  Result.FCliPath := '';
  Result.FMcpConfigured := False;
  if TRadIACliCatalog.FindById(
    Result.FCliId,
    LCliDefinition
  ) then
  begin
    LMcpStore := TRadIACliMcpSettings.Create;
    try
      LMcpSettings := LMcpStore.Load(
        LCliDefinition.Id,
        '',
        FBridgePath
      );
    finally
      LMcpStore.Free;
    end;
    if Result.FCliRequired then
    begin
      LCliDetector := TRadIACliDetector.Create;
      try
        LCliDetection := LCliDetector.Detect(
          LCliDefinition,
          LMcpSettings.CliExecutablePath
        );
        Result.FCliDetected := LCliDetection.Installed;
        Result.FCliPath := LCliDetection.ExecutablePath;
      finally
        LCliDetector.Free;
      end;
    end;
    Result.FMcpConfigured := TFile.Exists(
      LMcpSettings.McpConfigPath
    );
  end;
  Result.FTerminalReady := TRadIAPseudoTerminalRunner.IsSupported;
  Result.FWebReady :=
    TFile.Exists(TPath.Combine(FWebDirectory, 'chat.html')) and
    TFile.Exists(TPath.Combine(FWebDirectory, 'chat.js')) and
    TFile.Exists(TPath.Combine(FWebDirectory, 'chat.css'));
  Result.FFirstToolReady := IsFirstToolReady;
  Result.FExternalMcpAvailable := Assigned(FExternalMcpRuntime);
  if Result.FExternalMcpAvailable then
    Result.FExternalMcpStatus := FExternalMcpRuntime.GetStatus;
  if Assigned(FRegistry) then
    Result.FToolCount := FRegistry.GetCount
  else
    Result.FToolCount := 0;
  Result.FMcpBridgeAvailable := TFile.Exists(FBridgePath);
  Result.FMcpRequired := LExecutorSettings.Kind = aekCli;
  Result.FMcpReady := not Result.FMcpRequired or
    (Result.FMcpBridgeAvailable and Result.FMcpConfigured);
end;

procedure TRadIAInstallationHealthProbe.AddIssues(
  const AReadiness: TRadIAInstallationReadiness;
  const AIssues: TJSONArray;
  const ARecommendations: TJSONArray
);
  procedure AddIssue(
    const ACode: string;
    const AMessage: string;
    const ARecommendation: string
  );
  begin
    AIssues.Add(ACode + ': ' + AMessage);
    ARecommendations.Add(ARecommendation);
  end;
begin
  if not AReadiness.FProviderReady then
    AddIssue(
        'provider_not_configured',
        'The active provider is not ready.',
        'Open /settings and configure or authenticate the active provider.'
    );
  if AReadiness.FCliRequired and not AReadiness.FCliDetected then
    AddIssue(
        'cli_not_detected',
        'The selected CLI executable was not detected.',
        'Use Settings > CLI & MCP to diagnose or install the selected CLI.'
    );
  if AReadiness.FMcpRequired and
    not AReadiness.FMcpBridgeAvailable then
    AddIssue(
        'mcp_bridge_missing',
        'The MCP bridge executable is missing.',
        'Repair the RadIA installation for the current IDE architecture.'
    )
  else if AReadiness.FMcpRequired and
    not AReadiness.FMcpConfigured then
    AddIssue(
        'mcp_not_configured',
        'The selected MCP client configuration was not found.',
        'Use Settings > CLI & MCP to preview and provision MCP.'
    );
  if AReadiness.FExternalMcpAvailable and
    (AReadiness.FExternalMcpStatus.ErrorCount > 0) then
    AddIssue(
      'external_mcp_attention',
      'One or more enabled external MCP servers are unavailable.',
      'Open Settings > CLI & MCP > External MCP Servers and run Refresh or Test.'
    );
  if not AReadiness.FTerminalReady then
    AddIssue(
        'interactive_terminal_unavailable',
        'Windows ConPTY is unavailable.',
        'Update Windows or use the non-interactive terminal fallback.'
    );
  if not AReadiness.FWebReady then
    AddIssue(
        'web_assets_missing',
        'Chat web assets are incomplete.',
        'Repair the RadIA installation to restore WebView resources.'
    );
  if not AReadiness.FFirstToolReady then
    AddIssue(
        'first_tool_unavailable',
        'The read-only GetIDEState tool is unavailable.',
        'Repair the RadIA package and restart the IDE.'
    );
end;

procedure TRadIAInstallationHealthProbe.AddReadiness(
  const ARoot: TJSONObject;
  const AReadiness: TRadIAInstallationReadiness
);
var
  LChecks: TJSONObject;
  LReadyCount: Integer;
begin
  ARoot.AddPair('activeProvider', AReadiness.FProviderId);
  ARoot.AddPair('providerTransport', AReadiness.FProviderTransport);
  ARoot.AddPair(
    'providerConfigured',
    TJSONBool.Create(AReadiness.FProviderReady)
  );
  ARoot.AddPair('executor', AReadiness.FExecutorId);
  ARoot.AddPair('effectiveCli', AReadiness.FCliId);
  ARoot.AddPair(
    'cliRequired',
    TJSONBool.Create(AReadiness.FCliRequired)
  );
  ARoot.AddPair(
    'cliDetected',
    TJSONBool.Create(AReadiness.FCliDetected)
  );
  ARoot.AddPair(
    'mcpBridgeAvailable',
    TJSONBool.Create(AReadiness.FMcpBridgeAvailable)
  );
  ARoot.AddPair(
    'mcpConfigured',
    TJSONBool.Create(AReadiness.FMcpConfigured)
  );
  ARoot.AddPair(
    'mcpRequired',
    TJSONBool.Create(AReadiness.FMcpRequired)
  );
  ARoot.AddPair(
    'interactiveTerminal',
    TJSONBool.Create(AReadiness.FTerminalReady)
  );
  ARoot.AddPair(
    'webAssetsAvailable',
    TJSONBool.Create(AReadiness.FWebReady)
  );
  ARoot.AddPair(
    'firstToolReady',
    TJSONBool.Create(AReadiness.FFirstToolReady)
  );
  ARoot.AddPair('toolCount', AReadiness.FToolCount);
  if AReadiness.FExternalMcpAvailable then
  begin
    ARoot.AddPair(
      'externalMcpConfiguredServers',
      AReadiness.FExternalMcpStatus.ConfiguredServers
    );
    ARoot.AddPair(
      'externalMcpConnectedServers',
      AReadiness.FExternalMcpStatus.ConnectedServers
    );
    ARoot.AddPair(
      'externalMcpErrors',
      AReadiness.FExternalMcpStatus.ErrorCount
    );
  end;
  LChecks := TJSONObject.Create;
  ARoot.AddPair('checks', LChecks);
  LChecks.AddPair(
    'provider',
    TJSONBool.Create(AReadiness.FProviderReady)
  );
  LChecks.AddPair(
    'executor',
    TJSONBool.Create(
      not AReadiness.FCliRequired or AReadiness.FCliDetected
    )
  );
  LChecks.AddPair('mcp', TJSONBool.Create(AReadiness.FMcpReady));
  LChecks.AddPair(
    'terminal',
    TJSONBool.Create(AReadiness.FTerminalReady)
  );
  LChecks.AddPair('chat', TJSONBool.Create(AReadiness.FWebReady));
  LChecks.AddPair(
    'firstTool',
    TJSONBool.Create(AReadiness.FFirstToolReady)
  );
  LReadyCount := Ord(AReadiness.FProviderReady) +
    Ord(not AReadiness.FCliRequired or AReadiness.FCliDetected) +
    Ord(AReadiness.FMcpReady) +
    Ord(AReadiness.FTerminalReady) + Ord(AReadiness.FWebReady) +
    Ord(AReadiness.FFirstToolReady);
  ARoot.AddPair(
    'readinessScore',
    TJSONNumber.Create((LReadyCount * 100) div 6)
  );
end;

function TRadIAInstallationHealthProbe.NextAction(
  const AReadiness: TRadIAInstallationReadiness
): string;
begin
  if not AReadiness.FProviderReady then
    Exit('open_provider_settings');
  if not AReadiness.FWebReady then
    Exit('repair_web_assets');
  if AReadiness.FCliRequired and not AReadiness.FCliDetected then
    Exit('configure_cli');
  if not AReadiness.FMcpReady then
    Exit('provision_mcp');
  if AReadiness.FExternalMcpAvailable and
    (AReadiness.FExternalMcpStatus.ErrorCount > 0) then
    Exit('repair_external_mcp');
  if not AReadiness.FTerminalReady then
    Exit('open_terminal_fallback');
  if not AReadiness.FFirstToolReady then
    Exit('repair_package');
  Result := 'run_first_read_only_tool';
end;

constructor TRadIAInstallationHealthTool.Create(
  const AProbe: IRadIAInstallationHealthProbe
);
begin
  inherited Create;
  if not Assigned(AProbe) then
    raise EArgumentNilException.Create('AProbe');
  FProbe := AProbe;
end;

function TRadIAInstallationHealthTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Result := TRadIAToolResult.Succeeded(FProbe.Diagnose);
end;

function TRadIAInstallationHealthTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetInstallationHealth',
    '2.0.0',
    'Diagnoses the effective route, CLI, MCP, terminal, chat, tools, and installation readiness.',
    CEmptyInputSchema,
    '{"type":"object"}',
    trReadOnly
  );
end;

constructor TRadIADeepInstallationHealthTool.Create(
  const AProbe: IRadIAInstallationHealthProbe
);
begin
  inherited Create;
  if not Assigned(AProbe) then
    raise EArgumentNilException.Create('AProbe');
  FProbe := AProbe;
end;

function TRadIADeepInstallationHealthTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Result := TRadIAToolResult.Succeeded(FProbe.DiagnoseDeep);
end;

function TRadIADeepInstallationHealthTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'RunInstallationDeepDiagnostic',
    '1.0.0',
    'Runs consented CLI version and authentication probes plus external MCP handshakes.',
    CEmptyInputSchema,
    '{"type":"object"}',
    trExecution
  ).WithExecutionOptions(120000, False).WithConsentEveryTime;
end;

constructor TRadIAStatusTool.Create(
  const AProbe: IRadIAInstallationHealthProbe
);
begin
  inherited Create;
  if not Assigned(AProbe) then
    raise EArgumentNilException.Create('AProbe');
  FProbe := AProbe;
end;

function TRadIAStatusTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LAgentModeEnabled: Boolean;
  LFilter: string;
  LRoot: TJSONObject;
begin
  LAgentModeEnabled := False;
  LFilter := 'all';
  LRoot := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  try
    if Assigned(LRoot) then
    begin
      LFilter := LRoot.GetValue<string>('filter', 'all');
      LAgentModeEnabled := LRoot.GetValue<Boolean>(
        'agentModeEnabled',
        False
      );
    end;
    Result := TRadIAToolResult.Succeeded(
      FProbe.Status(LFilter, LAgentModeEnabled)
    );
  finally
    LRoot.Free;
  end;
end;

function TRadIAStatusTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetRadIAStatus',
    '1.0.0',
    'Returns a sanitized, filterable snapshot of RadIA configuration and readiness.',
    CStatusInputSchema,
    '{"type":"object"}',
    trReadOnly
  );
end;

procedure RegisterRadIAInstallationHealthTools(
  const ARegistry: IRadIAToolRegistry;
  const AProbe: IRadIAInstallationHealthProbe
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAInstallationHealthTool.Create(AProbe));
  ARegistry.RegisterTool(TRadIADeepInstallationHealthTool.Create(AProbe));
  ARegistry.RegisterTool(TRadIAStatusTool.Create(AProbe));
end;

end.
