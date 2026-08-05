unit RadIA.Core.InstallationHealthTools;

interface

uses
  RadIA.Core.Interfaces,
  RadIA.Core.Tools;

type
  IRadIAInstallationHealthProbe = interface
    ['{8188E3A4-B0B1-4708-B310-060E9E961635}']
    function Diagnose: string;
  end;

  TRadIAInstallationHealthProbe = class(
    TInterfacedObject,
    IRadIAInstallationHealthProbe
  )
  private
    FBridgePath: string;
    FConfig: IRadIAConfig;
    FWebDirectory: string;
    function IsProviderConfigured(const AProviderId: string): Boolean;
  public
    constructor Create(
      const AConfig: IRadIAConfig;
      const ABridgePath: string;
      const AWebDirectory: string
    );
    function Diagnose: string;
  end;

procedure RegisterRadIAInstallationHealthTools(
  const ARegistry: IRadIAToolRegistry;
  const AProbe: IRadIAInstallationHealthProbe
);

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliManager,
  RadIA.Core.CliMcpSettings,
  RadIA.Core.PseudoTerminal;

type
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

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';

constructor TRadIAInstallationHealthProbe.Create(
  const AConfig: IRadIAConfig;
  const ABridgePath: string;
  const AWebDirectory: string
);
begin
  inherited Create;
  if not Assigned(AConfig) then
    raise EArgumentNilException.Create('AConfig');
  FConfig := AConfig;
  FBridgePath := TPath.GetFullPath(ABridgePath);
  FWebDirectory := TPath.GetFullPath(AWebDirectory);
end;

function TRadIAInstallationHealthProbe.IsProviderConfigured(
  const AProviderId: string
): Boolean;
begin
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

function TRadIAInstallationHealthProbe.Diagnose: string;
var
  LCliDefinition: TRadIACliDefinition;
  LCliDetection: TRadIACliDetection;
  LCliDetector: TRadIACliDetector;
  LCliInstalled: Boolean;
  LExecutorSettings: TRadIAAgentExecutorSettings;
  LExecutorStore: TRadIAAgentExecutorSettingsStore;
  LIssues: TJSONArray;
  LMcpConfigured: Boolean;
  LMcpSettings: TRadIACliMcpClientSettings;
  LMcpStore: TRadIACliMcpSettings;
  LProviderId: string;
  LProviderReady: Boolean;
  LRecommendations: TJSONArray;
  LRoot: TJSONObject;
  LTerminalReady: Boolean;
  LWebReady: Boolean;
  procedure AddIssue(
    const ACode: string;
    const AMessage: string;
    const ARecommendation: string
  );
  begin
    LIssues.Add(ACode + ': ' + AMessage);
    LRecommendations.Add(ARecommendation);
  end;
begin
  LProviderId := FConfig.GetActiveProvider;
  LProviderReady := IsProviderConfigured(LProviderId);
  LExecutorStore := TRadIAAgentExecutorSettingsStore.Create;
  try
    LExecutorSettings := LExecutorStore.Load;
  finally
    LExecutorStore.Free;
  end;
  LCliInstalled := LExecutorSettings.Kind = aekNative;
  LMcpConfigured := False;
  if TRadIACliCatalog.FindById(
    LExecutorSettings.CliClientId,
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
    if LExecutorSettings.Kind = aekCli then
    begin
      LCliDetector := TRadIACliDetector.Create;
      try
        LCliDetection := LCliDetector.Detect(
          LCliDefinition,
          LMcpSettings.CliExecutablePath
        );
        LCliInstalled := LCliDetection.Installed;
      finally
        LCliDetector.Free;
      end;
    end;
    LMcpConfigured := TFile.Exists(LMcpSettings.McpConfigPath);
  end;
  LTerminalReady := TRadIAPseudoTerminalRunner.IsSupported;
  LWebReady :=
    TFile.Exists(TPath.Combine(FWebDirectory, 'chat.html')) and
    TFile.Exists(TPath.Combine(FWebDirectory, 'chat.js')) and
    TFile.Exists(TPath.Combine(FWebDirectory, 'chat.css'));

  LRoot := TJSONObject.Create;
  try
    LIssues := TJSONArray.Create;
    LRecommendations := TJSONArray.Create;
    LRoot.AddPair('issues', LIssues);
    LRoot.AddPair('recommendations', LRecommendations);
    if not LProviderReady then
      AddIssue(
        'provider_not_configured',
        'The active provider is not ready.',
        'Open /settings and configure or authenticate the active provider.'
      );
    if not LCliInstalled then
      AddIssue(
        'cli_not_detected',
        'The selected CLI executable was not detected.',
        'Use Settings > CLI & MCP to diagnose or install the selected CLI.'
      );
    if not TFile.Exists(FBridgePath) then
      AddIssue(
        'mcp_bridge_missing',
        'The MCP bridge executable is missing.',
        'Repair the RadIA installation for the current IDE architecture.'
      )
    else if not LMcpConfigured then
      AddIssue(
        'mcp_not_configured',
        'The selected MCP client configuration was not found.',
        'Use Settings > CLI & MCP to preview and provision MCP.'
      );
    if not LTerminalReady then
      AddIssue(
        'interactive_terminal_unavailable',
        'Windows ConPTY is unavailable.',
        'Update Windows or use the non-interactive terminal fallback.'
      );
    if not LWebReady then
      AddIssue(
        'web_assets_missing',
        'Chat web assets are incomplete.',
        'Repair the RadIA installation to restore WebView resources.'
      );
    if LIssues.Count = 0 then
      LRoot.AddPair('status', 'ready')
    else
      LRoot.AddPair('status', 'attention');
    LRoot.AddPair('activeProvider', LProviderId);
    LRoot.AddPair('providerConfigured', TJSONBool.Create(LProviderReady));
    LRoot.AddPair('executor', LExecutorSettings.CliClientId);
    LRoot.AddPair('cliRequired', TJSONBool.Create(
      LExecutorSettings.Kind = aekCli
    ));
    LRoot.AddPair('cliDetected', TJSONBool.Create(LCliInstalled));
    LRoot.AddPair(
      'mcpBridgeAvailable',
      TJSONBool.Create(TFile.Exists(FBridgePath))
    );
    LRoot.AddPair('mcpConfigured', TJSONBool.Create(LMcpConfigured));
    LRoot.AddPair('interactiveTerminal', TJSONBool.Create(LTerminalReady));
    LRoot.AddPair('webAssetsAvailable', TJSONBool.Create(LWebReady));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
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
    '1.0.0',
    'Diagnoses provider, CLI, MCP, terminal, and local web assets.',
    CEmptyInputSchema,
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
end;

end.
