unit RadIA.OTA.DockableForm;

interface

procedure ShowRadIAChat;
procedure ShowRadIAChatCommand(const ACommand: string);
procedure ShowRadIATerminal;
procedure RegisterDockableForm;
procedure PrepareDockableFormsForShutdown;
procedure RestoreDockableFormVisibility;
procedure UnregisterDockableForm;

implementation

uses
  System.Classes,
  System.IniFiles,
  System.SysUtils,
  System.Win.Registry,
  Winapi.Messages,
  Winapi.Windows,
  DesignIntf,
  Vcl.ActnList,
  Vcl.ComCtrls,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.ImgList,
  Vcl.Menus,
  ToolsAPI,
  RadIA.Core.Logger,
  RadIA.Core.Types,
  RadIA.Core.Version,
  RadIA.UI.ChatFrame,
  RadIA.UI.TerminalFrame;

type
  TRadIACustomDockableForm = class;
  TRadIAAccessibleCustomForm = class(TCustomForm);

  TRadIADockableFormObserver = class(TComponent)
  private
    FHost: TRadIACustomDockableForm;
    FTimer: TTimer;
    procedure TimerEvent(Sender: TObject);
  protected
    procedure Notification(AComponent: TComponent; Operation: TOperation); override;
  public
    constructor Create(AHost: TRadIACustomDockableForm); reintroduce;
  end;

  TRadIACustomDockableForm = class(TInterfacedObject, INTACustomDockableForm)
  private
    FForm: TCustomForm;
    FFrame: TCustomFrame;
    FObserver: TRadIADockableFormObserver;
    FCaption: string;
    FIdentifier: string;
    FFrameClass: TCustomFrameClass;
    FDefaultWidth: Integer;
    FDefaultHeight: Integer;
    FHasSavedWindowState: Boolean;
    FObservedBounds: TRect;
    FObservedStateInitialized: Boolean;
    FObservedVisible: Boolean;
    FPreviousWindowProc: TWndMethod;
    procedure ApplyIDETheme;
    procedure ApplyWindowIdentity;
    procedure AttachNativeForm(AForm: TCustomForm);
    procedure DetachNativeForm;
    procedure EnsureFrameContent;
    procedure FormWindowProc(var AMessage: TMessage);
    procedure FormRemoved;
    procedure LoadPersistedBounds;
    procedure PersistCurrentState;
    procedure SavePersistedBounds;
    procedure SaveVisibility(const AVisible: Boolean);
    procedure SynchronizeCurrentState;
  public
    constructor Create(
      const ACaption: string;
      const AIdentifier: string;
      const AFrameClass: TCustomFrameClass;
      const ADefaultWidth: Integer;
      const ADefaultHeight: Integer
    );
    destructor Destroy; override;
    function GetCaption: string;
    function GetFrameClass: TCustomFrameClass;
    procedure FrameCreated(AFrame: TCustomFrame);
    function GetIdentifier: string;
    function GetMenuActionList: TCustomActionList;
    function GetMenuImageList: TCustomImageList;
    procedure CustomizePopupMenu(APopupMenu: TPopupMenu);
    function GetToolbarActionList: TCustomActionList;
    function GetToolbarImageList: TCustomImageList;
    procedure CustomizeToolBar(AToolBar: TToolBar);
    procedure LoadWindowState(ADesktop: TCustomIniFile; const ASection: string);
    procedure SaveWindowState(
      ADesktop: TCustomIniFile;
      const ASection: string;
      AIsProject: Boolean
    );
    function GetEditState: TEditState;
    function EditAction(AAction: TEditAction): Boolean;
    procedure ReleaseForm;
    procedure Show;
  end;

var
  GRadIADockableForm: INTACustomDockableForm;
  GRadIADockableFormHost: TRadIACustomDockableForm = nil;
  GRadIADockableFormRegistered: Boolean = False;
  GRadIATerminalDockableForm: INTACustomDockableForm;
  GRadIATerminalDockableFormHost: TRadIACustomDockableForm = nil;
  GRadIATerminalDockableFormRegistered: Boolean = False;

procedure ShowRadIAChat;
begin
  RegisterDockableForm;
  if not Assigned(GRadIADockableFormHost) then
    Exit;

  GRadIADockableFormHost.Show;
end;

procedure ShowRadIAChatCommand(const ACommand: string);
begin
  ShowRadIAChat;
  if Assigned(GRadIADockableFormHost) and
    (GRadIADockableFormHost.FFrame is TRadIAFrameAIChat) then
    TRadIAFrameAIChat(GRadIADockableFormHost.FFrame).ExecutePrompt(
      ACommand
    );
end;

procedure ShowRadIATerminal;
begin
  RegisterDockableForm;
  if Assigned(GRadIATerminalDockableFormHost) then
    GRadIATerminalDockableFormHost.Show;
end;

procedure RegisterDockableForm;
var
  LServices: INTAServices;
begin
  if GRadIADockableFormRegistered then
    Exit;
  if not Supports(BorlandIDEServices, INTAServices, LServices) then
  begin
    TLogger.Log(
      'INTAServices is unavailable; native dock registration was skipped.',
      'DockableForm'
    );
    Exit;
  end;

  if not Assigned(GRadIADockableFormHost) then
  begin
    GRadIADockableFormHost := TRadIACustomDockableForm.Create(
      'Rad IA Chat',
      'RadIADockableForm',
      TRadIAFrameAIChat,
      990,
      650
    );
    GRadIADockableForm := GRadIADockableFormHost;
  end;
  LServices.RegisterDockableForm(GRadIADockableForm);
  GRadIADockableFormRegistered := True;

  if not Assigned(GRadIATerminalDockableFormHost) then
  begin
    GRadIATerminalDockableFormHost := TRadIACustomDockableForm.Create(
      'Rad IA Terminal',
      'RadIATerminalDockableForm',
      TRadIATerminalTabsFrame,
      900,
      520
    );
    GRadIATerminalDockableForm := GRadIATerminalDockableFormHost;
  end;
  LServices.RegisterDockableForm(GRadIATerminalDockableForm);
  GRadIATerminalDockableFormRegistered := True;
  if Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_TERMINAL')
  ) <> '' then
    GRadIATerminalDockableFormHost.Show;
  if Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_WEBVIEW_LIFECYCLE')
  ) <> '' then
    GRadIADockableFormHost.Show
  else if Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_NATURAL_VCL')
  ) <> '' then
    GRadIADockableFormHost.Show
  else if Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_SESSION_ISOLATION')
  ) <> '' then
    GRadIADockableFormHost.Show
  else if Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_CONVERSATION')
  ) <> '' then
    GRadIADockableFormHost.Show
  else if Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_CANCELLATION')
  ) <> '' then
    GRadIADockableFormHost.Show
  else if Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_PROVIDER_RECOVERY')
  ) <> '' then
    GRadIADockableFormHost.Show
  else if Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_AGENT_BUDGET')
  ) <> '' then
    GRadIADockableFormHost.Show;
  TLogger.Log('Native chat and terminal docks registered.', 'DockableForm');
end;

procedure UnregisterDockableForm;
var
  LServices: INTAServices;
begin
  if GIsShuttingDown then
  begin
    GRadIADockableForm := nil;
    GRadIADockableFormHost := nil;
    GRadIADockableFormRegistered := False;
    GRadIATerminalDockableForm := nil;
    GRadIATerminalDockableFormHost := nil;
    GRadIATerminalDockableFormRegistered := False;
    Exit;
  end;

  if GRadIADockableFormRegistered and
    Supports(BorlandIDEServices, INTAServices, LServices) then
    LServices.UnregisterDockableForm(GRadIADockableForm);

  if Assigned(GRadIADockableFormHost) then
    GRadIADockableFormHost.ReleaseForm;
  if GRadIATerminalDockableFormRegistered and
    Supports(BorlandIDEServices, INTAServices, LServices) then
    LServices.UnregisterDockableForm(GRadIATerminalDockableForm);
  if Assigned(GRadIATerminalDockableFormHost) then
    GRadIATerminalDockableFormHost.ReleaseForm;
  GRadIADockableForm := nil;
  GRadIADockableFormHost := nil;
  GRadIADockableFormRegistered := False;
  GRadIATerminalDockableForm := nil;
  GRadIATerminalDockableFormHost := nil;
  GRadIATerminalDockableFormRegistered := False;
end;

{ TRadIADockableFormObserver }

constructor TRadIADockableFormObserver.Create(AHost: TRadIACustomDockableForm);
begin
  inherited Create(nil);
  FHost := AHost;
  FTimer := TTimer.Create(Self);
  FTimer.Interval := 500;
  FTimer.OnTimer := TimerEvent;
  FTimer.Enabled := True;
end;

procedure TRadIADockableFormObserver.Notification(
  AComponent: TComponent;
  Operation: TOperation
);
begin
  inherited Notification(AComponent, Operation);
  if (Operation = opRemove) and Assigned(FHost) and
    (AComponent = FHost.FForm) then
    FHost.FormRemoved;
end;

procedure TRadIADockableFormObserver.TimerEvent(Sender: TObject);
begin
  if Assigned(FHost) and not GIsShuttingDown then
    FHost.SynchronizeCurrentState;
end;

{ TRadIACustomDockableForm }

constructor TRadIACustomDockableForm.Create(
  const ACaption: string;
  const AIdentifier: string;
  const AFrameClass: TCustomFrameClass;
  const ADefaultWidth: Integer;
  const ADefaultHeight: Integer
);
begin
  inherited Create;
  FCaption := ACaption;
  FIdentifier := AIdentifier;
  FFrameClass := AFrameClass;
  FDefaultWidth := ADefaultWidth;
  FDefaultHeight := ADefaultHeight;
  FObserver := TRadIADockableFormObserver.Create(Self);
end;

destructor TRadIACustomDockableForm.Destroy;
begin
  DetachNativeForm;
  FObserver.Free;
  inherited Destroy;
end;

procedure PrepareDockableFormsForShutdown;
var
  LPreviousShutdownState: Boolean;
begin
  LPreviousShutdownState := GIsShuttingDown;
  GIsShuttingDown := True;
  try
    if Assigned(GRadIADockableFormHost) then
    begin
      GRadIADockableFormHost.PersistCurrentState;
      GRadIADockableFormHost.ReleaseForm;
    end;
    if Assigned(GRadIATerminalDockableFormHost) then
    begin
      GRadIATerminalDockableFormHost.PersistCurrentState;
      GRadIATerminalDockableFormHost.ReleaseForm;
    end;
  finally
    GIsShuttingDown := LPreviousShutdownState;
  end;
end;

procedure RestoreDockableFormVisibility;
var
  LRegistry: TRegistry;
  LServices: IOTAServices;
  LVisible: Boolean;
begin
  LVisible := False;
  if not Supports(BorlandIDEServices, IOTAServices, LServices) then
    Exit;
  LRegistry := TRegistry.Create;
  try
    LRegistry.RootKey := HKEY_CURRENT_USER;
    if LRegistry.OpenKeyReadOnly(
      LServices.GetBaseRegistryKey + '\RadIA'
    ) and LRegistry.ValueExists('WindowVisible') then
      LVisible := LRegistry.ReadBool('WindowVisible');
  finally
    LRegistry.Free;
  end;
  if Assigned(GRadIADockableFormHost) and LVisible then
    GRadIADockableFormHost.Show;
end;

procedure TRadIACustomDockableForm.DetachNativeForm;
begin
  if not Assigned(FForm) then
    Exit;
  TRadIAAccessibleCustomForm(FForm).WindowProc := FPreviousWindowProc;
  FForm.RemoveFreeNotification(FObserver);
  FForm := nil;
  FFrame := nil;
  FPreviousWindowProc := nil;
end;

procedure TRadIACustomDockableForm.ApplyIDETheme;
var
  LThemingServices: IOTAIDEThemingServices;
begin
  if not Assigned(FFrame) then
    Exit;
  if not Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
    Exit;

  if LThemingServices.IDEThemingEnabled then
  begin
    if Assigned(FForm) then
      LThemingServices.ApplyTheme(FForm);
    LThemingServices.ApplyTheme(FFrame);
    if FFrame is TRadIAFrameAIChat then
      TRadIAFrameAIChat(FFrame).ApplyCurrentTheme
    else if FFrame is TRadIATerminalTabsFrame then
      TRadIATerminalTabsFrame(FFrame).ApplyCurrentTheme;
  end;
end;

procedure TRadIACustomDockableForm.ApplyWindowIdentity;
begin
  if not Assigned(FForm) or not FForm.HandleAllocated then
    Exit;
  SetProp(
    FForm.Handle,
    PChar(FIdentifier),
    THandle(1)
  );
end;

procedure TRadIACustomDockableForm.EnsureFrameContent;
begin
  if FFrame is TRadIAFrameAIChat then
    TRadIAFrameAIChat(FFrame).EnsureVisibleContent
  else if FFrame is TRadIATerminalTabsFrame then
    TRadIATerminalTabsFrame(FFrame).EnsureVisibleContent;
end;

procedure TRadIACustomDockableForm.CustomizePopupMenu(APopupMenu: TPopupMenu);
begin
  // The IDE adds its standard docking commands to the popup menu.
end;

procedure TRadIACustomDockableForm.CustomizeToolBar(AToolBar: TToolBar);
begin
  // The RadIA frame owns its toolbar, so the native host needs no extra toolbar.
end;

function TRadIACustomDockableForm.EditAction(AAction: TEditAction): Boolean;
begin
  Result := False;
end;

procedure TRadIACustomDockableForm.FormRemoved;
begin
  if Assigned(FForm) and not GIsShuttingDown then
  begin
    SavePersistedBounds;
    SaveVisibility(False);
  end;
  FForm := nil;
  FFrame := nil;
  FPreviousWindowProc := nil;
end;

procedure TRadIACustomDockableForm.SynchronizeCurrentState;
var
  LBounds: TRect;
  LVisible: Boolean;
begin
  if not Assigned(FForm) then
    Exit;
  LBounds := FForm.BoundsRect;
  LVisible := FForm.Visible;
  if not FObservedStateInitialized or (LVisible <> FObservedVisible) then
    SaveVisibility(LVisible);
  if not FObservedStateInitialized or not EqualRect(LBounds, FObservedBounds) then
    SavePersistedBounds;
  FObservedBounds := LBounds;
  FObservedVisible := LVisible;
  FObservedStateInitialized := True;
end;

procedure TRadIACustomDockableForm.FormWindowProc(var AMessage: TMessage);
begin
  if Assigned(FPreviousWindowProc) then
    FPreviousWindowProc(AMessage);
  if not Assigned(FForm) then
    Exit;
  if AMessage.Msg = CM_SHOWINGCHANGED then
    SaveVisibility(FForm.Visible)
  else if AMessage.Msg = WM_EXITSIZEMOVE then
    SavePersistedBounds;
end;

procedure TRadIACustomDockableForm.FrameCreated(AFrame: TCustomFrame);
begin
  FFrame := AFrame;
  AttachNativeForm(GetParentForm(AFrame));
  ApplyIDETheme;
end;

procedure TRadIACustomDockableForm.AttachNativeForm(AForm: TCustomForm);
begin
  if not Assigned(AForm) or (FForm = AForm) then
    Exit;

  FForm := AForm;
  FForm.FreeNotification(FObserver);
  FForm.Caption := GetCaption;
  FPreviousWindowProc := TRadIAAccessibleCustomForm(FForm).WindowProc;
  TRadIAAccessibleCustomForm(FForm).WindowProc := FormWindowProc;
  ApplyWindowIdentity;
end;

function TRadIACustomDockableForm.GetCaption: string;
begin
  Result := RadIAVersionedCaption(FCaption);
end;

function TRadIACustomDockableForm.GetEditState: TEditState;
begin
  Result := [];
end;

function TRadIACustomDockableForm.GetFrameClass: TCustomFrameClass;
begin
  Result := FFrameClass;
end;

function TRadIACustomDockableForm.GetIdentifier: string;
begin
  Result := FIdentifier;
end;

function TRadIACustomDockableForm.GetMenuActionList: TCustomActionList;
begin
  Result := nil;
end;

function TRadIACustomDockableForm.GetMenuImageList: TCustomImageList;
begin
  Result := nil;
end;

function TRadIACustomDockableForm.GetToolbarActionList: TCustomActionList;
begin
  Result := nil;
end;

function TRadIACustomDockableForm.GetToolbarImageList: TCustomImageList;
begin
  Result := nil;
end;

procedure TRadIACustomDockableForm.LoadWindowState(
  ADesktop: TCustomIniFile;
  const ASection: string
);
begin
  FHasSavedWindowState := ADesktop.SectionExists(ASection);
  TLogger.Log(
    'Desktop state loaded for ' + FIdentifier + ': section=' + ASection +
    ', source=' + ADesktop.ClassName +
    ', exists=' + BoolToStr(FHasSavedWindowState, True) + '.',
    'DockableForm'
  );
end;

procedure TRadIACustomDockableForm.LoadPersistedBounds;
var
  LRegistry: TRegistry;
  LServices: IOTAServices;
begin
  if FIdentifier <> 'RadIADockableForm' then
    Exit;
  if not Supports(BorlandIDEServices, IOTAServices, LServices) then
    Exit;
  LRegistry := TRegistry.Create;
  try
    LRegistry.RootKey := HKEY_CURRENT_USER;
    if not LRegistry.OpenKeyReadOnly(LServices.GetBaseRegistryKey + '\RadIA') then
      Exit;
    if LRegistry.ValueExists('WindowWidth') then
      FForm.Width := LRegistry.ReadInteger('WindowWidth');
    if LRegistry.ValueExists('WindowHeight') then
      FForm.Height := LRegistry.ReadInteger('WindowHeight');
    if LRegistry.ValueExists('WindowLeft') then
      FForm.Left := LRegistry.ReadInteger('WindowLeft');
    if LRegistry.ValueExists('WindowTop') then
      FForm.Top := LRegistry.ReadInteger('WindowTop');
  finally
    LRegistry.Free;
  end;
end;

procedure TRadIACustomDockableForm.PersistCurrentState;
begin
  if not Assigned(FForm) then
    Exit;
  SaveVisibility(FForm.Visible);
  SavePersistedBounds;
end;

procedure TRadIACustomDockableForm.SavePersistedBounds;
var
  LRegistry: TRegistry;
  LServices: IOTAServices;
begin
  if (FIdentifier <> 'RadIADockableForm') or not Assigned(FForm) then
    Exit;
  if not TRadIAAccessibleCustomForm(FForm).Floating then
    Exit;
  if not Supports(BorlandIDEServices, IOTAServices, LServices) then
    Exit;
  LRegistry := TRegistry.Create;
  try
    LRegistry.RootKey := HKEY_CURRENT_USER;
    if LRegistry.OpenKey(LServices.GetBaseRegistryKey + '\RadIA', True) then
    begin
      LRegistry.WriteInteger('WindowWidth', FForm.Width);
      LRegistry.WriteInteger('WindowHeight', FForm.Height);
      LRegistry.WriteInteger('WindowLeft', FForm.Left);
      LRegistry.WriteInteger('WindowTop', FForm.Top);
    end;
  finally
    LRegistry.Free;
  end;
end;

procedure TRadIACustomDockableForm.SaveVisibility(const AVisible: Boolean);
var
  LRegistry: TRegistry;
  LServices: IOTAServices;
begin
  if FIdentifier <> 'RadIADockableForm' then
    Exit;
  if not Supports(BorlandIDEServices, IOTAServices, LServices) then
    Exit;
  LRegistry := TRegistry.Create;
  try
    LRegistry.RootKey := HKEY_CURRENT_USER;
    if LRegistry.OpenKey(LServices.GetBaseRegistryKey + '\RadIA', True) then
      LRegistry.WriteBool('WindowVisible', AVisible);
  finally
    LRegistry.Free;
  end;
end;

procedure TRadIACustomDockableForm.ReleaseForm;
begin
  FForm.Free;
  FForm := nil;
  FFrame := nil;
end;

procedure TRadIACustomDockableForm.SaveWindowState(
  ADesktop: TCustomIniFile;
  const ASection: string;
  AIsProject: Boolean
);
begin
  TLogger.Log(
    'Desktop state saved for ' + FIdentifier + ': section=' + ASection +
    ', source=' + ADesktop.ClassName +
    ', project=' + BoolToStr(AIsProject, True) + '.',
    'DockableForm'
  );
end;

procedure TRadIACustomDockableForm.Show;
var
  LServices: INTAServices;
begin
  TLogger.Log('Show requested for ' + FIdentifier + '.', 'DockableForm');
  if not Supports(BorlandIDEServices, INTAServices, LServices) then
  begin
    TLogger.Log(
      'INTAServices is unavailable while showing ' + FIdentifier + '.',
      'DockableForm'
    );
    Exit;
  end;

  if not Assigned(FForm) then
  begin
    FForm := LServices.CreateDockableForm(Self);
    if not Assigned(FForm) then
    begin
      TLogger.Log(
        'The IDE returned no native form for ' + FIdentifier + '.',
        'DockableForm'
      );
      Exit;
    end;
    if not FHasSavedWindowState then
    begin
      FForm.Width := FDefaultWidth;
      FForm.Height := FDefaultHeight;
      LoadPersistedBounds;
    end;
    TLogger.Log(
      'Native form created for ' + FIdentifier + ': ' + FForm.ClassName + '.',
      'DockableForm'
    );
  end;

  ApplyIDETheme;
  FForm.Show;
  ApplyWindowIdentity;
  FForm.BringToFront;
  EnsureFrameContent;
  TLogger.Log('Native form shown for ' + FIdentifier + '.', 'DockableForm');
end;

end.
