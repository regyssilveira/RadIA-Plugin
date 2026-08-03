unit RadIA.Tests.DesignerProperties;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.DesignerProperties,
  RadIA.Core.Tools,
  RadIA.Tests.DesignerMutations;

type
  [TestFixture]
  TTestRadIADesignerProperties = class
  private
    FExecutor: IRadIAToolExecutor;
    FFacade: TRadIAFakeDesignerMutationFacade;
    FRegistry: IRadIAToolRegistry;
    FService: IRadIAComponentPropertyService;
    function ExecuteTool(
      const AName: string;
      const AArgumentsJson: string
    ): TRadIAToolResult;
    function PreparePreview: TRadIAToolResult;
    function ReadPreviewId(
      const AJson: string
    ): string;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure RegistersRiskLevels;
    [Test]
    procedure PreparesWithoutMutation;
    [Test]
    procedure AppliesAndRevertsProperty;
    [Test]
    procedure DetectsChangedPropertyBeforeApply;
    [Test]
    procedure RejectsUnsupportedProperty;
    [Test]
    procedure ReportsDesignerRejection;
  end;

implementation

uses
  System.JSON,
  RadIA.Core.DesignerPropertyTools,
  RadIA.Core.ToolRegistry;

procedure TTestRadIADesignerProperties.AppliesAndRevertsProperty;
var
  LApply: TRadIAToolResult;
  LPreview: TRadIAToolResult;
  LPreviewId: string;
  LRevert: TRadIAToolResult;
begin
  LPreview := PreparePreview;
  LPreviewId := ReadPreviewId(LPreview.ContentJson);

  LApply := ExecuteTool(
    'ApplyComponentProperty',
    '{"previewId":"' + LPreviewId + '"}'
  );
  Assert.IsTrue(LApply.Success);
  Assert.AreEqual('Save changes', FFacade.Caption);

  LRevert := ExecuteTool(
    'RevertComponentProperty',
    '{"previewId":"' + LPreviewId + '"}'
  );
  Assert.IsTrue(LRevert.Success);
  Assert.AreEqual('Save', FFacade.Caption);
end;

procedure TTestRadIADesignerProperties.DetectsChangedPropertyBeforeApply;
var
  LPreview: TRadIAToolResult;
  LResult: TRadIAToolResult;
begin
  LPreview := PreparePreview;
  FFacade.Caption := 'Changed externally';

  LResult := ExecuteTool(
    'ApplyComponentProperty',
    '{"previewId":"' +
      ReadPreviewId(LPreview.ContentJson) + '"}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
end;

function TTestRadIADesignerProperties.ExecuteTool(
  const AName: string;
  const AArgumentsJson: string
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(
      AName,
      AArgumentsJson,
      'designer-property-test'
    )
  );
end;

function TTestRadIADesignerProperties.PreparePreview:
  TRadIAToolResult;
begin
  Result := ExecuteTool(
    'PrepareComponentProperty',
    '{"componentName":"SaveButton","propertyName":"Caption",' +
      '"value":"Save changes"}'
  );
  Assert.IsTrue(Result.Success);
end;

procedure TTestRadIADesignerProperties.PreparesWithoutMutation;
var
  LResult: TRadIAToolResult;
begin
  LResult := PreparePreview;

  Assert.Contains(LResult.ContentJson, '"propertyName":"Caption"');
  Assert.Contains(LResult.ContentJson, '"originalValue":"Save"');
  Assert.Contains(LResult.ContentJson, '"proposedValue":"Save changes"');
  Assert.AreEqual('Save', FFacade.Caption);
end;

function TTestRadIADesignerProperties.ReadPreviewId(
  const AJson: string
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  Assert.IsNotNull(LJson);
  try
    Result := LJson.GetValue<string>('previewId', '');
  finally
    LJson.Free;
  end;
  Assert.IsNotEmpty(Result);
end;

procedure TTestRadIADesignerProperties.RegistersRiskLevels;
begin
  Assert.AreEqual(3, FRegistry.Count);
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('PrepareComponentProperty').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    FRegistry.Resolve('ApplyComponentProperty').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    FRegistry.Resolve('RevertComponentProperty').Descriptor.Risk
  );
end;

procedure TTestRadIADesignerProperties.RejectsUnsupportedProperty;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'PrepareComponentProperty',
    '{"componentName":"SaveButton","propertyName":"OnClick",' +
      '"value":"SaveButtonClick"}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
end;

procedure TTestRadIADesignerProperties.ReportsDesignerRejection;
var
  LPreview: TRadIAToolResult;
  LResult: TRadIAToolResult;
begin
  LPreview := PreparePreview;
  FFacade.RejectProperty := True;

  LResult := ExecuteTool(
    'ApplyComponentProperty',
    '{"previewId":"' +
      ReadPreviewId(LPreview.ContentJson) + '"}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('apply_failed', LResult.ErrorCode);
end;

procedure TTestRadIADesignerProperties.Setup;
begin
  FRegistry := TRadIAToolRegistry.Create;
  FFacade := TRadIAFakeDesignerMutationFacade.Create;
  FService := TRadIAComponentPropertyService.Create(FFacade);
  RegisterRadIADesignerPropertyTools(FRegistry, FService);
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADesignerProperties);

end.
