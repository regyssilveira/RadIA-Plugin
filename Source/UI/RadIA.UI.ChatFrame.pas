unit RadIA.UI.ChatFrame;

interface

uses  Winapi.Messages, System.SysUtils, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Edge, Vcl.Menus, Vcl.Buttons, RadIA.Core.Sessions, RadIA.UI.Resources,
  RadIA.UI.ChatPresenter;

type
  TRadIAEdgeBrowser = class(TEdgeBrowser)
  public
    procedure RefreshControllerBounds;
  end;

  TRadIAFrameAIChat = class(TFrame, IRadIAChatView)
    pnlToolbar: TPanel;
    lblTitle: TLabel;
    btnToggleSessions: TSpeedButton;
    cbProvider: TComboBox;
    cbModel: TComboBox;
    btnSettings: TSpeedButton;
    btnClear: TSpeedButton;
    btnExport: TSpeedButton;
    btnTemplates: TSpeedButton;
    btnTerminal: TSpeedButton;
    SaveDialog: TSaveDialog;
    pnlInput: TPanel;
    shpInputBg: TShape;
    shpSendBg: TShape;
    memPrompt: TMemo;
    btnSend: TSpeedButton;
    lblContext: TLabel;
    pnlBrowser: TPanel;
    pnlSessions: TPanel;
    pnlSessionsHeader: TPanel;
    btnNewSession: TSpeedButton;
    btnRenameSession: TSpeedButton;
    btnDeleteSession: TSpeedButton;
    lstSessions: TListBox;
    splitterSessions: TSplitter;
    procedure btnSendClick(Sender: TObject);
    procedure cbProviderChange(Sender: TObject);
    procedure cbModelChange(Sender: TObject);
    procedure btnClearClick(Sender: TObject);
    procedure btnTemplatesClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure btnSettingsClick(Sender: TObject);
    procedure btnTerminalClick(Sender: TObject);
    procedure EdgeBrowserCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HRESULT);
    procedure EdgeBrowserWebMessageReceived(Sender: TCustomEdgeBrowser; Args: TWebMessageReceivedEventArgs);
    procedure memPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnToggleSessionsClick(Sender: TObject);
    procedure btnNewSessionClick(Sender: TObject);
    procedure btnRenameSessionClick(Sender: TObject);
    procedure btnDeleteSessionClick(Sender: TObject);
    procedure lstSessionsClick(Sender: TObject);
  private
    FPresenter: TRadIAChatPresenter;
    FWebFilesDir: string;
    FBrowserInitialized: Boolean;
    FWebViewInitialized: Boolean;
    FPopupMenuTemplates: TPopupMenu;
    FLifecycleGuard: IInterface;
    FEdgeBrowser: TRadIAEdgeBrowser;
    FLayoutRefreshQueued: Boolean;

    procedure UpdateWebViewNavigation;
    procedure UpdateSendButtonVisual(const AInProgress: Boolean);
    function GetCurrentIDEThemeName: string;
    function GetWebThemeName(const AThemeName: string): string;
    function ColorToHex(AColor: TColor): string;
    procedure CreateEdgeBrowser;
    procedure EnsureMainWebView;
    procedure RefreshBrowserLayout;
    procedure CMShowingChanged(var Message: TMessage); message CM_SHOWINGCHANGED;
    procedure InitializeWebView;
    procedure CopyWebFiles;
    procedure CopyDirectory(const ASourceDir, ADestDir: string);
    procedure OnTemplateMenuClick(Sender: TObject);
    procedure UpdateVCLColors(const AColors: TRadIAThemeColors);
    procedure OnGlobalPromptRequest(const APrompt: string; const AOpenChat: Boolean);

    procedure CleanupUIComponents;
    procedure UnregisterHandlers;
    procedure CleanupBrowsers;

  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    procedure SetTheme(const AThemeName: string);
    procedure EnsureVisibleContent;
    procedure ExecutePrompt(const APrompt: string);

    { IRadIAChatView Implementation }
    procedure SetRequestState(const AInProgress: Boolean);
    procedure UpdateTokensStats(const AStats: string);
    procedure PostMessageToWeb(const AJson: string);
    procedure ApplyCurrentTheme;
    procedure ShowLoginWindow(const AUrl: string; AOnLoginSuccess: TProc);

    procedure UpdateProviders(const AProviders: TArray<string>; const AActiveProvider: string);
    procedure UpdateModels(const AModels: TArray<string>; const AActiveModel: string; const AEnabled: Boolean);
    procedure UpdateSessions(const ASessions: TArray<TSessionInfo>; const AActiveSessionId: string);
    procedure UpdateTemplates(const ATemplates: TArray<string>);

    function GetPromptInput: string;
    procedure SetPromptInput(const APrompt: string);
    procedure FocusPromptInput;

    function GetActiveEditorText(out ACode: string; const AOnlySelected: Boolean): Boolean;
    procedure ReplaceActiveEditorText(const ACode: string; const AReplaceWholeBuffer: Boolean = False;
      const AOriginalText: string = '');

    procedure ShowMessageDialog(const AMessage: string);
    function SaveDialogExecute(out AFileName: string): Boolean;
    procedure ToggleSessionsPanel;
    procedure OpenSettingsDialog;
    procedure OpenTerminal;
    procedure OpenExtensionManager;
  end;

implementation

uses
  System.IOUtils, System.JSON, ToolsAPI, RadIA.OTA.Helper, RadIA.UI.ConfigForm,
  RadIA.Core.Mediator, RadIA.Core.Logger, RadIA.Core.Container,
  Winapi.ActiveX, RadIA.Core.ProviderRegistry, RadIA.Core.Types, Winapi.Windows,
  RadIA.Core.Interfaces, Winapi.WebView2, RadIA.OTA.DockableForm,
  RadIA.UI.ExtensionManagerForm;

{$R *.dfm}

const
  CWebViewScrollbarStyleId = 'radia-scrollbar-style';

procedure TRadIAFrameAIChat.ExecutePrompt(const APrompt: string);
begin
  FPresenter.SendPromptText(APrompt);
end;

function BuildWebViewScrollbarScript: string;
begin
  Result :=
    '(function(){' +
    'var css="::-webkit-scrollbar{width:14px;height:14px;}"+' +
    '"::-webkit-scrollbar-thumb{background:rgba(120,120,120,.55);border-radius:8px;' +
    'border:3px solid transparent;background-clip:content-box;}"+' +
    '"::-webkit-scrollbar-track{background:rgba(120,120,120,.12);}";' +
    'function apply(){if(document.getElementById("' + CWebViewScrollbarStyleId + '"))return;' +
    'var style=document.createElement("style");style.id="' + CWebViewScrollbarStyleId + '";' +
    'style.textContent=css;(document.head||document.documentElement).appendChild(style);}' +
    'if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",apply);' +
    'else apply();' +
    '})();';
end;

procedure InjectWebViewScrollbarStyle(const ABrowser: TEdgeBrowser; const AContext: string);
begin
  if Assigned(ABrowser) and Assigned(ABrowser.DefaultInterface) then
  begin
    try
      ABrowser.DefaultInterface.AddScriptToExecuteOnDocumentCreated(
        PWideChar(BuildWebViewScrollbarScript),
        nil);
    except
      on E: Exception do
        TLogger.Log('Error injecting scrollbar style to ' + AContext + ': ' + E.Message, 'UI');
    end;
  end;
end;

type
  TSessionObject = class
  private
    FId: string;
  public
    constructor Create(const AId: string);
    property Id: string read FId write FId;
  end;
  TProviderObject = class
  private
    FId: string;
  public
    constructor Create(const AId: string);
    property Id: string read FId write FId;
  end;

constructor TProviderObject.Create(const AId: string);
begin
  inherited Create;
  Id := AId;
end;

constructor TSessionObject.Create(const AId: string);
begin
  inherited Create;
  Id := AId;
end;

{ TRadIAFrameAIChat }

procedure TRadIAEdgeBrowser.RefreshControllerBounds;
begin
  Resize;
end;

constructor TRadIAFrameAIChat.Create(AOwner: TComponent);
var
  LThemingServices: IOTAIDEThemingServices;
begin
  inherited Create(AOwner);
  FBrowserInitialized := False;
  FWebViewInitialized := False;
  FLayoutRefreshQueued := False;

  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
    begin
      LThemingServices.ApplyTheme(Self);
    end;
  end;

  FLifecycleGuard := TLifecycleGuard.Create;
  FPopupMenuTemplates := TPopupMenu.Create(Self);
  FWebFilesDir := TPath.Combine(TPath.GetHomePath, 'RadIA\Web');
  CopyWebFiles;

  FPresenter := TRadIAChatPresenter.Create(Self, nil);

  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
      UpdateVCLColors(TRadIAThemeColors.GetColorsForTheme(LThemingServices.ActiveTheme))
    else
      UpdateVCLColors(TRadIAThemeColors.GetColorsForTheme('light'));
  end
  else
    UpdateVCLColors(TRadIAThemeColors.GetColorsForTheme('light'));

  FPresenter.Initialize(FWebFilesDir);

  memPrompt.OnKeyDown := Self.memPromptKeyDown;
  var LMediator: IRadIAMediator;
  if TRadIAContainer.TryResolve<IRadIAMediator>(LMediator) then
    LMediator.RegisterPromptHandler(Self.OnGlobalPromptRequest)
  else
    TRadIAMediator.Instance.RegisterPromptHandler(Self.OnGlobalPromptRequest);
end;

procedure TRadIAFrameAIChat.CleanupUIComponents;
var
  I: Integer;
begin
  if Assigned(FPopupMenuTemplates) then
  begin
    for I := 0 to FPopupMenuTemplates.Items.Count - 1 do
      FPopupMenuTemplates.Items[I].OnClick := nil;
  end;

  if Assigned(lstSessions) then
  begin
    for I := 0 to lstSessions.Items.Count - 1 do
      lstSessions.Items.Objects[I].Free;
  end;

  if Assigned(cbProvider) then
  begin
    for I := 0 to cbProvider.Items.Count - 1 do
      cbProvider.Items.Objects[I].Free;
  end;
end;

procedure TRadIAFrameAIChat.UnregisterHandlers;
var
  LMediator: IRadIAMediator;
begin
  if Assigned(FLifecycleGuard) then
    (FLifecycleGuard as IRadIALifecycleGuard).Invalidate;

  if TRadIAContainer.TryResolve<IRadIAMediator>(LMediator) then
    LMediator.UnregisterPromptHandler
  else
    TRadIAMediator.Instance.UnregisterPromptHandler;
end;

procedure TRadIAFrameAIChat.CleanupBrowsers;
begin
  if not GIsShuttingDown then
  begin
    if Assigned(FEdgeBrowser) then
      FEdgeBrowser.Parent := nil;
    FreeAndNil(FEdgeBrowser);
    FreeAndNil(pnlBrowser);
  end
  else
  begin
    if Assigned(FEdgeBrowser) then
      FEdgeBrowser.Parent := nil;
  end;
end;

destructor TRadIAFrameAIChat.Destroy;
begin
  UnregisterHandlers;
  CleanupUIComponents;
  FPresenter.Free;
  CleanupBrowsers;

  inherited Destroy;
end;

procedure TRadIAFrameAIChat.CMShowingChanged(var Message: TMessage);
begin
  inherited;
  if Showing then
    EnsureVisibleContent;
end;

procedure TRadIAFrameAIChat.CreateEdgeBrowser;
begin
  if not Assigned(FEdgeBrowser) then
  begin
    FEdgeBrowser := TRadIAEdgeBrowser.Create(nil);
    FEdgeBrowser.Parent := pnlBrowser;
    FEdgeBrowser.Align := alClient;
    FEdgeBrowser.AlignWithMargins := True;
    FEdgeBrowser.OnCreateWebViewCompleted := EdgeBrowserCreateWebViewCompleted;
    FEdgeBrowser.OnWebMessageReceived := EdgeBrowserWebMessageReceived;
  end;
end;

procedure TRadIAFrameAIChat.CreateWnd;
begin
  inherited CreateWnd;
  if Showing then
    EnsureMainWebView;
end;

procedure TRadIAFrameAIChat.EnsureMainWebView;
begin
  CreateEdgeBrowser;
  pnlBrowser.Caption := 'Loading Rad IA Chat...';

  if not FWebViewInitialized then
  begin
    FWebViewInitialized := True;
    TThread.ForceQueue(nil,
      TThreadProcedure(
      procedure
      begin
        if Assigned(FEdgeBrowser) then
          InitializeWebView;
      end));
  end
  else if FBrowserInitialized then
    UpdateWebViewNavigation;
end;

procedure TRadIAFrameAIChat.EnsureVisibleContent;
begin
  EnsureMainWebView;
  RefreshBrowserLayout;
end;

procedure TRadIAFrameAIChat.RefreshBrowserLayout;
var
  LGuard: IRadIALifecycleGuard;
begin
  if FLayoutRefreshQueued then
    Exit;

  FLayoutRefreshQueued := True;
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  TThread.ForceQueue(
    nil,
    TThreadProcedure(
      procedure
      begin
        if not LGuard.IsAlive then
          Exit;
        FLayoutRefreshQueued := False;
        if GIsShuttingDown or not Assigned(FEdgeBrowser) or
          not Assigned(pnlBrowser) then
          Exit;

        pnlBrowser.Realign;
        FEdgeBrowser.SetBounds(
          0,
          0,
          pnlBrowser.ClientWidth,
          pnlBrowser.ClientHeight
        );
        FEdgeBrowser.RefreshControllerBounds;
      end
    )
  );
end;

procedure TRadIAFrameAIChat.DestroyWnd;
var
  LEdgeToFree: TRadIAEdgeBrowser;
begin
  FBrowserInitialized := False;
  FWebViewInitialized := False;
  FLayoutRefreshQueued := False;

  if Assigned(FEdgeBrowser) then
  begin
    LEdgeToFree := FEdgeBrowser;
    FEdgeBrowser := nil;
    LEdgeToFree.Parent := nil;
    if not GIsShuttingDown then
    begin
      LEdgeToFree.Free;
    end;
  end;

  inherited DestroyWnd;
end;

procedure TRadIAFrameAIChat.CopyDirectory(const ASourceDir, ADestDir: string);
var
  LFile: string;
  LDir: string;
  LFileName: string;
  LSubDir: string;
begin
  if not TDirectory.Exists(ASourceDir) then
    Exit;

  ForceDirectories(ADestDir);

  for LFile in TDirectory.GetFiles(ASourceDir) do
  begin
    LFileName := TPath.GetFileName(LFile);
    TFile.Copy(LFile, TPath.Combine(ADestDir, LFileName), True);
  end;

  for LDir in TDirectory.GetDirectories(ASourceDir) do
  begin
    LSubDir := TPath.GetFileName(LDir);
    CopyDirectory(LDir, TPath.Combine(ADestDir, LSubDir));
  end;
end;

procedure TRadIAFrameAIChat.CopyWebFiles;
var
  LSourceDir: string;
  LModuleDir: string;
begin
  ForceDirectories(FWebFilesDir);

  LModuleDir := ExtractFilePath(GetModuleName(HInstance));
  LSourceDir := TPath.Combine(LModuleDir, 'Web');

  if not TDirectory.Exists(LSourceDir) then
  begin
    LSourceDir := TPath.GetFullPath(TPath.Combine(LModuleDir, '..\Web'));
  end;

  if not TDirectory.Exists(LSourceDir) then
  begin
    LSourceDir := TPath.GetFullPath(TPath.Combine(LModuleDir, '..\..\..\Source\UI\Web'));
  end;

  if not TDirectory.Exists(LSourceDir) then
  begin
    LSourceDir := 'D:\Projetos\PluginDelphiIA\Source\UI\Web';
  end;

  if not TDirectory.Exists(LSourceDir) then
    Exit;

  CopyDirectory(LSourceDir, FWebFilesDir);
end;

procedure TRadIAFrameAIChat.InitializeWebView;
begin
  FEdgeBrowser.UserDataFolder := TPath.Combine(TPath.GetHomePath, 'RadIA\WebView2');
  FEdgeBrowser.CreateWebView;
end;

procedure TRadIAFrameAIChat.UpdateWebViewNavigation;
var
  LTargetUrl: string;
begin
  if FBrowserInitialized then
  begin
    pnlBrowser.Caption := '';
    cbProvider.Visible := True;
    cbModel.Visible := True;
    btnTemplates.Visible := True;

    LTargetUrl := 'file:///' + TPath.Combine(FWebFilesDir, 'chat.html').Replace('\', '/') +
      '?theme=' + GetWebThemeName(GetCurrentIDEThemeName);
    TLogger.Log('UpdateWebViewNavigation: Navigating to local chat: ' + LTargetUrl, 'UI');
    FEdgeBrowser.Navigate(LTargetUrl);
  end;
end;

procedure TRadIAFrameAIChat.btnSendClick(Sender: TObject);
begin
  FPresenter.SendPrompt;
end;

procedure TRadIAFrameAIChat.cbProviderChange(Sender: TObject);
begin
  if cbProvider.ItemIndex <> -1 then
  begin
    FPresenter.ChangeProvider(TProviderObject(cbProvider.Items.Objects[cbProvider.ItemIndex]).Id);
  end;
end;

procedure TRadIAFrameAIChat.cbModelChange(Sender: TObject);
begin
  if cbModel.ItemIndex <> -1 then
  begin
    FPresenter.ChangeModel(cbModel.Text);
  end;
end;

procedure TRadIAFrameAIChat.btnClearClick(Sender: TObject);
begin
  FPresenter.ClearChat;
end;

procedure TRadIAFrameAIChat.btnExportClick(Sender: TObject);
begin
  FPresenter.ExportChat;
end;

procedure TRadIAFrameAIChat.btnSettingsClick(Sender: TObject);
begin
  FPresenter.OpenSettings;
end;

procedure TRadIAFrameAIChat.btnTerminalClick(Sender: TObject);
begin
  OpenTerminal;
end;

procedure TRadIAFrameAIChat.memPromptKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  FPresenter.HandlePromptInputKeyDown(Key, Shift);
end;

procedure TRadIAFrameAIChat.btnToggleSessionsClick(Sender: TObject);
begin
  FPresenter.ToggleSessions;
end;

procedure TRadIAFrameAIChat.btnNewSessionClick(Sender: TObject);
begin
  FPresenter.CreateNewSession;
end;

procedure TRadIAFrameAIChat.btnRenameSessionClick(Sender: TObject);
var
  LNewName: string;
  LCurrentName: string;
begin
  LCurrentName := '';
  if lstSessions.ItemIndex <> -1 then
    LCurrentName := lstSessions.Items[lstSessions.ItemIndex];

  LNewName := InputBox('Rename Conversation', 'Enter the new title of the conversation:', LCurrentName);
  if not LNewName.Trim.IsEmpty then
  begin
    FPresenter.RenameSession(FPresenter.SessionManager.ActiveSessionId, LNewName);
  end;
end;

procedure TRadIAFrameAIChat.btnDeleteSessionClick(Sender: TObject);
begin
  if MessageDlg('Do you really want to delete this conversation and all its history?',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FPresenter.DeleteSession(FPresenter.SessionManager.ActiveSessionId);
  end;
end;

procedure TRadIAFrameAIChat.lstSessionsClick(Sender: TObject);
begin
  if lstSessions.ItemIndex <> -1 then
  begin
    FPresenter.SelectSession(TSessionObject(lstSessions.Items.Objects[lstSessions.ItemIndex]).Id);
  end;
end;

procedure TRadIAFrameAIChat.EdgeBrowserCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HRESULT);
var
  LSettings: ICoreWebView2Settings;
begin
  if Succeeded(AResult) then
  begin
    FBrowserInitialized := True;
    if Assigned(FEdgeBrowser.DefaultInterface) then
    begin
      if Succeeded(FEdgeBrowser.DefaultInterface.Get_Settings(LSettings)) and Assigned(LSettings) then
      begin
        LSettings.Set_AreDevToolsEnabled(1);
        LSettings.Set_AreDefaultContextMenusEnabled(1);
      end;
      InjectWebViewScrollbarStyle(FEdgeBrowser, 'main chat WebView');
    end;
    UpdateWebViewNavigation;
  end;
  if Failed(AResult) then
  begin
    FBrowserInitialized := False;
    FWebViewInitialized := False;
    pnlBrowser.Caption := 'Unable to load Rad IA Chat. Close and reopen the chat window.';
    TLogger.Log('EdgeBrowserCreateWebViewCompleted failed for main chat WebView. HRESULT: ' +
      IntToHex(AResult, 8), 'UI');
  end;
end;

procedure TRadIAFrameAIChat.EdgeBrowserWebMessageReceived(Sender: TCustomEdgeBrowser;
    Args: TWebMessageReceivedEventArgs);
var
  LStr: PWideChar;
  LJsonStr: PWideChar;
begin
  if Assigned(Args.ArgsInterface) then
  begin
    if Succeeded(Args.ArgsInterface.TryGetWebMessageAsString(LStr)) then
    begin
      try
        FPresenter.ProcessWebMessage(string(LStr));
      finally
        CoTaskMemFree(LStr);
      end;
    end
    else
    begin
      Args.ArgsInterface.Get_webMessageAsJson(LJsonStr);
      try
        FPresenter.ProcessWebMessage(string(LJsonStr));
      finally
        CoTaskMemFree(LJsonStr);
      end;
    end;
  end;
end;

procedure TRadIAFrameAIChat.btnTemplatesClick(Sender: TObject);
var
  LPoint: TPoint;
begin
  LPoint := btnTemplates.Parent.ClientToScreen(Point(btnTemplates.Left, btnTemplates.Top + btnTemplates.Height));
  FPopupMenuTemplates.Popup(LPoint.X, LPoint.Y);
end;

procedure TRadIAFrameAIChat.OnTemplateMenuClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    FPresenter.HandleTemplateSelected(TMenuItem(Sender).Caption);
end;

procedure TRadIAFrameAIChat.OnGlobalPromptRequest(const APrompt: string; const AOpenChat: Boolean);
begin
  FPresenter.HandleGlobalPromptRequest(APrompt, AOpenChat);
end;

procedure TRadIAFrameAIChat.SetTheme(const AThemeName: string);
var
  LJson: TJSONObject;
  LColors: TRadIAThemeColors;
begin
  LColors := TRadIAThemeColors.GetColorsForTheme(AThemeName);
  UpdateVCLColors(LColors);

  if not FBrowserInitialized then
    Exit;

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'set_theme');
    LJson.AddPair('theme', GetWebThemeName(AThemeName));

    LJson.AddPair('bgBase', ColorToHex(LColors.BgBase));
    LJson.AddPair('bgPanel', ColorToHex(LColors.BgBase));
    LJson.AddPair('bgInput', ColorToHex(LColors.InputBgColor));
    LJson.AddPair('fgPrimary', ColorToHex(LColors.TextColor));
    LJson.AddPair('bgElevated', ColorToHex(LColors.BgElevated));
    LJson.AddPair('fgSecondary', LColors.FgSecondary);
    LJson.AddPair('codeBg', LColors.CodeBg);
    LJson.AddPair('codeHeader', ColorToHex(LColors.CodeHeader));
    LJson.AddPair('greenApply', LColors.GreenApply);
    LJson.AddPair('border', ColorToHex(LColors.BorderColor));

    if LColors.IsDark then
      LJson.AddPair('accent', '#007acc')
    else
      LJson.AddPair('accent', '#005a9e');

    PostMessageToWeb(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.ApplyCurrentTheme;
begin
  SetTheme(GetCurrentIDEThemeName);
end;

function TRadIAFrameAIChat.GetCurrentIDEThemeName: string;
var
  LThemingServices: IOTAIDEThemingServices;
begin
  Result := 'light';
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
      Result := LThemingServices.ActiveTheme;
  end;
end;

function TRadIAFrameAIChat.GetWebThemeName(const AThemeName: string): string;
begin
  if IsThemeDark(AThemeName) then
    Result := 'dark'
  else
    Result := 'light';
end;

function TRadIAFrameAIChat.ColorToHex(AColor: TColor): string;
var
  LColorRGB: LongInt;
  LRed, LGreen, LBlue: Byte;
begin
  LColorRGB := ColorToRGB(AColor);
  LRed := GetRValue(LColorRGB);
  LGreen := GetGValue(LColorRGB);
  LBlue := GetBValue(LColorRGB);
  Result := Format('#%.2x%.2x%.2x', [LRed, LGreen, LBlue]);
end;

procedure TRadIAFrameAIChat.UpdateSendButtonVisual(const AInProgress: Boolean);
var
  LIsDark: Boolean;
  LThemingServices: IOTAIDEThemingServices;
  LActiveTheme: string;
begin
  LIsDark := False;
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
    begin
      LActiveTheme := LThemingServices.ActiveTheme;
      LIsDark := IsThemeDark(LActiveTheme);
    end;
  end;

  if AInProgress then
  begin
    shpSendBg.Brush.Color := $003B3BFC;
    shpSendBg.Pen.Color := $003B3BFC;
    shpSendBg.Pen.Style := psSolid;
    btnSend.Caption := #9632;
    btnSend.Font.Color := clWhite;
  end
  else
  begin
    if LIsDark then
    begin
      shpSendBg.Brush.Color := $00E5E5E5;
      shpSendBg.Pen.Color := $00E5E5E5;
      shpSendBg.Pen.Style := psSolid;
      btnSend.Caption := #10148;
      btnSend.Font.Color := $001E1E1E;
    end
    else
    begin
      shpSendBg.Brush.Color := $001E1E1E;
      shpSendBg.Pen.Color := $001E1E1E;
      shpSendBg.Pen.Style := psSolid;
      btnSend.Caption := #10148;
      btnSend.Font.Color := clWhite;
    end;
  end;
end;

procedure TRadIAFrameAIChat.UpdateVCLColors(const AColors: TRadIAThemeColors);
begin
  Self.Color := AColors.BgBase;
  pnlToolbar.Color := AColors.BgBase;
  pnlInput.Color := AColors.BgBase;
  pnlSessions.Color := AColors.BgBase;
  pnlSessionsHeader.Color := AColors.BgBase;
  pnlBrowser.Color := AColors.BgBase;

  lblTitle.Font.Color := AColors.TextColor;
  lblContext.Font.Color := AColors.TextColor;

  memPrompt.Color := AColors.InputBgColor;
  memPrompt.Font.Color := AColors.TextColor;

  lstSessions.Color := AColors.InputBgColor;
  lstSessions.Font.Color := AColors.TextColor;

  shpInputBg.Brush.Color := AColors.InputBgColor;
  shpInputBg.Pen.Color := AColors.BorderColor;
end;

{ IRadIAChatView Implementation }

procedure TRadIAFrameAIChat.SetRequestState(const AInProgress: Boolean);
var
  LJson: TJSONObject;
begin
  Self.UpdateSendButtonVisual(AInProgress);
  Self.btnSend.Enabled := True;

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'set_request_state');
    LJson.AddPair('inProgress', TJSONBool.Create(AInProgress));
    PostMessageToWeb(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.UpdateTokensStats(const AStats: string);
begin
  // Intentionally empty: token statistics not rendered on VCL frame directly
end;

procedure TRadIAFrameAIChat.PostMessageToWeb(const AJson: string);
begin
  if FBrowserInitialized and Assigned(FEdgeBrowser) and Assigned(FEdgeBrowser.DefaultInterface) then
  begin
    FEdgeBrowser.DefaultInterface.PostWebMessageAsJson(PChar(AJson));
  end;
end;



procedure TRadIAFrameAIChat.ShowLoginWindow(const AUrl: string; AOnLoginSuccess: TProc);
begin
  // Web Login is deprecated
end;

procedure TRadIAFrameAIChat.UpdateProviders(const AProviders: TArray<string>; const AActiveProvider: string);
var
  LProviderId: string;
  I, LFoundIndex: Integer;
  LMeta: TProviderMetadata;
  LProvObj: TProviderObject;
begin
  if Assigned(cbProvider) then
  begin
    for I := 0 to cbProvider.Items.Count - 1 do
      cbProvider.Items.Objects[I].Free;
    cbProvider.Items.Clear;
  end;

  for LProviderId in AProviders do
  begin
    if TProviderRegistry.GetProvider(LProviderId, LMeta) then
    begin
      LProvObj := TProviderObject.Create(LProviderId);
      cbProvider.Items.AddObject(LMeta.DisplayName, LProvObj);
    end;
  end;

  LFoundIndex := -1;
  for I := 0 to cbProvider.Items.Count - 1 do
  begin
    if SameText(TProviderObject(cbProvider.Items.Objects[I]).Id, AActiveProvider) then
    begin
      LFoundIndex := I;
      Break;
    end;
  end;

  if LFoundIndex <> -1 then
    cbProvider.ItemIndex := LFoundIndex
  else if cbProvider.Items.Count > 0 then
    cbProvider.ItemIndex := 0;
end;

procedure TRadIAFrameAIChat.UpdateModels(const AModels: TArray<string>; const AActiveModel: string;
    const AEnabled: Boolean);
var
  LModel: string;
begin
  cbModel.Items.Clear;
  for LModel in AModels do
    cbModel.Items.Add(LModel);
  cbModel.ItemIndex := cbModel.Items.IndexOf(AActiveModel);
  cbModel.Enabled := AEnabled;
end;

procedure TRadIAFrameAIChat.UpdateSessions(const ASessions: TArray<TSessionInfo>; const AActiveSessionId: string);
var
  LSession: TSessionInfo;
  I, LIndexToSelect: Integer;
begin
  lstSessions.OnClick := nil;
  try
    for I := 0 to lstSessions.Items.Count - 1 do
      lstSessions.Items.Objects[I].Free;
    lstSessions.Items.Clear;

    for LSession in ASessions do
    begin
      lstSessions.Items.AddObject(LSession.Name, TSessionObject.Create(LSession.Id));
    end;

    LIndexToSelect := -1;
    for I := 0 to lstSessions.Items.Count - 1 do
    begin
      if SameText(TSessionObject(lstSessions.Items.Objects[I]).Id, AActiveSessionId) then
      begin
        LIndexToSelect := I;
        Break;
      end;
    end;

    if LIndexToSelect <> -1 then
      lstSessions.ItemIndex := LIndexToSelect
    else if lstSessions.Items.Count > 0 then
      lstSessions.ItemIndex := 0;
  finally
    lstSessions.OnClick := Self.lstSessionsClick;
  end;
end;

procedure TRadIAFrameAIChat.UpdateTemplates(const ATemplates: TArray<string>);
var
  LTemplateName: string;
  LMenuItem: TMenuItem;
  I: Integer;
begin
  if Assigned(FPopupMenuTemplates) then
  begin
    for I := 0 to FPopupMenuTemplates.Items.Count - 1 do
      FPopupMenuTemplates.Items[I].OnClick := nil;
    FPopupMenuTemplates.Items.Clear;
  end;

  for LTemplateName in ATemplates do
  begin
    LMenuItem := TMenuItem.Create(FPopupMenuTemplates);
    LMenuItem.Caption := LTemplateName;
    LMenuItem.OnClick := OnTemplateMenuClick;
    FPopupMenuTemplates.Items.Add(LMenuItem);
  end;
end;

function TRadIAFrameAIChat.GetPromptInput: string;
begin
  Result := memPrompt.Text;
end;

procedure TRadIAFrameAIChat.SetPromptInput(const APrompt: string);
begin
  memPrompt.Text := APrompt;
  memPrompt.SelStart := Length(APrompt);
end;

procedure TRadIAFrameAIChat.FocusPromptInput;
begin
  memPrompt.SetFocus;
end;

function TRadIAFrameAIChat.GetActiveEditorText(out ACode: string; const AOnlySelected: Boolean): Boolean;
begin
  Result := TRadIAOTAHelper.GetActiveEditorText(ACode, AOnlySelected);
end;

procedure TRadIAFrameAIChat.ReplaceActiveEditorText(const ACode: string; const AReplaceWholeBuffer: Boolean;
  const AOriginalText: string);
begin
  TRadIAOTAHelper.ReplaceActiveEditorText(ACode, AReplaceWholeBuffer, AOriginalText);
end;

procedure TRadIAFrameAIChat.ShowMessageDialog(const AMessage: string);
begin
  ShowMessage(AMessage);
end;

function TRadIAFrameAIChat.SaveDialogExecute(out AFileName: string): Boolean;
begin
  Result := SaveDialog.Execute;
  if Result then
    AFileName := SaveDialog.FileName;
end;

procedure TRadIAFrameAIChat.ToggleSessionsPanel;
begin
  pnlSessions.Visible := not pnlSessions.Visible;
  splitterSessions.Visible := pnlSessions.Visible;
  if pnlSessions.Visible then
    splitterSessions.Left := pnlSessions.Left + pnlSessions.Width + 1;
end;

procedure TRadIAFrameAIChat.OpenSettingsDialog;
var
  LForm: TRadIAFormAIConfig;
  LThemingServices: IOTAIDEThemingServices;
begin
  LForm := TRadIAFormAIConfig.Create(nil);
  try
    if Assigned(Vcl.Forms.Application.MainForm) then
    begin
      LForm.PopupParent := Vcl.Forms.Application.MainForm;
      LForm.PopupMode := pmExplicit;
    end;

    LForm.LoadConfig;

    if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
    begin
      if LThemingServices.IDEThemingEnabled then
      begin
        LThemingServices.ApplyTheme(LForm);
      end;
    end;

    if LForm.ShowModal = mrOk then
    begin
      FPresenter.LoadConfig;
    end;
  finally
    LForm.Free;
  end;
end;

procedure TRadIAFrameAIChat.OpenTerminal;
begin
  ShowRadIATerminal;
end;

procedure TRadIAFrameAIChat.OpenExtensionManager;
begin
  ShowRadIAExtensionManager;
end;

end.
