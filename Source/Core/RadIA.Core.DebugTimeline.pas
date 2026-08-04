unit RadIA.Core.DebugTimeline;

interface

uses
  System.Generics.Collections;

type
  TRadIADebugEventKind = (
    dekSessionStarting,
    dekProcessCreated,
    dekProcessStateChanged,
    dekCurrentProcessChanged,
    dekBreakpointAdded,
    dekBreakpointChanged,
    dekBreakpointDeleted,
    dekThreadCreated,
    dekThreadDestroyed,
    dekProcessMemoryChanged,
    dekProcessDestroyed
  );

  TRadIADebugEvent = record
  private
    FSequence: Int64;
    FTimestampUtc: string;
    FKind: TRadIADebugEventKind;
    FProcessId: LongWord;
    FState: string;
    FDetails: string;
  public
    constructor Create(
      const ASequence: Int64;
      const ATimestampUtc: string;
      const AKind: TRadIADebugEventKind;
      const AProcessId: LongWord;
      const AState: string;
      const ADetails: string
    );
    property Sequence: Int64 read FSequence;
    property TimestampUtc: string read FTimestampUtc;
    property Kind: TRadIADebugEventKind read FKind;
    property ProcessId: LongWord read FProcessId;
    property State: string read FState;
    property Details: string read FDetails;
  end;

  IRadIADebugTimeline = interface
    ['{C5C944DF-837A-4203-8AF5-84A8EA8B62CD}']
    procedure RecordEvent(
      const AKind: TRadIADebugEventKind;
      const AProcessId: LongWord;
      const AState: string;
      const ADetails: string
    );
    function ListEvents(
      const ASinceSequence: Int64;
      const AMaxCount: Integer
    ): TArray<TRadIADebugEvent>;
    function GetLastSequence: Int64;
  end;

  IRadIADebugTimelineStore = interface
    ['{BA94EC0A-5D27-45C9-80A5-A639700433EF}']
    procedure Append(const AEvent: TRadIADebugEvent);
  end;

  TRadIADebugTimeline = class(
    TInterfacedObject,
    IRadIADebugTimeline
  )
  private
    FEvents: TList<TRadIADebugEvent>;
    FLastSequence: Int64;
    FMaxEvents: Integer;
    FStore: IRadIADebugTimelineStore;
  public
    constructor Create(
      const AMaxEvents: Integer = 500;
      const AStore: IRadIADebugTimelineStore = nil
    );
    destructor Destroy; override;
    procedure RecordEvent(
      const AKind: TRadIADebugEventKind;
      const AProcessId: LongWord;
      const AState: string;
      const ADetails: string
    );
    function ListEvents(
      const ASinceSequence: Int64;
      const AMaxCount: Integer
    ): TArray<TRadIADebugEvent>;
    function GetLastSequence: Int64;
  end;

function RadIADebugEventKindName(
  const AKind: TRadIADebugEventKind
): string;

implementation

uses
  System.DateUtils,
  System.SysUtils;

constructor TRadIADebugEvent.Create(
  const ASequence: Int64;
  const ATimestampUtc: string;
  const AKind: TRadIADebugEventKind;
  const AProcessId: LongWord;
  const AState: string;
  const ADetails: string
);
begin
  FSequence := ASequence;
  FTimestampUtc := ATimestampUtc;
  FKind := AKind;
  FProcessId := AProcessId;
  FState := AState;
  FDetails := ADetails;
end;

constructor TRadIADebugTimeline.Create(
  const AMaxEvents: Integer;
  const AStore: IRadIADebugTimelineStore
);
begin
  inherited Create;
  if (AMaxEvents < 10) or (AMaxEvents > 10000) then
    raise EArgumentOutOfRangeException.Create(
      'Debug timeline capacity must be between 10 and 10000.'
    );
  FEvents := TList<TRadIADebugEvent>.Create;
  FMaxEvents := AMaxEvents;
  FStore := AStore;
end;

destructor TRadIADebugTimeline.Destroy;
begin
  FEvents.Free;
  inherited Destroy;
end;

function TRadIADebugTimeline.GetLastSequence: Int64;
begin
  TMonitor.Enter(FEvents);
  try
    Result := FLastSequence;
  finally
    TMonitor.Exit(FEvents);
  end;
end;

function TRadIADebugTimeline.ListEvents(
  const ASinceSequence: Int64;
  const AMaxCount: Integer
): TArray<TRadIADebugEvent>;
var
  LEvent: TRadIADebugEvent;
  LResult: TList<TRadIADebugEvent>;
begin
  if (AMaxCount < 1) or (AMaxCount > 500) then
    raise EArgumentOutOfRangeException.Create(
      'Debug timeline query limit must be between 1 and 500.'
    );
  LResult := TList<TRadIADebugEvent>.Create;
  try
    TMonitor.Enter(FEvents);
    try
      for LEvent in FEvents do
      begin
        if LEvent.Sequence <= ASinceSequence then
          Continue;
        LResult.Add(LEvent);
        if LResult.Count >= AMaxCount then
          Break;
      end;
    finally
      TMonitor.Exit(FEvents);
    end;
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

procedure TRadIADebugTimeline.RecordEvent(
  const AKind: TRadIADebugEventKind;
  const AProcessId: LongWord;
  const AState: string;
  const ADetails: string
);
var
  LEvent: TRadIADebugEvent;
begin
  TMonitor.Enter(FEvents);
  try
    Inc(FLastSequence);
    LEvent := TRadIADebugEvent.Create(
      FLastSequence,
      DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True),
      AKind,
      AProcessId,
      AState,
      ADetails
    );
    FEvents.Add(LEvent);
    while FEvents.Count > FMaxEvents do
      FEvents.Delete(0);
  finally
    TMonitor.Exit(FEvents);
  end;
  if Assigned(FStore) then
  begin
    try
      FStore.Append(LEvent);
    except
      // Debugger notifications must never be disrupted by audit I/O.
    end;
  end;
end;

function RadIADebugEventKindName(
  const AKind: TRadIADebugEventKind
): string;
begin
  case AKind of
    dekSessionStarting: Result := 'sessionStarting';
    dekProcessCreated: Result := 'processCreated';
    dekProcessStateChanged: Result := 'processStateChanged';
    dekCurrentProcessChanged: Result := 'currentProcessChanged';
    dekBreakpointAdded: Result := 'breakpointAdded';
    dekBreakpointChanged: Result := 'breakpointChanged';
    dekBreakpointDeleted: Result := 'breakpointDeleted';
    dekThreadCreated: Result := 'threadCreated';
    dekThreadDestroyed: Result := 'threadDestroyed';
    dekProcessMemoryChanged: Result := 'processMemoryChanged';
  else
    Result := 'processDestroyed';
  end;
end;

end.
