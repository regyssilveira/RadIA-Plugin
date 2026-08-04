unit RadIA.Tests.McpProvisioning;

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  RadIA.Core.McpProvisioning;

type
  TRadIAFakeMcpConfigStorage = class(
    TInterfacedObject,
    IRadIAMcpConfigStorage
  )
  private
    FFiles: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFile(const AFileName: string; const AContent: string);
    function FileExists(const AFileName: string): Boolean;
    function ReadText(const AFileName: string): string;
    procedure WriteText(const AFileName: string; const AContent: string);
    procedure CopyFile(const ASource, ADestination: string);
    procedure DeleteFile(const AFileName: string);
  end;

  [TestFixture]
  TRadIAMcpProvisioningTests = class
  private
    function JsonProfile: TRadIAMcpClientProfile;
    function TomlProfile: TRadIAMcpClientProfile;
  public
    [Test]
    procedure CatalogContainsEverySupportedCli;
    [Test]
    procedure PreviewDoesNotWriteConfiguration;
    [Test]
    procedure JsonProvisionPreservesExistingServers;
    [Test]
    procedure JsonProvisionCreatesBackup;
    [Test]
    procedure ProvisionRejectsMissingBridge;
    [Test]
    procedure InvalidJsonIsNotOverwritten;
    [Test]
    procedure JsonDriftCanBeRepaired;
    [Test]
    procedure JsonRemovalPreservesOtherServers;
    [Test]
    procedure TomlProvisionPreservesUnmanagedContent;
    [Test]
    procedure TomlRepairReplacesManagedBlock;
    [Test]
    procedure TomlRemovalPreservesUnmanagedContent;
    [Test]
    procedure ProvisionIsIdempotent;
  end;

implementation

uses
  System.SysUtils;

const
  CBridgePath = 'C:\RadIA\RadIA.MCP.Bridge.exe';
  CConfigPath = 'C:\Client\config.json';

{ TRadIAFakeMcpConfigStorage }

constructor TRadIAFakeMcpConfigStorage.Create;
begin
  inherited Create;
  FFiles := TDictionary<string, string>.Create;
end;

destructor TRadIAFakeMcpConfigStorage.Destroy;
begin
  FFiles.Free;
  inherited;
end;

procedure TRadIAFakeMcpConfigStorage.AddFile(
  const AFileName: string;
  const AContent: string
);
begin
  FFiles.AddOrSetValue(LowerCase(AFileName), AContent);
end;

procedure TRadIAFakeMcpConfigStorage.CopyFile(
  const ASource, ADestination: string
);
begin
  AddFile(ADestination, ReadText(ASource));
end;

procedure TRadIAFakeMcpConfigStorage.DeleteFile(
  const AFileName: string
);
begin
  FFiles.Remove(LowerCase(AFileName));
end;

function TRadIAFakeMcpConfigStorage.FileExists(
  const AFileName: string
): Boolean;
begin
  Result := FFiles.ContainsKey(LowerCase(AFileName));
end;

function TRadIAFakeMcpConfigStorage.ReadText(
  const AFileName: string
): string;
begin
  if not FFiles.TryGetValue(LowerCase(AFileName), Result) then
    raise EFileNotFoundException.Create(AFileName);
end;

procedure TRadIAFakeMcpConfigStorage.WriteText(
  const AFileName: string;
  const AContent: string
);
begin
  AddFile(AFileName, AContent);
end;

{ TRadIAMcpProvisioningTests }

function TRadIAMcpProvisioningTests.JsonProfile:
  TRadIAMcpClientProfile;
begin
  Assert.IsTrue(TRadIAMcpClientCatalog.FindById('gemini', Result));
end;

function TRadIAMcpProvisioningTests.TomlProfile:
  TRadIAMcpClientProfile;
begin
  Assert.IsTrue(TRadIAMcpClientCatalog.FindById('codex', Result));
end;

procedure TRadIAMcpProvisioningTests.CatalogContainsEverySupportedCli;
begin
  Assert.AreEqual<Integer>(4, Length(TRadIAMcpClientCatalog.All));
end;

procedure TRadIAMcpProvisioningTests.InvalidJsonIsNotOverwritten;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LResult: TRadIAMcpProvisionResult;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LStorageObject.AddFile(CBridgePath, 'binary');
  LStorageObject.AddFile(CConfigPath, '{invalid');
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    LResult := LProvisioner.Provision(
      JsonProfile,
      CConfigPath,
      CBridgePath
    );
    Assert.IsFalse(LResult.Succeeded);
    Assert.AreEqual('{invalid', LStorageObject.ReadText(CConfigPath));
    Assert.IsFalse(LStorageObject.FileExists(CConfigPath + '.radia.bak'));
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.JsonDriftCanBeRepaired;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LPreview: TRadIAMcpProvisionPreview;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LStorageObject.AddFile(CBridgePath, 'binary');
  LStorageObject.AddFile(
    CConfigPath,
    '{"mcpServers":{"radia":{"command":"old.exe"}}}'
  );
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    LPreview := LProvisioner.Preview(
      JsonProfile,
      CConfigPath,
      CBridgePath
    );
    Assert.AreEqual(mpsDrifted, LPreview.State);
    Assert.IsTrue(
      LProvisioner.Provision(
        JsonProfile,
        CConfigPath,
        CBridgePath
      ).Succeeded
    );
    Assert.IsTrue(
      LProvisioner.Verify(JsonProfile, CConfigPath, CBridgePath)
    );
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.JsonProvisionCreatesBackup;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LResult: TRadIAMcpProvisionResult;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LStorageObject.AddFile(CBridgePath, 'binary');
  LStorageObject.AddFile(CConfigPath, '{"theme":"dark"}');
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    LResult := LProvisioner.Provision(
      JsonProfile,
      CConfigPath,
      CBridgePath
    );
    Assert.IsTrue(LResult.Succeeded);
    Assert.AreEqual(CConfigPath + '.radia.bak', LResult.BackupPath);
    Assert.AreEqual(
      '{"theme":"dark"}',
      LStorageObject.ReadText(LResult.BackupPath)
    );
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.JsonProvisionPreservesExistingServers;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LContent: string;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LStorageObject.AddFile(CBridgePath, 'binary');
  LStorageObject.AddFile(
    CConfigPath,
    '{"theme":"dark","mcpServers":{"other":{"command":"other.exe"}}}'
  );
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    Assert.IsTrue(
      LProvisioner.Provision(
        JsonProfile,
        CConfigPath,
        CBridgePath
      ).Succeeded
    );
    LContent := LStorageObject.ReadText(CConfigPath);
    Assert.Contains(LContent, '"theme": "dark"');
    Assert.Contains(LContent, '"other"');
    Assert.Contains(LContent, '"radia"');
    Assert.Contains(LContent, 'C:\\RadIA\\RadIA.MCP.Bridge.exe');
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.JsonRemovalPreservesOtherServers;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LContent: string;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LStorageObject.AddFile(
    CConfigPath,
    '{"mcpServers":{"other":{"command":"other.exe"},' +
    '"radia":{"command":"bridge.exe"}}}'
  );
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    Assert.IsTrue(
      LProvisioner.Remove(JsonProfile, CConfigPath).Succeeded
    );
    LContent := LStorageObject.ReadText(CConfigPath);
    Assert.Contains(LContent, '"other"');
    Assert.IsFalse(LContent.Contains('"radia"'));
    Assert.IsTrue(LStorageObject.FileExists(CConfigPath + '.radia.bak'));
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.PreviewDoesNotWriteConfiguration;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LPreview: TRadIAMcpProvisionPreview;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    LPreview := LProvisioner.Preview(
      JsonProfile,
      CConfigPath,
      CBridgePath
    );
    Assert.AreEqual(mpsMissing, LPreview.State);
    Assert.IsTrue(LPreview.Changed);
    Assert.Contains(LPreview.ToDiagnosticText, 'Configure the RadIA');
    Assert.IsFalse(LStorageObject.FileExists(CConfigPath));
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.ProvisionIsIdempotent;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LResult: TRadIAMcpProvisionResult;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LStorageObject.AddFile(CBridgePath, 'binary');
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    LProvisioner.Provision(JsonProfile, CConfigPath, CBridgePath);
    LResult := LProvisioner.Provision(
      JsonProfile,
      CConfigPath,
      CBridgePath
    );
    Assert.IsTrue(LResult.Succeeded);
    Assert.IsFalse(LResult.Changed);
    Assert.Contains(LResult.ToDiagnosticText, 'already configured');
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.ProvisionRejectsMissingBridge;
var
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LResult: TRadIAMcpProvisionResult;
begin
  LStorage := TRadIAFakeMcpConfigStorage.Create;
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    LResult := LProvisioner.Provision(
      JsonProfile,
      CConfigPath,
      CBridgePath
    );
    Assert.IsFalse(LResult.Succeeded);
    Assert.IsFalse(LResult.Changed);
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.TomlProvisionPreservesUnmanagedContent;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LContent: string;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LStorageObject.AddFile(CBridgePath, 'binary');
  LStorageObject.AddFile(CConfigPath, 'model = "gpt-5"' + sLineBreak);
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    Assert.IsTrue(
      LProvisioner.Provision(
        TomlProfile,
        CConfigPath,
        CBridgePath
      ).Succeeded
    );
    LContent := LStorageObject.ReadText(CConfigPath);
    Assert.Contains(LContent, 'model = "gpt-5"');
    Assert.Contains(LContent, '[mcp_servers.radia]');
    Assert.Contains(LContent, 'C:\\RadIA\\RadIA.MCP.Bridge.exe');
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.TomlRemovalPreservesUnmanagedContent;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LContent: string;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LStorageObject.AddFile(CBridgePath, 'binary');
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    LProvisioner.Provision(TomlProfile, CConfigPath, CBridgePath);
    LStorageObject.WriteText(
      CConfigPath,
      'model = "gpt-5"' + sLineBreak +
      LStorageObject.ReadText(CConfigPath)
    );
    Assert.IsTrue(
      LProvisioner.Remove(TomlProfile, CConfigPath).Succeeded
    );
    LContent := LStorageObject.ReadText(CConfigPath);
    Assert.Contains(LContent, 'model = "gpt-5"');
    Assert.IsFalse(LContent.Contains('[mcp_servers.radia]'));
  finally
    LProvisioner.Free;
  end;
end;

procedure TRadIAMcpProvisioningTests.TomlRepairReplacesManagedBlock;
var
  LStorageObject: TRadIAFakeMcpConfigStorage;
  LStorage: IRadIAMcpConfigStorage;
  LProvisioner: TRadIAMcpProvisioner;
  LContent: string;
begin
  LStorageObject := TRadIAFakeMcpConfigStorage.Create;
  LStorage := LStorageObject;
  LStorageObject.AddFile(CBridgePath, 'binary');
  LStorageObject.AddFile(
    CConfigPath,
    '# BEGIN RadIA managed MCP server' + sLineBreak +
    '[mcp_servers.radia]' + sLineBreak +
    'command = "old.exe"' + sLineBreak +
    '# END RadIA managed MCP server' + sLineBreak
  );
  LProvisioner := TRadIAMcpProvisioner.Create(LStorage);
  try
    Assert.IsTrue(
      LProvisioner.Provision(
        TomlProfile,
        CConfigPath,
        CBridgePath
      ).Succeeded
    );
    LContent := LStorageObject.ReadText(CConfigPath);
    Assert.IsFalse(LContent.Contains('old.exe'));
    Assert.Contains(LContent, 'C:\\RadIA\\RadIA.MCP.Bridge.exe');
  finally
    LProvisioner.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAMcpProvisioningTests);

end.
