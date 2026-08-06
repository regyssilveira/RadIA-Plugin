unit RadIA.Core.CliProcess;

interface

uses
  System.SysUtils,
  RadIA.Core.AgentExecutors;

type
  TRadIACliProcessResult = record
  private
    FExitCode: Cardinal;
    FStdOut: string;
    FStdErr: string;
    FCancelled: Boolean;
    FTimedOut: Boolean;
  public
    constructor Create(
      const AExitCode: Cardinal;
      const AStdOut: string;
      const AStdErr: string;
      const ACancelled: Boolean;
      const ATimedOut: Boolean
    );
    function Succeeded: Boolean;
    property ExitCode: Cardinal read FExitCode;
    property StdOut: string read FStdOut;
    property StdErr: string read FStdErr;
    property Cancelled: Boolean read FCancelled;
    property TimedOut: Boolean read FTimedOut;
  end;

  IRadIACliProcessSession = interface
    ['{DBDE9871-A66E-49E4-9D70-FD63863B721C}']
    procedure Cancel;
    function IsPseudoTerminal: Boolean;
    function IsRunning: Boolean;
    function Resize(
      const AColumns: SmallInt;
      const ARows: SmallInt
    ): Boolean;
    function WriteInput(const AText: string): Boolean;
  end;

  TRadIACliProcessRunner = class
  public
    class function Start(
      const AInvocation: TRadIACliInvocation;
      const ATimeoutMs: Cardinal;
      const AOnStdOut: TProc<string>;
      const AOnStdErr: TProc<string>;
      const AOnComplete: TProc<TRadIACliProcessResult>
    ): IRadIACliProcessSession; static;
    class function StartWithInput(
      const AInvocation: TRadIACliInvocation;
      const AStdInput: string;
      const ATimeoutMs: Cardinal;
      const AOnStdOut: TProc<string>;
      const AOnStdErr: TProc<string>;
      const AOnComplete: TProc<TRadIACliProcessResult>
    ): IRadIACliProcessSession; static;
    class function StartInteractive(
      const AInvocation: TRadIACliInvocation;
      const ATimeoutMs: Cardinal;
      const AOnStdOut: TProc<string>;
      const AOnStdErr: TProc<string>;
      const AOnComplete: TProc<TRadIACliProcessResult>
    ): IRadIACliProcessSession; static;
  end;

implementation

uses
  System.Classes,
  System.Math,
  System.SyncObjs,
  Winapi.Windows,
  RadIA.Core.Logger,
  RadIA.Core.Types;

const
  CReadBufferSize = 16384;
  CMaxCapturedCharacters = 8 * 1024 * 1024;
  CProcessPollIntervalMs = 10;
  CCancelledExitCode = $FFFFFFFF;

type
  TRadIACliProcessSession = class(
    TInterfacedObject,
    IRadIACliProcessSession
  )
  private
    FInvocation: TRadIACliInvocation;
    FStdInput: string;
    FTimeoutMs: Cardinal;
    FOnStdOut: TProc<string>;
    FOnStdErr: TProc<string>;
    FOnComplete: TProc<TRadIACliProcessResult>;
    FLock: TObject;
    FJobHandle: THandle;
    FStdInWriteHandle: THandle;
    FInteractive: Boolean;
    FRunning: Boolean;
    FCancelRequested: Boolean;
    procedure AppendCaptured(
      var ATarget: string;
      const AChunk: string
    );
    procedure CloseHandleIfAssigned(var AHandle: THandle);
    function ConfigureJob(const AProcessHandle: THandle): Boolean;
    function CancellationRequested: Boolean;
    procedure DrainPipe(
      const APipe: THandle;
      var ATarget: string;
      const ACallback: TProc<string>
    );
    procedure ExecuteWorker;
    procedure Finish(
      const AResult: TRadIACliProcessResult
    );
    function HasTimedOut(const AStartedAt: UInt64): Boolean;
    procedure ActivateStandardInput(var AHandle: THandle);
    procedure PrepareStandardInput(
      var AReadHandle: THandle;
      var AWriteHandle: THandle;
      const ASecurity: TSecurityAttributes
    );
    function ResolveStandardInputHandle(
      const AReadHandle: THandle
    ): THandle;
    procedure StartWorker;
    procedure TerminateProcessTree;
    procedure WriteStandardInput(const AHandle: THandle);
  public
    constructor Create(
      const AInvocation: TRadIACliInvocation;
      const AStdInput: string;
      const AInteractive: Boolean;
      const ATimeoutMs: Cardinal;
      const AOnStdOut: TProc<string>;
      const AOnStdErr: TProc<string>;
      const AOnComplete: TProc<TRadIACliProcessResult>
    );
    destructor Destroy; override;
    procedure Cancel;
    function IsPseudoTerminal: Boolean;
    function IsRunning: Boolean;
    function Resize(
      const AColumns: SmallInt;
      const ARows: SmallInt
    ): Boolean;
    function WriteInput(const AText: string): Boolean;
  end;

{ TRadIACliProcessResult }

constructor TRadIACliProcessResult.Create(
  const AExitCode: Cardinal;
  const AStdOut: string;
  const AStdErr: string;
  const ACancelled: Boolean;
  const ATimedOut: Boolean
);
begin
  FExitCode := AExitCode;
  FStdOut := AStdOut;
  FStdErr := AStdErr;
  FCancelled := ACancelled;
  FTimedOut := ATimedOut;
end;

function TRadIACliProcessResult.Succeeded: Boolean;
begin
  Result := (ExitCode = 0) and not Cancelled and not TimedOut;
end;

{ TRadIACliProcessSession }

constructor TRadIACliProcessSession.Create(
  const AInvocation: TRadIACliInvocation;
  const AStdInput: string;
  const AInteractive: Boolean;
  const ATimeoutMs: Cardinal;
  const AOnStdOut: TProc<string>;
  const AOnStdErr: TProc<string>;
  const AOnComplete: TProc<TRadIACliProcessResult>
);
begin
  inherited Create;
  FInvocation := AInvocation;
  FStdInput := AStdInput;
  FInteractive := AInteractive;
  FTimeoutMs := ATimeoutMs;
  FOnStdOut := AOnStdOut;
  FOnStdErr := AOnStdErr;
  FOnComplete := AOnComplete;
  FLock := TObject.Create;
  FJobHandle := 0;
  FStdInWriteHandle := 0;
  FRunning := False;
  FCancelRequested := False;
end;

destructor TRadIACliProcessSession.Destroy;
begin
  TerminateProcessTree;
  FLock.Free;
  inherited Destroy;
end;

procedure TRadIACliProcessSession.AppendCaptured(
  var ATarget: string;
  const AChunk: string
);
var
  LRemaining: Integer;
begin
  LRemaining := CMaxCapturedCharacters - Length(ATarget);
  if LRemaining <= 0 then
    Exit;
  ATarget := ATarget + AChunk.Substring(0, Min(Length(AChunk), LRemaining));
end;

procedure TRadIACliProcessSession.ActivateStandardInput(
  var AHandle: THandle
);
begin
  WriteStandardInput(AHandle);
  if not FInteractive then
  begin
    CloseHandleIfAssigned(AHandle);
    Exit;
  end;
  TMonitor.Enter(FLock);
  try
    FStdInWriteHandle := AHandle;
    AHandle := 0;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIACliProcessSession.Cancel;
begin
  TMonitor.Enter(FLock);
  try
    FCancelRequested := True;
    TerminateProcessTree;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIACliProcessSession.CloseHandleIfAssigned(
  var AHandle: THandle
);
begin
  if AHandle <> 0 then
  begin
    CloseHandle(AHandle);
    AHandle := 0;
  end;
end;

function TRadIACliProcessSession.CancellationRequested: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FCancelRequested;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIACliProcessSession.ConfigureJob(
  const AProcessHandle: THandle
): Boolean;
var
  LJobInfo: TJobObjectExtendedLimitInformation;
begin
  FJobHandle := CreateJobObject(nil, nil);
  if FJobHandle = 0 then
    Exit(False);
  ZeroMemory(@LJobInfo, SizeOf(LJobInfo));
  LJobInfo.BasicLimitInformation.LimitFlags :=
    JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;
  Result := SetInformationJobObject(
    FJobHandle,
    JobObjectExtendedLimitInformation,
    @LJobInfo,
    SizeOf(LJobInfo)
  ) and AssignProcessToJobObject(FJobHandle, AProcessHandle);
end;

procedure TRadIACliProcessSession.DrainPipe(
  const APipe: THandle;
  var ATarget: string;
  const ACallback: TProc<string>
);
var
  LAvailable: Cardinal;
  LBuffer: TBytes;
  LBytesRead: Cardinal;
  LChunk: string;
begin
  if APipe = 0 then
    Exit;
  repeat
    LAvailable := 0;
    if not PeekNamedPipe(APipe, nil, 0, nil, @LAvailable, nil) or
      (LAvailable = 0) then
      Exit;
    SetLength(LBuffer, Min(LAvailable, Cardinal(CReadBufferSize)));
    LBytesRead := 0;
    if not ReadFile(
      APipe,
      LBuffer[0],
      Length(LBuffer),
      LBytesRead,
      nil
    ) or (LBytesRead = 0) then
      Exit;
    LChunk := TEncoding.UTF8.GetString(LBuffer, 0, LBytesRead);
    AppendCaptured(ATarget, LChunk);
    if Assigned(ACallback) then
      try
        ACallback(LChunk);
      except
        on E: Exception do
          TLogger.Log(
            'CLI stdout callback failed: ' + E.Message,
            'CliProcess'
          );
      end;
  until LAvailable <= LBytesRead;
end;

procedure TRadIACliProcessSession.ExecuteWorker;
var
  LCancelled: Boolean;
  LCommandLine: string;
  LCreated: Boolean;
  LExitCode: Cardinal;
  LJobConfigured: Boolean;
  LProcessInfo: TProcessInformation;
  LSecurity: TSecurityAttributes;
  LStartedAt: UInt64;
  LStartupInfo: TStartupInfo;
  LStdErr: string;
  LStdErrRead: THandle;
  LStdErrWrite: THandle;
  LStdInRead: THandle;
  LStdInWrite: THandle;
  LStdOut: string;
  LStdOutRead: THandle;
  LStdOutWrite: THandle;
  LTimedOut: Boolean;
  LWaitResult: Cardinal;
begin
  LStdOutRead := 0;
  LStdOutWrite := 0;
  LStdErrRead := 0;
  LStdErrWrite := 0;
  LStdInRead := 0;
  LStdInWrite := 0;
  ZeroMemory(@LProcessInfo, SizeOf(LProcessInfo));
  ZeroMemory(@LStartupInfo, SizeOf(LStartupInfo));
  LStartupInfo.cb := SizeOf(LStartupInfo);
  ZeroMemory(@LSecurity, SizeOf(LSecurity));
  LSecurity.nLength := SizeOf(LSecurity);
  LSecurity.bInheritHandle := True;
  LExitCode := CCancelledExitCode;
  LCancelled := False;
  LTimedOut := False;
  try
    if not CreatePipe(LStdOutRead, LStdOutWrite, @LSecurity, 0) or
      not CreatePipe(LStdErrRead, LStdErrWrite, @LSecurity, 0) then
      RaiseLastOSError;
    PrepareStandardInput(LStdInRead, LStdInWrite, LSecurity);
    SetHandleInformation(LStdOutRead, HANDLE_FLAG_INHERIT, 0);
    SetHandleInformation(LStdErrRead, HANDLE_FLAG_INHERIT, 0);
    LStartupInfo.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    LStartupInfo.wShowWindow := SW_HIDE;
    LStartupInfo.hStdOutput := LStdOutWrite;
    LStartupInfo.hStdError := LStdErrWrite;
    LStartupInfo.hStdInput := ResolveStandardInputHandle(LStdInRead);
    LCommandLine := FInvocation.ToCommandLine;
    UniqueString(LCommandLine);
    LCreated := CreateProcess(
      nil,
      PChar(LCommandLine),
      nil,
      nil,
      True,
      CREATE_NO_WINDOW or CREATE_SUSPENDED,
      nil,
      PChar(FInvocation.WorkingDirectory),
      LStartupInfo,
      LProcessInfo
    );
    if not LCreated then
      RaiseLastOSError;
    CloseHandleIfAssigned(LStdOutWrite);
    CloseHandleIfAssigned(LStdErrWrite);
    CloseHandleIfAssigned(LStdInRead);
    TMonitor.Enter(FLock);
    try
      LJobConfigured := ConfigureJob(LProcessInfo.hProcess);
      if not LJobConfigured then
        RaiseLastOSError;
      if FCancelRequested then
        TerminateProcessTree;
    finally
      TMonitor.Exit(FLock);
    end;
    ResumeThread(LProcessInfo.hThread);
    ActivateStandardInput(LStdInWrite);
    LStartedAt := GetTickCount64;
    repeat
      DrainPipe(LStdOutRead, LStdOut, FOnStdOut);
      DrainPipe(LStdErrRead, LStdErr, FOnStdErr);
      LWaitResult := WaitForSingleObject(
        LProcessInfo.hProcess,
        CProcessPollIntervalMs
      );
      LCancelled := CancellationRequested;
      LTimedOut := HasTimedOut(LStartedAt);
      if LCancelled or LTimedOut then
        TerminateProcessTree;
    until (LWaitResult = WAIT_OBJECT_0) or LCancelled or LTimedOut;
    WaitForSingleObject(LProcessInfo.hProcess, 5000);
    DrainPipe(LStdOutRead, LStdOut, FOnStdOut);
    DrainPipe(LStdErrRead, LStdErr, FOnStdErr);
    if not GetExitCodeProcess(LProcessInfo.hProcess, LExitCode) then
      LExitCode := CCancelledExitCode;
  except
    on E: Exception do
      AppendCaptured(LStdErr, E.ClassName + ': ' + E.Message);
  end;
  CloseHandleIfAssigned(LProcessInfo.hThread);
  CloseHandleIfAssigned(LProcessInfo.hProcess);
  CloseHandleIfAssigned(LStdOutWrite);
  CloseHandleIfAssigned(LStdErrWrite);
  CloseHandleIfAssigned(LStdOutRead);
  CloseHandleIfAssigned(LStdErrRead);
  CloseHandleIfAssigned(LStdInRead);
  CloseHandleIfAssigned(LStdInWrite);
  TMonitor.Enter(FLock);
  try
    CloseHandleIfAssigned(FStdInWriteHandle);
    CloseHandleIfAssigned(FJobHandle);
  finally
    TMonitor.Exit(FLock);
  end;
  Finish(
    TRadIACliProcessResult.Create(
      LExitCode,
      LStdOut,
      LStdErr,
      LCancelled,
      LTimedOut
    )
  );
  TInterlocked.Decrement(GActiveThreadCount);
  _Release;
end;

procedure TRadIACliProcessSession.Finish(
  const AResult: TRadIACliProcessResult
);
begin
  TMonitor.Enter(FLock);
  try
    FRunning := False;
  finally
    TMonitor.Exit(FLock);
  end;
  if Assigned(FOnComplete) then
    try
      FOnComplete(AResult);
    except
      on E: Exception do
        TLogger.Log(
          'CLI completion callback failed: ' + E.Message,
          'CliProcess'
        );
    end;
end;

function TRadIACliProcessSession.HasTimedOut(
  const AStartedAt: UInt64
): Boolean;
begin
  Result := (FTimeoutMs > 0) and
    ((GetTickCount64 - AStartedAt) >= FTimeoutMs);
end;

function TRadIACliProcessSession.IsRunning: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FRunning;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIACliProcessSession.IsPseudoTerminal: Boolean;
begin
  Result := False;
end;

function TRadIACliProcessSession.Resize(
  const AColumns: SmallInt;
  const ARows: SmallInt
): Boolean;
begin
  Result := False;
end;

procedure TRadIACliProcessSession.PrepareStandardInput(
  var AReadHandle: THandle;
  var AWriteHandle: THandle;
  const ASecurity: TSecurityAttributes
);
var
  LSecurity: TSecurityAttributes;
begin
  if (FStdInput = '') and not FInteractive then
    Exit;
  LSecurity := ASecurity;
  if not CreatePipe(AReadHandle, AWriteHandle, @LSecurity, 0) then
    RaiseLastOSError;
  if not SetHandleInformation(
    AWriteHandle,
    HANDLE_FLAG_INHERIT,
    0
  ) then
    RaiseLastOSError;
end;

function TRadIACliProcessSession.ResolveStandardInputHandle(
  const AReadHandle: THandle
): THandle;
begin
  if AReadHandle <> 0 then
    Result := AReadHandle
  else
    Result := GetStdHandle(STD_INPUT_HANDLE);
end;

procedure TRadIACliProcessSession.StartWorker;
var
  LThread: TThread;
begin
  TMonitor.Enter(FLock);
  try
    FRunning := True;
  finally
    TMonitor.Exit(FLock);
  end;
  _AddRef;
  TInterlocked.Increment(GActiveThreadCount);
  try
    LThread := TThread.CreateAnonymousThread(ExecuteWorker);
    LThread.FreeOnTerminate := True;
    LThread.Start;
  except
    TInterlocked.Decrement(GActiveThreadCount);
    _Release;
    raise;
  end;
end;

procedure TRadIACliProcessSession.TerminateProcessTree;
begin
  if FJobHandle <> 0 then
    TerminateJobObject(FJobHandle, CCancelledExitCode);
end;

function TRadIACliProcessSession.WriteInput(
  const AText: string
): Boolean;
var
  LBytes: TBytes;
  LBytesWritten: Cardinal;
  LInputHandle: THandle;
  LOffset: Integer;
begin
  Result := False;
  if AText = '' then
    Exit;
  LBytes := TEncoding.UTF8.GetBytes(AText);
  LInputHandle := 0;
  TMonitor.Enter(FLock);
  try
    if not FRunning or (FStdInWriteHandle = 0) then
      Exit;
    if not DuplicateHandle(
      GetCurrentProcess,
      FStdInWriteHandle,
      GetCurrentProcess,
      @LInputHandle,
      0,
      False,
      DUPLICATE_SAME_ACCESS
    ) then
      Exit;
  finally
    TMonitor.Exit(FLock);
  end;
  try
    LOffset := 0;
    while LOffset < Length(LBytes) do
    begin
      LBytesWritten := 0;
      if not WriteFile(
        LInputHandle,
        LBytes[LOffset],
        Length(LBytes) - LOffset,
        LBytesWritten,
        nil
      ) or (LBytesWritten = 0) then
        Exit;
      Inc(LOffset, LBytesWritten);
    end;
    Result := True;
  finally
    CloseHandleIfAssigned(LInputHandle);
  end;
end;

procedure TRadIACliProcessSession.WriteStandardInput(
  const AHandle: THandle
);
var
  LBytes: TBytes;
  LBytesWritten: Cardinal;
  LOffset: Integer;
begin
  if (AHandle = 0) or (FStdInput = '') then
    Exit;
  LBytes := TEncoding.UTF8.GetBytes(FStdInput);
  LOffset := 0;
  while LOffset < Length(LBytes) do
  begin
    LBytesWritten := 0;
    if not WriteFile(
      AHandle,
      LBytes[LOffset],
      Length(LBytes) - LOffset,
      LBytesWritten,
      nil
    ) then
      RaiseLastOSError;
    if LBytesWritten = 0 then
      raise EWriteError.Create('Unable to write process standard input.');
    Inc(LOffset, LBytesWritten);
  end;
end;

{ TRadIACliProcessRunner }

class function TRadIACliProcessRunner.Start(
  const AInvocation: TRadIACliInvocation;
  const ATimeoutMs: Cardinal;
  const AOnStdOut: TProc<string>;
  const AOnStdErr: TProc<string>;
  const AOnComplete: TProc<TRadIACliProcessResult>
): IRadIACliProcessSession;
var
  LSession: TRadIACliProcessSession;
begin
  LSession := TRadIACliProcessSession.Create(
    AInvocation,
    '',
    False,
    ATimeoutMs,
    AOnStdOut,
    AOnStdErr,
    AOnComplete
  );
  Result := LSession;
  LSession.StartWorker;
end;

class function TRadIACliProcessRunner.StartInteractive(
  const AInvocation: TRadIACliInvocation;
  const ATimeoutMs: Cardinal;
  const AOnStdOut: TProc<string>;
  const AOnStdErr: TProc<string>;
  const AOnComplete: TProc<TRadIACliProcessResult>
): IRadIACliProcessSession;
var
  LSession: TRadIACliProcessSession;
begin
  LSession := TRadIACliProcessSession.Create(
    AInvocation,
    '',
    True,
    ATimeoutMs,
    AOnStdOut,
    AOnStdErr,
    AOnComplete
  );
  Result := LSession;
  LSession.StartWorker;
end;

class function TRadIACliProcessRunner.StartWithInput(
  const AInvocation: TRadIACliInvocation;
  const AStdInput: string;
  const ATimeoutMs: Cardinal;
  const AOnStdOut: TProc<string>;
  const AOnStdErr: TProc<string>;
  const AOnComplete: TProc<TRadIACliProcessResult>
): IRadIACliProcessSession;
var
  LSession: TRadIACliProcessSession;
begin
  LSession := TRadIACliProcessSession.Create(
    AInvocation,
    AStdInput,
    False,
    ATimeoutMs,
    AOnStdOut,
    AOnStdErr,
    AOnComplete
  );
  Result := LSession;
  LSession.StartWorker;
end;

end.
