unit RadIA.Tests.RuntimePerformance;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimePerformance,
  RadIA.Core.RuntimeScenario;

type
  [TestFixture]
  TTestRadIARuntimePerformance = class
  private
    FCoordinator: IRadIARuntimePerformanceCoordinator;
    FDebug: IRadIARuntimeDebugSessionCoordinator;
    FSampler: IRadIARuntimePerformanceSampler;
    FScenario: IRadIARuntimeScenarioCoordinator;
    procedure AttachSession(const ABuildId: string);
    function CompleteEvidenceId: string;
    function PrepareScenario: TRadIARuntimeScenarioPreview;
    procedure RunSuccessfulScenario;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure ComparesSameScenarioAcrossDistinctBuilds;
    [Test]
    procedure RejectsIncompleteScenario;
    [Test]
    procedure SamplesCurrentProcessWithinBounds;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.Tools,
  RadIA.OTA.RuntimePerformance;

type
  TRadIATestPerformanceSampler = class(
    TInterfacedObject,
    IRadIARuntimePerformanceSampler
  )
  private
    FActive: Boolean;
  public
    function BeginMeasurement(
      const AProcessId: LongWord;
      const AMaximumDurationMs: Cardinal;
      out AErrorMessage: string
    ): Boolean;
    function CompleteMeasurement(
      out ASummary: TRadIARuntimePerformanceSummary;
      out AErrorMessage: string
    ): Boolean;
    procedure CancelMeasurement;
  end;

  TRadIATestRuntimeActionFacade = class(
    TInterfacedObject,
    IRadIARuntimeActionFacade
  )
  public
    function ExecuteAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
    function ValidateAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
  end;

function TRadIATestPerformanceSampler.BeginMeasurement(
  const AProcessId: LongWord;
  const AMaximumDurationMs: Cardinal;
  out AErrorMessage: string
): Boolean;
begin
  AErrorMessage := '';
  FActive := (AProcessId > 0) and (AMaximumDurationMs >= 100);
  Result := FActive;
end;

procedure TRadIATestPerformanceSampler.CancelMeasurement;
begin
  FActive := False;
end;

function TRadIATestPerformanceSampler.CompleteMeasurement(
  out ASummary: TRadIARuntimePerformanceSummary;
  out AErrorMessage: string
): Boolean;
begin
  AErrorMessage := '';
  Result := FActive;
  if Result then
    ASummary := TRadIARuntimePerformanceSummary.Create(
      1000,
      200,
      32 * 1024 * 1024,
      24 * 1024 * 1024,
      10,
      0
    );
  FActive := False;
end;

function TRadIATestRuntimeActionFacade.ExecuteAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Result := TRadIARuntimeActionResult.Succeeded('ok');
end;

function TRadIATestRuntimeActionFacade.ValidateAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Result := TRadIARuntimeActionResult.Succeeded('ok');
end;

procedure TTestRadIARuntimePerformance.Setup;
begin
  FDebug := TRadIARuntimeDebugSessionCoordinator.Create;
  FScenario := TRadIARuntimeScenarioCoordinator.Create(
    TRadIATestRuntimeActionFacade.Create
  );
  FSampler := TRadIATestPerformanceSampler.Create;
  FCoordinator := TRadIARuntimePerformanceCoordinator.Create(
    FDebug,
    FScenario,
    FSampler
  );
end;

procedure TTestRadIARuntimePerformance.AttachSession(const ABuildId: string);
var
  LSessionId: string;
begin
  LSessionId := FDebug.BeginSession('C:\Workspace\Sample.dproj');
  Assert.IsTrue(FDebug.AttachProcess(
    LSessionId,
    4242,
    Now,
    'C:\Workspace\Sample.exe',
    ABuildId
  ));
end;

function TTestRadIARuntimePerformance.PrepareScenario:
  TRadIARuntimeScenarioPreview;
var
  LAction: TRadIARuntimeScenarioAction;
  LScenario: TRadIARuntimeScenario;
begin
  LAction := TRadIARuntimeScenarioAction.Create(
    rakAssert,
    TRadIARuntimeSelector.Create('', 'TLabel', '', 'Ready', 'MainForm'),
    'Ready',
    1000
  );
  LScenario := TRadIARuntimeScenario.Create(
    'performance-test',
    FDebug.GetCurrentSession,
    TRadIARuntimeScenarioLimits.Create(4, 5000, 1),
    [LAction]
  );
  Result := FScenario.Prepare(LScenario);
end;

procedure TTestRadIARuntimePerformance.RunSuccessfulScenario;
var
  LPreview: TRadIARuntimeScenarioPreview;
begin
  LPreview := PrepareScenario;
  Assert.IsTrue(FCoordinator.BeginMeasurement('checkout', 5000).Success);
  Assert.AreEqual(
    rssSucceeded,
    FScenario.Run(LPreview.PreviewId, FDebug.GetCurrentSession, nil).State
  );
end;

function TTestRadIARuntimePerformance.CompleteEvidenceId: string;
var
  LJson: TJSONObject;
  LResult: TRadIAToolResult;
begin
  LResult := FCoordinator.CompleteMeasurement;
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  LJson := TJSONObject.ParseJSONValue(LResult.ContentJson) as TJSONObject;
  try
    Result := LJson.GetValue<string>('evidenceId', '');
  finally
    LJson.Free;
  end;
  Assert.IsNotEmpty(Result);
end;

procedure TTestRadIARuntimePerformance.ComparesSameScenarioAcrossDistinctBuilds;
var
  LBaselineId: string;
  LResult: TRadIAToolResult;
  LVerificationId: string;
begin
  AttachSession('build-1');
  RunSuccessfulScenario;
  LBaselineId := CompleteEvidenceId;
  AttachSession('build-2');
  RunSuccessfulScenario;
  LVerificationId := CompleteEvidenceId;
  LResult := FCoordinator.Compare(LBaselineId, LVerificationId);
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"comparable":true');
  Assert.Contains(LResult.ContentJson, '"regressionDetected":false');
end;

procedure TTestRadIARuntimePerformance.RejectsIncompleteScenario;
var
  LResult: TRadIAToolResult;
begin
  AttachSession('build-1');
  PrepareScenario;
  Assert.IsTrue(FCoordinator.BeginMeasurement('checkout', 5000).Success);
  LResult := FCoordinator.CompleteMeasurement;
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('performance_scenario_incomplete', LResult.ErrorCode);
end;

procedure TTestRadIARuntimePerformance.SamplesCurrentProcessWithinBounds;
var
  LError: string;
  LProductionSampler: IRadIARuntimePerformanceSampler;
  LSummary: TRadIARuntimePerformanceSummary;
begin
  LProductionSampler := TRadIAWindowsRuntimePerformanceSampler.Create;
  Assert.IsTrue(LProductionSampler.BeginMeasurement(
    GetCurrentProcessId,
    5000,
    LError
  ), LError);
  Sleep(250);
  Assert.IsTrue(LProductionSampler.CompleteMeasurement(LSummary, LError), LError);
  Assert.IsTrue(LSummary.IsUsable);
  Assert.IsTrue(LSummary.SampleCount >= 2);
  Assert.IsTrue(LSummary.PeakWorkingSetBytes > 0);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimePerformance);

end.
