unit RadIA.OTA.DockableForm;

interface

procedure ShowRadIAChat;
procedure ShowRadIATerminal;
procedure RegisterDockableForm;
procedure UnregisterDockableForm;

implementation

uses
  System.Classes,
  System.IniFiles,
  System.SysUtils,
  DesignIntf,
  Vcl.ActnList,
  Vcl.ComCtrls,
  Vcl.Forms,
  Vcl.ImgList,
  Vcl.Menus,
  ToolsAPI,
  RadIA.Core.Types,
  RadIA.UI.ChatFrame,
  RadIA.UI.TerminalFrame;

type
  TRadIACustomDockableForm = class;

  TRadIADockableFormObserver = class(TComponent)
  private
    FHost: TRadIACustomDockableForm;
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
    procedure ApplyIDETheme;
    procedure EnsureFrameContent;
    procedure FormRemoved;
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

procedure ShowRadIATerminal;
begin
  RegisterDockableForm;
  if Assigned(GRadIATerminalDockableFormHost) then
    GRadIATerminalDockableFormHost.Show;
end;

procedure RegisterDockableForm;
var
  LServices: INTAServices270;
begin
  if GRadIADockableFormRegistered then
    Exit;
  if not Supports(BorlandIDEServices, INTAServices270, LServices) then
    Exit;

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
end;

procedure UnregisterDockableForm;
var
  LServices: INTAServices270;
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
    Supports(BorlandIDEServices, INTAServices270, LServices) then
    LServices.UnregisterDockableForm(GRadIADockableForm);

  if Assigned(GRadIADockableFormHost) then
    GRadIADockableFormHost.ReleaseForm;
  if GRadIATerminalDockableFormRegistered and
    Supports(BorlandIDEServices, INTAServices270, LServices) then
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
  FObserver.Free;
  inherited Destroy;
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
  FForm := nil;
  FFrame := nil;
end;

procedure TRadIACustomDockableForm.FrameCreated(AFrame: TCustomFrame);
begin
  FFrame := AFrame;
  ApplyIDETheme;
  EnsureFrameContent;
end;

function TRadIACustomDockableForm.GetCaption: string;
begin
  Result := FCaption;
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
  // The native IDE host restores docking, size, and visibility.
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
  // The native IDE host persists its standard docking state.
end;

procedure TRadIACustomDockableForm.Show;
var
  LServices: INTAServices270;
begin
  if not Supports(BorlandIDEServices, INTAServices270, LServices) then
    Exit;

  if not Assigned(FForm) then
  begin
    FForm := LServices.CreateDockableForm(Self);
    FForm.FreeNotification(FObserver);
    FForm.Width := FDefaultWidth;
    FForm.Height := FDefaultHeight;
  end;

  ApplyIDETheme;
  FForm.Show;
  FForm.BringToFront;
  EnsureFrameContent;
end;

end.
