unit RadIA.Core.RuntimeVisualTools;

interface

uses
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.Tools,
  RadIA.Core.VisualRuntimeSession;

procedure RegisterRadIARuntimeVisualTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const ACaptureFacade: IRadIARuntimeVisualCaptureFacade;
  const AVisualSession: IRadIAVisualRuntimeSession
);

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.RuntimeAutomation;

const
  CCaptureInputSchema =
    '{"type":"object","required":["windowId","phase"],"properties":{' +
    '"windowId":{"type":"string","minLength":64,"maxLength":64},' +
    '"phase":{"type":"string","enum":["before","after"]}},' +
    '"additionalProperties":false}';
  CObjectOutputSchema = '{"type":"object"}';

type
  TRadIACaptureRuntimeVisualTool = class(TInterfacedObject, IRadIATool)
  private
    FCaptureFacade: IRadIARuntimeVisualCaptureFacade;
    FCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FVisualSession: IRadIAVisualRuntimeSession;
    function ParseRequest(
      const ARequest: TRadIAToolRequest;
      out AWindowId: string;
      out APhase: TRadIAVisualCapturePhase;
      out AError: TRadIAToolResult
    ): Boolean;
  public
    constructor Create(
      const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
      const ACaptureFacade: IRadIARuntimeVisualCaptureFacade;
      const AVisualSession: IRadIAVisualRuntimeSession
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

constructor TRadIACaptureRuntimeVisualTool.Create(
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const ACaptureFacade: IRadIARuntimeVisualCaptureFacade;
  const AVisualSession: IRadIAVisualRuntimeSession
);
begin
  inherited Create;
  if not Assigned(ACoordinator) then
    raise EArgumentNilException.Create('ACoordinator');
  if not Assigned(ACaptureFacade) then
    raise EArgumentNilException.Create('ACaptureFacade');
  if not Assigned(AVisualSession) then
    raise EArgumentNilException.Create('AVisualSession');
  FCoordinator := ACoordinator;
  FCaptureFacade := ACaptureFacade;
  FVisualSession := AVisualSession;
end;

function TRadIACaptureRuntimeVisualTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LCapture: TRadIAVisualCapture;
  LError: TRadIAToolResult;
  LJson: TJSONObject;
  LPhase: TRadIAVisualCapturePhase;
  LRuntimeSession: TRadIARuntimeSessionIdentity;
  LSnapshot: TRadIAVisualSessionSnapshot;
  LWindowId: string;
begin
  if not ParseRequest(ARequest, LWindowId, LPhase, LError) then
    Exit(LError);
  try
    LRuntimeSession := FCoordinator.GetCurrentSession;
    if not LRuntimeSession.IsComplete then
      Exit(TRadIAToolResult.Failed(
        'runtime_session_unavailable',
        'Start the active project under the debugger before capturing a runtime window.'
      ));
    if not FVisualSession.TryGetSnapshot(LSnapshot) or
      not SameText(LSnapshot.Session.SessionId, LRuntimeSession.SessionId) or
      (LSnapshot.State <> vssActive) then
      FVisualSession.BeginSession(LRuntimeSession);
    LCapture := FCaptureFacade.CaptureWindow(
      LRuntimeSession,
      LWindowId,
      LPhase
    );
    if not FVisualSession.RecordCapture(LRuntimeSession.SessionId, LCapture) then
      Exit(TRadIAToolResult.Failed(
        'visual_session_changed',
        'The visual runtime session changed before the capture was recorded.'
      ));
    if LPhase = vcpAfter then
      FVisualSession.Complete(
        LRuntimeSession.SessionId,
        vssCompleted,
        'Before and after runtime captures are available for review.'
      );
    LJson := TJSONObject.Create;
    try
      LJson.AddPair('captureId', LCapture.CaptureId);
      LJson.AddPair('sessionId', LRuntimeSession.SessionId);
      LJson.AddPair('windowId', LCapture.WindowId);
      LJson.AddPair('phase', RadIAVisualCapturePhaseName(LCapture.Phase));
      LJson.AddPair('mimeType', LCapture.MimeType);
      LJson.AddPair('width', TJSONNumber.Create(LCapture.Width));
      LJson.AddPair('height', TJSONNumber.Create(LCapture.Height));
      LJson.AddPair('byteLength', TJSONNumber.Create(Length(LCapture.Bytes)));
      LJson.AddPair('retentionMinutes', TJSONNumber.Create(10));
      Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
    finally
      LJson.Free;
    end;
  except
    on E: EArgumentException do
      Result := TRadIAToolResult.Failed('invalid_runtime_capture', E.Message);
    on E: EInvalidOp do
      Result := TRadIAToolResult.Failed('runtime_capture_unavailable', E.Message);
  end;
end;

function TRadIACaptureRuntimeVisualTool.GetDescriptor:
  TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'CaptureRuntimeVisual',
    '1.0.0',
    'Capture a bounded PNG of one visible window owned by the active runtime process.',
    CCaptureInputSchema,
    CObjectOutputSchema,
    trSensitive
  ).WithExecutionOptions(10000, False).WithConsentEveryTime;
end;

function TRadIACaptureRuntimeVisualTool.ParseRequest(
  const ARequest: TRadIAToolRequest;
  out AWindowId: string;
  out APhase: TRadIAVisualCapturePhase;
  out AError: TRadIAToolResult
): Boolean;
var
  LJson: TJSONObject;
  LPhase: string;
begin
  Result := False;
  AWindowId := '';
  APhase := vcpBefore;
  AError := TRadIAToolResult.Failed('invalid_request', 'Capture arguments are invalid.');
  LJson := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LJson) then
    Exit;
  try
    AWindowId := Trim(LJson.GetValue<string>('windowId', ''));
    LPhase := Trim(LJson.GetValue<string>('phase', ''));
    if Length(AWindowId) <> 64 then
    begin
      AError := TRadIAToolResult.Failed(
        'invalid_window_id',
        'Runtime window id must be a 64-character opaque identifier.'
      );
      Exit;
    end;
    if SameText(LPhase, 'before') then
      APhase := vcpBefore
    else if SameText(LPhase, 'after') then
      APhase := vcpAfter
    else
    begin
      AError := TRadIAToolResult.Failed(
        'invalid_capture_phase',
        'Capture phase must be before or after.'
      );
      Exit;
    end;
    Result := True;
  finally
    LJson.Free;
  end;
end;

procedure RegisterRadIARuntimeVisualTools(
  const ARegistry: IRadIAToolRegistry;
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const ACaptureFacade: IRadIARuntimeVisualCaptureFacade;
  const AVisualSession: IRadIAVisualRuntimeSession
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(
    TRadIACaptureRuntimeVisualTool.Create(
      ACoordinator,
      ACaptureFacade,
      AVisualSession
    )
  );
end;

end.
