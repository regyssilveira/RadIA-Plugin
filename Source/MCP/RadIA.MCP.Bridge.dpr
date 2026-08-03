program RadIAMcpBridge;

{$APPTYPE CONSOLE}

uses
  System.Classes,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows;

const
  CMaxPayloadBytes = 1024 * 1024;
  CPipeResponseTimeoutMs = 10 * 60 * 1000;
  CProcessQueryLimitedInformation = $1000;

function IsProcessRunning(const AProcessId: Cardinal): Boolean;
var
  LExitCode: DWORD;
  LProcess: THandle;
begin
  Result := False;
  if AProcessId = 0 then
    Exit;
  LProcess := OpenProcess(
    CProcessQueryLimitedInformation,
    False,
    AProcessId
  );
  if LProcess = 0 then
    Exit;
  try
    Result := GetExitCodeProcess(LProcess, LExitCode) and
      (LExitCode = STILL_ACTIVE);
  finally
    CloseHandle(LProcess);
  end;
end;

function TryLoadConnection(
  const AConnectionFile: string;
  out AEndpoint: string
): Boolean;
var
  LJson: TJSONObject;
  LProcessId: Cardinal;
begin
  Result := False;
  AEndpoint := '';
  if not TFile.Exists(AConnectionFile) then
    Exit;
  try
    LJson := TJSONObject.ParseJSONValue(
      TFile.ReadAllText(AConnectionFile, TEncoding.UTF8)
    ) as TJSONObject;
    if not Assigned(LJson) then
      Exit;
    try
      AEndpoint := LJson.GetValue<string>('endpoint', '');
      LProcessId := LJson.GetValue<Cardinal>('processId', 0);
      Result := (AEndpoint <> '') and IsProcessRunning(LProcessId);
    finally
      LJson.Free;
    end;
  except
    on Exception do
    begin
      AEndpoint := '';
      Result := False;
    end;
  end;
end;

function ConnectionBelongsTo(
  const AConnectionFile: string;
  const AEndpoint: string;
  const AProcessId: Cardinal
): Boolean;
var
  LJson: TJSONObject;
begin
  Result := False;
  if not TFile.Exists(AConnectionFile) then
    Exit;
  try
    LJson := TJSONObject.ParseJSONValue(
      TFile.ReadAllText(AConnectionFile, TEncoding.UTF8)
    ) as TJSONObject;
    if not Assigned(LJson) then
      Exit;
    try
      Result :=
        SameText(
          LJson.GetValue<string>('endpoint', ''),
          AEndpoint
        ) and
        (LJson.GetValue<Cardinal>('processId', 0) =
          AProcessId);
    finally
      LJson.Free;
    end;
  except
    on Exception do
      Result := False;
  end;
end;

procedure DeleteOwnedConnection(
  const AConnectionFile: string;
  const AEndpoint: string;
  const AProcessId: Cardinal
);
begin
  try
    if ConnectionBelongsTo(
      AConnectionFile,
      AEndpoint,
      AProcessId
    ) then
      TFile.Delete(AConnectionFile);
  except
    on Exception do
      Exit;
  end;
end;

procedure RunCleanupWatchdog;
const
  CProcessSynchronize = $00100000;
var
  LEndpoint: string;
  LInstanceConnectionFile: string;
  LLegacyConnectionFile: string;
  LProcess: THandle;
  LProcessId: Cardinal;
begin
  if ParamCount <> 5 then
    raise EArgumentException.Create(
      'Invalid cleanup watchdog arguments.'
    );
  if not TryStrToUInt(ParamStr(2), LProcessId) or
    (LProcessId = 0) then
    raise EArgumentException.Create(
      'Invalid cleanup watchdog process identifier.'
    );
  LInstanceConnectionFile := TPath.GetFullPath(ParamStr(3));
  LLegacyConnectionFile := TPath.GetFullPath(ParamStr(4));
  LEndpoint := ParamStr(5);
  LProcess := OpenProcess(
    CProcessSynchronize,
    False,
    LProcessId
  );
  if LProcess <> 0 then
  begin
    try
      WaitForSingleObject(LProcess, INFINITE);
    finally
      CloseHandle(LProcess);
    end;
  end;
  DeleteOwnedConnection(
    LInstanceConnectionFile,
    LEndpoint,
    LProcessId
  );
  DeleteOwnedConnection(
    LLegacyConnectionFile,
    LEndpoint,
    LProcessId
  );
end;

function ResolveDefaultConnectionFile: string;
var
  LCandidate: string;
  LConnectionDirectory: string;
  LConnectionFile: string;
  LEndpoint: string;
  LInstanceFiles: TArray<string>;
begin
  LConnectionDirectory := TPath.Combine(
    TPath.GetHomePath,
    'RadIA'
  );
  LConnectionFile := TPath.Combine(
    LConnectionDirectory,
    'mcp.json'
  );
  if TryLoadConnection(LConnectionFile, LEndpoint) then
    Exit(LConnectionFile);

  Result := '';
  if not TDirectory.Exists(LConnectionDirectory) then
    Exit;
  LInstanceFiles := TDirectory.GetFiles(
    LConnectionDirectory,
    'mcp.*.json'
  );
  for LCandidate in LInstanceFiles do
  begin
    if not TryLoadConnection(LCandidate, LEndpoint) then
      Continue;
    if Result <> '' then
      raise EInOutError.Create(
        'Multiple RadIA IDE instances are active. Pass an instance ' +
        'connection file path to the bridge.'
      );
    Result := LCandidate;
  end;
end;

function GetConnectionFile: string;
begin
  if ParamCount > 0 then
    Result := TPath.GetFullPath(ParamStr(1))
  else
    Result := ResolveDefaultConnectionFile;
end;

function LoadEndpoint(const AConnectionFile: string): string;
var
  LJson: TJSONObject;
begin
  Result := '';
  if not TFile.Exists(AConnectionFile) then
    Exit;

  LJson := TJSONObject.ParseJSONValue(
    TFile.ReadAllText(AConnectionFile, TEncoding.UTF8)
  ) as TJSONObject;
  if not Assigned(LJson) then
    Exit;
  try
    Result := LJson.GetValue<string>('endpoint', '');
  finally
    LJson.Free;
  end;
end;

function ConnectPipe(const AEndpoint: string): THandle;
var
  LMode: DWORD;
begin
  Result := INVALID_HANDLE_VALUE;
  if not WaitNamedPipe(PChar(AEndpoint), 5000) then
    Exit;

  Result := CreateFile(
    PChar(AEndpoint),
    GENERIC_READ or GENERIC_WRITE,
    0,
    nil,
    OPEN_EXISTING,
    0,
    0
  );
  if Result = INVALID_HANDLE_VALUE then
    Exit;

  LMode := PIPE_READMODE_MESSAGE or PIPE_NOWAIT;
  if not SetNamedPipeHandleState(Result, LMode, nil, nil) then
  begin
    CloseHandle(Result);
    Result := INVALID_HANDLE_VALUE;
  end;
end;

function ReadPipeMessage(
  const APipe: THandle;
  out AMessage: string
): Boolean;
var
  LAvailableBytes: DWORD;
  LBuffer: TBytes;
  LBytesRead: DWORD;
  LDeadline: UInt64;
begin
  AMessage := '';
  SetLength(LBuffer, CMaxPayloadBytes);
  LDeadline := GetTickCount64 + CPipeResponseTimeoutMs;
  LBytesRead := 0;
  repeat
    LAvailableBytes := 0;
    if not PeekNamedPipe(
      APipe,
      nil,
      0,
      nil,
      @LAvailableBytes,
      nil
    ) then
      Exit(False);
    if LAvailableBytes = 0 then
    begin
      Sleep(10);
      Continue;
    end;

    LBytesRead := 0;
    Result := ReadFile(
      APipe,
      LBuffer[0],
      Length(LBuffer),
      LBytesRead,
      nil
    );
    if not Result then
      Exit(False);
    if LBytesRead > 0 then
      Break;
  until GetTickCount64 >= LDeadline;
  if LBytesRead = 0 then
    Exit(False);

  SetLength(LBuffer, LBytesRead);
  AMessage := TEncoding.UTF8.GetString(LBuffer);
  Result := True;
end;

function WritePipeMessage(
  const APipe: THandle;
  const AMessage: string
): Boolean;
var
  LBytes: TBytes;
  LBytesWritten: DWORD;
begin
  LBytes := TEncoding.UTF8.GetBytes(AMessage);
  if (Length(LBytes) = 0) or
    (Length(LBytes) > CMaxPayloadBytes) then
    Exit(False);

  LBytesWritten := 0;
  Result := WriteFile(
    APipe,
    LBytes[0],
    Length(LBytes),
    LBytesWritten,
    nil
  ) and (LBytesWritten = DWORD(Length(LBytes)));
end;

function MessageExpectsResponse(const AMessage: string): Boolean;
var
  LId: TJSONValue;
  LJson: TJSONObject;
begin
  Result := True;
  LJson := TJSONObject.ParseJSONValue(AMessage) as TJSONObject;
  if not Assigned(LJson) then
    Exit;
  try
    LId := LJson.GetValue('id');
    Result := Assigned(LId) and not (LId is TJSONNull);
  finally
    LJson.Free;
  end;
end;

procedure WriteHandleLine(
  const AHandle: THandle;
  const AMessage: string
);
var
  LBytes: TBytes;
  LBytesWritten: DWORD;
begin
  LBytes := TEncoding.UTF8.GetBytes(AMessage + sLineBreak);
  LBytesWritten := 0;
  if not WriteFile(
    AHandle,
    LBytes[0],
    Length(LBytes),
    LBytesWritten,
    nil
  ) or (LBytesWritten <> DWORD(Length(LBytes))) then
    raise EWriteError.Create('Failed to write an MCP stream message.');
end;

procedure RunBridge(
  const APipe: THandle;
  const AInput: TStreamReader;
  const AOutput: THandle
);
var
  LLine: string;
  LResponse: string;
begin
  while not AInput.EndOfStream do
  begin
    LLine := AInput.ReadLine;
    if Trim(LLine) = '' then
      Continue;
    if not WritePipeMessage(APipe, LLine) then
      raise EWriteError.Create('Failed to write to the RadIA MCP pipe.');
    if not MessageExpectsResponse(LLine) then
      Continue;
    if not ReadPipeMessage(APipe, LResponse) then
      raise EReadError.Create('Failed to read from the RadIA MCP pipe.');
    WriteHandleLine(AOutput, LResponse);
  end;
end;

var
  LConnectionFile: string;
  LEndpoint: string;
  LInputReader: TStreamReader;
  LInputStream: THandleStream;
  LPipe: THandle;
begin
  if SameText(ParamStr(1), '--watch') then
  begin
    try
      RunCleanupWatchdog;
    except
      on E: Exception do
      begin
        WriteHandleLine(
          GetStdHandle(STD_ERROR_HANDLE),
          E.Message
        );
        ExitCode := 1;
      end;
    end;
    Exit;
  end;

  LInputStream := THandleStream.Create(
    GetStdHandle(STD_INPUT_HANDLE)
  );
  try
    LInputReader := TStreamReader.Create(
      LInputStream,
      TEncoding.UTF8,
      False,
      4096
    );
    try
      try
        LConnectionFile := GetConnectionFile;
        LEndpoint := LoadEndpoint(LConnectionFile);
        if LEndpoint = '' then
          raise EFileNotFoundException.Create(
            'RadIA MCP connection information was not found.'
          );

        LPipe := ConnectPipe(LEndpoint);
        if LPipe = INVALID_HANDLE_VALUE then
          raise EInOutError.Create(
            'The RadIA MCP named pipe is unavailable.'
          );
        try
          RunBridge(
            LPipe,
            LInputReader,
            GetStdHandle(STD_OUTPUT_HANDLE)
          );
        finally
          CloseHandle(LPipe);
        end;
      except
        on E: Exception do
        begin
          WriteHandleLine(
            GetStdHandle(STD_ERROR_HANDLE),
            E.Message
          );
          ExitCode := 1;
        end;
      end;
    finally
      LInputReader.Free;
    end;
  finally
    LInputStream.Free;
  end;
end.
