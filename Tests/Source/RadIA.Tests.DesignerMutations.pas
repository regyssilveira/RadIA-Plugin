unit RadIA.Tests.DesignerMutations;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Designer,
  RadIA.Core.DesignerMutations,
  RadIA.Core.Tools;

type
  TRadIAFakeDesignerMutationFacade = class(
    TInterfacedObject,
    IRadIAFormDesignerMutationFacade
  )
  private
    FBounds: TRadIAComponentBounds;
    FCaption: string;
    FRejectApply: Boolean;
    FRejectProperty: Boolean;
  public
    constructor Create;
    function GetComponentBounds(
      const AComponentName: string;
      out AFormFileName: string;
      out ABounds: TRadIAComponentBounds
    ): Boolean;
    function ApplyComponentBounds(
      const AFormFileName: string;
      const AComponentName: string;
      const AExpectedBounds: TRadIAComponentBounds;
      const ANewBounds: TRadIAComponentBounds;
      out AActualBounds: TRadIAComponentBounds
    ): Boolean;
    function GetComponentProperty(
      const AComponentName: string;
      const APropertyName: string;
      out AFormFileName: string;
      out AValue: TRadIAComponentPropertyValue
    ): Boolean;
    function ApplyComponentProperty(
      const AFormFileName: string;
      const AComponentName: string;
      const AExpectedValue: TRadIAComponentPropertyValue;
      const ANewValue: TRadIAComponentPropertyValue;
      out AActualValue: TRadIAComponentPropertyValue
    ): Boolean;
    property Bounds: TRadIAComponentBounds read FBounds write FBounds;
    property Caption: string read FCaption write FCaption;
    property RejectApply: Boolean read FRejectApply write FRejectApply;
    property RejectProperty: Boolean read FRejectProperty write FRejectProperty;
  end;

  [TestFixture]
  TTestRadIADesignerMutations = class
  private
    FExecutor: IRadIAToolExecutor;
    FFacade: TRadIAFakeDesignerMutationFacade;
    FRegistry: IRadIAToolRegistry;
    FService: IRadIAComponentLayoutService;
    function ExecuteTool(
      const AName: string;
      const AArgumentsJson: string
    ): TRadIAToolResult;
    function PreparePreview: TRadIAToolResult;
    function ReadPreviewId(const AJson: string): string;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure RegistersRiskLevels;
    [Test]
    procedure PreparesWithoutMutation;
    [Test]
    procedure AppliesAndRevertsLayout;
    [Test]
    procedure DetectsChangedComponentBeforeApply;
    [Test]
    procedure RejectsInvalidBounds;
    [Test]
    procedure ReportsDesignerRejection;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.DesignerMutationTools,
  RadIA.Core.ToolRegistry;

{ TRadIAFakeDesignerMutationFacade }

function TRadIAFakeDesignerMutationFacade.ApplyComponentBounds(
  const AFormFileName: string;
  const AComponentName: string;
  const AExpectedBounds: TRadIAComponentBounds;
  const ANewBounds: TRadIAComponentBounds;
  out AActualBounds: TRadIAComponentBounds
): Boolean;
begin
  AActualBounds := FBounds;
  Result := SameText(AFormFileName, 'C:\Sample\MainForm.dfm') and
    SameText(AComponentName, 'SaveButton') and
    FBounds.Equals(AExpectedBounds) and
    not FRejectApply;
  if Result then
  begin
    FBounds := ANewBounds;
    AActualBounds := FBounds;
  end;
end;

constructor TRadIAFakeDesignerMutationFacade.Create;
begin
  inherited;
  FBounds := TRadIAComponentBounds.Create(10, 20, 80, 25);
  FCaption := 'Save';
end;

function TRadIAFakeDesignerMutationFacade.ApplyComponentProperty(
  const AFormFileName: string;
  const AComponentName: string;
  const AExpectedValue: TRadIAComponentPropertyValue;
  const ANewValue: TRadIAComponentPropertyValue;
  out AActualValue: TRadIAComponentPropertyValue
): Boolean;
begin
  AActualValue := TRadIAComponentPropertyValue.Create(
    'Caption',
    'string',
    FCaption
  );
  Result := SameText(AFormFileName, 'C:\Sample\MainForm.dfm') and
    SameText(AComponentName, 'SaveButton') and
    AActualValue.Equals(AExpectedValue) and
    not FRejectProperty;
  if Result then
  begin
    FCaption := ANewValue.Value;
    AActualValue := TRadIAComponentPropertyValue.Create(
      'Caption',
      'string',
      FCaption
    );
  end;
end;

function TRadIAFakeDesignerMutationFacade.GetComponentBounds(
  const AComponentName: string;
  out AFormFileName: string;
  out ABounds: TRadIAComponentBounds
): Boolean;
begin
  Result := SameText(AComponentName, 'SaveButton');
  if Result then
  begin
    AFormFileName := 'C:\Sample\MainForm.dfm';
    ABounds := FBounds;
  end
  else
  begin
    AFormFileName := '';
    ABounds := Default(TRadIAComponentBounds);
  end;
end;

function TRadIAFakeDesignerMutationFacade.GetComponentProperty(
  const AComponentName: string;
  const APropertyName: string;
  out AFormFileName: string;
  out AValue: TRadIAComponentPropertyValue
): Boolean;
begin
  Result := SameText(AComponentName, 'SaveButton') and
    SameText(APropertyName, 'Caption');
  if Result then
  begin
    AFormFileName := 'C:\Sample\MainForm.dfm';
    AValue := TRadIAComponentPropertyValue.Create(
      'Caption',
      'string',
      FCaption
    );
  end
  else
  begin
    AFormFileName := '';
    AValue := Default(TRadIAComponentPropertyValue);
  end;
end;

{ TTestRadIADesignerMutations }

procedure TTestRadIADesignerMutations.AppliesAndRevertsLayout;
var
  LApply: TRadIAToolResult;
  LPreview: TRadIAToolResult;
  LPreviewId: string;
  LRevert: TRadIAToolResult;
begin
  LPreview := PreparePreview;
  LPreviewId := ReadPreviewId(LPreview.ContentJson);

  LApply := ExecuteTool(
    'ApplyComponentLayout',
    '{"previewId":"' + LPreviewId + '"}'
  );
  Assert.IsTrue(LApply.Success);
  Assert.IsTrue(
    FFacade.Bounds.Equals(
      TRadIAComponentBounds.Create(30, 40, 100, 35)
    )
  );

  LRevert := ExecuteTool(
    'RevertComponentLayout',
    '{"previewId":"' + LPreviewId + '"}'
  );
  Assert.IsTrue(LRevert.Success);
  Assert.IsTrue(
    FFacade.Bounds.Equals(
      TRadIAComponentBounds.Create(10, 20, 80, 25)
    )
  );
end;

procedure TTestRadIADesignerMutations.DetectsChangedComponentBeforeApply;
var
  LPreview: TRadIAToolResult;
  LResult: TRadIAToolResult;
begin
  LPreview := PreparePreview;
  FFacade.Bounds := TRadIAComponentBounds.Create(11, 20, 80, 25);

  LResult := ExecuteTool(
    'ApplyComponentLayout',
    '{"previewId":"' +
      ReadPreviewId(LPreview.ContentJson) + '"}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
end;

function TTestRadIADesignerMutations.ExecuteTool(
  const AName: string;
  const AArgumentsJson: string
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(
      AName,
      AArgumentsJson,
      'designer-mutation-test'
    )
  );
end;

function TTestRadIADesignerMutations.PreparePreview:
  TRadIAToolResult;
begin
  Result := ExecuteTool(
    'PrepareComponentLayout',
    '{"componentName":"SaveButton","left":30,"top":40,' +
      '"width":100,"height":35}'
  );
  Assert.IsTrue(Result.Success);
end;

procedure TTestRadIADesignerMutations.PreparesWithoutMutation;
var
  LResult: TRadIAToolResult;
begin
  LResult := PreparePreview;

  Assert.Contains(LResult.ContentJson, '"componentName":"SaveButton"');
  Assert.Contains(LResult.ContentJson, '"left":10');
  Assert.Contains(LResult.ContentJson, '"left":30');
  Assert.IsTrue(
    FFacade.Bounds.Equals(
      TRadIAComponentBounds.Create(10, 20, 80, 25)
    )
  );
end;

function TTestRadIADesignerMutations.ReadPreviewId(
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

procedure TTestRadIADesignerMutations.RegistersRiskLevels;
begin
  Assert.AreEqual(3, FRegistry.Count);
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('PrepareComponentLayout').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    FRegistry.Resolve('ApplyComponentLayout').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    FRegistry.Resolve('RevertComponentLayout').Descriptor.Risk
  );
end;

procedure TTestRadIADesignerMutations.RejectsInvalidBounds;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'PrepareComponentLayout',
    '{"componentName":"SaveButton","left":30,"top":40,' +
      '"width":0,"height":35}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_layout', LResult.ErrorCode);
end;

procedure TTestRadIADesignerMutations.ReportsDesignerRejection;
var
  LPreview: TRadIAToolResult;
  LResult: TRadIAToolResult;
begin
  LPreview := PreparePreview;
  FFacade.RejectApply := True;

  LResult := ExecuteTool(
    'ApplyComponentLayout',
    '{"previewId":"' +
      ReadPreviewId(LPreview.ContentJson) + '"}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('apply_failed', LResult.ErrorCode);
end;

procedure TTestRadIADesignerMutations.Setup;
begin
  FRegistry := TRadIAToolRegistry.Create;
  FFacade := TRadIAFakeDesignerMutationFacade.Create;
  FService := TRadIAComponentLayoutService.Create(FFacade);
  RegisterRadIADesignerMutationTools(FRegistry, FService);
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADesignerMutations);

end.
