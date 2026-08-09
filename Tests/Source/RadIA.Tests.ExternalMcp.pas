unit RadIA.Tests.ExternalMcp;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAExternalMcpTests = class
  public
    [Test]
    procedure ConfigurationRequiresStableIdentityAndBoundedTimeout;
    [Test]
    procedure CatalogPublishesNamespacedTools;
    [Test]
    procedure CatalogRejectsDuplicateNamesWithoutReplacingPreviousState;
    [Test]
    procedure CatalogRefreshRemovesToolsMissingFromNewDiscovery;
    [Test]
    procedure CatalogRejectsToolsFromAnotherServer;
    [Test]
    procedure CatalogRejectsDisabledServersAndInvalidSchemas;
    [Test]
    [Category('ExternalProcess')]
    procedure StdioTransportRoundTripsAndStops;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpTransport;

function ServerConfig: TRadIAExternalMcpServerConfig;
begin
  Result := TRadIAExternalMcpServerConfig.Create(
    'local-files',
    'Local files',
    'C:\Tools\mcp-files.exe',
    ['--stdio'],
    'C:\Projects',
    True,
    30000
  );
end;

procedure TRadIAExternalMcpTests.ConfigurationRequiresStableIdentityAndBoundedTimeout;
var
  LConfig: TRadIAExternalMcpServerConfig;
  LError: string;
begin
  LConfig := TRadIAExternalMcpServerConfig.Create(
    'invalid.id',
    'Invalid',
    'server.exe',
    [],
    '',
    True,
    500
  );
  Assert.IsFalse(LConfig.Validate(LError));
  Assert.Contains(LError, 'Server ID');
end;

procedure TRadIAExternalMcpTests.CatalogPublishesNamespacedTools;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LError: string;
  LResolved: TRadIAExternalMcpTool;
  LTools: TArray<TRadIAExternalMcpTool>;
begin
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LTools := [
    TRadIAExternalMcpTool.Create(
      'local-files',
      'read_file',
      'Reads one file.',
      '{"type":"object"}'
    )
  ];
  Assert.IsTrue(LCatalog.PublishTools(ServerConfig, LTools, LError), LError);
  Assert.IsTrue(LCatalog.TryResolve('mcp.local-files.read_file', LResolved));
  Assert.AreEqual('read_file', LResolved.ToolName);
end;

procedure TRadIAExternalMcpTests.CatalogRejectsDuplicateNamesWithoutReplacingPreviousState;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LError: string;
  LResolved: TRadIAExternalMcpTool;
  LTools: TArray<TRadIAExternalMcpTool>;
begin
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LTools := [
    TRadIAExternalMcpTool.Create('local-files', 'read_file', 'First', '{}')
  ];
  Assert.IsTrue(LCatalog.PublishTools(ServerConfig, LTools, LError), LError);
  LTools := [
    TRadIAExternalMcpTool.Create('local-files', 'write_file', 'First', '{}'),
    TRadIAExternalMcpTool.Create('local-files', 'WRITE_FILE', 'Second', '{}')
  ];
  Assert.IsFalse(LCatalog.PublishTools(ServerConfig, LTools, LError));
  Assert.Contains(LError, 'Duplicate');
  Assert.IsTrue(LCatalog.TryResolve('mcp.local-files.read_file', LResolved));
  Assert.IsFalse(LCatalog.TryResolve('mcp.local-files.write_file', LResolved));
end;

procedure TRadIAExternalMcpTests.CatalogRefreshRemovesToolsMissingFromNewDiscovery;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LError: string;
  LResolved: TRadIAExternalMcpTool;
  LTools: TArray<TRadIAExternalMcpTool>;
begin
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LTools := [
    TRadIAExternalMcpTool.Create('local-files', 'read_file', 'Read', '{}'),
    TRadIAExternalMcpTool.Create('local-files', 'write_file', 'Write', '{}')
  ];
  Assert.IsTrue(LCatalog.PublishTools(ServerConfig, LTools, LError), LError);
  LTools := [
    TRadIAExternalMcpTool.Create('local-files', 'read_file', 'Read', '{}')
  ];
  Assert.IsTrue(LCatalog.PublishTools(ServerConfig, LTools, LError), LError);
  Assert.AreEqual<Integer>(1, Length(LCatalog.GetTools));
  Assert.IsFalse(LCatalog.TryResolve('mcp.local-files.write_file', LResolved));
end;

procedure TRadIAExternalMcpTests.CatalogRejectsToolsFromAnotherServer;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LError: string;
  LTools: TArray<TRadIAExternalMcpTool>;
begin
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LTools := [
    TRadIAExternalMcpTool.Create('other-server', 'read_file', 'Read', '{}')
  ];
  Assert.IsFalse(LCatalog.PublishTools(ServerConfig, LTools, LError));
  Assert.Contains(LError, 'different server');
end;

procedure TRadIAExternalMcpTests.CatalogRejectsDisabledServersAndInvalidSchemas;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LConfig: TRadIAExternalMcpServerConfig;
  LError: string;
  LTools: TArray<TRadIAExternalMcpTool>;
begin
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LTools := [
    TRadIAExternalMcpTool.Create('local-files', 'read_file', 'Read', '[]')
  ];
  Assert.IsFalse(LCatalog.PublishTools(ServerConfig, LTools, LError));
  Assert.Contains(LError, 'JSON object');
  LConfig := TRadIAExternalMcpServerConfig.Create(
    'local-files',
    'Local files',
    'server.exe',
    [],
    '',
    False,
    30000
  );
  LTools := [
    TRadIAExternalMcpTool.Create('local-files', 'read_file', 'Read', '{}')
  ];
  Assert.IsFalse(LCatalog.PublishTools(LConfig, LTools, LError));
  Assert.Contains(LError, 'Disabled');
end;

procedure TRadIAExternalMcpTests.StdioTransportRoundTripsAndStops;
const
  CLoopCommand =
    'while (($line = [Console]::ReadLine()) -ne $null) { ' +
    '[Console]::WriteLine($line); [Console]::Out.Flush() }';
var
  LConfig: TRadIAExternalMcpServerConfig;
  LError: string;
  LMessage: string;
  LTransport: IRadIAExternalMcpTransport;
begin
  LConfig := TRadIAExternalMcpServerConfig.Create(
    'fixture',
    'Fixture server',
    GetEnvironmentVariable('SystemRoot') +
      '\System32\WindowsPowerShell\v1.0\powershell.exe',
    ['-NoLogo', '-NoProfile', '-NonInteractive', '-Command', CLoopCommand],
    GetCurrentDir,
    True,
    5000
  );
  LTransport := TRadIAExternalMcpStdioTransport.Create;
  Assert.IsTrue(LTransport.Start(LConfig, LError), LError);
  Assert.IsTrue(LTransport.Send('{"jsonrpc":"2.0","id":1}'));
  Assert.IsTrue(LTransport.Receive(5000, LMessage), LTransport.LastError);
  Assert.AreEqual('{"jsonrpc":"2.0","id":1}', LMessage);
  LTransport.Stop;
  Assert.IsFalse(LTransport.Running);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAExternalMcpTests);

end.
