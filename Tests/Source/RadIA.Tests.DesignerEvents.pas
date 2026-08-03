unit RadIA.Tests.DesignerEvents;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.DesignerEvents,
  RadIA.Core.Tools;

type
  TRadIAFakeDesignerEventFacade = class(
    TInterfacedObject,
    IRadIAFormDesignerEventFacade
  )
  private
    FHandlerName: string;
    FSource: string;
  public
    constructor Create;
    function PrepareEvent(
      const AComponentName: string;
      const AEventName: string;
      const AHandlerName: string;
      out AState: TRadIAFormEventState
    ): Boolean;
    function ApplyEvent(
      const AExpected: TRadIAFormEventState;
      out AApplied: TRadIAFormEventState
    ): Boolean;
    function RevertEvent(
      const AExpected: TRadIAFormEventState
    ): Boolean;
    property HandlerName: string read FHandlerName;
    property Source: string read FSource write FSource;
  end;

  [TestFixture]
  TTestRadIADesignerEvents = class
  private
    FFacade: TRadIAFakeDesignerEventFacade;
    FRegistry: IRadIAToolRegistry;
    FService: IRadIAFormEventService;
    function Prepare: TRadIAFormEventResult;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure PreparesWithoutMutation;
    [Test]
    procedure AppliesAndRevertsAtomically;
    [Test]
    procedure RejectsInvalidIdentifier;
    [Test]
    procedure RejectsApplyWhenSourceChanged;
    [Test]
    procedure RejectsDuplicateApply;
    [Test]
    procedure RejectsRevertBeforeApply;
    [Test]
    procedure RejectsRevertWhenSourceChanged;
    [Test]
    procedure RegistersExpectedRiskLevels;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.DesignerEventTools,
  RadIA.Core.ToolRegistry;

constructor TRadIAFakeDesignerEventFacade.Create;
begin
  inherited;
  FSource :=
    'unit Main;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';
end;

function TRadIAFakeDesignerEventFacade.ApplyEvent(
  const AExpected: TRadIAFormEventState;
  out AApplied: TRadIAFormEventState
): Boolean;
begin
  Result := (FHandlerName = AExpected.OriginalHandlerName) and
    (FSource = AExpected.BeforeSource);
  if not Result then
    Exit;
  FHandlerName := AExpected.Identity.HandlerName;
  FSource := AExpected.BeforeSource + sLineBreak +
    'procedure TMainForm.SaveButtonClick(Sender: TObject);' +
    sLineBreak + 'begin' + sLineBreak + 'end;';
  AApplied := AExpected.WithAfterSource(FSource);
end;

function TRadIAFakeDesignerEventFacade.PrepareEvent(
  const AComponentName: string;
  const AEventName: string;
  const AHandlerName: string;
  out AState: TRadIAFormEventState
): Boolean;
var
  LIdentity: TRadIAFormEventIdentity;
begin
  Result := (FHandlerName = '') and
    SameText(AComponentName, 'SaveButton') and
    SameText(AEventName, 'OnClick');
  if not Result then
    Exit;
  LIdentity := TRadIAFormEventIdentity.Create(
    'MainForm.dfm',
    'MainForm.pas',
    AComponentName,
    AEventName,
    'TNotifyEvent',
    AHandlerName
  );
  AState := TRadIAFormEventState.Create(
    LIdentity,
    FHandlerName,
    FSource,
    ''
  );
end;

function TRadIAFakeDesignerEventFacade.RevertEvent(
  const AExpected: TRadIAFormEventState
): Boolean;
begin
  Result := SameText(
    FHandlerName,
    AExpected.Identity.HandlerName
  ) and (FSource = AExpected.AfterSource);
  if not Result then
    Exit;
  FHandlerName := AExpected.OriginalHandlerName;
  FSource := AExpected.BeforeSource;
end;

function TTestRadIADesignerEvents.Prepare:
  TRadIAFormEventResult;
begin
  Result := FService.Prepare(
    'SaveButton',
    'OnClick',
    'SaveButtonClick'
  );
end;

procedure TTestRadIADesignerEvents.AppliesAndRevertsAtomically;
var
  LPreview: TRadIAFormEventResult;
begin
  LPreview := Prepare;
  Assert.IsTrue(FService.Apply(LPreview.Preview.Id).Success);
  Assert.AreEqual('SaveButtonClick', FFacade.HandlerName);
  Assert.IsTrue(FFacade.Source.Contains('procedure TMainForm'));
  Assert.IsTrue(FService.Revert(LPreview.Preview.Id).Success);
  Assert.AreEqual('', FFacade.HandlerName);
  Assert.IsFalse(FFacade.Source.Contains('procedure TMainForm'));
end;

procedure TTestRadIADesignerEvents.PreparesWithoutMutation;
begin
  Assert.IsTrue(Prepare.Success);
  Assert.AreEqual('', FFacade.HandlerName);
  Assert.IsFalse(FFacade.Source.Contains('procedure TMainForm'));
end;

procedure TTestRadIADesignerEvents.RegistersExpectedRiskLevels;
var
  LDescriptor: TRadIAToolDescriptor;
begin
  LDescriptor := FRegistry.Resolve(
    'PrepareFormEventHandler'
  ).Descriptor;
  Assert.AreEqual(trReadOnly, LDescriptor.Risk);
  LDescriptor := FRegistry.Resolve(
    'ApplyFormEventHandler'
  ).Descriptor;
  Assert.AreEqual(trStructuralWrite, LDescriptor.Risk);
  LDescriptor := FRegistry.Resolve(
    'RevertFormEventHandler'
  ).Descriptor;
  Assert.AreEqual(trStructuralWrite, LDescriptor.Risk);
end;

procedure TTestRadIADesignerEvents.RejectsApplyWhenSourceChanged;
var
  LPreview: TRadIAFormEventResult;
begin
  LPreview := Prepare;
  FFacade.Source := FFacade.Source + sLineBreak + '// User edit';
  Assert.IsFalse(FService.Apply(LPreview.Preview.Id).Success);
  Assert.AreEqual('', FFacade.HandlerName);
end;

procedure TTestRadIADesignerEvents.RejectsDuplicateApply;
var
  LPreview: TRadIAFormEventResult;
begin
  LPreview := Prepare;
  Assert.IsTrue(FService.Apply(LPreview.Preview.Id).Success);
  Assert.IsFalse(FService.Apply(LPreview.Preview.Id).Success);
end;

procedure TTestRadIADesignerEvents.RejectsInvalidIdentifier;
var
  LResult: TRadIAFormEventResult;
begin
  LResult := FService.Prepare(
    'SaveButton',
    'OnClick',
    'Save Button Click'
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_event', LResult.ErrorCode);
end;

procedure TTestRadIADesignerEvents.RejectsRevertBeforeApply;
var
  LPreview: TRadIAFormEventResult;
begin
  LPreview := Prepare;
  Assert.IsFalse(FService.Revert(LPreview.Preview.Id).Success);
  Assert.AreEqual('', FFacade.HandlerName);
end;

procedure TTestRadIADesignerEvents.RejectsRevertWhenSourceChanged;
var
  LPreview: TRadIAFormEventResult;
begin
  LPreview := Prepare;
  Assert.IsTrue(FService.Apply(LPreview.Preview.Id).Success);
  FFacade.Source := FFacade.Source + sLineBreak + '// User edit';
  Assert.IsFalse(FService.Revert(LPreview.Preview.Id).Success);
  Assert.AreEqual('SaveButtonClick', FFacade.HandlerName);
end;

procedure TTestRadIADesignerEvents.Setup;
begin
  FFacade := TRadIAFakeDesignerEventFacade.Create;
  FService := TRadIAFormEventService.Create(FFacade);
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIADesignerEventTools(FRegistry, FService);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADesignerEvents);

end.
