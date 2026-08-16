unit RadIA.OTA.RuntimeVclTransport;

interface

uses
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeVclAdapter;

type
  TRadIARuntimeVclEndpointLocator = class(
    TInterfacedObject,
    IRadIARuntimeVclEndpointLocator
  )
  private
    FRootPath: string;
    function ConnectionFile(const AProcessId: LongWord): string;
  public
    constructor Create(const ARootPath: string = '');
    function Locate(
      const ASession: TRadIARuntimeSessionIdentity;
      out AIdentity: TRadIARuntimeVclAdapterIdentity
    ): Boolean;
  end;

  TRadIARuntimeVclNamedPipeTransport = class(
    TInterfacedObject,
    IRadIARuntimeVclTransport
  )
  public
    function Send(
      const AIdentity: TRadIARuntimeVclAdapterIdentity;
      const AMethod: string;
      const AParametersJson: string;
      const ALimits: TRadIARuntimeVclAdapterLimits
    ): TRadIARuntimeVclTransportResult;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows;

const
  CConnectionDirectory = 'RuntimeAdapter';

function ReadExact(
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
      AHandle,
      PByte(ABuffer)[LOffset],
      ACount - LOffset,
      LRead,
      nil
    ) or (LRead = 0) then
      Exit;
    Inc(LOffset, LRead);
  end;
  Result := True;
end;

function WriteExact(
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
      AHandle,
      PByte(ABuffer)[LOffset],
      ACount - LOffset,
      LWritten,
      nil
    ) or (LWritten = 0) then
      Exit;
    Inc(LOffset, LWritten);
  end;
  Result := True;
end;

function WaitForNamedPipeEndpoint(
  const AEndpoint: string;
  const ATimeoutMs: Cardinal
): Boolean;
var
  LDeadline: UInt64;
  LRemaining: Cardinal;
begin
  LDeadline := GetTickCount64 + ATimeoutMs;
  repeat
    if GetTickCount64 >= LDeadline then
      Exit(False);
    LRemaining := Cardinal(LDeadline - GetTickCount64);
    if LRemaining > 100 then
      LRemaining := 100;
    if WaitNamedPipe(PChar(AEndpoint), LRemaining) then
      Exit(True);
    if not (GetLastError in [ERROR_FILE_NOT_FOUND, ERROR_SEM_TIMEOUT,
      ERROR_PIPE_BUSY]) then
      Exit(False);
    Sleep(10);
  until False;
end;

constructor TRadIARuntimeVclEndpointLocator.Create(
  const ARootPath: string
);
begin
  inherited Create;
  if Trim(ARootPath) <> '' then
    FRootPath := TPath.GetFullPath(ARootPath)
  else
    FRootPath := TPath.Combine(
      TPath.Combine(TPath.GetHomePath, 'RadIA'),
      CConnectionDirectory
    );
end;

function TRadIARuntimeVclEndpointLocator.ConnectionFile(
  const AProcessId: LongWord
): string;
begin
  Result := TPath.Combine(FRootPath, AProcessId.ToString + '.json');
end;

function TRadIARuntimeVclEndpointLocator.Locate(
  const ASession: TRadIARuntimeSessionIdentity;
  out AIdentity: TRadIARuntimeVclAdapterIdentity
): Boolean;
var
  LFileName: string;
  LJson: TJSONObject;
  LSessionId: string;
begin
  AIdentity := Default(TRadIARuntimeVclAdapterIdentity);
  Result := False;
  if not ASession.IsComplete then
    Exit;
  LFileName := ConnectionFile(ASession.ProcessId);
  if not TFile.Exists(LFileName) then
    Exit;
  try
    LJson := TJSONObject.ParseJSONValue(
      TFile.ReadAllText(LFileName, TEncoding.UTF8)
    ) as TJSONObject;
    if not Assigned(LJson) then
      Exit;
    try
      LSessionId := LJson.GetValue<string>('sessionId', '');
      if Trim(LSessionId) = '' then
        LSessionId := ASession.SessionId;
      AIdentity := TRadIARuntimeVclAdapterIdentity.Create(
        LJson.GetValue<LongWord>('processId', 0),
        LSessionId,
        LJson.GetValue<string>('endpoint', ''),
        LJson.GetValue<string>('token', ''),
        LJson.GetValue<Integer>('protocolVersion', 0)
      );
      Result := AIdentity.IsUsableFor(ASession);
    finally
      LJson.Free;
    end;
  except
    on Exception do
      Result := False;
  end;
end;

function BuildRequest(
  const AIdentity: TRadIARuntimeVclAdapterIdentity;
  const AMethod: string;
  const AParametersJson: string;
  out ARequest: TBytes
): Boolean;
var
  LJson: TJSONObject;
  LParameters: TJSONValue;
begin
  Result := False;
  LParameters := TJSONObject.ParseJSONValue(AParametersJson);
  if not Assigned(LParameters) then
    Exit;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('protocolVersion', TJSONNumber.Create(AIdentity.ProtocolVersion));
    LJson.AddPair('sessionId', AIdentity.SessionId);
    LJson.AddPair('token', AIdentity.Token);
    LJson.AddPair('method', Trim(AMethod));
    LJson.AddPair('parameters', LParameters);
    LParameters := nil;
    ARequest := TEncoding.UTF8.GetBytes(LJson.ToJSON);
    Result := True;
  finally
    LParameters.Free;
    LJson.Free;
  end;
end;

function TRadIARuntimeVclNamedPipeTransport.Send(
  const AIdentity: TRadIARuntimeVclAdapterIdentity;
  const AMethod: string;
  const AParametersJson: string;
  const ALimits: TRadIARuntimeVclAdapterLimits
): TRadIARuntimeVclTransportResult;
var
  LHandle: THandle;
  LRequest: TBytes;
  LRequestSize: Cardinal;
  LResponse: TBytes;
  LResponseSize: Cardinal;
begin
  if not ALimits.IsValid then
    Exit(TRadIARuntimeVclTransportResult.Failed(
      'runtime_vcl_invalid_limits', 'Runtime VCL adapter limits are invalid.'
    ));
  if Trim(AMethod) = '' then
    Exit(TRadIARuntimeVclTransportResult.Failed(
      'runtime_vcl_invalid_method', 'Runtime VCL adapter method is required.'
    ));
  if not BuildRequest(AIdentity, AMethod, AParametersJson, LRequest) then
    Exit(TRadIARuntimeVclTransportResult.Failed(
      'runtime_vcl_invalid_parameters', 'Parameters must be valid JSON.'
    ));
  if Length(LRequest) > ALimits.MaxPayloadBytes then
    Exit(TRadIARuntimeVclTransportResult.Failed(
      'runtime_vcl_payload_too_large', 'Runtime VCL request exceeds the configured limit.'
    ));
  if not WaitForNamedPipeEndpoint(AIdentity.Endpoint, ALimits.TimeoutMs) then
    Exit(TRadIARuntimeVclTransportResult.Failed(
      'runtime_vcl_endpoint_unavailable', 'Runtime VCL adapter is not available.'
    ));
  LHandle := CreateFile(
    PChar(AIdentity.Endpoint), GENERIC_READ or GENERIC_WRITE, 0,
    nil, OPEN_EXISTING, 0, 0
  );
  if LHandle = INVALID_HANDLE_VALUE then
    Exit(TRadIARuntimeVclTransportResult.Failed(
      'runtime_vcl_connection_failed', 'Could not connect to the runtime VCL adapter.'
    ));
  try
    LRequestSize := Length(LRequest);
    if not WriteExact(LHandle, @LRequestSize, SizeOf(LRequestSize)) or
      not WriteExact(LHandle, Pointer(LRequest), LRequestSize) or
      not ReadExact(LHandle, @LResponseSize, SizeOf(LResponseSize)) then
      Exit(TRadIARuntimeVclTransportResult.Failed(
        'runtime_vcl_transport_failed', 'Runtime VCL transport did not complete.'
      ));
    if (LResponseSize = 0) or
      (LResponseSize > Cardinal(ALimits.MaxPayloadBytes)) then
      Exit(TRadIARuntimeVclTransportResult.Failed(
        'runtime_vcl_invalid_response', 'Runtime VCL response exceeded the configured limit.'
      ));
    SetLength(LResponse, LResponseSize);
    if not ReadExact(LHandle, Pointer(LResponse), LResponseSize) then
      Exit(TRadIARuntimeVclTransportResult.Failed(
        'runtime_vcl_transport_failed', 'Runtime VCL response was incomplete.'
      ));
    Result := TRadIARuntimeVclTransportResult.Succeeded(
      TEncoding.UTF8.GetString(LResponse)
    );
  finally
    CloseHandle(LHandle);
  end;
end;

end.
