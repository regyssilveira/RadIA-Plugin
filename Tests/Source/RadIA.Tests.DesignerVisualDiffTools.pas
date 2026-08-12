unit RadIA.Tests.DesignerVisualDiffTools;

interface

implementation

uses
  System.JSON,
  DUnitX.TestFramework,
  RadIA.Core.Designer,
  RadIA.Core.DesignerVisualDiff,
  RadIA.Core.DesignerVisualDiffTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Tests.DesignerVisualDiff;

type
  [TestFixture]
  TTestRadIADesignerVisualDiffTools = class
  private
    FFacade: TRadIADesignerVisualDiffFacadeStub;
    FExecutor: IRadIAToolExecutor;
    FRegistry: IRadIAToolRegistry;
    function Execute(
      const AName: string;
      const AArguments: string
    ): TRadIAToolResult;
    function JsonString(
      const AJson: string;
      const AName: string
    ): string;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure CapturesComparesRejectsAndClears;
    [Test]
    procedure RegistersExpectedRiskLevels;
  end;

function BuildComponent(
  const ALeft: Integer;
  const ACaption: string
): TRadIAFormComponentSnapshot;
begin
  Result := TRadIAFormComponentSnapshot.Create(
    'SaveButton',
    'TButton',
    'MainForm',
    True,
    False,
    ALeft,
    20
  );
  Result.SetSize(90, 25);
  Result.SetProperties([
    TRadIAComponentPropertyValue.Create(
      'Caption',
      'string',
      ACaption
    )
  ]);
end;

procedure TTestRadIADesignerVisualDiffTools.CapturesComparesRejectsAndClears;
var
  LAfterId: string;
  LBeforeId: string;
  LComparisonId: string;
  LResult: TRadIAToolResult;
begin
  FFacade.SetComponents([BuildComponent(10, 'Save')]);
  LResult := Execute('CaptureDesignerVisualSnapshot', '{}');
  Assert.IsTrue(LResult.Success);
  LBeforeId := JsonString(LResult.ContentJson, 'snapshotId');
  FFacade.SetComponents([BuildComponent(30, 'Save changes')]);
  LResult := Execute('CaptureDesignerVisualSnapshot', '{}');
  LAfterId := JsonString(LResult.ContentJson, 'snapshotId');

  LResult := Execute(
    'CompareDesignerVisualSnapshots',
    '{"beforeId":"' + LBeforeId + '","afterId":"' +
      LAfterId + '"}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"kind":"moved"');
  Assert.Contains(LResult.ContentJson, '"kind":"propertyChanged"');
  LComparisonId := JsonString(LResult.ContentJson, 'comparisonId');

  LResult := Execute(
    'DecideDesignerVisualDiff',
    '{"comparisonId":"' + LComparisonId + '","decision":"reject"}'
  );
  Assert.Contains(LResult.ContentJson, '"state":"rejected"');
  Assert.Contains(LResult.ContentJson, '"designerMutated":false');

  LResult := Execute('ClearDesignerVisualDiffArtifacts', '{}');
  Assert.Contains(LResult.ContentJson, '"cleared":true');
  Assert.Contains(LResult.ContentJson, '"storage":"memory"');
end;

function TTestRadIADesignerVisualDiffTools.Execute(
  const AName: string;
  const AArguments: string
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(AName, AArguments, 'visual-diff-test')
  );
end;

function TTestRadIADesignerVisualDiffTools.JsonString(
  const AJson: string;
  const AName: string
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  try
    Result := LJson.GetValue<string>(AName);
  finally
    LJson.Free;
  end;
end;

procedure TTestRadIADesignerVisualDiffTools.RegistersExpectedRiskLevels;
begin
  Assert.AreEqual(4, FRegistry.Count);
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('CaptureDesignerVisualSnapshot').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('CompareDesignerVisualSnapshots').Descriptor.Risk
  );
  Assert.AreEqual(
    trReversibleWrite,
    FRegistry.Resolve('DecideDesignerVisualDiff').Descriptor.Risk
  );
end;

procedure TTestRadIADesignerVisualDiffTools.Setup;
var
  LService: IRadIADesignerVisualDiffService;
begin
  FFacade := TRadIADesignerVisualDiffFacadeStub.Create;
  LService := TRadIADesignerVisualDiffService.Create(FFacade);
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIADesignerVisualDiffTools(FRegistry, LService);
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADesignerVisualDiffTools);

end.
