unit RadIA.OTA.DebugTimeline;

interface

uses
  ToolsAPI,
  RadIA.Core.DebugTimeline;

type
  TRadIAOTADebugTimelineNotifier = class(
    TNotifierObject,
    IOTADebuggerNotifier,
    IOTADebuggerNotifier110
  )
  private
    FTimeline: IRadIADebugTimeline;
    FNotifierIndex: Integer;
    function ProcessId(const AProcess: IOTAProcess): LongWord;
    function ProcessState(const AProcess: IOTAProcess): string;
    procedure RecordBreakpoint(
      const AKind: TRadIADebugEventKind;
      const ABreakpoint: IOTABreakpoint
    );
  public
    constructor Create(const ATimeline: IRadIADebugTimeline);
    procedure Install;
    procedure Uninstall;
    procedure ProcessCreated(const Process: IOTAProcess);
    procedure ProcessDestroyed(const Process: IOTAProcess);
    procedure BreakpointAdded(const Breakpoint: IOTABreakpoint);
    procedure BreakpointDeleted(const Breakpoint: IOTABreakpoint);
    procedure BreakpointChanged(const Breakpoint: IOTABreakpoint);
    procedure CurrentProcessChanged(const Process: IOTAProcess);
    procedure ProcessStateChanged(const Process: IOTAProcess);
    function BeforeProgramLaunch(const Project: IOTAProject): Boolean;
    procedure ProcessMemoryChanged; overload;
    procedure ProcessMemoryChanged(EIPChanged: Boolean); overload;
    procedure DebuggerOptionsChanged;
  end;

implementation

uses
  System.SysUtils;

constructor TRadIAOTADebugTimelineNotifier.Create(
  const ATimeline: IRadIADebugTimeline
);
begin
  inherited Create;
  if not Assigned(ATimeline) then
    raise EArgumentNilException.Create('ATimeline');
  FTimeline := ATimeline;
  FNotifierIndex := -1;
end;

function TRadIAOTADebugTimelineNotifier.BeforeProgramLaunch(
  const Project: IOTAProject
): Boolean;
var
  LDetails: string;
begin
  LDetails := '';
  if Assigned(Project) then
    LDetails := Project.FileName;
  FTimeline.RecordEvent(dekSessionStarting, 0, 'starting', LDetails);
  Result := True;
end;

procedure TRadIAOTADebugTimelineNotifier.BreakpointAdded(
  const Breakpoint: IOTABreakpoint
);
begin
  RecordBreakpoint(dekBreakpointAdded, Breakpoint);
end;

procedure TRadIAOTADebugTimelineNotifier.BreakpointChanged(
  const Breakpoint: IOTABreakpoint
);
begin
  RecordBreakpoint(dekBreakpointChanged, Breakpoint);
end;

procedure TRadIAOTADebugTimelineNotifier.BreakpointDeleted(
  const Breakpoint: IOTABreakpoint
);
begin
  RecordBreakpoint(dekBreakpointDeleted, Breakpoint);
end;

procedure TRadIAOTADebugTimelineNotifier.CurrentProcessChanged(
  const Process: IOTAProcess
);
begin
  FTimeline.RecordEvent(
    dekCurrentProcessChanged,
    ProcessId(Process),
    ProcessState(Process),
    ''
  );
end;

procedure TRadIAOTADebugTimelineNotifier.DebuggerOptionsChanged;
begin
  // Debugger option changes do not alter the execution timeline.
end;

procedure TRadIAOTADebugTimelineNotifier.Install;
var
  LDebugger: IOTADebuggerServices;
  LNotifier: IOTADebuggerNotifier;
begin
  if FNotifierIndex >= 0 then
    Exit;
  if Supports(BorlandIDEServices, IOTADebuggerServices, LDebugger) then
  begin
    LNotifier := Self;
    FNotifierIndex := LDebugger.AddNotifier(LNotifier);
  end;
end;

function TRadIAOTADebugTimelineNotifier.ProcessId(
  const AProcess: IOTAProcess
): LongWord;
begin
  Result := 0;
  if Assigned(AProcess) then
    Result := AProcess.ProcessId;
end;

procedure TRadIAOTADebugTimelineNotifier.ProcessCreated(
  const Process: IOTAProcess
);
begin
  FTimeline.RecordEvent(
    dekProcessCreated,
    ProcessId(Process),
    ProcessState(Process),
    ''
  );
end;

procedure TRadIAOTADebugTimelineNotifier.ProcessDestroyed(
  const Process: IOTAProcess
);
begin
  FTimeline.RecordEvent(
    dekProcessDestroyed,
    ProcessId(Process),
    ProcessState(Process),
    ''
  );
end;

procedure TRadIAOTADebugTimelineNotifier.ProcessMemoryChanged;
begin
  FTimeline.RecordEvent(dekProcessMemoryChanged, 0, '', 'memory');
end;

procedure TRadIAOTADebugTimelineNotifier.ProcessMemoryChanged(
  EIPChanged: Boolean
);
begin
  FTimeline.RecordEvent(
    dekProcessMemoryChanged,
    0,
    '',
    BoolToStr(EIPChanged, True)
  );
end;

function TRadIAOTADebugTimelineNotifier.ProcessState(
  const AProcess: IOTAProcess
): string;
begin
  if not Assigned(AProcess) then
    Exit('noProcess');
  case AProcess.ProcessState of
    psNothing: Result := 'nothing';
    psRunning: Result := 'running';
    psStopping: Result := 'stopping';
    psStopped: Result := 'stopped';
    psFault: Result := 'fault';
    psResFault: Result := 'resourceFault';
    psTerminated: Result := 'terminated';
    psException: Result := 'exception';
    psNoProcess: Result := 'noProcess';
  else
    Result := 'unknown';
  end;
end;

procedure TRadIAOTADebugTimelineNotifier.ProcessStateChanged(
  const Process: IOTAProcess
);
begin
  FTimeline.RecordEvent(
    dekProcessStateChanged,
    ProcessId(Process),
    ProcessState(Process),
    ''
  );
end;

procedure TRadIAOTADebugTimelineNotifier.RecordBreakpoint(
  const AKind: TRadIADebugEventKind;
  const ABreakpoint: IOTABreakpoint
);
var
  LDetails: string;
  LSource: IOTASourceBreakpoint;
begin
  LDetails := '';
  if Supports(ABreakpoint, IOTASourceBreakpoint, LSource) then
    LDetails := Format(
      '%s:%d',
      [LSource.FileName, LSource.LineNumber]
    );
  FTimeline.RecordEvent(AKind, 0, '', LDetails);
end;

procedure TRadIAOTADebugTimelineNotifier.Uninstall;
var
  LDebugger: IOTADebuggerServices;
begin
  if FNotifierIndex < 0 then
    Exit;
  if Supports(BorlandIDEServices, IOTADebuggerServices, LDebugger) then
    LDebugger.RemoveNotifier(FNotifierIndex);
  FNotifierIndex := -1;
end;

end.
