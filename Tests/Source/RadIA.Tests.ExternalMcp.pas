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
  end;

implementation

uses
  RadIA.Core.ExternalMcp;

function ServerConfig: TRadIAExternalMcpServerConfig;
begin
  Result := TRadIAExternalMcpServerConfig.Create(
    'local-files',
    'Local files',
    'C:\Tools\mcp-files.exe',
    '--stdio',
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
    '',
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
    '',
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

initialization
  TDUnitX.RegisterTestFixture(TRadIAExternalMcpTests);

end.
