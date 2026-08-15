unit RadIA.Tests.ExternalMcpSecurity;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpClient,
  RadIA.Core.ExternalMcpSecurity,
  RadIA.Core.ToolSecurity,
  RadIA.Core.Tools;

type
  TRadIAFakeMcpConsentProvider = class(
    TInterfacedObject,
    IRadIAConsentProvider
  )
  private
    FDecision: TRadIAConsentDecision;
    FRequestCount: Integer;
  public
    constructor Create(const ADecision: TRadIAConsentDecision);
    function RequestConsent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor
    ): TRadIAConsentDecision;
    property RequestCount: Integer read FRequestCount;
  end;

  TRadIAFakeExternalMcpClient = class(
    TInterfacedObject,
    IRadIAExternalMcpClient
  )
  private
    FCallCount: Integer;
  public
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
    property CallCount: Integer read FCallCount;
  end;

  TRadIAFakeExternalMcpWorkspaceRootProvider = class(
    TInterfacedObject,
    IRadIAExternalMcpWorkspaceRootProvider
  )
  public
    function GetWorkspaceRoot: string;
  end;

  [TestFixture]
  TRadIAExternalMcpSecurityTests = class
  public
    [Test]
    procedure GrantRequiresPathsOrExplicitUnboundedAccess;
    [Test]
    procedure AdapterRejectsPathsOutsideWorkspace;
    [Test]
    procedure ReadOnlyGrantRunsThroughSharedPolicyAndAudit;
    [Test]
    procedure DestructiveGrantIsDeniedBeforeExternalCall;
  end;

implementation

uses
  RadIA.Core.ToolRegistry,
  RadIA.Core.WorkspaceBoundary;

{ TRadIAFakeMcpConsentProvider }

constructor TRadIAFakeMcpConsentProvider.Create(
  const ADecision: TRadIAConsentDecision
);
begin
  inherited Create;
  FDecision := ADecision;
end;

function TRadIAFakeMcpConsentProvider.RequestConsent(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor
): TRadIAConsentDecision;
begin
  Inc(FRequestCount);
  Result := FDecision;
end;

function NewAdapter(
  const AClient: IRadIAExternalMcpClient;
  const AGrant: TRadIAExternalMcpToolGrant
): IRadIATool;
var
  LTool: TRadIAExternalMcpTool;
begin
  LTool := TRadIAExternalMcpTool.Create(
    'fixture',
    'read_file',
    'Reads a file.',
    '{"type":"object"}'
  );
  Result := TRadIAExternalMcpToolAdapter.Create(
    AClient,
    LTool,
    AGrant,
    TRadIAFakeExternalMcpWorkspaceRootProvider.Create,
    TRadIAWorkspaceBoundary.Create
  );
end;

{ TRadIAFakeExternalMcpClient }

function TRadIAFakeExternalMcpClient.CallTool(
  const ANamespacedName: string;
  const AArgumentsJson: string;
  out AResultJson: string;
  out AError: string
): Boolean;
begin
  Inc(FCallCount);
  AError := '';
  AResultJson :=
    '{"tool":"' + ANamespacedName + '","arguments":' +
    AArgumentsJson + '}';
  Result := True;
end;

function TRadIAFakeExternalMcpClient.Connect(
  const AConfig: TRadIAExternalMcpServerConfig;
  out AError: string
): Boolean;
begin
  AError := '';
  Result := AConfig.Enabled;
end;

procedure TRadIAFakeExternalMcpClient.Disconnect;
begin
  // The fake owns no process or transport lifecycle.
end;

function TRadIAFakeExternalMcpClient.DiscoverTools(
  out AError: string
): Boolean;
begin
  AError := '';
  Result := True;
end;

function TRadIAFakeExternalMcpClient.GetConnected: Boolean;
begin
  Result := True;
end;

function TRadIAFakeExternalMcpClient.GetProtocolVersion: string;
begin
  Result := '2025-06-18';
end;

{ TRadIAFakeExternalMcpWorkspaceRootProvider }

function TRadIAFakeExternalMcpWorkspaceRootProvider.GetWorkspaceRoot: string;
begin
  Result := 'C:\Workspace\Project';
end;

procedure TRadIAExternalMcpSecurityTests.GrantRequiresPathsOrExplicitUnboundedAccess;
var
  LError: string;
  LGrant: TRadIAExternalMcpToolGrant;
begin
  LGrant := TRadIAExternalMcpToolGrant.Create(
    'mcp.fixture.read_file',
    trReadOnly,
    False,
    [],
    False
  );
  Assert.IsFalse(LGrant.Validate(LError));
  Assert.Contains(LError, 'path arguments');
end;

procedure TRadIAExternalMcpSecurityTests.AdapterRejectsPathsOutsideWorkspace;
var
  LAdapter: IRadIATool;
  LClientApi: IRadIAExternalMcpClient;
  LClient: TRadIAFakeExternalMcpClient;
  LGrant: TRadIAExternalMcpToolGrant;
  LResult: TRadIAToolResult;
begin
  LClient := TRadIAFakeExternalMcpClient.Create;
  LClientApi := LClient;
  LGrant := TRadIAExternalMcpToolGrant.Create(
    'mcp.fixture.read_file',
    trReadOnly,
    False,
    ['path'],
    False
  );
  LAdapter := NewAdapter(LClientApi, LGrant);
  LResult := LAdapter.Execute(
    TRadIAToolRequest.Create(
      'mcp.fixture.read_file',
      '{"path":"C:\\Outside\\secret.txt"}',
      'outside-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('external_mcp_path_denied', LResult.ErrorCode);
  Assert.AreEqual(0, LClient.CallCount);
end;

procedure TRadIAExternalMcpSecurityTests.ReadOnlyGrantRunsThroughSharedPolicyAndAudit;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LAuditSink: IRadIAToolAuditSink;
  LClientApi: IRadIAExternalMcpClient;
  LClient: TRadIAFakeExternalMcpClient;
  LConsent: TRadIAFakeMcpConsentProvider;
  LExecutor: IRadIAToolExecutor;
  LGrant: TRadIAExternalMcpToolGrant;
  LInner: IRadIAToolExecutor;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LClient := TRadIAFakeExternalMcpClient.Create;
  LClientApi := LClient;
  LGrant := TRadIAExternalMcpToolGrant.Create(
    'mcp.fixture.read_file',
    trReadOnly,
    False,
    ['path'],
    False
  );
  LRegistry := TRadIAToolRegistry.Create;
  LRegistry.RegisterTool(NewAdapter(LClientApi, LGrant));
  LInner := TRadIAToolExecutor.Create(LRegistry);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LAuditSink := LAudit;
  { Federated tools always ask for consent, even when the grant is read-only }
  LConsent := TRadIAFakeMcpConsentProvider.Create(cdAllowOnce);
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    LInner,
    LConsent,
    LAuditSink,
    TRadIASecretRedactor.Create
  );
  LResult := LExecutor.Execute(
    TRadIAToolRequest.Create(
      'mcp.fixture.read_file',
      '{"path":"Source\\Unit1.pas"}',
      'allowed-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.AreEqual(1, LClient.CallCount);
  Assert.AreEqual(1, LConsent.RequestCount);
  Assert.AreEqual<Integer>(1, Length(LAudit.GetEvents));
  Assert.AreEqual(aoSucceeded, LAudit.GetEvents[0].Outcome);
end;

procedure TRadIAExternalMcpSecurityTests.DestructiveGrantIsDeniedBeforeExternalCall;
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LAuditSink: IRadIAToolAuditSink;
  LClientApi: IRadIAExternalMcpClient;
  LClient: TRadIAFakeExternalMcpClient;
  LExecutor: IRadIAToolExecutor;
  LGrant: TRadIAExternalMcpToolGrant;
  LInner: IRadIAToolExecutor;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LClient := TRadIAFakeExternalMcpClient.Create;
  LClientApi := LClient;
  LGrant := TRadIAExternalMcpToolGrant.Create(
    'mcp.fixture.read_file',
    trDestructive,
    True,
    [],
    True
  );
  LRegistry := TRadIAToolRegistry.Create;
  LRegistry.RegisterTool(NewAdapter(LClientApi, LGrant));
  LInner := TRadIAToolExecutor.Create(LRegistry);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LAuditSink := LAudit;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    LInner,
    TRadIADenyConsentProvider.Create,
    LAuditSink,
    TRadIASecretRedactor.Create
  );
  LResult := LExecutor.Execute(
    TRadIAToolRequest.Create(
      'mcp.fixture.read_file',
      '{}',
      'denied-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('consent_denied', LResult.ErrorCode);
  Assert.AreEqual(0, LClient.CallCount);
  Assert.AreEqual(aoDenied, LAudit.GetEvents[0].Outcome);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAExternalMcpSecurityTests);

end.
