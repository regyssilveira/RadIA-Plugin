unit RadIA.Core.RuntimeScenario;

interface

uses
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.Tools;

type
  TRadIARuntimeScenarioState = (
    rssIdle,
    rssPrepared,
    rssRunning,
    rssSucceeded,
    rssFailed,
    rssCancelled
  );

  TRadIARuntimeScenarioPreview = record
  private
    FActionCount: Integer;
    FFingerprint: string;
    FName: string;
    FPreviewId: string;
    FRepetitions: Integer;
    FSessionId: string;
  public
    constructor Create(
      const APreviewId: string;
      const AFingerprint: string;
      const AName: string;
      const ASessionId: string;
      const AActionCount: Integer;
      const ARepetitions: Integer
    );
    property PreviewId: string read FPreviewId;
    property Fingerprint: string read FFingerprint;
    property Name: string read FName;
    property SessionId: string read FSessionId;
    property ActionCount: Integer read FActionCount;
    property Repetitions: Integer read FRepetitions;
  end;

  TRadIARuntimeScenarioStatus = record
  private
    FActionIndex: Integer;
    FCompletedActions: Integer;
    FErrorCode: string;
    FMessage: string;
    FPreviewId: string;
    FRepetition: Integer;
    FState: TRadIARuntimeScenarioState;
  public
    constructor Create(
      const APreviewId: string;
      const AState: TRadIARuntimeScenarioState;
      const ARepetition: Integer;
      const AActionIndex: Integer;
      const ACompletedActions: Integer;
      const AErrorCode: string;
      const AMessage: string
    );
    property PreviewId: string read FPreviewId;
    property State: TRadIARuntimeScenarioState read FState;
    property Repetition: Integer read FRepetition;
    property ActionIndex: Integer read FActionIndex;
    property CompletedActions: Integer read FCompletedActions;
    property ErrorCode: string read FErrorCode;
    property Message: string read FMessage;
  end;

  IRadIARuntimeScenarioCoordinator = interface
    ['{58F20E2E-999A-42B6-9343-31B774113BCF}']
    function Cancel: Boolean;
    function GetStatus: TRadIARuntimeScenarioStatus;
    function Prepare(
      const AScenario: TRadIARuntimeScenario
    ): TRadIARuntimeScenarioPreview;
    function Run(
      const APreviewId: string;
      const ACurrentSession: TRadIARuntimeSessionIdentity;
      const ACancellationToken: IRadIAToolCancellationToken
    ): TRadIARuntimeScenarioStatus;
  end;

  TRadIARuntimeScenarioCoordinator = class(
    TInterfacedObject,
    IRadIARuntimeScenarioCoordinator
  )
  private type
    TRadIAPreparedRuntimeScenario = class
    private
      FPreview: TRadIARuntimeScenarioPreview;
      FScenario: TRadIARuntimeScenario;
    public
      constructor Create(
        const APreview: TRadIARuntimeScenarioPreview;
        const AScenario: TRadIARuntimeScenario
      );
      property Preview: TRadIARuntimeScenarioPreview read FPreview;
      property Scenario: TRadIARuntimeScenario read FScenario;
    end;
  private
    FActionFacade: IRadIARuntimeActionFacade;
    FCancelRequested: Boolean;
    FPrepared: TRadIAPreparedRuntimeScenario;
    FStatus: TRadIARuntimeScenarioStatus;
    function BuildFingerprint(
      const AScenario: TRadIARuntimeScenario
    ): string;
    function BuildActionFailureStatus(
      const APrepared: TRadIAPreparedRuntimeScenario;
      const AResult: TRadIARuntimeActionResult;
      const ARepetition: Integer;
      const AActionIndex: Integer;
      const ACompletedActions: Integer
    ): TRadIARuntimeScenarioStatus;
    function CancellationRequested(
      const ACancellationToken: IRadIAToolCancellationToken
    ): Boolean;
    function CanRevealRuntimeTarget(
      const AKind: TRadIARuntimeActionKind
    ): Boolean;
    function ExecuteScenario(
      const APrepared: TRadIAPreparedRuntimeScenario;
      const ACancellationToken: IRadIAToolCancellationToken
    ): TRadIARuntimeScenarioStatus;
    function ExecutePreparedAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction;
      const ACancellationToken: IRadIAToolCancellationToken
    ): TRadIARuntimeActionResult;
    function ExecuteWait(
      const ATimeoutMs: Cardinal;
      const ACancellationToken: IRadIAToolCancellationToken
    ): Boolean;
    function SameSession(
      const AExpected: TRadIARuntimeSessionIdentity;
      const AActual: TRadIARuntimeSessionIdentity
    ): Boolean;
    function TryGetInterruption(
      const APrepared: TRadIAPreparedRuntimeScenario;
      const ACancellationToken: IRadIAToolCancellationToken;
      const AElapsedMs: Int64;
      const ARepetition: Integer;
      const AActionIndex: Integer;
      const ACompletedActions: Integer;
      out AStatus: TRadIARuntimeScenarioStatus
    ): Boolean;
    procedure SetStatus(
      const AStatus: TRadIARuntimeScenarioStatus
    );
    procedure ValidateScenario(
      const AScenario: TRadIARuntimeScenario
    );
  public
    constructor Create(
      const AActionFacade: IRadIARuntimeActionFacade
    );
    destructor Destroy; override;
    function Cancel: Boolean;
    function GetStatus: TRadIARuntimeScenarioStatus;
    function Prepare(
      const AScenario: TRadIARuntimeScenario
    ): TRadIARuntimeScenarioPreview;
    function Run(
      const APreviewId: string;
      const ACurrentSession: TRadIARuntimeSessionIdentity;
      const ACancellationToken: IRadIAToolCancellationToken
    ): TRadIARuntimeScenarioStatus;
  end;

function RadIARuntimeScenarioStateName(
  const AState: TRadIARuntimeScenarioState
): string;

implementation

uses
  System.DateUtils,
  System.Diagnostics,
  System.Hash,
  System.SysUtils;

const
  CWaitSliceMs = 100;

function RadIARuntimeScenarioStateName(
  const AState: TRadIARuntimeScenarioState
): string;
begin
  case AState of
    rssPrepared:
      Result := 'prepared';
    rssRunning:
      Result := 'running';
    rssSucceeded:
      Result := 'succeeded';
    rssFailed:
      Result := 'failed';
    rssCancelled:
      Result := 'cancelled';
  else
    Result := 'idle';
  end;
end;

{ TRadIARuntimeScenarioPreview }

constructor TRadIARuntimeScenarioPreview.Create(
  const APreviewId: string;
  const AFingerprint: string;
  const AName: string;
  const ASessionId: string;
  const AActionCount: Integer;
  const ARepetitions: Integer
);
begin
  FPreviewId := APreviewId;
  FFingerprint := AFingerprint;
  FName := AName;
  FSessionId := ASessionId;
  FActionCount := AActionCount;
  FRepetitions := ARepetitions;
end;

{ TRadIARuntimeScenarioStatus }

constructor TRadIARuntimeScenarioStatus.Create(
  const APreviewId: string;
  const AState: TRadIARuntimeScenarioState;
  const ARepetition: Integer;
  const AActionIndex: Integer;
  const ACompletedActions: Integer;
  const AErrorCode: string;
  const AMessage: string
);
begin
  FPreviewId := APreviewId;
  FState := AState;
  FRepetition := ARepetition;
  FActionIndex := AActionIndex;
  FCompletedActions := ACompletedActions;
  FErrorCode := AErrorCode;
  FMessage := AMessage;
end;

{ TRadIARuntimeScenarioCoordinator.TRadIAPreparedRuntimeScenario }

constructor TRadIARuntimeScenarioCoordinator.
  TRadIAPreparedRuntimeScenario.Create(
  const APreview: TRadIARuntimeScenarioPreview;
  const AScenario: TRadIARuntimeScenario
);
begin
  inherited Create;
  FPreview := APreview;
  FScenario := AScenario;
end;

{ TRadIARuntimeScenarioCoordinator }

function TRadIARuntimeScenarioCoordinator.BuildFingerprint(
  const AScenario: TRadIARuntimeScenario
): string;
var
  LAction: TRadIARuntimeScenarioAction;
  LSource: string;
begin
  LSource :=
    AScenario.Session.SessionId + '|' +
    AScenario.Name + '|' +
    AScenario.Limits.MaxActions.ToString + '|' +
    AScenario.Limits.MaxDurationMs.ToString + '|' +
    AScenario.Limits.MaxRepetitions.ToString;
  for LAction in AScenario.Actions do
    LSource := LSource + '|' +
      Ord(LAction.Kind).ToString + '|' +
      LAction.Selector.AutomationId + '|' +
      LAction.Selector.ClassName + '|' +
      LAction.Selector.ControlName + '|' +
      LAction.Selector.Text + '|' +
      LAction.Selector.ParentPath + '|' +
      LAction.Value + '|' +
      LAction.TimeoutMs.ToString;
  Result := LowerCase(
    THashSHA2.GetHashString(
      LSource,
      THashSHA2.TSHA2Version.SHA256
    )
  );
end;

function TRadIARuntimeScenarioCoordinator.BuildActionFailureStatus(
  const APrepared: TRadIAPreparedRuntimeScenario;
  const AResult: TRadIARuntimeActionResult;
  const ARepetition: Integer;
  const AActionIndex: Integer;
  const ACompletedActions: Integer
): TRadIARuntimeScenarioStatus;
var
  LState: TRadIARuntimeScenarioState;
begin
  if SameText(
    AResult.ErrorCode,
    'runtime_scenario_cancelled'
  ) then
    LState := rssCancelled
  else
    LState := rssFailed;
  Result := TRadIARuntimeScenarioStatus.Create(
    APrepared.Preview.PreviewId,
    LState,
    ARepetition,
    AActionIndex,
    ACompletedActions,
    AResult.ErrorCode,
    AResult.Message
  );
end;

function TRadIARuntimeScenarioCoordinator.Cancel: Boolean;
begin
  TMonitor.Enter(Self);
  try
    Result := FStatus.State = rssRunning;
    if Result then
    begin
      FCancelRequested := True;
      TMonitor.PulseAll(Self);
    end;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TRadIARuntimeScenarioCoordinator.CancellationRequested(
  const ACancellationToken: IRadIAToolCancellationToken
): Boolean;
begin
  TMonitor.Enter(Self);
  try
    Result := FCancelRequested;
  finally
    TMonitor.Exit(Self);
  end;
  Result := Result or (
    Assigned(ACancellationToken) and
    ACancellationToken.CancellationRequested
  );
end;

function TRadIARuntimeScenarioCoordinator.CanRevealRuntimeTarget(
  const AKind: TRadIARuntimeActionKind
): Boolean;
begin
  Result := AKind in [
    rakInvoke,
    rakSetValue,
    rakSelect,
    rakClose,
    rakCancel
  ];
end;

constructor TRadIARuntimeScenarioCoordinator.Create(
  const AActionFacade: IRadIARuntimeActionFacade
);
begin
  inherited Create;
  if not Assigned(AActionFacade) then
    raise EArgumentNilException.Create('AActionFacade');
  FActionFacade := AActionFacade;
  FPrepared := nil;
  FCancelRequested := False;
  FStatus := TRadIARuntimeScenarioStatus.Create(
    '',
    rssIdle,
    0,
    0,
    0,
    '',
    ''
  );
end;

destructor TRadIARuntimeScenarioCoordinator.Destroy;
begin
  FPrepared.Free;
  inherited;
end;

function TRadIARuntimeScenarioCoordinator.ExecutePreparedAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction;
  const ACancellationToken: IRadIAToolCancellationToken
): TRadIARuntimeActionResult;
begin
  if AAction.Kind <> rakWait then
    Exit(FActionFacade.ExecuteAction(ASession, AAction));
  if ExecuteWait(AAction.TimeoutMs, ACancellationToken) then
    Result := TRadIARuntimeActionResult.Succeeded
  else
    Result := TRadIARuntimeActionResult.Failed(
      'runtime_scenario_cancelled',
      'Runtime scenario execution was cancelled.'
    );
end;

function TRadIARuntimeScenarioCoordinator.ExecuteScenario(
  const APrepared: TRadIAPreparedRuntimeScenario;
  const ACancellationToken: IRadIAToolCancellationToken
): TRadIARuntimeScenarioStatus;
var
  LAction: TRadIARuntimeScenarioAction;
  LActionIndex: Integer;
  LActionResult: TRadIARuntimeActionResult;
  LCompletedActions: Integer;
  LRepetition: Integer;
  LStopwatch: TStopwatch;
begin
  LCompletedActions := 0;
  LStopwatch := TStopwatch.StartNew;
  for LRepetition := 1 to
    APrepared.Scenario.Limits.MaxRepetitions do
    for LActionIndex := 0 to
      High(APrepared.Scenario.Actions) do
    begin
      if TryGetInterruption(
        APrepared,
        ACancellationToken,
        LStopwatch.ElapsedMilliseconds,
        LRepetition,
        LActionIndex + 1,
        LCompletedActions,
        Result
      ) then
        Exit;
      SetStatus(TRadIARuntimeScenarioStatus.Create(
        APrepared.Preview.PreviewId,
        rssRunning,
        LRepetition,
        LActionIndex + 1,
        LCompletedActions,
        '',
        ''
      ));
      LAction := APrepared.Scenario.Actions[LActionIndex];
      LActionResult := ExecutePreparedAction(
        APrepared.Scenario.Session,
        LAction,
        ACancellationToken
      );
      if not LActionResult.Success then
        Exit(BuildActionFailureStatus(
          APrepared,
          LActionResult,
          LRepetition,
          LActionIndex + 1,
          LCompletedActions
        ));
      Inc(LCompletedActions);
      if LActionResult.ObservedValue <> '' then
        SetStatus(TRadIARuntimeScenarioStatus.Create(
          APrepared.Preview.PreviewId,
          rssRunning,
          LRepetition,
          LActionIndex + 1,
          LCompletedActions,
          '',
          LActionResult.ObservedValue
        ));
    end;
  Result := TRadIARuntimeScenarioStatus.Create(
    APrepared.Preview.PreviewId,
    rssSucceeded,
    APrepared.Scenario.Limits.MaxRepetitions,
    Length(APrepared.Scenario.Actions),
    LCompletedActions,
    '',
    'Runtime scenario completed successfully.'
  );
end;

function TRadIARuntimeScenarioCoordinator.TryGetInterruption(
  const APrepared: TRadIAPreparedRuntimeScenario;
  const ACancellationToken: IRadIAToolCancellationToken;
  const AElapsedMs: Int64;
  const ARepetition: Integer;
  const AActionIndex: Integer;
  const ACompletedActions: Integer;
  out AStatus: TRadIARuntimeScenarioStatus
): Boolean;
begin
  Result := CancellationRequested(ACancellationToken);
  if Result then
  begin
    AStatus := TRadIARuntimeScenarioStatus.Create(
      APrepared.Preview.PreviewId,
      rssCancelled,
      ARepetition,
      AActionIndex,
      ACompletedActions,
      'runtime_scenario_cancelled',
      'Runtime scenario execution was cancelled.'
    );
    Exit;
  end;
  Result := AElapsedMs >
    APrepared.Scenario.Limits.MaxDurationMs;
  if Result then
    AStatus := TRadIARuntimeScenarioStatus.Create(
      APrepared.Preview.PreviewId,
      rssFailed,
      ARepetition,
      AActionIndex,
      ACompletedActions,
      'runtime_scenario_timeout',
      'Runtime scenario exceeded its maximum duration.'
    );
end;

function TRadIARuntimeScenarioCoordinator.ExecuteWait(
  const ATimeoutMs: Cardinal;
  const ACancellationToken: IRadIAToolCancellationToken
): Boolean;
var
  LRemainingMs: Cardinal;
  LSliceMs: Cardinal;
begin
  LRemainingMs := ATimeoutMs;
  while LRemainingMs > 0 do
  begin
    if CancellationRequested(ACancellationToken) then
      Exit(False);
    LSliceMs := LRemainingMs;
    if LSliceMs > CWaitSliceMs then
      LSliceMs := CWaitSliceMs;
    TMonitor.Enter(Self);
    try
      TMonitor.Wait(Self, LSliceMs);
    finally
      TMonitor.Exit(Self);
    end;
    Dec(LRemainingMs, LSliceMs);
  end;
  Result := not CancellationRequested(ACancellationToken);
end;

function TRadIARuntimeScenarioCoordinator.GetStatus:
  TRadIARuntimeScenarioStatus;
begin
  TMonitor.Enter(Self);
  try
    Result := FStatus;
  finally
    TMonitor.Exit(Self);
  end;
end;

function TRadIARuntimeScenarioCoordinator.Prepare(
  const AScenario: TRadIARuntimeScenario
): TRadIARuntimeScenarioPreview;
var
  LFingerprint: string;
  LPrepared: TRadIAPreparedRuntimeScenario;
begin
  ValidateScenario(AScenario);
  LFingerprint := BuildFingerprint(AScenario);
  Result := TRadIARuntimeScenarioPreview.Create(
    LowerCase(TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '')),
    LFingerprint,
    AScenario.Name,
    AScenario.Session.SessionId,
    Length(AScenario.Actions),
    AScenario.Limits.MaxRepetitions
  );
  LPrepared := TRadIAPreparedRuntimeScenario.Create(
    Result,
    AScenario
  );
  TMonitor.Enter(Self);
  try
    if FStatus.State = rssRunning then
      raise EInvalidOp.Create(
        'A runtime scenario is already running.'
      );
    FPrepared.Free;
    FPrepared := LPrepared;
    LPrepared := nil;
    FCancelRequested := False;
    FStatus := TRadIARuntimeScenarioStatus.Create(
      Result.PreviewId,
      rssPrepared,
      0,
      0,
      0,
      '',
      'Runtime scenario is prepared and awaiting consent.'
    );
  finally
    TMonitor.Exit(Self);
    LPrepared.Free;
  end;
end;

function TRadIARuntimeScenarioCoordinator.Run(
  const APreviewId: string;
  const ACurrentSession: TRadIARuntimeSessionIdentity;
  const ACancellationToken: IRadIAToolCancellationToken
): TRadIARuntimeScenarioStatus;
var
  LCancellationNotifier: IRadIAToolCancellationNotifier;
  LPrepared: TRadIAPreparedRuntimeScenario;
begin
  TMonitor.Enter(Self);
  try
    if not Assigned(FPrepared) or
      not SameText(FPrepared.Preview.PreviewId, APreviewId) then
      raise EArgumentException.Create(
        'Runtime scenario preview id is unknown or expired.'
      );
    if FStatus.State = rssRunning then
      raise EInvalidOp.Create(
        'A runtime scenario is already running.'
      );
    if not SameSession(
      FPrepared.Scenario.Session,
      ACurrentSession
    ) then
      raise EInvalidOp.Create(
        'Runtime debug session changed after scenario preparation.'
      );
    FCancelRequested := False;
    FStatus := TRadIARuntimeScenarioStatus.Create(
      FPrepared.Preview.PreviewId,
      rssRunning,
      1,
      1,
      0,
      '',
      ''
    );
    LPrepared := FPrepared;
  finally
    TMonitor.Exit(Self);
  end;
  LCancellationNotifier := nil;
  if Assigned(ACancellationToken) then
    Supports(
      ACancellationToken,
      IRadIAToolCancellationNotifier,
      LCancellationNotifier
    );
  if Assigned(LCancellationNotifier) then
    LCancellationNotifier.SetCancellationCallback(
      procedure
      begin
        Cancel;
      end
    );
  try
    Result := ExecuteScenario(LPrepared, ACancellationToken);
    SetStatus(Result);
  finally
    if Assigned(LCancellationNotifier) then
      LCancellationNotifier.ClearCancellationCallback;
  end;
end;

function TRadIARuntimeScenarioCoordinator.SameSession(
  const AExpected: TRadIARuntimeSessionIdentity;
  const AActual: TRadIARuntimeSessionIdentity
): Boolean;
begin
  Result :=
    SameText(AExpected.SessionId, AActual.SessionId) and
    (AExpected.ProcessId = AActual.ProcessId) and
    (Abs(MilliSecondsBetween(
      AExpected.CreatedAtUtc,
      AActual.CreatedAtUtc
    )) < 1000) and
    SameFileName(
      AExpected.ExecutablePath,
      AActual.ExecutablePath
    ) and
    SameText(AExpected.BuildId, AActual.BuildId);
end;

procedure TRadIARuntimeScenarioCoordinator.SetStatus(
  const AStatus: TRadIARuntimeScenarioStatus
);
begin
  TMonitor.Enter(Self);
  try
    FStatus := AStatus;
  finally
    TMonitor.Exit(Self);
  end;
end;

procedure TRadIARuntimeScenarioCoordinator.ValidateScenario(
  const AScenario: TRadIARuntimeScenario
);
var
  LAction: TRadIARuntimeScenarioAction;
  LDynamicTargetAllowed: Boolean;
  LResult: TRadIARuntimeActionResult;
begin
  if not AScenario.IsExecutable then
    raise EArgumentException.Create(
      'Runtime scenario is invalid or exceeds its limits.'
    );
  LDynamicTargetAllowed := False;
  for LAction in AScenario.Actions do
  begin
    if LAction.Kind = rakWait then
      Continue;
    LResult := FActionFacade.ValidateAction(
      AScenario.Session,
      LAction
    );
    if not LResult.Success then
    begin
      if LDynamicTargetAllowed and SameText(
        LResult.ErrorCode,
        'runtime_target_not_found'
      ) then
        Continue;
      raise EArgumentException.CreateFmt(
        '%s: %s',
        [LResult.ErrorCode, LResult.Message]
      );
    end;
    if CanRevealRuntimeTarget(LAction.Kind) then
      LDynamicTargetAllowed := True;
  end;
end;

end.
