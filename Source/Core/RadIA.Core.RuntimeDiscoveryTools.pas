unit RadIA.Core.RuntimeDiscoveryTools;

interface

uses
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.Tools;

procedure RegisterRadIARuntimeDiscoveryTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const ADiscovery: IRadIARuntimeDiscoveryFacade
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIARuntimeDiscoveryToolKind = (
    rdtkGetWindows,
    rdtkGetControlTree
  );

  TRadIARuntimeDiscoveryTool = class(TInterfacedObject, IRadIATool)
  private
    FCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FDiscovery: IRadIARuntimeDiscoveryFacade;
    FKind: TRadIARuntimeDiscoveryToolKind;
    function ExecuteGetControlTree(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function ExecuteGetWindows: TRadIAToolResult;
  public
    constructor Create(
      const AKind: TRadIARuntimeDiscoveryToolKind;
      const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
      const ADiscovery: IRadIARuntimeDiscoveryFacade
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';
  CControlTreeInputSchema =
    '{"type":"object","required":["windowId"],"properties":{' +
    '"windowId":{"type":"string","minLength":64,"maxLength":64}},' +
    '"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

procedure AddCapabilities(
  const ACapabilities: TRadIARuntimeAutomationCapabilities;
  const AJson: TJSONObject
);
var
  LArray: TJSONArray;
begin
  LArray := TJSONArray.Create;
  AJson.AddPair('capabilities', LArray);
  if racInvoke in ACapabilities then
    LArray.Add('invoke');
  if racSetValue in ACapabilities then
    LArray.Add('setValue');
  if racSelect in ACapabilities then
    LArray.Add('select');
  if racClose in ACapabilities then
    LArray.Add('close');
end;

procedure AddElementState(
  const AState: TRadIARuntimeElementState;
  const AJson: TJSONObject
);
begin
  AJson.AddPair('visible', TJSONBool.Create(AState.Visible));
  AJson.AddPair('enabled', TJSONBool.Create(AState.Enabled));
  AddCapabilities(AState.Capabilities, AJson);
end;

{ TRadIARuntimeDiscoveryTool }

constructor TRadIARuntimeDiscoveryTool.Create(
  const AKind: TRadIARuntimeDiscoveryToolKind;
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const ADiscovery: IRadIARuntimeDiscoveryFacade
);
begin
  inherited Create;
  if not Assigned(ACoordinator) then
    raise EArgumentNilException.Create('ACoordinator');
  if not Assigned(ADiscovery) then
    raise EArgumentNilException.Create('ADiscovery');
  FKind := AKind;
  FCoordinator := ACoordinator;
  FDiscovery := ADiscovery;
end;

function TRadIARuntimeDiscoveryTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  try
    case FKind of
      rdtkGetWindows:
        Result := ExecuteGetWindows;
      rdtkGetControlTree:
        Result := ExecuteGetControlTree(ARequest);
    else
      Result := TRadIAToolResult.Failed(
        'unsupported_tool',
        'Runtime discovery tool kind is unsupported.'
      );
    end;
  except
    on E: EInvalidOp do
      Result := TRadIAToolResult.Failed(
        'runtime_session_changed',
        E.Message
      );
    on E: EArgumentException do
      Result := TRadIAToolResult.Failed(
        'invalid_runtime_window',
        E.Message
      );
  end;
end;

function TRadIARuntimeDiscoveryTool.ExecuteGetControlTree(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LArray: TJSONArray;
  LControl: TRadIARuntimeControlSnapshot;
  LItem: TJSONObject;
  LJson: TJSONObject;
  LRoot: TJSONObject;
  LWindowId: string;
begin
  LJson := TJSONObject.ParseJSONValue(
    ARequest.ArgumentsJson
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit(TRadIAToolResult.Failed(
      'invalid_request',
      'Runtime control tree arguments must be a JSON object.'
    ));
  try
    LWindowId := LJson.GetValue<string>('windowId', '');
    if Length(LWindowId) <> 64 then
      Exit(TRadIAToolResult.Failed(
        'invalid_window_id',
        'Runtime window id must be a 64-character opaque identifier.'
      ));
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('windowId', LWindowId);
      LArray := TJSONArray.Create;
      LRoot.AddPair('controls', LArray);
      for LControl in FDiscovery.GetControlTree(
        FCoordinator.GetCurrentSession,
        LWindowId
      ) do
      begin
        LItem := TJSONObject.Create;
        LItem.AddPair('controlId', LControl.ControlId);
        LItem.AddPair('parentId', LControl.ParentId);
        LItem.AddPair('className', LControl.ClassName);
        LItem.AddPair('text', LControl.Text);
        LItem.AddPair('path', LControl.Path);
        AddElementState(LControl.State, LItem);
        LArray.AddElement(LItem);
      end;
      LRoot.AddPair('count', TJSONNumber.Create(LArray.Count));
      Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
    finally
      LRoot.Free;
    end;
  finally
    LJson.Free;
  end;
end;

function TRadIARuntimeDiscoveryTool.ExecuteGetWindows:
  TRadIAToolResult;
var
  LArray: TJSONArray;
  LItem: TJSONObject;
  LRoot: TJSONObject;
  LWindow: TRadIARuntimeWindowSnapshot;
begin
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LRoot.AddPair('windows', LArray);
    for LWindow in FDiscovery.GetWindows(
      FCoordinator.GetCurrentSession
    ) do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('windowId', LWindow.WindowId);
      LItem.AddPair(
        'processId',
        TJSONNumber.Create(LWindow.ProcessId)
      );
      LItem.AddPair('className', LWindow.ClassName);
      LItem.AddPair('text', LWindow.Text);
      LItem.AddPair('ownerId', LWindow.OwnerId);
      LItem.AddPair('modal', TJSONBool.Create(LWindow.Modal));
      AddElementState(LWindow.State, LItem);
      LArray.AddElement(LItem);
    end;
    LRoot.AddPair('count', TJSONNumber.Create(LArray.Count));
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimeDiscoveryTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  case FKind of
    rdtkGetWindows:
      Result := TRadIAToolDescriptor.Create(
        'GetRuntimeWindows',
        '1.0.0',
        'List opaque windows confined to the active runtime debug session.',
        CEmptyInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
    rdtkGetControlTree:
      Result := TRadIAToolDescriptor.Create(
        'GetRuntimeControlTree',
        '1.0.0',
        'Return safe selectors and capabilities for an authorized window.',
        CControlTreeInputSchema,
        CObjectOutputSchema,
        trReadOnly
      );
  end;
end;

procedure RegisterRadIARuntimeDiscoveryTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const ADiscovery: IRadIARuntimeDiscoveryFacade
);
var
  LKind: TRadIARuntimeDiscoveryToolKind;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  for LKind := Low(TRadIARuntimeDiscoveryToolKind) to
    High(TRadIARuntimeDiscoveryToolKind) do
    ARegistry.RegisterTool(
      TRadIARuntimeDiscoveryTool.Create(
        LKind,
        ACoordinator,
        ADiscovery
      )
    );
end;

end.
