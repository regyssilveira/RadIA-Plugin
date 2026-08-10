unit RadIA.Core.PseudoTerminal;

interface

uses
  System.SysUtils,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliProcess;

type
  TRadIAUtf8StreamDecoder = class
  private
    FPending: TBytes;
    function CompleteLength(const ABytes: TBytes): Integer;
  public
    function Decode(const ABytes: TBytes; const ACount: Integer): string;
    function Flush: string;
  end;

  TRadIAPseudoTerminalRunner = class
  public
    class function IsSupported: Boolean; static;
    class function Start(
      const AInvocation: TRadIACliInvocation;
      const AColumns: SmallInt;
      const ARows: SmallInt;
      const ATimeoutMs: Cardinal;
      const AOnOutput: TProc<string>;
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
  CCancelledExitCode = $FFFFFFFF;
  CExtendedStartupInfoPresent = $00080000;
  CMaxCapturedCharacters = 8 * 1024 * 1024;
  CProcessPollIntervalMs = 10;
  CProcThreadAttributePseudoConsole = $00020016;
  CReadBufferSize = 16384;

type
  TRadIACreatePseudoConsole = function(
    ASize: Cardinal;
    AInput: THandle;
    AOutput: THandle;
    AFlags: Cardinal;
    out APseudoConsole: THandle
  ): HRESULT; stdcall;

  TRadIAResizePseudoConsole = function(
    APseudoConsole: THandle;
    ASize: Cardinal
  ): HRESULT; stdcall;

  TRadIAClosePseudoConsole = procedure(
    APseudoConsole: THandle
  ); stdcall;

  TRadIAInitializeAttributeList = function(
    AAttributeList: Pointer;
    AAttributeCount: Cardinal;
    AFlags: Cardinal;
    var ASize: NativeUInt
  ): BOOL; stdcall;

  TRadIAUpdateAttribute = function(
    AAttributeList: Pointer;
    AFlags: Cardinal;
    AAttribute: NativeUInt;
    AValue: Pointer;
    AValueSize: NativeUInt;
    APreviousValue: Pointer;
    AReturnSize: Pointer
  ): BOOL; stdcall;

  TRadIADeleteAttributeList = procedure(
    AAttributeList: Pointer
  ); stdcall;

  TRadIACreateProcess = function(
    AApplicationName: PWideChar;
    ACommandLine: PWideChar;
    AProcessAttributes: Pointer;
    AThreadAttributes: Pointer;
    AInheritHandles: BOOL;
    ACreationFlags: Cardinal;
    AEnvironment: Pointer;
    ACurrentDirectory: PWideChar;
    AStartupInfo: Pointer;
    out AProcessInformation: TProcessInformation
  ): BOOL; stdcall;

  TRadIAStartupInfoEx = packed record
    StartupInfo: TStartupInfo;
    AttributeList: Pointer;
  end;

  TRadIAConPtyApi = record
    CreatePseudoConsole: TRadIACreatePseudoConsole;
    ResizePseudoConsole: TRadIAResizePseudoConsole;
    ClosePseudoConsole: TRadIAClosePseudoConsole;
    InitializeAttributeList: TRadIAInitializeAttributeList;
    UpdateAttribute: TRadIAUpdateAttribute;
    DeleteAttributeList: TRadIADeleteAttributeList;
    CreateProcess: TRadIACreateProcess;
    class function Load(out AApi: TRadIAConPtyApi): Boolean; static;
  end;

  TRadIAPseudoTerminalSession = class(
    TInterfacedObject,
    IRadIACliProcessSession
  )
  private
    FApi: TRadIAConPtyApi;
    FInvocation: TRadIACliInvocation;
    FColumns: SmallInt;
    FRows: SmallInt;
    FTimeoutMs: Cardinal;
    FOnOutput: TProc<string>;
    FOnComplete: TProc<TRadIACliProcessResult>;
    FLock: TObject;
    FInputWriteHandle: THandle;
    FJobHandle: THandle;
    FPseudoConsole: THandle;
    FRunning: Boolean;
    FCancelRequested: Boolean;
    FDecoder: TRadIAUtf8StreamDecoder;
    procedure AppendCaptured(
      var ATarget: string;
      const AChunk: string
    );
    procedure CloseHandleIfAssigned(var AHandle: THandle);
    function ConfigureJob(const AProcessHandle: THandle): Boolean;
    function CancellationRequested: Boolean;
    procedure DrainOutput(
      const AHandle: THandle;
      var AOutput: string
    );
    procedure DrainOutputUntilQuiet(
      const AHandle: THandle;
      var AOutput: string
    );
    procedure ExecuteWorker;
    procedure Finish(const AResult: TRadIACliProcessResult);
    function HasTimedOut(const AStartedAt: UInt64): Boolean;
    procedure PrepareStartupInfo(
      const APseudoConsole: THandle;
      const AInputHandle: THandle;
      const AOutputHandle: THandle;
      var AStartupInfo: TRadIAStartupInfoEx
    );
    procedure ReleaseRuntimeHandles(
      var AOutputReadHandle: THandle;
      var APseudoConsole: THandle
    );
    procedure StartWorker;
    procedure TerminateProcessTree;
  public
    constructor Create(
      const AApi: TRadIAConPtyApi;
      const AInvocation: TRadIACliInvocation;
      const AColumns: SmallInt;
      const ARows: SmallInt;
      const ATimeoutMs: Cardinal;
      const AOnOutput: TProc<string>;
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

function RadIACoord(
  const AColumns: SmallInt;
  const ARows: SmallInt
): Cardinal;
begin
  Result := Cardinal(Word(AColumns)) or
    (Cardinal(Word(ARows)) shl 16);
end;

{ TRadIAUtf8StreamDecoder }

function TRadIAUtf8StreamDecoder.CompleteLength(
  const ABytes: TBytes
): Integer;
var
  LExpected: Integer;
  LIndex: Integer;
begin
  Result := Length(ABytes);
  if Result = 0 then
    Exit;
  LIndex := Result - 1;
  while (LIndex >= 0) and ((ABytes[LIndex] and $C0) = $80) do
    Dec(LIndex);
  if LIndex < 0 then
    Exit(0);
  case ABytes[LIndex] of
    $C2..$DF: LExpected := 2;
    $E0..$EF: LExpected := 3;
    $F0..$F4: LExpected := 4;
  else
    Exit;
  end;
  if Result - LIndex < LExpected then
    Result := LIndex;
end;

function TRadIAUtf8StreamDecoder.Decode(
  const ABytes: TBytes;
  const ACount: Integer
): string;
var
  LCompleteLength: Integer;
  LIndex: Integer;
  LInput: TBytes;
begin
  if (ACount < 0) or (ACount > Length(ABytes)) then
    raise EArgumentOutOfRangeException.Create('Invalid UTF-8 byte count.');
  SetLength(LInput, Length(FPending) + ACount);
  for LIndex := 0 to High(FPending) do
    LInput[LIndex] := FPending[LIndex];
  for LIndex := 0 to ACount - 1 do
    LInput[Length(FPending) + LIndex] := ABytes[LIndex];
  LCompleteLength := CompleteLength(LInput);
  Result := TEncoding.UTF8.GetString(LInput, 0, LCompleteLength);
  SetLength(FPending, Length(LInput) - LCompleteLength);
  for LIndex := 0 to High(FPending) do
    FPending[LIndex] := LInput[LCompleteLength + LIndex];
end;

function TRadIAUtf8StreamDecoder.Flush: string;
begin
  Result := TEncoding.UTF8.GetString(FPending);
  FPending := nil;
end;

{ TRadIAConPtyApi }

class function TRadIAConPtyApi.Load(
  out AApi: TRadIAConPtyApi
): Boolean;
var
  LKernel32: HMODULE;
begin
  AApi := Default(TRadIAConPtyApi);
  LKernel32 := GetModuleHandle(kernel32);
  if LKernel32 = 0 then
    Exit(False);
  AApi.CreatePseudoConsole := TRadIACreatePseudoConsole(
    GetProcAddress(LKernel32, 'CreatePseudoConsole')
  );
  AApi.ResizePseudoConsole := TRadIAResizePseudoConsole(
    GetProcAddress(LKernel32, 'ResizePseudoConsole')
  );
  AApi.ClosePseudoConsole := TRadIAClosePseudoConsole(
    GetProcAddress(LKernel32, 'ClosePseudoConsole')
  );
  AApi.InitializeAttributeList := TRadIAInitializeAttributeList(
    GetProcAddress(LKernel32, 'InitializeProcThreadAttributeList')
  );
  AApi.UpdateAttribute := TRadIAUpdateAttribute(
    GetProcAddress(LKernel32, 'UpdateProcThreadAttribute')
  );
  AApi.DeleteAttributeList := TRadIADeleteAttributeList(
    GetProcAddress(LKernel32, 'DeleteProcThreadAttributeList')
  );
  AApi.CreateProcess := TRadIACreateProcess(
    GetProcAddress(LKernel32, 'CreateProcessW')
  );
  Result := Assigned(AApi.CreatePseudoConsole) and
    Assigned(AApi.ResizePseudoConsole) and
    Assigned(AApi.ClosePseudoConsole) and
    Assigned(AApi.InitializeAttributeList) and
    Assigned(AApi.UpdateAttribute) and
    Assigned(AApi.DeleteAttributeList) and
    Assigned(AApi.CreateProcess);
end;

{ TRadIAPseudoTerminalSession }

constructor TRadIAPseudoTerminalSession.Create(
  const AApi: TRadIAConPtyApi;
  const AInvocation: TRadIACliInvocation;
  const AColumns: SmallInt;
  const ARows: SmallInt;
  const ATimeoutMs: Cardinal;
  const AOnOutput: TProc<string>;
  const AOnComplete: TProc<TRadIACliProcessResult>
);
begin
  inherited Create;
  FApi := AApi;
  FInvocation := AInvocation;
  FColumns := AColumns;
  FRows := ARows;
  FDecoder := TRadIAUtf8StreamDecoder.Create;
  FTimeoutMs := ATimeoutMs;
  FOnOutput := AOnOutput;
  FOnComplete := AOnComplete;
  FLock := TObject.Create;
end;

destructor TRadIAPseudoTerminalSession.Destroy;
begin
  TerminateProcessTree;
  FLock.Free;
  FDecoder.Free;
  inherited Destroy;
end;

procedure TRadIAPseudoTerminalSession.AppendCaptured(
  var ATarget: string;
  const AChunk: string
);
var
  LRemaining: Integer;
begin
  LRemaining := CMaxCapturedCharacters - Length(ATarget);
  if LRemaining <= 0 then
    Exit;
  ATarget := ATarget +
    AChunk.Substring(0, Min(Length(AChunk), LRemaining));
end;

procedure TRadIAPseudoTerminalSession.Cancel;
begin
  TMonitor.Enter(FLock);
  try
    FCancelRequested := True;
    TerminateProcessTree;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAPseudoTerminalSession.CloseHandleIfAssigned(
  var AHandle: THandle
);
begin
  if AHandle = 0 then
    Exit;
  CloseHandle(AHandle);
  AHandle := 0;
end;

function TRadIAPseudoTerminalSession.ConfigureJob(
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

function TRadIAPseudoTerminalSession.CancellationRequested: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FCancelRequested;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAPseudoTerminalSession.DrainOutput(
  const AHandle: THandle;
  var AOutput: string
);
var
  LAvailable: Cardinal;
  LBuffer: TBytes;
  LBytesRead: Cardinal;
  LChunk: string;
begin
  if AHandle = 0 then
    Exit;
  repeat
    LAvailable := 0;
    if not PeekNamedPipe(
      AHandle,
      nil,
      0,
      nil,
      @LAvailable,
      nil
    ) or (LAvailable = 0) then
      Exit;
    SetLength(LBuffer, Min(LAvailable, Cardinal(CReadBufferSize)));
    LBytesRead := 0;
    if not ReadFile(
      AHandle,
      LBuffer[0],
      Length(LBuffer),
      LBytesRead,
      nil
    ) or (LBytesRead = 0) then
      Exit;
    LChunk := FDecoder.Decode(LBuffer, LBytesRead);
    if LChunk = '' then
      Continue;
    AppendCaptured(AOutput, LChunk);
    if Assigned(FOnOutput) then
      try
        FOnOutput(LChunk);
      except
        on E: Exception do
          TLogger.Log(
            'Pseudo-terminal output callback failed: ' + E.Message,
            'PseudoTerminal'
          );
      end;
  until LAvailable <= LBytesRead;
end;

procedure TRadIAPseudoTerminalSession.DrainOutputUntilQuiet(
  const AHandle: THandle;
  var AOutput: string
);
const
  CMaximumDrainMs = 1000;
  CQuietPeriodMs = 100;
var
  LDeadline: UInt64;
  LLengthBefore: Integer;
  LMaximumDeadline: UInt64;
begin
  LDeadline := GetTickCount64 + CQuietPeriodMs;
  LMaximumDeadline := GetTickCount64 + CMaximumDrainMs;
  repeat
    LLengthBefore := Length(AOutput);
    DrainOutput(AHandle, AOutput);
    if Length(AOutput) > LLengthBefore then
      LDeadline := GetTickCount64 + CQuietPeriodMs
    else
      Sleep(CProcessPollIntervalMs);
  until (GetTickCount64 >= LDeadline) or
    (GetTickCount64 >= LMaximumDeadline);
end;

procedure TRadIAPseudoTerminalSession.ExecuteWorker;
var
  LCancelled: Boolean;
  LCommandLine: string;
  LCreated: Boolean;
  LCreateResult: HRESULT;
  LExitCode: Cardinal;
  LHostInputWrite: THandle;
  LHostOutputRead: THandle;
  LProcessInfo: TProcessInformation;
  LPseudoConsole: THandle;
  LPseudoInputRead: THandle;
  LPseudoOutputWrite: THandle;
  LStartedAt: UInt64;
  LStartupInfo: TRadIAStartupInfoEx;
  LStdOut: string;
  LTimedOut: Boolean;
  LWaitResult: Cardinal;
begin
  LHostInputWrite := 0;
  LHostOutputRead := 0;
  LPseudoConsole := 0;
  LPseudoInputRead := 0;
  LPseudoOutputWrite := 0;
  LExitCode := CCancelledExitCode;
  LCancelled := False;
  LTimedOut := False;
  ZeroMemory(@LProcessInfo, SizeOf(LProcessInfo));
  ZeroMemory(@LStartupInfo, SizeOf(LStartupInfo));
  try
    if not CreatePipe(
      LPseudoInputRead,
      LHostInputWrite,
      nil,
      0
    ) or not CreatePipe(
      LHostOutputRead,
      LPseudoOutputWrite,
      nil,
      0
    ) then
      RaiseLastOSError;
    LCreateResult := FApi.CreatePseudoConsole(
      RadIACoord(FColumns, FRows),
      LPseudoInputRead,
      LPseudoOutputWrite,
      0,
      LPseudoConsole
    );
    if Failed(LCreateResult) then
      raise EOSError.CreateFmt(
        'Unable to create the Windows pseudo-terminal (0x%.8x).',
        [Cardinal(LCreateResult)]
      );
    PrepareStartupInfo(
      LPseudoConsole,
      LPseudoInputRead,
      LPseudoOutputWrite,
      LStartupInfo
    );
    LCommandLine := FInvocation.ToCommandLine;
    UniqueString(LCommandLine);
    LCreated := FApi.CreateProcess(
      nil,
      PChar(LCommandLine),
      nil,
      nil,
      False,
      CExtendedStartupInfoPresent,
      nil,
      PChar(FInvocation.WorkingDirectory),
      @LStartupInfo,
      LProcessInfo
    );
    if not LCreated then
      RaiseLastOSError;
    CloseHandleIfAssigned(LPseudoInputRead);
    CloseHandleIfAssigned(LPseudoOutputWrite);
    TMonitor.Enter(FLock);
    try
      if not ConfigureJob(LProcessInfo.hProcess) then
        RaiseLastOSError;
      FInputWriteHandle := LHostInputWrite;
      LHostInputWrite := 0;
      FPseudoConsole := LPseudoConsole;
      if FCancelRequested then
        TerminateProcessTree;
    finally
      TMonitor.Exit(FLock);
    end;
    LStartedAt := GetTickCount64;
    repeat
      DrainOutput(LHostOutputRead, LStdOut);
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
    DrainOutputUntilQuiet(LHostOutputRead, LStdOut);
    if not GetExitCodeProcess(LProcessInfo.hProcess, LExitCode) then
      LExitCode := CCancelledExitCode;
  except
    on E: Exception do
      AppendCaptured(LStdOut, E.ClassName + ': ' + E.Message);
  end;
  CloseHandleIfAssigned(LProcessInfo.hThread);
  CloseHandleIfAssigned(LProcessInfo.hProcess);
  CloseHandleIfAssigned(LPseudoInputRead);
  CloseHandleIfAssigned(LPseudoOutputWrite);
  CloseHandleIfAssigned(LHostInputWrite);
  if Assigned(LStartupInfo.AttributeList) then
  begin
    FApi.DeleteAttributeList(LStartupInfo.AttributeList);
    HeapFree(
      GetProcessHeap,
      0,
      LStartupInfo.AttributeList
    );
  end;
  ReleaseRuntimeHandles(LHostOutputRead, LPseudoConsole);
  Finish(
    TRadIACliProcessResult.Create(
      LExitCode,
      LStdOut,
      '',
      LCancelled,
      LTimedOut
    )
  );
  TInterlocked.Decrement(GActiveThreadCount);
  _Release;
end;

procedure TRadIAPseudoTerminalSession.Finish(
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
          'Pseudo-terminal completion callback failed: ' + E.Message,
          'PseudoTerminal'
        );
    end;
end;

function TRadIAPseudoTerminalSession.HasTimedOut(
  const AStartedAt: UInt64
): Boolean;
begin
  Result := (FTimeoutMs > 0) and
    ((GetTickCount64 - AStartedAt) >= FTimeoutMs);
end;

function TRadIAPseudoTerminalSession.IsPseudoTerminal: Boolean;
begin
  Result := True;
end;

function TRadIAPseudoTerminalSession.IsRunning: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := FRunning;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAPseudoTerminalSession.PrepareStartupInfo(
  const APseudoConsole: THandle;
  const AInputHandle: THandle;
  const AOutputHandle: THandle;
  var AStartupInfo: TRadIAStartupInfoEx
);
var
  LInitialized: Boolean;
  LSize: NativeUInt;
begin
  ZeroMemory(@AStartupInfo, SizeOf(AStartupInfo));
  AStartupInfo.StartupInfo.cb := SizeOf(AStartupInfo);
  AStartupInfo.StartupInfo.dwFlags := STARTF_USESTDHANDLES;
  AStartupInfo.StartupInfo.hStdInput := AInputHandle;
  AStartupInfo.StartupInfo.hStdOutput := AOutputHandle;
  AStartupInfo.StartupInfo.hStdError := AOutputHandle;
  LSize := 0;
  FApi.InitializeAttributeList(nil, 1, 0, LSize);
  AStartupInfo.AttributeList := HeapAlloc(
    GetProcessHeap,
    HEAP_ZERO_MEMORY,
    LSize
  );
  if not Assigned(AStartupInfo.AttributeList) then
    raise EOutOfMemory.Create('Unable to allocate the attribute list.');
  LInitialized := False;
  try
    if not FApi.InitializeAttributeList(
      AStartupInfo.AttributeList,
      1,
      0,
      LSize
    ) then
      RaiseLastOSError;
    LInitialized := True;
    if not FApi.UpdateAttribute(
      AStartupInfo.AttributeList,
      0,
      CProcThreadAttributePseudoConsole,
      Pointer(APseudoConsole),
      SizeOf(APseudoConsole),
      nil,
      nil
    ) then
      RaiseLastOSError;
  except
    if LInitialized then
      FApi.DeleteAttributeList(AStartupInfo.AttributeList);
    HeapFree(
      GetProcessHeap,
      0,
      AStartupInfo.AttributeList
    );
    AStartupInfo.AttributeList := nil;
    raise;
  end;
end;

procedure TRadIAPseudoTerminalSession.ReleaseRuntimeHandles(
  var AOutputReadHandle: THandle;
  var APseudoConsole: THandle
);
var
  LPseudoConsole: THandle;
begin
  TMonitor.Enter(FLock);
  try
    CloseHandleIfAssigned(FInputWriteHandle);
    CloseHandleIfAssigned(FJobHandle);
    LPseudoConsole := FPseudoConsole;
    FPseudoConsole := 0;
  finally
    TMonitor.Exit(FLock);
  end;
  CloseHandleIfAssigned(AOutputReadHandle);
  if LPseudoConsole = 0 then
    LPseudoConsole := APseudoConsole;
  APseudoConsole := 0;
  if LPseudoConsole <> 0 then
    FApi.ClosePseudoConsole(LPseudoConsole);
end;

function TRadIAPseudoTerminalSession.Resize(
  const AColumns: SmallInt;
  const ARows: SmallInt
): Boolean;
begin
  Result := False;
  if (AColumns <= 0) or (ARows <= 0) then
    Exit;
  TMonitor.Enter(FLock);
  try
    if FPseudoConsole = 0 then
      Exit;
    Result := Succeeded(
      FApi.ResizePseudoConsole(
        FPseudoConsole,
        RadIACoord(AColumns, ARows)
      )
    );
    if Result then
    begin
      FColumns := AColumns;
      FRows := ARows;
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAPseudoTerminalSession.StartWorker;
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

procedure TRadIAPseudoTerminalSession.TerminateProcessTree;
begin
  if FJobHandle <> 0 then
    TerminateJobObject(FJobHandle, CCancelledExitCode);
end;

function TRadIAPseudoTerminalSession.WriteInput(
  const AText: string
): Boolean;
var
  LBytes: TBytes;
  LBytesWritten: Cardinal;
  LHandle: THandle;
  LOffset: Integer;
begin
  Result := False;
  if AText = '' then
    Exit;
  LHandle := 0;
  TMonitor.Enter(FLock);
  try
    if not FRunning or (FInputWriteHandle = 0) then
      Exit;
    if not DuplicateHandle(
      GetCurrentProcess,
      FInputWriteHandle,
      GetCurrentProcess,
      @LHandle,
      0,
      False,
      DUPLICATE_SAME_ACCESS
    ) then
      Exit;
  finally
    TMonitor.Exit(FLock);
  end;
  try
    LBytes := TEncoding.UTF8.GetBytes(AText);
    LOffset := 0;
    while LOffset < Length(LBytes) do
    begin
      LBytesWritten := 0;
      if not WriteFile(
        LHandle,
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
    CloseHandleIfAssigned(LHandle);
  end;
end;

{ TRadIAPseudoTerminalRunner }

class function TRadIAPseudoTerminalRunner.IsSupported: Boolean;
var
  LApi: TRadIAConPtyApi;
begin
  Result := TRadIAConPtyApi.Load(LApi);
end;

class function TRadIAPseudoTerminalRunner.Start(
  const AInvocation: TRadIACliInvocation;
  const AColumns: SmallInt;
  const ARows: SmallInt;
  const ATimeoutMs: Cardinal;
  const AOnOutput: TProc<string>;
  const AOnComplete: TProc<TRadIACliProcessResult>
): IRadIACliProcessSession;
var
  LApi: TRadIAConPtyApi;
  LSession: TRadIAPseudoTerminalSession;
begin
  if (AColumns <= 0) or (ARows <= 0) then
    raise EArgumentOutOfRangeException.Create(
      'Pseudo-terminal dimensions must be positive.'
    );
  if not TRadIAConPtyApi.Load(LApi) then
    raise ENotSupportedException.Create(
      'Windows ConPTY is unavailable on this operating system.'
    );
  LSession := TRadIAPseudoTerminalSession.Create(
    LApi,
    AInvocation,
    AColumns,
    ARows,
    ATimeoutMs,
    AOnOutput,
    AOnComplete
  );
  Result := LSession;
  LSession.StartWorker;
end;

end.
