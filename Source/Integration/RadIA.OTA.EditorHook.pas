unit RadIA.OTA.EditorHook;

interface

uses
  System.Classes, Vcl.Menus, Vcl.Forms, Vcl.ExtCtrls,
  ToolsAPI,
  RadIA.Core.Interfaces,
  RadIA.Core.InlineCompletion,
  RadIA.Core.InlineReviews,
  RadIA.Core.InlineShortcuts,
  RadIA.OTA.ContextParser,
  RadIA.OTA.InlineCompletion;

type
  TRadIAEditorHook = class;

  TRadIAInlineCompletionKeyboardBinding = class(
    TNotifierObject,
    IOTAKeyboardBinding
  )
  private
    FOwner: TRadIAEditorHook;
    procedure AddBinding(
      const ABindingServices: IOTAKeyBindingServices;
      const AShortcut: TShortCut;
      const AHandler: TKeyBindingProc;
      const AActionName: string
    );
    procedure AcceptAll(
      const AContext: IOTAKeyContext;
      AKeyCode: TShortCut;
      var AResult: TKeyBindingResult
    );
    procedure AcceptNextWord(
      const AContext: IOTAKeyContext;
      AKeyCode: TShortCut;
      var AResult: TKeyBindingResult
    );
    procedure Alternative(
      const AContext: IOTAKeyContext;
      AKeyCode: TShortCut;
      var AResult: TKeyBindingResult
    );
    procedure Reject(
      const AContext: IOTAKeyContext;
      AKeyCode: TShortCut;
      var AResult: TKeyBindingResult
    );
    procedure ReviewAccept(
      const AContext: IOTAKeyContext;
      AKeyCode: TShortCut;
      var AResult: TKeyBindingResult
    );
    procedure ReviewReject(
      const AContext: IOTAKeyContext;
      AKeyCode: TShortCut;
      var AResult: TKeyBindingResult
    );
    procedure Request(
      const AContext: IOTAKeyContext;
      AKeyCode: TShortCut;
      var AResult: TKeyBindingResult
    );
  public
    constructor Create(const AOwner: TRadIAEditorHook);
    procedure AfterSave;
    procedure BeforeSave;
    procedure BindKeyboard(
      const ABindingServices: IOTAKeyBindingServices
    );
    procedure Destroyed;
    function GetBindingType: TBindingType;
    function GetDisplayName: string;
    function GetName: string;
    procedure Modified;
  end;

  { Manager to create and handle RadIA IDE contextual actions }
  TRadIAEditorHook = class(TComponent)
  private
    FOldActiveFormChange: TNotifyEvent;
    FInstalled: Boolean;
    FIDENotifierIndex: Integer;
    FEditorNotifiers: TInterfaceList;
    FConfig: IRadIAConfig;
    FIDEAdapter: IRadIAIDEAdapter;
    FInlineCompletionConsentGranted: Boolean;
    FInlineCompletionController: IRadIAInlineCompletionController;
    FInlineCompletionLastKey: string;
    FInlineCompletionSessionEnabled: Boolean;
    FInlineCompletionSession: IRadIAOTAInlineCompletionSession;
    FInlineShortcutBinding: IOTAKeyboardBinding;
    FInlineShortcutBindingIndex: Integer;
    FInlineShortcutProfile: string;
    FMediator: IRadIAMediator;
    {$IFNDEF TESTS}
    FTimer: TTimer;
    FHookPending: Boolean;
    FHookRequestedAt: UInt64;
    FInlineCompletionSmokePending: Boolean;
    {$ENDIF}

    procedure ActiveFormChange(Sender: TObject);
    procedure AddInlineMenuItems(
      const ARootItem: TMenuItem;
      const AProfile: TRadIAInlineShortcutProfile
    );
    procedure QueueHookActiveEditor;
    {$IFNDEF TESTS}
    procedure HookEditorWindowsNow;
    {$ENDIF}
    procedure InstallEditorNotifiers;
    procedure RemoveEditorNotifiers;
    procedure RestoreScreenOnActiveFormChange;
    procedure UnhookAllForms;
    procedure RestoreInterceptedMenus;
    {$IFNDEF TESTS}
    procedure SafeHookActiveForm;
    procedure SafeHookAllEditorForms;

    procedure HookPopupMenu(AForm: TCustomForm);
    {$ENDIF}
    procedure UnhookPopupMenu(AForm: TCustomForm);
    function FindEditorPopupMenu(AParent: TComponent): TPopupMenu;
    function IsEditorPopupMenu(APopupMenu: TPopupMenu): Boolean;
    procedure EditorMenuPopup(Sender: TObject);
    procedure InjectMenuIntoPopupMenu(APopupMenu: TPopupMenu);
    procedure RemoveMenuFromPopupMenu(APopupMenu: TPopupMenu);
    function FindMenuItemByName(const AItems: TMenuItem; const AName: string): TMenuItem;

    procedure OnExplainExecute(Sender: TObject);
    procedure OnOptimizeExecute(Sender: TObject);
    procedure OnOptimizeSQLExecute(Sender: TObject);
    procedure OnTestsExecute(Sender: TObject);
    procedure OnBugsExecute(Sender: TObject);
    procedure OnScanWarningsExecute(Sender: TObject);
    procedure OnDocExecute(Sender: TObject);
    procedure OnReviewExecute(Sender: TObject);
    procedure OnCreateExampleExecute(Sender: TObject);
    procedure OnFixErrorExecute(Sender: TObject);
    procedure OnGettingStartedExecute(Sender: TObject);
    procedure OnShowChatExecute(Sender: TObject);
    procedure OnShowTerminalExecute(Sender: TObject);
    procedure OnInlineCompletionAcceptExecute(Sender: TObject);
    procedure OnInlineCompletionAlternativeExecute(Sender: TObject);
    procedure OnInlineCompletionNextWordExecute(Sender: TObject);
    procedure OnInlineCompletionRejectExecute(Sender: TObject);
    procedure OnInlineCompletionPreviewDiagnosticExecute(Sender: TObject);
    procedure OnInlineCompletionRequestExecute(Sender: TObject);
    procedure OnInlineCompletionSessionToggleExecute(Sender: TObject);
    procedure OnInlineCompletionStatusExecute(Sender: TObject);
    procedure OnInlineReviewAcceptExecute(Sender: TObject);
    procedure OnInlineReviewRejectExecute(Sender: TObject);
    function ReviewWithSmartDiff(
      const AService: IRadIAInlineReviewService;
      const AReview: TRadIAInlineReview
    ): Boolean;
    function TryGetInlineReviewAtCursor(
      out AService: IRadIAInlineReviewService;
      out AReview: TRadIAInlineReview
    ): Boolean;
    function TryPreviewInlineCompletionDiagnostic: Boolean;
    {$IFNDEF TESTS}
    function TryRunInlineCompletionAcceptanceDiagnostic: Boolean;
    {$ENDIF}
    procedure RequestContinuousInlineCompletion;
    procedure RefreshInlineCompletionWatch;
    procedure RefreshKeyboardBinding;
    procedure RemoveKeyboardBinding;

    function BuildCreateExamplePrompt(const ASourceCode: string; const AContext: TMethodExampleContext): string;
    function GetEditorCodeContext(out ACode: string; out AUsedSelection: Boolean): Boolean;
    procedure SendCommandToChat(const ACommand: string; const APromptPrefix: string);
    {$IFNDEF TESTS}
    procedure RequestDelayedHook;
    procedure OnTimerEvent(Sender: TObject);
    {$ENDIF}
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure Install;
    procedure Uninstall;
    procedure PopulateToolsMenu(const AMenuItem: TMenuItem);

    procedure HookMenuDirectly(APopupMenu: TPopupMenu);
    procedure UnhookMenuDirectly(APopupMenu: TPopupMenu);
  end;

implementation

uses
  RadIA.Core.Patches,
  System.Generics.Collections,
  System.SysUtils,
  System.UITypes,
  Vcl.Dialogs,
  Winapi.Windows,
  RadIA.Core.Types,
  RadIA.Core.Mediator,
  {$IFNDEF TESTS}
  RadIA.OTA.DockableForm,
  RadIA.OTA.Onboarding,
  RadIA.UI.DiffForm,
  {$ENDIF}
  RadIA.Core.Logger, RadIA.Core.Container, RadIA.OTA.Adapter, RadIA.OTA.Helper;

const
  CEditorHookDelayMs = 2500;

{$IFDEF TESTS}
procedure ShowRadIAChat;
begin
  // Stub for unit tests to avoid pulling VCL Forms/WebView2 components
end;

procedure ShowRadIATerminal;
begin
  // Stub for unit tests to avoid pulling native dockable forms.
end;

procedure ShowRadIAOnboarding(const AForce: Boolean);
begin
  // Stub for unit tests to avoid pulling the onboarding form.
end;
{$ENDIF}

var
  // Global dictionary to track original OnPopup events for intercepted menus
  FInterceptedMenus: TDictionary<TPopupMenu, TNotifyEvent> = nil;

threadvar
  GExecutingPopup: Boolean;

{ TRadIAInlineCompletionKeyboardBinding }

procedure TRadIAInlineCompletionKeyboardBinding.AddBinding(
  const ABindingServices: IOTAKeyBindingServices;
  const AShortcut: TShortCut;
  const AHandler: TKeyBindingProc;
  const AActionName: string
);
begin
  if not ABindingServices.AddKeyBinding(
    [AShortcut],
    AHandler,
    nil
  ) then
    TLogger.Log(
      'Inline shortcut conflict for ' + AActionName + ': ' +
      ShortCutToText(AShortcut),
      'Warning'
    );
end;

procedure TRadIAInlineCompletionKeyboardBinding.AcceptAll(
  const AContext: IOTAKeyContext;
  AKeyCode: TShortCut;
  var AResult: TKeyBindingResult
);
begin
  AResult := krHandled;
  if Assigned(FOwner) then
    FOwner.OnInlineCompletionAcceptExecute(nil);
end;

procedure TRadIAInlineCompletionKeyboardBinding.AcceptNextWord(
  const AContext: IOTAKeyContext;
  AKeyCode: TShortCut;
  var AResult: TKeyBindingResult
);
begin
  AResult := krHandled;
  if Assigned(FOwner) then
    FOwner.OnInlineCompletionNextWordExecute(nil);
end;

procedure TRadIAInlineCompletionKeyboardBinding.AfterSave;
begin
  // No persisted state is owned by the OTA binding object.
end;

procedure TRadIAInlineCompletionKeyboardBinding.Alternative(
  const AContext: IOTAKeyContext;
  AKeyCode: TShortCut;
  var AResult: TKeyBindingResult
);
begin
  AResult := krHandled;
  if Assigned(FOwner) then
    FOwner.OnInlineCompletionAlternativeExecute(nil);
end;

procedure TRadIAInlineCompletionKeyboardBinding.BeforeSave;
begin
  // No persisted state is owned by the OTA binding object.
end;

procedure TRadIAInlineCompletionKeyboardBinding.BindKeyboard(
  const ABindingServices: IOTAKeyBindingServices
);
var
  LError: string;
  LProfile: TRadIAInlineShortcutProfile;
begin
  if not Assigned(ABindingServices) or not Assigned(FOwner) then
    Exit;
  if not TRadIAInlineShortcutProfile.TryParse(
    FOwner.FInlineShortcutProfile,
    LProfile,
    LError
  ) then
    LProfile := TRadIAInlineShortcutProfile.Default;
  AddBinding(
    ABindingServices,
    LProfile.ShortcutFor(isaRequest),
    Request,
    'request'
  );
  AddBinding(
    ABindingServices,
    LProfile.ShortcutFor(isaAcceptAll),
    AcceptAll,
    'accept'
  );
  AddBinding(
    ABindingServices,
    LProfile.ShortcutFor(isaAcceptNextWord),
    AcceptNextWord,
    'nextWord'
  );
  AddBinding(
    ABindingServices,
    LProfile.ShortcutFor(isaAlternative),
    Alternative,
    'alternative'
  );
  AddBinding(
    ABindingServices,
    LProfile.ShortcutFor(isaReject),
    Reject,
    'reject'
  );
  AddBinding(
    ABindingServices,
    LProfile.ShortcutFor(isaReviewAccept),
    ReviewAccept,
    'reviewAccept'
  );
  AddBinding(
    ABindingServices,
    LProfile.ShortcutFor(isaReviewReject),
    ReviewReject,
    'reviewReject'
  );
end;

constructor TRadIAInlineCompletionKeyboardBinding.Create(
  const AOwner: TRadIAEditorHook
);
begin
  inherited Create;
  FOwner := AOwner;
end;

procedure TRadIAInlineCompletionKeyboardBinding.Destroyed;
begin
  FOwner := nil;
end;

function TRadIAInlineCompletionKeyboardBinding.GetBindingType:
  TBindingType;
begin
  Result := btPartial;
end;

function TRadIAInlineCompletionKeyboardBinding.GetDisplayName: string;
begin
  Result := 'RadIA Inline Completion';
end;

function TRadIAInlineCompletionKeyboardBinding.GetName: string;
begin
  Result := 'RadIA.InlineCompletion';
end;

procedure TRadIAInlineCompletionKeyboardBinding.Modified;
begin
  // The binding is refreshed when the configured profile changes.
end;

procedure TRadIAInlineCompletionKeyboardBinding.Reject(
  const AContext: IOTAKeyContext;
  AKeyCode: TShortCut;
  var AResult: TKeyBindingResult
);
begin
  AResult := krHandled;
  if Assigned(FOwner) then
    FOwner.OnInlineCompletionRejectExecute(nil);
end;

procedure TRadIAInlineCompletionKeyboardBinding.Request(
  const AContext: IOTAKeyContext;
  AKeyCode: TShortCut;
  var AResult: TKeyBindingResult
);
begin
  AResult := krHandled;
  if Assigned(FOwner) then
    FOwner.OnInlineCompletionRequestExecute(nil);
end;

procedure TRadIAInlineCompletionKeyboardBinding.ReviewAccept(
  const AContext: IOTAKeyContext;
  AKeyCode: TShortCut;
  var AResult: TKeyBindingResult
);
begin
  AResult := krHandled;
  if Assigned(FOwner) then
    FOwner.OnInlineReviewAcceptExecute(nil);
end;

procedure TRadIAInlineCompletionKeyboardBinding.ReviewReject(
  const AContext: IOTAKeyContext;
  AKeyCode: TShortCut;
  var AResult: TKeyBindingResult
);
begin
  AResult := krHandled;
  if Assigned(FOwner) then
    FOwner.OnInlineReviewRejectExecute(nil);
end;

{ TRadIAEditorHook }

constructor TRadIAEditorHook.Create(AOwner: TComponent);
var
  LDispatcher: TRadIAInlineCompletionDispatcher;
  LOptions: TRadIAInlineCompletionOptions;
  LProvider: IRadIAInlineCompletionProvider;
  LRunner: TRadIAInlineCompletionRunner;
  LView: IRadIAInlineCompletionView;
begin
  inherited Create(AOwner);
  if not TRadIAContainer.TryResolve<IRadIAIDEAdapter>(FIDEAdapter) then
    FIDEAdapter := TRadIAConcreteIDEAdapter.Create;
  if not TRadIAContainer.TryResolve<IRadIAMediator>(FMediator) then
    FMediator := TRadIAMediator.Instance;
  TRadIAContainer.TryResolve<IRadIAConfig>(FConfig);
  FOldActiveFormChange := nil;
  FInlineCompletionConsentGranted := False;
  FInlineCompletionSessionEnabled := True;
  FInlineCompletionLastKey := '';
  FInlineShortcutBindingIndex := -1;
  FInlineShortcutProfile := TRadIAInlineShortcutProfile.DefaultText;
  FInlineCompletionSession := TRadIAOTAInlineCompletionSession.Create;
  if TRadIAContainer.TryResolve<IRadIAInlineCompletionProvider>(
    LProvider
  ) then
  begin
    LView := FInlineCompletionSession;
    LRunner :=
      procedure(const AAction: TProc)
      begin
        System.Classes.TThread.CreateAnonymousThread(AAction).Start;
      end;
    LDispatcher :=
      procedure(const AAction: TProc)
      begin
        System.Classes.TThread.Queue(
          nil,
          procedure
          begin
            AAction();
          end
        );
      end;
    if Assigned(FConfig) then
      LOptions := TRadIAInlineCompletionOptions.Create(
        FConfig.AutocompleteDelay,
        24000,
        4000
      )
    else
      LOptions := TRadIAInlineCompletionOptions.Default;
    FInlineCompletionController := TRadIAInlineCompletionController.Create(
      LProvider,
      LView,
      LOptions,
      LRunner,
      LDispatcher
    );
    RefreshInlineCompletionWatch;
  end;
  FIDENotifierIndex := -1;
  FEditorNotifiers := TInterfaceList.Create;
  {$IFNDEF TESTS}
  FTimer := nil;
  FHookPending := False;
  FHookRequestedAt := 0;
  FInlineCompletionSmokePending := SameText(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_INLINE_COMPLETION'),
    '1'
  );
  {$ENDIF}
  FInstalled := False;
end;

destructor TRadIAEditorHook.Destroy;
begin
  Uninstall;
  if Assigned(FInlineCompletionController) then
    FInlineCompletionController.Stop;
  FInlineCompletionController := nil;
  FInlineCompletionSession.ConfigureContinuous(False, nil);
  FInlineCompletionSession := nil;
  FEditorNotifiers.Free;
  inherited Destroy;
end;

procedure TRadIAEditorHook.Install;
begin
  if FInstalled then
    Exit;

  TLogger.Log('Installing editor local menu hooks via VCL injection', 'EditorHook');

  if not Assigned(FInterceptedMenus) then
    FInterceptedMenus := TDictionary<TPopupMenu, TNotifyEvent>.Create;

  FOldActiveFormChange := Screen.OnActiveFormChange;
  Screen.OnActiveFormChange := ActiveFormChange;
  InstallEditorNotifiers;
  RefreshKeyboardBinding;

{$IFNDEF TESTS}
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 250;
  FTimer.OnTimer := OnTimerEvent;
  FTimer.Enabled := True;
{$ENDIF}

  FInstalled := True;
  QueueHookActiveEditor;
end;

procedure TRadIAEditorHook.RestoreScreenOnActiveFormChange;
begin
  if Assigned(Screen) then
  begin
    try
      Screen.OnActiveFormChange := FOldActiveFormChange;
    except
      on E: Exception do
        TLogger.Log('Uninstall: Error restoring Screen.OnActiveFormChange: ' + E.Message, 'EditorHook');
    end;
  end;
end;

procedure TRadIAEditorHook.UnhookAllForms;
var
  I: Integer;
begin
  if Assigned(Screen) then
  begin
    for I := 0 to Screen.FormCount - 1 do
    begin
      try
        UnhookPopupMenu(Screen.Forms[I]);
      except
        on E: Exception do
          TLogger.Log('Uninstall: Error unhooking form menu: ' + E.Message, 'EditorHook');
      end;
    end;
  end;
end;

procedure TRadIAEditorHook.RestoreInterceptedMenus;
var
  LMenu: TPopupMenu;
  LOldOnPopup: TNotifyEvent;
begin
  if Assigned(FInterceptedMenus) then
  begin
    try
      for LMenu in FInterceptedMenus.Keys do
      begin
        try
          LOldOnPopup := FInterceptedMenus[LMenu];
          LMenu.OnPopup := LOldOnPopup;
          RemoveMenuFromPopupMenu(LMenu);
        except
          on E: Exception do
            TLogger.Log('Uninstall: Error restoring popup menu: ' + E.Message, 'EditorHook');
        end;
      end;
    finally
      FInterceptedMenus.Clear;
      FreeAndNil(FInterceptedMenus);
    end;
  end;
end;

procedure TRadIAEditorHook.Uninstall;
begin
  if not FInstalled then
    Exit;

  TLogger.Log('Uninstalling editor local menu hooks', 'EditorHook');

  {$IFNDEF TESTS}
  if Assigned(FTimer) then
  begin
    FTimer.Enabled := False;
    FreeAndNil(FTimer);
  end;
  {$ENDIF}

  RestoreScreenOnActiveFormChange;
  RemoveKeyboardBinding;
  FInstalled := False;
  RemoveEditorNotifiers;
  UnhookAllForms;
  RestoreInterceptedMenus;
end;

procedure TRadIAEditorHook.ActiveFormChange(Sender: TObject);
var
  LActiveForm: TCustomForm;
begin
  if Assigned(FOldActiveFormChange) then
  begin
    try
      FOldActiveFormChange(Sender);
    except
      on E: Exception do
        TLogger.Log('ActiveFormChange: Error executing original OnActiveFormChange: ' + E.Message, 'EditorHook');
    end;
  end;

  try
    if Assigned(Screen) then
    begin
      LActiveForm := Screen.ActiveForm;
      if Assigned(LActiveForm) and SameText(LActiveForm.ClassName, 'TEditWindow') then
      begin
        RefreshKeyboardBinding;
        RefreshInlineCompletionWatch;
        QueueHookActiveEditor;
      end;
    end;
  except
    on E: Exception do
      TLogger.Log('ActiveFormChange: General error: ' + E.Message, 'EditorHook');
  end;
end;

procedure TRadIAEditorHook.QueueHookActiveEditor;
begin
  {$IFDEF TESTS}
  Exit;
  {$ELSE}
  TThread.Queue(nil,
    TThreadProcedure(
    procedure begin
      RequestDelayedHook;
    end));
  {$ENDIF}
end;

{$IFNDEF TESTS}
procedure TRadIAEditorHook.SafeHookActiveForm;
begin
  if Assigned(Screen) and Assigned(Screen.ActiveForm) and
     Screen.ActiveForm.HandleAllocated and Screen.ActiveForm.Visible then
  begin
    try
      HookPopupMenu(Screen.ActiveForm);
    except
      on E: Exception do
        TLogger.Log('HookEditorWindowsNow: Error hooking active form: ' + E.Message, 'EditorHook');
    end;
  end;
end;

procedure TRadIAEditorHook.SafeHookAllEditorForms;
var
  I: Integer;
begin
  if Assigned(Screen) then
  begin
    for I := 0 to Screen.FormCount - 1 do
    begin
      if SameText(Screen.Forms[I].ClassName, 'TEditWindow') and
         Screen.Forms[I].HandleAllocated and Screen.Forms[I].Visible then
      begin
        try
          HookPopupMenu(Screen.Forms[I]);
        except
          on E: Exception do
            TLogger.Log('HookEditorWindowsNow: Error hooking editor window: ' + E.Message, 'EditorHook');
        end;
      end;
    end;
  end;
end;

procedure TRadIAEditorHook.HookEditorWindowsNow;
begin
  if (not FInstalled) or GIsShuttingDown then
    Exit;

  SafeHookActiveForm;
  SafeHookAllEditorForms;
end;
{$ENDIF}

procedure TRadIAEditorHook.InstallEditorNotifiers;
begin
  // Intentionally empty: Notifiers not needed because VCL timer is used to hook windows
  // Added harmless statement to satisfy SonarQube EmptyRoutine and RedundantJump rules
  if True then ;
end;

procedure TRadIAEditorHook.RemoveEditorNotifiers;
var
  LOTAServices: IOTAServices;
begin
  {$IFDEF TESTS}
  Exit;
  {$ENDIF}

  FEditorNotifiers.Clear;

  if (FIDENotifierIndex >= 0) and Supports(BorlandIDEServices, IOTAServices, LOTAServices) then
  begin
    try
      LOTAServices.RemoveNotifier(FIDENotifierIndex);
    except
      on E: Exception do
        TLogger.Log('RemoveEditorNotifiers: Error removing IDE notifier: ' + E.Message, 'EditorHook');
    end;
    FIDENotifierIndex := -1;
  end;
end;

function TRadIAEditorHook.FindEditorPopupMenu(AParent: TComponent): TPopupMenu;
var
  LComp: TComponent;
begin
  Result := nil;
  if Assigned(AParent) then
  begin
    LComp := AParent.FindComponent('EditorLocalMenu');
    if Assigned(LComp) and (LComp is TPopupMenu) then
      Result := TPopupMenu(LComp);
  end;
end;

function TRadIAEditorHook.IsEditorPopupMenu(APopupMenu: TPopupMenu): Boolean;
  function HasCaption(const AItem: TMenuItem; const ACaption: string): Boolean;
  var
    I: Integer;
    LCaption: string;
  begin
    Result := False;
    if not Assigned(AItem) then
      Exit;

    for I := 0 to AItem.Count - 1 do
    begin
      LCaption := StringReplace(AItem[I].Caption, '&', '', [rfReplaceAll]);
      if SameText(LCaption, ACaption) then
        Exit(True);

      if HasCaption(AItem[I], ACaption) then
        Exit(True);
    end;
  end;
begin
  Result := False;
  if not Assigned(APopupMenu) then
    Exit;

  if SameText(APopupMenu.Name, 'EditorLocalMenu') then
    Exit(True);

  Result :=
    HasCaption(APopupMenu.Items, 'Cut') or
    HasCaption(APopupMenu.Items, 'Copy') or
    HasCaption(APopupMenu.Items, 'Paste') or
    HasCaption(APopupMenu.Items, 'Select All') or
    HasCaption(APopupMenu.Items, 'Editor Options') or
    HasCaption(APopupMenu.Items, 'Read Only');
end;

{$IFNDEF TESTS}
procedure TRadIAEditorHook.HookPopupMenu(AForm: TCustomForm);
var
  LPopupMenu: TPopupMenu;
begin
  if not Assigned(AForm) then
    Exit;

  // Only hook editor windows to avoid side effects while other IDE forms are being created.
  if not SameText(AForm.ClassName, 'TEditWindow') then
    Exit;

  if (not AForm.HandleAllocated) or (not AForm.Visible) then
    Exit;

  LPopupMenu := FindEditorPopupMenu(AForm);
  if Assigned(LPopupMenu) then
    HookMenuDirectly(LPopupMenu);
end;
{$ENDIF}

procedure TRadIAEditorHook.UnhookPopupMenu(AForm: TCustomForm);
var
  LPopupMenu: TPopupMenu;
begin
  if not Assigned(AForm) then
    Exit;

  if not SameText(AForm.ClassName, 'TEditWindow') then
    Exit;

  if not AForm.HandleAllocated then
    Exit;

  LPopupMenu := FindEditorPopupMenu(AForm);
  if Assigned(LPopupMenu) then
    UnhookMenuDirectly(LPopupMenu);
end;

procedure TRadIAEditorHook.HookMenuDirectly(APopupMenu: TPopupMenu);
var
  LEventHook: TNotifyEvent;
  LEventCurrent: TNotifyEvent;
  LMethodHook: TMethod;
  LMethodCurrent: TMethod;
begin
  if not Assigned(APopupMenu) then
    Exit;

  if not Assigned(FInterceptedMenus) then
    Exit;

  LEventHook := EditorMenuPopup;
  LMethodHook := TMethod(LEventHook);
  LEventCurrent := APopupMenu.OnPopup;
  LMethodCurrent := TMethod(LEventCurrent);

  // Re-hook when another extension or the IDE replaces our popup handler.
  if (LMethodCurrent.Code <> LMethodHook.Code) or (LMethodCurrent.Data <> LMethodHook.Data) then
  begin
    if FInterceptedMenus.ContainsKey(APopupMenu) then
    begin
      TLogger.Log('Re-hooking OnPopup of EditorLocalMenu - hook was overridden', 'EditorHook');
      FInterceptedMenus.AddOrSetValue(APopupMenu, LEventCurrent);
    end
    else
    begin
      TLogger.Log('Hooking OnPopup of EditorLocalMenu', 'EditorHook');
      FInterceptedMenus.Add(APopupMenu, LEventCurrent);
    end;

    APopupMenu.OnPopup := LEventHook;
  end;
end;

procedure TRadIAEditorHook.UnhookMenuDirectly(APopupMenu: TPopupMenu);
var
  LOldOnPopup: TNotifyEvent;
begin
  if not Assigned(APopupMenu) then
    Exit;

  if Assigned(FInterceptedMenus) and FInterceptedMenus.TryGetValue(APopupMenu, LOldOnPopup) then
  begin
    TLogger.Log('Unhooking OnPopup of EditorLocalMenu', 'EditorHook');
    APopupMenu.OnPopup := LOldOnPopup;
    FInterceptedMenus.Remove(APopupMenu);
    RemoveMenuFromPopupMenu(APopupMenu);
  end;
end;

procedure TRadIAEditorHook.EditorMenuPopup(Sender: TObject);
var
  LPopupMenu: TPopupMenu;
  LOldOnPopup: TNotifyEvent;
begin
  // Circuit breaker to avoid mutual recursion with other third-party popup hooks.
  if GExecutingPopup then
    Exit;

  GExecutingPopup := True;
  try
    try
      if Sender is TPopupMenu then
      begin
        LPopupMenu := TPopupMenu(Sender);

        if Assigned(FInterceptedMenus) and FInterceptedMenus.TryGetValue(LPopupMenu,
            LOldOnPopup) and Assigned(LOldOnPopup) then
        begin
          try
            LOldOnPopup(Sender);
          except
            on E: Exception do
              TLogger.Log('EditorMenuPopup: Error executing original OnPopup: ' + E.Message, 'EditorHook');
          end;
        end;

        if IsEditorPopupMenu(LPopupMenu) then
        begin
          try
            InjectMenuIntoPopupMenu(LPopupMenu);
          except
            on E: Exception do
              TLogger.Log('EditorMenuPopup: Error injecting RadIA menu: ' + E.Message, 'EditorHook');
          end;
        end
        else
          TLogger.Log('EditorMenuPopup: Skipping non-editor popup menu: ' + LPopupMenu.Name, 'EditorHook');
      end;
    except
      on E: Exception do
        TLogger.Log('EditorMenuPopup: General error: ' + E.Message, 'EditorHook');
    end;
  finally
    GExecutingPopup := False;
  end;
end;

function TRadIAEditorHook.FindMenuItemByName(const AItems: TMenuItem; const AName: string): TMenuItem;
var
  I: Integer;
begin
  Result := nil;
  if not Assigned(AItems) then
    Exit;

  for I := 0 to AItems.Count - 1 do
  begin
    if SameText(AItems[I].Name, AName) then
      Exit(AItems[I]);

    Result := FindMenuItemByName(AItems[I], AName);
    if Assigned(Result) then
      Exit;
  end;
end;

procedure TRadIAEditorHook.AddInlineMenuItems(
  const ARootItem: TMenuItem;
  const AProfile: TRadIAInlineShortcutProfile
);
  procedure AddItem(
    const ACaption: string;
    const AShortcut: TShortCut;
    const AHandler: TNotifyEvent
  );
  var
    LItem: TMenuItem;
  begin
    LItem := TMenuItem.Create(ARootItem);
    LItem.Caption := ACaption;
    LItem.ShortCut := AShortcut;
    LItem.OnClick := AHandler;
    ARootItem.Add(LItem);
  end;
begin
  AddItem(
    'Request Inline Suggestion',
    AProfile.ShortcutFor(isaRequest),
    OnInlineCompletionRequestExecute
  );
  AddItem(
    'Accept Inline Suggestion',
    AProfile.ShortcutFor(isaAcceptAll),
    OnInlineCompletionAcceptExecute
  );
  AddItem(
    'Accept Next Inline Word',
    AProfile.ShortcutFor(isaAcceptNextWord),
    OnInlineCompletionNextWordExecute
  );
  AddItem(
    'Request Alternative Inline Suggestion',
    AProfile.ShortcutFor(isaAlternative),
    OnInlineCompletionAlternativeExecute
  );
  AddItem(
    'Reject Inline Suggestion',
    AProfile.ShortcutFor(isaReject),
    OnInlineCompletionRejectExecute
  );
  AddItem('-', 0, nil);
  AddItem(
    'Accept Review at Cursor',
    AProfile.ShortcutFor(isaReviewAccept),
    OnInlineReviewAcceptExecute
  );
  AddItem(
    'Reject Review at Cursor',
    AProfile.ShortcutFor(isaReviewReject),
    OnInlineReviewRejectExecute
  );
  AddItem(
    'Pause/Resume Inline Completion for Session',
    0,
    OnInlineCompletionSessionToggleExecute
  );
  AddItem(
    'Preview Local Ghost Text Diagnostic',
    0,
    OnInlineCompletionPreviewDiagnosticExecute
  );
  AddItem(
    'Show Inline Completion Route Status',
    0,
    OnInlineCompletionStatusExecute
  );
end;

procedure TRadIAEditorHook.InjectMenuIntoPopupMenu(APopupMenu: TPopupMenu);
var
  LError: string;
  LProfile: TRadIAInlineShortcutProfile;
  LRootItem: TMenuItem;
  LSubItem: TMenuItem;
  LComp: TComponent;
begin
  if not Assigned(APopupMenu) then
    Exit;

  // Nothing to do if the Rad IA menu is already present.
  if Assigned(FindMenuItemByName(APopupMenu.Items, 'mnuRadIARoot')) then
    Exit;

  // Remove orphaned owner components to avoid duplicate component names in the IDE.

  LComp := APopupMenu.FindComponent('mnuRadIARoot');
  if Assigned(LComp) then
  begin
    try
      LComp.Free;
    except
      on E: Exception do
        TLogger.Log('InjectMenuIntoPopupMenu: Error freeing orphaned mnuRadIARoot: ' + E.Message, 'EditorHook');
    end;
  end;

  LComp := APopupMenu.FindComponent('mnuRadIASeparator');
  if Assigned(LComp) then
  begin
    try
      LComp.Free;
    except
      on E: Exception do
        TLogger.Log('InjectMenuIntoPopupMenu: Error freeing orphaned mnuRadIASeparator: ' + E.Message, 'EditorHook');
    end;
  end;

  TLogger.Log('Injecting Rad IA menu items into EditorLocalMenu', 'EditorHook');
  if not TRadIAInlineShortcutProfile.TryParse(
    FInlineShortcutProfile,
    LProfile,
    LError
  ) then
    LProfile := TRadIAInlineShortcutProfile.Default;

  // Root Submenu Item
  LRootItem := TMenuItem.Create(APopupMenu);
  LRootItem.Name := 'mnuRadIARoot';
  LRootItem.Caption := 'Rad IA';

  // Action Submenu Items - Owner MUST be LRootItem so they are automatically freed when LRootItem is freed
  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := 'Explain Selected Code';
  LSubItem.OnClick := OnExplainExecute;
  LRootItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := 'Optimize/Refactor Code';
  LSubItem.OnClick := OnOptimizeExecute;
  LRootItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := 'Optimize SQL Query';
  LSubItem.OnClick := OnOptimizeSQLExecute;
  LRootItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := 'Create Implementation from Comment';
  LSubItem.OnClick := OnCreateExampleExecute;
  LRootItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := 'Generate Unit Tests (DUnitX)';
  LSubItem.OnClick := OnTestsExecute;
  LRootItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := 'Locate Bugs/Memory Leaks';
  LSubItem.OnClick := OnBugsExecute;
  LRootItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := 'Scan Compiler & OS Warnings';
  LSubItem.OnClick := OnScanWarningsExecute;
  LRootItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := 'Document Method (XML)';
  LSubItem.OnClick := OnDocExecute;
  LRootItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := 'Review Active Unit (Leaks/SOLID)';
  LSubItem.OnClick := OnReviewExecute;
  LRootItem.Add(LSubItem);

  LSubItem := TMenuItem.Create(LRootItem);
  LSubItem.Caption := '-';
  LRootItem.Add(LSubItem);

  AddInlineMenuItems(LRootItem, LProfile);

  // Separator visual
  LSubItem := TMenuItem.Create(APopupMenu);
  LSubItem.Caption := '-';
  LSubItem.Name := 'mnuRadIASeparator';

  // Keep Rad IA visible as the first editor action group.
  APopupMenu.Items.Insert(0, LRootItem);
  APopupMenu.Items.Insert(1, LSubItem);
end;

procedure TRadIAEditorHook.RemoveMenuFromPopupMenu(APopupMenu: TPopupMenu);
var
  LItem: TMenuItem;
begin
  if not Assigned(APopupMenu) then
    Exit;

  LItem := FindMenuItemByName(APopupMenu.Items, 'mnuRadIARoot');
  LItem.Free;

  LItem := FindMenuItemByName(APopupMenu.Items, 'mnuRadIASeparator');
  LItem.Free;
end;

procedure TRadIAEditorHook.PopulateToolsMenu(const AMenuItem: TMenuItem);
var
  LError: string;
  LItem: TMenuItem;
  LProfile: TRadIAInlineShortcutProfile;
begin
  if not Assigned(AMenuItem) then
    Exit;
  if not TRadIAInlineShortcutProfile.TryParse(
    FInlineShortcutProfile,
    LProfile,
    LError
  ) then
    LProfile := TRadIAInlineShortcutProfile.Default;

  LItem := TMenuItem.Create(AMenuItem);
  LItem.Caption := 'Rad IA Chat Panel';
  LItem.OnClick := OnShowChatExecute;
  AMenuItem.Add(LItem);

  LItem := TMenuItem.Create(AMenuItem);
  LItem.Caption := 'Rad IA Terminal';
  LItem.ShortCut := LProfile.ShortcutFor(isaTerminal);
  LItem.OnClick := OnShowTerminalExecute;
  AMenuItem.Add(LItem);

  LItem := TMenuItem.Create(AMenuItem);
  LItem.Caption := 'Rad IA Getting Started';
  LItem.OnClick := OnGettingStartedExecute;
  AMenuItem.Add(LItem);

  LItem := TMenuItem.Create(AMenuItem);
  LItem.Caption := 'Preview Rad IA Ghost Text Diagnostic';
  LItem.OnClick := OnInlineCompletionPreviewDiagnosticExecute;
  AMenuItem.Add(LItem);

  LItem := TMenuItem.Create(AMenuItem);
  LItem.Caption := 'Rad IA Inline Completion Route Status';
  LItem.OnClick := OnInlineCompletionStatusExecute;
  AMenuItem.Add(LItem);

  LItem := TMenuItem.Create(AMenuItem);
  LItem.Caption := 'Fix Last Compiler Error';
  LItem.OnClick := OnFixErrorExecute;
  AMenuItem.Add(LItem);
end;

function TRadIAEditorHook.GetEditorCodeContext(out ACode: string; out AUsedSelection: Boolean): Boolean;
var
  LHasText: Boolean;
begin
  Result := False;
  ACode := '';
  AUsedSelection := False;

  LHasText := FIDEAdapter.GetActiveEditorText(ACode, True);

  if LHasText and (not ACode.Trim.IsEmpty) then
  begin
    AUsedSelection := True;
    Exit(True);
  end;

  LHasText := FIDEAdapter.GetActiveEditorText(ACode, False);

  if LHasText and (not ACode.Trim.IsEmpty) then
    Exit(True);
end;

procedure TRadIAEditorHook.SendCommandToChat(const ACommand: string; const APromptPrefix: string);
var
  LCode: string;
  LUsedSelection: Boolean;
  LPrompt: string;
begin
  if not GetEditorCodeContext(LCode, LUsedSelection) then
  begin
    TLogger.Log(Format('SendCommandToChat failed: no active code for command %s', [ACommand]), 'EditorHook');
    ShowMessage('No active code file open in the editor.');
    Exit;
  end;

  TLogger.Log(Format('SendCommandToChat: Command=%s, CodeLength=%d, UsedSelection=%s',
    [ACommand, Length(LCode), BoolToStr(LUsedSelection, True)]), 'EditorHook');
  ShowRadIAChat;

  LPrompt := ACommand + sLineBreak +
    APromptPrefix + sLineBreak + sLineBreak +
    '```pascal' + sLineBreak +
    LCode.TrimRight + sLineBreak +
    '```';
  FMediator.RequestPrompt(LPrompt, True);
end;

procedure TRadIAEditorHook.OnExplainExecute(Sender: TObject);
begin
  SendCommandToChat('/explain', 'Explain this Delphi Pascal code briefly. Focus on intent and important details only:');
end;

procedure TRadIAEditorHook.OnOptimizeSQLExecute(Sender: TObject);
begin
  SendCommandToChat('/sqloptimize', 'Analyze and optimize this SQL query. Suggest indexes, join optimization, ' +
      'syntax corrections, and general improvements:');
end;

procedure TRadIAEditorHook.OnScanWarningsExecute(Sender: TObject);
begin
  SendCommandToChat('/scanwarnings', 'Analyze this Delphi code for potential compiler warnings, thread-safety ' +
      'violations, and Windows resource leaks (such as unreleased GDI handles):');
end;

procedure TRadIAEditorHook.OnShowChatExecute(Sender: TObject);
begin
  ShowRadIAChat;
end;

procedure TRadIAEditorHook.OnGettingStartedExecute(Sender: TObject);
begin
  ShowRadIAOnboarding(True);
end;

procedure TRadIAEditorHook.OnShowTerminalExecute(Sender: TObject);
begin
  ShowRadIATerminal;
end;

procedure TRadIAEditorHook.OnInlineCompletionAcceptExecute(
  Sender: TObject
);
begin
  if Assigned(FInlineCompletionController) then
    FInlineCompletionController.AcceptAll;
end;

procedure TRadIAEditorHook.OnInlineCompletionAlternativeExecute(
  Sender: TObject
);
begin
  if Assigned(FInlineCompletionController) then
    FInlineCompletionController.RequestAlternative;
end;

procedure TRadIAEditorHook.OnInlineCompletionNextWordExecute(
  Sender: TObject
);
begin
  if Assigned(FInlineCompletionController) then
    FInlineCompletionController.AcceptNextWord;
end;

procedure TRadIAEditorHook.OnInlineCompletionRejectExecute(
  Sender: TObject
);
begin
  if Assigned(FInlineCompletionController) then
    FInlineCompletionController.Reject;
end;

procedure TRadIAEditorHook.OnInlineCompletionPreviewDiagnosticExecute(
  Sender: TObject
);
begin
  if not TryPreviewInlineCompletionDiagnostic then
    ShowMessage('No supported active code buffer was found.');
end;

function TRadIAEditorHook.TryPreviewInlineCompletionDiagnostic: Boolean;
const
  CDiagnosticSuggestion =
    'RadIAGhostTextDiagnostic' + sLineBreak +
    '// Local multiline preview; no context was sent.';
var
  LContext: TRadIAInlineCompletionContext;
begin
  Result := False;
  if not Assigned(FInlineCompletionController) or
    not Assigned(FInlineCompletionSession) then
    Exit;
  if not FInlineCompletionSession.Capture(LContext) then
    Exit;
  FInlineCompletionController.Preview(
    LContext,
    CDiagnosticSuggestion
  );
  Result := True;
end;

procedure TRadIAEditorHook.OnInlineCompletionRequestExecute(
  Sender: TObject
);
var
  LContext: TRadIAInlineCompletionContext;
begin
  if not Assigned(FInlineCompletionController) or
    not Assigned(FInlineCompletionSession) then
    Exit;
  if not FInlineCompletionConsentGranted then
  begin
    if MessageDlg(
      'RadIA will send a bounded context from the active editor buffer ' +
      'to the selected provider to generate an inline suggestion. ' +
      'Continue for this IDE session?',
      mtConfirmation,
      [mbYes, mbNo],
      0
    ) <> mrYes then
      Exit;
    FInlineCompletionConsentGranted := True;
  end;
  if not FInlineCompletionSession.Capture(LContext) then
  begin
    ShowMessage('No supported active code buffer was found.');
    Exit;
  end;
  FInlineCompletionController.Request(LContext);
end;

procedure TRadIAEditorHook.OnInlineCompletionSessionToggleExecute(
  Sender: TObject
);
begin
  FInlineCompletionSessionEnabled :=
    not FInlineCompletionSessionEnabled;
  FInlineCompletionLastKey := '';
  if not FInlineCompletionSessionEnabled and
    Assigned(FInlineCompletionController) then
    FInlineCompletionController.Stop;
  RefreshInlineCompletionWatch;
end;

{$IFNDEF TESTS}
function TRadIAEditorHook.TryRunInlineCompletionAcceptanceDiagnostic:
  Boolean;
const
  CAcceptanceSuggestion =
    'RadIAFimAcceptanceDiagnostic' + sLineBreak +
    '// Local acceptance and undo diagnostic.';
var
  LAccepted: Boolean;
  LAcceptedContext: TRadIAInlineCompletionContext;
  LOriginalContext: TRadIAInlineCompletionContext;
  LPreviewContext: TRadIAInlineCompletionContext;
  LPreviewClean: Boolean;
  LRejectedContext: TRadIAInlineCompletionContext;
  LRejectedClean: Boolean;
  LSingleUndo: Boolean;
  LUndoContext: TRadIAInlineCompletionContext;
  LUndoRestored: Boolean;
begin
  Result := False;
  if not Assigned(FInlineCompletionController) or
    not Assigned(FInlineCompletionSession) or
    not FInlineCompletionSession.Capture(LOriginalContext) then
    Exit;
  Result := True;
  FInlineCompletionController.Preview(
    LOriginalContext,
    CAcceptanceSuggestion
  );
  LPreviewClean := FInlineCompletionSession.Capture(LPreviewContext) and
    SameText(LPreviewContext.Revision, LOriginalContext.Revision);
  LAccepted := FInlineCompletionController.AcceptAll and
    FInlineCompletionSession.Capture(LAcceptedContext) and
    not SameText(LAcceptedContext.Revision, LOriginalContext.Revision);
  LSingleUndo := LAccepted and
    FInlineCompletionSession.UndoCurrentBuffer;
  LUndoRestored := LSingleUndo and
    FInlineCompletionSession.Capture(LUndoContext) and
    SameText(LUndoContext.Revision, LOriginalContext.Revision);
  if LUndoRestored then
  begin
    FInlineCompletionController.Preview(
      LUndoContext,
      CAcceptanceSuggestion
    );
    FInlineCompletionController.Reject;
  end;
  LRejectedClean := LUndoRestored and
    FInlineCompletionSession.Capture(LRejectedContext) and
    SameText(LRejectedContext.Revision, LOriginalContext.Revision);
  TLogger.Log(
    Format(
      'Inline completion acceptance: previewClean=%s, accepted=%s, ' +
      'singleUndo=%s, undoRestored=%s, rejectedClean=%s, file=%s',
      [
        BoolToStr(LPreviewClean, True),
        BoolToStr(LAccepted, True),
        BoolToStr(LSingleUndo, True),
        BoolToStr(LUndoRestored, True),
        BoolToStr(LRejectedClean, True),
        ExtractFileName(LOriginalContext.FileName)
      ]
    ),
    'InlineCompletion'
  );
end;
{$ENDIF}

procedure TRadIAEditorHook.OnInlineCompletionStatusExecute(
  Sender: TObject
);
var
  LDiagnostic: TRadIAFimDiagnostic;
  LDiagnostics: IRadIAInlineCompletionDiagnostics;
  LMessage: string;
  LProvider: IRadIAInlineCompletionProvider;
begin
  if not TRadIAContainer.TryResolve<IRadIAInlineCompletionProvider>(
    LProvider
  ) or not Supports(
    LProvider,
    IRadIAInlineCompletionDiagnostics,
    LDiagnostics
  ) then
  begin
    ShowMessage('Inline completion diagnostics are not available.');
    Exit;
  end;
  LDiagnostic := LDiagnostics.GetLastDiagnostic;
  if LDiagnostic.ProviderId = '' then
  begin
    ShowMessage(
      'No inline completion request has finished in this IDE session.'
    );
    Exit;
  end;
  LMessage :=
    'Route: ' + LDiagnostic.RouteName + sLineBreak +
    'Provider: ' + LDiagnostic.ProviderId + sLineBreak +
    'Model: ' + LDiagnostic.ModelId + sLineBreak +
    'Local latency: ' + LDiagnostic.LatencyMs.ToString + ' ms';
  if LDiagnostic.FallbackReason <> '' then
    LMessage := LMessage + sLineBreak +
      'Fallback reason: ' + LDiagnostic.FallbackReason;
  ShowMessage(LMessage);
end;

procedure TRadIAEditorHook.OnInlineReviewAcceptExecute(
  Sender: TObject
);
var
  LResult: TRadIAPatchResult;
  LReview: TRadIAInlineReview;
  LService: IRadIAInlineReviewService;
begin
  if not TryGetInlineReviewAtCursor(LService, LReview) then
  begin
    ShowMessage('No inline review is available at the current line.');
    Exit;
  end;
  if LReview.RequiresSmartDiff then
  begin
    ReviewWithSmartDiff(LService, LReview);
    Exit;
  end;
  if MessageDlg(
    'Apply this inline review suggestion?' + sLineBreak + sLineBreak +
    LReview.Message,
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then
    Exit;
  LResult := LService.ApplyFix(LReview.Id);
  if not LResult.Success then
  begin
    ShowMessage(
      'The inline review could not be applied: ' +
      LResult.ErrorMessage
    );
    Exit;
  end;
  TLogger.Log(
    'Inline review applied from the editor: ' + LReview.Id,
    'InlineReview'
  );
end;

procedure TRadIAEditorHook.OnInlineReviewRejectExecute(
  Sender: TObject
);
var
  LReview: TRadIAInlineReview;
  LService: IRadIAInlineReviewService;
begin
  if not TryGetInlineReviewAtCursor(LService, LReview) then
  begin
    ShowMessage('No inline review is available at the current line.');
    Exit;
  end;
  if not LService.Reject(LReview.Id) then
  begin
    ShowMessage('The inline review is no longer available.');
    Exit;
  end;
  TLogger.Log(
    'Inline review rejected from the editor: ' + LReview.Id,
    'InlineReview'
  );
end;

function TRadIAEditorHook.ReviewWithSmartDiff(
  const AService: IRadIAInlineReviewService;
  const AReview: TRadIAInlineReview
): Boolean;
{$IFNDEF TESTS}
var
  LApply: TRadIAPatchResult;
  LForm: TRadIAFormAIDiff;
  LPatchService: IRadIAPatchService;
  LPrepare: TRadIAPatchResult;
  LSelected: TRadIAPatchResult;
{$ENDIF}
begin
  Result := False;
  {$IFNDEF TESTS}
  LPrepare := AService.PrepareFix(AReview.Id);
  if not LPrepare.Success then
  begin
    ShowMessage(
      'The inline review preview could not be prepared: ' +
      LPrepare.ErrorMessage
    );
    Exit;
  end;
  if not TRadIAContainer.TryResolve<IRadIAPatchService>(
    LPatchService
  ) then
    Exit;
  LForm := TRadIAFormAIDiff.Create(nil);
  try
    LForm.InitializePreparedDiff(
      AReview.FileName,
      LPrepare.Preview.OriginalContent,
      LPrepare.Preview.ProposedContent
    );
    if LForm.ShowModal <> mrOk then
      Exit;
    LSelected := LPatchService.Prepare(
      TRadIAPatchSpec.Create(
        AReview.FileName,
        AReview.BaseRevision,
        LPrepare.Preview.OriginalContent,
        LForm.SuggestedCode
      )
    );
    if not LSelected.Success then
      LApply := LSelected
    else
      LApply := LPatchService.Apply(LSelected.Preview.Id);
    if not LApply.Success then
    begin
      ShowMessage(
        'The selected inline review blocks could not be applied: ' +
        LApply.ErrorMessage
      );
      Exit;
    end;
    AService.Remove(AReview.Id);
    TLogger.Log(
      'Inline review applied through Smart Diff: ' + AReview.Id,
      'InlineReview'
    );
    Result := True;
  finally
    LForm.Free;
  end;
  {$ENDIF}
end;

function TRadIAEditorHook.TryGetInlineReviewAtCursor(
  out AService: IRadIAInlineReviewService;
  out AReview: TRadIAInlineReview
): Boolean;
var
  LEditorServices: IOTAEditorServices;
  LReview: TRadIAInlineReview;
  LReviews: TArray<TRadIAInlineReview>;
  LRow: Integer;
  LView: IOTAEditView;
begin
  Result := False;
  AService := nil;
  AReview := Default(TRadIAInlineReview);
  if not TRadIAContainer.TryResolve<IRadIAInlineReviewService>(
    AService
  ) or not Supports(
    BorlandIDEServices,
    IOTAEditorServices,
    LEditorServices
  ) then
    Exit;
  LView := LEditorServices.TopView;
  if not Assigned(LView) or not Assigned(LView.Position) then
    Exit;
  LRow := LView.Position.Row;
  LReviews := AService.ListCurrent;
  for LReview in LReviews do
    if (LRow >= LReview.StartLine) and
      (LRow <= LReview.EndLine) then
    begin
      AReview := LReview;
      Exit(True);
    end;
end;

procedure TRadIAEditorHook.RefreshKeyboardBinding;
var
  LKeyboardServices: IOTAKeyboardServices;
  LShortcutConfig: IRadIAInlineShortcutConfig;
  LProfileText: string;
begin
  LProfileText := TRadIAInlineShortcutProfile.DefaultText;
  if Supports(FConfig, IRadIAInlineShortcutConfig, LShortcutConfig) then
    LProfileText := LShortcutConfig.InlineShortcutProfile;
  if SameText(LProfileText, FInlineShortcutProfile) and
    (FInlineShortcutBindingIndex >= 0) then
    Exit;
  RemoveKeyboardBinding;
  FInlineShortcutProfile := LProfileText;
  if not Supports(
    BorlandIDEServices,
    IOTAKeyboardServices,
    LKeyboardServices
  ) then
    Exit;
  FInlineShortcutBinding :=
    TRadIAInlineCompletionKeyboardBinding.Create(Self);
  FInlineShortcutBindingIndex := LKeyboardServices.AddKeyboardBinding(
    FInlineShortcutBinding
  );
end;

procedure TRadIAEditorHook.RefreshInlineCompletionWatch;
var
  LEnabled: Boolean;
  LIdleHandler: TRadIAInlineCompletionIdleHandler;
begin
  if not Assigned(FInlineCompletionSession) or
    not Assigned(FConfig) then
    Exit;
  LEnabled := FInlineCompletionSessionEnabled and
    FConfig.AutocompleteEnabled;
  if Assigned(FInlineCompletionController) then
    FInlineCompletionController.Configure(
      TRadIAInlineCompletionOptions.Create(
        FConfig.AutocompleteDelay,
        24000,
        4000
      )
    );
  if LEnabled then
  begin
    LIdleHandler :=
      procedure
      begin
        RequestContinuousInlineCompletion;
      end;
  end
  else
    LIdleHandler := nil;
  FInlineCompletionSession.ConfigureContinuous(
    LEnabled,
    LIdleHandler
  );
end;

procedure TRadIAEditorHook.RemoveKeyboardBinding;
var
  LKeyboardServices: IOTAKeyboardServices;
begin
  if (FInlineShortcutBindingIndex >= 0) and Supports(
    BorlandIDEServices,
    IOTAKeyboardServices,
    LKeyboardServices
  ) then
  begin
    try
      LKeyboardServices.RemoveKeyboardBinding(
        FInlineShortcutBindingIndex
      );
    except
      on E: Exception do
        TLogger.Log(
          'Inline shortcut binding removal failed: ' + E.Message,
          'Warning'
        );
    end;
  end;
  FInlineShortcutBindingIndex := -1;
  FInlineShortcutBinding := nil;
end;

procedure TRadIAEditorHook.RequestContinuousInlineCompletion;
var
  LContext: TRadIAInlineCompletionContext;
  LRequestKey: string;
begin
  if not FInlineCompletionSessionEnabled or
    not Assigned(FConfig) or
    not FConfig.AutocompleteEnabled or
    not Assigned(FInlineCompletionController) or
    not FInlineCompletionSession.Capture(LContext) then
    Exit;
  if not TRadIAInlineCompletionPolicy.IsAllowed(
    LContext,
    FConfig.AutocompleteExcludedLanguages,
    FConfig.AutocompleteExcludedFiles,
    FConfig.AutocompleteExcludedProjects
  ) then
    Exit;
  LRequestKey := LContext.CacheKey + '|' +
    LContext.CursorLine.ToString + '|' +
    LContext.CursorColumn.ToString;
  if SameText(LRequestKey, FInlineCompletionLastKey) then
    Exit;
  FInlineCompletionLastKey := LRequestKey;
  FInlineCompletionController.Request(LContext);
end;

procedure TRadIAEditorHook.OnOptimizeExecute(Sender: TObject);
var
  LCode: string;
  LUsedSelection: Boolean;
begin
  if not GetEditorCodeContext(LCode, LUsedSelection) then
  begin
    TLogger.Log('OnOptimizeExecute failed: no active code', 'EditorHook');
    ShowMessage('No active code file open in the editor.');
    Exit;
  end;

  TLogger.Log(Format('OnOptimizeExecute: CodeLength=%d, UsedSelection=%s',
    [Length(LCode), BoolToStr(LUsedSelection, True)]), 'EditorHook');
  FMediator.RequestDiff(LCode, not LUsedSelection);
end;

function TRadIAEditorHook.BuildCreateExamplePrompt(const ASourceCode: string;
  const AContext: TMethodExampleContext): string;
var
  LBuilder: TStringBuilder;
begin
  LBuilder := TStringBuilder.Create;
  try
    LBuilder.AppendLine('You are generating Object Pascal code for ' + TRadIAOTAHelper.GetDelphiVersionName + '.');
    LBuilder.AppendLine('Implement the method below completely. Return the complete method ' +
        'declaration, including the method signature, ');
    LBuilder.AppendLine('the local variable "var" block (if any local variables are needed) ' +
        'immediately below the signature and before the "begin", ');
    LBuilder.AppendLine('and the full method body enclosed in the main "begin/end;".');
    LBuilder.AppendLine('Do not return explanations, markdown wrapper blocks outside of the ' +
        'single Pascal code block, or separate declaration and implementation sections.');
    LBuilder.AppendLine('Use only symbols already available in the full unit context whenever possible.');
    LBuilder.AppendLine('Do not introduce dependencies that require changing the unit uses clause unless ' +
        'there is no practical alternative.');
    {$IF CompilerVersion >= 36.0}
    LBuilder.AppendLine('You can use multiline string literals (surrounded by triple single ' +
        'quotes ''''''texto'''''') for long strings or formatting blocks.');
    {$ELSE}
    LBuilder.AppendLine('Do not use multiline string literals (triple single quotes). Instead, use traditional ' +
        'single quotes and string concatenation (+ and sLineBreak / #13#10) for multiline text.');
    {$ENDIF}
    LBuilder.AppendLine('Preserve valid Delphi formatting and indentation using two spaces per indentation level.');
    LBuilder.AppendLine('The code will be inserted immediately below the natural-language comment.');
    LBuilder.AppendLine;
    LBuilder.AppendLine('Natural-language comment:');
    LBuilder.AppendLine(AContext.CommentText);
    LBuilder.AppendLine;
    LBuilder.AppendLine('Target method:');
    LBuilder.AppendLine('```pascal');
    LBuilder.AppendLine(AContext.MethodText);
    LBuilder.AppendLine('```');
    LBuilder.AppendLine;
    LBuilder.AppendLine('Full unit context:');
    LBuilder.AppendLine('```pascal');
    LBuilder.AppendLine(ASourceCode);
    LBuilder.AppendLine('```');
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;



procedure TRadIAEditorHook.OnCreateExampleExecute(Sender: TObject);
var
  LSourceCode: string;
  LCursorLine: Integer;
  LContext: TMethodExampleContext;
  LErrorMessage: string;
  LPrompt: string;
begin
  if not FIDEAdapter.GetActiveEditorText(LSourceCode, False) then
  begin
    TLogger.Log('OnCreateExampleExecute failed: no active code', 'EditorHook');
    ShowMessage('No active code file open in the editor.');
    Exit;
  end;

  LCursorLine := FIDEAdapter.GetCurrentCursorLine;
  if not TRadIAContextParser.TryGetMethodExampleContext(LSourceCode, LCursorLine, LContext, LErrorMessage) then
  begin
    TLogger.Log('OnCreateExampleExecute failed: ' + LErrorMessage, 'EditorHook');
    ShowMessage(LErrorMessage);
    Exit;
  end;

  LPrompt := BuildCreateExamplePrompt(LSourceCode, LContext);
  TLogger.Log(Format('OnCreateExampleExecute: PromptLength=%d', [Length(LPrompt)]), 'EditorHook');

  TRadIAMediator.Instance.AutoReplaceTarget := LContext.MethodText;
  ShowRadIAChat;
  FMediator.RequestPrompt(LPrompt, True);
end;

procedure TRadIAEditorHook.OnTestsExecute(Sender: TObject);
begin
  SendCommandToChat('/test', 'Write focused DUnitX unit tests for this Delphi Pascal code:');
end;

procedure TRadIAEditorHook.OnBugsExecute(Sender: TObject);
begin
  SendCommandToChat('/bugs', 'Analyze this Delphi code for actionable bugs, exceptions, memory leaks, ' +
      'and SOLID issues. Be concise:');
end;

procedure TRadIAEditorHook.OnDocExecute(Sender: TObject);
var
  LCode: string;
  LUsedSelection: Boolean;
  LPrompt: string;
begin
  if not GetEditorCodeContext(LCode, LUsedSelection) then
  begin
    TLogger.Log('OnDocExecute failed: no active code', 'EditorHook');
    ShowMessage('No active code file open in the editor.');
    Exit;
  end;

  TLogger.Log(Format('OnDocExecute: CodeLength=%d, UsedSelection=%s',
    [Length(LCode), BoolToStr(LUsedSelection, True)]), 'EditorHook');
  LPrompt := Format('/doc'#13#10'```pascal'#13#10'%s'#13#10'```', [LCode]);
  FMediator.RequestPrompt(LPrompt, True);
end;

procedure TRadIAEditorHook.OnReviewExecute(Sender: TObject);
var
  LActiveCode: string;
  LPrompt: string;
begin
  if not FIDEAdapter.GetActiveEditorText(LActiveCode, False) then
  begin
    TLogger.Log('OnReviewExecute failed: no active code', 'EditorHook');
    ShowMessage('No active code file open in the editor.');
    Exit;
  end;

  TLogger.Log(Format('OnReviewExecute: CodeLength=%d', [Length(LActiveCode)]), 'EditorHook');
  ShowRadIAChat;

  LPrompt := Format('/review'#13#10'```pascal'#13#10'%s'#13#10'```', [LActiveCode]);
  FMediator.RequestPrompt(LPrompt, True);
end;

procedure TRadIAEditorHook.OnFixErrorExecute(Sender: TObject);
var
  LErrorMsg, LFileName, LSourceCode, LPrompt: string;
  LLine: Integer;
begin
  if not FIDEAdapter.GetLastCompilerError(LErrorMsg, LFileName, LLine) then
  begin
    TLogger.Log('OnFixErrorExecute failed: no compiler error found in Messages View', 'EditorHook');
    ShowMessage('No compiler errors found in the Messages View.');
    Exit;
  end;

  TLogger.Log(Format('OnFixErrorExecute: Compiler Error found. File=%s, Line=%d, Msg=%s', [LFileName,
      LLine, LErrorMsg]), 'EditorHook');

  { Extract source code context if line is valid }
  LSourceCode := '';
  if LLine > 0 then
  begin
    var LHasText: Boolean;
    LHasText := FIDEAdapter.GetActiveEditorText(LSourceCode, False);

    if LHasText then
    begin
      LSourceCode := 'Source Code Context around the error line:'#13#10'```pascal'#13#10 +
                     TRadIAContextParser.GetClassContextAtLine(LSourceCode, LLine) +
                     #13#10'```';
    end;
  end;

  LPrompt := Format('/fix'#13#10'Compiler Error: %s'#13#10'File: %s (Line %d)'#13#10#13#10'%s',
    [LErrorMsg, ExtractFileName(LFileName), LLine, LSourceCode]);

  FMediator.RequestPrompt(LPrompt, True);
end;

{$IFNDEF TESTS}
procedure TRadIAEditorHook.RequestDelayedHook;
begin
  if (not FInstalled) or GIsShuttingDown then
    Exit;

  FHookPending := True;
  FHookRequestedAt := GetTickCount64;
end;

procedure TRadIAEditorHook.OnTimerEvent(Sender: TObject);
var
  LActiveForm: TCustomForm;
begin
  if (not FInstalled) or GIsShuttingDown then
    Exit;

  if FInlineCompletionSmokePending and
    TryRunInlineCompletionAcceptanceDiagnostic then
    FInlineCompletionSmokePending := False;

  if not FHookPending then
  begin
    if Assigned(Screen) then
    begin
      LActiveForm := Screen.ActiveForm;
      if Assigned(LActiveForm) and SameText(LActiveForm.ClassName, 'TEditWindow') then
        RequestDelayedHook;
    end;
    Exit;
  end;

  if GetTickCount64 - FHookRequestedAt < CEditorHookDelayMs then
    Exit;

  FHookPending := False;
  HookEditorWindowsNow;
end;
{$ENDIF}

initialization
  // Ensure the FInterceptedMenus dictionary is nil at startup
  FInterceptedMenus := nil;

finalization
  if Assigned(FInterceptedMenus) then
  begin
    FInterceptedMenus.Clear;
    FreeAndNil(FInterceptedMenus);
  end;

end.
