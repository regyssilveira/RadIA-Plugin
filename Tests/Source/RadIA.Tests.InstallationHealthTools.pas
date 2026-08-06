unit RadIA.Tests.InstallationHealthTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.InstallationHealthTools,
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
  end;

  [TestFixture]
  TTestRadIAInstallationHealthTools = class
  public
    [Test]
    procedure RegistersReadOnlyDiagnosticTool;
    [Test]
    procedure ConcreteProbeReportsLocalReadinessWithoutSecrets;
    [Test]
    procedure NativeJourneyDoesNotRequireMcpAndExposesNextAction;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.Config,
  RadIA.Core.Interfaces,
  RadIA.Core.SettingsStorage,
  RadIA.Core.ToolRegistry;

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

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAInstallationHealthTools);

end.
