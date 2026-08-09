unit RadIA.Tests.EditorHook;

interface

uses
  DUnitX.TestFramework, Vcl.Menus, RadIA.OTA.EditorHook;

type
  [TestFixture]
  TTestEditorHook = class
  private
    FHook: TRadIAEditorHook;
    FPopupMenu: TPopupMenu;
    FOnPopupCalled: Boolean;
    FOnPopup2Called: Boolean;
    procedure DummyOnPopup(Sender: TObject);
    procedure DummyOnPopup2(Sender: TObject);
    procedure DummyOnPopupClearsMenu(Sender: TObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestInitialHooking;
    [Test]
    procedure TestReHookingWhenOverridden;
    [Test]
    procedure TestRadIAMenuSurvivesOriginalPopupRebuild;
    [Test]
    procedure TestRadIAMenuExposesInlineReviewDecisions;
    [Test]
    procedure TestUnhooking;
    [Test]
    procedure TestCleanCreateExampleResponseWithPascalFence;
    [Test]
    procedure TestCleanCreateExampleResponseWithoutFence;
    [Test]
    procedure TestCleanCreateExampleResponseIgnoresTextOutsideFence;
  end;

implementation

uses
  System.Classes,
  System.SysUtils,
  RadIA.OTA.Helper;

{ TTestEditorHook }

procedure TTestEditorHook.Setup;
begin
  FHook := TRadIAEditorHook.Create(nil);
  FHook.Install;
  FPopupMenu := TPopupMenu.Create(nil);
  FOnPopupCalled := False;
  FOnPopup2Called := False;
end;

procedure TTestEditorHook.TearDown;
begin
  FPopupMenu.Free;
  FHook.Uninstall;
  FHook.Free;
end;

procedure TTestEditorHook.DummyOnPopup(Sender: TObject);
begin
  FOnPopupCalled := True;
end;

procedure TTestEditorHook.DummyOnPopup2(Sender: TObject);
begin
  FOnPopup2Called := True;
end;

procedure TTestEditorHook.DummyOnPopupClearsMenu(Sender: TObject);
var
  LItem: TMenuItem;
begin
  FOnPopupCalled := True;
  FPopupMenu.Items.Clear;
  LItem := TMenuItem.Create(FPopupMenu);
  LItem.Caption := 'Cut';
  FPopupMenu.Items.Add(LItem);
end;

procedure TTestEditorHook.TestInitialHooking;
var
  LEventDummy: TNotifyEvent;
begin
  LEventDummy := DummyOnPopup;
  FPopupMenu.OnPopup := LEventDummy;

  FHook.HookMenuDirectly(FPopupMenu);

  // The OnPopup handler should have been changed to the hook handler
  Assert.AreNotEqual(TMethod(FPopupMenu.OnPopup).Code, TMethod(LEventDummy).Code);
end;

procedure TTestEditorHook.TestReHookingWhenOverridden;
var
  LEventDummy: TNotifyEvent;
  LNewDummy: TNotifyEvent;
begin
  LEventDummy := DummyOnPopup;
  FPopupMenu.OnPopup := LEventDummy;

  FHook.HookMenuDirectly(FPopupMenu);

  // Override the handler (simulating the IDE re-creating the menu)
  FOnPopup2Called := False;
  LNewDummy := DummyOnPopup2;
  FPopupMenu.OnPopup := LNewDummy;

  // Execute the hooker again (e.g. triggered by the 1s timer)
  FHook.HookMenuDirectly(FPopupMenu);

  // The active OnPopup handler should still point to the hook handler
  Assert.AreNotEqual(TMethod(FPopupMenu.OnPopup).Code, TMethod(LNewDummy).Code);

  // When the event fires, the overridden IDE handler should still be invoked
  if Assigned(FPopupMenu.OnPopup) then
    FPopupMenu.OnPopup(FPopupMenu);

  Assert.IsTrue(FOnPopup2Called, 'The overridden IDE handler should have been chained and executed by the hooker');
end;

procedure TTestEditorHook.TestRadIAMenuSurvivesOriginalPopupRebuild;
var
  LEventDummy: TNotifyEvent;
begin
  LEventDummy := DummyOnPopupClearsMenu;
  FPopupMenu.OnPopup := LEventDummy;

  FHook.HookMenuDirectly(FPopupMenu);

  if Assigned(FPopupMenu.OnPopup) then
    FPopupMenu.OnPopup(FPopupMenu);

  Assert.IsTrue(FOnPopupCalled, 'The original IDE popup handler should run before RadIA injection');
  Assert.IsNotNull(FPopupMenu.Items.Find('Rad IA'), 'Rad IA menu should be present after the original ' +
      'popup rebuilds the menu');
end;

procedure TTestEditorHook.TestRadIAMenuExposesInlineReviewDecisions;
  function HasCaption(
    const AParent: TMenuItem;
    const ACaption: string
  ): Boolean;
  var
    LIndex: Integer;
  begin
    Result := False;
    for LIndex := 0 to AParent.Count - 1 do
      if SameText(AParent[LIndex].Caption, ACaption) then
        Exit(True);
  end;
var
  LCut: TMenuItem;
  LRoot: TMenuItem;
begin
  LCut := TMenuItem.Create(FPopupMenu);
  LCut.Caption := 'Cut';
  FPopupMenu.Items.Add(LCut);
  FHook.HookMenuDirectly(FPopupMenu);
  if Assigned(FPopupMenu.OnPopup) then
    FPopupMenu.OnPopup(FPopupMenu);
  LRoot := FPopupMenu.Items.Find('Rad IA');
  Assert.IsNotNull(LRoot);
  Assert.IsTrue(HasCaption(LRoot, 'Accept Review at Cursor'));
  Assert.IsTrue(HasCaption(LRoot, 'Reject Review at Cursor'));
  Assert.IsTrue(HasCaption(LRoot, 'Next Review Block'));
  Assert.IsTrue(HasCaption(LRoot, 'Previous Review Block'));
  Assert.IsTrue(HasCaption(LRoot, 'Edit Review Block at Cursor'));
  Assert.IsTrue(HasCaption(LRoot, 'Explain Review Block at Cursor'));
  Assert.IsTrue(HasCaption(LRoot, 'Apply Resolved Block Review'));
  Assert.IsTrue(HasCaption(LRoot, 'Discard Block Review Session'));
  Assert.IsTrue(
    HasCaption(LRoot, 'Show Inline Completion Route Status')
  );
end;

procedure TTestEditorHook.TestUnhooking;
var
  LEventDummy: TNotifyEvent;
begin
  LEventDummy := DummyOnPopup;
  FPopupMenu.OnPopup := LEventDummy;

  FHook.HookMenuDirectly(FPopupMenu);
  FHook.UnhookMenuDirectly(FPopupMenu);

  // The original OnPopup handler should be perfectly restored
  Assert.AreEqual(TMethod(FPopupMenu.OnPopup).Code, TMethod(LEventDummy).Code);
end;

procedure TTestEditorHook.TestCleanCreateExampleResponseWithPascalFence;
var
  LCleaned: string;
begin
  LCleaned := TRadIAOTAHelper.CleanCodeResponse(
    '```pascal' + sLineBreak +
    'Result := True;' + sLineBreak +
    '```', '  ');

  Assert.AreEqual('  Result := True;', LCleaned);
end;

procedure TTestEditorHook.TestCleanCreateExampleResponseWithoutFence;
var
  LCleaned: string;
begin
  LCleaned := TRadIAOTAHelper.CleanCodeResponse(
    'Result := True;' + sLineBreak +
    'Exit;', '    ');

  Assert.AreEqual('    Result := True;' + sLineBreak + '    Exit;', LCleaned);
end;

procedure TTestEditorHook.TestCleanCreateExampleResponseIgnoresTextOutsideFence;
var
  LCleaned: string;
begin
  LCleaned := TRadIAOTAHelper.CleanCodeResponse(
    'Here is the code:' + sLineBreak +
    '```pascal' + sLineBreak +
    '  Result := True;' + sLineBreak +
    '```' + sLineBreak +
    'Done.', '  ');

  Assert.AreEqual('  Result := True;', LCleaned);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestEditorHook);

end.
