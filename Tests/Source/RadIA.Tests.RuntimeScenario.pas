unit RadIA.Tests.RuntimeScenario;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeScenario;

type
  TMockRadIARuntimeActionFacade = class(
    TInterfacedObject,
    IRadIARuntimeActionFacade
  )
  private
    FExecuteCount: Integer;
    FFailExecution: Boolean;
    FRejectDynamicTarget: Boolean;
    FRejectValidation: Boolean;
    FValidationCount: Integer;
  public
    function ExecuteAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
    function ValidateAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
    property ExecuteCount: Integer read FExecuteCount;
    property FailExecution: Boolean
      read FFailExecution write FFailExecution;
    property RejectDynamicTarget: Boolean
      read FRejectDynamicTarget write FRejectDynamicTarget;
    property RejectValidation: Boolean
      read FRejectValidation write FRejectValidation;
  end;

  [TestFixture]
  TTestRadIARuntimeScenario = class
  private
    FActionFacade: IRadIARuntimeActionFacade;
    FCoordinator: IRadIARuntimeScenarioCoordinator;
    FMock: TMockRadIARuntimeActionFacade;
    FSession: TRadIARuntimeSessionIdentity;
    function Action(
      const AKind: TRadIARuntimeActionKind;
      const ATargetId: string;
      const AValue: string = '';
      const ATimeoutMs: Cardinal = 100
    ): TRadIARuntimeScenarioAction;
    function Scenario(
      const AActions: TArray<TRadIARuntimeScenarioAction>;
      const ARepetitions: Integer = 1;
      const AMaxDurationMs: Cardinal = 5000
    ): TRadIARuntimeScenario;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure CancelInterruptsWaitImmediately;
    [Test]
    procedure FailedActionStopsScenario;
    [Test]
    procedure PrepareAllowsTargetRevealedByPriorAction;
    [Test]
    procedure PrepareValidatesEveryAction;
    [Test]
    procedure RunRejectsChangedSession;
    [Test]
    procedure RunCompletesTenStableRepetitions;
    [Test]
    procedure RunStopsAtGlobalTimeout;
    [Test]
    procedure ToolsKeepRunBehindConsentAndCancelImmediate;
  end;

implementation

uses
  System.Classes,
  System.DateUtils,
  System.SysUtils,
  System.Threading,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeScenarioTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools;

function TMockRadIARuntimeActionFacade.ExecuteAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Inc(FExecuteCount);
  if FFailExecution then
    Result := TRadIARuntimeActionResult.Failed(
      'mock_action_failed',
      'Mock runtime action failed.'
    )
  else
    Result := TRadIARuntimeActionResult.Succeeded;
end;

function TMockRadIARuntimeActionFacade.ValidateAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Inc(FValidationCount);
  if FRejectDynamicTarget and (FValidationCount > 1) then
    Exit(TRadIARuntimeActionResult.Failed(
      'runtime_target_not_found',
      'Mock dynamic runtime target is not visible yet.'
    ));
  if FRejectValidation then
    Result := TRadIARuntimeActionResult.Failed(
      'mock_action_rejected',
      'Mock runtime action was rejected.'
    )
  else
    Result := TRadIARuntimeActionResult.Succeeded;
end;

procedure TTestRadIARuntimeScenario.
  PrepareAllowsTargetRevealedByPriorAction;
var
  LPreview: TRadIARuntimeScenarioPreview;
begin
  FMock.RejectDynamicTarget := True;
  LPreview := FCoordinator.Prepare(
    Scenario(
      [
        Action(rakInvoke, StringOfChar('a', 64)),
        Action(rakCancel, StringOfChar('b', 64))
      ]
    )
  );
  Assert.AreEqual(36, Length(LPreview.PreviewId));
  Assert.AreEqual(2, LPreview.ActionCount);
end;

function TTestRadIARuntimeScenario.Action(
  const AKind: TRadIARuntimeActionKind;
  const ATargetId: string;
  const AValue: string;
  const ATimeoutMs: Cardinal
): TRadIARuntimeScenarioAction;
begin
  Result := TRadIARuntimeScenarioAction.Create(
    AKind,
    TRadIARuntimeSelector.Create(
      ATargetId,
      '',
      '',
      '',
      ''
    ),
    AValue,
    ATimeoutMs
  );
end;

procedure TTestRadIARuntimeScenario.CancelInterruptsWaitImmediately;
var
  LPreview: TRadIARuntimeScenarioPreview;
  LStatus: TRadIARuntimeScenarioStatus;
  LTask: ITask;
begin
  LPreview := FCoordinator.Prepare(
    Scenario([Action(rakWait, '', '', 5000)], 1, 10000)
  );
  LTask := TTask.Run(
    procedure
    begin
      LStatus := FCoordinator.Run(
        LPreview.PreviewId,
        FSession,
        nil
      );
    end
  );
  while FCoordinator.GetStatus.State <> rssRunning do
    TThread.Yield;
  Assert.IsTrue(FCoordinator.Cancel);
  Assert.IsTrue(LTask.Wait(2000));
  Assert.AreEqual(rssCancelled, LStatus.State);
end;

procedure TTestRadIARuntimeScenario.FailedActionStopsScenario;
var
  LPreview: TRadIARuntimeScenarioPreview;
  LStatus: TRadIARuntimeScenarioStatus;
begin
  FMock.FailExecution := True;
  LPreview := FCoordinator.Prepare(
    Scenario([Action(rakInvoke, StringOfChar('a', 64))])
  );
  LStatus := FCoordinator.Run(
    LPreview.PreviewId,
    FSession,
    nil
  );
  Assert.AreEqual(rssFailed, LStatus.State);
  Assert.AreEqual('mock_action_failed', LStatus.ErrorCode);
  Assert.AreEqual(0, LStatus.CompletedActions);
end;

procedure TTestRadIARuntimeScenario.PrepareValidatesEveryAction;
var
  LPreview: TRadIARuntimeScenarioPreview;
begin
  FMock.RejectValidation := True;
  LPreview := Default(TRadIARuntimeScenarioPreview);
  Assert.WillRaise(
    procedure
    begin
      LPreview := FCoordinator.Prepare(
        Scenario([Action(rakInvoke, StringOfChar('a', 64))])
      );
    end,
    EArgumentException
  );
  Assert.AreEqual('', LPreview.PreviewId);
end;

procedure TTestRadIARuntimeScenario.RunRejectsChangedSession;
var
  LChangedSession: TRadIARuntimeSessionIdentity;
  LPreview: TRadIARuntimeScenarioPreview;
  LStatus: TRadIARuntimeScenarioStatus;
begin
  LPreview := FCoordinator.Prepare(
    Scenario([Action(rakInvoke, StringOfChar('a', 64))])
  );
  LChangedSession := TRadIARuntimeSessionIdentity.Create(
    'different-session',
    FSession.ProcessId,
    FSession.CreatedAtUtc,
    FSession.ExecutablePath,
    FSession.ProjectPath,
    FSession.BuildId
  );
  LStatus := Default(TRadIARuntimeScenarioStatus);
  Assert.WillRaise(
    procedure
    begin
      LStatus := FCoordinator.Run(
        LPreview.PreviewId,
        LChangedSession,
        nil
      );
    end,
    EInvalidOp
  );
  Assert.AreEqual(rssIdle, LStatus.State);
end;

procedure TTestRadIARuntimeScenario.RunCompletesTenStableRepetitions;
var
  LPreview: TRadIARuntimeScenarioPreview;
  LStatus: TRadIARuntimeScenarioStatus;
begin
  LPreview := FCoordinator.Prepare(
    Scenario(
      [
        Action(rakInvoke, StringOfChar('a', 64)),
        Action(rakAssert, StringOfChar('b', 64), 'ready')
      ],
      10
    )
  );
  LStatus := FCoordinator.Run(
    LPreview.PreviewId,
    FSession,
    nil
  );
  Assert.AreEqual(rssSucceeded, LStatus.State);
  Assert.AreEqual(20, LStatus.CompletedActions);
  Assert.AreEqual(20, FMock.ExecuteCount);
end;

procedure TTestRadIARuntimeScenario.RunStopsAtGlobalTimeout;
var
  LPreview: TRadIARuntimeScenarioPreview;
  LStarted: TDateTime;
  LStatus: TRadIARuntimeScenarioStatus;
begin
  LPreview := FCoordinator.Prepare(
    Scenario([Action(rakWait, '', '', 120)], 2, 150)
  );
  LStarted := Now;
  LStatus := FCoordinator.Run(LPreview.PreviewId, FSession, nil);
  Assert.AreEqual(rssFailed, LStatus.State);
  Assert.AreEqual('runtime_scenario_timeout', LStatus.ErrorCode);
  Assert.IsTrue(
    MilliSecondsBetween(Now, LStarted) < 1000,
    'Global timeout must cap the remaining repeated action time.'
  );
end;

procedure TTestRadIARuntimeScenario.
  ToolsKeepRunBehindConsentAndCancelImmediate;
var
  LDebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
  LRegistry: IRadIAToolRegistry;
begin
  LDebugCoordinator := TRadIARuntimeDebugSessionCoordinator.Create;
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIARuntimeScenarioTools(
    LRegistry,
    LDebugCoordinator,
    FCoordinator
  );
  Assert.AreEqual(4, LRegistry.Count);
  Assert.AreEqual(
    trExecution,
    LRegistry.Resolve('RunRuntimeScenario').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('CancelRuntimeScenario').Descriptor.Risk
  );
  Assert.IsFalse(
    LRegistry.Resolve('RunRuntimeScenario').Descriptor.Idempotent
  );
  Assert.IsTrue(
    LRegistry.Resolve('RunRuntimeScenario').Descriptor.ConsentEveryTime
  );
end;

function TTestRadIARuntimeScenario.Scenario(
  const AActions: TArray<TRadIARuntimeScenarioAction>;
  const ARepetitions: Integer;
  const AMaxDurationMs: Cardinal
): TRadIARuntimeScenario;
begin
  Result := TRadIARuntimeScenario.Create(
    'Runtime scenario test',
    FSession,
    TRadIARuntimeScenarioLimits.Create(
      Length(AActions),
      AMaxDurationMs,
      ARepetitions
    ),
    AActions
  );
end;

procedure TTestRadIARuntimeScenario.Setup;
begin
  FSession := TRadIARuntimeSessionIdentity.Create(
    'runtime-scenario-session',
    100,
    Now,
    'C:\Tests\RuntimeScenario.exe',
    'C:\Tests\RuntimeScenario.dproj',
    'runtime-scenario-build'
  );
  FMock := TMockRadIARuntimeActionFacade.Create;
  FActionFacade := FMock;
  FCoordinator := TRadIARuntimeScenarioCoordinator.Create(
    FActionFacade
  );
end;

procedure TTestRadIARuntimeScenario.TearDown;
begin
  FCoordinator := nil;
  FActionFacade := nil;
  FMock := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimeScenario);

end.
