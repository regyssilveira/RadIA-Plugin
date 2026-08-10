unit RadIA.Core.VisualRuntimeSession;

interface

uses
  RadIA.Core.RuntimeAutomation;

type
  TRadIAVisualCapturePhase = (
    vcpBefore,
    vcpAfter
  );

  TRadIAVisualSessionEventKind = (
    vsekSessionStarted,
    vsekCaptureRecorded,
    vsekActionStarted,
    vsekActionCompleted,
    vsekDebuggerEvent,
    vsekValidationRecorded,
    vsekSessionCompleted
  );

  TRadIAVisualSessionState = (
    vssActive,
    vssCompleted,
    vssFailed,
    vssCancelled
  );

  IRadIAVisualSessionClock = interface
    ['{2FC807B6-89C5-4596-8176-DA85A1E96E04}']
    function UtcNow: TDateTime;
  end;

  TRadIAVisualCaptureContent = record
  private
    FBytes: TArray<Byte>;
    FHeight: Integer;
    FMimeType: string;
    FWidth: Integer;
  public
    constructor Create(
      const AMimeType: string;
      const AWidth: Integer;
      const AHeight: Integer;
      const ABytes: TArray<Byte>
    );
    function Clone: TRadIAVisualCaptureContent;
    property Bytes: TArray<Byte> read FBytes;
    property Height: Integer read FHeight;
    property MimeType: string read FMimeType;
    property Width: Integer read FWidth;
  end;

  TRadIAVisualCapture = record
  private
    FCapturedAtUtc: TDateTime;
    FCaptureId: string;
    FContent: TRadIAVisualCaptureContent;
    FPhase: TRadIAVisualCapturePhase;
    FProcessId: LongWord;
    FWindowId: string;
    function GetBytes: TArray<Byte>;
    function GetHeight: Integer;
    function GetMimeType: string;
    function GetWidth: Integer;
  public
    constructor Create(
      const ACaptureId: string;
      const AProcessId: LongWord;
      const AWindowId: string;
      const APhase: TRadIAVisualCapturePhase;
      const AContent: TRadIAVisualCaptureContent;
      const ACapturedAtUtc: TDateTime
    );
    function Clone: TRadIAVisualCapture;
    property Bytes: TArray<Byte> read GetBytes;
    property CapturedAtUtc: TDateTime read FCapturedAtUtc;
    property CaptureId: string read FCaptureId;
    property Height: Integer read GetHeight;
    property MimeType: string read GetMimeType;
    property Phase: TRadIAVisualCapturePhase read FPhase;
    property ProcessId: LongWord read FProcessId;
    property Width: Integer read GetWidth;
    property WindowId: string read FWindowId;
  end;

  IRadIARuntimeVisualCaptureFacade = interface
    ['{3737FCB4-AD4B-42B4-9FD0-B690E613932E}']
    function CaptureWindow(
      const ASession: TRadIARuntimeSessionIdentity;
      const AWindowId: string;
      const APhase: TRadIAVisualCapturePhase
    ): TRadIAVisualCapture;
  end;

  TRadIAVisualSessionEvent = record
  private
    FActionIndex: Integer;
    FDetails: string;
    FKind: TRadIAVisualSessionEventKind;
    FSequence: Int64;
    FStatus: string;
    FTimestampUtc: TDateTime;
  public
    constructor Create(
      const ASequence: Int64;
      const AKind: TRadIAVisualSessionEventKind;
      const AActionIndex: Integer;
      const AStatus: string;
      const ADetails: string;
      const ATimestampUtc: TDateTime
    );
    property ActionIndex: Integer read FActionIndex;
    property Details: string read FDetails;
    property Kind: TRadIAVisualSessionEventKind read FKind;
    property Sequence: Int64 read FSequence;
    property Status: string read FStatus;
    property TimestampUtc: TDateTime read FTimestampUtc;
  end;

  TRadIAVisualSessionSnapshot = record
  private
    FCaptures: TArray<TRadIAVisualCapture>;
    FEvents: TArray<TRadIAVisualSessionEvent>;
    FSession: TRadIARuntimeSessionIdentity;
    FState: TRadIAVisualSessionState;
  public
    constructor Create(
      const ASession: TRadIARuntimeSessionIdentity;
      const AState: TRadIAVisualSessionState;
      const AEvents: TArray<TRadIAVisualSessionEvent>;
      const ACaptures: TArray<TRadIAVisualCapture>
    );
    property Captures: TArray<TRadIAVisualCapture> read FCaptures;
    property Events: TArray<TRadIAVisualSessionEvent> read FEvents;
    property Session: TRadIARuntimeSessionIdentity read FSession;
    property State: TRadIAVisualSessionState read FState;
  end;

  IRadIAVisualRuntimeSession = interface
    ['{40740BE8-5D46-494F-B3D3-E3BB51E8909E}']
    procedure BeginSession(const ASession: TRadIARuntimeSessionIdentity);
    function RecordEvent(
      const ASessionId: string;
      const AKind: TRadIAVisualSessionEventKind;
      const AActionIndex: Integer;
      const AStatus: string;
      const ADetails: string
    ): Boolean;
    function RecordCapture(
      const ASessionId: string;
      const ACapture: TRadIAVisualCapture
    ): Boolean;
    function Complete(
      const ASessionId: string;
      const AState: TRadIAVisualSessionState;
      const ADetails: string
    ): Boolean;
    function TryGetSnapshot(out ASnapshot: TRadIAVisualSessionSnapshot): Boolean;
    function TryGetCapture(
      const ACaptureId: string;
      out ACapture: TRadIAVisualCapture
    ): Boolean;
    procedure Clear;
  end;

  TRadIAVisualRuntimeSession = class(
    TInterfacedObject,
    IRadIAVisualRuntimeSession
  )
  private
    FCaptures: TArray<TRadIAVisualCapture>;
    FClock: IRadIAVisualSessionClock;
    FEvents: TArray<TRadIAVisualSessionEvent>;
    FExpiresAtUtc: TDateTime;
    FLock: TObject;
    FSequence: Int64;
    FSession: TRadIARuntimeSessionIdentity;
    FState: TRadIAVisualSessionState;
    FTotalCaptureBytes: Int64;
    procedure AppendEvent(
      const AKind: TRadIAVisualSessionEventKind;
      const AActionIndex: Integer;
      const AStatus: string;
      const ADetails: string
    );
    procedure ClearUnlocked;
    function IsCurrentSession(const ASessionId: string): Boolean;
    procedure PurgeIfExpired;
    procedure Touch;
    class procedure ValidateCapture(
      const ASession: TRadIARuntimeSessionIdentity;
      const ACapture: TRadIAVisualCapture
    ); static;
  public
    constructor Create(const AClock: IRadIAVisualSessionClock = nil);
    destructor Destroy; override;
    procedure BeginSession(const ASession: TRadIARuntimeSessionIdentity);
    procedure Clear;
    function Complete(
      const ASessionId: string;
      const AState: TRadIAVisualSessionState;
      const ADetails: string
    ): Boolean;
    function RecordCapture(
      const ASessionId: string;
      const ACapture: TRadIAVisualCapture
    ): Boolean;
    function RecordEvent(
      const ASessionId: string;
      const AKind: TRadIAVisualSessionEventKind;
      const AActionIndex: Integer;
      const AStatus: string;
      const ADetails: string
    ): Boolean;
    function TryGetSnapshot(out ASnapshot: TRadIAVisualSessionSnapshot): Boolean;
    function TryGetCapture(
      const ACaptureId: string;
      out ACapture: TRadIAVisualCapture
    ): Boolean;
  end;

function RadIAVisualCapturePhaseName(const APhase: TRadIAVisualCapturePhase): string;
function RadIAVisualSessionEventKindName(
  const AKind: TRadIAVisualSessionEventKind
): string;
function RadIAVisualSessionStateName(const AState: TRadIAVisualSessionState): string;

implementation

uses
  System.DateUtils,
  System.SysUtils;

const
  CMaximumCaptureBytes = 2 * 1024 * 1024;
  CMaximumCaptureCount = 6;
  CMaximumCaptureHeight = 1440;
  CMaximumCaptureWidth = 2560;
  CMaximumEventCount = 200;
  CMaximumTotalCaptureBytes = 8 * 1024 * 1024;
  CRetentionMinutes = 10;

type
  TRadIAVisualSessionClock = class(
    TInterfacedObject,
    IRadIAVisualSessionClock
  )
  public
    function UtcNow: TDateTime;
  end;

function RadIAVisualCapturePhaseName(
  const APhase: TRadIAVisualCapturePhase
): string;
begin
  case APhase of
    vcpBefore: Result := 'before';
    vcpAfter: Result := 'after';
  else
    Result := 'unknown';
  end;
end;

function RadIAVisualSessionEventKindName(
  const AKind: TRadIAVisualSessionEventKind
): string;
begin
  case AKind of
    vsekSessionStarted: Result := 'sessionStarted';
    vsekCaptureRecorded: Result := 'captureRecorded';
    vsekActionStarted: Result := 'actionStarted';
    vsekActionCompleted: Result := 'actionCompleted';
    vsekDebuggerEvent: Result := 'debuggerEvent';
    vsekValidationRecorded: Result := 'validationRecorded';
    vsekSessionCompleted: Result := 'sessionCompleted';
  else
    Result := 'unknown';
  end;
end;

function RadIAVisualSessionStateName(
  const AState: TRadIAVisualSessionState
): string;
begin
  case AState of
    vssActive: Result := 'active';
    vssCompleted: Result := 'completed';
    vssFailed: Result := 'failed';
    vssCancelled: Result := 'cancelled';
  else
    Result := 'unknown';
  end;
end;

{ TRadIAVisualSessionClock }

function TRadIAVisualSessionClock.UtcNow: TDateTime;
begin
  Result := TTimeZone.Local.ToUniversalTime(Now);
end;

{ TRadIAVisualCapture }

{ TRadIAVisualCaptureContent }

function TRadIAVisualCaptureContent.Clone: TRadIAVisualCaptureContent;
begin
  Result := TRadIAVisualCaptureContent.Create(
    FMimeType,
    FWidth,
    FHeight,
    FBytes
  );
end;

constructor TRadIAVisualCaptureContent.Create(
  const AMimeType: string;
  const AWidth: Integer;
  const AHeight: Integer;
  const ABytes: TArray<Byte>
);
begin
  FMimeType := Trim(AMimeType);
  FWidth := AWidth;
  FHeight := AHeight;
  FBytes := Copy(ABytes);
end;

{ TRadIAVisualCapture }

function TRadIAVisualCapture.Clone: TRadIAVisualCapture;
begin
  Result := TRadIAVisualCapture.Create(
    FCaptureId,
    FProcessId,
    FWindowId,
    FPhase,
    FContent.Clone,
    FCapturedAtUtc
  );
end;

constructor TRadIAVisualCapture.Create(
  const ACaptureId: string;
  const AProcessId: LongWord;
  const AWindowId: string;
  const APhase: TRadIAVisualCapturePhase;
  const AContent: TRadIAVisualCaptureContent;
  const ACapturedAtUtc: TDateTime
);
begin
  FCaptureId := Trim(ACaptureId);
  FProcessId := AProcessId;
  FWindowId := Trim(AWindowId);
  FPhase := APhase;
  FContent := AContent.Clone;
  FCapturedAtUtc := ACapturedAtUtc;
end;

function TRadIAVisualCapture.GetBytes: TArray<Byte>;
begin
  Result := FContent.Bytes;
end;

function TRadIAVisualCapture.GetHeight: Integer;
begin
  Result := FContent.Height;
end;

function TRadIAVisualCapture.GetMimeType: string;
begin
  Result := FContent.MimeType;
end;

function TRadIAVisualCapture.GetWidth: Integer;
begin
  Result := FContent.Width;
end;

{ TRadIAVisualSessionEvent }

constructor TRadIAVisualSessionEvent.Create(
  const ASequence: Int64;
  const AKind: TRadIAVisualSessionEventKind;
  const AActionIndex: Integer;
  const AStatus: string;
  const ADetails: string;
  const ATimestampUtc: TDateTime
);
begin
  FSequence := ASequence;
  FKind := AKind;
  FActionIndex := AActionIndex;
  FStatus := AStatus;
  FDetails := ADetails;
  FTimestampUtc := ATimestampUtc;
end;

{ TRadIAVisualSessionSnapshot }

constructor TRadIAVisualSessionSnapshot.Create(
  const ASession: TRadIARuntimeSessionIdentity;
  const AState: TRadIAVisualSessionState;
  const AEvents: TArray<TRadIAVisualSessionEvent>;
  const ACaptures: TArray<TRadIAVisualCapture>
);
var
  LIndex: Integer;
begin
  FSession := ASession;
  FState := AState;
  SetLength(FEvents, Length(AEvents));
  for LIndex := Low(AEvents) to High(AEvents) do
    FEvents[LIndex] := TRadIAVisualSessionEvent.Create(
      AEvents[LIndex].Sequence,
      AEvents[LIndex].Kind,
      AEvents[LIndex].ActionIndex,
      AEvents[LIndex].Status,
      AEvents[LIndex].Details,
      AEvents[LIndex].TimestampUtc
    );
  SetLength(FCaptures, Length(ACaptures));
  for LIndex := Low(ACaptures) to High(ACaptures) do
    FCaptures[LIndex] := ACaptures[LIndex].Clone;
end;

{ TRadIAVisualRuntimeSession }

procedure TRadIAVisualRuntimeSession.AppendEvent(
  const AKind: TRadIAVisualSessionEventKind;
  const AActionIndex: Integer;
  const AStatus: string;
  const ADetails: string
);
var
  LDetails: string;
  LIndex: Integer;
begin
  LDetails := Copy(Trim(ADetails), 1, 1000);
  if RadIAVisualSessionEventKindName(AKind) = 'unknown' then
    raise EArgumentException.Create('Visual session event kind is invalid.');
  Inc(FSequence);
  if Length(FEvents) = CMaximumEventCount then
  begin
    for LIndex := 1 to High(FEvents) do
      FEvents[LIndex - 1] := FEvents[LIndex];
    SetLength(FEvents, Length(FEvents) - 1);
  end;
  SetLength(FEvents, Length(FEvents) + 1);
  FEvents[High(FEvents)] := TRadIAVisualSessionEvent.Create(
    FSequence,
    AKind,
    AActionIndex,
    Copy(Trim(AStatus), 1, 100),
    LDetails,
    FClock.UtcNow
  );
end;

procedure TRadIAVisualRuntimeSession.BeginSession(
  const ASession: TRadIARuntimeSessionIdentity
);
begin
  if not ASession.IsComplete then
    raise EArgumentException.Create(
      'A complete runtime session is required for visual evidence.'
    );
  TMonitor.Enter(FLock);
  try
    ClearUnlocked;
    FSession := ASession;
    FState := vssActive;
    Touch;
    AppendEvent(vsekSessionStarted, 0, 'active', 'Runtime visual session started.');
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAVisualRuntimeSession.Clear;
begin
  TMonitor.Enter(FLock);
  try
    ClearUnlocked;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAVisualRuntimeSession.ClearUnlocked;
begin
  FCaptures := nil;
  FEvents := nil;
  FExpiresAtUtc := 0;
  FSequence := 0;
  FSession := Default(TRadIARuntimeSessionIdentity);
  FState := vssCancelled;
  FTotalCaptureBytes := 0;
end;

function TRadIAVisualRuntimeSession.Complete(
  const ASessionId: string;
  const AState: TRadIAVisualSessionState;
  const ADetails: string
): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    PurgeIfExpired;
    Result := IsCurrentSession(ASessionId) and
      (FState = vssActive) and
      (AState in [vssCompleted, vssFailed, vssCancelled]);
    if not Result then
      Exit;
    FState := AState;
    AppendEvent(
      vsekSessionCompleted,
      0,
      RadIAVisualSessionStateName(AState),
      ADetails
    );
    Touch;
  finally
    TMonitor.Exit(FLock);
  end;
end;

constructor TRadIAVisualRuntimeSession.Create(
  const AClock: IRadIAVisualSessionClock
);
begin
  inherited Create;
  FLock := TObject.Create;
  if Assigned(AClock) then
    FClock := AClock
  else
    FClock := TRadIAVisualSessionClock.Create;
  ClearUnlocked;
end;

destructor TRadIAVisualRuntimeSession.Destroy;
begin
  FClock := nil;
  FLock.Free;
  inherited Destroy;
end;

function TRadIAVisualRuntimeSession.IsCurrentSession(
  const ASessionId: string
): Boolean;
begin
  Result := (FSession.SessionId <> '') and
    SameText(FSession.SessionId, Trim(ASessionId));
end;

procedure TRadIAVisualRuntimeSession.PurgeIfExpired;
begin
  if (FExpiresAtUtc > 0) and (FClock.UtcNow >= FExpiresAtUtc) then
    ClearUnlocked;
end;

function TRadIAVisualRuntimeSession.RecordCapture(
  const ASessionId: string;
  const ACapture: TRadIAVisualCapture
): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    PurgeIfExpired;
    Result := IsCurrentSession(ASessionId) and (FState = vssActive);
    if not Result then
      Exit;
    ValidateCapture(FSession, ACapture);
    if Length(FCaptures) >= CMaximumCaptureCount then
      raise EArgumentOutOfRangeException.Create(
        'A visual session accepts at most six captures.'
      );
    if FTotalCaptureBytes + Length(ACapture.Bytes) >
      CMaximumTotalCaptureBytes then
      raise EArgumentOutOfRangeException.Create(
        'Visual session captures exceed the 8 MiB retention limit.'
      );
    SetLength(FCaptures, Length(FCaptures) + 1);
    FCaptures[High(FCaptures)] := ACapture.Clone;
    Inc(FTotalCaptureBytes, Length(ACapture.Bytes));
    AppendEvent(
      vsekCaptureRecorded,
      0,
      RadIAVisualCapturePhaseName(ACapture.Phase),
      'A bounded runtime window capture was recorded.'
    );
    Touch;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAVisualRuntimeSession.RecordEvent(
  const ASessionId: string;
  const AKind: TRadIAVisualSessionEventKind;
  const AActionIndex: Integer;
  const AStatus: string;
  const ADetails: string
): Boolean;
begin
  if AKind in [vsekSessionStarted, vsekCaptureRecorded, vsekSessionCompleted] then
    raise EArgumentException.Create(
      'Lifecycle and capture events are recorded by their dedicated operations.'
    );
  if AActionIndex < 0 then
    raise EArgumentOutOfRangeException.Create(
      'Visual session action index cannot be negative.'
    );
  TMonitor.Enter(FLock);
  try
    PurgeIfExpired;
    Result := IsCurrentSession(ASessionId) and (FState = vssActive);
    if not Result then
      Exit;
    AppendEvent(AKind, AActionIndex, AStatus, ADetails);
    Touch;
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAVisualRuntimeSession.Touch;
begin
  FExpiresAtUtc := IncMinute(FClock.UtcNow, CRetentionMinutes);
end;

function TRadIAVisualRuntimeSession.TryGetSnapshot(
  out ASnapshot: TRadIAVisualSessionSnapshot
): Boolean;
begin
  ASnapshot := Default(TRadIAVisualSessionSnapshot);
  TMonitor.Enter(FLock);
  try
    PurgeIfExpired;
    Result := FSession.SessionId <> '';
    if Result then
      ASnapshot := TRadIAVisualSessionSnapshot.Create(
        FSession,
        FState,
        FEvents,
        FCaptures
      );
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAVisualRuntimeSession.TryGetCapture(
  const ACaptureId: string;
  out ACapture: TRadIAVisualCapture
): Boolean;
var
  LCapture: TRadIAVisualCapture;
begin
  ACapture := Default(TRadIAVisualCapture);
  TMonitor.Enter(FLock);
  try
    PurgeIfExpired;
    Result := False;
    for LCapture in FCaptures do
      if SameText(LCapture.CaptureId, Trim(ACaptureId)) then
      begin
        ACapture := LCapture.Clone;
        Exit(True);
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TRadIAVisualRuntimeSession.ValidateCapture(
  const ASession: TRadIARuntimeSessionIdentity;
  const ACapture: TRadIAVisualCapture
);
begin
  if (ACapture.CaptureId = '') or (ACapture.WindowId = '') then
    raise EArgumentException.Create(
      'Visual capture identity is required.'
    );
  if (ASession.ProcessId = 0) or
    (ACapture.ProcessId <> ASession.ProcessId) then
    raise EArgumentException.Create(
      'Visual capture must belong to the active runtime process.'
    );
  if not SameText(ACapture.MimeType, 'image/png') then
    raise EArgumentException.Create('Visual captures must use image/png.');
  if (ACapture.Width <= 0) or (ACapture.Width > CMaximumCaptureWidth) or
    (ACapture.Height <= 0) or (ACapture.Height > CMaximumCaptureHeight) then
    raise EArgumentOutOfRangeException.Create(
      'Visual capture dimensions exceed the bounded viewport.'
    );
  if (Length(ACapture.Bytes) = 0) or
    (Length(ACapture.Bytes) > CMaximumCaptureBytes) then
    raise EArgumentOutOfRangeException.Create(
      'Visual capture must contain at most 2 MiB.'
    );
  if ACapture.CapturedAtUtc <= 0 then
    raise EArgumentException.Create('Visual capture timestamp is required.');
end;

end.
