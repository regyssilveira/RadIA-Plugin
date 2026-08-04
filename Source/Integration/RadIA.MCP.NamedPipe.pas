unit RadIA.MCP.NamedPipe;

interface

uses
  System.Classes,
  System.SyncObjs,
  RadIA.Core.Mcp,
  RadIA.Core.Workspace;

type
  TRadIANamedPipeMcpServer = class(
    TInterfacedObject,
    IRadIAMcpServer
  )
  private
    FConnectionFile: string;
    FEndpoint: string;
    FInstanceConnectionFile: string;
    FProtocol: IRadIAMcpProtocol;
    FRunning: Integer;
    FWorker: TThread;
    FWorkspace: IRadIAWorkspaceFacade;
    procedure DeleteConnectionFile;
    procedure DeleteStaleInstanceConnectionFiles;
    function IsProcessRunning(
      const AProcessId: Cardinal
    ): Boolean;
    procedure WriteConnectionFileAtomic(
      const AFileName: string;
      const AContent: string
    );
    procedure WriteConnectionFile;
    {$IFNDEF TESTS}
    procedure StartCleanupWatchdog;
    {$ENDIF}
  public
    constructor Create(
      const AProtocol: IRadIAMcpProtocol;
      const AWorkspace: IRadIAWorkspaceFacade;
      const AConnectionFile: string
    );
    destructor Destroy; override;
    procedure Start;
    procedure Stop;
    function GetEndpoint: string;
    function GetRunning: Boolean;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.Logger,
  RadIA.Core.Types;

const
  CMaxMcpPayloadBytes = 1024 * 1024;
  CPipePollIntervalMs = 50;
  CSecurityDescriptorRevision = 1;
  CSecurityDescriptor =
    'D:P(A;;GA;;;SY)(A;;GA;;;OW)';

type
  TRadIAMcpRequestWorker = class(TThread)
  private
    FMessage: string;
    FProtocol: IRadIAMcpProtocol;
    FResponse: string;
    FSession: TRadIAMcpSession;
  protected
    procedure Execute; override;
  public
    constructor Create(
      const AMessage: string;
      const AProtocol: IRadIAMcpProtocol;
      const ASession: TRadIAMcpSession
    );
    property Response: string read FResponse;
  end;

  TRadIANamedPipeWorker = class(TThread)
  private
    FConnectionFile: string;
    FEndpoint: string;
    FInstanceConnectionFile: string;
    FProtocol: IRadIAMcpProtocol;
    FReadyEvent: TEvent;
    FStartupError: DWORD;
    FWorkspace: IRadIAWorkspaceFacade;
    function CreatePipe: THandle;
    function CreateSecurityDescriptor(
      out ASecurityDescriptor: Pointer
    ): Boolean;
    function BuildBusyResponse(const AMessage: string): string;
    function BuildErrorResponse(
      const AMessage: string;
      const ACode: Integer;
      const AErrorMessage: string
    ): string;
    function GetMessageMethod(const AMessage: string): string;
    procedure HandleClient(const APipe: THandle);
    function RequestFinished(
      const AWorker: TRadIAMcpRequestWorker
    ): Boolean;
    function IsIDEReady: Boolean;
    function IsStopping: Boolean;
    function ReadMessage(
      const APipe: THandle;
      out AMessage: string
    ): Boolean;
    function WaitForClient(const APipe: THandle): Boolean;
    function WriteMessage(
      const APipe: THandle;
      const AMessage: string
    ): Boolean;
  protected
    procedure Execute; override;
  public
    constructor Create(
      const AEndpoint: string;
      const AProtocol: IRadIAMcpProtocol;
      const AWorkspace: IRadIAWorkspaceFacade;
      const AConnectionFile: string;
      const AInstanceConnectionFile: string
    );
    destructor Destroy; override;
    function WaitUntilReady(out AErrorCode: DWORD): Boolean;
  end;

function ConvertStringSecurityDescriptorToSecurityDescriptor(
  StringSecurityDescriptor: PWideChar;
  StringSDRevision: DWORD;
  SecurityDescriptor: PPointer;
  SecurityDescriptorSize: PULONG
): BOOL; stdcall; external 'advapi32.dll'
  name 'ConvertStringSecurityDescriptorToSecurityDescriptorW';

function FindReadyIDEWindow(
  const AWindow: HWND;
  const AData: LPARAM
): BOOL; stdcall;
var
  LClassName: array[0..63] of Char;
  LProcessId: DWORD;
begin
  Result := True;
  LProcessId := 0;
  GetWindowThreadProcessId(AWindow, @LProcessId);
  if (LProcessId <> GetCurrentProcessId) or
    not IsWindowVisible(AWindow) or
    (GetWindowTextLength(AWindow) = 0) then
    Exit;
  ZeroMemory(@LClassName, SizeOf(LClassName));
  GetClassName(AWindow, LClassName, Length(LClassName));
  if not SameText(string(LClassName), 'TAppBuilder') then
    Exit;
  PBoolean(AData)^ := True;
  Result := False;
end;

function ConnectionFileBelongsTo(
  const AFileName: string;
  const AEndpoint: string;
  const AProcessId: Cardinal
): Boolean;
var
  LJson: TJSONObject;
begin
  Result := False;
  if not TFile.Exists(AFileName) then
    Exit;
  try
    LJson := TJSONObject.ParseJSONValue(
      TFile.ReadAllText(AFileName, TEncoding.UTF8)
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

procedure DeleteConnectionFiles(
  const AConnectionFile: string;
  const AInstanceConnectionFile: string;
  const AEndpoint: string
);
var
  LProcessId: Cardinal;
begin
  LProcessId := GetCurrentProcessId;
  try
    if ConnectionFileBelongsTo(
      AInstanceConnectionFile,
      AEndpoint,
      LProcessId
    ) then
      TFile.Delete(AInstanceConnectionFile);
  except
    on E: Exception do
      OutputDebugString(
        PChar('RadIA MCP instance cleanup failed: ' + E.Message)
      );
  end;
  try
    if ConnectionFileBelongsTo(
      AConnectionFile,
      AEndpoint,
      LProcessId
    ) then
      TFile.Delete(AConnectionFile);
  except
    on E: Exception do
      OutputDebugString(
        PChar('RadIA MCP legacy cleanup failed: ' + E.Message)
      );
  end;
end;

{ TRadIAMcpRequestWorker }

constructor TRadIAMcpRequestWorker.Create(
  const AMessage: string;
  const AProtocol: IRadIAMcpProtocol;
  const ASession: TRadIAMcpSession
);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FMessage := AMessage;
  FProtocol := AProtocol;
  FSession := ASession;
end;

procedure TRadIAMcpRequestWorker.Execute;
begin
  try
    FResponse := FProtocol.HandleMessage(FMessage, FSession);
  except
    on Exception do
      FResponse :=
        '{"jsonrpc":"2.0","id":null,"error":{' +
        '"code":-32603,"message":"Internal server error."}}';
  end;
end;

{ TRadIANamedPipeWorker }

constructor TRadIANamedPipeWorker.Create(
  const AEndpoint: string;
  const AProtocol: IRadIAMcpProtocol;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AConnectionFile: string;
  const AInstanceConnectionFile: string
);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FConnectionFile := AConnectionFile;
  FEndpoint := AEndpoint;
  FInstanceConnectionFile := AInstanceConnectionFile;
  FProtocol := AProtocol;
  FReadyEvent := TEvent.Create(nil, True, False, '');
  FWorkspace := AWorkspace;
end;

destructor TRadIANamedPipeWorker.Destroy;
begin
  FReadyEvent.Free;
  inherited;
end;

function TRadIANamedPipeWorker.CreatePipe: THandle;
var
  LSecurityAttributes: TSecurityAttributes;
  LSecurityDescriptor: Pointer;
begin
  Result := INVALID_HANDLE_VALUE;
  if not CreateSecurityDescriptor(LSecurityDescriptor) then
    Exit;
  try
    ZeroMemory(
      @LSecurityAttributes,
      SizeOf(LSecurityAttributes)
    );
    LSecurityAttributes.nLength := SizeOf(LSecurityAttributes);
    LSecurityAttributes.lpSecurityDescriptor :=
      LSecurityDescriptor;
    LSecurityAttributes.bInheritHandle := False;

    Result := CreateNamedPipe(
      PChar(FEndpoint),
      PIPE_ACCESS_DUPLEX,
      PIPE_TYPE_MESSAGE or PIPE_READMODE_MESSAGE or PIPE_NOWAIT,
      1,
      CMaxMcpPayloadBytes,
      CMaxMcpPayloadBytes,
      0,
      @LSecurityAttributes
    );
  finally
    LocalFree(HLOCAL(LSecurityDescriptor));
  end;
end;

function TRadIANamedPipeWorker.CreateSecurityDescriptor(
  out ASecurityDescriptor: Pointer
): Boolean;
begin
  ASecurityDescriptor := nil;
  Result := ConvertStringSecurityDescriptorToSecurityDescriptor(
    PWideChar(CSecurityDescriptor),
    CSecurityDescriptorRevision,
    @ASecurityDescriptor,
    nil
  );
end;

function TRadIANamedPipeWorker.BuildBusyResponse(
  const AMessage: string
): string;
begin
  Result := BuildErrorResponse(
    AMessage,
    -32003,
    'MCP connection already has an active request.'
  );
end;

function TRadIANamedPipeWorker.BuildErrorResponse(
  const AMessage: string;
  const ACode: Integer;
  const AErrorMessage: string
): string;
var
  LError: TJSONObject;
  LId: TJSONValue;
  LParsed: TJSONValue;
  LResponse: TJSONObject;
begin
  LResponse := TJSONObject.Create;
  try
    LResponse.AddPair('jsonrpc', '2.0');
    LParsed := TJSONObject.ParseJSONValue(AMessage);
    try
      LId := nil;
      if LParsed is TJSONObject then
        LId := TJSONObject(LParsed).GetValue('id');
      if Assigned(LId) then
        LResponse.AddPair(
          'id',
          TJSONObject.ParseJSONValue(LId.ToJSON)
        )
      else
        LResponse.AddPair('id', TJSONNull.Create);
    finally
      LParsed.Free;
    end;
    LError := TJSONObject.Create;
    LError.AddPair('code', TJSONNumber.Create(ACode));
    LError.AddPair('message', AErrorMessage);
    LResponse.AddPair('error', LError);
    Result := LResponse.ToJSON;
  finally
    LResponse.Free;
  end;
end;

procedure TRadIANamedPipeWorker.Execute;
var
  LPipe: THandle;
begin
  try
    while not IsStopping do
    begin
      LPipe := CreatePipe;
      if LPipe = INVALID_HANDLE_VALUE then
      begin
        FStartupError := GetLastError;
        FReadyEvent.SetEvent;
        Exit;
      end;
      try
        FReadyEvent.SetEvent;
        if WaitForClient(LPipe) then
          HandleClient(LPipe);
        DisconnectNamedPipe(LPipe);
      finally
        CloseHandle(LPipe);
      end;
    end;
  finally
    DeleteConnectionFiles(
      FConnectionFile,
      FInstanceConnectionFile,
      FEndpoint
    );
  end;
end;

function TRadIANamedPipeWorker.WaitUntilReady(
  out AErrorCode: DWORD
): Boolean;
begin
  Result := FReadyEvent.WaitFor(5000) = wrSignaled;
  AErrorCode := FStartupError;
  Result := Result and (AErrorCode = ERROR_SUCCESS);
end;

procedure TRadIANamedPipeWorker.HandleClient(
  const APipe: THandle
);
var
  LMessage: string;
  LMethod: string;
  LProject: TRadIAProjectSnapshot;
  LRequestWorker: TRadIAMcpRequestWorker;
  LResponse: string;
  LSession: TRadIAMcpSession;
begin
  LSession := TRadIAMcpSession.Create(
    'named-pipe-' + TGUID.NewGuid.ToString,
    TGUID.NewGuid.ToString,
    ''
  );
  LRequestWorker := nil;
  LResponse := '';
  try
    while not IsStopping do
    begin
      if Assigned(LRequestWorker) and
        RequestFinished(LRequestWorker) then
      begin
        LResponse := LRequestWorker.Response;
        LRequestWorker.Free;
        LRequestWorker := nil;
        if (LResponse <> '') and
          not WriteMessage(APipe, LResponse) then
          Exit;
      end;

      if not ReadMessage(APipe, LMessage) then
      begin
        if GetLastError = ERROR_NO_DATA then
        begin
          Sleep(CPipePollIntervalMs);
          Continue;
        end;
        Exit;
      end;

      try
        LResponse := '';
        LMethod := GetMessageMethod(LMessage);
        if (LMethod = 'notifications/cancelled') or
          (LMethod = 'notifications/initialized') then
        begin
          LResponse := FProtocol.HandleMessage(LMessage, LSession);
          if (LResponse <> '') and
            not WriteMessage(APipe, LResponse) then
            Exit;
          Continue;
        end;
        if Assigned(LRequestWorker) then
        begin
          LSession.RecordMessageReceived;
          LSession.RecordRejectedRequest;
          if not WriteMessage(APipe, BuildBusyResponse(LMessage)) then
            Exit;
          Continue;
        end;
        if LMethod = 'tools/call' then
        begin
          if not IsIDEReady then
          begin
            LSession.RecordMessageReceived;
            LSession.RecordRejectedRequest;
            LResponse := BuildErrorResponse(
              LMessage,
              -32004,
              'The Delphi IDE is still starting. Retry shortly.'
            );
            if not WriteMessage(APipe, LResponse) then
              Exit;
            Continue;
          end;
          LProject := FWorkspace.GetActiveProject;
          LSession.ProjectId := LProject.FileName;
        end;
        LRequestWorker := TRadIAMcpRequestWorker.Create(
          LMessage,
          FProtocol,
          LSession
        );
        LRequestWorker.Start;
      except
        on Exception do
          LResponse :=
            '{"jsonrpc":"2.0","id":null,"error":{' +
            '"code":-32603,"message":"Internal server error."}}';
      end;

      if LResponse <> '' then
      begin
        if not WriteMessage(APipe, LResponse) then
          Exit;
        LResponse := '';
      end;
    end;
  finally
    if Assigned(LRequestWorker) then
    begin
      LSession.CancelAllRequests;
      LRequestWorker.Terminate;
      LRequestWorker.WaitFor;
      LRequestWorker.Free;
    end;
    LSession.Free;
  end;
end;

function TRadIANamedPipeWorker.GetMessageMethod(
  const AMessage: string
): string;
var
  LParsed: TJSONValue;
begin
  Result := '';
  LParsed := TJSONObject.ParseJSONValue(AMessage);
  try
    if LParsed is TJSONObject then
      Result := TJSONObject(LParsed).GetValue<string>('method', '');
  finally
    LParsed.Free;
  end;
end;

function TRadIANamedPipeWorker.ReadMessage(
  const APipe: THandle;
  out AMessage: string
): Boolean;
var
  LBuffer: TBytes;
  LBytesRead: DWORD;
begin
  AMessage := '';
  SetLength(LBuffer, CMaxMcpPayloadBytes);
  LBytesRead := 0;
  Result := ReadFile(
    APipe,
    LBuffer[0],
    Length(LBuffer),
    LBytesRead,
    nil
  );
  if not Result then
    Exit;
  if LBytesRead = 0 then
    Exit(False);

  SetLength(LBuffer, LBytesRead);
  AMessage := TEncoding.UTF8.GetString(LBuffer);
end;

function TRadIANamedPipeWorker.IsStopping: Boolean;
begin
  Result := Terminated or
    GIsShuttingDown;
end;

function TRadIANamedPipeWorker.IsIDEReady: Boolean;
begin
  {$IFDEF TESTS}
  Result := True;
  {$ELSE}
  Result := False;
  EnumWindows(
    @FindReadyIDEWindow,
    LPARAM(@Result)
  );
  {$ENDIF}
end;

function TRadIANamedPipeWorker.RequestFinished(
  const AWorker: TRadIAMcpRequestWorker
): Boolean;
begin
  Result := WaitForSingleObject(AWorker.Handle, 0) = WAIT_OBJECT_0;
end;

function TRadIANamedPipeWorker.WaitForClient(
  const APipe: THandle
): Boolean;
var
  LError: DWORD;
begin
  Result := False;
  while not IsStopping do
  begin
    if ConnectNamedPipe(APipe, nil) then
      Exit(True);
    LError := GetLastError;
    if LError = ERROR_PIPE_CONNECTED then
      Exit(True);
    if LError <> ERROR_PIPE_LISTENING then
      Exit(False);
    Sleep(CPipePollIntervalMs);
  end;
end;

function TRadIANamedPipeWorker.WriteMessage(
  const APipe: THandle;
  const AMessage: string
): Boolean;
var
  LBytes: TBytes;
  LBytesWritten: DWORD;
begin
  LBytes := TEncoding.UTF8.GetBytes(AMessage);
  if Length(LBytes) > CMaxMcpPayloadBytes then
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

{ TRadIANamedPipeMcpServer }

constructor TRadIANamedPipeMcpServer.Create(
  const AProtocol: IRadIAMcpProtocol;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AConnectionFile: string
);
begin
  inherited Create;
  if not Assigned(AProtocol) then
    raise EArgumentNilException.Create('AProtocol');
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if Trim(AConnectionFile) = '' then
    raise EArgumentException.Create(
      'AConnectionFile must not be empty.'
    );

  FProtocol := AProtocol;
  FWorkspace := AWorkspace;
  FConnectionFile := TPath.GetFullPath(AConnectionFile);
  FInstanceConnectionFile := TPath.Combine(
    TPath.GetDirectoryName(FConnectionFile),
    TPath.GetFileNameWithoutExtension(FConnectionFile) + '.' +
      UIntToStr(GetCurrentProcessId) +
      TPath.GetExtension(FConnectionFile)
  );
  FEndpoint := '\\.\pipe\RadIA-MCP-' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '');
end;

procedure TRadIANamedPipeMcpServer.DeleteConnectionFile;
begin
  DeleteConnectionFiles(
    FConnectionFile,
    FInstanceConnectionFile,
    FEndpoint
  );
end;

procedure TRadIANamedPipeMcpServer.DeleteStaleInstanceConnectionFiles;
var
  LDirectory: string;
  LFileName: string;
  LJson: TJSONObject;
  LProcessId: Cardinal;
begin
  LDirectory := TPath.GetDirectoryName(FConnectionFile);
  if not TDirectory.Exists(LDirectory) then
    Exit;
  for LFileName in TDirectory.GetFiles(
    LDirectory,
    'mcp.*.json'
  ) do
  begin
    try
      LJson := TJSONObject.ParseJSONValue(
        TFile.ReadAllText(LFileName, TEncoding.UTF8)
      ) as TJSONObject;
      if not Assigned(LJson) then
        Continue;
      try
        LProcessId := LJson.GetValue<Cardinal>('processId', 0);
        if (LProcessId > 0) and
          not IsProcessRunning(LProcessId) then
          TFile.Delete(LFileName);
      finally
        LJson.Free;
      end;
    except
      on Exception do
        Continue;
    end;
  end;
end;

function TRadIANamedPipeMcpServer.IsProcessRunning(
  const AProcessId: Cardinal
): Boolean;
const
  CProcessQueryLimitedInformation = $1000;
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

destructor TRadIANamedPipeMcpServer.Destroy;
begin
  Stop;
  inherited;
end;

function TRadIANamedPipeMcpServer.GetEndpoint: string;
begin
  Result := FEndpoint;
end;

function TRadIANamedPipeMcpServer.GetRunning: Boolean;
begin
  Result := TInterlocked.CompareExchange(FRunning, 0, 0) <> 0;
end;

procedure TRadIANamedPipeMcpServer.Start;
var
  LErrorCode: DWORD;
begin
  if GIsShuttingDown then
    Exit;
  if TInterlocked.CompareExchange(FRunning, 1, 0) <> 0 then
    Exit;

  try
    DeleteStaleInstanceConnectionFiles;
    FWorker := TRadIANamedPipeWorker.Create(
      FEndpoint,
      FProtocol,
      FWorkspace,
      FConnectionFile,
      FInstanceConnectionFile
    );
    FWorker.Start;
    if not TRadIANamedPipeWorker(FWorker).WaitUntilReady(
      LErrorCode
    ) then
      raise EOSError.CreateFmt(
        'Failed to start the RadIA MCP named pipe. Error: %d.',
        [LErrorCode]
      );
    WriteConnectionFile;
  except
    TInterlocked.Exchange(FRunning, 0);
    if Assigned(FWorker) then
      FWorker.Terminate;
    FWorker.Free;
    FWorker := nil;
    raise;
  end;
end;

{$IFNDEF TESTS}
procedure TRadIANamedPipeMcpServer.StartCleanupWatchdog;
var
  LBridgeFile: string;
  LCommandLine: string;
  LModuleBuffer: array[0..MAX_PATH] of Char;
  LModuleFile: string;
  LModuleHandle: HMODULE;
  LProcessInformation: TProcessInformation;
  LStartupInfo: TStartupInfo;
begin
  LModuleHandle := GetModuleHandle('RadIA.bpl');
  if LModuleHandle = 0 then
    LModuleHandle := HInstance;
  SetString(
    LModuleFile,
    LModuleBuffer,
    GetModuleFileName(
      LModuleHandle,
      LModuleBuffer,
      Length(LModuleBuffer)
    )
  );
  LBridgeFile := TPath.Combine(
    TPath.GetDirectoryName(LModuleFile),
    'RadIA.MCP.Bridge.exe'
  );
  if not TFile.Exists(LBridgeFile) then
    Exit;

  LCommandLine :=
    '"' + LBridgeFile + '" --watch ' +
    UIntToStr(GetCurrentProcessId) +
    ' "' + FInstanceConnectionFile + '"' +
    ' "' + FConnectionFile + '"' +
    ' "' + FEndpoint + '"';
  ZeroMemory(@LStartupInfo, SizeOf(LStartupInfo));
  LStartupInfo.cb := SizeOf(LStartupInfo);
  ZeroMemory(
    @LProcessInformation,
    SizeOf(LProcessInformation)
  );
  if not CreateProcess(
    nil,
    PChar(LCommandLine),
    nil,
    nil,
    False,
    CREATE_NO_WINDOW,
    nil,
    nil,
    LStartupInfo,
    LProcessInformation
  ) then
    Exit;
  CloseHandle(LProcessInformation.hThread);
  CloseHandle(LProcessInformation.hProcess);
end;
{$ENDIF}

procedure TRadIANamedPipeMcpServer.Stop;
begin
  TLogger.Log('MCP Stop entered', 'MCP');
  if TInterlocked.Exchange(FRunning, 0) = 0 then
    Exit;

  if Assigned(FWorker) then
  begin
    FWorker.Terminate;
    TLogger.Log('MCP Stop waiting for worker', 'MCP');
    FWorker.WaitFor;
    TLogger.Log('MCP Stop worker finished', 'MCP');
    FWorker.Free;
    FWorker := nil;
  end;
  DeleteConnectionFile;
  TLogger.Log('MCP Stop completed', 'MCP');
end;

procedure TRadIANamedPipeMcpServer.WriteConnectionFile;
var
  LDirectory: string;
  LJson: TJSONObject;
begin
  LDirectory := TPath.GetDirectoryName(FConnectionFile);
  if not TDirectory.Exists(LDirectory) then
    TDirectory.CreateDirectory(LDirectory);

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('transport', 'named-pipe');
    LJson.AddPair('endpoint', FEndpoint);
    LJson.AddPair('protocolVersion', '2025-06-18');
    LJson.AddPair(
      'processId',
      TJSONNumber.Create(GetCurrentProcessId)
    );
    LJson.AddPair(
      'instanceFile',
      FInstanceConnectionFile
    );
    WriteConnectionFileAtomic(
      FInstanceConnectionFile,
      LJson.ToJSON
    );
    WriteConnectionFileAtomic(
      FConnectionFile,
      LJson.ToJSON
    );
    {$IFNDEF TESTS}
    StartCleanupWatchdog;
    {$ENDIF}
  finally
    LJson.Free;
  end;
end;

procedure TRadIANamedPipeMcpServer.WriteConnectionFileAtomic(
  const AFileName: string;
  const AContent: string
);
const
  CMoveFileReplaceExisting = $00000001;
  CMoveFileWriteThrough = $00000008;
var
  LTemporaryFile: string;
begin
  LTemporaryFile := AFileName + '.' +
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '') +
    '.tmp';
  try
    TFile.WriteAllText(
      LTemporaryFile,
      AContent,
      TEncoding.UTF8
    );
    if not MoveFileEx(
      PChar(LTemporaryFile),
      PChar(AFileName),
      CMoveFileReplaceExisting or CMoveFileWriteThrough
    ) then
      RaiseLastOSError;
  finally
    if TFile.Exists(LTemporaryFile) then
      TFile.Delete(LTemporaryFile);
  end;
end;

end.
