unit RadIA.Tests.ExternalMcpRuntime;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAExternalMcpRuntimeTests = class
  public
    [Test]
    procedure RefreshRegistersOnlyGrantedToolsAndPublishesHealth;
    [Test]
    procedure FailedRefreshPreservesPreviousRuntime;
    [Test]
    procedure ConnectionFailurePreservesPreviousRuntimeAndReportsHealth;
    [Test]
    procedure TestServerDiscoversWithoutPublishingRuntime;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpClient,
  RadIA.Core.ExternalMcpContent,
  RadIA.Core.ExternalMcpRuntime,
  RadIA.Core.ExternalMcpSecurity,
  RadIA.Core.ExternalMcpSettings,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAFakeExternalMcpSettings = class(
    TInterfacedObject,
    IRadIAExternalMcpSettingsStore
  )
  private
    FFailLoad: Boolean;
    FGrants: TArray<TRadIAExternalMcpToolGrant>;
    FServers: TArray<TRadIAExternalMcpServerConfig>;
  public
    function Load(
      out AServers: TArray<TRadIAExternalMcpServerConfig>;
      out AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean;
    function Save(
      const AServers: TArray<TRadIAExternalMcpServerConfig>;
      const AGrants: TArray<TRadIAExternalMcpToolGrant>;
      out AError: string
    ): Boolean;
    property FailLoad: Boolean read FFailLoad write FFailLoad;
    property Grants: TArray<TRadIAExternalMcpToolGrant> read FGrants write FGrants;
    property Servers: TArray<TRadIAExternalMcpServerConfig> read FServers write FServers;
  end;

  TRadIAFakeExternalMcpClient = class(
    TInterfacedObject,
    IRadIAExternalMcpClient
  )
  private
    FCatalog: IRadIAExternalMcpCatalog;
    FConfig: TRadIAExternalMcpServerConfig;
    FConnected: Boolean;
    FFailConnect: Boolean;
  public
    constructor Create(
      const ACatalog: IRadIAExternalMcpCatalog;
      const AFailConnect: Boolean
    );
    function CallTool(
      const ANamespacedName: string;
      const AArgumentsJson: string;
      out AResultJson: string;
      out AError: string
    ): Boolean;
    function Connect(
      const AConfig: TRadIAExternalMcpServerConfig;
      out AError: string
    ): Boolean;
    procedure Disconnect;
    function DiscoverTools(out AError: string): Boolean;
    function GetConnected: Boolean;
    function GetProtocolVersion: string;
  end;

  TRadIAFakeExternalMcpClientFactory = class(
    TInterfacedObject,
    IRadIAExternalMcpClientFactory
  )
  private
    FFailConnect: Boolean;
  public
    function CreateClient(
      out AClient: IRadIAExternalMcpClient;
      out AToolCatalog: IRadIAExternalMcpCatalog;
      out AContentCatalog: IRadIAExternalMcpContentCatalog
    ): Boolean;
    property FailConnect: Boolean read FFailConnect write FFailConnect;
  end;

  TRadIAFakeExternalMcpRootProvider = class(
    TInterfacedObject,
    IRadIAExternalMcpWorkspaceRootProvider
  )
  public
    function GetWorkspaceRoot: string;
  end;

function ServerConfig: TRadIAExternalMcpServerConfig;
begin
  Result := TRadIAExternalMcpServerConfig.Create(
    'fixture',
    'Fixture',
    'fixture.exe',
    nil,
    '',
    True,
    5000
  );
end;

function ToolGrant: TRadIAExternalMcpToolGrant;
begin
  Result := TRadIAExternalMcpToolGrant.Create(
    'mcp.fixture.read_state',
    trReadOnly,
    False,
    nil,
    True
  );
end;

{ TRadIAFakeExternalMcpSettings }

function TRadIAFakeExternalMcpSettings.Load(
  out AServers: TArray<TRadIAExternalMcpServerConfig>;
  out AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out AError: string
): Boolean;
begin
  Result := not FFailLoad;
  if not Result then
  begin
    AServers := nil;
    AGrants := nil;
    AError := 'Invalid settings.';
    Exit;
  end;
  AServers := Copy(FServers);
  AGrants := Copy(FGrants);
  AError := '';
end;

function TRadIAFakeExternalMcpSettings.Save(
  const AServers: TArray<TRadIAExternalMcpServerConfig>;
  const AGrants: TArray<TRadIAExternalMcpToolGrant>;
  out AError: string
): Boolean;
begin
  FServers := Copy(AServers);
  FGrants := Copy(AGrants);
  AError := '';
  Result := True;
end;

{ TRadIAFakeExternalMcpClient }

constructor TRadIAFakeExternalMcpClient.Create(
  const ACatalog: IRadIAExternalMcpCatalog;
  const AFailConnect: Boolean
);
begin
  inherited Create;
  FCatalog := ACatalog;
  FFailConnect := AFailConnect;
end;

function TRadIAFakeExternalMcpClient.CallTool(
  const ANamespacedName: string;
  const AArgumentsJson: string;
  out AResultJson: string;
  out AError: string
): Boolean;
begin
  AResultJson := '{"ok":true}';
  AError := '';
  Result := FConnected and SameText(ANamespacedName, 'mcp.fixture.read_state');
end;

function TRadIAFakeExternalMcpClient.Connect(
  const AConfig: TRadIAExternalMcpServerConfig;
  out AError: string
): Boolean;
begin
  FConfig := AConfig;
  FConnected := not FFailConnect;
  Result := FConnected;
  if Result then
    AError := ''
  else
    AError := 'Fixture connection failed.';
end;

procedure TRadIAFakeExternalMcpClient.Disconnect;
begin
  FConnected := False;
end;

function TRadIAFakeExternalMcpClient.DiscoverTools(
  out AError: string
): Boolean;
begin
  Result := FCatalog.PublishTools(
    FConfig,
    [TRadIAExternalMcpTool.Create(
      FConfig.Id,
      'read_state',
      'Reads fixture state.',
      '{"type":"object"}'
    )],
    AError
  );
end;

function TRadIAFakeExternalMcpClient.GetConnected: Boolean;
begin
  Result := FConnected;
end;

function TRadIAFakeExternalMcpClient.GetProtocolVersion: string;
begin
  Result := '2025-06-18';
end;

{ TRadIAFakeExternalMcpClientFactory }

function TRadIAFakeExternalMcpClientFactory.CreateClient(
  out AClient: IRadIAExternalMcpClient;
  out AToolCatalog: IRadIAExternalMcpCatalog;
  out AContentCatalog: IRadIAExternalMcpContentCatalog
): Boolean;
begin
  AToolCatalog := TRadIAExternalMcpCatalog.Create;
  AContentCatalog := TRadIAExternalMcpContentCatalog.Create;
  AClient := TRadIAFakeExternalMcpClient.Create(
    AToolCatalog,
    FFailConnect
  );
  Result := True;
end;

{ TRadIAFakeExternalMcpRootProvider }

function TRadIAFakeExternalMcpRootProvider.GetWorkspaceRoot: string;
begin
  Result := GetCurrentDir;
end;

{ TRadIAExternalMcpRuntimeTests }

procedure TRadIAExternalMcpRuntimeTests.RefreshRegistersOnlyGrantedToolsAndPublishesHealth;
var
  LError: string;
  LRegistry: IRadIAToolRegistry;
  LRuntime: IRadIAExternalMcpRuntime;
  LSettings: TRadIAFakeExternalMcpSettings;
  LStatus: TRadIAExternalMcpRuntimeStatus;
  LTool: IRadIATool;
begin
  LSettings := TRadIAFakeExternalMcpSettings.Create;
  LSettings.Servers := [ServerConfig];
  LSettings.Grants := [ToolGrant];
  LRegistry := TRadIAToolRegistry.Create;
  LRuntime := TRadIAExternalMcpRuntime.Create(
    LSettings,
    LRegistry,
    TRadIAFakeExternalMcpRootProvider.Create,
    TRadIAWorkspaceBoundary.Create,
    TRadIAFakeExternalMcpClientFactory.Create
  );

  Assert.IsTrue(LRuntime.Refresh(LError), LError);
  Assert.IsTrue(LRegistry.TryResolve('mcp.fixture.read_state', LTool));
  LStatus := LRuntime.GetStatus;
  Assert.AreEqual(1, LStatus.ConfiguredServers);
  Assert.AreEqual(1, LStatus.EnabledServers);
  Assert.AreEqual(1, LStatus.ConnectedServers);
  Assert.AreEqual(1, LStatus.ToolCount);
  Assert.AreEqual(1, LStatus.GrantedTools);
  Assert.AreEqual(0, LStatus.ErrorCount);
  Assert.AreEqual<Integer>(1, Length(LRuntime.GetDiscoveredTools));
end;

procedure TRadIAExternalMcpRuntimeTests.FailedRefreshPreservesPreviousRuntime;
var
  LError: string;
  LRegistry: IRadIAToolRegistry;
  LRuntime: IRadIAExternalMcpRuntime;
  LSettings: TRadIAFakeExternalMcpSettings;
  LTool: IRadIATool;
begin
  LSettings := TRadIAFakeExternalMcpSettings.Create;
  LSettings.Servers := [ServerConfig];
  LSettings.Grants := [ToolGrant];
  LRegistry := TRadIAToolRegistry.Create;
  LRuntime := TRadIAExternalMcpRuntime.Create(
    LSettings,
    LRegistry,
    TRadIAFakeExternalMcpRootProvider.Create,
    TRadIAWorkspaceBoundary.Create,
    TRadIAFakeExternalMcpClientFactory.Create
  );
  Assert.IsTrue(LRuntime.Refresh(LError), LError);

  LSettings.FailLoad := True;
  Assert.IsFalse(LRuntime.Refresh(LError));
  Assert.IsTrue(LRegistry.TryResolve('mcp.fixture.read_state', LTool));
  Assert.AreEqual(1, LRuntime.GetStatus.ConnectedServers);
  Assert.AreEqual(1, LRuntime.GetStatus.ErrorCount);
end;

procedure TRadIAExternalMcpRuntimeTests.
  ConnectionFailurePreservesPreviousRuntimeAndReportsHealth;
var
  LError: string;
  LFactory: TRadIAFakeExternalMcpClientFactory;
  LRegistry: IRadIAToolRegistry;
  LRuntime: IRadIAExternalMcpRuntime;
  LSettings: TRadIAFakeExternalMcpSettings;
  LTool: IRadIATool;
begin
  LSettings := TRadIAFakeExternalMcpSettings.Create;
  LSettings.Servers := [ServerConfig];
  LSettings.Grants := [ToolGrant];
  LRegistry := TRadIAToolRegistry.Create;
  LFactory := TRadIAFakeExternalMcpClientFactory.Create;
  LRuntime := TRadIAExternalMcpRuntime.Create(
    LSettings,
    LRegistry,
    TRadIAFakeExternalMcpRootProvider.Create,
    TRadIAWorkspaceBoundary.Create,
    LFactory
  );
  Assert.IsTrue(LRuntime.Refresh(LError), LError);

  LFactory.FailConnect := True;
  Assert.IsFalse(LRuntime.Refresh(LError));
  Assert.IsTrue(LRegistry.TryResolve('mcp.fixture.read_state', LTool));
  Assert.AreEqual(1, LRuntime.GetStatus.ConnectedServers);
  Assert.AreEqual(1, LRuntime.GetStatus.ErrorCount);
end;

procedure TRadIAExternalMcpRuntimeTests.
  TestServerDiscoversWithoutPublishingRuntime;
var
  LError: string;
  LRegistry: IRadIAToolRegistry;
  LRuntime: IRadIAExternalMcpRuntime;
  LSettings: TRadIAFakeExternalMcpSettings;
  LStatus: TRadIAExternalMcpRuntimeStatus;
  LTool: IRadIATool;
begin
  LSettings := TRadIAFakeExternalMcpSettings.Create;
  LRegistry := TRadIAToolRegistry.Create;
  LRuntime := TRadIAExternalMcpRuntime.Create(
    LSettings,
    LRegistry,
    TRadIAFakeExternalMcpRootProvider.Create,
    TRadIAWorkspaceBoundary.Create,
    TRadIAFakeExternalMcpClientFactory.Create
  );

  Assert.IsTrue(LRuntime.TestServer(ServerConfig, LStatus, LError), LError);
  Assert.AreEqual(1, LStatus.ConnectedServers);
  Assert.AreEqual(1, LStatus.ToolCount);
  Assert.IsFalse(LRegistry.TryResolve('mcp.fixture.read_state', LTool));
  Assert.AreEqual<Integer>(0, Length(LRuntime.GetServers));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAExternalMcpRuntimeTests);

end.
