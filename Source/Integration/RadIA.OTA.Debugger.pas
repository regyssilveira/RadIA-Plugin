unit RadIA.OTA.Debugger;

interface

uses
  System.Classes,
  RadIA.Core.Debugger;

type
  TRadIAOTADebuggerFacade = class(
    TInterfacedObject,
    IRadIADebuggerFacade,
    IRadIADebuggerRuntimeFacade,
    IRadIADebuggerControlFacade,
    IRadIADebuggerBreakpointFacade,
    IRadIADebuggerEvaluationFacade,
    IRadIADebuggerSessionFacade
  )
  private
    procedure RunOnMainThread(const AAction: TThreadProcedure);
  public
    function GetDebuggerState: TRadIADebuggerSnapshot;
    function ListBreakpoints(
      const AMaxCount: Integer
    ): TArray<TRadIABreakpointSnapshot>;
    function GetCallStack(
      const AMaxCount: Integer
    ): TRadIACallStackSnapshot;
    function ResolveRuntimeProcess(
      out AProcessId: LongWord;
      out ACreatedAtUtc: TDateTime;
      out AExecutablePath: string;
      out ABuildId: string
    ): Boolean;
    function ExecuteAction(
      const AAction: TRadIADebuggerAction
    ): TRadIADebuggerActionResult;
    function HasSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer
    ): Boolean;
    function AddSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer
    ): Boolean;
    function RemoveSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer
    ): Boolean;
    function GetBreakpointCapabilities:
      TRadIADebuggerBreakpointCapabilities;
    function GetSourceBreakpointConfiguration(
      const AFileName: string;
      const ALineNumber: Integer;
      out AConfiguration: TRadIABreakpointConfiguration;
      out AError: string
    ): Boolean;
    function ConfigureSourceBreakpoint(
      const AFileName: string;
      const ALineNumber: Integer;
      const AConfiguration: TRadIABreakpointConfiguration;
      out APrevious: TRadIABreakpointConfiguration;
      out AError: string
    ): Boolean;
    function EvaluateExpression(
      const AExpression: string
    ): TRadIADebugValueSnapshot;
    function StartDebugging: TRadIADebuggerActionResult;
    function StartRuntimeProcess(
      out AProcessId: LongWord;
      out ACreatedAtUtc: TDateTime;
      out AExecutablePath: string;
      out ABuildId: string
    ): TRadIADebuggerActionResult;
    function StopRuntimeProcess(const AProcessId: LongWord): Boolean;
  end;

implementation

uses
  System.Actions,
  System.DateUtils,
  System.Math,
  System.SysUtils,
  System.Variants,
  ToolsAPI,
  Vcl.ActnList,
  Vcl.Menus,
  Winapi.Windows,
  RadIA.Core.Logger,
  RadIA.Core.Types,
  RadIA.OTA.RuntimeProcess;

const
  CDebuggerUnavailable = 'The debugger is shutting down.';

function ReadBreakpointConfiguration(
  const ABreakpoint: IOTASourceBreakpoint
): TRadIABreakpointConfiguration;
begin
  Result.Condition := ABreakpoint.Expression;
  Result.HitCount := ABreakpoint.PassCount;
  Result.DoBreak := ABreakpoint.DoBreak;
  Result.LogMessage := ABreakpoint.LogMessage;
  Result.EvaluateExpression := ABreakpoint.EvalExpression;
  Result.LogResult := ABreakpoint.LogResult;
  Result.StackFramesToLog := ABreakpoint.StackFramesToLog;
  Result.ThreadCondition := ABreakpoint.ThreadCondition;
end;

procedure ApplyBreakpointConfiguration(
  const ABreakpoint: IOTASourceBreakpoint;
  const AConfiguration: TRadIABreakpointConfiguration
);
begin
  ABreakpoint.Expression := AConfiguration.Condition;
  ABreakpoint.PassCount := AConfiguration.HitCount;
  ABreakpoint.DoBreak := AConfiguration.DoBreak;
  ABreakpoint.LogMessage := AConfiguration.LogMessage;
  ABreakpoint.EvalExpression := AConfiguration.EvaluateExpression;
  ABreakpoint.LogResult := AConfiguration.LogResult;
  ABreakpoint.StackFramesToLog := AConfiguration.StackFramesToLog;
  ABreakpoint.ThreadCondition := AConfiguration.ThreadCondition;
end;

function FindIDEAction(
  const AActionNames: array of string
): TBasicAction;
var
  LAction: TContainedAction;
  LActionIndex: Integer;
  LActionList: TCustomActionList;
  LNameIndex: Integer;
  LServices: INTAServices;
begin
  Result := nil;
  if not Supports(BorlandIDEServices, INTAServices, LServices) then
    Exit;
  LActionList := LServices.ActionList;
  if not Assigned(LActionList) then
    Exit;

  for LNameIndex := Low(AActionNames) to High(AActionNames) do
    for LActionIndex := 0 to LActionList.ActionCount - 1 do
    begin
      LAction := LActionList[LActionIndex];
      if Assigned(LAction) and
        SameText(LAction.Name, AActionNames[LNameIndex]) then
        Exit(LAction);
    end;
end;

function FindMenuItemForAction(
  const ARoot: TMenuItem;
  const AAction: TBasicAction
): TMenuItem;
var
  LIndex: Integer;
begin
  Result := nil;
  if not Assigned(ARoot) then
    Exit;
  if ARoot.Action = AAction then
    Exit(ARoot);
  for LIndex := 0 to ARoot.Count - 1 do
  begin
    Result := FindMenuItemForAction(ARoot[LIndex], AAction);
    if Assigned(Result) then
      Exit;
  end;
end;

function ExecuteIDEActionThroughMenu(
  const AAction: TBasicAction
): Boolean;
var
  LMenuItem: TMenuItem;
  LServices: INTAServices;
begin
  Result := False;
  if not Supports(BorlandIDEServices, INTAServices, LServices) or
    not Assigned(LServices.MainMenu) then
    Exit;
  LMenuItem := FindMenuItemForAction(
    LServices.MainMenu.Items,
    AAction
  );
  if not Assigned(LMenuItem) then
    Exit;
  LMenuItem.Click;
  Result := True;
end;

function ProcessStateToString(
  const AState: TOTAProcessState
): string;
begin
  case AState of
    psNothing:
      Result := 'nothing';
    psRunning:
      Result := 'running';
    psStopping:
      Result := 'stopping';
    psStopped:
      Result := 'stopped';
    psFault:
      Result := 'fault';
    psResFault:
      Result := 'resource_fault';
    psTerminated:
      Result := 'terminated';
    psException:
      Result := 'exception';
    psNoProcess:
      Result := 'no_process';
  else
    Result := 'unknown';
  end;
end;

function EvaluateResultToString(
  const AResult: TOTAEvaluateResult
): string;
begin
  case AResult of
    erOK:
      Result := 'ok';
    erError:
      Result := 'error';
    erDeferred:
      Result := 'deferred';
    erBusy:
      Result := 'busy';
  else
    Result := 'unknown';
  end;
end;

function FindSourceBreakpoint(
  const ADebugger: IOTADebuggerServices;
  const AFileName: string;
  const ALineNumber: Integer;
  out ABreakpoint: IOTASourceBreakpoint
): Boolean;
var
  LIndex: Integer;
begin
  ABreakpoint := nil;
  for LIndex := 0 to ADebugger.SourceBkptCount - 1 do
  begin
    ABreakpoint := ADebugger.SourceBkpts[LIndex];
    if Assigned(ABreakpoint) and
      SameFileName(ABreakpoint.FileName, AFileName) and
      (ABreakpoint.LineNumber = ALineNumber) then
      Exit(True);
  end;
  ABreakpoint := nil;
  Result := False;
end;

function DebuggerActionStateIsValid(
  const AProcess: IOTAProcess;
  const AAction: TRadIADebuggerAction;
  const AStateBefore: string;
  out AFailure: TRadIADebuggerActionResult
): Boolean;
begin
  Result := False;
  case AAction of
    daPause:
      if AProcess.ProcessState <> psRunning then
      begin
        AFailure := TRadIADebuggerActionResult.Failed(
          'invalid_debugger_state',
          'Pause requires a running debug process.',
          AStateBefore
        );
        Exit;
      end;
    daContinue,
    daStepInto,
    daStepOver,
    daStepOut:
      if not (AProcess.ProcessState in [psStopped, psException]) then
      begin
        AFailure := TRadIADebuggerActionResult.Failed(
          'invalid_debugger_state',
          'Continue and step actions require a stopped debug process.',
          AStateBefore
        );
        Exit;
      end;
    daStop:
      if AProcess.ProcessState in [
        psTerminated,
        psNoProcess,
        psNothing
      ] then
      begin
        AFailure := TRadIADebuggerActionResult.Failed(
          'invalid_debugger_state',
          'The debug process is not active.',
          AStateBefore
        );
        Exit;
      end;
  end;
  Result := True;
end;

function ExecuteProcessAction(
  const AProcess: IOTAProcess;
  const AAction: TRadIADebuggerAction
): TRadIADebuggerActionResult;
var
  LStateBefore: string;
begin
  LStateBefore := ProcessStateToString(AProcess.ProcessState);
  if not DebuggerActionStateIsValid(
    AProcess,
    AAction,
    LStateBefore,
    Result
  ) then
    Exit;
  try
    case AAction of
      daPause:
        AProcess.Pause;
      daContinue:
        AProcess.Run(ormRun);
      daStepInto:
        AProcess.Run(ormStmtStepInto);
      daStepOver:
        AProcess.Run(ormStmtStepOver);
      daStepOut:
        AProcess.Run(ormRunUntilReturn);
      daStop:
        AProcess.Terminate;
    end;
    if AAction = daStop then
      Result := TRadIADebuggerActionResult.Succeeded(
        'The debugger accepted the requested action.',
        LStateBefore,
        'terminated'
      )
    else
      Result := TRadIADebuggerActionResult.Succeeded(
        'The debugger accepted the requested action.',
        LStateBefore,
        ProcessStateToString(AProcess.ProcessState)
      );
  except
    on E: Exception do
      Result := TRadIADebuggerActionResult.Failed(
        'debugger_action_failed',
        E.Message,
        LStateBefore
      );
  end;
end;

function TryGetDebugProject(
  out ADebugger: IOTADebuggerServices;
  out AProject: IOTAProject;
  out AFailure: TRadIADebuggerActionResult
): Boolean;
var
  LModuleServices: IOTAModuleServices;
  LProcess: IOTAProcess;
begin
  AFailure := TRadIADebuggerActionResult.Failed(
    'debugger_unavailable',
    'The IDE debugger is unavailable.',
    'unknown'
  );
  Result := Supports(
    BorlandIDEServices,
    IOTADebuggerServices,
    ADebugger
  ) and Supports(
    BorlandIDEServices,
    IOTAModuleServices,
    LModuleServices
  );
  if not Result then
    Exit;
  LProcess := ADebugger.CurrentProcess;
  if Assigned(LProcess) and
    not (LProcess.ProcessState in [
      psNothing,
      psTerminated,
      psNoProcess
    ]) then
  begin
    AFailure := TRadIADebuggerActionResult.Failed(
      'debug_process_active',
      'A debug process is already active.',
      ProcessStateToString(LProcess.ProcessState)
    );
    Exit(False);
  end;
  AProject := LModuleServices.GetActiveProject;
  Result := Assigned(AProject) and
    Assigned(AProject.ProjectBuilder) and
    Assigned(AProject.ProjectOptions);
  if not Result then
    AFailure := TRadIADebuggerActionResult.Failed(
      'project_unavailable',
      'There is no buildable active project.',
      'no_process'
    );
end;

function StartDebugProject(
  const AProject: IOTAProject
): TRadIADebuggerActionResult;
var
  LAction: TBasicAction;
  LTargetName: string;
begin
  try
    LAction := FindIDEAction([
      'RunRunCommand',
      'ProjectRunCommand',
      'DebuggerRunCommand',
      'RunCommand',
      'RunProjectCommand'
    ]);
    if not Assigned(LAction) then
      Exit(TRadIADebuggerActionResult.Failed(
        'debugger_action_unavailable',
        'The IDE Run action is unavailable.',
        'no_process'
      ));
    if not Assigned(AProject.ProjectBuilder) then
      Exit(TRadIADebuggerActionResult.Failed(
        'project_builder_unavailable',
        'The active project cannot be run by the IDE.',
        'no_process'
      ));
    LTargetName := AProject.ProjectOptions.TargetName;
    TLogger.Log(
      Format(
        'Queueing debugger action: name=%s; class=%s; target=%s',
        [LAction.Name, LAction.ClassName, LTargetName]
      ),
      'Debugger'
    );
    TThread.CreateAnonymousThread(
      procedure
      begin
        Sleep(250);
        TThread.ForceQueue(
          nil,
          procedure
          begin
            try
              if not ExecuteIDEActionThroughMenu(LAction) then
                TLogger.Log(
                  'The queued debugger action was rejected by the IDE.',
                  'Debugger'
                );
            except
              on E: Exception do
                TLogger.Log(
                  'The queued debugger action failed: ' + E.Message,
                  'Debugger'
                );
            end;
          end
        );
      end
    ).Start;
    Result := TRadIADebuggerActionResult.Succeeded(
      'The IDE accepted the active project debug request.',
      'no_process',
      'starting'
    );
  except
    on E: Exception do
      Result := TRadIADebuggerActionResult.Failed(
        'debugger_start_failed',
        E.Message,
        'no_process'
      );
  end;
end;

{ TRadIAOTADebuggerFacade }

function TRadIAOTADebuggerFacade.AddSourceBreakpoint(
  const AFileName: string;
  const ALineNumber: Integer
): Boolean;
var
  LResult: Boolean;
begin
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LBreakpoint: IOTABreakpoint;
      LExisting: IOTASourceBreakpoint;
      LDebugger: IOTADebuggerServices;
    begin
      if not Supports(
        BorlandIDEServices,
        IOTADebuggerServices,
        LDebugger
      ) then
        Exit;
      if FindSourceBreakpoint(
        LDebugger,
        AFileName,
        ALineNumber,
        LExisting
      ) then
        Exit;

      LBreakpoint := LDebugger.NewSourceBreakpoint(
        AFileName,
        ALineNumber,
        nil
      );
      LResult := Assigned(LBreakpoint);
    end
  );
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.GetBreakpointCapabilities:
  TRadIADebuggerBreakpointCapabilities;
var
  LResult: TRadIADebuggerBreakpointCapabilities;
begin
  LResult := TRadIADebuggerBreakpointCapabilities.Create(
    False,
    False,
    False,
    False,
    False,
    False,
    False
  );
  RunOnMainThread(
    procedure
    var
      LDebugger: IOTADebuggerServices;
    begin
      if Supports(BorlandIDEServices, IOTADebuggerServices, LDebugger) then
        LResult := TRadIADebuggerBreakpointCapabilities.Create(
          True,
          True,
          True,
          True,
          True,
          True,
          False
        );
    end
  );
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.GetSourceBreakpointConfiguration(
  const AFileName: string;
  const ALineNumber: Integer;
  out AConfiguration: TRadIABreakpointConfiguration;
  out AError: string
): Boolean;
var
  LConfiguration: TRadIABreakpointConfiguration;
  LError: string;
  LResult: Boolean;
begin
  LError := '';
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LBreakpoint: IOTASourceBreakpoint;
      LDebugger: IOTADebuggerServices;
    begin
      if not Supports(BorlandIDEServices, IOTADebuggerServices, LDebugger) then
      begin
        LError := 'The IDE debugger service is unavailable.';
        Exit;
      end;
      if not FindSourceBreakpoint(
        LDebugger,
        AFileName,
        ALineNumber,
        LBreakpoint
      ) then
      begin
        LError := 'No source breakpoint exists at this location.';
        Exit;
      end;
      LConfiguration := ReadBreakpointConfiguration(LBreakpoint);
      LResult := True;
    end
  );
  AConfiguration := LConfiguration;
  AError := LError;
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.ConfigureSourceBreakpoint(
  const AFileName: string;
  const ALineNumber: Integer;
  const AConfiguration: TRadIABreakpointConfiguration;
  out APrevious: TRadIABreakpointConfiguration;
  out AError: string
): Boolean;
var
  LError: string;
  LPrevious: TRadIABreakpointConfiguration;
  LResult: Boolean;
begin
  LError := '';
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LBreakpoint: IOTASourceBreakpoint;
      LDebugger: IOTADebuggerServices;
    begin
      if not Supports(BorlandIDEServices, IOTADebuggerServices, LDebugger) then
      begin
        LError := 'The IDE debugger service is unavailable.';
        Exit;
      end;
      if not FindSourceBreakpoint(
        LDebugger,
        AFileName,
        ALineNumber,
        LBreakpoint
      ) then
      begin
        LError := 'No source breakpoint exists at this location.';
        Exit;
      end;
      LPrevious := ReadBreakpointConfiguration(LBreakpoint);
      try
        ApplyBreakpointConfiguration(LBreakpoint, AConfiguration);
        LResult := True;
      except
        on E: Exception do
        begin
          ApplyBreakpointConfiguration(LBreakpoint, LPrevious);
          LError := E.Message;
        end;
      end;
    end
  );
  APrevious := LPrevious;
  AError := LError;
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.ExecuteAction(
  const AAction: TRadIADebuggerAction
): TRadIADebuggerActionResult;
var
  LResult: TRadIADebuggerActionResult;
begin
  LResult := TRadIADebuggerActionResult.Failed(
    'debugger_unavailable',
    'The IDE debugger is unavailable.',
    'unknown'
  );
  RunOnMainThread(
    procedure
    var
      LDebugger: IOTADebuggerServices;
      LProcess: IOTAProcess;
    begin
      if not Supports(
        BorlandIDEServices,
        IOTADebuggerServices,
        LDebugger
      ) then
        Exit;
      LProcess := LDebugger.CurrentProcess;
      if not Assigned(LProcess) then
      begin
        LResult := TRadIADebuggerActionResult.Failed(
          'no_debug_process',
          'There is no active debug process.',
          'no_process'
        );
        Exit;
      end;
      LResult := ExecuteProcessAction(LProcess, AAction);
    end
  );
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.EvaluateExpression(
  const AExpression: string
): TRadIADebugValueSnapshot;
const
  CResultBufferSize = 16384;
var
  LResult: TRadIADebugValueSnapshot;
begin
  LResult := TRadIADebugValueSnapshot.Create(
    AExpression,
    '',
    'unavailable',
    False,
    0,
    0
  );
  RunOnMainThread(
    procedure
    var
      LAddress: TOTAAddress;
      LBuffer: TArray<Char>;
      LCanModify: Boolean;
      LDebugger: IOTADebuggerServices;
      LEvaluateResult: TOTAEvaluateResult;
      LProcess: IOTAProcess;
      LResultSize: LongWord;
      LResultValue: LongWord;
      LThread: IOTAThread;
    begin
      if not Supports(
        BorlandIDEServices,
        IOTADebuggerServices,
        LDebugger
      ) then
        Exit;
      LProcess := LDebugger.CurrentProcess;
      if not Assigned(LProcess) or
        not (LProcess.ProcessState in [psStopped, psException]) then
      begin
        LResult := TRadIADebugValueSnapshot.Create(
          AExpression,
          '',
          'process_not_stopped',
          False,
          0,
          0
        );
        Exit;
      end;
      LThread := LProcess.CurrentThread;
      if not Assigned(LThread) then
        Exit;
      SetLength(LBuffer, CResultBufferSize);
      FillChar(LBuffer[0], CResultBufferSize * SizeOf(Char), 0);
      LAddress := 0;
      LResultSize := 0;
      LResultValue := 0;
      LCanModify := False;
      LEvaluateResult := LThread.Evaluate(
        AExpression,
        PChar(LBuffer),
        CResultBufferSize,
        LCanModify,
        eseNone,
        nil,
        LAddress,
        LResultSize,
        LResultValue,
        LThread.CurrentFile,
        LThread.CurrentLine
      );
      LResult := TRadIADebugValueSnapshot.Create(
        AExpression,
        PChar(LBuffer),
        EvaluateResultToString(LEvaluateResult),
        LCanModify and (LEvaluateResult = erOK),
        LAddress,
        LResultSize
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.GetCallStack(
  const AMaxCount: Integer
): TRadIACallStackSnapshot;
var
  LResult: TRadIACallStackSnapshot;
begin
  LResult := TRadIACallStackSnapshot.Create(False, 'unavailable', nil);
  RunOnMainThread(
    procedure
    var
      LAccessState: TOTACallStackState;
      LCount: Integer;
      LFileName: string;
      LFrames: TArray<TRadIACallStackFrame>;
      LIndex: Integer;
      LLineNumber: Integer;
      LDebugger: IOTADebuggerServices;
      LProcess: IOTAProcess;
      LThread: IOTAThread;
    begin
      if AMaxCount <= 0 then
        Exit;
      if not Supports(
        BorlandIDEServices,
        IOTADebuggerServices,
        LDebugger
      ) then
        Exit;

      LProcess := LDebugger.CurrentProcess;
      if not Assigned(LProcess) then
      begin
        LResult := TRadIACallStackSnapshot.Create(
          False,
          'no_process',
          nil
        );
        Exit;
      end;
      LThread := LProcess.CurrentThread;
      if not Assigned(LThread) then
      begin
        LResult := TRadIACallStackSnapshot.Create(
          False,
          'no_thread',
          nil
        );
        Exit;
      end;

      LAccessState := LThread.StartCallStackAccess;
      case LAccessState of
        csInaccessible:
          LResult := TRadIACallStackSnapshot.Create(
            False,
            'inaccessible',
            nil
          );
        csWait:
          LResult := TRadIACallStackSnapshot.Create(
            False,
            'temporarily_unavailable',
            nil
          );
        csAccessible:
        begin
          try
            LCount := Min(LThread.CallCount, AMaxCount);
            SetLength(LFrames, LCount);
            for LIndex := 1 to LCount do
            begin
              LFileName := '';
              LLineNumber := 0;
              LThread.GetCallPos(
                LIndex,
                LFileName,
                LLineNumber
              );
              LFrames[LIndex - 1] := TRadIACallStackFrame.Create(
                LIndex,
                LThread.CallHeaders[LIndex],
                LFileName,
                LLineNumber
              );
            end;
            LResult := TRadIACallStackSnapshot.Create(
              True,
              'accessible',
              LFrames
            );
          finally
            LThread.EndCallStackAccess;
          end;
        end;
      end;
    end
  );
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.GetDebuggerState:
  TRadIADebuggerSnapshot;
var
  LResult: TRadIADebuggerSnapshot;
begin
  LResult := Default(TRadIADebuggerSnapshot);
  RunOnMainThread(
    procedure
    var
      LDebugger: IOTADebuggerServices;
      LProcess: IOTAProcess;
    begin
      if not Supports(
        BorlandIDEServices,
        IOTADebuggerServices,
        LDebugger
      ) then
        Exit;

      LProcess := LDebugger.CurrentProcess;
      if not Assigned(LProcess) then
      begin
        LResult := TRadIADebuggerSnapshot.Create(
          True,
          'no_process',
          0,
          '',
          0,
          LDebugger.SourceBkptCount
        );
        Exit;
      end;

      LResult := TRadIADebuggerSnapshot.Create(
        True,
        ProcessStateToString(LProcess.ProcessState),
        LProcess.ProcessId,
        LProcess.ExeName,
        LProcess.ThreadCount,
        LDebugger.SourceBkptCount
      );
      LResult.SetProcessDetails(
        LProcess.OSProcessId,
        LProcess.Location,
        LProcess.Status
      );
    end
  );
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.HasSourceBreakpoint(
  const AFileName: string;
  const ALineNumber: Integer
): Boolean;
var
  LResult: Boolean;
begin
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LBreakpoint: IOTASourceBreakpoint;
      LDebugger: IOTADebuggerServices;
    begin
      if Supports(
        BorlandIDEServices,
        IOTADebuggerServices,
        LDebugger
      ) then
        LResult := FindSourceBreakpoint(
          LDebugger,
          AFileName,
          ALineNumber,
          LBreakpoint
        );
    end
  );
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.ListBreakpoints(
  const AMaxCount: Integer
): TArray<TRadIABreakpointSnapshot>;
var
  LResult: TArray<TRadIABreakpointSnapshot>;
begin
  SetLength(LResult, 0);
  RunOnMainThread(
    procedure
    var
      LBreakpoint: IOTASourceBreakpoint;
      LCount: Integer;
      LDebugger: IOTADebuggerServices;
      LIndex: Integer;
      LSnapshot: TRadIABreakpointSnapshot;
    begin
      if AMaxCount <= 0 then
        Exit;
      if not Supports(
        BorlandIDEServices,
        IOTADebuggerServices,
        LDebugger
      ) then
        Exit;

      LCount := Min(LDebugger.SourceBkptCount, AMaxCount);
      SetLength(LResult, LCount);
      for LIndex := 0 to LCount - 1 do
      begin
        LBreakpoint := LDebugger.SourceBkpts[LIndex];
        if Assigned(LBreakpoint) then
        begin
          LSnapshot := TRadIABreakpointSnapshot.Create(
            LBreakpoint.FileName,
            LBreakpoint.LineNumber,
            LBreakpoint.Enabled,
            LBreakpoint.ValidInCurrentProcess
          );
          LSnapshot.SetAdvanced(
            LBreakpoint.Expression,
            LBreakpoint.PassCount,
            LBreakpoint.CurPassCount,
            LBreakpoint.DoBreak,
            LBreakpoint.LogMessage,
            LBreakpoint.EvalExpression,
            LBreakpoint.LogResult
          );
          LSnapshot.SetAdvancedContext(
            LBreakpoint.StackFramesToLog,
            LBreakpoint.ThreadCondition
          );
          LResult[LIndex] := LSnapshot;
        end;
      end;
    end
  );
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.RemoveSourceBreakpoint(
  const AFileName: string;
  const ALineNumber: Integer
): Boolean;
var
  LResult: Boolean;
begin
  LResult := False;
  RunOnMainThread(
    procedure
    var
      LBreakpoint: IOTASourceBreakpoint;
      LDebugger: IOTADebuggerServices;
    begin
      if not Supports(
        BorlandIDEServices,
        IOTADebuggerServices,
        LDebugger
      ) then
        Exit;
      if not FindSourceBreakpoint(
        LDebugger,
        AFileName,
        ALineNumber,
        LBreakpoint
      ) then
        Exit;

      LDebugger.RemoveBreakpoint(LBreakpoint);
      LResult := not FindSourceBreakpoint(
        LDebugger,
        AFileName,
        ALineNumber,
        LBreakpoint
      );
    end
  );
  Result := LResult;
end;

procedure TRadIAOTADebuggerFacade.RunOnMainThread(
  const AAction: TThreadProcedure
);
begin
  if GIsShuttingDown then
    raise EInvalidOperation.Create(CDebuggerUnavailable);

  if GetCurrentThreadId = MainThreadID then
    AAction()
  else
    TThread.Synchronize(nil, AAction);
end;

function TRadIAOTADebuggerFacade.StartDebugging:
  TRadIADebuggerActionResult;
var
  LResult: TRadIADebuggerActionResult;
begin
  LResult := TRadIADebuggerActionResult.Failed(
    'debugger_unavailable',
    'The IDE debugger is unavailable.',
    'unknown'
  );
  RunOnMainThread(
    procedure
    var
      LDebugger: IOTADebuggerServices;
      LProject: IOTAProject;
    begin
      if TryGetDebugProject(LDebugger, LProject, LResult) then
        LResult := StartDebugProject(LProject);
    end
  );
  Result := LResult;
end;

function TRadIAOTADebuggerFacade.StartRuntimeProcess(
  out AProcessId: LongWord;
  out ACreatedAtUtc: TDateTime;
  out AExecutablePath: string;
  out ABuildId: string
): TRadIADebuggerActionResult;
var
  LArguments: string;
  LCommandLine: string;
  LExecutablePath: string;
  LProcessInfo: TProcessInformation;
  LStartupInfo: TStartupInfo;
begin
  AProcessId := 0;
  ACreatedAtUtc := 0;
  AExecutablePath := '';
  ABuildId := '';
  LArguments := '';
  LExecutablePath := '';
  RunOnMainThread(
    procedure
    var
      LModuleServices: IOTAModuleServices;
      LProject: IOTAProject;
    begin
      if not Supports(
        BorlandIDEServices,
        IOTAModuleServices,
        LModuleServices
      ) then
        Exit;
      LProject := LModuleServices.GetActiveProject;
      if not Assigned(LProject) or
        not Assigned(LProject.ProjectOptions) then
        Exit;
      LExecutablePath := LProject.ProjectOptions.TargetName;
      LArguments := VarToStr(
        LProject.ProjectOptions.Values['Debugger_RunParams']
      );
    end
  );
  if LExecutablePath.IsEmpty or not FileExists(LExecutablePath) then
    Exit(TRadIADebuggerActionResult.Failed(
      'runtime_target_unavailable',
      'The built runtime target is unavailable.',
      'no_process'
    ));
  LCommandLine := '"' + LExecutablePath + '"';
  if not LArguments.IsEmpty then
    LCommandLine := LCommandLine + ' ' + LArguments;
  ZeroMemory(@LStartupInfo, SizeOf(LStartupInfo));
  LStartupInfo.cb := SizeOf(LStartupInfo);
  ZeroMemory(@LProcessInfo, SizeOf(LProcessInfo));
  if not Winapi.Windows.CreateProcess(
    PChar(LExecutablePath),
    PChar(LCommandLine),
    nil,
    nil,
    False,
    CREATE_NEW_PROCESS_GROUP,
    nil,
    PChar(ExtractFilePath(LExecutablePath)),
    LStartupInfo,
    LProcessInfo
  ) then
    Exit(TRadIADebuggerActionResult.Failed(
      'runtime_start_failed',
      SysErrorMessage(GetLastError),
      'no_process'
    ));
  try
    AProcessId := LProcessInfo.dwProcessId;
    AExecutablePath := LExecutablePath;
    if not TryGetRadIARuntimeProcessIdentity(
      AProcessId,
      AExecutablePath,
      ACreatedAtUtc
    ) then
      ACreatedAtUtc := TTimeZone.Local.ToUniversalTime(Now);
    ABuildId := GetRadIARuntimeBuildId(AExecutablePath);
    Result := TRadIADebuggerActionResult.Succeeded(
      'The instrumented runtime process started.',
      'no_process',
      'running'
    );
  finally
    CloseHandle(LProcessInfo.hThread);
    CloseHandle(LProcessInfo.hProcess);
  end;
end;

function TRadIAOTADebuggerFacade.StopRuntimeProcess(
  const AProcessId: LongWord
): Boolean;
var
  LHandle: THandle;
begin
  Result := False;
  LHandle := OpenProcess(PROCESS_TERMINATE, False, AProcessId);
  if LHandle = 0 then
    Exit;
  try
    Result := TerminateProcess(LHandle, 5);
  finally
    CloseHandle(LHandle);
  end;
end;

function TRadIAOTADebuggerFacade.ResolveRuntimeProcess(
  out AProcessId: LongWord;
  out ACreatedAtUtc: TDateTime;
  out AExecutablePath: string;
  out ABuildId: string
): Boolean;
var
  LSnapshot: TRadIADebuggerSnapshot;
begin
  AProcessId := 0;
  ACreatedAtUtc := 0;
  AExecutablePath := '';
  ABuildId := '';
  LSnapshot := GetDebuggerState;
  AProcessId := LSnapshot.OSProcessId;
  Result := (AProcessId > 0) and
    TryGetRadIARuntimeProcessIdentity(
      AProcessId,
      AExecutablePath,
      ACreatedAtUtc
    );
  if Result then
  begin
    ABuildId := GetRadIARuntimeBuildId(AExecutablePath);
    Result := ABuildId <> '';
  end;
end;

end.
