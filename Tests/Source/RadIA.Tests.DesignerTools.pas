unit RadIA.Tests.DesignerTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Designer,
  RadIA.Core.Tools;

type
  TRadIAFakeFormDesignerFacade = class(
    TInterfacedObject,
    IRadIAFormDesignerFacade
  )
  public
    function GetActiveForm: TRadIAFormSnapshot;
    function ListFormComponents(
      const AMaxCount: Integer
    ): TArray<TRadIAFormComponentSnapshot>;
  end;

  [TestFixture]
  TTestRadIADesignerTools = class
  private
    FExecutor: IRadIAToolExecutor;
    FRegistry: IRadIAToolRegistry;
    function ExecuteTool(
      const AName: string;
      const AArgumentsJson: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure RegistersReadOnlyTools;
    [Test]
    procedure GetsActiveFormSnapshot;
    [Test]
    procedure ListsLiveComponents;
    [Test]
    procedure RejectsInvalidComponentLimit;
  end;

implementation

uses
  RadIA.Core.DesignerTools,
  RadIA.Core.ToolRegistry;

{ TRadIAFakeFormDesignerFacade }

function TRadIAFakeFormDesignerFacade.GetActiveForm:
  TRadIAFormSnapshot;
begin
  Result := TRadIAFormSnapshot.Create(
    True,
    'MainForm',
    'TMainForm',
    'C:\Sample\MainForm.pas',
    'C:\Sample\MainForm.dfm',
    2,
    1
  );
end;

function TRadIAFakeFormDesignerFacade.ListFormComponents(
  const AMaxCount: Integer
): TArray<TRadIAFormComponentSnapshot>;
var
  LButton: TRadIAFormComponentSnapshot;
  LTimer: TRadIAFormComponentSnapshot;
begin
  if AMaxCount <= 0 then
    Exit(nil);

  LButton := TRadIAFormComponentSnapshot.Create(
    'SaveButton',
    'TButton',
    'MainForm',
    True,
    True,
    24,
    40
  );
  LButton.SetSize(90, 25);
  LTimer := TRadIAFormComponentSnapshot.Create(
    'RefreshTimer',
    'TTimer',
    'MainForm',
    False,
    False,
    0,
    0
  );
  Result := [LButton, LTimer];
end;

{ TTestRadIADesignerTools }

function TTestRadIADesignerTools.ExecuteTool(
  const AName: string;
  const AArgumentsJson: string
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(
      AName,
      AArgumentsJson,
      'designer-test'
    )
  );
end;

procedure TTestRadIADesignerTools.GetsActiveFormSnapshot;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool('GetActiveForm', '{}');

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"available":true');
  Assert.Contains(LResult.ContentJson, '"name":"MainForm"');
  Assert.Contains(LResult.ContentJson, '"componentCount":2');
end;

procedure TTestRadIADesignerTools.ListsLiveComponents;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'ListFormComponents',
    '{"maxCount":20}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"name":"SaveButton"');
  Assert.Contains(LResult.ContentJson, '"selected":true');
  Assert.Contains(LResult.ContentJson, '"width":90');
  Assert.Contains(LResult.ContentJson, '"name":"RefreshTimer"');
end;

procedure TTestRadIADesignerTools.RegistersReadOnlyTools;
var
  LDescriptor: TRadIAToolDescriptor;
begin
  Assert.AreEqual(2, FRegistry.Count);
  LDescriptor := FRegistry.Resolve('GetActiveForm').Descriptor;
  Assert.AreEqual(trReadOnly, LDescriptor.Risk);
  LDescriptor := FRegistry.Resolve(
    'ListFormComponents'
  ).Descriptor;
  Assert.AreEqual(trReadOnly, LDescriptor.Risk);
end;

procedure TTestRadIADesignerTools.RejectsInvalidComponentLimit;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'ListFormComponents',
    '{"maxCount":1001}'
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('tool_execution_failed', LResult.ErrorCode);
end;

procedure TTestRadIADesignerTools.Setup;
var
  LDesigner: IRadIAFormDesignerFacade;
begin
  FRegistry := TRadIAToolRegistry.Create;
  LDesigner := TRadIAFakeFormDesignerFacade.Create;
  RegisterRadIADesignerTools(FRegistry, LDesigner);
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADesignerTools);

end.
