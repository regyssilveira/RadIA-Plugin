unit RadIA.Core.ExternalMcpClient;

interface

uses
  System.JSON,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpContent,
  RadIA.Core.ExternalMcpTransport,
  RadIA.Core.Tools;

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

  IRadIAExternalMcpCancelableClient = interface
    ['{CA19A7D8-C1CC-4C54-9B6D-04EBEEDC2ED2}']
    function CallToolWithCancellation(
      const ANamespacedName: string;
      const AArgumentsJson: string;
      const ACancellationToken: IRadIAToolCancellationToken;
      out AResultJson: string;
      out AError: string
    ): Boolean;
  end;

  IRadIAExternalMcpDiscoveryClient = interface
    ['{E67F563B-FD2A-43ED-A5E5-EF678CF5812E}']
    function DiscoverPrompts(out AError: string): Boolean;
    function DiscoverResources(out AError: string): Boolean;
  end;

  TRadIAExternalMcpClient = class(
    TInterfacedObject,
    IRadIAExternalMcpClient,
    IRadIAExternalMcpCancelableClient,
    IRadIAExternalMcpDiscoveryClient
  )
  private
    FCatalog: IRadIAExternalMcpCatalog;
    FContentCatalog: IRadIAExternalMcpContentCatalog;
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
    function CallToolCore(
      const ANamespacedName: string;
      const AArgumentsJson: string;
      const ACancellationToken: IRadIAToolCancellationToken;
      out AResultJson: string;
      out AError: string
    ): Boolean;
    function ParseTools(
      const AItems: TJSONArray;
      out ATools: TArray<TRadIAExternalMcpTool>;
      out AError: string
    ): Boolean;
    function FetchListItems(
      const AMethod: string;
      const AItemName: string;
      out AItems: TJSONArray;
      out AError: string
    ): Boolean;
    class function AppendListPage(
      const AResult: TJSONObject;
      const AItemName: string;
      const AItems: TJSONArray;
      out ANextCursor: string;
      out AError: string
    ): Boolean; static;
    function ParsePrompts(
      const AItems: TJSONArray;
      out APrompts: TArray<TRadIAExternalMcpPrompt>;
      out AError: string
    ): Boolean;
    function ParseResources(
      const AItems: TJSONArray;
      out AResources: TArray<TRadIAExternalMcpResource>;
      out AError: string
    ): Boolean;
    procedure ConfigureCancellation(
      const ACancellationToken: IRadIAToolCancellationToken;
      const ARequestId: string;
      out ANotifier: IRadIAToolCancellationNotifier
    );
    function CheckCancellation(
      const ACancellationToken: IRadIAToolCancellationToken;
      const ARequestId: string;
      const AHasCancellationNotifier: Boolean;
      out AError: string
    ): Boolean;
    function ReceiveNextResponse(
      const ACancellationToken: IRadIAToolCancellationToken;
      const ARequestId: string;
      const AStartedAt: UInt64;
      const AHasCancellationNotifier: Boolean;
      out AMessage: string;
      out AError: string
    ): Boolean;
    function TryGetWaitDuration(
      const AStartedAt: UInt64;
      const ACanCancel: Boolean;
      out AWaitMs: Cardinal;
      out AError: string
    ): Boolean;
    function SendNotification(
      const AMethod: string;
      const AParamsJson: string;
      out AError: string
    ): Boolean;
    procedure SendCancellationNotification(const ARequestId: string);
    function SendRequest(
      const AMethod: string;
      const AParamsJson: string;
      const ACancellationToken: IRadIAToolCancellationToken;
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
    ); overload;
    constructor Create(
      const ATransport: IRadIAExternalMcpTransport;
      const ACatalog: IRadIAExternalMcpCatalog;
      const AContentCatalog: IRadIAExternalMcpContentCatalog
    ); overload;
    destructor Destroy; override;
    function CallTool(
      const ANamespacedName: string;
      const AArgumentsJson: string;
      out AResultJson: string;
      out AError: string
    ): Boolean;
    function CallToolWithCancellation(
      const ANamespacedName: string;
      const AArgumentsJson: string;
      const ACancellationToken: IRadIAToolCancellationToken;
      out AResultJson: string;
      out AError: string
    ): Boolean;
    function Connect(
      const AConfig: TRadIAExternalMcpServerConfig;
      out AError: string
    ): Boolean;
    procedure Disconnect;
    function DiscoverPrompts(out AError: string): Boolean;
    function DiscoverResources(out AError: string): Boolean;
    function DiscoverTools(out AError: string): Boolean;
    function GetConnected: Boolean;
    function GetProtocolVersion: string;
  end;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.Version;

const
  CJsonRpcVersion = '2.0';
  CMcpProtocolVersion = '2025-06-18';
  CLegacyMcpProtocolVersion = '2024-11-05';
  CMaximumSkippedMessages = 100;
  CMaximumListPages = 100;
  CMaximumListItems = 4096;
  CCancellationPollIntervalMs = 50;

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

function BuildCursorParams(const ACursor: string): string;
var
  LParams: TJSONObject;
begin
  if ACursor = '' then
    Exit('{}');
  LParams := TJSONObject.Create;
  try
    LParams.AddPair('cursor', ACursor);
    Result := LParams.ToJSON;
  finally
    LParams.Free;
  end;
end;

{ TRadIAExternalMcpClient }

constructor TRadIAExternalMcpClient.Create(
  const ATransport: IRadIAExternalMcpTransport;
  const ACatalog: IRadIAExternalMcpCatalog
);
begin
  Create(ATransport, ACatalog, nil);
end;

constructor TRadIAExternalMcpClient.Create(
  const ATransport: IRadIAExternalMcpTransport;
  const ACatalog: IRadIAExternalMcpCatalog;
  const AContentCatalog: IRadIAExternalMcpContentCatalog
);
begin
  inherited Create;
  if not Assigned(ATransport) then
    raise EArgumentNilException.Create('External MCP transport is required.');
  if not Assigned(ACatalog) then
    raise EArgumentNilException.Create('External MCP catalog is required.');
  FTransport := ATransport;
  FCatalog := ACatalog;
  FContentCatalog := AContentCatalog;
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
begin
  Result := CallToolCore(
    ANamespacedName,
    AArgumentsJson,
    nil,
    AResultJson,
    AError
  );
end;

function TRadIAExternalMcpClient.CallToolCore(
  const ANamespacedName: string;
  const AArgumentsJson: string;
  const ACancellationToken: IRadIAToolCancellationToken;
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
        ACancellationToken,
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

function TRadIAExternalMcpClient.CallToolWithCancellation(
  const ANamespacedName: string;
  const AArgumentsJson: string;
  const ACancellationToken: IRadIAToolCancellationToken;
  out AResultJson: string;
  out AError: string
): Boolean;
begin
  Result := CallToolCore(
    ANamespacedName,
    AArgumentsJson,
    ACancellationToken,
    AResultJson,
    AError
  );
end;

function TRadIAExternalMcpClient.CheckCancellation(
  const ACancellationToken: IRadIAToolCancellationToken;
  const ARequestId: string;
  const AHasCancellationNotifier: Boolean;
  out AError: string
): Boolean;
begin
  Result := Assigned(ACancellationToken) and
    ACancellationToken.CancellationRequested;
  if not Result then
    Exit;
  if not AHasCancellationNotifier then
    SendCancellationNotification(ARequestId);
  AError := 'External MCP request was cancelled.';
end;

procedure TRadIAExternalMcpClient.ConfigureCancellation(
  const ACancellationToken: IRadIAToolCancellationToken;
  const ARequestId: string;
  out ANotifier: IRadIAToolCancellationNotifier
);
begin
  ANotifier := nil;
  if not Assigned(ACancellationToken) or not Supports(
    ACancellationToken,
    IRadIAToolCancellationNotifier,
    ANotifier
  ) then
    Exit;
  ANotifier.SetCancellationCallback(
    procedure
    begin
      SendCancellationNotification(ARequestId);
    end
  );
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
      if Assigned(FContentCatalog) then
        FContentCatalog.ClearServer(FConfig.Id);
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
      nil,
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
    begin
      FCatalog.ClearServer(FConfig.Id);
      if Assigned(FContentCatalog) then
        FContentCatalog.ClearServer(FConfig.Id);
    end;
    FConnected := False;
    FProtocolVersion := '';
    FTransport.Stop;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpClient.DiscoverPrompts(
  out AError: string
): Boolean;
var
  LItems: TJSONArray;
  LPrompts: TArray<TRadIAExternalMcpPrompt>;
begin
  AError := '';
  TMonitor.Enter(FLock);
  try
    if not FConnected then
    begin
      AError := 'External MCP client is not connected.';
      Exit(False);
    end;
    if not Assigned(FContentCatalog) then
    begin
      AError := 'External MCP content catalog is not configured.';
      Exit(False);
    end;
    if not FetchListItems('prompts/list', 'prompts', LItems, AError) then
      Exit(False);
    try
      if not ParsePrompts(LItems, LPrompts, AError) then
        Exit(False);
      Result := FContentCatalog.PublishPrompts(FConfig, LPrompts, AError);
    finally
      LItems.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpClient.DiscoverResources(
  out AError: string
): Boolean;
var
  LItems: TJSONArray;
  LResources: TArray<TRadIAExternalMcpResource>;
begin
  AError := '';
  TMonitor.Enter(FLock);
  try
    if not FConnected then
    begin
      AError := 'External MCP client is not connected.';
      Exit(False);
    end;
    if not Assigned(FContentCatalog) then
    begin
      AError := 'External MCP content catalog is not configured.';
      Exit(False);
    end;
    if not FetchListItems('resources/list', 'resources', LItems, AError) then
      Exit(False);
    try
      if not ParseResources(LItems, LResources, AError) then
        Exit(False);
      Result := FContentCatalog.PublishResources(FConfig, LResources, AError);
    finally
      LItems.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpClient.DiscoverTools(
  out AError: string
): Boolean;
var
  LItems: TJSONArray;
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
    if not FetchListItems('tools/list', 'tools', LItems, AError) then
      Exit(False);
    try
      if not ParseTools(LItems, LTools, AError) then
        Exit(False);
      Result := FCatalog.PublishTools(FConfig, LTools, AError);
    finally
      LItems.Free;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpClient.FetchListItems(
  const AMethod: string;
  const AItemName: string;
  out AItems: TJSONArray;
  out AError: string
): Boolean;
var
  LCursor: string;
  LCursors: TDictionary<string, Boolean>;
  LPage: Integer;
  LParams: string;
  LResult: TJSONObject;
  LResultJson: string;
begin
  Result := False;
  AItems := TJSONArray.Create;
  AError := '';
  LCursors := TDictionary<string, Boolean>.Create;
  try
    LCursor := '';
    for LPage := 1 to CMaximumListPages do
    begin
      LParams := BuildCursorParams(LCursor);
      if not SendRequest(AMethod, LParams, nil, LResultJson, AError) then
        Exit;
      if not ParseJsonObject(LResultJson, LResult) then
      begin
        AError := 'External MCP list result must be a JSON object.';
        Exit;
      end;
      try
        if not AppendListPage(
          LResult,
          AItemName,
          AItems,
          LCursor,
          AError
        ) then
          Exit;
      finally
        LResult.Free;
      end;
      if LCursor = '' then
        Exit(True);
      if LCursors.ContainsKey(LCursor) then
      begin
        AError := 'External MCP list returned a repeated cursor.';
        Exit;
      end;
      LCursors.Add(LCursor, True);
    end;
    AError := 'External MCP list exceeds the safe page limit.';
  finally
    LCursors.Free;
    if not Result then
      FreeAndNil(AItems);
  end;
end;

class function TRadIAExternalMcpClient.AppendListPage(
  const AResult: TJSONObject;
  const AItemName: string;
  const AItems: TJSONArray;
  out ANextCursor: string;
  out AError: string
): Boolean;
var
  LIndex: Integer;
  LPageItems: TJSONArray;
begin
  Result := False;
  ANextCursor := '';
  AError := '';
  if not (AResult.GetValue(AItemName) is TJSONArray) then
  begin
    AError := 'External MCP list result does not contain ' + AItemName + '.';
    Exit;
  end;
  LPageItems := TJSONArray(AResult.GetValue(AItemName));
  if AItems.Count + LPageItems.Count > CMaximumListItems then
  begin
    AError := 'External MCP list exceeds the safe item limit.';
    Exit;
  end;
  for LIndex := 0 to LPageItems.Count - 1 do
    AItems.AddElement(LPageItems[LIndex].Clone as TJSONValue);
  ANextCursor := AResult.GetValue<string>('nextCursor', '');
  Result := True;
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
  const AItems: TJSONArray;
  out ATools: TArray<TRadIAExternalMcpTool>;
  out AError: string
): Boolean;
var
  LDescription: string;
  LIndex: Integer;
  LName: string;
  LSchema: TJSONValue;
  LTool: TJSONObject;
begin
  ATools := nil;
  AError := '';
  SetLength(ATools, AItems.Count);
  for LIndex := 0 to AItems.Count - 1 do
  begin
    if not (AItems[LIndex] is TJSONObject) then
    begin
      AError := 'External MCP tool entry must be a JSON object.';
      Exit(False);
    end;
    LTool := TJSONObject(AItems[LIndex]);
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
end;

function TRadIAExternalMcpClient.ParsePrompts(
  const AItems: TJSONArray;
  out APrompts: TArray<TRadIAExternalMcpPrompt>;
  out AError: string
): Boolean;
var
  LArguments: TJSONValue;
  LIndex: Integer;
  LPrompt: TJSONObject;
begin
  APrompts := nil;
  AError := '';
  SetLength(APrompts, AItems.Count);
  for LIndex := 0 to AItems.Count - 1 do
  begin
    if not (AItems[LIndex] is TJSONObject) then
    begin
      AError := 'External MCP prompt entry must be a JSON object.';
      Exit(False);
    end;
    LPrompt := TJSONObject(AItems[LIndex]);
    LArguments := LPrompt.GetValue('arguments');
    if not Assigned(LArguments) then
      LArguments := TJSONArray.Create;
    try
      if not (LArguments is TJSONArray) then
      begin
        AError := 'External MCP prompt arguments must be an array.';
        Exit(False);
      end;
      APrompts[LIndex] := TRadIAExternalMcpPrompt.Create(
        FConfig.Id,
        LPrompt.GetValue<string>('name', ''),
        LPrompt.GetValue<string>('description', ''),
        LArguments.ToJSON
      );
    finally
      if not Assigned(LPrompt.GetValue('arguments')) then
        LArguments.Free;
    end;
  end;
  Result := True;
end;

function TRadIAExternalMcpClient.ParseResources(
  const AItems: TJSONArray;
  out AResources: TArray<TRadIAExternalMcpResource>;
  out AError: string
): Boolean;
var
  LIndex: Integer;
  LResource: TJSONObject;
begin
  AResources := nil;
  AError := '';
  SetLength(AResources, AItems.Count);
  for LIndex := 0 to AItems.Count - 1 do
  begin
    if not (AItems[LIndex] is TJSONObject) then
    begin
      AError := 'External MCP resource entry must be a JSON object.';
      Exit(False);
    end;
    LResource := TJSONObject(AItems[LIndex]);
    AResources[LIndex] := TRadIAExternalMcpResource.Create(
      FConfig.Id,
      LResource.GetValue<string>('uri', ''),
      LResource.GetValue<string>('name', ''),
      LResource.GetValue<string>('description', ''),
      LResource.GetValue<string>('mimeType', '')
    );
  end;
  Result := True;
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

procedure TRadIAExternalMcpClient.SendCancellationNotification(
  const ARequestId: string
);
var
  LError: string;
begin
  SendNotification(
    'notifications/cancelled',
    '{"requestId":' + ARequestId + '}',
    LError
  );
end;

function TRadIAExternalMcpClient.ReceiveNextResponse(
  const ACancellationToken: IRadIAToolCancellationToken;
  const ARequestId: string;
  const AStartedAt: UInt64;
  const AHasCancellationNotifier: Boolean;
  out AMessage: string;
  out AError: string
): Boolean;
var
  LWaitMs: Cardinal;
begin
  Result := False;
  AMessage := '';
  AError := '';
  repeat
    if CheckCancellation(
      ACancellationToken,
      ARequestId,
      AHasCancellationNotifier,
      AError
    ) then
      Exit;
    if not TryGetWaitDuration(
      AStartedAt,
      Assigned(ACancellationToken),
      LWaitMs,
      AError
    ) then
      Exit;
    if FTransport.Receive(LWaitMs, AMessage) then
      Exit(True);
    if not FTransport.Running then
    begin
      AError := FTransport.LastError;
      if AError = '' then
        AError := 'External MCP server stopped before responding.';
      Exit;
    end;
  until False;
end;

function TRadIAExternalMcpClient.TryGetWaitDuration(
  const AStartedAt: UInt64;
  const ACanCancel: Boolean;
  out AWaitMs: Cardinal;
  out AError: string
): Boolean;
var
  LElapsed: UInt64;
begin
  AError := '';
  LElapsed := GetTickCount64 - AStartedAt;
  Result := LElapsed < Cardinal(FConfig.TimeoutMs);
  if not Result then
  begin
    AWaitMs := 0;
    AError := 'External MCP request timed out.';
    Exit;
  end;
  AWaitMs := Cardinal(FConfig.TimeoutMs) - Cardinal(LElapsed);
  if ACanCancel and (AWaitMs > CCancellationPollIntervalMs) then
    AWaitMs := CCancellationPollIntervalMs;
end;

function TRadIAExternalMcpClient.SendRequest(
  const AMethod: string;
  const AParamsJson: string;
  const ACancellationToken: IRadIAToolCancellationToken;
  out AResultJson: string;
  out AError: string
): Boolean;
var
  LCancellationNotifier: IRadIAToolCancellationNotifier;
  LId: string;
  LMessage: string;
  LReceived: string;
  LResponseSucceeded: Boolean;
  LSkipped: Integer;
  LStartedAt: UInt64;
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
  ConfigureCancellation(
    ACancellationToken,
    LId,
    LCancellationNotifier
  );
  try
    LStartedAt := GetTickCount64;
    LSkipped := 0;
    while ReceiveNextResponse(
      ACancellationToken,
      LId,
      LStartedAt,
      Assigned(LCancellationNotifier),
      LReceived,
      AError
    ) do
    begin
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
    end;
    Result := False;
  finally
    if Assigned(LCancellationNotifier) then
      LCancellationNotifier.ClearCancellationCallback;
  end;
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
