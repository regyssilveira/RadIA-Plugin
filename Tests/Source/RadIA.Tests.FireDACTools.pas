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
    procedure RejectsMissingSql;
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

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACToolsTests);

end.
