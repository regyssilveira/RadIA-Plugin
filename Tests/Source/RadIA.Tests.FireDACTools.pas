unit RadIA.Tests.FireDACTools;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACToolsTests = class
  public
    [Test]
    procedure RegistersReadOnlyQueryAndParameterTools;
    [Test]
    procedure AnalyzesQueryWithoutEchoingOrExecutingSql;
    [Test]
    procedure ValidatesMissingAndExtraBindingsCaseInsensitively;
    [Test]
    procedure ValidatesTypedBindingMetadata;
    [Test]
    procedure RejectsMissingSql;
    [Test]
    procedure StructuresQueryExplanationWithoutEchoingSql;
    [Test]
    procedure StructuresFindingExplanationWithoutEvidenceInput;
  end;

implementation

uses
  RadIA.Core.FireDAC.Tools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools;

function CreateRegistry: IRadIAToolRegistry;
begin
  Result := TRadIAToolRegistry.Create;
  RegisterRadIAFireDACTools(Result);
end;

procedure TRadIAFireDACToolsTests.RegistersReadOnlyQueryAndParameterTools;
var
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := CreateRegistry;
  Assert.AreEqual(trReadOnly, LRegistry.Resolve('AnalyzeFireDACQuery').Descriptor.Risk);
  Assert.AreEqual(trReadOnly, LRegistry.Resolve('ValidateFireDACParameters').Descriptor.Risk);
end;

procedure TRadIAFireDACToolsTests.AnalyzesQueryWithoutEchoingOrExecutingSql;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := CreateRegistry;
  LResult := LRegistry.Resolve('AnalyzeFireDACQuery').Execute(TRadIAToolRequest.Create(
    'AnalyzeFireDACQuery',
    '{"sql":"select secret_value from account where id = :Id"}',
    'firedac-tool-test'
  ));
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"statementKind":"select"');
  Assert.Contains(LResult.ContentJson, '"sqlExecuted":false');
  Assert.DoesNotContain(LResult.ContentJson, 'secret_value');
end;

procedure TRadIAFireDACToolsTests.ValidatesMissingAndExtraBindingsCaseInsensitively;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := CreateRegistry;
  LResult := LRegistry.Resolve('ValidateFireDACParameters').Execute(TRadIAToolRequest.Create(
    'ValidateFireDACParameters',
    '{"sql":"select * from account where id = :Id and tenant = :Tenant",' +
    '"bindings":["ID","Unused"]}',
    'firedac-tool-test'
  ));
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"missingBindings":["Tenant"]');
  Assert.Contains(LResult.ContentJson, '"extraBindings":["Unused"]');
  Assert.Contains(LResult.ContentJson, '"valid":false');
end;

procedure TRadIAFireDACToolsTests.ValidatesTypedBindingMetadata;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := CreateRegistry;
  LResult := LRegistry.Resolve('ValidateFireDACParameters').Execute(TRadIAToolRequest.Create(
    'ValidateFireDACParameters',
    '{"sql":"select * from account where name = :Name",' +
    '"bindings":[{"name":"Name","dataType":"ftString","direction":"input",' +
    '"size":0,"nullable":"false","valueState":"null","assignmentKind":"AsInteger"}]}',
    'firedac-tool-test'
  ));
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'firedac.parameter.string-size-missing');
  Assert.Contains(LResult.ContentJson, 'firedac.parameter.null-not-allowed');
  Assert.Contains(LResult.ContentJson, 'firedac.parameter.assignment-type-mismatch');
  Assert.Contains(LResult.ContentJson, '"direction":"input"');
end;

procedure TRadIAFireDACToolsTests.RejectsMissingSql;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := CreateRegistry;
  LResult := LRegistry.Resolve('AnalyzeFireDACQuery').Execute(TRadIAToolRequest.Create(
    'AnalyzeFireDACQuery',
    '{"sql":""}',
    'firedac-tool-test'
  ));
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('sql_required', LResult.ErrorCode);
end;

procedure TRadIAFireDACToolsTests.StructuresQueryExplanationWithoutEchoingSql;
var
  LResult: TRadIAToolResult;
begin
  LResult := CreateRegistry.Resolve('ExplainFireDACQuery').Execute(TRadIAToolRequest.Create(
    'ExplainFireDACQuery',
    '{"sql":"select private_token from account where id = :Id"}',
    'explain-query'
  ));
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"deterministicFacts"');
  Assert.Contains(LResult.ContentJson, '"hypotheses"');
  Assert.Contains(LResult.ContentJson, '"limitations"');
  Assert.Contains(LResult.ContentJson, '"contentTrust":"untrusted-data"');
  Assert.DoesNotContain(LResult.ContentJson, 'private_token');
end;

procedure TRadIAFireDACToolsTests.StructuresFindingExplanationWithoutEvidenceInput;
var
  LResult: TRadIAToolResult;
begin
  LResult := CreateRegistry.Resolve('ExplainFireDACFinding').Execute(TRadIAToolRequest.Create(
    'ExplainFireDACFinding',
    '{"ruleId":"firedac.schema.column-missing","severity":"high",' +
    '"confidence":"proven","automaticFixAvailable":false}',
    'explain-finding'
  ));
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'firedac.schema.column-missing');
  Assert.Contains(LResult.ContentJson, 'must not invent schema');
  Assert.DoesNotContain(LResult.ContentJson, 'evidence');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACToolsTests);

end.
