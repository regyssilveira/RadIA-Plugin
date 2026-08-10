unit RadIA.Tests.InstallationHealthTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpSecurity,
  RadIA.Core.InstallationHealthTools,
  RadIA.Core.ExternalMcpRuntime,
  RadIA.Core.Tools;

type
  TRadIAFirstReadOnlyTool = class(TInterfacedObject, IRadIATool)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIAInstallationHealthTestProbe = class(
    TInterfacedObject,
    IRadIAInstallationHealthProbe
  )
  public
    function Diagnose: string;
    function DiagnoseDeep: string;
    function Status(
      const AFilter: string;
      const AAgentModeEnabled: Boolean
    ): string;
  end;

  TRadIAInstallationHealthExternalMcpRuntime = class(
    TInterfacedObject,
    IRadIAExternalMcpRuntime
  )
  public
    function GetDiscoveredTools: TArray<TRadIAExternalMcpTool>;
    function GetGrants: TArray<TRadIAExternalMcpToolGrant>;
    function GetServers: TArray<TRadIAExternalMcpServerConfig>;
    function GetStatus: TRadIAExternalMcpRuntimeStatus;
    function Refresh(out AError: string): Boolean;
    function SaveAndRefresh(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean;
    function TestServer(
      const AServer: TRadIAExternalMcpServerConfig;
      out AStatus: TRadIAExternalMcpRuntimeStatus;
      out AError: string
    ): Boolean;
  end;

  [TestFixture]
  TTestRadIAInstallationHealthTools = class
  public
    [Test]
    procedure RegistersReadOnlyDiagnosticTool;
    [Test]
    procedure RegistersReadOnlyStatusTool;
    [Test]
    procedure RegistersConsentedDeepDiagnosticTool;
    [Test]
    procedure DeepDiagnosticRunsApplicableActiveChecks;
    [Test]
    procedure ConcreteProbeReportsLocalReadinessWithoutSecrets;
    [Test]
    procedure StatusFiltersSanitizedConfiguration;
    [Test]
    procedure NativeJourneyDoesNotRequireMcpAndExposesNextAction;
    [Test]
    procedure ChatGptProNativeRouteRequiresCodexButNotMcp;
    [Test]
    procedure StatusSeparatesExternalMcpWithoutExposingConfiguration;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.Config,
  RadIA.Core.Interfaces,
  RadIA.Core.SettingsStorage,
  RadIA.Core.ToolRegistry;

procedure TTestRadIAInstallationHealthTools.
  ChatGptProNativeRouteRequiresCodexButNotMcp;
var
  LConfig: IRadIAConfig;
  LDirectory: string;
  LProbe: IRadIAInstallationHealthProbe;
  LResult: string;
  LStorage: IRadIASettingsStorage;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIAProRoute-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LDirectory);
  try
    LStorage := TRadIAMemorySettingsStorage.Create;
    TRadIAConfig.SetStorage(LStorage);
    LConfig := TRadIAConfig.Create;
    LConfig.SetActiveProvider('OpenAI');
    LConfig.SetProviderAuthType('OpenAI', 'oauth_cli');
    LProbe := TRadIAInstallationHealthProbe.Create(
      LConfig,
      TPath.Combine(LDirectory, 'bridge.exe'),
      LDirectory
    );

    LResult := LProbe.Diagnose;

    Assert.Contains(LResult, '"providerConfigured":true');
    Assert.Contains(LResult, '"providerTransport":"codex-cli"');
    Assert.Contains(LResult, '"effectiveCli":"codex"');
    Assert.Contains(LResult, '"cliRequired":true');
    Assert.Contains(LResult, '"mcpRequired":false');
  finally
    LProbe := nil;
    LConfig := nil;
    LStorage := nil;
    TRadIAConfig.SetStorage(nil);
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

function TRadIAFirstReadOnlyTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Result := TRadIAToolResult.Succeeded('{"ready":true}');
end;

function TRadIAFirstReadOnlyTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetIDEState',
    '1.0.0',
    'Returns IDE state.',
    '{"type":"object"}',
    '{"type":"object"}',
    trReadOnly
  );
end;

function TRadIAInstallationHealthTestProbe.Diagnose: string;
begin
  Result :=
    '{"status":"attention","issues":["mcp_bridge_missing"],' +
    '"recommendations":["Repair the installation."]}';
end;

function TRadIAInstallationHealthTestProbe.Status(
  const AFilter: string;
  const AAgentModeEnabled: Boolean
): string;
begin
  Result := '{"scope":"' + AFilter + '","sanitized":true}';
end;

function TRadIAInstallationHealthTestProbe.DiagnoseDeep: string;
begin
  Result := '{"status":"ready","profile":"deep-active"}';
end;

function TRadIAInstallationHealthExternalMcpRuntime.GetGrants:
  TArray<TRadIAExternalMcpToolGrant>;
begin
  Result := nil;
end;

function TRadIAInstallationHealthExternalMcpRuntime.GetDiscoveredTools:
  TArray<TRadIAExternalMcpTool>;
begin
  Result := nil;
end;

function TRadIAInstallationHealthExternalMcpRuntime.GetServers:
  TArray<TRadIAExternalMcpServerConfig>;
begin
  Result := nil;
end;

function TRadIAInstallationHealthExternalMcpRuntime.GetStatus:
  TRadIAExternalMcpRuntimeStatus;
begin
  Result := Default(TRadIAExternalMcpRuntimeStatus);
end;

function TRadIAInstallationHealthExternalMcpRuntime.Refresh(
  out AError: string
): Boolean;
begin
  AError := '';
  Result := True;
end;

function TRadIAInstallationHealthExternalMcpRuntime.SaveAndRefresh(
  const AServers: TArray<TRadIAExternalMcpServerConfig>;
  const AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out AError: string
): Boolean;
begin
  AError := '';
  Result := True;
end;

function TRadIAInstallationHealthExternalMcpRuntime.TestServer(
  const AServer: TRadIAExternalMcpServerConfig;
  out AStatus: TRadIAExternalMcpRuntimeStatus;
  out AError: string
): Boolean;
begin
  AStatus := Default(TRadIAExternalMcpRuntimeStatus);
  AError := '';
  Result := True;
end;

procedure TTestRadIAInstallationHealthTools.
  NativeJourneyDoesNotRequireMcpAndExposesNextAction;
var
  LBridgePath: string;
  LConfig: IRadIAConfig;
  LDirectory: string;
  LProbe: IRadIAInstallationHealthProbe;
  LRegistry: IRadIAToolRegistry;
  LResult: string;
  LStorage: IRadIASettingsStorage;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIAFirstValue-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LDirectory);
  try
    TFile.WriteAllText(TPath.Combine(LDirectory, 'chat.html'), 'html');
    TFile.WriteAllText(TPath.Combine(LDirectory, 'chat.js'), 'js');
    TFile.WriteAllText(TPath.Combine(LDirectory, 'chat.css'), 'css');
    LBridgePath := TPath.Combine(LDirectory, 'missing-bridge.exe');
    LStorage := TRadIAMemorySettingsStorage.Create;
    TRadIAConfig.SetStorage(LStorage);
    LConfig := TRadIAConfig.Create;
    LConfig.SetActiveProvider('Ollama');
    LConfig.OllamaBaseUrl := 'http://localhost:11434';
    LRegistry := TRadIAToolRegistry.Create;
    LRegistry.RegisterTool(TRadIAFirstReadOnlyTool.Create);
    LProbe := TRadIAInstallationHealthProbe.Create(
      LConfig,
      LBridgePath,
      LDirectory,
      LRegistry
    );

    LResult := LProbe.Diagnose;

    Assert.Contains(LResult, '"mcpRequired":false');
    Assert.Contains(LResult, '"firstToolReady":true');
    Assert.Contains(LResult, '"readinessScore":100');
    Assert.Contains(LResult, '"readyCheckCount":6');
    Assert.Contains(LResult, '"totalCheckCount":6');
    Assert.Contains(LResult, '"summary":"6 of 6 readiness checks passed."');
    Assert.Contains(
      LResult,
      '"nextAction":"run_first_read_only_tool"'
    );
    Assert.DoesNotContain(LResult, 'mcp_bridge_missing');
  finally
    LProbe := nil;
    LRegistry := nil;
    LConfig := nil;
    LStorage := nil;
    TRadIAConfig.SetStorage(nil);
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestRadIAInstallationHealthTools.RegistersReadOnlyStatusTool;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTool: IRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAInstallationHealthTools(
    LRegistry,
    TRadIAInstallationHealthTestProbe.Create
  );
  LTool := LRegistry.Resolve('GetRadIAStatus');
  Assert.AreEqual(trReadOnly, LTool.Descriptor.Risk);
  LResult := LTool.Execute(
    TRadIAToolRequest.Create(
      'GetRadIAStatus',
      '{"filter":"cli","agentModeEnabled":true}',
      'status-test'
    )
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"scope":"cli"');
  Assert.Contains(LResult.ContentJson, '"sanitized":true');
end;

procedure TTestRadIAInstallationHealthTools.
  RegistersReadOnlyDiagnosticTool;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTool: IRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAInstallationHealthTools(
    LRegistry,
    TRadIAInstallationHealthTestProbe.Create
  );
  LTool := LRegistry.Resolve('GetInstallationHealth');
  Assert.AreEqual(trReadOnly, LTool.Descriptor.Risk);
  LResult := LTool.Execute(
    TRadIAToolRequest.Create(
      'GetInstallationHealth',
      '{}',
      'doctor-test'
    )
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'mcp_bridge_missing');
  Assert.Contains(LResult.ContentJson, 'Repair the installation.');
end;

procedure TTestRadIAInstallationHealthTools.
  StatusFiltersSanitizedConfiguration;
var
  LConfig: IRadIAConfig;
  LDirectory: string;
  LProbe: IRadIAInstallationHealthProbe;
  LResult: string;
  LStorage: IRadIASettingsStorage;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIAStatus-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LDirectory);
  try
    LStorage := TRadIAMemorySettingsStorage.Create;
    TRadIAConfig.SetStorage(LStorage);
    LConfig := TRadIAConfig.Create;
    LConfig.SetActiveProvider('OpenAI');
    LConfig.SetApiKey('OpenAI', 'secret-value');
    LProbe := TRadIAInstallationHealthProbe.Create(
      LConfig,
      TPath.Combine(LDirectory, 'bridge.exe'),
      LDirectory
    );

    LResult := LProbe.Status('provider', True);

    Assert.Contains(LResult, '"scope":"provider"');
    Assert.Contains(LResult, '"provider"');
    Assert.DoesNotContain(LResult, '"security"');
    Assert.DoesNotContain(LResult, 'secret-value');
  finally
    LProbe := nil;
    LConfig := nil;
    LStorage := nil;
    TRadIAConfig.SetStorage(nil);
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestRadIAInstallationHealthTools.
  ConcreteProbeReportsLocalReadinessWithoutSecrets;
var
  LBridgePath: string;
  LConfig: IRadIAConfig;
  LDirectory: string;
  LProbe: IRadIAInstallationHealthProbe;
  LResult: string;
  LStorage: IRadIASettingsStorage;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIAInstallationHealth-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LDirectory);
  try
    TFile.WriteAllText(TPath.Combine(LDirectory, 'chat.html'), 'html');
    TFile.WriteAllText(TPath.Combine(LDirectory, 'chat.js'), 'js');
    TFile.WriteAllText(TPath.Combine(LDirectory, 'chat.css'), 'css');
    LBridgePath := TPath.Combine(LDirectory, 'RadIA.MCP.Bridge.exe');
    TFile.WriteAllText(LBridgePath, 'bridge');
    LStorage := TRadIAMemorySettingsStorage.Create;
    TRadIAConfig.SetStorage(LStorage);
    LConfig := TRadIAConfig.Create;
    LConfig.SetActiveProvider('Ollama');
    LConfig.OllamaBaseUrl := 'http://localhost:11434';
    LProbe := TRadIAInstallationHealthProbe.Create(
      LConfig,
      LBridgePath,
      LDirectory
    );
    LResult := LProbe.Diagnose;
    Assert.Contains(LResult, '"diagnosticVersion":"2.0"');
    Assert.Contains(LResult, '"profile":"full-local"');
    Assert.Contains(LResult, '"sanitized":true');
    Assert.Contains(LResult, '"effectiveRoute"');
    Assert.Contains(LResult, '"nonGitWorkspaceSupported":true');
    Assert.Contains(LResult, '"providerConfigured":true');
    Assert.Contains(LResult, '"mcpBridgeAvailable":true');
    Assert.Contains(LResult, '"webAssetsAvailable":true');
    Assert.DoesNotContain(LResult, 'localhost:11434');
  finally
    LProbe := nil;
    LConfig := nil;
    LStorage := nil;
    TRadIAConfig.SetStorage(nil);
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestRadIAInstallationHealthTools.
  RegistersConsentedDeepDiagnosticTool;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTool: IRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAInstallationHealthTools(
    LRegistry,
    TRadIAInstallationHealthTestProbe.Create
  );
  LTool := LRegistry.Resolve('RunInstallationDeepDiagnostic');
  Assert.AreEqual(trExecution, LTool.Descriptor.Risk);
  Assert.IsTrue(LTool.Descriptor.ConsentEveryTime);
  Assert.IsFalse(LTool.Descriptor.Idempotent);
  LResult := LTool.Execute(
    TRadIAToolRequest.Create(
      'RunInstallationDeepDiagnostic',
      '{}',
      'deep-doctor-test'
    )
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'deep-active');
end;

procedure TTestRadIAInstallationHealthTools.
  DeepDiagnosticRunsApplicableActiveChecks;
var
  LConfig: IRadIAConfig;
  LDirectory: string;
  LProbe: IRadIAInstallationHealthProbe;
  LResult: string;
  LStorage: IRadIASettingsStorage;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIADeepDoctor-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LDirectory);
  try
    LStorage := TRadIAMemorySettingsStorage.Create;
    TRadIAConfig.SetStorage(LStorage);
    LConfig := TRadIAConfig.Create;
    LConfig.SetActiveProvider('OpenAI');
    LConfig.SetApiKey('OpenAI', 'secret-value');
    LProbe := TRadIAInstallationHealthProbe.Create(
      LConfig,
      TPath.Combine(LDirectory, 'bridge.exe'),
      LDirectory
    );

    LResult := LProbe.DiagnoseDeep;

    Assert.Contains(LResult, '"profile":"deep-active"');
    Assert.Contains(LResult, '"consentRequired":true');
    Assert.Contains(LResult, '"id":"cli-runtime"');
    Assert.Contains(LResult, '"status":"not-required"');
    Assert.Contains(LResult, '"id":"external-mcp-handshake"');
    Assert.DoesNotContain(LResult, 'secret-value');
  finally
    LProbe := nil;
    LConfig := nil;
    LStorage := nil;
    TRadIAConfig.SetStorage(nil);
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

procedure TTestRadIAInstallationHealthTools.
  StatusSeparatesExternalMcpWithoutExposingConfiguration;
var
  LConfig: IRadIAConfig;
  LDirectory: string;
  LProbe: IRadIAInstallationHealthProbe;
  LResult: string;
  LStorage: IRadIASettingsStorage;
begin
  LDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIAExternalMcpHealth-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LDirectory);
  try
    LStorage := TRadIAMemorySettingsStorage.Create;
    TRadIAConfig.SetStorage(LStorage);
    LConfig := TRadIAConfig.Create;
    LConfig.SetActiveProvider('Ollama');
    LConfig.OllamaBaseUrl := 'http://localhost:11434';
    LProbe := TRadIAInstallationHealthProbe.Create(
      LConfig,
      TPath.Combine(LDirectory, 'bridge.exe'),
      LDirectory,
      TRadIAToolRegistry.Create,
      TRadIAInstallationHealthExternalMcpRuntime.Create
    );

    LResult := LProbe.Status('mcp', False);

    Assert.Contains(LResult, '"externalConfiguredServers":0');
    Assert.Contains(LResult, '"externalConnectedServers":0');
    Assert.Contains(LResult, '"externalRefreshWithoutRestart":true');
    Assert.DoesNotContain(LResult, 'external-mcp.settings');
    Assert.DoesNotContain(LResult, 'fixture.exe');
  finally
    LProbe := nil;
    LConfig := nil;
    LStorage := nil;
    TRadIAConfig.SetStorage(nil);
    if TDirectory.Exists(LDirectory) then
      TDirectory.Delete(LDirectory, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAInstallationHealthTools);

end.
