unit RadIA.Runtime.VclServer;

interface

type
  TRadIARuntimeVclServer = class
  private
    FAdapter: TObject;
    FBoundSessionId: string;
    FConnectionFile: string;
    FEndpoint: string;
    FToken: string;
    FWorker: TObject;
    function BuildConnectionJson: string;
    function HandleRequest(const ARequest: string): string;
    procedure RemoveConnectionFile;
    procedure WriteConnectionFile;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    property Endpoint: string read FEndpoint;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  System.Classes,
  Winapi.Windows,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeVclAdapter,
  RadIA.Runtime.VclAdapter;

const
  CMaxPayloadBytes = 1024 * 1024;
  CPipeBufferBytes = 1024 * 1024;
  CSecurityDescriptorRevision = 1;
  CSecurityDescriptor = 'D:P(A;;GA;;;SY)(A;;GA;;;OW)';

type
  TRadIARuntimeVclServerWorker = class(TThread)
  private
    FEndpoint: string;
    FOwner: TRadIARuntimeVclServer;
    function CreatePipe: THandle;
    function ReadExact(
      const AHandle: THandle;
      const ABuffer: Pointer;
      const ACount: Cardinal
    ): Boolean;
    function ReadRequest(
      const AHandle: THandle;
      out ARequest: string
    ): Boolean;
    function WriteExact(
      const AHandle: THandle;
      const ABuffer: Pointer;
      const ACount: Cardinal
    ): Boolean;
    procedure WriteResponse(
      const AHandle: THandle;
      const AResponse: string
    );
  protected
    procedure Execute; override;
  public
    constructor Create(
      const AOwner: TRadIARuntimeVclServer;
      const AEndpoint: string
    );
  end;

function ConvertStringSecurityDescriptorToSecurityDescriptor(
  StringSecurityDescriptor: PWideChar;
  StringSDRevision: DWORD;
  SecurityDescriptor: PPointer;
  SecurityDescriptorSize: PULONG
): BOOL; stdcall; external 'advapi32.dll'
  name 'ConvertStringSecurityDescriptorToSecurityDescriptorW';

function SecureEquals(const ALeft, ARight: string): Boolean;
var
  LDifference: Integer;
  LIndex: Integer;
  LLeft: Integer;
  LLength: Integer;
  LRight: Integer;
begin
  LDifference := Length(ALeft) xor Length(ARight);
  LLength := Length(ALeft);
  if Length(ARight) > LLength then
    LLength := Length(ARight);
  for LIndex := 1 to LLength do
  begin
    if LIndex <= Length(ALeft) then
      LLeft := Ord(ALeft[LIndex])
    else
      LLeft := 0;
    if LIndex <= Length(ARight) then
      LRight := Ord(ARight[LIndex])
    else
      LRight := 0;
    LDifference := LDifference or (LLeft xor LRight);
  end;
  Result := LDifference = 0;
end;

function ErrorResponse(
  const ACode: string;
  const AMessage: string
): string;
var
  LError: TJSONObject;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('success', TJSONBool.Create(False));
    LError := TJSONObject.Create;
    LError.AddPair('code', ACode);
    LError.AddPair('message', AMessage);
    LRoot.AddPair('error', LError);
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function CapabilityNames(
  const ACapabilities: TRadIARuntimeAutomationCapabilities
): TJSONArray;
begin
  Result := TJSONArray.Create;
  if racInvoke in ACapabilities then
    Result.Add('invoke');
  if racSetValue in ACapabilities then
    Result.Add('setValue');
  if racSelect in ACapabilities then
    Result.Add('select');
  if racClose in ACapabilities then
    Result.Add('close');
end;

function SnapshotJson(
  const ASnapshot: TRadIARuntimeControlSnapshot
): TJSONObject;
var
  LState: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('controlId', ASnapshot.ControlId);
  Result.AddPair('parentId', ASnapshot.ParentId);
  Result.AddPair('className', ASnapshot.ClassName);
  Result.AddPair('text', ASnapshot.Text);
  Result.AddPair('path', ASnapshot.Path);
  LState := TJSONObject.Create;
  LState.AddPair('visible', TJSONBool.Create(ASnapshot.State.Visible));
  LState.AddPair('enabled', TJSONBool.Create(ASnapshot.State.Enabled));
  LState.AddPair('capabilities', CapabilityNames(ASnapshot.State.Capabilities));
  Result.AddPair('state', LState);
end;

function ParseActionKind(
  const AName: string;
  out AKind: TRadIARuntimeActionKind
): Boolean;
begin
  Result := True;
  if SameText(AName, 'invoke') then
    AKind := rakInvoke
  else if SameText(AName, 'setValue') then
    AKind := rakSetValue
  else if SameText(AName, 'select') then
    AKind := rakSelect
  else if SameText(AName, 'close') then
    AKind := rakClose
  else if SameText(AName, 'assert') then
    AKind := rakAssert
  else
    Result := False;
end;

function ParseAction(
  const AParameters: TJSONObject;
  out AAction: TRadIARuntimeScenarioAction
): Boolean;
var
  LKind: TRadIARuntimeActionKind;
  LSelector: TJSONObject;
begin
  Result := False;
  if not ParseActionKind(
    AParameters.GetValue<string>('action', ''),
    LKind
  ) then
    Exit;
  LSelector := AParameters.GetValue<TJSONObject>('selector');
  if not Assigned(LSelector) then
    Exit;
  AAction := TRadIARuntimeScenarioAction.Create(
    LKind,
    TRadIARuntimeSelector.Create(
      LSelector.GetValue<string>('automationId', ''),
      LSelector.GetValue<string>('className', ''),
      LSelector.GetValue<string>('controlName', ''),
      LSelector.GetValue<string>('text', ''),
      LSelector.GetValue<string>('parentPath', '')
    ),
    AParameters.GetValue<string>('value', ''),
    AParameters.GetValue<Cardinal>('timeoutMs', 5000)
  );
  Result := AAction.Selector.HasStableIdentity;
end;

constructor TRadIARuntimeVclServerWorker.Create(
  const AOwner: TRadIARuntimeVclServer;
  const AEndpoint: string
);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FEndpoint := AEndpoint;
end;

function TRadIARuntimeVclServerWorker.CreatePipe: THandle;
var
  LAttributes: TSecurityAttributes;
  LDescriptor: Pointer;
begin
  Result := INVALID_HANDLE_VALUE;
  LDescriptor := nil;
  if not ConvertStringSecurityDescriptorToSecurityDescriptor(
    CSecurityDescriptor,
    CSecurityDescriptorRevision,
    @LDescriptor,
    nil
  ) then
    Exit;
  try
    ZeroMemory(@LAttributes, SizeOf(LAttributes));
    LAttributes.nLength := SizeOf(LAttributes);
    LAttributes.lpSecurityDescriptor := LDescriptor;
    Result := CreateNamedPipe(
      PChar(FEndpoint),
      PIPE_ACCESS_DUPLEX,
      PIPE_TYPE_BYTE or PIPE_READMODE_BYTE or PIPE_WAIT,
      1,
      CPipeBufferBytes,
      CPipeBufferBytes,
      0,
      @LAttributes
    );
  finally
    LocalFree(HLOCAL(LDescriptor));
  end;
end;

procedure TRadIARuntimeVclServerWorker.Execute;
var
  LConnected: Boolean;
  LPipe: THandle;
  LRequest: string;
  LResponse: string;
begin
  while not Terminated do
  begin
    LPipe := CreatePipe;
    if LPipe = INVALID_HANDLE_VALUE then
      Exit;
    try
      LConnected := ConnectNamedPipe(LPipe, nil) or
        (GetLastError = ERROR_PIPE_CONNECTED);
      if not LConnected or Terminated then
        Continue;
      if not ReadRequest(LPipe, LRequest) then
        Continue;
      LResponse := '';
      TThread.Synchronize(nil,
        procedure
        begin
          LResponse := FOwner.HandleRequest(LRequest);
        end
      );
      WriteResponse(LPipe, LResponse);
      FlushFileBuffers(LPipe);
    finally
      DisconnectNamedPipe(LPipe);
      CloseHandle(LPipe);
    end;
  end;
end;

function TRadIARuntimeVclServerWorker.ReadExact(
  const AHandle: THandle;
  const ABuffer: Pointer;
  const ACount: Cardinal
): Boolean;
var
  LOffset: Cardinal;
  LRead: Cardinal;
begin
  Result := False;
  LOffset := 0;
  while LOffset < ACount do
  begin
    LRead := 0;
    if not ReadFile(
      AHandle, PByte(ABuffer)[LOffset], ACount - LOffset, LRead, nil
    ) or (LRead = 0) then
      Exit;
    Inc(LOffset, LRead);
  end;
  Result := True;
end;

function TRadIARuntimeVclServerWorker.ReadRequest(
  const AHandle: THandle;
  out ARequest: string
): Boolean;
var
  LBytes: TBytes;
  LSize: Cardinal;
begin
  ARequest := '';
  Result := ReadExact(AHandle, @LSize, SizeOf(LSize));
  if not Result or (LSize = 0) or (LSize > CMaxPayloadBytes) then
    Exit(False);
  SetLength(LBytes, LSize);
  Result := ReadExact(AHandle, Pointer(LBytes), LSize);
  if Result then
    ARequest := TEncoding.UTF8.GetString(LBytes);
end;

function TRadIARuntimeVclServerWorker.WriteExact(
  const AHandle: THandle;
  const ABuffer: Pointer;
  const ACount: Cardinal
): Boolean;
var
  LOffset: Cardinal;
  LWritten: Cardinal;
begin
  Result := False;
  LOffset := 0;
  while LOffset < ACount do
  begin
    LWritten := 0;
    if not WriteFile(
      AHandle, PByte(ABuffer)[LOffset], ACount - LOffset, LWritten, nil
    ) or (LWritten = 0) then
      Exit;
    Inc(LOffset, LWritten);
  end;
  Result := True;
end;

procedure TRadIARuntimeVclServerWorker.WriteResponse(
  const AHandle: THandle;
  const AResponse: string
);
var
  LBytes: TBytes;
  LSize: Cardinal;
begin
  LBytes := TEncoding.UTF8.GetBytes(AResponse);
  LSize := Length(LBytes);
  if (LSize = 0) or (LSize > CMaxPayloadBytes) then
    Exit;
  if WriteExact(AHandle, @LSize, SizeOf(LSize)) then
    WriteExact(AHandle, Pointer(LBytes), LSize);
end;

constructor TRadIARuntimeVclServer.Create;
var
  LNonce: string;
begin
  inherited Create;
  FAdapter := TRadIARuntimeVclControlAdapter.Create;
  LNonce := StringReplace(TGUID.NewGuid.ToString, '-', '', [rfReplaceAll]);
  LNonce := StringReplace(LNonce, '{', '', [rfReplaceAll]);
  LNonce := StringReplace(LNonce, '}', '', [rfReplaceAll]);
  FToken := LowerCase(THashSHA2.GetHashString(
    TGUID.NewGuid.ToString + LNonce,
    THashSHA2.TSHA2Version.SHA256
  ));
  FEndpoint := '\\.\pipe\RadIA.Runtime.' +
    UIntToStr(GetCurrentProcessId) + '.' + LNonce;
  FConnectionFile := TPath.Combine(
    TPath.Combine(TPath.Combine(TPath.GetHomePath, 'RadIA'), 'RuntimeAdapter'),
    UIntToStr(GetCurrentProcessId) + '.json'
  );
end;

destructor TRadIARuntimeVclServer.Destroy;
begin
  Stop;
  FAdapter.Free;
  inherited Destroy;
end;

function TRadIARuntimeVclServer.BuildConnectionJson: string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('processId', TJSONNumber.Create(GetCurrentProcessId));
    LJson.AddPair('sessionId', FBoundSessionId);
    LJson.AddPair('endpoint', FEndpoint);
    LJson.AddPair('token', FToken);
    LJson.AddPair('protocolVersion', TJSONNumber.Create(1));
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function TRadIARuntimeVclServer.HandleRequest(
  const ARequest: string
): string;
var
  LAction: TRadIARuntimeScenarioAction;
  LActionResult: TRadIARuntimeActionResult;
  LControls: TJSONArray;
  LJson: TJSONObject;
  LMethod: string;
  LParameters: TJSONObject;
  LRoot: TJSONObject;
  LSession: TRadIARuntimeSessionIdentity;
  LSessionId: string;
  LSnapshot: TRadIARuntimeControlSnapshot;
begin
  LRoot := TJSONObject.ParseJSONValue(ARequest) as TJSONObject;
  if not Assigned(LRoot) then
    Exit(ErrorResponse('invalid_request', 'Request must be valid JSON.'));
  try
    if LRoot.GetValue<Integer>('protocolVersion', 0) <> 1 then
      Exit(ErrorResponse('protocol_mismatch', 'Protocol version is not supported.'));
    if not SecureEquals(LRoot.GetValue<string>('token', ''), FToken) then
      Exit(ErrorResponse('authentication_failed', 'Adapter token was rejected.'));
    LSessionId := Trim(LRoot.GetValue<string>('sessionId', ''));
    if LSessionId = '' then
      Exit(ErrorResponse('invalid_session', 'Runtime session id is required.'));
    if FBoundSessionId = '' then
    begin
      FBoundSessionId := LSessionId;
      WriteConnectionFile;
    end
    else if not SecureEquals(FBoundSessionId, LSessionId) then
      Exit(ErrorResponse('session_mismatch', 'Adapter is bound to another session.'));
    LMethod := LRoot.GetValue<string>('method', '');
    LParameters := LRoot.GetValue<TJSONObject>('parameters');
    if not Assigned(LParameters) then
      Exit(ErrorResponse('invalid_parameters', 'Parameters must be a JSON object.'));
    LSession := TRadIARuntimeSessionIdentity.Create(
      FBoundSessionId, GetCurrentProcessId, Now,
      ParamStr(0), ParamStr(0), 'runtime-adapter'
    );
    if SameText(LMethod, 'discover') then
    begin
      LControls := TJSONArray.Create;
      LJson := TJSONObject.Create;
      try
        for LSnapshot in TRadIARuntimeVclControlAdapter(FAdapter).Discover(
          LSession,
          TRadIARuntimeVclAdapterLimits.Defaults
        ) do
          LControls.AddElement(SnapshotJson(LSnapshot));
        LJson.AddPair('success', TJSONBool.Create(True));
        LJson.AddPair('controls', LControls);
        LControls := nil;
        Exit(LJson.ToJSON);
      finally
        LControls.Free;
        LJson.Free;
      end;
    end;
    if not SameText(LMethod, 'execute') or
      not ParseAction(LParameters, LAction) then
      Exit(ErrorResponse('invalid_method', 'Runtime VCL method or action is invalid.'));
    LActionResult := TRadIARuntimeVclControlAdapter(FAdapter).Execute(
      LSession,
      LAction,
      TRadIARuntimeVclAdapterLimits.Defaults
    );
    if not LActionResult.Success then
      Exit(ErrorResponse(LActionResult.ErrorCode, LActionResult.Message));
    LJson := TJSONObject.Create;
    try
      LJson.AddPair('success', TJSONBool.Create(True));
      LJson.AddPair('observedValue', LActionResult.ObservedValue);
      Result := LJson.ToJSON;
    finally
      LJson.Free;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TRadIARuntimeVclServer.RemoveConnectionFile;
begin
  if TFile.Exists(FConnectionFile) then
    TFile.Delete(FConnectionFile);
end;

procedure TRadIARuntimeVclServer.Start;
begin
  if Assigned(FWorker) then
    Exit;
  WriteConnectionFile;
  FWorker := TRadIARuntimeVclServerWorker.Create(Self, FEndpoint);
  TThread(FWorker).Start;
end;

procedure TRadIARuntimeVclServer.Stop;
var
  LHandle: THandle;
begin
  if not Assigned(FWorker) then
  begin
    RemoveConnectionFile;
    Exit;
  end;
  TThread(FWorker).Terminate;
  LHandle := CreateFile(
    PChar(FEndpoint), GENERIC_READ or GENERIC_WRITE, 0,
    nil, OPEN_EXISTING, 0, 0
  );
  if LHandle <> INVALID_HANDLE_VALUE then
    CloseHandle(LHandle);
  TThread(FWorker).WaitFor;
  FWorker.Free;
  FWorker := nil;
  RemoveConnectionFile;
end;

procedure TRadIARuntimeVclServer.WriteConnectionFile;
var
  LDirectory: string;
  LTemporary: string;
begin
  LDirectory := TPath.GetDirectoryName(FConnectionFile);
  TDirectory.CreateDirectory(LDirectory);
  LTemporary := FConnectionFile + '.' + TGUID.NewGuid.ToString + '.tmp';
  TFile.WriteAllText(LTemporary, BuildConnectionJson, TEncoding.UTF8);
  if TFile.Exists(FConnectionFile) then
    TFile.Delete(FConnectionFile);
  TFile.Move(LTemporary, FConnectionFile);
end;

end.
