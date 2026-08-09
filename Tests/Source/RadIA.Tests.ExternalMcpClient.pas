unit RadIA.Tests.ExternalMcpClient;

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpTransport;

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
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.ExternalMcpClient;

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
    FSent.Add(AMessage);
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

initialization
  TDUnitX.RegisterTestFixture(TRadIAExternalMcpClientTests);

end.
