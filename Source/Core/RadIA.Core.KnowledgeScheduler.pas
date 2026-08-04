unit RadIA.Core.KnowledgeScheduler;

interface

uses
  System.SysUtils,
  RadIA.Core.Knowledge;

type
  TRadIAKnowledgeBackgroundRunner = reference to procedure(
    const AAction: TProc
  );

  TRadIAKnowledgeTickProvider = reference to function: UInt64;

  IRadIAKnowledgeRefreshScheduler = interface
    ['{E8339420-9254-40EE-88AD-E820C4D27BD9}']
    procedure MarkDirty;
    procedure Poll;
    procedure Stop;
    function IsRunning: Boolean;
  end;

  TRadIAKnowledgeRefreshScheduler = class(
    TInterfacedObject,
    IRadIAKnowledgeRefreshScheduler
  )
  private
    FDelayMs: Cardinal;
    FDirty: Boolean;
    FKnowledge: IRadIAKnowledgeService;
    FLastDirtyTick: UInt64;
    FRunner: TRadIAKnowledgeBackgroundRunner;
    FRunning: Boolean;
    FStopped: Boolean;
    FTickProvider: TRadIAKnowledgeTickProvider;
    procedure ExecuteRefresh;
    function GetCurrentTick: UInt64;
  public
    constructor Create(
      const AKnowledge: IRadIAKnowledgeService
    ); overload;
    constructor Create(
      const AKnowledge: IRadIAKnowledgeService;
      const ADelayMs: Cardinal;
      const ARunner: TRadIAKnowledgeBackgroundRunner;
      const ATickProvider: TRadIAKnowledgeTickProvider
    ); overload;
    procedure MarkDirty;
    procedure Poll;
    procedure Stop;
    function IsRunning: Boolean;
  end;

implementation

uses
  System.Classes,
  System.SyncObjs,
  Winapi.Windows,
  RadIA.Core.Types;

{ TRadIAKnowledgeRefreshScheduler }

constructor TRadIAKnowledgeRefreshScheduler.Create(
  const AKnowledge: IRadIAKnowledgeService
);
begin
  Create(AKnowledge, 1500, nil, nil);
end;

constructor TRadIAKnowledgeRefreshScheduler.Create(
  const AKnowledge: IRadIAKnowledgeService;
  const ADelayMs: Cardinal;
  const ARunner: TRadIAKnowledgeBackgroundRunner;
  const ATickProvider: TRadIAKnowledgeTickProvider
);
begin
  inherited Create;
  if not Assigned(AKnowledge) then
    raise EArgumentNilException.Create('AKnowledge');
  if ADelayMs = 0 then
    raise EArgumentOutOfRangeException.Create('ADelayMs');
  FKnowledge := AKnowledge;
  FDelayMs := ADelayMs;
  FRunner := ARunner;
  FTickProvider := ATickProvider;
end;

procedure TRadIAKnowledgeRefreshScheduler.ExecuteRefresh;
begin
  try
    FKnowledge.RefreshProject;
  finally
    TMonitor.Enter(Self);
    try
      FRunning := False;
    finally
      TMonitor.Exit(Self);
    end;
    TInterlocked.Decrement(GActiveThreadCount);
  end;
end;

function TRadIAKnowledgeRefreshScheduler.GetCurrentTick: UInt64;
begin
  if Assigned(FTickProvider) then
    Result := FTickProvider()
  else
    Result := GetTickCount64;
end;

function TRadIAKnowledgeRefreshScheduler.IsRunning: Boolean;
begin
  TMonitor.Enter(Self);
  try
    Result := FRunning;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIAKnowledgeRefreshScheduler.MarkDirty;
begin
  TMonitor.Enter(Self);
  try
    if FStopped then
      Exit;
    FDirty := True;
    FLastDirtyTick := GetCurrentTick;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIAKnowledgeRefreshScheduler.Poll;
var
  LAction: TProc;
  LKeepAlive: IRadIAKnowledgeRefreshScheduler;
  LShouldStart: Boolean;
  LThread: TThread;
begin
  LShouldStart := False;
  TMonitor.Enter(Self);
  try
    if not FStopped and FDirty and not FRunning and
      (GetCurrentTick - FLastDirtyTick >= FDelayMs) then
    begin
      FDirty := False;
      FRunning := True;
      LShouldStart := True;
    end;
  finally
    TMonitor.Exit(Self);
  end;
  if not LShouldStart then
    Exit;

  LKeepAlive := Self;
  LAction :=
    procedure
    begin
      LKeepAlive.IsRunning;
      ExecuteRefresh;
    end;
  TInterlocked.Increment(GActiveThreadCount);
  try
    if Assigned(FRunner) then
      FRunner(LAction)
    else
    begin
      LThread := TThread.CreateAnonymousThread(LAction);
      LThread.FreeOnTerminate := True;
      LThread.Start;
    end;
  except
    TMonitor.Enter(Self);
    try
      FRunning := False;
      FDirty := True;
    finally
      TMonitor.Exit(Self);
    end;
    TInterlocked.Decrement(GActiveThreadCount);
    raise;
  end;
end;

procedure TRadIAKnowledgeRefreshScheduler.Stop;
begin
  TMonitor.Enter(Self);
  try
    FStopped := True;
    FDirty := False;
  finally
    TMonitor.Exit(Self);
  end;
end;

end.
