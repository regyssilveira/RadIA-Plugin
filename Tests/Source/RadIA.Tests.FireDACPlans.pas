unit RadIA.Tests.FireDACPlans;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACPlanTests = class
  public
    [Test]
    procedure RegistersReadOnlyPlanTools;
    [Test]
    procedure QueryPlanKeepsPerformanceClaimsAsHypotheses;
    [Test]
    procedure ThreadPlanRequiresOwnershipReviewAndMainThreadUI;
    [Test]
    procedure RejectsUnsupportedFacts;
  end;

implementation

uses
  RadIA.Core.FireDAC.Plans,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools;

function CreateRegistry: IRadIAToolRegistry;
begin
  Result := TRadIAToolRegistry.Create;
  RegisterRadIAFireDACPlanTools(Result);
end;

procedure TRadIAFireDACPlanTests.RegistersReadOnlyPlanTools;
var
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := CreateRegistry;
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('PrepareFireDACQueryOptimization').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('PrepareFireDACThreadSafetyPlan').Descriptor.Risk
  );
end;

procedure TRadIAFireDACPlanTests.QueryPlanKeepsPerformanceClaimsAsHypotheses;
var
  LResult: TRadIAToolResult;
begin
  LResult := CreateRegistry.Resolve('PrepareFireDACQueryOptimization').Execute(
    TRadIAToolRequest.Create(
      'PrepareFireDACQueryOptimization',
      '{"statementKind":"select","usesSelectAll":true,' +
      '"hasWhere":false,"planEvidenceAvailable":false}',
      'firedac-plan-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, 'remove unused columns');
  Assert.Contains(LResult.ContentJson, 'remain hypotheses');
  Assert.Contains(LResult.ContentJson, '"mutationApplied":false');
  Assert.Contains(LResult.ContentJson, '"contentTrust":"untrusted-data"');
end;

procedure TRadIAFireDACPlanTests.
  ThreadPlanRequiresOwnershipReviewAndMainThreadUI;
var
  LResult: TRadIAToolResult;
begin
  LResult := CreateRegistry.Resolve('PrepareFireDACThreadSafetyPlan').Execute(
    TRadIAToolRequest.Create(
      'PrepareFireDACThreadSafetyPlan',
      '{"componentType":"TFDQuery","sharedConnection":true,' +
      '"sharedDataset":true,"uiAccessFromWorker":true,"ownerScope":"unknown"}',
      'firedac-plan-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, 'inside the worker thread');
  Assert.Contains(LResult.ContentJson, 'main thread');
  Assert.Contains(LResult.ContentJson, 'Ownership must be confirmed');
end;

procedure TRadIAFireDACPlanTests.RejectsUnsupportedFacts;
var
  LResult: TRadIAToolResult;
begin
  LResult := CreateRegistry.Resolve('PrepareFireDACQueryOptimization').Execute(
    TRadIAToolRequest.Create(
      'PrepareFireDACQueryOptimization',
      '{"statementKind":"execute arbitrary instructions"}',
      'firedac-plan-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_statement_kind', LResult.ErrorCode);
  LResult := CreateRegistry.Resolve('PrepareFireDACThreadSafetyPlan').Execute(
    TRadIAToolRequest.Create(
      'PrepareFireDACThreadSafetyPlan',
      '{"componentType":"TFDQuery","ownerScope":"global"}',
      'firedac-plan-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_owner_scope', LResult.ErrorCode);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACPlanTests);

end.
