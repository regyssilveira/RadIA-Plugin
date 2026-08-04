unit RadIA.Tests.Mcp;

interface

uses
  DUnitX.TestFramework,
  System.SyncObjs,
  RadIA.Core.Mcp,
  RadIA.Core.Tools;

type
  TTestRadIAMcpTool = class(TInterfacedObject, IRadIATool)
  private
    FExecutionCount: Integer;
    FLastRequest: TRadIAToolRequest;
    FRisk: TRadIAToolRisk;
  public
    constructor Create(const ARisk: TRadIAToolRisk);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    property ExecutionCount: Integer read FExecutionCount;
    property LastRequest: TRadIAToolRequest read FLastRequest;
  end;

  TTestRadIACancellableTool = class(
    TInterfacedObject,
    IRadIATool
  )
  private
    FStarted: TEvent;
  public
    constructor Create;
    destructor Destroy; override;
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
    function WaitUntilStarted: Boolean;
  end;

  [TestFixture]
  TTestRadIAMcpProtocol = class
  private
    FProtocol: IRadIAMcpProtocol;
    FSession: TRadIAMcpSession;
    FTool: TTestRadIAMcpTool;
    function CreateNamedPipeServer(
      out ARootPath: string;
      out AConnectionFile: string
    ): IRadIAMcpServer;
    function ConnectToServer(
      const AServer: IRadIAMcpServer
    ): THandle;
    function InitializeSession: string;
    function GetInstanceConnectionFile(
      const AConnectionFile: string
    ): string;
    function ReadClientMessage(
      const APipe: THandle;
      const ATimeoutMs: Cardinal
    ): string;
    procedure WriteClientMessage(
      const APipe: THandle;
      const AMessage: string
    );
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure InitializeNegotiatesCapabilities;
    [Test]
    procedure ToolsListMatchesRegistry;
    [Test]
    procedure ToolCallUsesMcpExecutionContext;
    [Test]
    procedure ToolCallUsesPolicyPipeline;
    [Test]
    procedure RequestBeforeInitializeIsRejected;
    [Test]
    procedure InvalidJsonAndBatchAreRejected;
    [Test]
    procedure InitializedNotificationHasNoResponse;
    [Test]
    procedure NamedPipeTransportRoundTripsAndCleansUp;
    [Test]
    procedure NamedPipeRestartsWithoutLeakingDiscovery;
    [Test]
    procedure NamedPipeStartRemovesStaleDiscovery;
    [Test]
    procedure NamedPipeStopPreservesForeignDiscovery;
    [Test]
    procedure NamedPipeStopDisconnectsIdleClient;
    [Test]
    procedure ProtocolHandlesRepeatedRequests;
    [Test]
    procedure CancelNotificationStopsCooperativeTool;
    [Test]
    procedure NamedPipeDeliversCancellationWhileToolRuns;
    [Test]
    procedure MetricsExposeSanitizedSessionCounters;
    [Test]
    [Category('ExternalProcess')]
    procedure StdioBridgeCompletesLiveHandshake;
  end;

implementation

uses
  System.Classes,
  System.Diagnostics,
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliProcess,
  RadIA.Core.McpHandshake,
  RadIA.MCP.NamedPipe,
  RadIA.Tests.Patches,
  RadIA.Core.ToolRegistry,
  RadIA.Core.ToolSecurity,
  RadIA.Core.Version;

{ TTestRadIAMcpTool }

constructor TTestRadIAMcpTool.Create(
  const ARisk: TRadIAToolRisk
);
begin
  inherited Create;
  FRisk := ARisk;
end;

function TTestRadIAMcpTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Inc(FExecutionCount);
  FLastRequest := ARequest;
  Result := TRadIAToolResult.Succeeded(
    '{"value":"ready"}'
  );
end;

function TTestRadIAMcpTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetState',
    '1.0.0',
    'Returns a test state.',
    '{"type":"object","additionalProperties":false}',
    '{"type":"object"}',
    FRisk
  );
end;

{ TTestRadIACancellableTool }

constructor TTestRadIACancellableTool.Create;
begin
  inherited Create;
  FStarted := TEvent.Create(nil, True, False, '');
end;

destructor TTestRadIACancellableTool.Destroy;
begin
  FStarted.Free;
  inherited;
end;

function TTestRadIACancellableTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LDeadline: UInt64;
begin
  FStarted.SetEvent;
  LDeadline := GetTickCount64 + 3000;
  while GetTickCount64 < LDeadline do
  begin
    if Assigned(ARequest.CancellationToken) and
      ARequest.CancellationToken.CancellationRequested then
      Exit(
        TRadIAToolResult.Failed(
          'tool_cancelled',
          'Tool execution was cancelled.'
        )
      );
    Sleep(5);
  end;
  Result := TRadIAToolResult.Failed(
    'test_timeout',
    'Cancellation was not observed.'
  );
end;

function TTestRadIACancellableTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'WaitForCancellation',
    '1.0.0',
    'Waits for a cooperative cancellation request.',
    '{"type":"object","additionalProperties":false}',
    '{"type":"object"}',
    trReadOnly
  );
end;

function TTestRadIACancellableTool.WaitUntilStarted: Boolean;
begin
  Result := FStarted.WaitFor(3000) = wrSignaled;
end;

{ TTestRadIAMcpProtocol }

procedure TTestRadIAMcpProtocol.CancelNotificationStopsCooperativeTool;
var
  LCancellableTool: TTestRadIACancellableTool;
  LExecutor: IRadIAToolExecutor;
  LProtocol: IRadIAMcpProtocol;
  LRegistry: IRadIAToolRegistry;
  LResponse: string;
  LSession: TRadIAMcpSession;
  LThread: TThread;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LCancellableTool := TTestRadIACancellableTool.Create;
  LRegistry.RegisterTool(LCancellableTool);
  LExecutor := TRadIAToolExecutor.Create(LRegistry);
  LProtocol := TRadIAMcpProtocol.Create(LRegistry, LExecutor);
  LSession := TRadIAMcpSession.Create('client', 'session', 'project');
  LProtocol.HandleMessage(
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{' +
    '"protocolVersion":"2025-06-18","capabilities":{},' +
    '"clientInfo":{"name":"test","version":"1"}}}',
    LSession
  );
  LThread := TThread.CreateAnonymousThread(
    procedure
    begin
      LResponse := LProtocol.HandleMessage(
        '{"jsonrpc":"2.0","id":42,"method":"tools/call",' +
        '"params":{"name":"WaitForCancellation","arguments":{}}}',
        LSession
      );
    end
  );
  LThread.FreeOnTerminate := False;
  try
    LThread.Start;
    Assert.IsTrue(LCancellableTool.WaitUntilStarted);
    Assert.AreEqual(
      '',
      LProtocol.HandleMessage(
        '{"jsonrpc":"2.0","method":"notifications/cancelled",' +
        '"params":{"requestId":42,"reason":"test"}}',
        LSession
      )
    );
    LThread.WaitFor;

    Assert.Contains(LResponse, '"isError":true');
    Assert.Contains(LResponse, 'tool_cancelled');
  finally
    LThread.Terminate;
    LThread.WaitFor;
    LThread.Free;
    LSession.Free;
  end;
end;

function TTestRadIAMcpProtocol.ConnectToServer(
  const AServer: IRadIAMcpServer
): THandle;
var
  LMode: DWORD;
begin
  Assert.IsTrue(WaitNamedPipe(PChar(AServer.Endpoint), 3000));
  Result := CreateFile(
    PChar(AServer.Endpoint),
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    0,
    0
  );
  Assert.AreNotEqual<THandle>(
    THandle(INVALID_HANDLE_VALUE),
    Result
  );
  LMode := PIPE_READMODE_MESSAGE or PIPE_NOWAIT;
  Assert.IsTrue(SetNamedPipeHandleState(Result, LMode, nil, nil));
end;

function TTestRadIAMcpProtocol.CreateNamedPipeServer(
  out ARootPath: string;
  out AConnectionFile: string
): IRadIAMcpServer;
var
  LWorkspace: TTestRadIAPatchWorkspace;
begin
  ARootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIAMcp-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(ARootPath);
  AConnectionFile := TPath.Combine(ARootPath, 'mcp.json');
  LWorkspace := TTestRadIAPatchWorkspace.Create(
    ARootPath,
    TPath.Combine(ARootPath, 'UnitOne.pas'),
    'unit UnitOne; end.'
  );
  Result := TRadIANamedPipeMcpServer.Create(
    FProtocol,
    LWorkspace,
    AConnectionFile
  );
end;

procedure TTestRadIAMcpProtocol.InitializeNegotiatesCapabilities;
var
  LResponse: string;
begin
  LResponse := InitializeSession;

  Assert.Contains(LResponse, '"protocolVersion":"2025-06-18"');
  Assert.Contains(LResponse, '"tools":{"listChanged":false}');
  Assert.Contains(LResponse, '"name":"RadIA"');
  Assert.Contains(
    LResponse,
    '"version":"' + CRadIAVersion + '"'
  );
  Assert.IsTrue(FSession.Initialized);
end;

function TTestRadIAMcpProtocol.InitializeSession: string;
begin
  Result := FProtocol.HandleMessage(
    '{"jsonrpc":"2.0","id":1,"method":"initialize",' +
    '"params":{"protocolVersion":"2025-06-18",' +
    '"capabilities":{},"clientInfo":{"name":"test","version":"1"}}}',
    FSession
  );
end;

function TTestRadIAMcpProtocol.GetInstanceConnectionFile(
  const AConnectionFile: string
): string;
begin
  Result := TPath.Combine(
    TPath.GetDirectoryName(AConnectionFile),
    TPath.GetFileNameWithoutExtension(AConnectionFile) + '.' +
      UIntToStr(GetCurrentProcessId) +
      TPath.GetExtension(AConnectionFile)
  );
end;

procedure TTestRadIAMcpProtocol.NamedPipeDeliversCancellationWhileToolRuns;
var
  LCancellableTool: TTestRadIACancellableTool;
  LConnectionFile: string;
  LExecutor: IRadIAToolExecutor;
  LPipe: THandle;
  LProtocol: IRadIAMcpProtocol;
  LRegistry: IRadIAToolRegistry;
  LResponse: string;
  LRootPath: string;
  LServer: IRadIAMcpServer;
  LWorkspace: TTestRadIAPatchWorkspace;
begin
  LRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIAMcp-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LRootPath);
  LConnectionFile := TPath.Combine(LRootPath, 'mcp.json');
  LRegistry := TRadIAToolRegistry.Create;
  LCancellableTool := TTestRadIACancellableTool.Create;
  LRegistry.RegisterTool(LCancellableTool);
  LExecutor := TRadIAToolExecutor.Create(LRegistry);
  LProtocol := TRadIAMcpProtocol.Create(LRegistry, LExecutor);
  LWorkspace := TTestRadIAPatchWorkspace.Create(
    LRootPath,
    TPath.Combine(LRootPath, 'UnitOne.pas'),
    'unit UnitOne; end.'
  );
  LServer := TRadIANamedPipeMcpServer.Create(
    LProtocol,
    LWorkspace,
    LConnectionFile
  );
  LPipe := INVALID_HANDLE_VALUE;
  try
    LServer.Start;
    LPipe := ConnectToServer(LServer);
    WriteClientMessage(
      LPipe,
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{' +
      '"protocolVersion":"2025-06-18","capabilities":{},' +
      '"clientInfo":{"name":"test","version":"1"}}}'
    );
    LResponse := ReadClientMessage(LPipe, 3000);
    Assert.Contains(LResponse, '"protocolVersion":"2025-06-18"');

    WriteClientMessage(
      LPipe,
      '{"jsonrpc":"2.0","id":42,"method":"tools/call",' +
      '"params":{"name":"WaitForCancellation","arguments":{}}}'
    );
    Assert.IsTrue(LCancellableTool.WaitUntilStarted);
    WriteClientMessage(
      LPipe,
      '{"jsonrpc":"2.0","id":43,"method":"ping"}'
    );
    LResponse := ReadClientMessage(LPipe, 3000);
    Assert.Contains(LResponse, '"id":43');
    Assert.Contains(LResponse, '"code":-32003');

    WriteClientMessage(
      LPipe,
      '{"jsonrpc":"2.0","method":"notifications/cancelled",' +
      '"params":{"requestId":42,"reason":"test"}}'
    );
    LResponse := ReadClientMessage(LPipe, 3000);

    Assert.Contains(LResponse, '"id":42');
    Assert.Contains(LResponse, '"isError":true');
    Assert.Contains(LResponse, 'tool_cancelled');
  finally
    if LPipe <> INVALID_HANDLE_VALUE then
      CloseHandle(LPipe);
    LServer.Stop;
    LServer := nil;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIAMcpProtocol.InitializedNotificationHasNoResponse;
var
  LResponse: string;
begin
  InitializeSession;
  LResponse := FProtocol.HandleMessage(
    '{"jsonrpc":"2.0","method":"notifications/initialized"}',
    FSession
  );

  Assert.AreEqual('', LResponse);
end;

procedure TTestRadIAMcpProtocol.InvalidJsonAndBatchAreRejected;
var
  LResponse: string;
begin
  LResponse := FProtocol.HandleMessage('{invalid', FSession);
  Assert.Contains(LResponse, '"code":-32700');

  LResponse := FProtocol.HandleMessage('[]', FSession);
  Assert.Contains(LResponse, '"code":-32600');
end;

procedure TTestRadIAMcpProtocol.MetricsExposeSanitizedSessionCounters;
var
  LResponse: string;
begin
  InitializeSession;
  FProtocol.HandleMessage(
    '{"jsonrpc":"2.0","id":2,"method":"ping"}',
    FSession
  );
  FProtocol.HandleMessage(
    '{"jsonrpc":"2.0","id":3,"method":"tools/call",' +
    '"params":{"name":"GetState","arguments":{}}}',
    FSession
  );
  LResponse := FProtocol.HandleMessage(
    '{"jsonrpc":"2.0","id":4,"method":"radia/metrics"}',
    FSession
  );

  Assert.Contains(LResponse, '"receivedMessages":4');
  Assert.Contains(LResponse, '"completedToolCalls":1');
  Assert.Contains(LResponse, '"activeToolCalls":0');
  Assert.Contains(LResponse, '"peakActiveToolCalls":1');
  Assert.Contains(LResponse, '"cancellationRequests":0');
  Assert.Contains(LResponse, '"rejectedRequests":0');
  Assert.IsFalse(LResponse.Contains('project-one'));
  Assert.IsFalse(LResponse.Contains('test-client'));
end;

procedure TTestRadIAMcpProtocol.NamedPipeTransportRoundTripsAndCleansUp;
var
  LAvailableBytes: DWORD;
  LBuffer: TBytes;
  LBytes: TBytes;
  LBytesRead: DWORD;
  LBytesWritten: DWORD;
  LConnectionFile: string;
  LDeadline: UInt64;
  LMode: DWORD;
  LPipe: THandle;
  LResponse: string;
  LRootPath: string;
  LServer: IRadIAMcpServer;
  LWorkspace: TTestRadIAPatchWorkspace;
begin
  LRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIAMcp-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LRootPath);
  LConnectionFile := TPath.Combine(LRootPath, 'mcp.json');
  LWorkspace := TTestRadIAPatchWorkspace.Create(
    LRootPath,
    TPath.Combine(LRootPath, 'UnitOne.pas'),
    'unit UnitOne; end.'
  );
  LServer := TRadIANamedPipeMcpServer.Create(
    FProtocol,
    LWorkspace,
    LConnectionFile
  );
  try
    LServer.Start;
    Assert.IsTrue(LServer.Running, 'Server should report running.');
    Assert.IsTrue(
      TFile.Exists(LConnectionFile),
      'Connection file should exist.'
    );
    Assert.IsTrue(
      WaitNamedPipe(PChar(LServer.Endpoint), 3000),
      'Named pipe should accept connections.'
    );

    LPipe := CreateFile(
      PChar(LServer.Endpoint),
      GENERIC_READ or GENERIC_WRITE,
      0,
      nil,
      OPEN_EXISTING,
      0,
      0
    );
    Assert.AreNotEqual<THandle>(
      THandle(INVALID_HANDLE_VALUE),
      LPipe
    );
    try
      LMode := PIPE_READMODE_MESSAGE or PIPE_NOWAIT;
      Assert.IsTrue(
        SetNamedPipeHandleState(LPipe, LMode, nil, nil),
        'Client should enter message read mode.'
      );
      LBytes := TEncoding.UTF8.GetBytes(
        '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{' +
        '"protocolVersion":"2025-06-18","capabilities":{},' +
        '"clientInfo":{"name":"test","version":"1"}}}'
      );
      Assert.IsTrue(
        WriteFile(
          LPipe,
          LBytes[0],
          Length(LBytes),
          LBytesWritten,
          nil
        ),
        'Client should write the initialize request.'
      );
      SetLength(LBuffer, 8192);
      LDeadline := GetTickCount64 + 3000;
      LBytesRead := 0;
      repeat
        LAvailableBytes := 0;
        Assert.IsTrue(
          PeekNamedPipe(
            LPipe,
            nil,
            0,
            nil,
            @LAvailableBytes,
            nil
          ),
          'Client should inspect the initialize response.'
        );
        if LAvailableBytes > 0 then
        begin
          LBytesRead := 0;
          Assert.IsTrue(
            ReadFile(
              LPipe,
              LBuffer[0],
              Length(LBuffer),
              LBytesRead,
              nil
            ),
            'Client should read the initialize response.'
          );
          Break;
        end;
        Sleep(10);
      until GetTickCount64 >= LDeadline;
      Assert.IsTrue(
        LBytesRead > 0,
        'Client should read the initialize response.'
      );
      SetLength(LBuffer, LBytesRead);
      LResponse := TEncoding.UTF8.GetString(LBuffer);
      Assert.Contains(LResponse, '"protocolVersion":"2025-06-18"');
    finally
      CloseHandle(LPipe);
    end;
  finally
    LServer.Stop;
    Assert.IsFalse(TFile.Exists(LConnectionFile));
    LServer := nil;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIAMcpProtocol.NamedPipeRestartsWithoutLeakingDiscovery;
const
  CRestartCount = 20;
var
  LConnectionFile: string;
  LIndex: Integer;
  LRootPath: string;
  LServer: IRadIAMcpServer;
begin
  LServer := CreateNamedPipeServer(LRootPath, LConnectionFile);
  try
    for LIndex := 1 to CRestartCount do
    begin
      LServer.Start;
      Assert.IsTrue(LServer.Running);
      Assert.IsTrue(TFile.Exists(LConnectionFile));
      Assert.IsTrue(
        TFile.Exists(GetInstanceConnectionFile(LConnectionFile))
      );
      Assert.IsTrue(WaitNamedPipe(PChar(LServer.Endpoint), 3000));
      LServer.Stop;
      Assert.IsFalse(LServer.Running);
      Assert.IsFalse(TFile.Exists(LConnectionFile));
      Assert.IsFalse(
        TFile.Exists(GetInstanceConnectionFile(LConnectionFile))
      );
    end;
  finally
    LServer.Stop;
    LServer := nil;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIAMcpProtocol.NamedPipeStartRemovesStaleDiscovery;
var
  LConnectionFile: string;
  LRootPath: string;
  LServer: IRadIAMcpServer;
  LStaleConnectionFile: string;
begin
  LServer := CreateNamedPipeServer(
    LRootPath,
    LConnectionFile
  );
  LStaleConnectionFile := TPath.Combine(
    LRootPath,
    'mcp.4294967295.json'
  );
  try
    TFile.WriteAllText(
      LStaleConnectionFile,
      '{"processId":4294967295,"endpoint":"stale"}',
      TEncoding.UTF8
    );
    LServer.Start;

    Assert.IsFalse(TFile.Exists(LStaleConnectionFile));
  finally
    LServer.Stop;
    LServer := nil;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIAMcpProtocol.NamedPipeStopPreservesForeignDiscovery;
var
  LConnectionFile: string;
  LForeignDiscovery: string;
  LInstanceConnectionFile: string;
  LRootPath: string;
  LServer: IRadIAMcpServer;
begin
  LServer := CreateNamedPipeServer(LRootPath, LConnectionFile);
  LInstanceConnectionFile :=
    GetInstanceConnectionFile(LConnectionFile);
  try
    LServer.Start;
    LForeignDiscovery :=
      '{"transport":"named-pipe","endpoint":"foreign",' +
      '"protocolVersion":"2025-06-18","processId":1}';
    TFile.WriteAllText(
      LConnectionFile,
      LForeignDiscovery,
      TEncoding.UTF8
    );

    LServer.Stop;

    Assert.IsTrue(TFile.Exists(LConnectionFile));
    Assert.AreEqual(
      LForeignDiscovery,
      TFile.ReadAllText(LConnectionFile, TEncoding.UTF8)
    );
    Assert.IsFalse(TFile.Exists(LInstanceConnectionFile));
  finally
    LServer.Stop;
    LServer := nil;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIAMcpProtocol.NamedPipeStopDisconnectsIdleClient;
var
  LConnectionFile: string;
  LPipe: THandle;
  LRootPath: string;
  LServer: IRadIAMcpServer;
  LStopwatch: TStopwatch;
begin
  LServer := CreateNamedPipeServer(LRootPath, LConnectionFile);
  LPipe := INVALID_HANDLE_VALUE;
  try
    LServer.Start;
    Assert.IsTrue(WaitNamedPipe(PChar(LServer.Endpoint), 3000));
    LPipe := CreateFile(
      PChar(LServer.Endpoint),
      GENERIC_READ or GENERIC_WRITE,
      0,
      nil,
      OPEN_EXISTING,
      0,
      0
    );
    Assert.AreNotEqual<THandle>(
      THandle(INVALID_HANDLE_VALUE),
      LPipe
    );

    LStopwatch := TStopwatch.StartNew;
    LServer.Stop;
    LStopwatch.Stop;

    Assert.IsTrue(
      LStopwatch.ElapsedMilliseconds < 3000,
      'Stopping an idle MCP client should remain bounded.'
    );
    Assert.IsFalse(LServer.Running);
    Assert.IsFalse(TFile.Exists(LConnectionFile));
  finally
    if LPipe <> INVALID_HANDLE_VALUE then
      CloseHandle(LPipe);
    LServer.Stop;
    LServer := nil;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIAMcpProtocol.ProtocolHandlesRepeatedRequests;
const
  CRequestCount = 1000;
var
  LIndex: Integer;
  LResponse: string;
begin
  InitializeSession;
  for LIndex := 1 to CRequestCount do
  begin
    LResponse := FProtocol.HandleMessage(
      Format(
        '{"jsonrpc":"2.0","id":%d,"method":"ping"}',
        [LIndex]
      ),
      FSession
    );
    Assert.Contains(LResponse, '"result":{}');
  end;

  Assert.AreEqual(0, FTool.ExecutionCount);
end;

function TTestRadIAMcpProtocol.ReadClientMessage(
  const APipe: THandle;
  const ATimeoutMs: Cardinal
): string;
var
  LAvailableBytes: DWORD;
  LBuffer: TBytes;
  LBytesRead: DWORD;
  LDeadline: UInt64;
begin
  Result := '';
  LDeadline := GetTickCount64 + ATimeoutMs;
  repeat
    LAvailableBytes := 0;
    Assert.IsTrue(
      PeekNamedPipe(APipe, nil, 0, nil, @LAvailableBytes, nil)
    );
    if LAvailableBytes > 0 then
    begin
      SetLength(LBuffer, LAvailableBytes);
      LBytesRead := 0;
      Assert.IsTrue(
        ReadFile(
          APipe,
          LBuffer[0],
          Length(LBuffer),
          LBytesRead,
          nil
        )
      );
      SetLength(LBuffer, LBytesRead);
      Exit(TEncoding.UTF8.GetString(LBuffer));
    end;
    Sleep(10);
  until GetTickCount64 >= LDeadline;
  Assert.Fail('Timed out waiting for the MCP response.');
end;

procedure TTestRadIAMcpProtocol.RequestBeforeInitializeIsRejected;
var
  LResponse: string;
begin
  LResponse := FProtocol.HandleMessage(
    '{"jsonrpc":"2.0","id":"a","method":"tools/list"}',
    FSession
  );

  Assert.Contains(LResponse, '"id":"a"');
  Assert.Contains(LResponse, '"code":-32002');
end;

procedure TTestRadIAMcpProtocol.Setup;
var
  LExecutor: IRadIAToolExecutor;
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := TRadIAToolRegistry.Create;
  FTool := TTestRadIAMcpTool.Create(trReadOnly);
  LRegistry.RegisterTool(FTool);
  LExecutor := TRadIAToolExecutor.Create(LRegistry);
  FProtocol := TRadIAMcpProtocol.Create(LRegistry, LExecutor);
  FSession := TRadIAMcpSession.Create(
    'test-client',
    'test-session',
    'C:\Project\ProjectOne.dproj'
  );
end;

procedure TTestRadIAMcpProtocol.TearDown;
begin
  FProtocol := nil;
  FTool := nil;
  FSession.Free;
end;

procedure TTestRadIAMcpProtocol.ToolCallUsesMcpExecutionContext;
var
  LResponse: string;
begin
  InitializeSession;
  LResponse := FProtocol.HandleMessage(
    '{"jsonrpc":"2.0","id":3,"method":"tools/call",' +
    '"params":{"name":"GetState","arguments":{}}}',
    FSession
  );

  Assert.Contains(LResponse, '"isError":false');
  Assert.Contains(
    LResponse,
    '"structuredContent":{"value":"ready"'
  );
  Assert.Contains(LResponse, '"sourceTool":"GetState"');
  Assert.AreEqual(1, FTool.ExecutionCount);
  Assert.AreEqual('mcp', FTool.LastRequest.Origin);
  Assert.AreEqual('test-session', FTool.LastRequest.SessionId);
  Assert.AreEqual(
    'C:\Project\ProjectOne.dproj',
    FTool.LastRequest.ProjectId
  );
end;

procedure TTestRadIAMcpProtocol.ToolCallUsesPolicyPipeline;
var
  LAudit: IRadIAToolAuditSink;
  LExecutor: IRadIAToolExecutor;
  LMutableTool: TTestRadIAMcpTool;
  LProtocol: IRadIAMcpProtocol;
  LRegistry: IRadIAToolRegistry;
  LResponse: string;
  LSession: TRadIAMcpSession;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LMutableTool := TTestRadIAMcpTool.Create(trReversibleWrite);
  LRegistry.RegisterTool(LMutableTool);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    TRadIADenyConsentProvider.Create,
    LAudit,
    TRadIASecretRedactor.Create
  ) as IRadIAToolExecutor;
  LProtocol := TRadIAMcpProtocol.Create(LRegistry, LExecutor);
  LSession := TRadIAMcpSession.Create('client', 'session', 'project');
  try
    LProtocol.HandleMessage(
      '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{' +
      '"protocolVersion":"2025-06-18","capabilities":{},' +
      '"clientInfo":{"name":"test","version":"1"}}}',
      LSession
    );
    LResponse := LProtocol.HandleMessage(
      '{"jsonrpc":"2.0","id":2,"method":"tools/call",' +
      '"params":{"name":"GetState","arguments":{}}}',
      LSession
    );

    Assert.Contains(LResponse, '"isError":true');
    Assert.Contains(LResponse, 'consent_denied');
    Assert.AreEqual(0, LMutableTool.ExecutionCount);
  finally
    LSession.Free;
  end;
end;

procedure TTestRadIAMcpProtocol.ToolsListMatchesRegistry;
var
  LResponse: string;
begin
  InitializeSession;
  LResponse := FProtocol.HandleMessage(
    '{"jsonrpc":"2.0","id":2,"method":"tools/list"}',
    FSession
  );

  Assert.Contains(LResponse, '"name":"GetState"');
  Assert.Contains(LResponse, '"readOnlyHint":true');
  Assert.Contains(LResponse, '"inputSchema":{"type":"object"');
end;

procedure TTestRadIAMcpProtocol.StdioBridgeCompletesLiveHandshake;
var
  LBridgePath: string;
  LCompleted: TEvent;
  LConnectionFile: string;
  LHandshake: TRadIAMcpHandshakeResult;
  LInvocation: TRadIACliInvocation;
  LProcessResult: TRadIACliProcessResult;
  LRootPath: string;
  LServer: IRadIAMcpServer;
  LSession: IRadIACliProcessSession;
begin
  LServer := CreateNamedPipeServer(LRootPath, LConnectionFile);
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    LServer.Start;
    LBridgePath := TPath.Combine(
      ExtractFilePath(ParamStr(0)),
      'RadIA.MCP.Bridge.exe'
    );
    Assert.IsTrue(TFile.Exists(LBridgePath));
    LInvocation := TRadIACliInvocation.Create(
      LBridgePath,
      [GetInstanceConnectionFile(LConnectionFile)],
      ExtractFilePath(LBridgePath),
      'jsonl'
    );
    LSession := TRadIACliProcessRunner.StartWithInput(
      LInvocation,
      TRadIAMcpHandshake.BuildInput,
      30000,
      nil,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LProcessResult := AResult;
        LCompleted.SetEvent;
      end
    );
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(30000));
    Assert.IsTrue(LProcessResult.Succeeded, LProcessResult.StdErr);
    LHandshake := TRadIAMcpHandshake.ParseOutput(LProcessResult.StdOut);
    Assert.IsTrue(LHandshake.Succeeded, LHandshake.Message);
    Assert.AreEqual(1, LHandshake.ToolCount);
    Assert.IsFalse(LSession.IsRunning);
  finally
    LServer.Stop;
    LCompleted.Free;
    if TDirectory.Exists(LRootPath) then
      TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TTestRadIAMcpProtocol.WriteClientMessage(
  const APipe: THandle;
  const AMessage: string
);
var
  LBytes: TBytes;
  LBytesWritten: DWORD;
begin
  LBytes := TEncoding.UTF8.GetBytes(AMessage);
  LBytesWritten := 0;
  Assert.IsTrue(
    WriteFile(
      APipe,
      LBytes[0],
      Length(LBytes),
      LBytesWritten,
      nil
    )
  );
  Assert.AreEqual(DWORD(Length(LBytes)), LBytesWritten);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAMcpProtocol);

end.
