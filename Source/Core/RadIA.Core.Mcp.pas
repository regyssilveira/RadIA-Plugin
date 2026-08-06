unit RadIA.Core.Mcp;

interface

uses
  System.Generics.Collections,
  System.JSON,
  RadIA.Core.Tools;

type
  IRadIAMcpCancellationSource = interface(
    IRadIAToolCancellationToken
  )
    ['{09F80619-D036-479E-89AD-8C8AD4B45A55}']
    procedure Cancel;
  end;

  TRadIAMcpCancellationSource = class(
    TInterfacedObject,
    IRadIAMcpCancellationSource,
    IRadIAToolCancellationToken
  )
  private
    FCancelled: Integer;
  public
    procedure Cancel;
    function GetCancellationRequested: Boolean;
  end;

  TRadIAMcpSession = class
  private
    FCancellations: TDictionary<string, IRadIAMcpCancellationSource>;
    FClientId: string;
    FCancellationRequests: Integer;
    FCompletedRequests: Integer;
    FInitialized: Boolean;
    FPeakActiveRequests: Integer;
    FProjectId: string;
    FReceivedMessages: Integer;
    FRejectedRequests: Integer;
    FActiveRequests: Integer;
    FSessionId: string;
    procedure UpdatePeakActiveRequests;
  public
    constructor Create(
      const AClientId: string;
      const ASessionId: string;
      const AProjectId: string
    );
    destructor Destroy; override;
    function BeginRequest(
      const ARequestId: string
    ): IRadIAToolCancellationToken;
    procedure CancelAllRequests;
    function CancelRequest(const ARequestId: string): Boolean;
    procedure EndRequest(const ARequestId: string);
    procedure MarkInitialized;
    procedure RecordMessageReceived;
    procedure RecordRejectedRequest;
    function GetActiveRequests: Integer;
    function GetCancellationRequests: Integer;
    function GetCompletedRequests: Integer;
    function GetPeakActiveRequests: Integer;
    function GetReceivedMessages: Integer;
    function GetRejectedRequests: Integer;
    property ActiveRequests: Integer read GetActiveRequests;
    property CancellationRequests: Integer
      read GetCancellationRequests;
    property CompletedRequests: Integer read GetCompletedRequests;
    property Initialized: Boolean read FInitialized;
    property ProjectId: string read FProjectId write FProjectId;
    property PeakActiveRequests: Integer read GetPeakActiveRequests;
    property ReceivedMessages: Integer read GetReceivedMessages;
    property RejectedRequests: Integer read GetRejectedRequests;
    property SessionId: string read FSessionId;
  end;

  IRadIAMcpProtocol = interface
    ['{2567EC59-3E91-4D66-92F2-ED0B246373A5}']
    function HandleMessage(
      const AMessage: string;
      const ASession: TRadIAMcpSession
    ): string;
  end;

  IRadIAMcpServer = interface
    ['{D85F64FB-0619-43CB-AF8B-B49518210D0D}']
    procedure Start;
    procedure Stop;
    function GetEndpoint: string;
    function GetRunning: Boolean;
    property Endpoint: string read GetEndpoint;
    property Running: Boolean read GetRunning;
  end;

  TRadIAMcpProtocol = class(
    TInterfacedObject,
    IRadIAMcpProtocol
  )
  private
    FRegistry: IRadIAToolRegistry;
    FExecutor: IRadIAToolExecutor;
    function BuildError(
      const AId: string;
      const ACode: Integer;
      const AMessage: string
    ): string;
    function BuildInitializeResult(
      const AId: string;
      const ASession: TRadIAMcpSession
    ): string;
    function BuildMetrics(
      const AId: string;
      const ASession: TRadIAMcpSession
    ): string;
    function BuildSuccess(
      const AId: string;
      const AResult: string
    ): string;
    function BuildToolsList(const AId: string): string;
    function CallTool(
      const AId: string;
      const AParamsJson: string;
      const ASession: TRadIAMcpSession
    ): string;
    function CancelRequest(
      const AParamsJson: string;
      const ASession: TRadIAMcpSession
    ): string;
    function DispatchMethod(
      const AMethod: string;
      const AIdJson: string;
      const AJson: TJSONObject;
      const ASession: TRadIAMcpSession
    ): string;
    function HandleNotification(
      const AMethod: string;
      const AJson: TJSONObject;
      const ASession: TRadIAMcpSession;
      out AHandled: Boolean
    ): string;
    function IsInitializeParamsValid(
      const AJson: TJSONObject
    ): Boolean;
    function ProcessRequest(
      const AJson: TJSONObject;
      const ASession: TRadIAMcpSession;
      out AIdJson: string
    ): string;
    function RiskIsDestructive(
      const ARisk: TRadIAToolRisk
    ): Boolean;
  public
    constructor Create(
      const ARegistry: IRadIAToolRegistry;
      const AExecutor: IRadIAToolExecutor
    );
    function HandleMessage(
      const AMessage: string;
      const ASession: TRadIAMcpSession
    ): string;
  end;

implementation

uses
  System.SyncObjs,
  System.SysUtils,
  RadIA.Core.Version;

const
  CMcpProtocolVersion = '2025-06-18';
  CJsonRpcVersion = '2.0';
  CParseError = -32700;
  CInvalidRequest = -32600;
  CMethodNotFound = -32601;
  CInvalidParams = -32602;
  CInternalError = -32603;
  CNotInitialized = -32002;
  CRequestLimitExceeded = -32003;

{ TRadIAMcpCancellationSource }

procedure TRadIAMcpCancellationSource.Cancel;
begin
  TInterlocked.Exchange(FCancelled, 1);
end;

function TRadIAMcpCancellationSource.GetCancellationRequested:
  Boolean;
begin
  Result := TInterlocked.CompareExchange(FCancelled, 0, 0) <> 0;
end;

{ TRadIAMcpSession }

constructor TRadIAMcpSession.Create(
  const AClientId: string;
  const ASessionId: string;
  const AProjectId: string
);
begin
  inherited Create;
  FCancellations :=
    TDictionary<string, IRadIAMcpCancellationSource>.Create;
  FClientId := AClientId;
  FSessionId := ASessionId;
  FProjectId := AProjectId;
  FInitialized := False;
end;

function TRadIAMcpSession.BeginRequest(
  const ARequestId: string
): IRadIAToolCancellationToken;
var
  LSource: IRadIAMcpCancellationSource;
begin
  LSource := TRadIAMcpCancellationSource.Create;
  TMonitor.Enter(FCancellations);
  try
    if FCancellations.Count >= 1 then
    begin
      RecordRejectedRequest;
      Exit(nil);
    end;
    FCancellations.Add(ARequestId, LSource);
  finally
    TMonitor.Exit(FCancellations);
  end;
  TInterlocked.Increment(FActiveRequests);
  UpdatePeakActiveRequests;
  Result := LSource;
end;

function TRadIAMcpSession.CancelRequest(
  const ARequestId: string
): Boolean;
var
  LSource: IRadIAMcpCancellationSource;
begin
  TMonitor.Enter(FCancellations);
  try
    Result := FCancellations.TryGetValue(ARequestId, LSource);
    if Result then
    begin
      LSource.Cancel;
      TInterlocked.Increment(FCancellationRequests);
    end;
  finally
    TMonitor.Exit(FCancellations);
  end;
end;

procedure TRadIAMcpSession.CancelAllRequests;
var
  LSource: IRadIAMcpCancellationSource;
begin
  TMonitor.Enter(FCancellations);
  try
    for LSource in FCancellations.Values do
      LSource.Cancel;
  finally
    TMonitor.Exit(FCancellations);
  end;
end;

destructor TRadIAMcpSession.Destroy;
begin
  FCancellations.Free;
  inherited;
end;

procedure TRadIAMcpSession.EndRequest(
  const ARequestId: string
);
begin
  TMonitor.Enter(FCancellations);
  try
    FCancellations.Remove(ARequestId);
  finally
    TMonitor.Exit(FCancellations);
  end;
  TInterlocked.Decrement(FActiveRequests);
  TInterlocked.Increment(FCompletedRequests);
end;

function TRadIAMcpSession.GetActiveRequests: Integer;
begin
  Result := TInterlocked.CompareExchange(FActiveRequests, 0, 0);
end;

function TRadIAMcpSession.GetCancellationRequests: Integer;
begin
  Result := TInterlocked.CompareExchange(
    FCancellationRequests,
    0,
    0
  );
end;

function TRadIAMcpSession.GetCompletedRequests: Integer;
begin
  Result := TInterlocked.CompareExchange(FCompletedRequests, 0, 0);
end;

function TRadIAMcpSession.GetPeakActiveRequests: Integer;
begin
  Result := TInterlocked.CompareExchange(FPeakActiveRequests, 0, 0);
end;

function TRadIAMcpSession.GetReceivedMessages: Integer;
begin
  Result := TInterlocked.CompareExchange(FReceivedMessages, 0, 0);
end;

function TRadIAMcpSession.GetRejectedRequests: Integer;
begin
  Result := TInterlocked.CompareExchange(FRejectedRequests, 0, 0);
end;

procedure TRadIAMcpSession.MarkInitialized;
begin
  FInitialized := True;
end;

procedure TRadIAMcpSession.RecordMessageReceived;
begin
  TInterlocked.Increment(FReceivedMessages);
end;

procedure TRadIAMcpSession.RecordRejectedRequest;
begin
  TInterlocked.Increment(FRejectedRequests);
end;

procedure TRadIAMcpSession.UpdatePeakActiveRequests;
var
  LActive: Integer;
  LPeak: Integer;
begin
  LActive := GetActiveRequests;
  repeat
    LPeak := GetPeakActiveRequests;
    if LActive <= LPeak then
      Exit;
  until TInterlocked.CompareExchange(
    FPeakActiveRequests,
    LActive,
    LPeak
  ) = LPeak;
end;

{ TRadIAMcpProtocol }

function TRadIAMcpProtocol.BuildError(
  const AId: string;
  const ACode: Integer;
  const AMessage: string
): string;
var
  LError: TJSONObject;
  LJson: TJSONObject;
  LRequestId: TJSONValue;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('jsonrpc', CJsonRpcVersion);
    LRequestId := TJSONObject.ParseJSONValue(AId);
    if Assigned(LRequestId) then
      LJson.AddPair('id', LRequestId)
    else
      LJson.AddPair('id', TJSONNull.Create);

    LError := TJSONObject.Create;
    LError.AddPair('code', TJSONNumber.Create(ACode));
    LError.AddPair('message', AMessage);
    LJson.AddPair('error', LError);
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function TRadIAMcpProtocol.BuildInitializeResult(
  const AId: string;
  const ASession: TRadIAMcpSession
): string;
var
  LCapabilities: TJSONObject;
  LResult: TJSONObject;
  LServerInfo: TJSONObject;
  LTools: TJSONObject;
begin
  ASession.MarkInitialized;
  LResult := TJSONObject.Create;
  try
    LResult.AddPair('protocolVersion', CMcpProtocolVersion);
    LCapabilities := TJSONObject.Create;
    LTools := TJSONObject.Create;
    LTools.AddPair('listChanged', TJSONBool.Create(False));
    LCapabilities.AddPair('tools', LTools);
    LResult.AddPair('capabilities', LCapabilities);

    LServerInfo := TJSONObject.Create;
    LServerInfo.AddPair('name', 'RadIA');
    LServerInfo.AddPair('version', CRadIAVersion);
    LResult.AddPair('serverInfo', LServerInfo);
    LResult.AddPair(
      'instructions',
      'Use IDE tools only within the active Delphi workspace. ' +
      'Mutating and execution tools require user consent.'
    );
    Result := BuildSuccess(AId, LResult.ToJSON);
  finally
    LResult.Free;
  end;
end;

function TRadIAMcpProtocol.BuildMetrics(
  const AId: string;
  const ASession: TRadIAMcpSession
): string;
var
  LMetrics: TJSONObject;
begin
  LMetrics := TJSONObject.Create;
  try
    LMetrics.AddPair(
      'receivedMessages',
      TJSONNumber.Create(ASession.ReceivedMessages)
    );
    LMetrics.AddPair(
      'completedToolCalls',
      TJSONNumber.Create(ASession.CompletedRequests)
    );
    LMetrics.AddPair(
      'activeToolCalls',
      TJSONNumber.Create(ASession.ActiveRequests)
    );
    LMetrics.AddPair(
      'peakActiveToolCalls',
      TJSONNumber.Create(ASession.PeakActiveRequests)
    );
    LMetrics.AddPair(
      'cancellationRequests',
      TJSONNumber.Create(ASession.CancellationRequests)
    );
    LMetrics.AddPair(
      'rejectedRequests',
      TJSONNumber.Create(ASession.RejectedRequests)
    );
    Result := BuildSuccess(AId, LMetrics.ToJSON);
  finally
    LMetrics.Free;
  end;
end;

function TRadIAMcpProtocol.BuildSuccess(
  const AId: string;
  const AResult: string
): string;
var
  LJson: TJSONObject;
  LRequestId: TJSONValue;
  LResult: TJSONValue;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('jsonrpc', CJsonRpcVersion);
    LRequestId := TJSONObject.ParseJSONValue(AId);
    if Assigned(LRequestId) then
      LJson.AddPair('id', LRequestId)
    else
      LJson.AddPair('id', TJSONNull.Create);
    LResult := TJSONObject.ParseJSONValue(AResult);
    if Assigned(LResult) then
      LJson.AddPair('result', LResult)
    else
      LJson.AddPair('result', TJSONObject.Create);
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function TRadIAMcpProtocol.BuildToolsList(
  const AId: string
): string;
var
  LAnnotations: TJSONObject;
  LDescriptor: TRadIAToolDescriptor;
  LInputSchema: TJSONValue;
  LResult: TJSONObject;
  LTool: TJSONObject;
  LTools: TJSONArray;
begin
  LResult := TJSONObject.Create;
  try
    LTools := TJSONArray.Create;
    for LDescriptor in FRegistry.GetDescriptors do
    begin
      LTool := TJSONObject.Create;
      LTool.AddPair('name', LDescriptor.Name);
      LTool.AddPair('title', LDescriptor.Name);
      LTool.AddPair('description', LDescriptor.Description);
      LInputSchema := TJSONObject.ParseJSONValue(
        LDescriptor.InputSchema
      );
      if Assigned(LInputSchema) then
        LTool.AddPair('inputSchema', LInputSchema)
      else
        LTool.AddPair('inputSchema', TJSONObject.Create);

      LAnnotations := TJSONObject.Create;
      LAnnotations.AddPair(
        'readOnlyHint',
        TJSONBool.Create(LDescriptor.Risk = trReadOnly)
      );
      LAnnotations.AddPair(
        'destructiveHint',
        TJSONBool.Create(
          RiskIsDestructive(LDescriptor.Risk)
        )
      );
      LAnnotations.AddPair(
        'idempotentHint',
        TJSONBool.Create(LDescriptor.Idempotent)
      );
      LAnnotations.AddPair(
        'openWorldHint',
        TJSONBool.Create(False)
      );
      LTool.AddPair('annotations', LAnnotations);
      LTools.AddElement(LTool);
    end;
    LResult.AddPair('tools', LTools);
    Result := BuildSuccess(AId, LResult.ToJSON);
  finally
    LResult.Free;
  end;
end;

function TRadIAMcpProtocol.CallTool(
  const AId: string;
  const AParamsJson: string;
  const ASession: TRadIAMcpSession
): string;
var
  LArguments: TJSONValue;
  LArgumentsJson: string;
  LContent: TJSONArray;
  LContentItem: TJSONObject;
  LParams: TJSONObject;
  LRequest: TRadIAToolRequest;
  LResult: TJSONObject;
  LStructuredContent: TJSONValue;
  LToolName: string;
  LToolResult: TRadIAToolResult;
  LCancellationToken: IRadIAToolCancellationToken;
begin
  LParams := TJSONObject.ParseJSONValue(AParamsJson) as TJSONObject;
  if not Assigned(LParams) then
    Exit(BuildError(AId, CInvalidParams, 'Invalid tool parameters.'));
  try
    LToolName := LParams.GetValue<string>('name', '');
    if LToolName = '' then
      Exit(BuildError(AId, CInvalidParams, 'Tool name is required.'));

    LArguments := LParams.GetValue('arguments');
    if Assigned(LArguments) then
      LArgumentsJson := LArguments.ToJSON
    else
      LArgumentsJson := '{}';
  finally
    LParams.Free;
  end;

  LCancellationToken := ASession.BeginRequest(AId);
  if not Assigned(LCancellationToken) then
    Exit(
      BuildError(
        AId,
        CRequestLimitExceeded,
        'MCP session already has an active tool request.'
      )
    );
  try
    LRequest := TRadIAToolRequest.Create(
      LToolName,
      LArgumentsJson,
      TGUID.NewGuid.ToString,
      'mcp',
      ASession.SessionId,
      ASession.ProjectId,
      'workspace'
    ).WithCancellation(LCancellationToken);
    LToolResult := FExecutor.Execute(LRequest);
  finally
    ASession.EndRequest(AId);
  end;

  LResult := TJSONObject.Create;
  try
    LContent := TJSONArray.Create;
    LContentItem := TJSONObject.Create;
    LContentItem.AddPair('type', 'text');
    if LToolResult.Success then
      LContentItem.AddPair('text', LToolResult.ContentJson)
    else
      LContentItem.AddPair(
        'text',
        Format(
          '%s: %s',
          [LToolResult.ErrorCode, LToolResult.ErrorMessage]
        )
      );
    LContent.AddElement(LContentItem);
    LResult.AddPair('content', LContent);
    LResult.AddPair(
      'isError',
      TJSONBool.Create(not LToolResult.Success)
    );

    if LToolResult.Success then
    begin
      LStructuredContent := TJSONObject.ParseJSONValue(
        LToolResult.ContentJson
      );
      if LStructuredContent is TJSONObject then
        LResult.AddPair('structuredContent', LStructuredContent)
      else
        LStructuredContent.Free;
    end;
    Result := BuildSuccess(AId, LResult.ToJSON);
  finally
    LResult.Free;
  end;
end;

function TRadIAMcpProtocol.CancelRequest(
  const AParamsJson: string;
  const ASession: TRadIAMcpSession
): string;
var
  LParams: TJSONObject;
  LRequestId: TJSONValue;
begin
  LParams := TJSONObject.ParseJSONValue(AParamsJson) as TJSONObject;
  if not Assigned(LParams) then
    Exit('');
  try
    LRequestId := LParams.GetValue('requestId');
    if Assigned(LRequestId) and
      ((LRequestId is TJSONString) or
      (LRequestId is TJSONNumber)) then
      ASession.CancelRequest(LRequestId.ToJSON);
  finally
    LParams.Free;
  end;
  Result := '';
end;

constructor TRadIAMcpProtocol.Create(
  const ARegistry: IRadIAToolRegistry;
  const AExecutor: IRadIAToolExecutor
);
begin
  inherited Create;
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  if not Assigned(AExecutor) then
    raise EArgumentNilException.Create('AExecutor');
  FRegistry := ARegistry;
  FExecutor := AExecutor;
end;

function TRadIAMcpProtocol.DispatchMethod(
  const AMethod: string;
  const AIdJson: string;
  const AJson: TJSONObject;
  const ASession: TRadIAMcpSession
): string;
var
  LParams: TJSONValue;
begin
  if AMethod = 'ping' then
    Exit(BuildSuccess(AIdJson, '{}'));
  if AMethod = 'tools/list' then
    Exit(BuildToolsList(AIdJson));
  if AMethod = 'radia/metrics' then
    Exit(BuildMetrics(AIdJson, ASession));
  if AMethod = 'tools/call' then
  begin
    LParams := AJson.GetValue('params');
    if Assigned(LParams) then
      Exit(CallTool(AIdJson, LParams.ToJSON, ASession));
    Exit(CallTool(AIdJson, '{}', ASession));
  end;
  Result := BuildError(
    AIdJson,
    CMethodNotFound,
    'Method not found.'
  );
end;

function TRadIAMcpProtocol.HandleMessage(
  const AMessage: string;
  const ASession: TRadIAMcpSession
): string;
var
  LIdJson: string;
  LParsed: TJSONValue;
begin
  if not Assigned(ASession) then
    Exit(BuildError('null', CInternalError, 'MCP session is required.'));
  ASession.RecordMessageReceived;

  LIdJson := 'null';
  LParsed := TJSONObject.ParseJSONValue(AMessage);
  if not Assigned(LParsed) then
    Exit(BuildError('null', CParseError, 'Invalid JSON.'));
  try
    try
      if not (LParsed is TJSONObject) then
        Exit(BuildError('null', CInvalidRequest, 'Invalid request.'));
      Result := ProcessRequest(TJSONObject(LParsed), ASession, LIdJson);
    except
      on Exception do
        Result := BuildError(
          LIdJson,
          CInternalError,
          'Internal server error.'
        );
    end;
  finally
    LParsed.Free;
  end;
end;

function TRadIAMcpProtocol.HandleNotification(
  const AMethod: string;
  const AJson: TJSONObject;
  const ASession: TRadIAMcpSession;
  out AHandled: Boolean
): string;
var
  LParams: TJSONValue;
begin
  AHandled := AMethod = 'notifications/initialized';
  if AHandled then
    Exit('');
  AHandled := AMethod = 'notifications/cancelled';
  if not AHandled then
    Exit('');
  LParams := AJson.GetValue('params');
  if Assigned(LParams) then
    Exit(CancelRequest(LParams.ToJSON, ASession));
  Result := '';
end;

function TRadIAMcpProtocol.IsInitializeParamsValid(
  const AJson: TJSONObject
): Boolean;
var
  LParams: TJSONValue;
begin
  LParams := AJson.GetValue('params');
  Result := (LParams is TJSONObject) and
    (TJSONObject(LParams).GetValue<string>('protocolVersion', '') <> '') and
    (TJSONObject(LParams).GetValue('capabilities') is TJSONObject) and
    (TJSONObject(LParams).GetValue('clientInfo') is TJSONObject);
end;

function TRadIAMcpProtocol.ProcessRequest(
  const AJson: TJSONObject;
  const ASession: TRadIAMcpSession;
  out AIdJson: string
): string;
var
  LHandled: Boolean;
  LId: TJSONValue;
  LMethod: string;
begin
  AIdJson := 'null';
  if AJson.GetValue<string>('jsonrpc', '') <> CJsonRpcVersion then
    Exit(BuildError(
      'null',
      CInvalidRequest,
      'Invalid JSON-RPC version.'
    ));
  LMethod := AJson.GetValue<string>('method', '');
  LId := AJson.GetValue('id');
  Result := HandleNotification(LMethod, AJson, ASession, LHandled);
  if LHandled then
    Exit;
  if not Assigned(LId) or (LId is TJSONNull) then
    Exit(BuildError(
      'null',
      CInvalidRequest,
      'JSON-RPC request ID is required.'
    ));
  if not (LId is TJSONString) and not (LId is TJSONNumber) then
    Exit(BuildError(
      'null',
      CInvalidRequest,
      'JSON-RPC request ID must be a string or number.'
    ));
  AIdJson := LId.ToJSON;
  if LMethod = 'initialize' then
  begin
    if not IsInitializeParamsValid(AJson) then
      Exit(BuildError(
        AIdJson,
        CInvalidParams,
        'Initialize parameters are incomplete.'
      ));
    Exit(BuildInitializeResult(AIdJson, ASession));
  end;
  if not ASession.Initialized then
    Exit(BuildError(
      AIdJson,
      CNotInitialized,
      'MCP session is not initialized.'
    ));
  Result := DispatchMethod(LMethod, AIdJson, AJson, ASession);
end;

function TRadIAMcpProtocol.RiskIsDestructive(
  const ARisk: TRadIAToolRisk
): Boolean;
begin
  Result := ARisk in [
    trStructuralWrite,
    trDestructive,
    trSensitive
  ];
end;

end.
