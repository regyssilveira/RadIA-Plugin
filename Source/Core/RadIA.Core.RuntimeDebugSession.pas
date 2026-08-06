unit RadIA.Core.RuntimeDebugSession;

interface

uses
  System.Generics.Collections,
  RadIA.Core.RuntimeAutomation;

type
  TRadIARuntimeDebugEventKind = (
    rdekProcessCreated,
    rdekRunning,
    rdekStopped,
    rdekException,
    rdekProcessExited,
    rdekProjectChanged,
    rdekWindowAvailable
  );

  TRadIARuntimeDebugEventKinds = set of TRadIARuntimeDebugEventKind;

  TRadIARuntimeDebugEvent = record
  private
    FDetails: string;
    FKind: TRadIARuntimeDebugEventKind;
    FProcessId: LongWord;
    FSequence: Int64;
    FSessionId: string;
    FState: string;
    FTimestampUtc: TDateTime;
  public
    constructor Create(
      const ASequence: Int64;
      const ASessionId: string;
      const AProcessId: LongWord;
      const AKind: TRadIARuntimeDebugEventKind;
      const AState: string;
      const ADetails: string
    );
    property Sequence: Int64 read FSequence;
    property SessionId: string read FSessionId;
    property ProcessId: LongWord read FProcessId;
    property Kind: TRadIARuntimeDebugEventKind read FKind;
    property State: string read FState;
    property Details: string read FDetails;
    property TimestampUtc: TDateTime read FTimestampUtc;
  end;

  TRadIARuntimeDebugWaitReason = (
    rdwrMatched,
    rdwrTimeout,
    rdwrCancelled,
    rdwrSessionChanged
  );

  TRadIARuntimeDebugWaitFilter = record
  private
    FKinds: TRadIARuntimeDebugEventKinds;
    FProcessId: LongWord;
    FSessionId: string;
    FSinceSequence: Int64;
    FTimeoutMs: Cardinal;
  public
    constructor Create(
      const ASessionId: string;
      const AProcessId: LongWord;
      const ASinceSequence: Int64;
      const AKinds: TRadIARuntimeDebugEventKinds;
      const ATimeoutMs: Cardinal
    );
    function IsValid: Boolean;
    property SessionId: string read FSessionId;
    property ProcessId: LongWord read FProcessId;
    property SinceSequence: Int64 read FSinceSequence;
    property Kinds: TRadIARuntimeDebugEventKinds read FKinds;
    property TimeoutMs: Cardinal read FTimeoutMs;
  end;

  TRadIARuntimeDebugWaitResult = record
  private
    FEvent: TRadIARuntimeDebugEvent;
    FReason: TRadIARuntimeDebugWaitReason;
  public
    constructor Create(
      const AReason: TRadIARuntimeDebugWaitReason;
      const AEvent: TRadIARuntimeDebugEvent
    );
    property Reason: TRadIARuntimeDebugWaitReason read FReason;
    property Event: TRadIARuntimeDebugEvent read FEvent;
  end;

  IRadIARuntimeDebugWaitCancellation = interface
    ['{B7DD48FD-92A5-4207-A463-06831B84E31D}']
    function IsCancelled: Boolean;
  end;

  IRadIARuntimeDebugWait = interface
    ['{5898AFC8-D2F5-49B6-823C-CC341F863886}']
    function Wait: TRadIARuntimeDebugWaitResult;
    procedure Cancel;
  end;

  IRadIARuntimeDebugSessionCoordinator = interface
    ['{8F463E20-B0B7-4B94-8822-06E92C58B8DF}']
    function BeginSession(const AProjectPath: string): string;
    function AttachProcess(
      const ASessionId: string;
      const AProcessId: LongWord;
      const ACreatedAtUtc: TDateTime;
      const AExecutablePath: string;
      const ABuildId: string
    ): Boolean;
    function GetCurrentSession: TRadIARuntimeSessionIdentity;
    function GetLastSequence: Int64;
    function RecordEvent(
      const ASessionId: string;
      const AKind: TRadIARuntimeDebugEventKind;
      const AState: string;
      const ADetails: string
    ): Boolean;
    function CreateWait(
      const AFilter: TRadIARuntimeDebugWaitFilter
    ): IRadIARuntimeDebugWait;
    function WaitForEvent(
      const AFilter: TRadIARuntimeDebugWaitFilter;
      const ACancellation: IRadIARuntimeDebugWaitCancellation
    ): TRadIARuntimeDebugWaitResult;
    procedure NotifyWaiters;
  end;

  TRadIARuntimeDebugSessionCoordinator = class(
    TInterfacedObject,
    IRadIARuntimeDebugSessionCoordinator
  )
  private
    FBuildId: string;
    FCreatedAtUtc: TDateTime;
    FEvents: TList<TRadIARuntimeDebugEvent>;
    FExecutablePath: string;
    FLastSequence: Int64;
    FLock: TObject;
    FProcessId: LongWord;
    FProjectPath: string;
    FSessionId: string;
    function FindEvent(
      const AFilter: TRadIARuntimeDebugWaitFilter;
      out AEvent: TRadIARuntimeDebugEvent
    ): Boolean;
    function SessionMatches(const ASessionId: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function BeginSession(const AProjectPath: string): string;
    function AttachProcess(
      const ASessionId: string;
      const AProcessId: LongWord;
      const ACreatedAtUtc: TDateTime;
      const AExecutablePath: string;
      const ABuildId: string
    ): Boolean;
    function GetCurrentSession: TRadIARuntimeSessionIdentity;
    function GetLastSequence: Int64;
    function RecordEvent(
      const ASessionId: string;
      const AKind: TRadIARuntimeDebugEventKind;
      const AState: string;
      const ADetails: string
    ): Boolean;
    function CreateWait(
      const AFilter: TRadIARuntimeDebugWaitFilter
    ): IRadIARuntimeDebugWait;
    function WaitForEvent(
      const AFilter: TRadIARuntimeDebugWaitFilter;
      const ACancellation: IRadIARuntimeDebugWaitCancellation
    ): TRadIARuntimeDebugWaitResult;
    procedure NotifyWaiters;
  end;

function RadIARuntimeDebugEventKindName(
  const AKind: TRadIARuntimeDebugEventKind
): string;

implementation

uses
  System.DateUtils,
  System.Diagnostics,
  System.SyncObjs,
  System.SysUtils;

const
  CMaxRetainedEvents = 500;
  CMaxWaitMilliseconds = 300000;

type
  TRadIARuntimeDebugWait = class(
    TInterfacedObject,
    IRadIARuntimeDebugWait,
    IRadIARuntimeDebugWaitCancellation
  )
  private
    FCancelled: Integer;
    FCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FFilter: TRadIARuntimeDebugWaitFilter;
  public
    constructor Create(
      const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
      const AFilter: TRadIARuntimeDebugWaitFilter
    );
    procedure Cancel;
    function IsCancelled: Boolean;
    function Wait: TRadIARuntimeDebugWaitResult;
  end;

{ TRadIARuntimeDebugEvent }

constructor TRadIARuntimeDebugEvent.Create(
  const ASequence: Int64;
  const ASessionId: string;
  const AProcessId: LongWord;
  const AKind: TRadIARuntimeDebugEventKind;
  const AState: string;
  const ADetails: string
);
begin
  FSequence := ASequence;
  FSessionId := ASessionId;
  FProcessId := AProcessId;
  FKind := AKind;
  FState := AState;
  FDetails := ADetails;
  FTimestampUtc := TTimeZone.Local.ToUniversalTime(Now);
end;

{ TRadIARuntimeDebugWaitFilter }

constructor TRadIARuntimeDebugWaitFilter.Create(
  const ASessionId: string;
  const AProcessId: LongWord;
  const ASinceSequence: Int64;
  const AKinds: TRadIARuntimeDebugEventKinds;
  const ATimeoutMs: Cardinal
);
begin
  FSessionId := Trim(ASessionId);
  FProcessId := AProcessId;
  FSinceSequence := ASinceSequence;
  FKinds := AKinds;
  FTimeoutMs := ATimeoutMs;
end;

function TRadIARuntimeDebugWaitFilter.IsValid: Boolean;
begin
  Result :=
    (FSessionId <> '') and
    (FSinceSequence >= 0) and
    (FKinds <> []) and
    (FTimeoutMs > 0) and
    (FTimeoutMs <= CMaxWaitMilliseconds);
end;

{ TRadIARuntimeDebugWaitResult }

constructor TRadIARuntimeDebugWaitResult.Create(
  const AReason: TRadIARuntimeDebugWaitReason;
  const AEvent: TRadIARuntimeDebugEvent
);
begin
  FReason := AReason;
  FEvent := AEvent;
end;

{ TRadIARuntimeDebugWait }

procedure TRadIARuntimeDebugWait.Cancel;
begin
  TInterlocked.Exchange(FCancelled, 1);
  FCoordinator.NotifyWaiters;
end;

constructor TRadIARuntimeDebugWait.Create(
  const ACoordinator: IRadIARuntimeDebugSessionCoordinator;
  const AFilter: TRadIARuntimeDebugWaitFilter
);
begin
  inherited Create;
  FCoordinator := ACoordinator;
  FFilter := AFilter;
end;

function TRadIARuntimeDebugWait.IsCancelled: Boolean;
begin
  Result := TInterlocked.CompareExchange(FCancelled, 0, 0) <> 0;
end;

function TRadIARuntimeDebugWait.Wait: TRadIARuntimeDebugWaitResult;
var
  LCancellation: IRadIARuntimeDebugWaitCancellation;
begin
  LCancellation := Self;
  Result := FCoordinator.WaitForEvent(FFilter, LCancellation);
end;

{ TRadIARuntimeDebugSessionCoordinator }

function TRadIARuntimeDebugSessionCoordinator.AttachProcess(
  const ASessionId: string;
  const AProcessId: LongWord;
  const ACreatedAtUtc: TDateTime;
  const AExecutablePath: string;
  const ABuildId: string
): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result :=
      SessionMatches(ASessionId) and
      (AProcessId > 0) and
      (ACreatedAtUtc > 0) and
      (Trim(AExecutablePath) <> '') and
      (Trim(ABuildId) <> '');
    if not Result then
      Exit;
    FProcessId := AProcessId;
    FCreatedAtUtc := ACreatedAtUtc;
    FExecutablePath := Trim(AExecutablePath);
    FBuildId := Trim(ABuildId);
    TMonitor.PulseAll(FLock);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIARuntimeDebugSessionCoordinator.BeginSession(
  const AProjectPath: string
): string;
var
  LGuid: TGUID;
begin
  if Trim(AProjectPath) = '' then
    raise EArgumentException.Create('Project path is required.');
  CreateGUID(LGuid);
  Result := GUIDToString(LGuid);
  TMonitor.Enter(FLock);
  try
    FSessionId := Result;
    FProjectPath := Trim(AProjectPath);
    FProcessId := 0;
    FCreatedAtUtc := 0;
    FExecutablePath := '';
    FBuildId := '';
    TMonitor.PulseAll(FLock);
  finally
    TMonitor.Exit(FLock);
  end;
end;

constructor TRadIARuntimeDebugSessionCoordinator.Create;
begin
  inherited Create;
  FLock := TObject.Create;
  FEvents := TList<TRadIARuntimeDebugEvent>.Create;
end;

function TRadIARuntimeDebugSessionCoordinator.CreateWait(
  const AFilter: TRadIARuntimeDebugWaitFilter
): IRadIARuntimeDebugWait;
var
  LCoordinator: IRadIARuntimeDebugSessionCoordinator;
begin
  if not AFilter.IsValid then
    raise EArgumentException.Create('Runtime debug wait filter is invalid.');
  LCoordinator := Self;
  Result := TRadIARuntimeDebugWait.Create(LCoordinator, AFilter);
end;

destructor TRadIARuntimeDebugSessionCoordinator.Destroy;
begin
  FEvents.Free;
  FLock.Free;
  inherited Destroy;
end;

function TRadIARuntimeDebugSessionCoordinator.FindEvent(
  const AFilter: TRadIARuntimeDebugWaitFilter;
  out AEvent: TRadIARuntimeDebugEvent
): Boolean;
var
  LEvent: TRadIARuntimeDebugEvent;
begin
  Result := False;
  for LEvent in FEvents do
  begin
    if LEvent.Sequence <= AFilter.SinceSequence then
      Continue;
    if not SameText(LEvent.SessionId, AFilter.SessionId) then
      Continue;
    if (AFilter.ProcessId > 0) and
      (LEvent.ProcessId <> AFilter.ProcessId) then
      Continue;
    if not (LEvent.Kind in AFilter.Kinds) then
      Continue;
    AEvent := LEvent;
    Exit(True);
  end;
end;

function TRadIARuntimeDebugSessionCoordinator.GetCurrentSession:
  TRadIARuntimeSessionIdentity;
begin
  TMonitor.Enter(FLock);
  try
    Result := TRadIARuntimeSessionIdentity.Create(
      FSessionId,
      FProcessId,
      FCreatedAtUtc,
      FExecutablePath,
      FProjectPath,
      FBuildId
    );
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIARuntimeDebugSessionCoordinator.GetLastSequence: Int64;
begin
  TMonitor.Enter(FLock);
  try
    Result := FLastSequence;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIARuntimeDebugSessionCoordinator.NotifyWaiters;
begin
  TMonitor.Enter(FLock);
  try
    TMonitor.PulseAll(FLock);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIARuntimeDebugSessionCoordinator.RecordEvent(
  const ASessionId: string;
  const AKind: TRadIARuntimeDebugEventKind;
  const AState: string;
  const ADetails: string
): Boolean;
var
  LEvent: TRadIARuntimeDebugEvent;
begin
  TMonitor.Enter(FLock);
  try
    Result := SessionMatches(ASessionId);
    if not Result then
      Exit;
    Inc(FLastSequence);
    LEvent := TRadIARuntimeDebugEvent.Create(
      FLastSequence,
      FSessionId,
      FProcessId,
      AKind,
      AState,
      ADetails
    );
    FEvents.Add(LEvent);
    while FEvents.Count > CMaxRetainedEvents do
      FEvents.Delete(0);
    TMonitor.PulseAll(FLock);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIARuntimeDebugSessionCoordinator.SessionMatches(
  const ASessionId: string
): Boolean;
begin
  Result :=
    (FSessionId <> '') and
    SameText(FSessionId, Trim(ASessionId));
end;

function TRadIARuntimeDebugSessionCoordinator.WaitForEvent(
  const AFilter: TRadIARuntimeDebugWaitFilter;
  const ACancellation: IRadIARuntimeDebugWaitCancellation
): TRadIARuntimeDebugWaitResult;
var
  LEvent: TRadIARuntimeDebugEvent;
  LRemaining: Int64;
  LStopwatch: TStopwatch;
begin
  LStopwatch := TStopwatch.StartNew;
  TMonitor.Enter(FLock);
  try
    while True do
    begin
      if Assigned(ACancellation) and ACancellation.IsCancelled then
        Exit(TRadIARuntimeDebugWaitResult.Create(
          rdwrCancelled,
          Default(TRadIARuntimeDebugEvent)
        ));
      if not SessionMatches(AFilter.SessionId) then
        Exit(TRadIARuntimeDebugWaitResult.Create(
          rdwrSessionChanged,
          Default(TRadIARuntimeDebugEvent)
        ));
      if FindEvent(AFilter, LEvent) then
        Exit(TRadIARuntimeDebugWaitResult.Create(rdwrMatched, LEvent));
      if LStopwatch.ElapsedMilliseconds >= AFilter.TimeoutMs then
        Exit(TRadIARuntimeDebugWaitResult.Create(
          rdwrTimeout,
          Default(TRadIARuntimeDebugEvent)
        ));
      LRemaining :=
        Int64(AFilter.TimeoutMs) -
        LStopwatch.ElapsedMilliseconds;
      TMonitor.Wait(FLock, Integer(LRemaining));
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function RadIARuntimeDebugEventKindName(
  const AKind: TRadIARuntimeDebugEventKind
): string;
begin
  case AKind of
    rdekProcessCreated: Result := 'processCreated';
    rdekRunning: Result := 'running';
    rdekStopped: Result := 'stopped';
    rdekException: Result := 'exception';
    rdekProcessExited: Result := 'processExited';
    rdekProjectChanged: Result := 'projectChanged';
  else
    Result := 'windowAvailable';
  end;
end;

end.
