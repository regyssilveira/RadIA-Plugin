unit RadIA.Tests.DesignerVisualDiff;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Designer,
  RadIA.Core.DesignerVisualDiff;

type
  TRadIADesignerVisualDiffFacadeStub = class(
    TInterfacedObject,
    IRadIAFormDesignerFacade
  )
  private
    FComponents: TArray<TRadIAFormComponentSnapshot>;
  public
    function GetActiveForm: TRadIAFormSnapshot;
    function ListFormComponents(
      const AMaxCount: Integer
    ): TArray<TRadIAFormComponentSnapshot>;
    procedure SetComponents(
      const AComponents: TArray<TRadIAFormComponentSnapshot>
    );
  end;

  [TestFixture]
  TTestRadIADesignerVisualDiff = class
  private
    FFacade: TRadIADesignerVisualDiffFacadeStub;
    FService: IRadIADesignerVisualDiffService;
    function Component(
      const AName: string;
      const AClassName: string;
      const AParentName: string;
      const ASelected: Boolean;
      const ABounds: TRadIAComponentBounds;
      const ACaption: string
    ): TRadIAFormComponentSnapshot;
    function ContainsKind(
      const AChanges: TArray<TRadIADesignerVisualChange>;
      const AKind: TRadIADesignerVisualChangeKind;
      const AName: string
    ): Boolean;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure DetectsStructuralAndLayoutChanges;
    [Test]
    procedure RejectsUnknownSnapshot;
    [Test]
    procedure ClearRemovesSnapshots;
    [Test]
    procedure DecisionsAreFinalAndDoNotMutateDesigner;
  end;

implementation

uses
  System.SysUtils;

{ TRadIADesignerVisualDiffFacadeStub }

function TRadIADesignerVisualDiffFacadeStub.GetActiveForm:
  TRadIAFormSnapshot;
begin
  Result := TRadIAFormSnapshot.Create(
    True,
    'MainForm',
    'TMainForm',
    'Main.pas',
    'Main.dfm',
    Length(FComponents),
    0
  );
end;

function TRadIADesignerVisualDiffFacadeStub.ListFormComponents(
  const AMaxCount: Integer
): TArray<TRadIAFormComponentSnapshot>;
begin
  Result := Copy(FComponents, 0, AMaxCount);
end;

procedure TRadIADesignerVisualDiffFacadeStub.SetComponents(
  const AComponents: TArray<TRadIAFormComponentSnapshot>
);
begin
  FComponents := Copy(AComponents);
end;

{ TTestRadIADesignerVisualDiff }

procedure TTestRadIADesignerVisualDiff.ClearRemovesSnapshots;
var
  LRaised: Boolean;
  LSnapshot: TRadIADesignerVisualSnapshot;
begin
  LSnapshot := FService.Capture;
  FService.Clear;
  LRaised := False;
  try
    FService.Compare(LSnapshot.Id, LSnapshot.Id);
  except
    on E: EArgumentException do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised);
end;

function TTestRadIADesignerVisualDiff.Component(
  const AName: string;
  const AClassName: string;
  const AParentName: string;
  const ASelected: Boolean;
  const ABounds: TRadIAComponentBounds;
  const ACaption: string
): TRadIAFormComponentSnapshot;
begin
  Result := TRadIAFormComponentSnapshot.Create(
    AName,
    AClassName,
    AParentName,
    True,
    ASelected,
    ABounds.Left,
    ABounds.Top
  );
  Result.SetSize(ABounds.Width, ABounds.Height);
  if ACaption <> '' then
    Result.SetProperties([
      TRadIAComponentPropertyValue.Create(
        'Caption',
        'string',
        ACaption
      )
    ]);
end;

function TTestRadIADesignerVisualDiff.ContainsKind(
  const AChanges: TArray<TRadIADesignerVisualChange>;
  const AKind: TRadIADesignerVisualChangeKind;
  const AName: string
): Boolean;
var
  LChange: TRadIADesignerVisualChange;
begin
  for LChange in AChanges do
    if (LChange.Kind = AKind) and SameText(LChange.ComponentName, AName) then
      Exit(True);
  Result := False;
end;

procedure TTestRadIADesignerVisualDiff.DetectsStructuralAndLayoutChanges;
var
  LAfter: TRadIADesignerVisualSnapshot;
  LBefore: TRadIADesignerVisualSnapshot;
  LChanges: TArray<TRadIADesignerVisualChange>;
begin
  FFacade.SetComponents([
    Component(
      'SaveButton',
      'TButton',
      'MainForm',
      False,
      TRadIAComponentBounds.Create(10, 20, 80, 25),
      'Save'
    ),
    Component(
      'OldLabel',
      'TLabel',
      'MainForm',
      False,
      TRadIAComponentBounds.Create(5, 5, 50, 25),
      'Old'
    )
  ]);
  LBefore := FService.Capture;
  FFacade.SetComponents([
    Component(
      'SaveButton',
      'TButton',
      'Panel1',
      True,
      TRadIAComponentBounds.Create(30, 20, 100, 25),
      'Save changes'
    ),
    Component(
      'NewEdit',
      'TEdit',
      'MainForm',
      False,
      TRadIAComponentBounds.Create(5, 50, 120, 25),
      ''
    )
  ]);
  LAfter := FService.Capture;

  LChanges := FService.Compare(LBefore.Id, LAfter.Id);

  Assert.IsTrue(ContainsKind(LChanges, dvkMoved, 'SaveButton'));
  Assert.IsTrue(ContainsKind(LChanges, dvkResized, 'SaveButton'));
  Assert.IsTrue(ContainsKind(LChanges, dvkReparented, 'SaveButton'));
  Assert.IsTrue(ContainsKind(LChanges, dvkSelectionChanged, 'SaveButton'));
  Assert.IsTrue(ContainsKind(LChanges, dvkPropertyChanged, 'SaveButton'));
  Assert.IsTrue(ContainsKind(LChanges, dvkRemoved, 'OldLabel'));
  Assert.IsTrue(ContainsKind(LChanges, dvkAdded, 'NewEdit'));
end;

procedure TTestRadIADesignerVisualDiff.DecisionsAreFinalAndDoNotMutateDesigner;
var
  LAfter: TRadIADesignerVisualSnapshot;
  LBefore: TRadIADesignerVisualSnapshot;
  LComparison: TRadIADesignerVisualComparison;
  LCount: Integer;
  LRaised: Boolean;
begin
  LBefore := FService.Capture;
  LAfter := FService.Capture;
  LCount := Length(FFacade.ListFormComponents(1000));
  LComparison := FService.PrepareComparison(LBefore.Id, LAfter.Id);

  LComparison := FService.Decide(LComparison.Id, False);

  Assert.AreEqual(dvsRejected, LComparison.State);
  Assert.AreEqual<Integer>(
    LCount,
    Length(FFacade.ListFormComponents(1000))
  );
  LRaised := False;
  try
    FService.Decide(LComparison.Id, True);
  except
    on E: EInvalidOpException do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised);
end;

procedure TTestRadIADesignerVisualDiff.RejectsUnknownSnapshot;
var
  LRaised: Boolean;
  LSnapshot: TRadIADesignerVisualSnapshot;
begin
  LSnapshot := FService.Capture;
  LRaised := False;
  try
    FService.Compare('missing', LSnapshot.Id);
  except
    on E: EArgumentException do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised);
end;

procedure TTestRadIADesignerVisualDiff.Setup;
begin
  FFacade := TRadIADesignerVisualDiffFacadeStub.Create;
  FService := TRadIADesignerVisualDiffService.Create(FFacade);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADesignerVisualDiff);

end.
