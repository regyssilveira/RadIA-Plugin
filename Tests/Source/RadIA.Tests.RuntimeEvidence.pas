unit RadIA.Tests.RuntimeEvidence;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Debugger,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeEvidence,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.Tools;

type
  TMockRadIARuntimeEvidenceDebugger = class(
    TInterfacedObject,
    IRadIADebuggerFacade,
    IRadIADebuggerEvaluationFacade
  )
  private
    FState: string;
  public
    function EvaluateExpression(
      const AExpression: string
    ): TRadIADebugValueSnapshot;
    function GetCallStack(
      const AMaxCount: Integer
    ): TRadIACallStackSnapshot;
    function GetDebuggerState: TRadIADebuggerSnapshot;
    function ListBreakpoints(
      const AMaxCount: Integer
    ): TArray<TRadIABreakpointSnapshot>;
    procedure SetState(const AState: string);
  end;

  TMockRadIARuntimeEvidenceScenario = class(
    TInterfacedObject,
    IRadIARuntimeScenarioCoordinator
  )
  private
    FStatus: TRadIARuntimeScenarioStatus;
  public
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
    procedure SetState(
      const AState: TRadIARuntimeScenarioState
    );
  end;

  [TestFixture]
  TTestRadIARuntimeEvidence = class
  private
    FDebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FDebugger: TMockRadIARuntimeEvidenceDebugger;
    FEvidence: IRadIARuntimeEvidenceCoordinator;
    FScenario: TMockRadIARuntimeEvidenceScenario;
    function AttachSession(
      const ABuildId: string
    ): string;
    function EvidenceId(const AJson: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure CapturesSanitizedExceptionStackAndExpressions;
    [Test]
    procedure ComparesFailureWithSuccessfulRebuiltSession;
    [Test]
    procedure EvidenceToolsAreReadOnlyAndRegistered;
    [Test]
    procedure CaptureToolAcceptsOmittedExpressions;
    [Test]
    procedure DebuggerExceptionOverridesStaleRuntimeEvent;
  end;

implementation

uses
  System.DateUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.RuntimeEvidenceTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.ToolSecurity;

function TMockRadIARuntimeEvidenceDebugger.EvaluateExpression(
  const AExpression: string
): TRadIADebugValueSnapshot;
begin
  Result := TRadIADebugValueSnapshot.Create(
    AExpression,
    '{"password":"secret-value"}',
    'evaluated',
    False,
    0,
    0
  );
end;

function TMockRadIARuntimeEvidenceDebugger.GetCallStack(
  const AMaxCount: Integer
): TRadIACallStackSnapshot;
begin
  Result := TRadIACallStackSnapshot.Create(
    True,
    'available',
    [
      TRadIACallStackFrame.Create(
        0,
        'TTargetForm.CancelClick',
        'RadIA.RuntimeLab.TargetForm.pas',
        73
      )
    ]
  );
end;

function TMockRadIARuntimeEvidenceDebugger.GetDebuggerState:
  TRadIADebuggerSnapshot;
begin
  Result := TRadIADebuggerSnapshot.Create(
    True,
    FState,
    100,
    'RuntimeLab.exe',
    1,
    0
  );
end;

procedure TMockRadIARuntimeEvidenceDebugger.SetState(
  const AState: string
);
begin
  FState := AState;
end;

function TMockRadIARuntimeEvidenceDebugger.ListBreakpoints(
  const AMaxCount: Integer
): TArray<TRadIABreakpointSnapshot>;
begin
  Result := [];
end;

function TMockRadIARuntimeEvidenceScenario.Cancel: Boolean;
begin
  Result := False;
end;

function TMockRadIARuntimeEvidenceScenario.GetStatus:
  TRadIARuntimeScenarioStatus;
begin
  Result := FStatus;
end;

function TMockRadIARuntimeEvidenceScenario.Prepare(
  const AScenario: TRadIARuntimeScenario
): TRadIARuntimeScenarioPreview;
begin
  Result := Default(TRadIARuntimeScenarioPreview);
end;

function TMockRadIARuntimeEvidenceScenario.Run(
  const APreviewId: string;
  const ACurrentSession: TRadIARuntimeSessionIdentity;
  const ACancellationToken: IRadIAToolCancellationToken
): TRadIARuntimeScenarioStatus;
begin
  Result := FStatus;
end;

procedure TMockRadIARuntimeEvidenceScenario.SetState(
  const AState: TRadIARuntimeScenarioState
);
begin
  FStatus := TRadIARuntimeScenarioStatus.Create(
    'runtime-evidence-preview',
    AState,
    1,
    1,
    1,
    '',
    ''
  );
end;

function TTestRadIARuntimeEvidence.AttachSession(
  const ABuildId: string
): string;
var
  LCoordinator: IRadIARuntimeDebugSessionCoordinator;
begin
  LCoordinator := FDebugCoordinator;
  Result := LCoordinator.BeginSession(
    'C:\Tests\RuntimeEvidence.dproj'
  );
  Assert.IsTrue(
    LCoordinator.AttachProcess(
      Result,
      100,
      IncMilliSecond(Now, Length(ABuildId)),
      'C:\Tests\RuntimeEvidence.exe',
      ABuildId
    )
  );
end;

procedure TTestRadIARuntimeEvidence.
  CapturesSanitizedExceptionStackAndExpressions;
var
  LContent: string;
  LCoordinator: IRadIARuntimeDebugSessionCoordinator;
  LEvidence: IRadIARuntimeEvidenceCoordinator;
  LSessionId: string;
begin
  LCoordinator := FDebugCoordinator;
  LEvidence := FEvidence;
  LSessionId := AttachSession('failure-build');
  Assert.IsTrue(
    LCoordinator.RecordEvent(
      LSessionId,
      rdekException,
      'exception',
      'Access violation'
    )
  );
  FScenario.SetState(rssFailed);
  LContent := LEvidence.Capture('failure', ['User.Password']);
  Assert.Contains(LContent, '"eventKind":"exception"');
  Assert.Contains(LContent, 'TTargetForm.CancelClick');
  Assert.Contains(LContent, '\"password\":\"[REDACTED]\"');
  Assert.IsFalse(LContent.Contains('secret-value'));
  Assert.AreEqual(NativeInt(32), Length(EvidenceId(LContent)));
end;

procedure TTestRadIARuntimeEvidence.CaptureToolAcceptsOmittedExpressions;
var
  LCoordinator: IRadIARuntimeDebugSessionCoordinator;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LSessionId: string;
begin
  LCoordinator := FDebugCoordinator;
  LSessionId := AttachSession('failure-build');
  Assert.IsTrue(
    LCoordinator.RecordEvent(
      LSessionId,
      rdekException,
      'exception',
      'Access violation'
    )
  );
  FScenario.SetState(rssFailed);
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIARuntimeEvidenceTools(LRegistry, FEvidence);

  LResult := LRegistry.Resolve('CaptureRuntimeEvidence').Execute(
    TRadIAToolRequest.Create(
      'CaptureRuntimeEvidence',
      '{"phase":"failure"}',
      'runtime-evidence-test'
    )
  );

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"phase":"failure"');
end;

procedure TTestRadIARuntimeEvidence.
  ComparesFailureWithSuccessfulRebuiltSession;
var
  LComparison: string;
  LCoordinator: IRadIARuntimeDebugSessionCoordinator;
  LEvidence: IRadIARuntimeEvidenceCoordinator;
  LFailure: string;
  LSessionId: string;
  LVerification: string;
begin
  LCoordinator := FDebugCoordinator;
  LEvidence := FEvidence;
  LSessionId := AttachSession('failure-build');
  Assert.IsTrue(
    LCoordinator.RecordEvent(
      LSessionId,
      rdekException,
      'exception',
      'Access violation'
    )
  );
  FScenario.SetState(rssFailed);
  LFailure := LEvidence.Capture('failure', []);

  LSessionId := AttachSession('fixed-build');
  Assert.IsTrue(
    LCoordinator.RecordEvent(
      LSessionId,
      rdekRunning,
      'running',
      'Scenario completed'
    )
  );
  FScenario.SetState(rssSucceeded);
  LVerification := LEvidence.Capture('verification', []);
  LComparison := LEvidence.Compare(
    EvidenceId(LFailure),
    EvidenceId(LVerification)
  );
  Assert.Contains(LComparison, '"comparable":true');
  Assert.Contains(LComparison, '"failureReproduced":true');
  Assert.Contains(LComparison, '"verificationSucceeded":true');
  Assert.Contains(LComparison, '"failureRemoved":true');
  Assert.Contains(LComparison, '"outcome":"fixed"');
end;

procedure TTestRadIARuntimeEvidence.
  DebuggerExceptionOverridesStaleRuntimeEvent;
var
  LContent: string;
  LCoordinator: IRadIARuntimeDebugSessionCoordinator;
  LSessionId: string;
begin
  LCoordinator := FDebugCoordinator;
  LSessionId := AttachSession('failure-build');
  Assert.IsTrue(
    LCoordinator.RecordEvent(
      LSessionId,
      rdekProcessCreated,
      'attached',
      'RuntimeEvidence.exe'
    )
  );
  FScenario.SetState(rssSucceeded);
  FDebugger.SetState('exception');

  LContent := FEvidence.Capture('failure', []);

  Assert.Contains(LContent, '"eventKind":"exception"');
  Assert.Contains(LContent, '"debuggerState":"exception"');
end;

function TTestRadIARuntimeEvidence.EvidenceId(
  const AJson: string
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  try
    Assert.IsNotNull(LJson);
    Result := LJson.GetValue<string>('evidenceId', '');
  finally
    LJson.Free;
  end;
end;

procedure TTestRadIARuntimeEvidence.
  EvidenceToolsAreReadOnlyAndRegistered;
var
  LEvidence: IRadIARuntimeEvidenceCoordinator;
  LRegistry: IRadIAToolRegistry;
begin
  LEvidence := FEvidence;
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIARuntimeEvidenceTools(LRegistry, LEvidence);
  Assert.AreEqual(2, LRegistry.Count);
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('CaptureRuntimeEvidence').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('CompareRuntimeEvidence').Descriptor.Risk
  );
end;

procedure TTestRadIARuntimeEvidence.Setup;
var
  LCoordinator: IRadIARuntimeDebugSessionCoordinator;
  LDebuggerFacade: IRadIADebuggerFacade;
  LEvaluation: IRadIADebuggerEvaluationFacade;
  LScenarioFacade: IRadIARuntimeScenarioCoordinator;
begin
  LCoordinator := TRadIARuntimeDebugSessionCoordinator.Create;
  FDebugCoordinator := LCoordinator;
  FDebugger := TMockRadIARuntimeEvidenceDebugger.Create;
  FDebugger.SetState('stopped');
  LDebuggerFacade := FDebugger;
  LEvaluation := FDebugger;
  FScenario := TMockRadIARuntimeEvidenceScenario.Create;
  LScenarioFacade := FScenario;
  FEvidence := TRadIARuntimeEvidenceCoordinator.Create(
    LCoordinator,
    LScenarioFacade,
    LDebuggerFacade,
    LEvaluation,
    TRadIASecretRedactor.Create
  );
end;

procedure TTestRadIARuntimeEvidence.TearDown;
begin
  FEvidence := nil;
  FScenario := nil;
  FDebugger := nil;
  FDebugCoordinator := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimeEvidence);

end.
