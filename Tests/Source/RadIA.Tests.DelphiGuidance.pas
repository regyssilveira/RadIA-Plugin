unit RadIA.Tests.DelphiGuidance;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIADelphiGuidance = class
  public
    [Test]
    procedure FiltersRulesByEnvironmentAndTopic;
    [Test]
    procedure ReturnsStableCitationsAndPriorityOrder;
    [Test]
    procedure BuildsBoundedPromptContext;
    [Test]
    procedure RegistersReadOnlyGuidanceTool;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.DelphiGuidance,
  RadIA.Core.DelphiGuidanceTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools;

procedure TTestRadIADelphiGuidance.BuildsBoundedPromptContext;
var
  LCatalog: IRadIADelphiGuidanceCatalog;
  LContext: string;
begin
  LCatalog := TRadIADelphiGuidanceCatalog.Create;
  LContext := LCatalog.BuildPromptContext('Delphi 13', 'VCL', 'IDE64', 3);

  Assert.Contains(LContext, '[radia-delphi:ide64-pointer-safety@1]');
  Assert.AreEqual<Integer>(3, Length(LContext.Split([#10])));
end;

procedure TTestRadIADelphiGuidance.FiltersRulesByEnvironmentAndTopic;
var
  LCatalog: IRadIADelphiGuidanceCatalog;
  LRules: TArray<TRadIADelphiGuidanceRule>;
begin
  LCatalog := TRadIADelphiGuidanceCatalog.Create;
  LRules := LCatalog.Query(
    TRadIADelphiGuidanceQuery.Create(
      'Delphi 13',
      'VCL',
      'IDE64',
      'compatibility',
      '',
      10
    )
  );

  Assert.AreEqual<Integer>(2, Length(LRules));
  Assert.AreEqual('ide64-pointer-safety', LRules[0].Id);
  Assert.AreEqual('delphi13-supported-baseline', LRules[1].Id);
end;

procedure TTestRadIADelphiGuidance.RegistersReadOnlyGuidanceTool;
var
  LCatalog: IRadIADelphiGuidanceCatalog;
  LExecutor: IRadIAToolExecutor;
  LRegistry: IRadIAToolRegistry;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
  LTool: IRadIATool;
begin
  LCatalog := TRadIADelphiGuidanceCatalog.Create;
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIADelphiGuidanceTools(LRegistry, LCatalog);

  Assert.IsTrue(LRegistry.TryResolve('GetDelphiGuidance', LTool));
  Assert.AreEqual(trReadOnly, LTool.Descriptor.Risk);
  LExecutor := TRadIAToolExecutor.Create(LRegistry);
  LRequest := TRadIAToolRequest.Create(
    'GetDelphiGuidance',
    '{"version":"13","framework":"VCL",' +
    '"architecture":"IDE64","topic":"compatibility"}',
    'guidance-test'
  );
  LResult := LExecutor.Execute(LRequest);

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"schemaVersion":1');
  Assert.Contains(LResult.ContentJson, 'radia-delphi:ide64-pointer-safety@1');
  Assert.Contains(LResult.ContentJson, '"source":"built-in"');
end;

procedure TTestRadIADelphiGuidance.ReturnsStableCitationsAndPriorityOrder;
var
  LCatalog: IRadIADelphiGuidanceCatalog;
  LRules: TArray<TRadIADelphiGuidanceRule>;
begin
  LCatalog := TRadIADelphiGuidanceCatalog.Create;
  LRules := LCatalog.Query(
    TRadIADelphiGuidanceQuery.Create(
      'Delphi 13',
      'VCL',
      'IDE64',
      '',
      '',
      50
    )
  );

  Assert.IsTrue(Length(LRules) >= 8);
  Assert.AreEqual('ide64-pointer-safety', LRules[0].Id);
  Assert.AreEqual('[radia-delphi:ide64-pointer-safety@1]', LRules[0].Citation);
  Assert.IsTrue(LRules[0].Priority >= LRules[1].Priority);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADelphiGuidance);

end.
