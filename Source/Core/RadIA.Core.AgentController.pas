unit RadIA.Core.AgentController;

interface

uses
  System.SysUtils,
  RadIA.Core.AgentProvider,
  RadIA.Core.AgentRuntime,
  RadIA.Core.Tools;

type
  TRadIAAgentStateCallback = reference to procedure(
    const ASnapshotJson: string
  );

  TRadIAAgentFinishedCallback = reference to procedure(
    const AResult: TRadIAAgentRunResult
  );

  IRadIAAgentRunController = interface
    ['{4BA96E6D-1FC3-4FA6-A181-151A797031E8}']
    procedure Start(
      const AObjective: string;
      const ASessionId: string;
      const AProjectId: string;
      const ALimits: TRadIAAgentLimits
    );
    procedure Resume(const ASessionId: string);
    procedure Pause;
    procedure Cancel;
    function IsRunning: Boolean;
  end;

  TRadIAAgentRunController = class(
    TInterfacedObject,
    IRadIAAgentRunController
  )
  private
    FToolExecutor: IRadIAToolExecutor;
    FDecisionProvider: IRadIAAgentDecisionProvider;
    FDecisionCancellation: IRadIAAgentDecisionCancellation;
    FCheckpointStore: IRadIAAgentCheckpointStore;
    FObserver: IRadIAAgentObserver;
    FOnFinished: TRadIAAgentFinishedCallback;
    FRuntime: TRadIAAgentRuntime;
    FRunning: Integer;
    procedure BeginRun(
      const ARun: TFunc<TRadIAAgentRuntime, TRadIAAgentRunResult>
    );
    procedure SetRuntime(const ARuntime: TRadIAAgentRuntime);
  public
    constructor Create(
      const AToolExecutor: IRadIAToolExecutor;
      const ADecisionProvider: IRadIAAgentDecisionProvider;
      const ACheckpointStore: IRadIAAgentCheckpointStore;
      const AOnState: TRadIAAgentStateCallback;
      const AOnFinished: TRadIAAgentFinishedCallback
    );
    procedure Start(
      const AObjective: string;
      const ASessionId: string;
      const AProjectId: string;
      const ALimits: TRadIAAgentLimits
    );
    procedure Resume(const ASessionId: string);
    procedure Pause;
    procedure Cancel;
    function IsRunning: Boolean;
  end;

implementation

uses
  System.Classes,
  System.SyncObjs,
  RadIA.Core.Types;

type
  TRadIAAgentCallbackObserver = class(
    TInterfacedObject,
    IRadIAAgentObserver
  )
  private
    FCallback: TRadIAAgentStateCallback;
  public
    constructor Create(const ACallback: TRadIAAgentStateCallback);
    procedure AgentStateChanged(const ASnapshotJson: string);
  end;

{ TRadIAAgentCallbackObserver }

constructor TRadIAAgentCallbackObserver.Create(
  const ACallback: TRadIAAgentStateCallback
);
begin
  inherited Create;
  FCallback := ACallback;
end;

procedure TRadIAAgentCallbackObserver.AgentStateChanged(
  const ASnapshotJson: string
);
begin
  if Assigned(FCallback) then
    FCallback(ASnapshotJson);
end;

{ TRadIAAgentRunController }

constructor TRadIAAgentRunController.Create(
  const AToolExecutor: IRadIAToolExecutor;
  const ADecisionProvider: IRadIAAgentDecisionProvider;
  const ACheckpointStore: IRadIAAgentCheckpointStore;
  const AOnState: TRadIAAgentStateCallback;
  const AOnFinished: TRadIAAgentFinishedCallback
);
begin
  inherited Create;
  if not Assigned(AToolExecutor) then
    raise EArgumentNilException.Create('AToolExecutor');
  if not Assigned(ADecisionProvider) then
    raise EArgumentNilException.Create('ADecisionProvider');
  if not Assigned(ACheckpointStore) then
    raise EArgumentNilException.Create('ACheckpointStore');
  FToolExecutor := AToolExecutor;
  FDecisionProvider := ADecisionProvider;
  Supports(
    ADecisionProvider,
    IRadIAAgentDecisionCancellation,
    FDecisionCancellation
  );
  FCheckpointStore := ACheckpointStore;
  FObserver := TRadIAAgentCallbackObserver.Create(AOnState);
  FOnFinished := AOnFinished;
end;

procedure TRadIAAgentRunController.BeginRun(
  const ARun: TFunc<TRadIAAgentRuntime, TRadIAAgentRunResult>
);
var
  LKeepAlive: IInterface;
begin
  if TInterlocked.CompareExchange(FRunning, 1, 0) <> 0 then
    raise EInvalidOp.Create('An agent run is already active.');
  LKeepAlive := Self;
  TInterlocked.Increment(GActiveThreadCount);
  TThread.CreateAnonymousThread(
    procedure
    var
      LResult: TRadIAAgentRunResult;
      LRuntime: TRadIAAgentRuntime;
    begin
      try
        LRuntime := TRadIAAgentRuntime.Create(
          FToolExecutor,
          FDecisionProvider,
          FCheckpointStore,
          FObserver
        );
        SetRuntime(LRuntime);
        try
          LResult := ARun(LRuntime);
        except
          on E: Exception do
            LResult := TRadIAAgentRunResult.Create(
              asFailed,
              'Agent run failed: ' + E.Message,
              0
            );
        end;
        SetRuntime(nil);
        LRuntime.Free;
        if Assigned(FOnFinished) then
          FOnFinished(LResult);
      finally
        TInterlocked.Exchange(FRunning, 0);
        TInterlocked.Decrement(GActiveThreadCount);
        LKeepAlive := nil;
      end;
    end
  ).Start;
end;

procedure TRadIAAgentRunController.Cancel;
var
  LRuntime: TRadIAAgentRuntime;
begin
  TMonitor.Enter(Self);
  try
    LRuntime := FRuntime;
    if Assigned(LRuntime) then
      LRuntime.RequestCancel;
    if Assigned(FDecisionCancellation) then
      FDecisionCancellation.CancelDecision;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TRadIAAgentRunController.IsRunning: Boolean;
begin
  Result := TInterlocked.CompareExchange(FRunning, 0, 0) <> 0;
end;

procedure TRadIAAgentRunController.Pause;
var
  LRuntime: TRadIAAgentRuntime;
begin
  TMonitor.Enter(Self);
  try
    LRuntime := FRuntime;
    if Assigned(LRuntime) then
      LRuntime.RequestPause;
    if Assigned(FDecisionCancellation) then
      FDecisionCancellation.CancelDecision;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIAAgentRunController.Resume(
  const ASessionId: string
);
begin
  BeginRun(
    function(
      ARuntime: TRadIAAgentRuntime
    ): TRadIAAgentRunResult
    begin
      Result := ARuntime.Resume(ASessionId);
    end
  );
end;

procedure TRadIAAgentRunController.SetRuntime(
  const ARuntime: TRadIAAgentRuntime
);
begin
  TMonitor.Enter(Self);
  try
    FRuntime := ARuntime;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIAAgentRunController.Start(
  const AObjective: string;
  const ASessionId: string;
  const AProjectId: string;
  const ALimits: TRadIAAgentLimits
);
begin
  BeginRun(
    function(
      ARuntime: TRadIAAgentRuntime
    ): TRadIAAgentRunResult
    begin
      Result := ARuntime.Start(
        AObjective,
        ASessionId,
        AProjectId,
        ALimits
      );
    end
  );
end;

end.
