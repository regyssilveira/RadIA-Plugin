unit RadIA.UI.ChatFrame;

interface

uses  Winapi.Messages, System.SysUtils, System.Classes,
  Winapi.WebView2,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.Edge, Vcl.Menus, Vcl.Buttons, RadIA.Core.Sessions, RadIA.UI.Resources,
  RadIA.UI.ChatPresenter, RadIA.Core.WebViewLifecycle;

type
  TRadIAEdgeBrowserAccess = class(TEdgeBrowser);

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
    procedure EdgeBrowserNavigationCompleted(
      Sender: TCustomEdgeBrowser;
      IsSuccess: Boolean;
      WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS
    );
    procedure EdgeBrowserNavigationStarting(Sender: TCustomEdgeBrowser; Args: TNavigationStartingEventArgs);
    procedure EdgeBrowserProcessFailed(
      Sender: TCustomEdgeBrowser;
      ProcessFailedKind: COREWEBVIEW2_PROCESS_FAILED_KIND
    );
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
    FEdgeBrowser: TEdgeBrowser;
    FLayoutRefreshQueued: Boolean;
    FRecoveryQueued: Boolean;
    FWebViewSmokeEvidencePath: string;
    FWebViewSmokeStarted: Boolean;
    FConversationSmokeEvidencePath: string;
    FConversationSmokePrompt: string;
    FConversationSmokeStarted: Boolean;
    FCancellationSmokeEvidencePath: string;
    FCancellationSmokeStarted: Boolean;
    FProviderRecoverySmokeEvidencePath: string;
    FProviderRecoverySmokeStarted: Boolean;
    FAgentBudgetSmokeEvidencePath: string;
    FAgentBudgetSmokeStarted: Boolean;
    FNaturalVclSmokeEvidencePath: string;
    FNaturalVclRecoveryVisible: Boolean;
    FNaturalVclSmokeStarted: Boolean;
    FSessionIsolationSmokeEvidencePath: string;
    FSessionIsolationSmokeStarted: Boolean;
    FWebStateJson: string;
    FWebViewLifecycle: TRadIAWebViewLifecycle;

    procedure UpdateWebViewNavigation;
    function TryOpenLocalLinkInIDE(const AFileName: string): Boolean;
    procedure UpdateSendButtonVisual(const AInProgress: Boolean);
    function GetCurrentIDEThemeName: string;
    function GetWebThemeName(const AThemeName: string): string;
    function ColorToHex(AColor: TColor): string;
    procedure CreateEdgeBrowser;
    procedure DetachEdgeBrowser(const AReleaseWindow: Boolean);
    procedure RefreshEdgeBrowserBounds;
    procedure EnsureMainWebView;
    procedure RefreshBrowserLayout;
    procedure RecreateWebView;
    procedure ScheduleWebViewRecovery(const AFailure: string);
    function IsExpectedWebMessageSource(const AArgs: TWebMessageReceivedEventArgs): Boolean;
    function CaptureWebViewState(const AJson: string): Boolean;
    function ContinueWebViewLifecycleSmoke(const AJson: string): Boolean;
    function CaptureWebViewSmokeResult(const AJson: string): Boolean;
    function CaptureConversationSmokeResult(const AJson: string): Boolean;
    function CaptureCancellationSmokeResult(const AJson: string): Boolean;
    function CaptureProviderRecoverySmokeResult(const AJson: string): Boolean;
    function CaptureAgentBudgetSmokeResult(const AJson: string): Boolean;
    function CaptureNaturalVclSmokeResult(const AJson: string): Boolean;
    function CaptureSessionIsolationSmokeResult(const AJson: string): Boolean;
    procedure ProcessWebPayload(const AJson: string);
    procedure RestoreWebViewState;
    procedure RunWebViewLifecycleSmoke;
    procedure RunConversationSmoke;
    procedure RunCancellationSmoke;
    procedure RunProviderRecoverySmoke;
    procedure RunAgentBudgetSmoke;
    procedure RunNaturalVclSmoke;
    procedure RunSessionIsolationSmoke;
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
  System.IOUtils, System.JSON, System.Math, System.NetEncoding, System.StrUtils,
  ToolsAPI, RadIA.OTA.Helper,
  RadIA.UI.ConfigForm,
  RadIA.Core.Mediator, RadIA.Core.Logger, RadIA.Core.Container,
  Winapi.ActiveX, RadIA.Core.ProviderRegistry, RadIA.Core.Types, Winapi.Windows,
  Winapi.ShellAPI, RadIA.Core.Interfaces, RadIA.OTA.DockableForm,
  RadIA.UI.ExtensionManagerForm, RadIA.Core.TokenUsage, RadIA.Core.Cache,
  RadIA.Core.HierarchicalSettings;

{$R *.dfm}

const
  CWebViewScrollbarStyleId = 'radia-scrollbar-style';

type
  TRadIAConversationSmokeService = class(TInterfacedObject, IRadIAService)
  private
    function TrySendNaturalVclPrompt(
      const APrompt: string;
      const ACallback: TCompletionCallback
    ): Boolean;
    function TrySendAgentBudgetPrompt(
      const APrompt: string;
      const ACallback: TCompletionCallback
    ): Boolean;
  public
    function GetEffectiveSystemPrompt: string;
    procedure ResolveParameters(const AProviderName: string;
      const AProfile: TAIRequestProfile; out ATemperature: Double;
      out AMaxTokens: Integer);
    function CreateActiveProvider: IRadIAProvider;
    function TrimHistory(const AHistory: TArray<IRadIAChatMessage>):
      TArray<IRadIAChatMessage>;
    procedure SendPrompt(const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback;
      const AProfile: TAIRequestProfile = rpGeneralChat);
    procedure SendPromptStream(const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback;
      const AProfile: TAIRequestProfile = rpGeneralChat);
    procedure SendPromptStreamWithSettings(const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback;
      const AProfile: TAIRequestProfile;
      const ASettings: TRadIAExecutionSettings);
    procedure CancelCurrentRequest;
    procedure ClearCache;
    function ListCacheEntries: TArray<TRadIACacheEntrySnapshot>;
    function RemoveCacheEntry(const AHash: string): Boolean;
  end;

procedure TRadIAConversationSmokeService.CancelCurrentRequest;
begin
  if True then ; // The pending deterministic smoke callback is intentionally discarded.
end;

procedure TRadIAConversationSmokeService.ClearCache;
begin
  if True then ; // The smoke service has no cache.
end;

function TRadIAConversationSmokeService.CreateActiveProvider: IRadIAProvider;
begin
  Result := nil;
end;

function TRadIAConversationSmokeService.GetEffectiveSystemPrompt: string;
begin
  Result := '';
end;

function TRadIAConversationSmokeService.ListCacheEntries:
  TArray<TRadIACacheEntrySnapshot>;
begin
  Result := [];
end;

function ParseAgentCurrentState(const APrompt: string): TJSONObject;
var
  LMarkerPosition: Integer;
  LStateText: string;
  LValue: TJSONValue;
begin
  Result := nil;
  LMarkerPosition := APrompt.IndexOf('CURRENT_STATE:');
  if LMarkerPosition < 0 then
    Exit;
  LStateText := Trim(APrompt.Substring(
    LMarkerPosition + Length('CURRENT_STATE:')
  ));
  LValue := TJSONObject.ParseJSONValue(LStateText);
  if LValue is TJSONObject then
    Result := TJSONObject(LValue)
  else
    LValue.Free;
end;

function AgentStatePlanApproved(const APrompt: string): Boolean;
var
  LState: TJSONObject;
begin
  LState := ParseAgentCurrentState(APrompt);
  try
    Result := Assigned(LState) and
      LState.GetValue<Boolean>('planApproved', False);
  finally
    LState.Free;
  end;
end;

function FindSuccessfulAgentToolStep(
  const APrompt: string;
  const AToolName: string
): TJSONObject;
var
  LItem: TJSONValue;
  LState: TJSONObject;
  LSteps: TJSONArray;
  LStep: TJSONObject;
begin
  Result := nil;
  LState := ParseAgentCurrentState(APrompt);
  if not Assigned(LState) then
    Exit;
  try
    LSteps := LState.GetValue<TJSONArray>('steps');
    if not Assigned(LSteps) then
      Exit;
    for LItem in LSteps do
      if LItem is TJSONObject then
      begin
        LStep := TJSONObject(LItem);
        if SameText(LStep.GetValue<string>('toolName', ''), AToolName) and
          LStep.GetValue<Boolean>('success', False) then
          Exit(TJSONObject.ParseJSONValue(LStep.ToJSON) as TJSONObject);
      end;
  finally
    LState.Free;
  end;
end;

function AgentStateHasSuccessfulTool(
  const APrompt: string;
  const AToolName: string
): Boolean;
var
  LStep: TJSONObject;
begin
  LStep := FindSuccessfulAgentToolStep(APrompt, AToolName);
  try
    Result := Assigned(LStep);
  finally
    LStep.Free;
  end;
end;

function AgentStateObjectiveContains(
  const APrompt: string;
  const AValue: string
): Boolean;
var
  LState: TJSONObject;
begin
  LState := ParseAgentCurrentState(APrompt);
  try
    Result := Assigned(LState) and
      LState.GetValue<string>('objective', '').Contains(AValue);
  finally
    LState.Free;
  end;
end;

function AgentStateHasFailedTool(
  const APrompt: string;
  const AToolName: string
): Boolean;
var
  LIndex: Integer;
  LState: TJSONObject;
  LSteps: TJSONArray;
  LStep: TJSONObject;
begin
  Result := False;
  LState := ParseAgentCurrentState(APrompt);
  if not Assigned(LState) then
    Exit;
  try
    LSteps := LState.GetValue<TJSONArray>('steps');
    if not Assigned(LSteps) then
      Exit;
    for LIndex := LSteps.Count - 1 downto 0 do
      if LSteps[LIndex] is TJSONObject then
      begin
        LStep := TJSONObject(LSteps[LIndex]);
        if SameText(LStep.GetValue<string>('toolName', ''), AToolName) and
          not LStep.GetValue<Boolean>('success', True) then
          Exit(True);
      end;
  finally
    LState.Free;
  end;
end;

function AgentStateHasSuccessfulToolDestination(
  const APrompt: string;
  const AToolName: string;
  const ADestination: string
): Boolean; forward;

function NaturalVclPreviewReady(
  const APrompt: string;
  const ARetryDestination: string;
  const ARecoveryRun: Boolean
): Boolean;
begin
  if ARecoveryRun then
    Exit(AgentStateHasSuccessfulToolDestination(
      APrompt,
      'PreviewProjectTemplate',
      ARetryDestination
    ));
  Result := AgentStateHasSuccessfulTool(APrompt, 'PreviewProjectTemplate');
end;

function AgentStateHasSuccessfulToolDestination(
  const APrompt: string;
  const AToolName: string;
  const ADestination: string
): Boolean;
var
  LArguments: TJSONObject;
  LStep: TJSONObject;
begin
  Result := False;
  LStep := FindSuccessfulAgentToolStep(APrompt, AToolName);
  if not Assigned(LStep) then
    Exit;
  try
    LArguments := TJSONObject.ParseJSONValue(
      LStep.GetValue<string>('arguments', '')
    ) as TJSONObject;
    try
      Result := Assigned(LArguments) and SameText(
        LArguments.GetValue<string>('destinationPath', ''),
        ADestination
      );
    finally
      LArguments.Free;
    end;
  finally
    LStep.Free;
  end;
end;

function AgentToolResultString(
  const APrompt: string;
  const AToolName: string;
  const APropertyName: string
): string;
var
  LResultJson: TJSONValue;
  LStep: TJSONObject;
begin
  Result := '';
  LStep := FindSuccessfulAgentToolStep(APrompt, AToolName);
  if not Assigned(LStep) then
    Exit;
  try
    LResultJson := TJSONObject.ParseJSONValue(
      LStep.GetValue<string>('result', '')
    );
    try
      if LResultJson is TJSONObject then
        Result := TJSONObject(LResultJson).GetValue<string>(
          APropertyName,
          ''
        );
    finally
      LResultJson.Free;
    end;
  finally
    LStep.Free;
  end;
end;

function JsonQuoted(const AValue: string): string;
var
  LJson: TJSONString;
begin
  LJson := TJSONString.Create(AValue);
  try
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function TRadIAConversationSmokeService.RemoveCacheEntry(
  const AHash: string
): Boolean;
begin
  Result := False;
end;

procedure TRadIAConversationSmokeService.ResolveParameters(
  const AProviderName: string;
  const AProfile: TAIRequestProfile;
  out ATemperature: Double;
  out AMaxTokens: Integer
);
begin
  ATemperature := 0;
  AMaxTokens := 64;
end;

procedure TRadIAConversationSmokeService.SendPrompt(
  const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TCompletionCallback;
  const AProfile: TAIRequestProfile
);
begin
  if TrySendNaturalVclPrompt(APrompt, ACallback) then
    Exit;
  if TrySendAgentBudgetPrompt(APrompt, ACallback) then
    Exit;
  ACallback(
    'I am RadIA, your Delphi development assistant.',
    '',
    False,
    TTokenUsage.Empty
  );
end;

function TRadIAConversationSmokeService.TrySendNaturalVclPrompt(
  const APrompt: string;
  const ACallback: TCompletionCallback
): Boolean;
var
  LDestination: string;
  LPreviewReady: Boolean;
  LRecoveryRun: Boolean;
  LRetryDestination: string;
begin
  Result :=
    (Trim(GetEnvironmentVariable('RADIA_IDE_SMOKE_NATURAL_VCL')) <> '') and
    APrompt.Contains('CURRENT_STATE:');
  if not Result then
    Exit;
  LDestination := GetEnvironmentVariable(
    'RADIA_IDE_SMOKE_NATURAL_VCL_DESTINATION'
  );
  LRetryDestination := GetEnvironmentVariable(
    'RADIA_IDE_SMOKE_NATURAL_VCL_RETRY_DESTINATION'
  );
  if not LRetryDestination.IsEmpty and
    AgentStateObjectiveContains(APrompt, LRetryDestination) then
    LDestination := LRetryDestination;
  LRecoveryRun := SameText(LDestination, LRetryDestination) and
    not LRetryDestination.IsEmpty;
  LPreviewReady := NaturalVclPreviewReady(
    APrompt,
    LRetryDestination,
    LRecoveryRun
  );
  if not AgentStatePlanApproved(APrompt) then
    ACallback(
        '{"kind":"plan","message":"Create and validate the VCL project.",' +
        '"steps":[{"title":"Create project",' +
        '"description":"Preview, create, open, inspect, and build"}]}',
        '',
        False,
        TTokenUsage.Empty
      )
    else if not LPreviewReady then
      ACallback(
        '{"kind":"tool","tool":"PreviewProjectTemplate","arguments":{' +
        '"projectName":"RadIAUserCalculator","template":"vcl",' +
        '"delphiVersion":' + JsonQuoted(GetEnvironmentVariable(
          'RADIA_IDE_SMOKE_DELPHI_VERSION'
        )) + ',"platforms":[' + JsonQuoted(GetEnvironmentVariable(
          'RADIA_IDE_SMOKE_TARGET_PLATFORM'
        )) + '],"destinationPath":' + JsonQuoted(LDestination) +
        ',"authorizedRoot":' + JsonQuoted(GetEnvironmentVariable(
          'RADIA_IDE_SMOKE_NATURAL_VCL_ROOT'
        )) + ',"projectSpecification":{"schemaVersion":1,' +
        '"kind":"calculator","creationProfile":"essential"}}}',
        '',
        False,
        TTokenUsage.Empty
      )
    else if AgentStateHasFailedTool(
      APrompt,
      'CreateProjectFromTemplate'
    ) and not LRecoveryRun then
      ACallback(
        '{"kind":"fail","message":"Choose another destination."}',
        '',
        False,
        TTokenUsage.Empty
      )
    else if not AgentStateHasSuccessfulTool(
      APrompt,
      'CreateProjectFromTemplate'
    ) then
      ACallback(
        '{"kind":"tool","tool":"CreateProjectFromTemplate",' +
        '"arguments":{"previewId":' + JsonQuoted(
          AgentToolResultString(
            APrompt,
            'PreviewProjectTemplate',
            'previewId'
          )
        ) + '}}',
        '',
        False,
        TTokenUsage.Empty
      )
    else if not AgentStateHasSuccessfulTool(
      APrompt,
      'OpenCreatedProject'
    ) then
      ACallback(
        '{"kind":"tool","tool":"OpenCreatedProject",' +
        '"arguments":{"previewId":' + JsonQuoted(
          AgentToolResultString(
            APrompt,
            'PreviewProjectTemplate',
            'previewId'
          )
        ) + '}}',
        '',
        False,
        TTokenUsage.Empty
      )
    else if not AgentStateHasSuccessfulTool(APrompt, 'BuildProject') then
      ACallback(
        '{"kind":"tool","tool":"BuildProject",' +
        '"arguments":{"mode":"build","timeoutMs":600000,' +
        '"clearMessages":true}}',
        '',
        False,
        TTokenUsage.Empty
      )
    else
      ACallback(
        '{"kind":"complete","message":"Project created, inspected, and built."}',
        '',
        False,
        TTokenUsage.Empty
      );
end;

function TRadIAConversationSmokeService.TrySendAgentBudgetPrompt(
  const APrompt: string;
  const ACallback: TCompletionCallback
): Boolean;
begin
  Result :=
    (Trim(GetEnvironmentVariable('RADIA_IDE_SMOKE_AGENT_BUDGET')) <> '') and
    APrompt.Contains('CURRENT_STATE:');
  if not Result then
    Exit;
  if not AgentStatePlanApproved(APrompt) then
    ACallback(
        '{"kind":"plan","message":"Approve IDE inspection.",' +
        '"steps":[{"title":"Inspect IDE",' +
        '"description":"Read the current IDE state once"}]}',
        '',
        False,
        TTokenUsage.Empty
      )
    else if not AgentStateHasSuccessfulTool(APrompt, 'GetIDEState') then
      ACallback(
        '{"kind":"tool","tool":"GetIDEState","arguments":{}}',
        '',
        False,
        TTokenUsage.Empty
      )
    else
      ACallback(
        '{"kind":"complete","message":"IDE inspection completed."}',
        '',
        False,
        TTokenUsage.Empty
      );
end;

procedure TRadIAConversationSmokeService.SendPromptStream(
  const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TStreamChunkCallback;
  const AProfile: TAIRequestProfile
);
begin
  if APrompt.Contains('Wait for cancellation.') then
    Exit;
  if APrompt.Contains('Simulate provider timeout.') then
  begin
    ACallback('', True, 'RADIA_INTERNAL_PROVIDER_EXCEPTION timeout');
    Exit;
  end;
  ACallback('I am RadIA, your Delphi development assistant.', True, '');
end;

procedure TRadIAConversationSmokeService.SendPromptStreamWithSettings(
  const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>;
  const ACallback: TStreamChunkCallback;
  const AProfile: TAIRequestProfile;
  const ASettings: TRadIAExecutionSettings
);
begin
  SendPromptStream(APrompt, AHistory, ACallback, AProfile);
end;

function TRadIAConversationSmokeService.TrimHistory(
  const AHistory: TArray<IRadIAChatMessage>
): TArray<IRadIAChatMessage>;
begin
  Result := Copy(AHistory);
end;

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

procedure TRadIAFrameAIChat.RefreshEdgeBrowserBounds;
begin
  if Assigned(FEdgeBrowser) then
    TRadIAEdgeBrowserAccess(FEdgeBrowser).Resize;
end;

constructor TRadIAFrameAIChat.Create(AOwner: TComponent);
var
  LDataDir: string;
  LService: IRadIAService;
  LThemingServices: IOTAIDEThemingServices;
begin
  inherited Create(AOwner);
  FBrowserInitialized := False;
  FWebViewInitialized := False;
  FLayoutRefreshQueued := False;
  FRecoveryQueued := False;
  FWebViewSmokeEvidencePath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_WEBVIEW_LIFECYCLE')
  );
  FWebViewSmokeStarted := False;
  FConversationSmokeEvidencePath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_CONVERSATION')
  );
  FConversationSmokeStarted := False;
  FConversationSmokePrompt := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_CONVERSATION_PROMPT')
  );
  if FConversationSmokePrompt = '' then
    FConversationSmokePrompt := 'Who are you?';
  FCancellationSmokeEvidencePath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_CANCELLATION')
  );
  FCancellationSmokeStarted := False;
  FProviderRecoverySmokeEvidencePath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_PROVIDER_RECOVERY')
  );
  FProviderRecoverySmokeStarted := False;
  FAgentBudgetSmokeEvidencePath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_AGENT_BUDGET')
  );
  FAgentBudgetSmokeStarted := False;
  FNaturalVclSmokeEvidencePath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_NATURAL_VCL')
  );
  FNaturalVclSmokeStarted := False;
  FNaturalVclRecoveryVisible := False;
  FSessionIsolationSmokeEvidencePath := Trim(
    GetEnvironmentVariable('RADIA_IDE_SMOKE_SESSION_ISOLATION')
  );
  FSessionIsolationSmokeStarted := False;
  FWebStateJson := '{}';
  FWebViewLifecycle := TRadIAWebViewLifecycle.Create(2);

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

  if (FConversationSmokeEvidencePath <> '') or
    (FCancellationSmokeEvidencePath <> '') or
    (FProviderRecoverySmokeEvidencePath <> '') or
    (FAgentBudgetSmokeEvidencePath <> '') or
    (FNaturalVclSmokeEvidencePath <> '') or
    (FSessionIsolationSmokeEvidencePath <> '') then
  begin
    LDataDir := TPath.Combine(
      TPath.GetTempPath,
      'RadIA-Conversation-Smoke'
    );
    LService := TRadIAConversationSmokeService.Create;
    FPresenter := TRadIAChatPresenter.Create(Self, nil, LService, LDataDir);
  end
  else
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
    DetachEdgeBrowser(True);
    FreeAndNil(FEdgeBrowser);
    FreeAndNil(pnlBrowser);
  end
  else
  begin
    DetachEdgeBrowser(False);
    FEdgeBrowser := nil;
  end;
end;

procedure TRadIAFrameAIChat.DetachEdgeBrowser(
  const AReleaseWindow: Boolean
);
begin
  if Assigned(FEdgeBrowser) then
  begin
    FEdgeBrowser.OnCreateWebViewCompleted := nil;
    FEdgeBrowser.OnNavigationCompleted := nil;
    FEdgeBrowser.OnNavigationStarting := nil;
    FEdgeBrowser.OnProcessFailed := nil;
    FEdgeBrowser.OnWebMessageReceived := nil;
    if AReleaseWindow then
    begin
      FEdgeBrowser.CloseWebView;
      FEdgeBrowser.Parent := nil;
    end;
  end;
end;

destructor TRadIAFrameAIChat.Destroy;
begin
  UnregisterHandlers;
  FWebViewLifecycle.Stop;
  CleanupUIComponents;
  FPresenter.Free;
  CleanupBrowsers;
  FWebViewLifecycle.Free;

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
    FEdgeBrowser := TEdgeBrowser.Create(nil);
    FEdgeBrowser.Parent := pnlBrowser;
    FEdgeBrowser.Align := alClient;
    FEdgeBrowser.AlignWithMargins := True;
    FEdgeBrowser.OnCreateWebViewCompleted := EdgeBrowserCreateWebViewCompleted;
    FEdgeBrowser.OnNavigationCompleted := EdgeBrowserNavigationCompleted;
    FEdgeBrowser.OnNavigationStarting := EdgeBrowserNavigationStarting;
    FEdgeBrowser.OnProcessFailed := EdgeBrowserProcessFailed;
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
    FWebViewLifecycle.BeginCreate;
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
        RefreshEdgeBrowserBounds;
      end
    )
  );
end;

procedure TRadIAFrameAIChat.RecreateWebView;
begin
  if GIsShuttingDown or not Assigned(FEdgeBrowser) then
    Exit;
  FBrowserInitialized := False;
  FWebViewInitialized := False;
  FPresenter.WebViewReady := False;
  FWebViewLifecycle.BeginCreate;
  FEdgeBrowser.ReinitializeWebView;
end;

procedure TRadIAFrameAIChat.ScheduleWebViewRecovery(
  const AFailure: string
);
var
  LGuard: IRadIALifecycleGuard;
  LSnapshot: TRadIAWebViewLifecycleSnapshot;
begin
  if FRecoveryQueued or GIsShuttingDown then
    Exit;
  if not FWebViewLifecycle.RegisterFailure(GIsShuttingDown) then
  begin
    pnlBrowser.Caption :=
      'RadIA Chat could not recover WebView2. Reopen the chat window.';
    TLogger.Log('WebView recovery limit reached: ' + AFailure, 'UI');
    Exit;
  end;
  FRecoveryQueued := True;
  LSnapshot := FWebViewLifecycle.Snapshot;
  pnlBrowser.Caption := Format(
    'Recovering RadIA Chat (%d/2)...',
    [LSnapshot.RecoveryAttempts]
  );
  TLogger.Log('Scheduling bounded WebView recovery: ' + AFailure, 'UI');
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  TThread.ForceQueue(
    nil,
    TThreadProcedure(
      procedure
      begin
        if not LGuard.IsAlive or GIsShuttingDown then
          Exit;
        FRecoveryQueued := False;
        if not HandleAllocated then
          Exit;
        RecreateWebView;
      end
    )
  );
end;

procedure TRadIAFrameAIChat.DestroyWnd;
begin
  FBrowserInitialized := False;
  FWebViewInitialized := False;
  FLayoutRefreshQueued := False;

  if Assigned(FEdgeBrowser) then
  begin
    DetachEdgeBrowser(not GIsShuttingDown);
    if not GIsShuttingDown then
      FreeAndNil(FEdgeBrowser)
    else
      FEdgeBrowser := nil;
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
    FWebViewLifecycle.BeginNavigation;
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
  if Sender <> FEdgeBrowser then
    Exit;
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
    TLogger.Log('EdgeBrowserCreateWebViewCompleted failed for main chat WebView. HRESULT: ' +
      IntToHex(AResult, 8), 'UI');
    ScheduleWebViewRecovery('create HRESULT ' + IntToHex(AResult, 8));
  end;
end;

procedure TRadIAFrameAIChat.EdgeBrowserNavigationCompleted(
  Sender: TCustomEdgeBrowser;
  IsSuccess: Boolean;
  WebErrorStatus: COREWEBVIEW2_WEB_ERROR_STATUS
);
begin
  if Sender <> FEdgeBrowser then
    Exit;
  if IsSuccess then
  begin
    FWebViewLifecycle.MarkReady;
    pnlBrowser.Caption := '';
    Exit;
  end;
  ScheduleWebViewRecovery(
    'navigation status ' + IntToStr(Ord(WebErrorStatus))
  );
end;

procedure TRadIAFrameAIChat.EdgeBrowserProcessFailed(
  Sender: TCustomEdgeBrowser;
  ProcessFailedKind: COREWEBVIEW2_PROCESS_FAILED_KIND
);
begin
  if Sender <> FEdgeBrowser then
    Exit;
  ScheduleWebViewRecovery(
    'process kind ' + IntToStr(Ord(ProcessFailedKind))
  );
end;

procedure TRadIAFrameAIChat.EdgeBrowserWebMessageReceived(Sender: TCustomEdgeBrowser;
    Args: TWebMessageReceivedEventArgs);
var
  LStr: PWideChar;
  LJsonStr: PWideChar;
begin
  if Assigned(Args.ArgsInterface) and IsExpectedWebMessageSource(Args) then
  begin
    if Succeeded(Args.ArgsInterface.TryGetWebMessageAsString(LStr)) then
    begin
      try
        ProcessWebPayload(string(LStr));
      finally
        CoTaskMemFree(LStr);
      end;
    end
    else
    begin
      Args.ArgsInterface.Get_webMessageAsJson(LJsonStr);
      try
        ProcessWebPayload(string(LJsonStr));
      finally
        CoTaskMemFree(LJsonStr);
      end;
    end;
  end;
end;

function TRadIAFrameAIChat.CaptureWebViewState(
  const AJson: string
): Boolean;
const
  CMaximumDraftLength = 12000;
  CMaximumScrollTop = 10000000;
var
  LAdvanced: Boolean;
  LDraft: string;
  LJson: TJSONValue;
  LRoot: TJSONObject;
  LScrollTop: Integer;
  LState: TJSONObject;
  LStateValue: TJSONValue;
  LStoredState: TJSONObject;
begin
  Result := False;
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LJson);
    if SameText(
      LRoot.GetValue<string>('action', ''),
      'natural_vcl_recovery_visible'
    ) then
    begin
      FNaturalVclRecoveryVisible := True;
      Exit(True);
    end;
    if not SameText(
      LRoot.GetValue<string>('action', ''),
      'webview_lifecycle_state'
    ) then
      Exit;
    Result := True;
    LStateValue := LRoot.GetValue('state');
    if not (LStateValue is TJSONObject) then
      Exit;
    LState := TJSONObject(LStateValue);
    LDraft := LState.GetValue<string>('draft', '');
    LDraft := LDraft.Substring(0, Min(LDraft.Length, CMaximumDraftLength));
    LScrollTop := EnsureRange(
      LState.GetValue<Integer>('scrollTop', 0),
      0,
      CMaximumScrollTop
    );
    LAdvanced := LState.GetValue<Boolean>('advanced', False);
    LStoredState := TJSONObject.Create;
    try
      LStoredState.AddPair('draft', LDraft);
      LStoredState.AddPair('scrollTop', TJSONNumber.Create(LScrollTop));
      LStoredState.AddPair('advanced', TJSONBool.Create(LAdvanced));
      FWebStateJson := LStoredState.ToJSON;
    finally
      LStoredState.Free;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.ProcessWebPayload(const AJson: string);
var
  LAction: string;
  LJson: TJSONValue;
begin
  if CaptureWebViewState(AJson) then
    Exit;
  if ContinueWebViewLifecycleSmoke(AJson) then
    Exit;
  if CaptureWebViewSmokeResult(AJson) then
    Exit;
  if CaptureConversationSmokeResult(AJson) then
    Exit;
  if CaptureCancellationSmokeResult(AJson) then
    Exit;
  if CaptureProviderRecoverySmokeResult(AJson) then
    Exit;
  if CaptureAgentBudgetSmokeResult(AJson) then
    Exit;
  if CaptureNaturalVclSmokeResult(AJson) then
    Exit;
  if CaptureSessionIsolationSmokeResult(AJson) then
    Exit;
  LAction := '';
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if LJson is TJSONObject then
      LAction := TJSONObject(LJson).GetValue<string>('action', '');
  finally
    LJson.Free;
  end;
  FPresenter.ProcessWebMessage(AJson);
  if SameText(LAction, 'ready') then
  begin
    RestoreWebViewState;
    RunWebViewLifecycleSmoke;
    RunConversationSmoke;
    RunCancellationSmoke;
    RunProviderRecoverySmoke;
    RunAgentBudgetSmoke;
    RunNaturalVclSmoke;
    RunSessionIsolationSmoke;
  end;
end;

function TRadIAFrameAIChat.CaptureSessionIsolationSmokeResult(
  const AJson: string
): Boolean;
var
  LEvidenceDirectory: string;
  LJson: TJSONValue;
  LRoot: TJSONObject;
begin
  Result := False;
  if FSessionIsolationSmokeEvidencePath = '' then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LJson);
    if not SameText(
      LRoot.GetValue<string>('action', ''),
      'session_isolation_smoke_result'
    ) then
      Exit;
    Result := True;
    LEvidenceDirectory := ExtractFileDir(FSessionIsolationSmokeEvidencePath);
    if LEvidenceDirectory <> '' then
      ForceDirectories(LEvidenceDirectory);
    TFile.WriteAllText(
      FSessionIsolationSmokeEvidencePath,
      LRoot.ToJSON,
      TEncoding.UTF8
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAFrameAIChat.CaptureConversationSmokeResult(
  const AJson: string
): Boolean;
var
  LAnswerVisible: Boolean;
  LConsentVisible: Boolean;
  LDuration: Integer;
  LEvidence: TJSONObject;
  LEvidenceDirectory: string;
  LJson: TJSONValue;
  LPassed: Boolean;
  LPlanVisible: Boolean;
  LRoot: TJSONObject;
  LStepLimitReached: Boolean;
begin
  Result := False;
  if FConversationSmokeEvidencePath = '' then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LJson);
    if not SameText(
      LRoot.GetValue<string>('action', ''),
      'conversation_smoke_result'
    ) then
      Exit;
    Result := True;
    LAnswerVisible := LRoot.GetValue<Boolean>('answerVisible', False);
    LConsentVisible := LRoot.GetValue<Boolean>('consentVisible', False);
    LPlanVisible := LRoot.GetValue<Boolean>('planVisible', False);
    LStepLimitReached := LRoot.GetValue<Boolean>('stepLimitReached', False);
    LDuration := LRoot.GetValue<Integer>('elapsedMilliseconds', MaxInt);
    LPassed := SameText(LRoot.GetValue<string>('status', ''), 'passed') and
      LAnswerVisible and not LConsentVisible and not LPlanVisible and
      not LStepLimitReached and (LDuration <= 20000);
    LEvidence := TJSONObject.Create;
    try
      LEvidence.AddPair('schemaVersion', TJSONNumber.Create(1));
      LEvidence.AddPair('evidenceKind', 'directConversationSmoke');
      LEvidence.AddPair('status', IfThen(LPassed, 'passed', 'failed'));
      LEvidence.AddPair('answerVisible', TJSONBool.Create(LAnswerVisible));
      LEvidence.AddPair('planVisible', TJSONBool.Create(LPlanVisible));
      LEvidence.AddPair('consentVisible', TJSONBool.Create(LConsentVisible));
      LEvidence.AddPair(
        'stepLimitReached',
        TJSONBool.Create(LStepLimitReached)
      );
      LEvidence.AddPair('elapsedMilliseconds', TJSONNumber.Create(LDuration));
      LEvidence.AddPair('promptContentStored', TJSONBool.Create(False));
      LEvidence.AddPair('responseContentStored', TJSONBool.Create(False));
      LEvidenceDirectory := ExtractFileDir(FConversationSmokeEvidencePath);
      if LEvidenceDirectory <> '' then
        ForceDirectories(LEvidenceDirectory);
      TFile.WriteAllText(
        FConversationSmokeEvidencePath,
        LEvidence.ToJSON,
        TEncoding.UTF8
      );
    finally
      LEvidence.Free;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.RunConversationSmoke;
var
  LPromptJson: TJSONString;
begin
  if (FConversationSmokeEvidencePath = '') or
    FConversationSmokeStarted or not Assigned(FEdgeBrowser) then
    Exit;
  FConversationSmokeStarted := True;
  LPromptJson := TJSONString.Create(FConversationSmokePrompt);
  try
    FEdgeBrowser.ExecuteScript(
      'beginConversationSmoke(' + LPromptJson.ToJSON + ', 20000);'
    );
  finally
    LPromptJson.Free;
  end;
end;

function TRadIAFrameAIChat.CaptureCancellationSmokeResult(
  const AJson: string
): Boolean;
var
  LDuration: Integer;
  LEvidence: TJSONObject;
  LEvidenceDirectory: string;
  LIdeRestartRequired: Boolean;
  LJson: TJSONValue;
  LNextAnswerVisible: Boolean;
  LPassed: Boolean;
  LRequestCancelled: Boolean;
  LRoot: TJSONObject;
  LUiIdle: Boolean;
begin
  Result := False;
  if FCancellationSmokeEvidencePath = '' then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LJson);
    if not SameText(
      LRoot.GetValue<string>('action', ''),
      'cancellation_smoke_result'
    ) then
      Exit;
    Result := True;
    LRequestCancelled := LRoot.GetValue<Boolean>('requestCancelled', False);
    LUiIdle := LRoot.GetValue<Boolean>('uiIdle', False);
    LNextAnswerVisible := LRoot.GetValue<Boolean>('nextAnswerVisible', False);
    LIdeRestartRequired := LRoot.GetValue<Boolean>('ideRestartRequired', True);
    LDuration := LRoot.GetValue<Integer>('elapsedMilliseconds', MaxInt);
    LPassed := SameText(LRoot.GetValue<string>('status', ''), 'passed') and
      LRequestCancelled and LUiIdle and LNextAnswerVisible and
      not LIdeRestartRequired and (LDuration <= 90000);
    LEvidence := TJSONObject.Create;
    try
      LEvidence.AddPair('schemaVersion', TJSONNumber.Create(1));
      LEvidence.AddPair('evidenceKind', 'requestCancellationSmoke');
      LEvidence.AddPair('status', IfThen(LPassed, 'passed', 'failed'));
      LEvidence.AddPair(
        'requestCancelled',
        TJSONBool.Create(LRequestCancelled)
      );
      LEvidence.AddPair('uiIdle', TJSONBool.Create(LUiIdle));
      LEvidence.AddPair(
        'nextAnswerVisible',
        TJSONBool.Create(LNextAnswerVisible)
      );
      LEvidence.AddPair(
        'ideRestartRequired',
        TJSONBool.Create(LIdeRestartRequired)
      );
      LEvidence.AddPair('elapsedMilliseconds', TJSONNumber.Create(LDuration));
      LEvidenceDirectory := ExtractFileDir(FCancellationSmokeEvidencePath);
      if LEvidenceDirectory <> '' then
        ForceDirectories(LEvidenceDirectory);
      TFile.WriteAllText(
        FCancellationSmokeEvidencePath,
        LEvidence.ToJSON,
        TEncoding.UTF8
      );
    finally
      LEvidence.Free;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.RunCancellationSmoke;
begin
  if (FCancellationSmokeEvidencePath = '') or
    FCancellationSmokeStarted or not Assigned(FEdgeBrowser) then
    Exit;
  FCancellationSmokeStarted := True;
  FEdgeBrowser.ExecuteScript('beginCancellationSmoke(30000);');
end;

function TRadIAFrameAIChat.CaptureProviderRecoverySmokeResult(
  const AJson: string
): Boolean;
var
  LActionableErrorVisible: Boolean;
  LChatFrozen: Boolean;
  LDuration: Integer;
  LEvidence: TJSONObject;
  LEvidenceDirectory: string;
  LJson: TJSONValue;
  LPassed: Boolean;
  LRawExceptionVisible: Boolean;
  LRetrySucceeded: Boolean;
  LRoot: TJSONObject;
  LSessionPreserved: Boolean;
begin
  Result := False;
  if FProviderRecoverySmokeEvidencePath = '' then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LJson);
    if not SameText(
      LRoot.GetValue<string>('action', ''),
      'provider_recovery_smoke_result'
    ) then
      Exit;
    Result := True;
    LActionableErrorVisible := LRoot.GetValue<Boolean>(
      'actionableErrorVisible',
      False
    );
    LSessionPreserved := LRoot.GetValue<Boolean>('sessionPreserved', False);
    LRetrySucceeded := LRoot.GetValue<Boolean>('retrySucceeded', False);
    LRawExceptionVisible := LRoot.GetValue<Boolean>(
      'rawExceptionVisible',
      True
    );
    LChatFrozen := LRoot.GetValue<Boolean>('chatFrozen', True);
    LDuration := LRoot.GetValue<Integer>('elapsedMilliseconds', MaxInt);
    LPassed := SameText(LRoot.GetValue<string>('status', ''), 'passed') and
      LActionableErrorVisible and LSessionPreserved and LRetrySucceeded and
      not LRawExceptionVisible and not LChatFrozen and (LDuration <= 120000);
    LEvidence := TJSONObject.Create;
    try
      LEvidence.AddPair('schemaVersion', TJSONNumber.Create(1));
      LEvidence.AddPair('evidenceKind', 'providerRecoverySmoke');
      LEvidence.AddPair('status', IfThen(LPassed, 'passed', 'failed'));
      LEvidence.AddPair(
        'actionableErrorVisible',
        TJSONBool.Create(LActionableErrorVisible)
      );
      LEvidence.AddPair(
        'sessionPreserved',
        TJSONBool.Create(LSessionPreserved)
      );
      LEvidence.AddPair('retrySucceeded', TJSONBool.Create(LRetrySucceeded));
      LEvidence.AddPair(
        'rawExceptionVisible',
        TJSONBool.Create(LRawExceptionVisible)
      );
      LEvidence.AddPair('chatFrozen', TJSONBool.Create(LChatFrozen));
      LEvidence.AddPair('elapsedMilliseconds', TJSONNumber.Create(LDuration));
      LEvidenceDirectory := ExtractFileDir(FProviderRecoverySmokeEvidencePath);
      if LEvidenceDirectory <> '' then
        ForceDirectories(LEvidenceDirectory);
      TFile.WriteAllText(
        FProviderRecoverySmokeEvidencePath,
        LEvidence.ToJSON,
        TEncoding.UTF8
      );
    finally
      LEvidence.Free;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.RunProviderRecoverySmoke;
begin
  if (FProviderRecoverySmokeEvidencePath = '') or
    FProviderRecoverySmokeStarted or not Assigned(FEdgeBrowser) then
    Exit;
  FProviderRecoverySmokeStarted := True;
  FEdgeBrowser.ExecuteScript('beginProviderRecoverySmoke(60000);');
end;

function TRadIAFrameAIChat.CaptureAgentBudgetSmokeResult(
  const AJson: string
): Boolean;
var
  LBudgetRemaining: Boolean;
  LDuration: Integer;
  LEvidence: TJSONObject;
  LEvidenceDirectory: string;
  LJourneyCompleted: Boolean;
  LJson: TJSONValue;
  LPassed: Boolean;
  LPlanApproved: Boolean;
  LRepeatedReadOnlyLoop: Boolean;
  LRoot: TJSONObject;
  LStepCount: Integer;
  LStepLimitReached: Boolean;
begin
  Result := False;
  if FAgentBudgetSmokeEvidencePath = '' then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LJson);
    if not SameText(
      LRoot.GetValue<string>('action', ''),
      'agent_budget_smoke_result'
    ) then
      Exit;
    Result := True;
    LPlanApproved := LRoot.GetValue<Boolean>('planApproved', False);
    LJourneyCompleted := LRoot.GetValue<Boolean>('journeyCompleted', False);
    LBudgetRemaining := LRoot.GetValue<Boolean>('budgetRemaining', False);
    LRepeatedReadOnlyLoop := LRoot.GetValue<Boolean>(
      'repeatedReadOnlyLoop',
      True
    );
    LStepLimitReached := LRoot.GetValue<Boolean>('stepLimitReached', True);
    LStepCount := LRoot.GetValue<Integer>('stepCount', MaxInt);
    LDuration := LRoot.GetValue<Integer>('elapsedMilliseconds', MaxInt);
    LPassed := SameText(LRoot.GetValue<string>('status', ''), 'passed') and
      LPlanApproved and LJourneyCompleted and LBudgetRemaining and
      not LRepeatedReadOnlyLoop and not LStepLimitReached and
      (LDuration <= 300000);
    LEvidence := TJSONObject.Create;
    try
      LEvidence.AddPair('schemaVersion', TJSONNumber.Create(1));
      LEvidence.AddPair('evidenceKind', 'agentStepBudgetSmoke');
      LEvidence.AddPair('status', IfThen(LPassed, 'passed', 'failed'));
      LEvidence.AddPair('planApproved', TJSONBool.Create(LPlanApproved));
      LEvidence.AddPair(
        'journeyCompleted',
        TJSONBool.Create(LJourneyCompleted)
      );
      LEvidence.AddPair(
        'budgetRemaining',
        TJSONBool.Create(LBudgetRemaining)
      );
      LEvidence.AddPair(
        'repeatedReadOnlyLoop',
        TJSONBool.Create(LRepeatedReadOnlyLoop)
      );
      LEvidence.AddPair(
        'stepLimitReached',
        TJSONBool.Create(LStepLimitReached)
      );
      LEvidence.AddPair('stepCount', TJSONNumber.Create(LStepCount));
      LEvidence.AddPair('elapsedMilliseconds', TJSONNumber.Create(LDuration));
      LEvidenceDirectory := ExtractFileDir(FAgentBudgetSmokeEvidencePath);
      if LEvidenceDirectory <> '' then
        ForceDirectories(LEvidenceDirectory);
      TFile.WriteAllText(
        FAgentBudgetSmokeEvidencePath,
        LEvidence.ToJSON,
        TEncoding.UTF8
      );
    finally
      LEvidence.Free;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.RunAgentBudgetSmoke;
begin
  if (FAgentBudgetSmokeEvidencePath = '') or
    FAgentBudgetSmokeStarted or not Assigned(FEdgeBrowser) then
    Exit;
  FAgentBudgetSmokeStarted := True;
  FEdgeBrowser.ExecuteScript('beginAgentBudgetSmoke(120000);');
end;

function TRadIAFrameAIChat.CaptureNaturalVclSmokeResult(
  const AJson: string
): Boolean;
var
  LEvidence: TJSONObject;
  LEvidenceDirectory: string;
  LJson: TJSONValue;
  LPassed: Boolean;
  LRoot: TJSONObject;
begin
  Result := False;
  if FNaturalVclSmokeEvidencePath = '' then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LJson);
    if not SameText(
      LRoot.GetValue<string>('action', ''),
      'natural_vcl_smoke_result'
    ) then
      Exit;
    Result := True;
    LPassed := SameText(LRoot.GetValue<string>('status', ''), 'passed') and
      LRoot.GetValue<Boolean>('recommendationAccepted', False) and
      LRoot.GetValue<Boolean>('previewSucceeded', False) and
      LRoot.GetValue<Boolean>('creationSucceeded', False) and
      LRoot.GetValue<Boolean>('projectOpened', False) and
      LRoot.GetValue<Boolean>('buildPassed', False) and
      LRoot.GetValue<Boolean>('applicationStarted', False) and
      LRoot.GetValue<Boolean>('destinationRecovered', False) and
      FNaturalVclRecoveryVisible and
      LRoot.GetValue<Boolean>('requirementsPreserved', False) and
      LRoot.GetValue<Boolean>('nativeOrchestration', False) and
      not LRoot.GetValue<Boolean>('cliCompletedEarly', True) and
      not LRoot.GetValue<Boolean>('toolUnavailable', True);
    LEvidence := TJSONObject.Create;
    try
      LEvidence.AddPair('schemaVersion', TJSONNumber.Create(1));
      LEvidence.AddPair('evidenceKind', 'naturalVclChatJourney');
      LEvidence.AddPair('status', IfThen(LPassed, 'passed', 'failed'));
      LEvidence.AddPair('reason', LRoot.GetValue<string>('reason', ''));
      LEvidence.AddPair('failedTool', LRoot.GetValue<string>('failedTool', ''));
      LEvidence.AddPair('errorCode', LRoot.GetValue<string>('errorCode', ''));
      LEvidence.AddPair('agentMessage', LRoot.GetValue<string>('agentMessage', ''));
      LEvidence.AddPair(
        'recommendationAccepted',
        TJSONBool.Create(LRoot.GetValue<Boolean>('recommendationAccepted', False))
      );
      LEvidence.AddPair(
        'previewSucceeded',
        TJSONBool.Create(LRoot.GetValue<Boolean>('previewSucceeded', False))
      );
      LEvidence.AddPair(
        'creationSucceeded',
        TJSONBool.Create(LRoot.GetValue<Boolean>('creationSucceeded', False))
      );
      LEvidence.AddPair(
        'projectOpened',
        TJSONBool.Create(LRoot.GetValue<Boolean>('projectOpened', False))
      );
      LEvidence.AddPair(
        'buildPassed',
        TJSONBool.Create(LRoot.GetValue<Boolean>('buildPassed', False))
      );
      LEvidence.AddPair(
        'applicationStarted',
        TJSONBool.Create(LRoot.GetValue<Boolean>('applicationStarted', False))
      );
      LEvidence.AddPair(
        'destinationRecovered',
        TJSONBool.Create(LRoot.GetValue<Boolean>('destinationRecovered', False))
      );
      LEvidence.AddPair(
        'recoveryCardVisible',
        TJSONBool.Create(FNaturalVclRecoveryVisible)
      );
      LEvidence.AddPair(
        'requirementsPreserved',
        TJSONBool.Create(LRoot.GetValue<Boolean>('requirementsPreserved', False))
      );
      LEvidence.AddPair(
        'nativeOrchestration',
        TJSONBool.Create(LRoot.GetValue<Boolean>('nativeOrchestration', False))
      );
      LEvidence.AddPair(
        'cliCompletedEarly',
        TJSONBool.Create(LRoot.GetValue<Boolean>('cliCompletedEarly', True))
      );
      LEvidence.AddPair(
        'toolUnavailable',
        TJSONBool.Create(LRoot.GetValue<Boolean>('toolUnavailable', True))
      );
      LEvidence.AddPair(
        'elapsedMilliseconds',
        TJSONNumber.Create(LRoot.GetValue<Integer>('elapsedMilliseconds', MaxInt))
      );
      LEvidenceDirectory := ExtractFileDir(FNaturalVclSmokeEvidencePath);
      if LEvidenceDirectory <> '' then
        ForceDirectories(LEvidenceDirectory);
      TFile.WriteAllText(
        FNaturalVclSmokeEvidencePath,
        LEvidence.ToJSON,
        TEncoding.UTF8
      );
    finally
      LEvidence.Free;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.RunNaturalVclSmoke;
var
  LDestination: string;
  LPrompt: string;
  LPromptJson: TJSONString;
  LRetryDestination: string;
  LRetryJson: TJSONString;
begin
  if (FNaturalVclSmokeEvidencePath = '') or not Assigned(FEdgeBrowser) then
    Exit;
  if FNaturalVclSmokeStarted then
  begin
    FEdgeBrowser.ExecuteScript(
      'resumeNaturalVclSmoke(300000, ' +
      LowerCase(BoolToStr(FNaturalVclRecoveryVisible, True)) + ');'
    );
    Exit;
  end;
  FNaturalVclSmokeStarted := True;
  LDestination := GetEnvironmentVariable(
    'RADIA_IDE_SMOKE_NATURAL_VCL_DESTINATION'
  );
  LRetryDestination := GetEnvironmentVariable(
    'RADIA_IDE_SMOKE_NATURAL_VCL_RETRY_DESTINATION'
  );
  LPrompt :=
    'Crie uma calculadora em VCL que exiba também o histórico das operações ' +
    'matemáticas realizadas. Grave em ' + LDestination;
  LPromptJson := TJSONString.Create(LPrompt);
  LRetryJson := TJSONString.Create(LRetryDestination);
  try
    FEdgeBrowser.ExecuteScript(
      'beginNaturalVclSmoke(' + LPromptJson.ToJSON + ', ' +
        LRetryJson.ToJSON + ', 300000);'
    );
  finally
    LRetryJson.Free;
    LPromptJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.RunSessionIsolationSmoke;
begin
  if (FSessionIsolationSmokeEvidencePath = '') or
    FSessionIsolationSmokeStarted or not Assigned(FEdgeBrowser) then
    Exit;
  FSessionIsolationSmokeStarted := True;
  FEdgeBrowser.ExecuteScript('beginSessionIsolationSmoke(60000);');
end;

function TRadIAFrameAIChat.ContinueWebViewLifecycleSmoke(
  const AJson: string
): Boolean;
var
  LJson: TJSONValue;
  LRoot: TJSONObject;
begin
  Result := False;
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LJson);
    if not SameText(
      LRoot.GetValue<string>('action', ''),
      'webview_lifecycle_smoke_ready'
    ) then
      Exit;
    Result := True;
    if GIsShuttingDown or (FWebStateJson = '{}') then
      Exit;
    EdgeBrowserProcessFailed(
      FEdgeBrowser,
      COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAFrameAIChat.CaptureWebViewSmokeResult(
  const AJson: string
): Boolean;
var
  LEvidence: TJSONObject;
  LEvidenceDirectory: string;
  LJson: TJSONValue;
  LPassed: Boolean;
  LRoot: TJSONObject;
  LSnapshot: TRadIAWebViewLifecycleSnapshot;
begin
  Result := False;
  if FWebViewSmokeEvidencePath = '' then
    Exit;
  LJson := TJSONObject.ParseJSONValue(AJson);
  try
    if not (LJson is TJSONObject) then
      Exit;
    LRoot := TJSONObject(LJson);
    if not SameText(
      LRoot.GetValue<string>('action', ''),
      'webview_lifecycle_smoke_result'
    ) then
      Exit;
    Result := True;
    LSnapshot := FWebViewLifecycle.Snapshot;
    LPassed :=
      LRoot.GetValue<Boolean>('draftRestored', False) and
      LRoot.GetValue<Boolean>('advancedRestored', False) and
      (LSnapshot.Generation > 1) and
      (LSnapshot.RecoveryCount >= 1) and
      (LSnapshot.State = wlsReady);
    LEvidence := TJSONObject.Create;
    try
      LEvidence.AddPair('schemaVersion', TJSONNumber.Create(1));
      if LPassed then
        LEvidence.AddPair('status', 'passed')
      else
        LEvidence.AddPair('status', 'failed');
      LEvidence.AddPair(
        'draftRestored',
        TJSONBool.Create(LRoot.GetValue<Boolean>('draftRestored', False))
      );
      LEvidence.AddPair(
        'advancedRestored',
        TJSONBool.Create(LRoot.GetValue<Boolean>('advancedRestored', False))
      );
      LEvidence.AddPair(
        'generation',
        TJSONNumber.Create(LSnapshot.Generation)
      );
      LEvidence.AddPair(
        'recoveryAttempts',
        TJSONNumber.Create(LSnapshot.RecoveryAttempts)
      );
      LEvidence.AddPair(
        'recoveryCount',
        TJSONNumber.Create(LSnapshot.RecoveryCount)
      );
      LEvidenceDirectory := ExtractFileDir(FWebViewSmokeEvidencePath);
      if LEvidenceDirectory <> '' then
        ForceDirectories(LEvidenceDirectory);
      TFile.WriteAllText(
        FWebViewSmokeEvidencePath,
        LEvidence.ToJSON,
        TEncoding.UTF8
      );
    finally
      LEvidence.Free;
    end;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIChat.RestoreWebViewState;
var
  LSmoke: string;
begin
  if FWebStateJson = '{}' then
    Exit;
  LSmoke := 'false';
  if FWebViewSmokeStarted and
    (FWebViewLifecycle.Snapshot.Generation > 1) and
    (FWebViewLifecycle.Snapshot.RecoveryCount > 0) then
    LSmoke := 'true';
  PostMessageToWeb(
    '{"action":"restore_lifecycle_state","state":' +
    FWebStateJson + ',"smoke":' + LSmoke + '}'
  );
end;

procedure TRadIAFrameAIChat.RunWebViewLifecycleSmoke;
begin
  if (FWebViewSmokeEvidencePath = '') or FWebViewSmokeStarted or
    not Assigned(FEdgeBrowser) then
    Exit;
  FWebViewSmokeStarted := True;
  FEdgeBrowser.ExecuteScript('beginLifecycleSmoke();');
end;

function TRadIAFrameAIChat.IsExpectedWebMessageSource(
  const AArgs: TWebMessageReceivedEventArgs
): Boolean;
var
  LExpectedSource: string;
  LSeparatorIndex: Integer;
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
  LSeparatorIndex := LSourceText.IndexOfAny(['?', '#']);
  if LSeparatorIndex >= 0 then
    LSourceText := LSourceText.Substring(0, LSeparatorIndex);
  LExpectedSource := 'file:///' + TPath.Combine(FWebFilesDir, 'chat.html').Replace('\', '/');
  Result := SameText(LSourceText, LExpectedSource);
  if not Result then
    TLogger.Log('Rejected WebView message from unexpected source: ' + LSourceText, 'Security');
end;

procedure TRadIAFrameAIChat.EdgeBrowserNavigationStarting(
  Sender: TCustomEdgeBrowser;
  Args: TNavigationStartingEventArgs
);
var
  LAllowedChatUrl: string;
  LLocalPath: string;
  LOpenResult: HINST;
  LUri: PWideChar;
  LUrl: string;
begin
  if not Assigned(Args) or not Assigned(Args.ArgsInterface) then
    Exit;
  LUri := nil;
  if Failed(Args.ArgsInterface.Get_uri(LUri)) then
    Exit;
  try
    LUrl := string(LUri);
  finally
    CoTaskMemFree(LUri);
  end;

  LAllowedChatUrl := 'file:///' +
    TPath.Combine(FWebFilesDir, 'chat.html').Replace('\', '/');
  if LUrl.StartsWith(LAllowedChatUrl, True) then
    Exit;

  Args.ArgsInterface.Set_Cancel(1);
  if LUrl.StartsWith('file:///', True) then
  begin
    LLocalPath := TNetEncoding.URL.Decode(LUrl.Substring(8)).Replace('/', '\');
    if TryOpenLocalLinkInIDE(LLocalPath) then
    begin
      Exit;
    end;
    LOpenResult := ShellExecute(
      0,
      'open',
      PChar(LLocalPath),
      nil,
      nil,
      SW_SHOWNORMAL
    );
    if NativeInt(LOpenResult) <= 32 then
      TLogger.Log('Unable to open local chat link: ' + LLocalPath, 'UI');
    Exit;
  end;
  if not LUrl.StartsWith('http://', True) and
    not LUrl.StartsWith('https://', True) and
    not LUrl.StartsWith('mailto:', True) then
  begin
    TLogger.Log('Blocked unsupported chat navigation: ' + LUrl, 'UI');
    Exit;
  end;
  LOpenResult := ShellExecute(0, 'open', PChar(LUrl), nil, nil, SW_SHOWNORMAL);
  if NativeInt(LOpenResult) <= 32 then
    TLogger.Log('Unable to open external chat link: ' + LUrl, 'UI');
end;

function TRadIAFrameAIChat.TryOpenLocalLinkInIDE(const AFileName: string): Boolean;
var
  LActionServices: IOTAActionServices;
  LExtension: string;
begin
  LExtension := TPath.GetExtension(AFileName);
  if SameText(LExtension, '.dproj') or SameText(LExtension, '.groupproj') then
  begin
    Result := TRadIAOTAHelper.OpenProjectInIDE(AFileName);
    if not Result then
      TLogger.Log('Unable to open project link in Delphi: ' + AFileName, 'UI');
    Exit;
  end;

  Result := False;
  if not MatchText(LExtension, ['.pas', '.dfm', '.dpr', '.dpk', '.inc']) then
    Exit;
  if Supports(BorlandIDEServices, IOTAActionServices, LActionServices) then
    Result := LActionServices.OpenFile(AFileName);
  if not Result then
    TLogger.Log('Unable to open source link in Delphi: ' + AFileName, 'UI');
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

    LForm.ShowModal;
    { OAuth login persists independently from the modal result. Always reload
      so a token obtained before closing the dialog is immediately available. }
    FPresenter.LoadConfig;
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
