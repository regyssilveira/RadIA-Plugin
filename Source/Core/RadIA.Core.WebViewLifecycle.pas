unit RadIA.Core.WebViewLifecycle;

interface

type
  TRadIAWebViewLifecycleState = (
    wlsIdle,
    wlsCreating,
    wlsNavigating,
    wlsReady,
    wlsFailed,
    wlsRecovering,
    wlsStopped
  );

  TRadIAWebViewLifecycleSnapshot = record
  private
    FGeneration: Integer;
    FRecoveryAttempts: Integer;
    FRecoveryCount: Integer;
    FState: TRadIAWebViewLifecycleState;
  public
    constructor Create(
      const AState: TRadIAWebViewLifecycleState;
      const AGeneration: Integer;
      const ARecoveryAttempts: Integer;
      const ARecoveryCount: Integer
    );
    property Generation: Integer read FGeneration;
    property RecoveryAttempts: Integer read FRecoveryAttempts;
    property RecoveryCount: Integer read FRecoveryCount;
    property State: TRadIAWebViewLifecycleState read FState;
  end;

  TRadIAWebViewLifecycle = class
  private
    FGeneration: Integer;
    FMaximumRecoveryAttempts: Integer;
    FRecoveryAttempts: Integer;
    FRecoveryCount: Integer;
    FState: TRadIAWebViewLifecycleState;
  public
    constructor Create(const AMaximumRecoveryAttempts: Integer = 2);
    procedure BeginCreate;
    procedure BeginNavigation;
    procedure MarkReady;
    function RegisterFailure(const AShuttingDown: Boolean): Boolean;
    procedure ResetRecoveryBudget;
    procedure Stop;
    function Snapshot: TRadIAWebViewLifecycleSnapshot;
  end;

implementation

uses
  System.Math;

constructor TRadIAWebViewLifecycleSnapshot.Create(
  const AState: TRadIAWebViewLifecycleState;
  const AGeneration: Integer;
  const ARecoveryAttempts: Integer;
  const ARecoveryCount: Integer
);
begin
  FState := AState;
  FGeneration := AGeneration;
  FRecoveryAttempts := ARecoveryAttempts;
  FRecoveryCount := ARecoveryCount;
end;

constructor TRadIAWebViewLifecycle.Create(
  const AMaximumRecoveryAttempts: Integer
);
begin
  inherited Create;
  FMaximumRecoveryAttempts := Max(0, AMaximumRecoveryAttempts);
  FState := wlsIdle;
end;

procedure TRadIAWebViewLifecycle.BeginCreate;
begin
  if FState = wlsStopped then
    Exit;
  Inc(FGeneration);
  FState := wlsCreating;
end;

procedure TRadIAWebViewLifecycle.BeginNavigation;
begin
  if FState <> wlsStopped then
    FState := wlsNavigating;
end;

procedure TRadIAWebViewLifecycle.MarkReady;
begin
  if FState = wlsStopped then
    Exit;
  FState := wlsReady;
  FRecoveryAttempts := 0;
end;

function TRadIAWebViewLifecycle.RegisterFailure(
  const AShuttingDown: Boolean
): Boolean;
begin
  Result := False;
  if FState = wlsStopped then
    Exit;
  FState := wlsFailed;
  if AShuttingDown or
    (FRecoveryAttempts >= FMaximumRecoveryAttempts) then
    Exit;
  Inc(FRecoveryAttempts);
  Inc(FRecoveryCount);
  FState := wlsRecovering;
  Result := True;
end;

procedure TRadIAWebViewLifecycle.ResetRecoveryBudget;
begin
  if FState = wlsReady then
    FRecoveryAttempts := 0;
end;

function TRadIAWebViewLifecycle.Snapshot: TRadIAWebViewLifecycleSnapshot;
begin
  Result := TRadIAWebViewLifecycleSnapshot.Create(
    FState,
    FGeneration,
    FRecoveryAttempts,
    FRecoveryCount
  );
end;

procedure TRadIAWebViewLifecycle.Stop;
begin
  FState := wlsStopped;
end;

end.
