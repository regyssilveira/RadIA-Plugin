unit RadIA.Core.ExternalMcpTransport;

interface

uses
  System.Generics.Collections,
  System.SyncObjs,
  RadIA.Core.CliProcess,
  RadIA.Core.ExternalMcp;

type
  IRadIAExternalMcpTransport = interface
    ['{D0CDB6E7-FDBA-48B2-8C38-F1692368CA14}']
    function GetLastError: string;
    function GetRunning: Boolean;
    function Receive(
      const ATimeoutMs: Cardinal;
      out AMessage: string
    ): Boolean;
    function Send(const AMessage: string): Boolean;
    function Start(
      const AConfig: TRadIAExternalMcpServerConfig;
      out AError: string
    ): Boolean;
    procedure Stop;
    property LastError: string read GetLastError;
    property Running: Boolean read GetRunning;
  end;

  TRadIAExternalMcpStdioTransport = class(
    TInterfacedObject,
    IRadIAExternalMcpTransport
  )
  private
    FBuffer: string;
    FLastError: string;
    FLock: TObject;
    FMessageEvent: TEvent;
    FMessages: TQueue<string>;
    FRunning: Boolean;
    FSession: IRadIACliProcessSession;
    FStdErr: string;
    FStoppedEvent: TEvent;
    procedure HandleComplete(const AResult: TRadIACliProcessResult);
    procedure HandleError(const AChunk: string);
    procedure HandleOutput(const AChunk: string);
    procedure QueueCompleteLines;
    procedure SetFailure(const AMessage: string);
  public
    constructor Create;
    destructor Destroy; override;
    function GetLastError: string;
    function GetRunning: Boolean;
    function Receive(
      const ATimeoutMs: Cardinal;
      out AMessage: string
    ): Boolean;
    function Send(const AMessage: string): Boolean;
    function Start(
      const AConfig: TRadIAExternalMcpServerConfig;
      out AError: string
    ): Boolean;
    procedure Stop;
  end;

implementation

uses
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.AgentExecutors;

const
  CMaximumMessageCharacters = 8 * 1024 * 1024;
  CProcessStartTimeoutMs = 5000;
  CProcessStopTimeoutMs = 5000;
  CSendRetryIntervalMs = 10;

{ TRadIAExternalMcpStdioTransport }

constructor TRadIAExternalMcpStdioTransport.Create;
begin
  inherited Create;
  FLock := TObject.Create;
  FMessages := TQueue<string>.Create;
  FMessageEvent := TEvent.Create(nil, False, False, '');
  FStoppedEvent := TEvent.Create(nil, True, True, '');
end;

destructor TRadIAExternalMcpStdioTransport.Destroy;
begin
  Stop;
  FStoppedEvent.Free;
  FMessageEvent.Free;
  FMessages.Free;
  FLock.Free;
  inherited Destroy;
end;

function TRadIAExternalMcpStdioTransport.GetLastError: string;
begin
  TMonitor.Enter(FLock);
  try
    Result := FLastError;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpStdioTransport.GetRunning: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FRunning;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAExternalMcpStdioTransport.HandleComplete(
  const AResult: TRadIACliProcessResult
);
begin
  TMonitor.Enter(FLock);
  try
    FRunning := False;
    if (FLastError = '') and not AResult.Cancelled and
       not AResult.TimedOut and (AResult.ExitCode <> 0) then
    begin
      FLastError := 'External MCP server exited with code ' +
        UIntToStr(AResult.ExitCode) + '.';
      if FStdErr <> '' then
        FLastError := FLastError + ' ' + FStdErr;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  FStoppedEvent.SetEvent;
  FMessageEvent.SetEvent;
end;

procedure TRadIAExternalMcpStdioTransport.HandleError(
  const AChunk: string
);
begin
  if Trim(AChunk) = '' then
    Exit;
  TMonitor.Enter(FLock);
  try
    if Length(FStdErr) < 4096 then
      FStdErr := Copy(FStdErr + Trim(AChunk), 1, 4096);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAExternalMcpStdioTransport.HandleOutput(
  const AChunk: string
);
begin
  if AChunk = '' then
    Exit;
  TMonitor.Enter(FLock);
  try
    if Length(FBuffer) + Length(AChunk) > CMaximumMessageCharacters then
    begin
      FLastError := 'External MCP output exceeded the safe message limit.';
      FBuffer := '';
      if Assigned(FSession) then
        FSession.Cancel;
      Exit;
    end;
    FBuffer := FBuffer + AChunk;
    QueueCompleteLines;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAExternalMcpStdioTransport.QueueCompleteLines;
var
  LLine: string;
  LNewLine: Integer;
begin
  LNewLine := Pos(#10, FBuffer);
  while LNewLine > 0 do
  begin
    LLine := Copy(FBuffer, 1, LNewLine - 1);
    Delete(FBuffer, 1, LNewLine);
    if LLine.EndsWith(#13) then
      Delete(LLine, Length(LLine), 1);
    if Trim(LLine) <> '' then
    begin
      FMessages.Enqueue(LLine);
      FMessageEvent.SetEvent;
    end;
    LNewLine := Pos(#10, FBuffer);
  end;
end;

function TRadIAExternalMcpStdioTransport.Receive(
  const ATimeoutMs: Cardinal;
  out AMessage: string
): Boolean;
var
  LStartedAt: UInt64;
  LWaitMs: Cardinal;
begin
  AMessage := '';
  LStartedAt := GetTickCount64;
  repeat
    TMonitor.Enter(FLock);
    try
      if FMessages.Count > 0 then
      begin
        AMessage := FMessages.Dequeue;
        Exit(True);
      end;
      if not FRunning then
        Exit(False);
    finally
      TMonitor.Exit(FLock);
    end;
    if GetTickCount64 - LStartedAt >= ATimeoutMs then
      Exit(False);
    LWaitMs := ATimeoutMs - Cardinal(GetTickCount64 - LStartedAt);
    FMessageEvent.WaitFor(LWaitMs);
  until False;
end;

function TRadIAExternalMcpStdioTransport.Send(
  const AMessage: string
): Boolean;
var
  LDeadline: UInt64;
  LSession: IRadIACliProcessSession;
begin
  Result := False;
  if (AMessage = '') or (Length(AMessage) > CMaximumMessageCharacters) or
     AMessage.Contains(#10) or AMessage.Contains(#13) then
  begin
    SetFailure('External MCP messages must be bounded single-line JSON.');
    Exit;
  end;
  LDeadline := GetTickCount64 + CProcessStartTimeoutMs;
  repeat
    TMonitor.Enter(FLock);
    try
      LSession := FSession;
      if not FRunning then
        Exit;
    finally
      TMonitor.Exit(FLock);
    end;
    if Assigned(LSession) and LSession.WriteInput(AMessage + sLineBreak) then
      Exit(True);
    Sleep(CSendRetryIntervalMs);
  until GetTickCount64 >= LDeadline;
  SetFailure('External MCP server standard input did not become available.');
end;

procedure TRadIAExternalMcpStdioTransport.SetFailure(
  const AMessage: string
);
begin
  TMonitor.Enter(FLock);
  try
    if FLastError = '' then
      FLastError := AMessage;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAExternalMcpStdioTransport.Start(
  const AConfig: TRadIAExternalMcpServerConfig;
  out AError: string
): Boolean;
var
  LInvocation: TRadIACliInvocation;
  LOnComplete: TProc<TRadIACliProcessResult>;
  LOnStdErr: TProc<string>;
  LOnStdOut: TProc<string>;
  LWorkingDirectory: string;
begin
  Result := False;
  AError := '';
  if not AConfig.Validate(AError) then
    Exit;
  if not AConfig.Enabled then
  begin
    AError := 'External MCP server is disabled.';
    Exit;
  end;
  Stop;
  LWorkingDirectory := AConfig.WorkingDirectory;
  if LWorkingDirectory = '' then
    LWorkingDirectory := GetCurrentDir;
  LInvocation := TRadIACliInvocation.Create(
    AConfig.Command,
    AConfig.Arguments,
    LWorkingDirectory,
    'jsonl'
  );
  LOnStdOut :=
    procedure(AChunk: string)
    begin
      HandleOutput(AChunk);
    end;
  LOnStdErr :=
    procedure(AChunk: string)
    begin
      HandleError(AChunk);
    end;
  LOnComplete :=
    procedure(AResult: TRadIACliProcessResult)
    begin
      HandleComplete(AResult);
    end;
  TMonitor.Enter(FLock);
  try
    FBuffer := '';
    FLastError := '';
    FMessages.Clear;
    FRunning := True;
    FStdErr := '';
    FStoppedEvent.ResetEvent;
    FSession := TRadIACliProcessRunner.StartInteractive(
      LInvocation,
      0,
      LOnStdOut,
      LOnStdErr,
      LOnComplete
    );
    Result := True;
  except
    on E: Exception do
    begin
      FRunning := False;
      FLastError := E.Message;
      AError := E.Message;
      FStoppedEvent.SetEvent;
    end;
  end;
  TMonitor.Exit(FLock);
end;

procedure TRadIAExternalMcpStdioTransport.Stop;
var
  LSession: IRadIACliProcessSession;
begin
  TMonitor.Enter(FLock);
  try
    LSession := FSession;
  finally
    TMonitor.Exit(FLock);
  end;
  if Assigned(LSession) and LSession.IsRunning then
  begin
    LSession.Cancel;
    FStoppedEvent.WaitFor(CProcessStopTimeoutMs);
  end;
  TMonitor.Enter(FLock);
  try
    FRunning := False;
    FSession := nil;
  finally
    TMonitor.Exit(FLock);
  end;
  FMessageEvent.SetEvent;
end;

end.
