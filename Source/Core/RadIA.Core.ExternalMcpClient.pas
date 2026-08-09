unit RadIA.Core.ExternalMcpClient;

interface

uses
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpTransport;

type
  IRadIAExternalMcpClient = interface
    ['{FA1CA2BB-4C39-4CE7-922A-51ECF97E11A3}']
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
    property Connected: Boolean read GetConnected;
    property ProtocolVersion: string read GetProtocolVersion;
  end;

  TRadIAExternalMcpClient = class(
    TInterfacedObject,
    IRadIAExternalMcpClient
  )
  private
    FCatalog: IRadIAExternalMcpCatalog;
    FConfig: TRadIAExternalMcpServerConfig;
    FConnected: Boolean;
    FLock: TObject;
    FNextRequestId: Int64;
    FProtocolVersion: string;
    FTransport: IRadIAExternalMcpTransport;
    function BuildRequestMessage(
      const AMethod: string;
      const AParamsJson: string;
      out AId: string;
      out AMessage: string;
      out AError: string
    ): Boolean;
    function BuildInitializeParams: string;
    function ParseTools(
      const AResultJson: string;
      out ATools: TArray<TRadIAExternalMcpTool>;
      out AError: string
    ): Boolean;
    function SendNotification(
      const AMethod: string;
      const AParamsJson: string;
      out AError: string
    ): Boolean;
    function SendRequest(
      const AMethod: string;
      const AParamsJson: string;
      out AResultJson: string;
      out AError: string
    ): Boolean;
    function TryHandleResponse(
      const AResponseJson: string;
      const AExpectedId: string;
      out AResultJson: string;
      out AError: string;
      out ASucceeded: Boolean
    ): Boolean;
    function ValidateInitializeResult(
      const AResultJson: string;
      out AError: string
    ): Boolean;
  public
    constructor Create(
      const ATransport: IRadIAExternalMcpTransport;
      const ACatalog: IRadIAExternalMcpCatalog
    );
    destructor Destroy; override;
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

implementation

uses
  System.JSON,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.Version;

const
  CJsonRpcVersion = '2.0';
  CMcpProtocolVersion = '2025-06-18';
  CLegacyMcpProtocolVersion = '2024-11-05';
  CMaximumSkippedMessages = 100;

function IsSupportedProtocolVersion(const AVersion: string): Boolean;
begin
  Result := (AVersion = CMcpProtocolVersion) or
    (AVersion = CLegacyMcpProtocolVersion);
end;

function ParseJsonObject(
  const AJson: string;
  out AObject: TJSONObject
): Boolean;
var
  LValue: TJSONValue;
begin
  AObject := nil;
  LValue := TJSONObject.ParseJSONValue(AJson);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    Exit(False);
  end;
  AObject := TJSONObject(LValue);
  Result := True;
end;

{ TRadIAExternalMcpClient }

constructor TRadIAExternalMcpClient.Create(
  const ATransport: IRadIAExternalMcpTransport;
  const ACatalog: IRadIAExternalMcpCatalog
);
begin
  inherited Create;
  if not Assigned(ATransport) then
    raise EArgumentNilException.Create('External MCP transport is required.');
  if not Assigned(ACatalog) then
    raise EArgumentNilException.Create('External MCP catalog is required.');
  FTransport := ATransport;
  FCatalog := ACatalog;
  FLock := TObject.Create;
end;

destructor TRadIAExternalMcpClient.Destroy;
begin
  Disconnect;
  FLock.Free;
  inherited Destroy;
end;

function TRadIAExternalMcpClient.BuildInitializeParams: string;
var
  LCapabilities: TJSONObject;
  LClientInfo: TJSONObject;
  LParams: TJSONObject;
begin
  LParams := TJSONObject.Create;
  try
    LCapabilities := TJSONObject.Create;
    LClientInfo := TJSONObject.Create;
    LClientInfo.AddPair('name', 'RadIA');
    LClientInfo.AddPair('version', CRadIAVersion);
    LParams.AddPair('protocolVersion', CMcpProtocolVersion);
    LParams.AddPair('capabilities', LCapabilities);
    LParams.AddPair('clientInfo', LClientInfo);
    Result := LParams.ToJSON;
  finally
    LParams.Free;
  end;
end;

function TRadIAExternalMcpClient.BuildRequestMessage(
  const AMethod: string;
  const AParamsJson: string;
  out AId: string;
  out AMessage: string;
  out AError: string
): Boolean;
var
  LMessage: TJSONObject;
  LParams: TJSONObject;
begin
  AId := '';
  AMessage := '';
  AError := '';
  if not ParseJsonObject(AParamsJson, LParams) then
  begin
    AError := 'External MCP request parameters must be a JSON object.';
    Exit(False);
  end;
  Inc(FNextRequestId);
  AId := IntToStr(FNextRequestId);
  LMessage := TJSONObject.Create;
  try
    LMessage.AddPair('jsonrpc', CJsonRpcVersion);
    LMessage.AddPair('id', TJSONNumber.Create(FNextRequestId));
    LMessage.AddPair('method', AMethod);
    LMessage.AddPair('params', LParams);
    AMessage := LMessage.ToJSON;
    Result := True;
  finally
    LMessage.Free;
  end;
end;

function TRadIAExternalMcpClient.CallTool(
  const ANamespacedName: string;
  const AArgumentsJson: string;
  out AResultJson: string;
  out AError: string
): Boolean;
var
  LArguments: TJSONObject;
  LParams: TJSONObject;
  LTool: TRadIAExternalMcpTool;
begin
  AResultJson := '';
  AError := '';
  TMonitor.Enter(FLock);
  try
    if not FConnected then
    begin
      AError := 'External MCP client is not connected.';
      Exit(False);
    end;
    if not FCatalog.TryResolve(ANamespacedName, LTool) or
       not SameText(LTool.ServerId, FConfig.Id) then
    begin
      AError := 'External MCP tool is unavailable in the active server.';
      Exit(False);
    end;
    if not ParseJsonObject(AArgumentsJson, LArguments) then
    begin
      AError := 'External MCP tool arguments must be a JSON object.';
      Exit(False);
    end;
    LParams := TJSONObject.Create;
    try
      LParams.AddPair('name', LTool.ToolName);
      LParams.AddPair('arguments', LArguments);
      Result := SendRequest(
        'tools/call',
        LParams.ToJSON,
        AResultJson,
        AError
      );
    finally
      LParams.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpClient.Connect(
  const AConfig: TRadIAExternalMcpServerConfig;
  out AError: string
): Boolean;
var
  LResultJson: string;
begin
  AError := '';
  TMonitor.Enter(FLock);
  try
    if FConnected then
    begin
      FCatalog.ClearServer(FConfig.Id);
      FTransport.Stop;
      FConnected := False;
    end;
    FConfig := AConfig;
    FProtocolVersion := '';
    if not FTransport.Start(AConfig, AError) then
      Exit(False);
    if not SendRequest(
      'initialize',
      BuildInitializeParams,
      LResultJson,
      AError
    ) or not ValidateInitializeResult(LResultJson, AError) or
       not SendNotification('notifications/initialized', '{}', AError) then
    begin
      FTransport.Stop;
      Exit(False);
    end;
    FConnected := True;
    Result := True;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAExternalMcpClient.Disconnect;
begin
  TMonitor.Enter(FLock);
  try
    if FConfig.Id <> '' then
      FCatalog.ClearServer(FConfig.Id);
    FConnected := False;
    FProtocolVersion := '';
    FTransport.Stop;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpClient.DiscoverTools(
  out AError: string
): Boolean;
var
  LResultJson: string;
  LTools: TArray<TRadIAExternalMcpTool>;
begin
  AError := '';
  TMonitor.Enter(FLock);
  try
    if not FConnected then
    begin
      AError := 'External MCP client is not connected.';
      Exit(False);
    end;
    if not SendRequest('tools/list', '{}', LResultJson, AError) then
      Exit(False);
    if not ParseTools(LResultJson, LTools, AError) then
      Exit(False);
    Result := FCatalog.PublishTools(FConfig, LTools, AError);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpClient.GetConnected: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FConnected;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpClient.GetProtocolVersion: string;
begin
  TMonitor.Enter(FLock);
  try
    Result := FProtocolVersion;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpClient.ParseTools(
  const AResultJson: string;
  out ATools: TArray<TRadIAExternalMcpTool>;
  out AError: string
): Boolean;
var
  LDescription: string;
  LIndex: Integer;
  LName: string;
  LObject: TJSONObject;
  LSchema: TJSONValue;
  LTool: TJSONObject;
  LTools: TJSONArray;
begin
  ATools := nil;
  AError := '';
  if not ParseJsonObject(AResultJson, LObject) then
  begin
    AError := 'External MCP tools/list result must be a JSON object.';
    Exit(False);
  end;
  try
    if not (LObject.GetValue('tools') is TJSONArray) then
    begin
      AError := 'External MCP tools/list result does not contain a tools array.';
      Exit(False);
    end;
    LTools := TJSONArray(LObject.GetValue('tools'));
    SetLength(ATools, LTools.Count);
    for LIndex := 0 to LTools.Count - 1 do
    begin
      if not (LTools[LIndex] is TJSONObject) then
      begin
        AError := 'External MCP tool entry must be a JSON object.';
        Exit(False);
      end;
      LTool := TJSONObject(LTools[LIndex]);
      LName := LTool.GetValue<string>('name', '');
      LDescription := LTool.GetValue<string>('description', '');
      LSchema := LTool.GetValue('inputSchema');
      if not (LSchema is TJSONObject) then
      begin
        AError := 'External MCP tool inputSchema must be a JSON object.';
        Exit(False);
      end;
      ATools[LIndex] := TRadIAExternalMcpTool.Create(
        FConfig.Id,
        LName,
        LDescription,
        LSchema.ToJSON
      );
    end;
    Result := True;
  finally
    LObject.Free;
  end;
end;

function TRadIAExternalMcpClient.SendNotification(
  const AMethod: string;
  const AParamsJson: string;
  out AError: string
): Boolean;
var
  LMessage: TJSONObject;
  LParams: TJSONObject;
begin
  AError := '';
  if not ParseJsonObject(AParamsJson, LParams) then
  begin
    AError := 'External MCP notification parameters must be a JSON object.';
    Exit(False);
  end;
  LMessage := TJSONObject.Create;
  try
    LMessage.AddPair('jsonrpc', CJsonRpcVersion);
    LMessage.AddPair('method', AMethod);
    LMessage.AddPair('params', LParams);
    Result := FTransport.Send(LMessage.ToJSON);
    if not Result then
      AError := FTransport.LastError;
  finally
    LMessage.Free;
  end;
end;

function TRadIAExternalMcpClient.SendRequest(
  const AMethod: string;
  const AParamsJson: string;
  out AResultJson: string;
  out AError: string
): Boolean;
var
  LId: string;
  LMessage: string;
  LReceived: string;
  LResponseSucceeded: Boolean;
  LSkipped: Integer;
  LStartedAt: UInt64;
  LWaitMs: Cardinal;
begin
  AResultJson := '';
  AError := '';
  if not BuildRequestMessage(
    AMethod,
    AParamsJson,
    LId,
    LMessage,
    AError
  ) then
    Exit(False);
  if not FTransport.Send(LMessage) then
  begin
    AError := FTransport.LastError;
    Exit(False);
  end;
  LStartedAt := GetTickCount64;
  LSkipped := 0;
  repeat
    if GetTickCount64 - LStartedAt >= Cardinal(FConfig.TimeoutMs) then
    begin
      AError := 'External MCP request timed out.';
      Exit(False);
    end;
    LWaitMs := Cardinal(FConfig.TimeoutMs) -
      Cardinal(GetTickCount64 - LStartedAt);
    if not FTransport.Receive(LWaitMs, LReceived) then
    begin
      AError := FTransport.LastError;
      if AError = '' then
        AError := 'External MCP request timed out or the server stopped.';
      Exit(False);
    end;
    Inc(LSkipped);
    if LSkipped > CMaximumSkippedMessages then
    begin
      AError := 'External MCP response correlation limit was exceeded.';
      Exit(False);
    end;
    if TryHandleResponse(
      LReceived,
      LId,
      AResultJson,
      AError,
      LResponseSucceeded
    ) then
      Exit(LResponseSucceeded);
  until False;
end;

function TRadIAExternalMcpClient.TryHandleResponse(
  const AResponseJson: string;
  const AExpectedId: string;
  out AResultJson: string;
  out AError: string;
  out ASucceeded: Boolean
): Boolean;
var
  LError: TJSONObject;
  LResponse: TJSONObject;
  LResult: TJSONValue;
begin
  Result := False;
  ASucceeded := False;
  AResultJson := '';
  AError := '';
  if not ParseJsonObject(AResponseJson, LResponse) then
    Exit;
  try
    if LResponse.GetValue<string>('jsonrpc', '') <> CJsonRpcVersion then
      Exit;
    if LResponse.GetValue<string>('id', '') <> AExpectedId then
      Exit;
    Result := True;
    if LResponse.GetValue('error') is TJSONObject then
    begin
      LError := TJSONObject(LResponse.GetValue('error'));
      AError := LError.GetValue<string>('message', 'External MCP server error.');
      Exit;
    end;
    LResult := LResponse.GetValue('result');
    if not Assigned(LResult) then
    begin
      AError := 'External MCP response does not contain a result.';
      Exit;
    end;
    AResultJson := LResult.ToJSON;
    ASucceeded := True;
  finally
    LResponse.Free;
  end;
end;

function TRadIAExternalMcpClient.ValidateInitializeResult(
  const AResultJson: string;
  out AError: string
): Boolean;
var
  LObject: TJSONObject;
begin
  AError := '';
  if not ParseJsonObject(AResultJson, LObject) then
  begin
    AError := 'External MCP initialize result must be a JSON object.';
    Exit(False);
  end;
  try
    FProtocolVersion := LObject.GetValue<string>('protocolVersion', '');
    if FProtocolVersion = '' then
      AError := 'External MCP server did not negotiate a protocol version.'
    else if not IsSupportedProtocolVersion(FProtocolVersion) then
      AError := 'External MCP server negotiated an unsupported protocol version.'
    else if not (LObject.GetValue('capabilities') is TJSONObject) then
      AError := 'External MCP initialize result does not contain capabilities.'
    else if not (LObject.GetValue('serverInfo') is TJSONObject) then
      AError := 'External MCP initialize result does not contain serverInfo.';
    Result := AError = '';
  finally
    LObject.Free;
  end;
end;

end.
