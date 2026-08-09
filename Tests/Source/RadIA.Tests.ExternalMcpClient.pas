unit RadIA.Tests.ExternalMcpClient;

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  System.SysUtils,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpSecurity,
  RadIA.Core.ExternalMcpTransport,
  RadIA.Core.ToolSecurity,
  RadIA.Core.Tools;

type
  TRadIAFakeExternalMcpTransport = class(
    TInterfacedObject,
    IRadIAExternalMcpTransport
  )
  private
    FLastError: string;
    FReceived: TQueue<string>;
    FRunning: Boolean;
    FSent: TList<string>;
    FOnSend: TProc<string>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddResponse(const AResponse: string);
    function GetLastError: string;
    function GetRunning: Boolean;
    function Receive(const ATimeoutMs: Cardinal; out AMessage: string): Boolean;
    function Send(const AMessage: string): Boolean;
    function SentMessages: TArray<string>;
    function Start(
      const AConfig: TRadIAExternalMcpServerConfig;
      out AError: string
    ): Boolean;
    procedure Stop;
    property OnSend: TProc<string> read FOnSend write FOnSend;
  end;

  TRadIAFakeToolCancellation = class(
    TInterfacedObject,
    IRadIAToolCancellationNotifier
  )
  private
    FCallback: TRadIAToolCancellationCallback;
    FLock: TObject;
    FRequested: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ClearCancellationCallback;
    function GetCancellationRequested: Boolean;
    procedure Request;
    procedure SetCancellationCallback(
      const ACallback: TRadIAToolCancellationCallback
    );
  end;

  TRadIARealMcpConsentProvider = class(
    TInterfacedObject,
    IRadIAConsentProvider
  )
  private
    FRequestCount: Integer;
  public
    function RequestConsent(
      const ARequest: TRadIAToolRequest;
      const ADescriptor: TRadIAToolDescriptor
    ): TRadIAConsentDecision;
    property RequestCount: Integer read FRequestCount;
  end;

  TRadIARealMcpRootProvider = class(
    TInterfacedObject,
    IRadIAExternalMcpWorkspaceRootProvider
  )
  private
    FRoot: string;
  public
    constructor Create(const ARoot: string);
    function GetWorkspaceRoot: string;
  end;

  [TestFixture]
  TRadIAExternalMcpClientTests = class
  public
    [Test]
    procedure ConnectNegotiatesLifecycleAndPublishesTools;
    [Test]
    procedure CallUsesOriginalToolNameAndReturnsStructuredResult;
    [Test]
    procedure InvalidDiscoveryPreservesLastValidCatalog;
    [Test]
    procedure ServerErrorIsReturnedWithoutDisconnecting;
    [Test]
    procedure UnsupportedProtocolVersionStopsConnection;
    [Test]
    procedure CancellationNotifiesServerAndIgnoresLateResponse;
    [Test]
    procedure PaginatedDiscoveryPublishesToolsResourcesAndPrompts;
    [Test]
    procedure RepeatedCursorPreservesLastValidToolCatalog;
    [Test]
    [Category('ExternalProcess')]
    procedure RealFixtureCompletesDiscoveryMutationAndCancellation;
    [Test]
    [Category('ExternalRealServer')]
    procedure AuthorizedFilesystemServerRespectsPolicyAndConsent;
  end;

implementation

uses
  System.Classes,
  System.JSON,
  System.IOUtils,
  System.Threading,
  RadIA.Core.ExternalMcpContent,
  RadIA.Core.ExternalMcpClient,
  RadIA.Core.ToolRegistry,
  RadIA.Core.WorkspaceBoundary;

function ServerConfig: TRadIAExternalMcpServerConfig;
begin
  Result := TRadIAExternalMcpServerConfig.Create(
    'fixture',
    'Fixture',
    'fixture.exe',
    [],
    GetCurrentDir,
    True,
    5000
  );
end;

function InitializeResponse: string;
begin
  Result :=
    '{"jsonrpc":"2.0","id":1,"result":{' +
    '"protocolVersion":"2025-06-18","capabilities":{},' +
    '"serverInfo":{"name":"fixture","version":"1.0"}}}';
end;

function FileArgumentsJson(
  const APath: string;
  const AContent: string = '';
  const AIncludeContent: Boolean = False
): string;
var
  LArguments: TJSONObject;
begin
  LArguments := TJSONObject.Create;
  try
    LArguments.AddPair('path', APath);
    if AIncludeContent then
      LArguments.AddPair('content', AContent);
    Result := LArguments.ToJSON;
  finally
    LArguments.Free;
  end;
end;

function ResolveExternalMcpFixturePath: string;
const
  CFixtureRelativePaths: array[0..1] of string = (
    'Tests\Fixtures\RadIA.ExternalMcpFixture.ps1',
    'Fixtures\RadIA.ExternalMcpFixture.ps1'
  );
  CMaximumParentDepth = 8;
var
  LBasePath: string;
  LCandidate: string;
  LDepth: Integer;
  LRelativePath: string;
  LRootIndex: Integer;
  LRoots: array[0..1] of string;
begin
  Result := '';
  LRoots[0] := GetCurrentDir;
  LRoots[1] := ExtractFilePath(ParamStr(0));
  for LRootIndex := Low(LRoots) to High(LRoots) do
  begin
    LBasePath := TPath.GetFullPath(LRoots[LRootIndex]);
    for LDepth := 0 to CMaximumParentDepth do
    begin
      for LRelativePath in CFixtureRelativePaths do
      begin
        LCandidate := TPath.GetFullPath(
          TPath.Combine(LBasePath, LRelativePath)
        );
        if TFile.Exists(LCandidate) then
          Exit(LCandidate);
      end;
      LCandidate := TPath.GetDirectoryName(LBasePath);
      if SameText(LCandidate, LBasePath) then
        Break;
      LBasePath := LCandidate;
    end;
  end;
end;

{ TRadIAFakeExternalMcpTransport }

constructor TRadIAFakeExternalMcpTransport.Create;
begin
  inherited Create;
  FReceived := TQueue<string>.Create;
  FSent := TList<string>.Create;
end;

destructor TRadIAFakeExternalMcpTransport.Destroy;
begin
  FSent.Free;
  FReceived.Free;
  inherited Destroy;
end;

procedure TRadIAFakeExternalMcpTransport.AddResponse(
  const AResponse: string
);
begin
  FReceived.Enqueue(AResponse);
end;

function TRadIAFakeExternalMcpTransport.GetLastError: string;
begin
  Result := FLastError;
end;

function TRadIAFakeExternalMcpTransport.GetRunning: Boolean;
begin
  Result := FRunning;
end;

function TRadIAFakeExternalMcpTransport.Receive(
  const ATimeoutMs: Cardinal;
  out AMessage: string
): Boolean;
begin
  AMessage := '';
  Result := FRunning and (FReceived.Count > 0) and (ATimeoutMs > 0);
  if Result then
    AMessage := FReceived.Dequeue;
end;

function TRadIAFakeExternalMcpTransport.Send(
  const AMessage: string
): Boolean;
begin
  Result := FRunning;
  if Result then
  begin
    FSent.Add(AMessage);
    if Assigned(FOnSend) then
      FOnSend(AMessage);
  end;
end;

function TRadIAFakeExternalMcpTransport.SentMessages: TArray<string>;
begin
  Result := FSent.ToArray;
end;

function TRadIAFakeExternalMcpTransport.Start(
  const AConfig: TRadIAExternalMcpServerConfig;
  out AError: string
): Boolean;
begin
  AError := '';
  FRunning := AConfig.Enabled;
  Result := FRunning;
end;

procedure TRadIAFakeExternalMcpTransport.Stop;
begin
  FRunning := False;
end;

{ TRadIAFakeToolCancellation }

constructor TRadIAFakeToolCancellation.Create;
begin
  inherited Create;
  FLock := TObject.Create;
end;

destructor TRadIAFakeToolCancellation.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TRadIAFakeToolCancellation.ClearCancellationCallback;
begin
  TMonitor.Enter(FLock);
  try
    FCallback := nil;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAFakeToolCancellation.GetCancellationRequested: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FRequested;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAFakeToolCancellation.Request;
var
  LCallback: TRadIAToolCancellationCallback;
begin
  TMonitor.Enter(FLock);
  try
    FRequested := True;
    LCallback := FCallback;
  finally
    TMonitor.Exit(FLock);
  end;
  if Assigned(LCallback) then
    LCallback();
end;

procedure TRadIAFakeToolCancellation.SetCancellationCallback(
  const ACallback: TRadIAToolCancellationCallback
);
var
  LCallImmediately: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    FCallback := ACallback;
    LCallImmediately := FRequested and Assigned(FCallback);
  finally
    TMonitor.Exit(FLock);
  end;
  if LCallImmediately then
    ACallback();
end;

{ TRadIARealMcpConsentProvider }

function TRadIARealMcpConsentProvider.RequestConsent(
  const ARequest: TRadIAToolRequest;
  const ADescriptor: TRadIAToolDescriptor
): TRadIAConsentDecision;
begin
  Inc(FRequestCount);
  Result := cdAllowOnce;
end;

{ TRadIARealMcpRootProvider }

constructor TRadIARealMcpRootProvider.Create(const ARoot: string);
begin
  inherited Create;
  FRoot := ARoot;
end;

function TRadIARealMcpRootProvider.GetWorkspaceRoot: string;
begin
  Result := FRoot;
end;

{ TRadIAExternalMcpClientTests }

procedure TRadIAExternalMcpClientTests.ConnectNegotiatesLifecycleAndPublishesTools;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LError: string;
  LMessages: TArray<string>;
  LTransport: TRadIAFakeExternalMcpTransport;
begin
  LTransport := TRadIAFakeExternalMcpTransport.Create;
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","method":"notifications/message","params":{}}'
  );
  LTransport.AddResponse(InitializeResponse);
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":2,"result":{"tools":[{' +
    '"name":"read_file","description":"Read","inputSchema":{}}]}}'
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(LTransport, LCatalog);
  Assert.IsTrue(LClient.Connect(ServerConfig, LError), LError);
  Assert.AreEqual('2025-06-18', LClient.ProtocolVersion);
  Assert.IsTrue(LClient.DiscoverTools(LError), LError);
  Assert.AreEqual<Integer>(1, Length(LCatalog.GetTools));
  LMessages := LTransport.SentMessages;
  Assert.Contains(LMessages[0], '"method":"initialize"');
  Assert.Contains(LMessages[1], '"method":"notifications/initialized"');
  Assert.Contains(LMessages[2], '"method":"tools/list"');
end;

procedure TRadIAExternalMcpClientTests.CallUsesOriginalToolNameAndReturnsStructuredResult;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LError: string;
  LMessages: TArray<string>;
  LResult: string;
  LTransport: TRadIAFakeExternalMcpTransport;
begin
  LTransport := TRadIAFakeExternalMcpTransport.Create;
  LTransport.AddResponse(InitializeResponse);
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":2,"result":{"tools":[{' +
    '"name":"read_file","description":"Read","inputSchema":{}}]}}'
  );
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":3,"result":{"content":[{' +
    '"type":"text","text":"ok"}]}}'
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(LTransport, LCatalog);
  Assert.IsTrue(LClient.Connect(ServerConfig, LError), LError);
  Assert.IsTrue(LClient.DiscoverTools(LError), LError);
  Assert.IsTrue(
    LClient.CallTool('mcp.fixture.read_file', '{"path":"a.pas"}', LResult, LError),
    LError
  );
  Assert.Contains(LResult, '"text":"ok"');
  LMessages := LTransport.SentMessages;
  Assert.Contains(LMessages[3], '"name":"read_file"');
  Assert.Contains(LMessages[3], '"path":"a.pas"');
end;

procedure TRadIAExternalMcpClientTests.InvalidDiscoveryPreservesLastValidCatalog;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LError: string;
  LTransport: TRadIAFakeExternalMcpTransport;
begin
  LTransport := TRadIAFakeExternalMcpTransport.Create;
  LTransport.AddResponse(InitializeResponse);
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":2,"result":{"tools":[{' +
    '"name":"read_file","description":"Read","inputSchema":{}}]}}'
  );
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":3,"result":{"tools":[{' +
    '"name":"broken","inputSchema":[]}]}}'
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(LTransport, LCatalog);
  Assert.IsTrue(LClient.Connect(ServerConfig, LError), LError);
  Assert.IsTrue(LClient.DiscoverTools(LError), LError);
  Assert.IsFalse(LClient.DiscoverTools(LError));
  Assert.AreEqual<Integer>(1, Length(LCatalog.GetTools));
end;

procedure TRadIAExternalMcpClientTests.ServerErrorIsReturnedWithoutDisconnecting;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LError: string;
  LTransport: TRadIAFakeExternalMcpTransport;
begin
  LTransport := TRadIAFakeExternalMcpTransport.Create;
  LTransport.AddResponse(InitializeResponse);
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":2,"error":{"code":-32000,' +
    '"message":"catalog unavailable"}}'
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(LTransport, LCatalog);
  Assert.IsTrue(LClient.Connect(ServerConfig, LError), LError);
  Assert.IsFalse(LClient.DiscoverTools(LError));
  Assert.AreEqual('catalog unavailable', LError);
  Assert.IsTrue(LClient.Connected);
end;

procedure TRadIAExternalMcpClientTests.UnsupportedProtocolVersionStopsConnection;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LError: string;
  LTransport: TRadIAFakeExternalMcpTransport;
begin
  LTransport := TRadIAFakeExternalMcpTransport.Create;
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":1,"result":{' +
    '"protocolVersion":"2099-01-01","capabilities":{},' +
    '"serverInfo":{"name":"fixture","version":"1.0"}}}'
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(LTransport, LCatalog);
  Assert.IsFalse(LClient.Connect(ServerConfig, LError));
  Assert.Contains(LError, 'unsupported protocol');
  Assert.IsFalse(LClient.Connected);
  Assert.IsFalse(LTransport.GetRunning);
end;

procedure TRadIAExternalMcpClientTests.CancellationNotifiesServerAndIgnoresLateResponse;
var
  LCancelClient: IRadIAExternalMcpCancelableClient;
  LCancellation: TRadIAFakeToolCancellation;
  LCancellationNotifier: IRadIAToolCancellationNotifier;
  LCancellationToken: IRadIAToolCancellationToken;
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LError: string;
  LMessages: TArray<string>;
  LResult: string;
  LTransport: TRadIAFakeExternalMcpTransport;
begin
  LTransport := TRadIAFakeExternalMcpTransport.Create;
  LTransport.AddResponse(InitializeResponse);
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":2,"result":{"tools":[{' +
    '"name":"read_file","description":"Read","inputSchema":{}}]}}'
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(LTransport, LCatalog);
  Assert.IsTrue(LClient.Connect(ServerConfig, LError), LError);
  Assert.IsTrue(LClient.DiscoverTools(LError), LError);
  Assert.IsTrue(Supports(LClient, IRadIAExternalMcpCancelableClient, LCancelClient));
  LCancellation := TRadIAFakeToolCancellation.Create;
  LCancellationNotifier := LCancellation;
  LCancellationToken := LCancellationNotifier;
  LTransport.OnSend :=
    procedure(AMessage: string)
    begin
      if AMessage.Contains('"method":"tools/call"') then
        LCancellation.Request;
    end;
  Assert.IsFalse(
    LCancelClient.CallToolWithCancellation(
      'mcp.fixture.read_file',
      '{"path":"a.pas"}',
      LCancellationToken,
      LResult,
      LError
    )
  );
  Assert.Contains(LError, 'cancelled');
  LMessages := LTransport.SentMessages;
  Assert.Contains(LMessages[4], '"method":"notifications/cancelled"');
  Assert.Contains(LMessages[4], '"requestId":3');

  LTransport.OnSend := nil;
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":3,"result":{"content":[]}}'
  );
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":4,"result":{"content":[{' +
    '"type":"text","text":"fresh"}]}}'
  );
  Assert.IsTrue(
    LClient.CallTool('mcp.fixture.read_file', '{}', LResult, LError),
    LError
  );
  Assert.Contains(LResult, 'fresh');
end;

procedure TRadIAExternalMcpClientTests.PaginatedDiscoveryPublishesToolsResourcesAndPrompts;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LContent: IRadIAExternalMcpContentCatalog;
  LDiscovery: IRadIAExternalMcpDiscoveryClient;
  LError: string;
  LMessages: TArray<string>;
  LPrompts: TArray<TRadIAExternalMcpPrompt>;
  LResources: TArray<TRadIAExternalMcpResource>;
  LTransport: TRadIAFakeExternalMcpTransport;
begin
  LTransport := TRadIAFakeExternalMcpTransport.Create;
  LTransport.AddResponse(InitializeResponse);
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":2,"result":{"tools":[{' +
    '"name":"read_file","description":"Read","inputSchema":{}}],' +
    '"nextCursor":"tools-2"}}'
  );
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":3,"result":{"tools":[{' +
    '"name":"write_file","description":"Write","inputSchema":{}}]}}'
  );
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":4,"result":{"resources":[{' +
    '"uri":"file:///project/readme.md","name":"Readme",' +
    '"description":"Project readme","mimeType":"text/markdown"}]}}'
  );
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":5,"result":{"prompts":[{' +
    '"name":"review","description":"Review code",' +
    '"arguments":[{"name":"path","required":true}]}]}}'
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LContent := TRadIAExternalMcpContentCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(LTransport, LCatalog, LContent);
  Assert.IsTrue(Supports(LClient, IRadIAExternalMcpDiscoveryClient, LDiscovery));
  Assert.IsTrue(LClient.Connect(ServerConfig, LError), LError);
  Assert.IsTrue(LClient.DiscoverTools(LError), LError);
  Assert.AreEqual<Integer>(2, Length(LCatalog.GetTools));
  Assert.IsTrue(LDiscovery.DiscoverResources(LError), LError);
  Assert.IsTrue(LDiscovery.DiscoverPrompts(LError), LError);
  LResources := LContent.GetResources;
  LPrompts := LContent.GetPrompts;
  Assert.AreEqual<Integer>(1, Length(LResources));
  Assert.StartsWith('mcp://fixture/resources/', LResources[0].FederatedUri);
  Assert.AreEqual<Integer>(1, Length(LPrompts));
  Assert.AreEqual('mcp.fixture.prompt.review', LPrompts[0].NamespacedName);
  LMessages := LTransport.SentMessages;
  Assert.Contains(LMessages[3], '"cursor":"tools-2"');
end;

procedure TRadIAExternalMcpClientTests.RepeatedCursorPreservesLastValidToolCatalog;
var
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LError: string;
  LTransport: TRadIAFakeExternalMcpTransport;
begin
  LTransport := TRadIAFakeExternalMcpTransport.Create;
  LTransport.AddResponse(InitializeResponse);
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":2,"result":{"tools":[{' +
    '"name":"stable","description":"Stable","inputSchema":{}}]}}'
  );
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":3,"result":{"tools":[],' +
    '"nextCursor":"again"}}'
  );
  LTransport.AddResponse(
    '{"jsonrpc":"2.0","id":4,"result":{"tools":[],' +
    '"nextCursor":"again"}}'
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(LTransport, LCatalog);
  Assert.IsTrue(LClient.Connect(ServerConfig, LError), LError);
  Assert.IsTrue(LClient.DiscoverTools(LError), LError);
  Assert.IsFalse(LClient.DiscoverTools(LError));
  Assert.Contains(LError, 'repeated cursor');
  Assert.AreEqual<Integer>(1, Length(LCatalog.GetTools));
  Assert.AreEqual('stable', LCatalog.GetTools[0].ToolName);
end;

procedure TRadIAExternalMcpClientTests.RealFixtureCompletesDiscoveryMutationAndCancellation;
var
  LCancelClient: IRadIAExternalMcpCancelableClient;
  LCancellation: TRadIAFakeToolCancellation;
  LCancellationNotifier: IRadIAToolCancellationNotifier;
  LCancellationTask: ITask;
  LCancellationToken: IRadIAToolCancellationToken;
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LConfig: TRadIAExternalMcpServerConfig;
  LContent: IRadIAExternalMcpContentCatalog;
  LDiscovery: IRadIAExternalMcpDiscoveryClient;
  LError: string;
  LFixturePath: string;
  LResult: string;
  LStateFile: string;
begin
  LFixturePath := ResolveExternalMcpFixturePath;
  Assert.IsTrue(TFile.Exists(LFixturePath), 'External MCP fixture script is missing.');
  LStateFile := TPath.Combine(
    TPath.GetTempPath,
    'radia-mcp-fixture-' + TGUID.NewGuid.ToString + '.txt'
  );
  LConfig := TRadIAExternalMcpServerConfig.Create(
    'fixture',
    'Complete fixture',
    GetEnvironmentVariable('SystemRoot') +
      '\System32\WindowsPowerShell\v1.0\powershell.exe',
    [
      '-NoLogo',
      '-NoProfile',
      '-NonInteractive',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      LFixturePath,
      '-StateFile',
      LStateFile
    ],
    GetCurrentDir,
    True,
    5000
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LContent := TRadIAExternalMcpContentCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(
    TRadIAExternalMcpStdioTransport.Create,
    LCatalog,
    LContent
  );
  try
    Assert.IsTrue(LClient.Connect(LConfig, LError), 'Connect: ' + LError);
    Assert.IsTrue(LClient.DiscoverTools(LError), 'Tools: ' + LError);
    Assert.AreEqual<Integer>(3, Length(LCatalog.GetTools));
    Assert.IsTrue(Supports(LClient, IRadIAExternalMcpDiscoveryClient, LDiscovery));
    Assert.IsTrue(LDiscovery.DiscoverResources(LError), 'Resources: ' + LError);
    Assert.IsTrue(LDiscovery.DiscoverPrompts(LError), 'Prompts: ' + LError);
    Assert.AreEqual<Integer>(1, Length(LContent.GetResources));
    Assert.AreEqual<Integer>(1, Length(LContent.GetPrompts));

    Assert.IsTrue(
      LClient.CallTool('mcp.fixture.read_state', '{}', LResult, LError),
      'Initial read: ' + LError
    );
    Assert.Contains(LResult, 'initial');
    Assert.IsTrue(
      LClient.CallTool(
        'mcp.fixture.write_state',
        '{"value":"updated"}',
        LResult,
        LError
      ),
      'Write: ' + LError
    );
    Assert.AreEqual('updated', TFile.ReadAllText(LStateFile, TEncoding.UTF8));

    Assert.IsTrue(Supports(LClient, IRadIAExternalMcpCancelableClient, LCancelClient));
    LCancellation := TRadIAFakeToolCancellation.Create;
    LCancellationNotifier := LCancellation;
    LCancellationToken := LCancellationNotifier;
    LCancellationTask := TTask.Run(
      procedure
      begin
        TThread.Sleep(150);
        LCancellation.Request;
      end
    );
    Assert.IsFalse(
      LCancelClient.CallToolWithCancellation(
        'mcp.fixture.slow_read',
        '{}',
        LCancellationToken,
        LResult,
        LError
      )
    );
    LCancellationTask.Wait;
    Assert.Contains(LError, 'cancelled');
    Assert.IsTrue(
      LClient.CallTool('mcp.fixture.read_state', '{}', LResult, LError),
      'Read after cancellation: ' + LError
    );
    Assert.Contains(LResult, 'updated');
  finally
    LClient.Disconnect;
    if TFile.Exists(LStateFile) then
      TFile.Delete(LStateFile);
  end;
end;

procedure TRadIAExternalMcpClientTests.AuthorizedFilesystemServerRespectsPolicyAndConsent;
const
  CPackage = '@modelcontextprotocol/server-filesystem@2026.7.10';
var
  LAudit: TRadIAInMemoryToolAuditSink;
  LAuditSink: IRadIAToolAuditSink;
  LBoundary: IRadIAWorkspaceBoundary;
  LCancellation: TRadIAFakeToolCancellation;
  LCancellationNotifier: IRadIAToolCancellationNotifier;
  LCancellationToken: IRadIAToolCancellationToken;
  LCatalog: IRadIAExternalMcpCatalog;
  LClient: IRadIAExternalMcpClient;
  LConfig: TRadIAExternalMcpServerConfig;
  LConsent: TRadIARealMcpConsentProvider;
  LConsentApi: IRadIAConsentProvider;
  LError: string;
  LExecutor: IRadIAToolExecutor;
  LInner: IRadIAToolExecutor;
  LOutsideFile: string;
  LReadAdapter: IRadIATool;
  LReadTool: TRadIAExternalMcpTool;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LRootProvider: IRadIAExternalMcpWorkspaceRootProvider;
  LWorkspace: string;
  LWorkspaceFile: string;
  LWriteAdapter: IRadIATool;
  LWriteTool: TRadIAExternalMcpTool;
begin
  if not SameText(GetEnvironmentVariable('RADIA_RUN_REAL_MCP_SMOKE'), '1') then
    Exit;
  LWorkspace := TPath.Combine(
    TPath.GetTempPath,
    'radia-real-mcp-' + TGUID.NewGuid.ToString
  );
  LOutsideFile := TPath.Combine(
    TPath.GetTempPath,
    'radia-real-mcp-outside-' + TGUID.NewGuid.ToString + '.txt'
  );
  TDirectory.CreateDirectory(LWorkspace);
  LWorkspaceFile := TPath.Combine(LWorkspace, 'consent-proof.txt');
  TFile.WriteAllText(LWorkspaceFile, 'before', TEncoding.UTF8);
  TFile.WriteAllText(LOutsideFile, 'outside', TEncoding.UTF8);
  LConfig := TRadIAExternalMcpServerConfig.Create(
    'real-filesystem',
    'Official filesystem reference server',
    GetEnvironmentVariable('ComSpec'),
    ['/d', '/c', 'npx.cmd', '-y', CPackage, LWorkspace],
    LWorkspace,
    True,
    30000
  );
  LCatalog := TRadIAExternalMcpCatalog.Create;
  LClient := TRadIAExternalMcpClient.Create(
    TRadIAExternalMcpStdioTransport.Create,
    LCatalog
  );
  try
    Assert.IsTrue(LClient.Connect(LConfig, LError), 'Connect: ' + LError);
    Assert.IsTrue(LClient.DiscoverTools(LError), 'Discovery: ' + LError);
    Assert.IsTrue(
      LCatalog.TryResolve('mcp.real-filesystem.read_text_file', LReadTool),
      'The official read_text_file tool was not discovered.'
    );
    Assert.IsTrue(
      LCatalog.TryResolve('mcp.real-filesystem.write_file', LWriteTool),
      'The official write_file tool was not discovered.'
    );
    LBoundary := TRadIAWorkspaceBoundary.Create;
    LRootProvider := TRadIARealMcpRootProvider.Create(LWorkspace);
    LReadAdapter := TRadIAExternalMcpToolAdapter.Create(
      LClient,
      LReadTool,
      TRadIAExternalMcpToolGrant.Create(
        LReadTool.NamespacedName,
        trReadOnly,
        False,
        ['path'],
        False
      ),
      LRootProvider,
      LBoundary
    );
    LWriteAdapter := TRadIAExternalMcpToolAdapter.Create(
      LClient,
      LWriteTool,
      TRadIAExternalMcpToolGrant.Create(
        LWriteTool.NamespacedName,
        trReversibleWrite,
        True,
        ['path'],
        False
      ),
      LRootProvider,
      LBoundary
    );
    LRegistry := TRadIAToolRegistry.Create;
    LRegistry.RegisterTool(LReadAdapter);
    LRegistry.RegisterTool(LWriteAdapter);
    LInner := TRadIAToolExecutor.Create(LRegistry);
    LConsent := TRadIARealMcpConsentProvider.Create;
    LConsentApi := LConsent;
    LAudit := TRadIAInMemoryToolAuditSink.Create;
    LAuditSink := LAudit;
    LExecutor := TRadIAToolPolicyExecutor.Create(
      LRegistry,
      LInner,
      LConsentApi,
      LAuditSink,
      TRadIASecretRedactor.Create
    );

    LResult := LExecutor.Execute(TRadIAToolRequest.Create(
      LReadTool.NamespacedName,
      FileArgumentsJson(LWorkspaceFile),
      'real-read'
    ));
    Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
    Assert.Contains(LResult.ContentJson, 'before');
    LResult := LExecutor.Execute(TRadIAToolRequest.Create(
      LWriteTool.NamespacedName,
      FileArgumentsJson(LWorkspaceFile, 'after', True),
      'real-write'
    ));
    Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
    Assert.AreEqual(1, LConsent.RequestCount);
    Assert.AreEqual('after', TFile.ReadAllText(LWorkspaceFile, TEncoding.UTF8));

    LResult := LExecutor.Execute(TRadIAToolRequest.Create(
      LReadTool.NamespacedName,
      FileArgumentsJson(LOutsideFile),
      'real-outside'
    ));
    Assert.IsFalse(LResult.Success);
    Assert.AreEqual('external_mcp_path_denied', LResult.ErrorCode);
    LCancellation := TRadIAFakeToolCancellation.Create;
    LCancellationNotifier := LCancellation;
    LCancellationToken := LCancellationNotifier;
    LCancellation.Request;
    LResult := LExecutor.Execute(
      TRadIAToolRequest.Create(
        LReadTool.NamespacedName,
        FileArgumentsJson(LWorkspaceFile),
        'real-cancelled'
      ).WithCancellation(LCancellationToken)
    );
    Assert.IsFalse(LResult.Success);
    Assert.AreEqual('tool_cancelled', LResult.ErrorCode);
    Assert.AreEqual<Integer>(4, Length(LAudit.GetEvents));
  finally
    LClient.Disconnect;
    if TFile.Exists(LOutsideFile) then
      TFile.Delete(LOutsideFile);
    if TDirectory.Exists(LWorkspace) then
      TDirectory.Delete(LWorkspace, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAExternalMcpClientTests);

end.
