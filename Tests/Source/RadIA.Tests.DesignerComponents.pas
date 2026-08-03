unit RadIA.Tests.DesignerComponents;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Designer,
  RadIA.Core.DesignerComponents;

type
  TRadIAFakeDesignerComponentFacade = class(
    TInterfacedObject,
    IRadIAFormDesignerComponentFacade
  )
  private
    FComponent: TRadIAFormComponentSnapshot;
    FComponentExists: Boolean;
    FRoot: TRadIAFormComponentSnapshot;
  public
    constructor Create;
    function GetComponentSnapshot(
      const AComponentName: string;
      out AFormFileName: string;
      out ASnapshot: TRadIAFormComponentSnapshot
    ): Boolean;
    function CreateComponent(
      const AFormFileName: string;
      const AParentName: string;
      const AClassName: string;
      const AComponentName: string;
      const ABounds: TRadIAComponentBounds;
      out ACreated: TRadIAFormComponentSnapshot
    ): Boolean;
    function RemoveComponent(
      const AFormFileName: string;
      const AExpected: TRadIAFormComponentSnapshot;
      out AActual: TRadIAFormComponentSnapshot
    ): Boolean;
    property ComponentExists: Boolean read FComponentExists;
  end;

  [TestFixture]
  TTestRadIADesignerComponents = class
  private
    FFacade: TRadIAFakeDesignerComponentFacade;
    FService: IRadIAComponentChangeService;
    function PrepareAdd: TRadIAComponentChangeResult;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure PreparesWithoutCreatingComponent;
    [Test]
    procedure AppliesAndRevertsCreation;
    [Test]
    procedure AppliesAndRevertsRemoval;
    [Test]
    procedure RejectsUnsupportedClass;
    [Test]
    procedure DetectsDuplicateName;
  end;

implementation

uses
  System.SysUtils;

constructor TRadIAFakeDesignerComponentFacade.Create;
begin
  inherited;
  FRoot := TRadIAFormComponentSnapshot.Create(
    'MainForm',
    'TForm',
    '',
    True,
    False,
    0,
    0
  );
  FRoot.SetSize(800, 600);
end;

function TRadIAFakeDesignerComponentFacade.CreateComponent(
  const AFormFileName: string;
  const AParentName: string;
  const AClassName: string;
  const AComponentName: string;
  const ABounds: TRadIAComponentBounds;
  out ACreated: TRadIAFormComponentSnapshot
): Boolean;
begin
  Result := SameText(AFormFileName, 'MainForm.dfm') and
    SameText(AParentName, 'MainForm') and not FComponentExists;
  if not Result then
    Exit;
  FComponent := TRadIAFormComponentSnapshot.Create(
    AComponentName,
    AClassName,
    AParentName,
    True,
    False,
    ABounds.Left,
    ABounds.Top
  );
  FComponent.SetSize(ABounds.Width, ABounds.Height);
  FComponentExists := True;
  ACreated := FComponent;
end;

function TRadIAFakeDesignerComponentFacade.GetComponentSnapshot(
  const AComponentName: string;
  out AFormFileName: string;
  out ASnapshot: TRadIAFormComponentSnapshot
): Boolean;
begin
  AFormFileName := 'MainForm.dfm';
  if SameText(AComponentName, FRoot.Name) then
  begin
    ASnapshot := FRoot;
    Exit(True);
  end;
  Result := FComponentExists and
    SameText(AComponentName, FComponent.Name);
  if Result then
    ASnapshot := FComponent
  else
    ASnapshot := Default(TRadIAFormComponentSnapshot);
end;

function TRadIAFakeDesignerComponentFacade.RemoveComponent(
  const AFormFileName: string;
  const AExpected: TRadIAFormComponentSnapshot;
  out AActual: TRadIAFormComponentSnapshot
): Boolean;
begin
  AActual := FComponent;
  Result := SameText(AFormFileName, 'MainForm.dfm') and
    FComponentExists and SameText(AExpected.Name, FComponent.Name) and
    SameText(AExpected.ClassName, FComponent.ClassName);
  if Result then
    FComponentExists := False;
end;

function TTestRadIADesignerComponents.PrepareAdd:
  TRadIAComponentChangeResult;
begin
  Result := FService.PrepareAdd(
    'MainForm',
    'TButton',
    'SaveButton',
    TRadIAComponentBounds.Create(16, 24, 90, 25)
  );
end;

procedure TTestRadIADesignerComponents.AppliesAndRevertsCreation;
var
  LResult: TRadIAComponentChangeResult;
begin
  LResult := PrepareAdd;
  Assert.IsTrue(FService.Apply(LResult.Preview.Id).Success);
  Assert.IsTrue(FFacade.ComponentExists);
  Assert.IsTrue(FService.Revert(LResult.Preview.Id).Success);
  Assert.IsFalse(FFacade.ComponentExists);
end;

procedure TTestRadIADesignerComponents.AppliesAndRevertsRemoval;
var
  LAdd: TRadIAComponentChangeResult;
  LRemove: TRadIAComponentChangeResult;
begin
  LAdd := PrepareAdd;
  Assert.IsTrue(FService.Apply(LAdd.Preview.Id).Success);
  LRemove := FService.PrepareRemove('SaveButton');
  Assert.IsTrue(LRemove.Success);
  Assert.IsTrue(FService.Apply(LRemove.Preview.Id).Success);
  Assert.IsFalse(FFacade.ComponentExists);
  Assert.IsTrue(FService.Revert(LRemove.Preview.Id).Success);
  Assert.IsTrue(FFacade.ComponentExists);
end;

procedure TTestRadIADesignerComponents.DetectsDuplicateName;
var
  LResult: TRadIAComponentChangeResult;
begin
  LResult := PrepareAdd;
  Assert.IsTrue(FService.Apply(LResult.Preview.Id).Success);
  LResult := PrepareAdd;
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
end;

procedure TTestRadIADesignerComponents.PreparesWithoutCreatingComponent;
begin
  Assert.IsTrue(PrepareAdd.Success);
  Assert.IsFalse(FFacade.ComponentExists);
end;

procedure TTestRadIADesignerComponents.RejectsUnsupportedClass;
var
  LResult: TRadIAComponentChangeResult;
begin
  LResult := FService.PrepareAdd(
    'MainForm',
    'TADOConnection',
    'Connection',
    TRadIAComponentBounds.Create(0, 0, 24, 24)
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('unsupported_component_class', LResult.ErrorCode);
end;

procedure TTestRadIADesignerComponents.Setup;
begin
  FFacade := TRadIAFakeDesignerComponentFacade.Create;
  FService := TRadIAComponentChangeService.Create(FFacade);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADesignerComponents);

end.
