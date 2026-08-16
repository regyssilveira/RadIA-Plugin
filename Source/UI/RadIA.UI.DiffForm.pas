unit RadIA.UI.DiffForm;

interface

uses  System.Classes, Vcl.Controls, Vcl.Forms, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Edge, RadIA.Core.Interfaces, Winapi.WebView2, Winapi.ActiveX;

type
  { Form to compare code changes side-by-side before applying them to the editor }
  TRadIAFormAIDiff = class(TForm)
    pnlFooter: TPanel;
    lblSeparator: TLabel;
    btnPrevConflict: TButton;
    btnNextConflict: TButton;
    btnApply: TButton;
    btnCancel: TButton;
    pnlBrowser: TPanel;
    EdgeBrowser: TEdgeBrowser;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure EdgeBrowserCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HRESULT);
    procedure EdgeBrowserNavigationCompleted(Sender: TCustomEdgeBrowser; IsSuccess: Boolean;
        WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
    procedure EdgeBrowserWebMessageReceived(
      Sender: TCustomEdgeBrowser;
      Args: TWebMessageReceivedEventArgs
    );
    procedure btnPrevConflictClick(Sender: TObject);
    procedure btnNextConflictClick(Sender: TObject);
  protected
    procedure CreateWnd; override;
  private
    FConfig: IRadIAConfig;
    FAIService: IRadIAService;
    FOriginalCode: string;
    FSuggestedCode: string;
    FUnitName: string;
    FWebFilesDir: string;
    FBrowserInitialized: Boolean;
    FPageReady: Boolean;
    FRequestStarted: Boolean;
    FRequestFinished: Boolean;
    FPendingRender: Boolean;
    FCanApply: Boolean;
    FRequestTimeoutTimer: TTimer;
    FLifecycleGuard: IInterface;
    FRenderId: string;
    FAcceptedBlockCount: Integer;
    FTotalBlockCount: Integer;

    procedure FormShow(Sender: TObject);
    procedure LoadWindowPlacement;
    procedure RequestRefactoring;
    procedure RequestTimeoutElapsed(Sender: TObject);
    procedure RenderDiffInBrowser;
    procedure SaveWindowPlacement;
    procedure TryStartRefactoring;
    function CleanSuggestedCode(const AResponse: string): string;
    procedure PostToWebView(const AAction, AText: string);
    procedure ProcessWebMessage(const AMessage: string);
    function IsExpectedWebMessageSource(const AArgs: TWebMessageReceivedEventArgs): Boolean;
  public
    procedure InitializeDiff(const AUnitName, AOriginalCode: string; const AWebFilesDir: string = '');
    procedure InitializePreparedDiff(
      const AUnitName: string;
      const AOriginalCode: string;
      const AProposedCode: string
    );

    property SuggestedCode: string read FSuggestedCode;
  end;

implementation


uses
  Winapi.Windows, System.SysUtils, RadIA.Core.Types, RadIA.Core.Config, RadIA.Core.Service, RadIA.Core.TokenUsage,
      System.IOUtils, System.JSON, System.Math, System.Win.Registry, ToolsAPI, RadIA.UI.Resources,
  RadIA.Core.Container, RadIA.Core.Version;

{$R *.dfm}



const
  CDiffDefaultTimeoutMs = 60000;
  CDiffWebLoginTimeoutMs = 300000;
  CMaxSelectedDiffCharacters = 2 * 1024 * 1024;
  CMaxDiffBlocks = 5000;

procedure TRadIAFormAIDiff.CreateWnd;
var
  LThemingServices: IOTAIDEThemingServices;
  LActiveTheme: string;
begin
  inherited CreateWnd;

  LActiveTheme := 'light';
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
    begin
      LActiveTheme := LThemingServices.ActiveTheme;
    end;
  end;

  if SameText(LActiveTheme, 'dark') then
  begin
    TRadIAUIHelper.ApplyDarkTitleBar(Self, True);
  end;
end;

procedure TRadIAFormAIDiff.FormCreate(Sender: TObject);
var
  LThemingServices: IOTAIDEThemingServices;
begin
  Caption := RadIAVersionedCaption('Rad IA - Smart Diff');
  FBrowserInitialized := False;
  FPageReady := False;
  FRequestStarted := False;
  FRequestFinished := False;
  FPendingRender := False;
  FCanApply := False;
  FRenderId := '';
  FAcceptedBlockCount := 0;
  FTotalBlockCount := 0;
  FLifecycleGuard := TLifecycleGuard.Create;
  if not TRadIAContainer.TryResolve<IRadIAConfig>(FConfig) then
  begin
    FConfig := TRadIAConfig.GetInstance;
    FConfig.Load;
  end;
  if not TRadIAContainer.TryResolve<IRadIAService>(FAIService) then
    FAIService := TRadIAService.Create(FConfig);
  FWebFilesDir := TPath.Combine(TPath.GetHomePath, 'RadIA\Web');
  FRequestTimeoutTimer := TTimer.Create(Self);
  FRequestTimeoutTimer.Enabled := False;
  if FConfig.IsWebLoginProvider(FConfig.GetActiveProvider) then
    FRequestTimeoutTimer.Interval := CDiffWebLoginTimeoutMs
  else
    FRequestTimeoutTimer.Interval := CDiffDefaultTimeoutMs;
  FRequestTimeoutTimer.OnTimer := RequestTimeoutElapsed;
  btnApply.Enabled := False;
  LoadWindowPlacement;

  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
    begin
      LThemingServices.ApplyTheme(Self);
    end;
  end;

  OnShow := FormShow;
end;

procedure TRadIAFormAIDiff.FormDestroy(Sender: TObject);
begin
  SaveWindowPlacement;
  (FLifecycleGuard as IRadIALifecycleGuard).Invalidate;
  FAIService := nil;

  if GIsShuttingDown then
  begin
    if Assigned(EdgeBrowser) then
    begin
      EdgeBrowser.Parent := nil;
      Self.RemoveComponent(EdgeBrowser);
    end;
  end;
end;

procedure TRadIAFormAIDiff.LoadWindowPlacement;
var
  LReg: TRegistry;
  LRegPath: string;
  LLeft: Integer;
  LTop: Integer;
  LWidth: Integer;
  LHeight: Integer;
  LBounds: TRect;
  LDesktop: TRect;
begin
  LReg := TRegistry.Create;
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    LRegPath := TRadIAConfig.GetRegistryPath;
    if not LReg.OpenKeyReadOnly(LRegPath) then
      Exit;

    if not (LReg.ValueExists('DiffWindowWidth') and
            LReg.ValueExists('DiffWindowHeight') and
            LReg.ValueExists('DiffWindowLeft') and
            LReg.ValueExists('DiffWindowTop')) then
      Exit;

    LWidth := LReg.ReadInteger('DiffWindowWidth');
    LHeight := LReg.ReadInteger('DiffWindowHeight');
    LLeft := LReg.ReadInteger('DiffWindowLeft');
    LTop := LReg.ReadInteger('DiffWindowTop');

    LWidth := Max(640, LWidth);
    LHeight := Max(480, LHeight);
    LBounds := Rect(LLeft, LTop, LLeft + LWidth, LTop + LHeight);
    LDesktop := Screen.DesktopRect;

    if (LBounds.Right < LDesktop.Left) or (LBounds.Left > LDesktop.Right) or
       (LBounds.Bottom < LDesktop.Top) or (LBounds.Top > LDesktop.Bottom) then
      Exit;

    Position := poDesigned;
    SetBounds(LLeft, LTop, LWidth, LHeight);
  finally
    LReg.Free;
  end;
end;

procedure TRadIAFormAIDiff.SaveWindowPlacement;
var
  LReg: TRegistry;
  LRegPath: string;
begin
  if WindowState <> wsNormal then
    Exit;

  LReg := TRegistry.Create;
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    LRegPath := TRadIAConfig.GetRegistryPath;
    if LReg.OpenKey(LRegPath, True) then
    begin
      LReg.WriteInteger('DiffWindowWidth', Width);
      LReg.WriteInteger('DiffWindowHeight', Height);
      LReg.WriteInteger('DiffWindowLeft', Left);
      LReg.WriteInteger('DiffWindowTop', Top);
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;
end;

procedure TRadIAFormAIDiff.FormShow(Sender: TObject);
var
  LThemingServices: IOTAIDEThemingServices;
begin
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
    begin
      LThemingServices.ApplyTheme(Self);
    end;
  end;

  if not FBrowserInitialized then
  begin
    EdgeBrowser.UserDataFolder := TPath.Combine(TPath.GetHomePath, 'RadIA\WebView2Diff');
    EdgeBrowser.Navigate('file:///' + TPath.Combine(FWebFilesDir, 'diff.html').Replace('\', '/'));
  end;
end;

procedure TRadIAFormAIDiff.InitializeDiff(const AUnitName, AOriginalCode: string; const AWebFilesDir: string);
begin
  FUnitName := AUnitName;
  FOriginalCode := AOriginalCode;
  if not AWebFilesDir.IsEmpty then
    FWebFilesDir := AWebFilesDir;
end;

procedure TRadIAFormAIDiff.InitializePreparedDiff(
  const AUnitName: string;
  const AOriginalCode: string;
  const AProposedCode: string
);
begin
  FUnitName := AUnitName;
  FOriginalCode := AOriginalCode;
  FSuggestedCode := AProposedCode;
  FRequestStarted := True;
  FRequestFinished := True;
  FCanApply := True;
  FPendingRender := True;
end;

procedure TRadIAFormAIDiff.EdgeBrowserCreateWebViewCompleted(Sender: TCustomEdgeBrowser; AResult: HRESULT);
begin
  if Succeeded(AResult) then
    FBrowserInitialized := True;
end;

procedure TRadIAFormAIDiff.EdgeBrowserNavigationCompleted(Sender: TCustomEdgeBrowser;
  IsSuccess: Boolean; WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS);
var
  LThemingServices: IOTAIDEThemingServices;
  LThemeName: string;
begin
  if not IsSuccess then
  begin
    FSuggestedCode := '// Error loading diff view. WebView2 status: ' + IntToStr(Ord(WebErrorStatus)) +
      #13#10 + FOriginalCode;
    FPendingRender := True;
    Exit;
  end;

  FPageReady := True;

  LThemeName := 'light';
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled and SameText(LThemingServices.ActiveTheme, 'Dark') then
      LThemeName := 'dark';
  end;

  PostToWebView('set_theme', LThemeName);

  if FPendingRender and (not FSuggestedCode.Trim.IsEmpty) then
    RenderDiffInBrowser
  else
    TryStartRefactoring;
end;

procedure TRadIAFormAIDiff.PostToWebView(const AAction, AText: string);
var
  LJson: TJSONObject;
begin
  if not FBrowserInitialized then
    Exit;

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', AAction);
    if not AText.IsEmpty then
      LJson.AddPair('theme', AText);

    if Assigned(EdgeBrowser.DefaultInterface) then
      EdgeBrowser.DefaultInterface.PostWebMessageAsJson(PChar(LJson.ToJSON));
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFormAIDiff.RenderDiffInBrowser;
var
  LJson: TJSONObject;
begin
  if not FBrowserInitialized or not FPageReady then
  begin
    FPendingRender := True;
    Exit;
  end;

  LJson := TJSONObject.Create;
  try
    FRenderId := TGUID.NewGuid.ToString;
    LJson.AddPair('action', 'render');
    LJson.AddPair('renderId', FRenderId);
    LJson.AddPair('fileName', FUnitName);
    LJson.AddPair('original', FOriginalCode);
    LJson.AddPair('modified', FSuggestedCode);

    if Assigned(EdgeBrowser.DefaultInterface) then
      EdgeBrowser.DefaultInterface.PostWebMessageAsJson(PChar(LJson.ToJSON));
    FPendingRender := False;
    btnApply.Enabled := FCanApply and (not FSuggestedCode.Trim.IsEmpty);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFormAIDiff.EdgeBrowserWebMessageReceived(
  Sender: TCustomEdgeBrowser;
  Args: TWebMessageReceivedEventArgs
);
var
  LJsonText: PWideChar;
  LText: PWideChar;
begin
  if not Assigned(Args.ArgsInterface) or not IsExpectedWebMessageSource(Args) then
    Exit;
  if Succeeded(Args.ArgsInterface.TryGetWebMessageAsString(LText)) then
  begin
    try
      ProcessWebMessage(string(LText));
    finally
      CoTaskMemFree(LText);
    end;
    Exit;
  end;
  if Failed(Args.ArgsInterface.Get_webMessageAsJson(LJsonText)) then
    Exit;
  try
    ProcessWebMessage(string(LJsonText));
  finally
    CoTaskMemFree(LJsonText);
  end;
end;

function TRadIAFormAIDiff.IsExpectedWebMessageSource(
  const AArgs: TWebMessageReceivedEventArgs
): Boolean;
var
  LExpectedSource: string;
  LSource: PWideChar;
  LSourceText: string;
begin
  Result := False;
  if not Assigned(AArgs.ArgsInterface) then
    Exit;
  LSource := nil;
  if Failed(AArgs.ArgsInterface.Get_Source(LSource)) then
    Exit;
  try
    LSourceText := string(LSource);
  finally
    CoTaskMemFree(LSource);
  end;
  LExpectedSource := 'file:///' + TPath.Combine(FWebFilesDir, 'diff.html').Replace('\', '/');
  Result := SameText(LSourceText, LExpectedSource);
end;

procedure TRadIAFormAIDiff.ProcessWebMessage(
  const AMessage: string
);
var
  LAcceptedCount: Integer;
  LJson: TJSONValue;
  LModified: string;
  LObject: TJSONObject;
  LRenderId: string;
  LTotalCount: Integer;
begin
  if Length(AMessage) > CMaxSelectedDiffCharacters + 4096 then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AMessage);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LObject := TJSONObject(LJson);
    if not SameText(
      LObject.GetValue<string>('action', ''),
      'selection_changed'
    ) then
      Exit;
    LRenderId := LObject.GetValue<string>('renderId', '');
    if (LRenderId = '') or not SameText(LRenderId, FRenderId) then
      Exit;
    LModified := LObject.GetValue<string>('modified', '');
    LAcceptedCount := LObject.GetValue<Integer>('acceptedCount', -1);
    LTotalCount := LObject.GetValue<Integer>('totalCount', -1);
    if (Length(LModified) > CMaxSelectedDiffCharacters) or
      (LAcceptedCount < 0) or
      (LTotalCount < 0) or
      (LTotalCount > CMaxDiffBlocks) or
      (LAcceptedCount > LTotalCount) then
      Exit;

    FSuggestedCode := LModified;
    FAcceptedBlockCount := LAcceptedCount;
    FTotalBlockCount := LTotalCount;
    btnApply.Enabled :=
      FCanApply and
      (FAcceptedBlockCount > 0) and
      (FSuggestedCode <> FOriginalCode);
    btnApply.Caption := Format(
      'Apply Selected (%d/%d)',
      [FAcceptedBlockCount, FTotalBlockCount]
    );
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFormAIDiff.TryStartRefactoring;
begin
  if FRequestStarted or not FBrowserInitialized or not FPageReady then
    Exit;

  FRequestStarted := True;
  FRequestFinished := False;
  RequestRefactoring;
end;

procedure TRadIAFormAIDiff.RequestTimeoutElapsed(Sender: TObject);
begin
  FRequestTimeoutTimer.Enabled := False;

  if FRequestFinished then
    Exit;

  FRequestFinished := True;
  FCanApply := False;
  FAIService.CancelCurrentRequest;
  FSuggestedCode := '// Error requesting refactoring: provider response timed out.' +
    #13#10 + FOriginalCode;
  RenderDiffInBrowser;
end;

function TRadIAFormAIDiff.CleanSuggestedCode(const AResponse: string): string;
var
  LLines: TStringList;
  I: Integer;
  LLine: string;
begin
  Result := AResponse.Trim;

  LLines := TStringList.Create;
  try
    LLines.Text := Result;

    I := LLines.Count - 1;
    while I >= 0 do
    begin
      LLine := LLines[I].Trim;
      if LLine.StartsWith('```') or SameText(LLine, 'Delphi') or SameText(LLine, 'Pascal') then
        LLines.Delete(I);
      Dec(I);
    end;

    while (LLines.Count > 0) and LLines[0].Trim.IsEmpty do
      LLines.Delete(0);

    while (LLines.Count > 0) and LLines[LLines.Count - 1].Trim.IsEmpty do
      LLines.Delete(LLines.Count - 1);

    Result := LLines.Text.Trim;
  finally
    LLines.Free;
  end;
end;

procedure TRadIAFormAIDiff.RequestRefactoring;
var
  LPrompt: string;
  LGuard: IRadIALifecycleGuard;
  LActiveProvider: string;
begin
  LActiveProvider := FConfig.GetActiveProvider;
  if (not FConfig.IsWebLoginProvider(LActiveProvider)) and
     (SameText(LActiveProvider, 'Gemini') or SameText(LActiveProvider, 'OpenAI')) and
     FConfig.GetApiKey(LActiveProvider).Trim.IsEmpty then
  begin
    FRequestFinished := True;
    FCanApply := False;
    FSuggestedCode := '// Error requesting refactoring: ' +
      'Provider is configured for API key authentication, but no API key is saved. ' +
      'Open Rad IA settings, select Web Login for ' + LActiveProvider +
      ', complete login, and save settings.' + #13#10 + FOriginalCode;
    RenderDiffInBrowser;
    Exit;
  end;

  LPrompt := 'Refactor and optimize the following Delphi Pascal code. ' +
             'Ensure it follows clean code principles, SOLID, and Delphi performance best practices. ' +
             'Preserve valid Delphi formatting and indentation using two spaces per indentation level. ' +
             'Return the complete refactored source in exactly one fenced code block using pascal as ' +
             'the language. Do not place any text before or after the fenced code block. ' +
             'Do not split the source into multiple code blocks or explanations.' +
             #13#10'Here is the code:'#13#10 + FOriginalCode;

  LGuard := FLifecycleGuard as IRadIALifecycleGuard;

  FRequestTimeoutTimer.Enabled := True;

  FAIService.SendPrompt(LPrompt, [],
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    var
      LCleanedResponse: string;
    begin
      if not LGuard.IsAlive then
        Exit;

      if FRequestFinished then
        Exit;

      FRequestFinished := True;
      FRequestTimeoutTimer.Enabled := False;

      if not AError.IsEmpty then
      begin
        FCanApply := False;
        FSuggestedCode := '// Error requesting refactoring: ' + AError + #13#10 + FOriginalCode;
      end
      else
      begin
        LCleanedResponse := CleanSuggestedCode(AResponse);

        FCanApply := not LCleanedResponse.Trim.IsEmpty;
        FSuggestedCode := LCleanedResponse.Trim;
      end;

      TThread.Queue(nil,
        procedure
        begin
          if LGuard.IsAlive then
            RenderDiffInBrowser;
        end);
    end, rpRefactorCode);
end;

procedure TRadIAFormAIDiff.btnPrevConflictClick(Sender: TObject);
var
  LJson: TJSONObject;
begin
  if not FBrowserInitialized then Exit;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'navigate');
    LJson.AddPair('direction', 'prev');
    if Assigned(EdgeBrowser.DefaultInterface) then
      EdgeBrowser.DefaultInterface.PostWebMessageAsJson(PChar(LJson.ToJSON));
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFormAIDiff.btnNextConflictClick(Sender: TObject);
var
  LJson: TJSONObject;
begin
  if not FBrowserInitialized then Exit;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'navigate');
    LJson.AddPair('direction', 'next');
    if Assigned(EdgeBrowser.DefaultInterface) then
      EdgeBrowser.DefaultInterface.PostWebMessageAsJson(PChar(LJson.ToJSON));
  finally
    LJson.Free;
  end;
end;

end.
