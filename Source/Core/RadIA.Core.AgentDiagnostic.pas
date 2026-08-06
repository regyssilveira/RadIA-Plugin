unit RadIA.Core.AgentDiagnostic;

interface

uses
  RadIA.Core.Tools;

procedure RunRadIAAgentRuntimeDiagnostic(
  const AToolExecutor: IRadIAToolExecutor;
  const ACheckpointDirectory: string
);

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.AgentRuntime,
  RadIA.Core.Logger;

const
  CDiagnosticSessionId = 'radia-agent-runtime-smoke';
  CDiagnosticProjectId = 'radia-agent-runtime-diagnostic';
  CDiagnosticToolName = 'GetIDEState';

type
  TRadIAAgentDiagnosticProvider = class(
    TInterfacedObject,
    IRadIAAgentDecisionProvider
  )
  private
    FDecisionIndex: Integer;
  public
    function NextDecision(
      const AContextJson: string
    ): TRadIAAgentDecision;
  end;

  TRadIAAgentDiagnosticObserver = class(
    TInterfacedObject,
    IRadIAAgentObserver
  )
  private
    FPauseRequested: Boolean;
    FRuntime: TRadIAAgentRuntime;
  public
    procedure AgentStateChanged(
      const ASnapshotJson: string
    );
    property Runtime: TRadIAAgentRuntime read FRuntime write FRuntime;
  end;

procedure AssertDiagnosticStatus(
  const AResult: TRadIAAgentRunResult;
  const AExpected: TRadIAAgentStatus;
  const AStage: string
);
begin
  if AResult.Status <> AExpected then
    raise EInvalidOp.CreateFmt(
      'Agent diagnostic %s returned %s instead of %s.',
      [
        AStage,
        RadIAAgentStatusName(AResult.Status),
        RadIAAgentStatusName(AExpected)
      ]
    );
  TLogger.Log(
    Format(
      'Agent diagnostic checkpoint: status=%s, steps=%d',
      [RadIAAgentStatusName(AResult.Status), AResult.StepCount]
    ),
    'AgentDiagnostic'
  );
end;

procedure AssertPersistedStatus(
  const AStore: IRadIAAgentCheckpointStore;
  const AExpectedStatus: string
);
var
  LRoot: TJSONObject;
  LSnapshot: string;
  LValue: TJSONValue;
begin
  if not AStore.TryLoad(CDiagnosticSessionId, LSnapshot) then
    raise EInvalidOp.Create('Agent diagnostic checkpoint was not persisted.');
  LValue := TJSONObject.ParseJSONValue(LSnapshot);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    raise EInvalidOp.Create('Agent diagnostic checkpoint is not valid JSON.');
  end;
  LRoot := TJSONObject(LValue);
  try
    if not SameText(
      LRoot.GetValue<string>('status', ''),
      AExpectedStatus
    ) then
      raise EInvalidOp.CreateFmt(
        'Agent diagnostic checkpoint did not persist status %s.',
        [AExpectedStatus]
      );
  finally
    LRoot.Free;
  end;
end;

{ TRadIAAgentDiagnosticProvider }

function TRadIAAgentDiagnosticProvider.NextDecision(
  const AContextJson: string
): TRadIAAgentDecision;
begin
  if Trim(AContextJson) = '' then
    raise EArgumentException.Create('Agent diagnostic context is empty.');
  Inc(FDecisionIndex);
  case FDecisionIndex of
    1:
      Result := TRadIAAgentDecision.Plan(
        'Approve the local agent runtime diagnostic.',
        '[{"title":"Inspect the active IDE state"}]'
      );
    2:
      Result := TRadIAAgentDecision.CallTool(
        CDiagnosticToolName,
        '{}'
      );
  else
    Result := TRadIAAgentDecision.Complete(
      'The local agent runtime diagnostic completed.'
    );
  end;
end;

{ TRadIAAgentDiagnosticObserver }

procedure TRadIAAgentDiagnosticObserver.AgentStateChanged(
  const ASnapshotJson: string
);
var
  LRoot: TJSONObject;
  LSteps: TJSONArray;
  LValue: TJSONValue;
begin
  if FPauseRequested or not Assigned(FRuntime) then
    Exit;
  LValue := TJSONObject.ParseJSONValue(ASnapshotJson);
  if not (LValue is TJSONObject) then
  begin
    LValue.Free;
    Exit;
  end;
  LRoot := TJSONObject(LValue);
  try
    LSteps := LRoot.GetValue<TJSONArray>('steps');
    if SameText(LRoot.GetValue<string>('status', ''), 'running') and
      Assigned(LSteps) and (LSteps.Count = 1) then
    begin
      FPauseRequested := True;
      FRuntime.RequestPause;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure RunRadIAAgentRuntimeDiagnostic(
  const AToolExecutor: IRadIAToolExecutor;
  const ACheckpointDirectory: string
);
var
  LObserver: IRadIAAgentObserver;
  LObserverObject: TRadIAAgentDiagnosticObserver;
  LProvider: IRadIAAgentDecisionProvider;
  LResult: TRadIAAgentRunResult;
  LRuntime: TRadIAAgentRuntime;
  LStore: IRadIAAgentCheckpointStore;
begin
  if not Assigned(AToolExecutor) then
    raise EArgumentNilException.Create('AToolExecutor');
  if Trim(ACheckpointDirectory) = '' then
    raise EArgumentException.Create('ACheckpointDirectory');

  LProvider := TRadIAAgentDiagnosticProvider.Create;
  LStore := TRadIAAgentFileCheckpointStore.Create(ACheckpointDirectory);
  LObserverObject := TRadIAAgentDiagnosticObserver.Create;
  LObserver := LObserverObject;
  LRuntime := TRadIAAgentRuntime.Create(
    AToolExecutor,
    LProvider,
    LStore,
    LObserver
  );
  try
    LObserverObject.Runtime := LRuntime;
    LResult := LRuntime.Start(
      'Validate the local RadIA agent runtime.',
      CDiagnosticSessionId,
      CDiagnosticProjectId,
      TRadIAAgentLimits.Default
    );
    AssertDiagnosticStatus(LResult, asAwaitingApproval, 'start');
    AssertPersistedStatus(LStore, 'awaitingApproval');

    LResult := LRuntime.Resume(CDiagnosticSessionId);
    AssertDiagnosticStatus(LResult, asPaused, 'pause');
    AssertPersistedStatus(LStore, 'paused');
  finally
    LObserverObject.Runtime := nil;
    LRuntime.Free;
  end;

  LRuntime := TRadIAAgentRuntime.Create(
    AToolExecutor,
    LProvider,
    LStore,
    LObserver
  );
  try
    LObserverObject.Runtime := LRuntime;
    LResult := LRuntime.Resume(CDiagnosticSessionId);
    AssertDiagnosticStatus(LResult, asCompleted, 'resume');
    AssertPersistedStatus(LStore, 'completed');
    TLogger.Log(
      'Agent runtime diagnostic passed: persisted=true, resumed=true, ' +
      'tool=' + CDiagnosticToolName,
      'AgentDiagnostic'
    );
  finally
    LObserverObject.Runtime := nil;
    LRuntime.Free;
  end;
end;

end.
