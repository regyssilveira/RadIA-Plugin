unit RadIA.Tests.DebuggerInspectionTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Debugger,
  RadIA.Core.DebuggerWatches,
  RadIA.Core.Tools;

type
  TRadIAFakeDebuggerInspection = class(
    TInterfacedObject,
    IRadIADebuggerEvaluationFacade,
    IRadIADebuggerSessionFacade
  )
  private
    FStartCount: Integer;
  public
    function EvaluateExpression(
      const AExpression: string
    ): TRadIADebugValueSnapshot;
    function StartDebugging: TRadIADebuggerActionResult;
    property StartCount: Integer read FStartCount;
  end;

  [TestFixture]
  TTestRadIADebuggerInspectionTools = class
  private
    FEvaluator: TRadIAFakeDebuggerInspection;
    FExecutor: IRadIAToolExecutor;
    FRegistry: IRadIAToolRegistry;
    FWatches: IRadIADebuggerWatchService;
    function ExecuteTool(
      const AName: string;
      const AArgumentsJson: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure AddsListsAndRemovesWatch;
    [Test]
    procedure RejectsDuplicateWatch;
    [Test]
    procedure EnforcesWatchLimit;
    [Test]
    procedure EvaluatesAllWatches;
    [Test]
    procedure RejectsMultilineWatch;
    [Test]
    procedure RegistersExpectedRiskLevels;
    [Test]
    procedure SerializesExpressionEvaluation;
    [Test]
    procedure StartsDebuggerThroughSessionFacade;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.DebuggerInspectionTools,
  RadIA.Core.ToolRegistry;

function TRadIAFakeDebuggerInspection.EvaluateExpression(
  const AExpression: string
): TRadIADebugValueSnapshot;
begin
  Result := TRadIADebugValueSnapshot.Create(
    AExpression,
    '42',
    'ok',
    True,
    4096,
    4
  );
end;

function TRadIAFakeDebuggerInspection.StartDebugging:
  TRadIADebuggerActionResult;
begin
  Inc(FStartCount);
  Result := TRadIADebuggerActionResult.Succeeded(
    'Started.',
    'no_process',
    'starting'
  );
end;

procedure TTestRadIADebuggerInspectionTools.AddsListsAndRemovesWatch;
var
  LExpressions: TArray<string>;
begin
  Assert.IsTrue(FWatches.Add('LCustomer.Id'));
  LExpressions := FWatches.List;
  Assert.AreEqual<Integer>(1, Length(LExpressions));
  Assert.AreEqual('LCustomer.Id', LExpressions[0]);
  Assert.IsTrue(FWatches.Remove('lcustomer.id'));
  Assert.AreEqual<Integer>(0, Length(FWatches.List));
end;

procedure TTestRadIADebuggerInspectionTools.EnforcesWatchLimit;
var
  LIndex: Integer;
begin
  for LIndex := 1 to 32 do
    Assert.IsTrue(FWatches.Add('LValue' + LIndex.ToString));
  Assert.IsFalse(FWatches.Add('LValue33'));
end;

function TTestRadIADebuggerInspectionTools.ExecuteTool(
  const AName: string;
  const AArgumentsJson: string
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(
      AName,
      AArgumentsJson,
      'debug-inspection-test'
    )
  );
end;

procedure TTestRadIADebuggerInspectionTools.EvaluatesAllWatches;
var
  LValues: TArray<TRadIADebugValueSnapshot>;
begin
  FWatches.Add('LCount');
  FWatches.Add('LTotal');
  LValues := FWatches.Evaluate(32);
  Assert.AreEqual<Integer>(2, Length(LValues));
  Assert.AreEqual('42', LValues[0].ResultText);
  Assert.AreEqual('ok', LValues[1].Status);
end;

procedure TTestRadIADebuggerInspectionTools.RegistersExpectedRiskLevels;
begin
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('EvaluateDebuggerExpression').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    FRegistry.Resolve('AddDebuggerWatch').Descriptor.Risk
  );
  Assert.AreEqual(
    trExecution,
    FRegistry.Resolve('StartDebugging').Descriptor.Risk
  );
end;

procedure TTestRadIADebuggerInspectionTools.RejectsDuplicateWatch;
begin
  Assert.IsTrue(FWatches.Add('LCount'));
  Assert.IsFalse(FWatches.Add('lcount'));
end;

procedure TTestRadIADebuggerInspectionTools.RejectsMultilineWatch;
begin
  try
    FWatches.Add('LValue' + sLineBreak + 'Other');
    Assert.Fail('A multiline watch must be rejected.');
  except
    on E: EArgumentException do
      Assert.IsNotEmpty(E.Message);
  end;
end;

procedure TTestRadIADebuggerInspectionTools.SerializesExpressionEvaluation;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'EvaluateDebuggerExpression',
    '{"expression":"LCount"}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.IsTrue(LResult.ContentJson.Contains('"result":"42"'));
  Assert.IsTrue(LResult.ContentJson.Contains('"status":"ok"'));
end;

procedure TTestRadIADebuggerInspectionTools.Setup;
begin
  FEvaluator := TRadIAFakeDebuggerInspection.Create;
  FWatches := TRadIADebuggerWatchService.Create(FEvaluator);
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIADebuggerInspectionTools(
    FRegistry,
    FEvaluator,
    FWatches,
    FEvaluator
  );
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

procedure TTestRadIADebuggerInspectionTools.StartsDebuggerThroughSessionFacade;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('StartDebugging', '{}');
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(1, FEvaluator.StartCount);
  Assert.IsTrue(LResult.ContentJson.Contains('"stateAfter":"starting"'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADebuggerInspectionTools);

end.
