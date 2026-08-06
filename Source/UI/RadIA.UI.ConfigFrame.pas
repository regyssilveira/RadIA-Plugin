unit RadIA.UI.ConfigFrame;

interface

uses  System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls,
  Vcl.ComCtrls, System.Generics.Collections,
  RadIA.UI.ConfigPresenter,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliManager,
  RadIA.Core.CliProcess,
  RadIA.Core.CliMcpSettings,
  RadIA.Core.McpProvisioning;

type
  TRadIAFrameAIConfig = class(TFrame, IRadIAConfigView)
  private
    FPresenter: TRadIAConfigPresenter;
    FLblTemplateOrigin: TLabel;

    FEdtTemperatures: TDictionary<string, TEdit>;
    FEdtMaxTokens: TDictionary<string, TEdit>;
    FEdtTimeouts: TDictionary<string, TEdit>;
    FChkSmartConfig: TCheckBox;
    FChkConciseResponses: TCheckBox;

    FTsGeneral: TTabSheet;
    FPnlGeneral: TPanel;
    FChkInjectDelphiVersion: TCheckBox;
    FChkLogEnabled: TCheckBox;
    FLblLogPath: TLabel;
    FEdtLogPath: TEdit;
    FBtnBrowseLogPath: TButton;
    FLblLogMaxSize: TLabel;
    FEdtLogMaxSize: TEdit;

    FGrpQuota: TGroupBox;
    FChkQuotaEnabled: TCheckBox;
    FLblQuotaLimit: TLabel;
    FEdtQuotaLimit: TEdit;
    FLblQuotaUsed: TLabel;
    FBtnResetQuota: TButton;

    FTsSecurity: TTabSheet;
    FPnlSecurity: TScrollBox;
    FLblConsentSummary: TLabel;
    FLblConsentTimeout: TLabel;
    FEdtConsentTimeout: TEdit;
    FChkConsentShowArguments: TCheckBox;
    FChkConsentRememberReversible: TCheckBox;
    FChkConsentRememberStructural: TCheckBox;
    FChkConsentRememberExecution: TCheckBox;
    FChkKnowledgeSemanticEnabled: TCheckBox;
    FChkKnowledgeApprovedHistoryEnabled: TCheckBox;
    FEdtKnowledgeExcludedFiles: TEdit;
    FEdtKnowledgeExcludedProjects: TEdit;
    FChkKnowledgeRemoteEnabled: TCheckBox;
    FChkKnowledgeRemoteConsent: TCheckBox;
    FEdtKnowledgeRemoteEndpoint: TEdit;
    FEdtKnowledgeRemoteModel: TEdit;
    FEdtKnowledgeRemoteApiKey: TEdit;
    FEdtKnowledgeRemoteDimensions: TEdit;
    FEdtKnowledgeRemoteTimeout: TEdit;
    FEdtKnowledgeRemoteInputLimit: TEdit;
    FBtnRevokeConsent: TButton;
    FChkInlineCompletionEnabled: TCheckBox;
    FEdtInlineCompletionDelay: TEdit;
    FEdtInlineCompletionExcludedFiles: TEdit;
    FEdtInlineCompletionExcludedLanguages: TEdit;
    FEdtInlineCompletionExcludedProjects: TEdit;
    FEdtInlineShortcutProfile: TEdit;
    FLblInlineCompletionDelay: TLabel;
    FLblInlineCompletionExcludedFiles: TLabel;
    FLblInlineCompletionExcludedLanguages: TLabel;
    FLblInlineCompletionExcludedProjects: TLabel;
    FLblKnowledgeExcludedFiles: TLabel;
    FLblKnowledgeExcludedProjects: TLabel;
    FLblKnowledgeRemoteEndpoint: TLabel;
    FLblKnowledgeRemoteModel: TLabel;
    FLblKnowledgeRemoteApiKey: TLabel;
    FLblKnowledgeRemoteLimits: TLabel;
    FLblInlineShortcutProfile: TLabel;

    FTsCliMcp: TTabSheet;
    FPnlCliMcp: TPanel;
    FCmbAgentExecutor: TComboBox;
    FCmbCliClient: TComboBox;
    FEdtCliExecutable: TEdit;
    FEdtMcpConfig: TEdit;
    FEdtMcpBridge: TEdit;
    FLblCliStatus: TLabel;
    FLblMcpStatus: TLabel;
    FMemoMcpPreview: TMemo;
    FBtnCliRefresh: TButton;
    FBtnCliInstall: TButton;
    FBtnMcpPreview: TButton;
    FBtnMcpProvision: TButton;
    FBtnMcpRemove: TButton;
    FBtnMcpHandshake: TButton;
    FAgentExecutorSettings: TRadIAAgentExecutorSettingsStore;
    FCliMcpSettings: TRadIACliMcpSettings;
    FCliInstallSession: IRadIACliProcessSession;
    FCliVersionSession: IRadIACliProcessSession;
    FCliVersionRequestId: Integer;
    FMcpHandshakeSession: IRadIACliProcessSession;
    FCliInstallGuard: IInterface;

    procedure BtnBrowseLogPathClick(Sender: TObject);
    procedure AppendCliInstallOutput(const AText: string);
    procedure BtnResetQuotaClick(Sender: TObject);
    procedure BtnRevokeConsentClick(Sender: TObject);
    procedure BtnCliRefreshClick(Sender: TObject);
    procedure BtnCliInstallClick(Sender: TObject);
    procedure BtnMcpPreviewClick(Sender: TObject);
    procedure BtnMcpHandshakeClick(Sender: TObject);
    procedure BtnMcpProvisionClick(Sender: TObject);
    procedure BtnMcpRemoveClick(Sender: TObject);
    procedure CliClientChange(Sender: TObject);
    procedure CompleteCliInstall(
      const AResult: TRadIACliProcessResult
    );
    procedure CompleteCliVersionProbe(
      const ACliId: string;
      const AExecutablePath: string;
      const ARequestId: Integer;
      const AResult: TRadIACliProcessResult
    );
    procedure CompleteMcpHandshake(
      const AResult: TRadIACliProcessResult
    );

    function CreateCheckBox(AParent: TWinControl; const ACaption: string; const ALeft,
        ATop, AWidth: Integer): TCheckBox;
    function CreateEdit(AParent: TWinControl; const ALeft, ATop, AWidth: Integer;
        const ANumbersOnly: Boolean = False): TEdit;
    function CreateLabel(AParent: TWinControl; const ACaption: string; const ALeft, ATop: Integer): TLabel;
    procedure CreateGeneralTab;
    procedure CreateSecurityTab;
    procedure CreateCliMcpTab;
    procedure CreateTemplateOriginLabel;
    procedure CreateProviderAdvancedControls(ATabSheet: TTabSheet; const AProviderId: string);
    function GetBridgePath: string;
    function GetDefaultMcpConfigPath(
      const AClientId: string
    ): string;
    function GetMcpConnectionPath: string;
    function GetSelectedCliDefinition(
      out ADefinition: TRadIACliDefinition
    ): Boolean;
    function GetSelectedMcpProfile(
      out AProfile: TRadIAMcpClientProfile
    ): Boolean;
    function McpStateText(
      const AState: TRadIAMcpProvisionState
    ): string;
    procedure LoadAgentExecutorSettings;
    procedure OpenUrl(const AUrl: string);
    procedure RefreshCliMcpDiagnostics;
    procedure RefreshMcpPreview;
    procedure SetCliInstallRunning(const ARunning: Boolean);
    procedure StartCliVersionProbe(
      const ADefinition: TRadIACliDefinition;
      const AExecutablePath: string
    );
    procedure SaveCliMcpSettings;
    procedure SaveAgentExecutorSettings;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadConfig;
    procedure UpdateVCLColors(const AThemeName: string);
    procedure TvCategoriesChange(Sender: TObject; Node: TTreeNode);
    procedure SelectCategoryByName(const ACategoryName: string);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnCancelClick(Sender: TObject);

    { IRadIAConfigView Implementation }
    function GetApiKey(const AProviderId: string): string;
    procedure SetApiKey(const AProviderId: string; const AKey: string);
    function GetCustomUrl(const AProviderId: string): string;
    procedure SetCustomUrl(const AProviderId: string; const AUrl: string);
    function GetAuthTypeIndex(const AProviderId: string): Integer;
    procedure SetAuthTypeIndex(const AProviderId: string; const AIndex: Integer);

    function GetTemperatureInput(const AProviderId: string): string;
    procedure SetTemperatureInput(const AProviderId: string; const AValue: string);
    function GetMaxTokensInput(const AProviderId: string): string;
    procedure SetMaxTokensInput(const AProviderId: string; const AValue: string);
    function GetTimeoutInput(const AProviderId: string): string;
    procedure SetTimeoutInput(const AProviderId: string; const AValue: string);

    function GetAzureModel: string;
    procedure SetAzureModel(const AValue: string);
    function GetAzureApiVersion: string;
    procedure SetAzureApiVersion(const AValue: string);

    function GetAwsAccessKeyId: string;
    procedure SetAwsAccessKeyId(const AValue: string);
    function GetAwsSecretAccessKey: string;
    procedure SetAwsSecretAccessKey(const AValue: string);
    function GetAwsRegion: string;
    procedure SetAwsRegion(const AValue: string);
    function GetAwsSessionToken: string;
    procedure SetAwsSessionToken(const AValue: string);

    function GetSystemPrompt: string;
    procedure SetSystemPrompt(const AValue: string);
    function GetSmartConfigEnabled: Boolean;
    procedure SetSmartConfigEnabled(const AValue: Boolean);
    function GetInjectDelphiVersion: Boolean;
    procedure SetInjectDelphiVersion(const AValue: Boolean);
    function GetConciseResponses: Boolean;
    procedure SetConciseResponses(const AValue: Boolean);
    function GetLogEnabled: Boolean;
    procedure SetLogEnabled(const AValue: Boolean);
    function GetLogPath: string;
    procedure SetLogPath(const AValue: string);
    function GetLogMaxSize: string;
    procedure SetLogMaxSize(const AValue: string);
    function GetConsentTimeoutSeconds: string;
    procedure SetConsentTimeoutSeconds(const AValue: string);
    function GetConsentShowArguments: Boolean;
    procedure SetConsentShowArguments(const AValue: Boolean);
    function GetConsentRememberReversible: Boolean;
    procedure SetConsentRememberReversible(const AValue: Boolean);
    function GetConsentRememberStructural: Boolean;
    procedure SetConsentRememberStructural(const AValue: Boolean);
    function GetConsentRememberExecution: Boolean;
    procedure SetConsentRememberExecution(const AValue: Boolean);
    function GetKnowledgeSemanticEnabled: Boolean;
    procedure SetKnowledgeSemanticEnabled(const AValue: Boolean);
    function GetKnowledgeApprovedHistoryEnabled: Boolean;
    procedure SetKnowledgeApprovedHistoryEnabled(const AValue: Boolean);
    function GetKnowledgeExcludedFiles: string;
    procedure SetKnowledgeExcludedFiles(const AValue: string);
    function GetKnowledgeExcludedProjects: string;
    procedure SetKnowledgeExcludedProjects(const AValue: string);
    function GetKnowledgeRemoteEnabled: Boolean;
    procedure SetKnowledgeRemoteEnabled(const AValue: Boolean);
    function GetKnowledgeRemoteConsent: Boolean;
    procedure SetKnowledgeRemoteConsent(const AValue: Boolean);
    function GetKnowledgeRemoteEndpoint: string;
    procedure SetKnowledgeRemoteEndpoint(const AValue: string);
    function GetKnowledgeRemoteModel: string;
    procedure SetKnowledgeRemoteModel(const AValue: string);
    function GetKnowledgeRemoteApiKey: string;
    procedure SetKnowledgeRemoteApiKey(const AValue: string);
    function GetKnowledgeRemoteDimensions: string;
    procedure SetKnowledgeRemoteDimensions(const AValue: string);
    function GetKnowledgeRemoteTimeout: string;
    procedure SetKnowledgeRemoteTimeout(const AValue: string);
    function GetKnowledgeRemoteInputLimit: string;
    procedure SetKnowledgeRemoteInputLimit(const AValue: string);
    function GetInlineCompletionEnabled: Boolean;
    procedure SetInlineCompletionEnabled(const AValue: Boolean);
    function GetInlineCompletionDelay: string;
    procedure SetInlineCompletionDelay(const AValue: string);
    function GetInlineCompletionExcludedFiles: string;
    procedure SetInlineCompletionExcludedFiles(const AValue: string);
    function GetInlineCompletionExcludedLanguages: string;
    procedure SetInlineCompletionExcludedLanguages(const AValue: string);
    function GetInlineCompletionExcludedProjects: string;
    procedure SetInlineCompletionExcludedProjects(const AValue: string);
    function GetInlineShortcutProfile: string;
    procedure SetInlineShortcutProfile(const AValue: string);

    function GetQuotaEnabled: Boolean;
    procedure SetQuotaEnabled(const AValue: Boolean);
    function GetQuotaLimit: string;
    procedure SetQuotaLimit(const AValue: string);
    procedure SetQuotaUsedText(const AText: string);

    procedure ShowMessageDialog(const AMessage: string);
    function SaveDialogExecute(out AFileName: string): Boolean;
    function OpenDialogExecute(out AFileName: string): Boolean;
    function FolderDialogExecute(out AFolderName: string): Boolean;
    procedure CloseView(const AModalResult: Integer);

    procedure UpdateTemplatesList(const ATemplateNames: TArray<string>; const ASelectedIndex: Integer);
    procedure GetTemplateEditorFields(out AName, ADesc, ABody, ASlash: string; out AIsProjGen: Boolean);
    procedure UpdateOAuthState(const AProviderId: string; const AIsLoggedIn: Boolean);
    procedure SetTemplateFields(const AName, ADesc, ABody, ASlash: string; const AIsProjGen: Boolean; const AIsSystem,
        AIsCustomized: Boolean);
    procedure ClearTemplateFields;
    procedure FocusTemplateName;
    function GetSelectedTemplateIndex: Integer;
    procedure SetSelectedTemplateIndex(const AIndex: Integer);
    procedure SetDeleteTemplateButtonState(const ACaption: string; const AEnabled: Boolean);
    procedure SetTemplateOriginLabel(const AText: string; const AColor: TColor);

  published
    pgcSettings: TPageControl;
    tsGemini: TTabSheet;
    pnlGemini: TPanel;
    tsOpenAI: TTabSheet;
    pnlOpenAI: TPanel;
    tsClaude: TTabSheet;
    pnlClaude: TPanel;
    tsDeepSeek: TTabSheet;
    pnlDeepSeek: TPanel;
    tsGroq: TTabSheet;
    pnlGroq: TPanel;
    tsOllama: TTabSheet;
    pnlOllama: TPanel;
    tsOpenRouter: TTabSheet;
    pnlOpenRouter: TPanel;
    tsLMStudio: TTabSheet;
    pnlLMStudio: TPanel;
    lblLMStudioUrl: TLabel;
    edtLMStudioUrl: TEdit;

    tsGithubCopilot: TTabSheet;
    pnlGithubCopilot: TPanel;
    lblGithubCopilotKey: TLabel;
    edtGithubCopilotKey: TEdit;
    btnConnectGithub: TButton;
    btnImportVSCode: TButton;
    btnGeminiWebLogin: TButton;
    btnOpenAIWebLogin: TButton;

    tsAzureOpenAI: TTabSheet;
    pnlAzureOpenAI: TPanel;
    lblAzureKey: TLabel;
    edtAzureKey: TEdit;
    lblAzureUrl: TLabel;
    edtAzureUrl: TEdit;
    lblAzureModel: TLabel;
    edtAzureModel: TEdit;
    lblAzureApiVersion: TLabel;
    edtAzureApiVersion: TEdit;

    tsQwen: TTabSheet;
    pnlQwen: TPanel;
    lblQwenKey: TLabel;
    edtQwenKey: TEdit;
    lnkQwenGetKey: TLabel;

    tsMistral: TTabSheet;
    pnlMistral: TPanel;
    lblMistralKey: TLabel;
    edtMistralKey: TEdit;
    lnkMistralGetKey: TLabel;

    tsBedrock: TTabSheet;
    pnlBedrock: TPanel;
    lblAwsAccessKeyId: TLabel;
    edtAwsAccessKeyId: TEdit;
    lblAwsSecretAccessKey: TLabel;
    edtAwsSecretAccessKey: TEdit;
    lblAwsRegion: TLabel;
    edtAwsRegion: TEdit;
    lblAwsSessionToken: TLabel;
    edtAwsSessionToken: TEdit;
    lnkBedrockGetKey: TLabel;

    lnkGeminiGetKey: TLabel;
    lnkOpenAIGetKey: TLabel;
    lnkClaudeGetKey: TLabel;
    lnkDeepSeekGetKey: TLabel;
    lnkGroqGetKey: TLabel;
    lnkOpenRouterGetKey: TLabel;

    tsSystemPrompt: TTabSheet;
    pnlSystemPrompt: TPanel;
    lblGeminiKey: TLabel;
    edtGeminiKey: TEdit;
    grpGeminiAuthType: TRadioGroup;
    lblOpenAIKey: TLabel;
    edtOpenAIKey: TEdit;
    lblOpenAICustomUrl: TLabel;
    edtOpenAICustomUrl: TEdit;
    grpOpenAIAuthType: TRadioGroup;
    lblClaudeKey: TLabel;
    edtClaudeKey: TEdit;
    lblOllamaUrl: TLabel;
    edtOllamaUrl: TEdit;
    lblDeepSeekKey: TLabel;
    edtDeepSeekKey: TEdit;
    lblGroqKey: TLabel;
    edtGroqKey: TEdit;
    lblOpenRouterKey: TLabel;
    edtOpenRouterKey: TEdit;
    memSystemPrompt: TMemo;
    tsTemplates: TTabSheet;
    pnlTemplatesLeft: TPanel;
    lstTemplates: TListBox;
    pnlTemplatesLeftButtons: TPanel;
    btnNewTemplate: TButton;
    btnDeleteTemplate: TButton;
    pnlTemplatesClient: TPanel;
    lblTemplateName: TLabel;
    lblTemplateDesc: TLabel;
    lblTemplateBody: TLabel;
    edtTemplateName: TEdit;
    edtTemplateDesc: TEdit;
    memTemplateBody: TMemo;
    btnSaveTemplate: TButton;
    btnRestoreDefaults: TButton;
    lblTemplateSlash: TLabel;
    edtTemplateSlash: TEdit;
    chkIsProjectGenerator: TCheckBox;
    btnExportTemplates: TButton;
    btnImportTemplates: TButton;
    dlgsTemplatesSave: TSaveDialog;
    dlgsTemplatesOpen: TOpenDialog;
    procedure lstTemplatesClick(Sender: TObject);
    procedure btnNewTemplateClick(Sender: TObject);
    procedure btnDeleteTemplateClick(Sender: TObject);
    procedure btnSaveTemplateClick(Sender: TObject);
    procedure btnRestoreDefaultsClick(Sender: TObject);
    procedure btnExportTemplatesClick(Sender: TObject);
    procedure btnImportTemplatesClick(Sender: TObject);
    procedure grpGeminiAuthTypeClick(Sender: TObject);
    procedure grpOpenAIAuthTypeClick(Sender: TObject);
    procedure lnkGeminiGetKeyClick(Sender: TObject);
    procedure lnkOpenAIGetKeyClick(Sender: TObject);
    procedure lnkClaudeGetKeyClick(Sender: TObject);
    procedure lnkDeepSeekGetKeyClick(Sender: TObject);
    procedure lnkGroqGetKeyClick(Sender: TObject);
    procedure lnkOpenRouterGetKeyClick(Sender: TObject);
    procedure lnkQwenGetKeyClick(Sender: TObject);
    procedure lnkMistralGetKeyClick(Sender: TObject);
    procedure lnkBedrockGetKeyClick(Sender: TObject);
    procedure btnConnectGithubClick(Sender: TObject);
    procedure btnImportVSCodeClick(Sender: TObject);
    procedure btnGeminiWebLoginClick(Sender: TObject);
    procedure btnOpenAIWebLoginClick(Sender: TObject);
  end;

implementation

uses
  System.IOUtils, System.JSON, System.SyncObjs,
  RadIA.UI.Resources, System.UITypes, Vcl.FileCtrl,
  Winapi.Messages, Winapi.ShellAPI, RadIA.UI.GithubAuthForm,
  Winapi.Windows, System.SysUtils, ToolsAPI,
  RadIA.Core.Container, RadIA.Core.McpHandshake,
  RadIA.Core.ToolSecurity;

{$R *.dfm}

type
  IRadIAConfigLifecycleGuard = interface
    ['{9BB2BF3C-EF66-407C-B830-3E0BB45D2D10}']
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

  TRadIAConfigLifecycleGuard = class(
    TInterfacedObject,
    IRadIAConfigLifecycleGuard
  )
  private
    FAlive: Integer;
  public
    constructor Create;
    function IsAlive: Boolean;
    procedure Invalidate;
  end;

  TWinControlHelper = class helper for TWinControl
  public
    procedure SetColor(const AColor: TColor); inline;
    procedure SetParentBackground(const AValue: Boolean); inline;
  end;

constructor TRadIAConfigLifecycleGuard.Create;
begin
  inherited Create;
  FAlive := 1;
end;

procedure TRadIAConfigLifecycleGuard.Invalidate;
begin
  TInterlocked.Exchange(FAlive, 0);
end;

function TRadIAConfigLifecycleGuard.IsAlive: Boolean;
begin
  Result := TInterlocked.CompareExchange(FAlive, 1, 1) = 1;
end;

{ TWinControlHelper }

procedure TWinControlHelper.SetColor(const AColor: TColor);
begin
  Self.Color := AColor;
end;

procedure TWinControlHelper.SetParentBackground(const AValue: Boolean);
begin
  Self.ParentBackground := AValue;
end;

function TRadIAFrameAIConfig.CreateCheckBox(AParent: TWinControl; const ACaption: string;
  const ALeft, ATop, AWidth: Integer): TCheckBox;
begin
  Result := TCheckBox.Create(Self);
  Result.Parent := AParent;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.Height := 23;
  Result.Caption := ACaption;
end;

function TRadIAFrameAIConfig.CreateEdit(AParent: TWinControl; const ALeft, ATop, AWidth: Integer;
  const ANumbersOnly: Boolean): TEdit;
begin
  Result := TEdit.Create(Self);
  Result.Parent := AParent;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Width := AWidth;
  Result.NumbersOnly := ANumbersOnly;
end;

function TRadIAFrameAIConfig.CreateLabel(AParent: TWinControl; const ACaption: string;
  const ALeft, ATop: Integer): TLabel;
begin
  Result := TLabel.Create(Self);
  Result.Parent := AParent;
  Result.Left := ALeft;
  Result.Top := ATop;
  Result.Caption := ACaption;
end;

procedure TRadIAFrameAIConfig.CreateTemplateOriginLabel;
begin
  FLblTemplateOrigin := TLabel.Create(Self);
  FLblTemplateOrigin.Parent := pnlTemplatesClient;
  FLblTemplateOrigin.Left := 14;
  FLblTemplateOrigin.Top := btnSaveTemplate.Top + btnSaveTemplate.Height + 12;
  FLblTemplateOrigin.Font.Assign(lblTemplateName.Font);
  FLblTemplateOrigin.Font.Style := [fsItalic];
  FLblTemplateOrigin.Caption := '';
end;

procedure TRadIAFrameAIConfig.CreateGeneralTab;
begin
  FTsGeneral := TTabSheet.Create(Self);
  FTsGeneral.PageControl := pgcSettings;
  FTsGeneral.Caption := 'General / Logs';
  FTsGeneral.TabVisible := False;

  FPnlGeneral := TPanel.Create(Self);
  FPnlGeneral.Parent := FTsGeneral;
  FPnlGeneral.Align := alClient;
  FPnlGeneral.BevelOuter := bvNone;
  FPnlGeneral.ShowCaption := False;

  FChkSmartConfig := CreateCheckBox(FPnlGeneral, 'Auto (Smart Parameters)', 16, 16, 300);
  FChkInjectDelphiVersion := CreateCheckBox(
    FPnlGeneral,
    'Inject Delphi version in prompt',
    16,
    48,
    300);
  FChkConciseResponses := CreateCheckBox(
    FPnlGeneral,
    'Prefer concise AI responses',
    16,
    80,
    300);
  FChkLogEnabled := CreateCheckBox(FPnlGeneral, 'Enable logging', 16, 112, 200);
  FLblLogPath := CreateLabel(FPnlGeneral, 'Log Folder Path:', 16, 144);
  FEdtLogPath := CreateEdit(FPnlGeneral, 16, 162, 320);

  FBtnBrowseLogPath := TButton.Create(Self);
  FBtnBrowseLogPath.Parent := FPnlGeneral;
  FBtnBrowseLogPath.Left := 342;
  FBtnBrowseLogPath.Top := 160;
  FBtnBrowseLogPath.Width := 30;
  FBtnBrowseLogPath.Height := 23;
  FBtnBrowseLogPath.Caption := '...';
  FBtnBrowseLogPath.OnClick := BtnBrowseLogPathClick;

  FLblLogMaxSize := CreateLabel(FPnlGeneral, 'Max Log File Size (KB):', 16, 200);
  FEdtLogMaxSize := CreateEdit(FPnlGeneral, 16, 218, 100, True);

  FGrpQuota := TGroupBox.Create(Self);
  FGrpQuota.Parent := FPnlGeneral;
  FGrpQuota.Left := 16;
  FGrpQuota.Top := 256;
  FGrpQuota.Width := 356;
  FGrpQuota.Height := 140;
  FGrpQuota.Caption := ' Local Token Quota ';

  FChkQuotaEnabled := CreateCheckBox(FGrpQuota, 'Enable local token quota', 16, 24, 200);
  FLblQuotaLimit := CreateLabel(FGrpQuota, 'Monthly Token Limit:', 16, 54);
  FEdtQuotaLimit := CreateEdit(FGrpQuota, 16, 72, 150, True);
  FLblQuotaUsed := CreateLabel(FGrpQuota, 'Monthly Used Tokens: 0', 16, 110);

  FBtnResetQuota := TButton.Create(Self);
  FBtnResetQuota.Parent := FGrpQuota;
  FBtnResetQuota.Left := 240;
  FBtnResetQuota.Top := 68;
  FBtnResetQuota.Width := 100;
  FBtnResetQuota.Height := 25;
  FBtnResetQuota.Caption := 'Reset Usage';
  FBtnResetQuota.OnClick := BtnResetQuotaClick;
end;

procedure TRadIAFrameAIConfig.CreateSecurityTab;
begin
  FTsSecurity := TTabSheet.Create(Self);
  FTsSecurity.PageControl := pgcSettings;
  FTsSecurity.Caption := 'Security & Consent';
  FTsSecurity.TabVisible := False;

  FPnlSecurity := TScrollBox.Create(Self);
  FPnlSecurity.Parent := FTsSecurity;
  FPnlSecurity.Align := alClient;
  FPnlSecurity.BorderStyle := bsNone;

  FLblConsentSummary := CreateLabel(
    FPnlSecurity,
    'Read-only operations run automatically. Destructive operations always require approval.',
    16,
    16
  );
  FLblConsentSummary.AutoSize := False;
  FLblConsentSummary.WordWrap := True;
  FLblConsentSummary.Width := 520;
  FLblConsentSummary.Height := 40;

  FLblConsentTimeout := CreateLabel(
    FPnlSecurity,
    'Consent dialog timeout (15-600 seconds):',
    16,
    72
  );
  FEdtConsentTimeout := CreateEdit(FPnlSecurity, 16, 92, 100, True);
  FChkConsentShowArguments := CreateCheckBox(
    FPnlSecurity,
    'Show tool arguments in the consent dialog',
    16,
    132,
    360
  );
  FChkConsentRememberReversible := CreateCheckBox(
    FPnlSecurity,
    'Allow session permission for reversible writes',
    16,
    164,
    380
  );
  FChkConsentRememberStructural := CreateCheckBox(
    FPnlSecurity,
    'Allow session permission for structural writes',
    16,
    196,
    380
  );
  FChkConsentRememberExecution := CreateCheckBox(
    FPnlSecurity,
    'Allow session permission for build, tests, and execution',
    16,
    228,
    420
  );

  FBtnRevokeConsent := TButton.Create(Self);
  FBtnRevokeConsent.Parent := FPnlSecurity;
  FBtnRevokeConsent.Left := 16;
  FBtnRevokeConsent.Top := 276;
  FBtnRevokeConsent.Width := 190;
  FBtnRevokeConsent.Height := 28;
  FBtnRevokeConsent.Caption := 'Revoke session permissions';
  FBtnRevokeConsent.OnClick := BtnRevokeConsentClick;

  FChkKnowledgeSemanticEnabled := CreateCheckBox(
    FPnlSecurity,
    'Enable local semantic project knowledge (no network)',
    16,
    320,
    500
  );
  FChkKnowledgeApprovedHistoryEnabled := CreateCheckBox(
    FPnlSecurity,
    'Include approved agent run summaries in local project knowledge',
    16,
    346,
    560
  );
  FChkKnowledgeApprovedHistoryEnabled.Hint :=
    'Indexes only completed runs with an approved plan from the current project. ' +
    'Tool arguments and results are never included.';
  FChkKnowledgeApprovedHistoryEnabled.ShowHint := True;
  FLblKnowledgeExcludedFiles := CreateLabel(
    FPnlSecurity,
    'Knowledge excluded file fragments (semicolon separated):',
    16,
    382
  );
  FEdtKnowledgeExcludedFiles := CreateEdit(
    FPnlSecurity,
    16,
    402,
    500
  );
  FLblKnowledgeExcludedProjects := CreateLabel(
    FPnlSecurity,
    'Knowledge excluded project name or path fragments (semicolon separated):',
    16,
    442
  );
  FEdtKnowledgeExcludedProjects := CreateEdit(
    FPnlSecurity,
    16,
    462,
    500
  );
  FChkKnowledgeRemoteEnabled := CreateCheckBox(
    FPnlSecurity,
    'Use a remote OpenAI-compatible embedding provider',
    16,
    502,
    520
  );
  FChkKnowledgeRemoteConsent := CreateCheckBox(
    FPnlSecurity,
    'I consent to sending bounded project text to this endpoint',
    16,
    528,
    560
  );
  FLblKnowledgeRemoteEndpoint := CreateLabel(
    FPnlSecurity,
    'Remote embeddings endpoint (HTTPS or loopback HTTP):',
    16,
    562
  );
  FEdtKnowledgeRemoteEndpoint := CreateEdit(
    FPnlSecurity,
    16,
    582,
    500
  );
  FLblKnowledgeRemoteModel := CreateLabel(
    FPnlSecurity,
    'Embedding model:',
    16,
    622
  );
  FEdtKnowledgeRemoteModel := CreateEdit(FPnlSecurity, 16, 642, 240);
  FLblKnowledgeRemoteApiKey := CreateLabel(
    FPnlSecurity,
    'API key (protected with Windows DPAPI):',
    276,
    622
  );
  FEdtKnowledgeRemoteApiKey := CreateEdit(
    FPnlSecurity,
    276,
    642,
    240
  );
  FEdtKnowledgeRemoteApiKey.PasswordChar := '*';
  FLblKnowledgeRemoteLimits := CreateLabel(
    FPnlSecurity,
    'Dimensions / timeout ms / maximum input characters:',
    16,
    682
  );
  FEdtKnowledgeRemoteDimensions := CreateEdit(
    FPnlSecurity,
    16,
    702,
    100,
    True
  );
  FEdtKnowledgeRemoteTimeout := CreateEdit(
    FPnlSecurity,
    132,
    702,
    100,
    True
  );
  FEdtKnowledgeRemoteInputLimit := CreateEdit(
    FPnlSecurity,
    248,
    702,
    120,
    True
  );
  FChkInlineCompletionEnabled := CreateCheckBox(
    FPnlSecurity,
    'Enable continuous inline completion (sends bounded editor context)',
    16,
    752,
    500
  );
  FLblInlineCompletionDelay := CreateLabel(
    FPnlSecurity,
    'Idle delay in milliseconds (250-5000):',
    16,
    788
  );
  FEdtInlineCompletionDelay := CreateEdit(
    FPnlSecurity,
    16,
    808,
    100,
    True
  );
  FLblInlineCompletionExcludedLanguages := CreateLabel(
    FPnlSecurity,
    'Excluded languages (semicolon separated, for example sql;markdown):',
    16,
    848
  );
  FEdtInlineCompletionExcludedLanguages := CreateEdit(
    FPnlSecurity,
    16,
    868,
    500
  );
  FLblInlineCompletionExcludedFiles := CreateLabel(
    FPnlSecurity,
    'Excluded file fragments (semicolon separated):',
    16,
    908
  );
  FEdtInlineCompletionExcludedFiles := CreateEdit(
    FPnlSecurity,
    16,
    928,
    500
  );
  FLblInlineCompletionExcludedProjects := CreateLabel(
    FPnlSecurity,
    'Excluded project name or path fragments (semicolon separated):',
    16,
    968
  );
  FEdtInlineCompletionExcludedProjects := CreateEdit(
    FPnlSecurity,
    16,
    988,
    500
  );
  FLblInlineShortcutProfile := CreateLabel(
    FPnlSecurity,
    'Inline shortcuts (request, accept, nextWord, alternative, reject):',
    16,
    1028
  );
  FEdtInlineShortcutProfile := CreateEdit(
    FPnlSecurity,
    16,
    1048,
    640
  );
end;

procedure TRadIAFrameAIConfig.CreateCliMcpTab;
var
  LDefinition: TRadIACliDefinition;
begin
  FTsCliMcp := TTabSheet.Create(Self);
  FTsCliMcp.PageControl := pgcSettings;
  FTsCliMcp.Caption := 'CLI & MCP';
  FTsCliMcp.TabVisible := False;

  FPnlCliMcp := TPanel.Create(Self);
  FPnlCliMcp.Parent := FTsCliMcp;
  FPnlCliMcp.Align := alClient;
  FPnlCliMcp.BevelOuter := bvNone;
  FPnlCliMcp.ShowCaption := False;

  CreateLabel(FPnlCliMcp, 'Chat executor:', 280, 16);
  FCmbAgentExecutor := TComboBox.Create(Self);
  FCmbAgentExecutor.Parent := FPnlCliMcp;
  FCmbAgentExecutor.Left := 280;
  FCmbAgentExecutor.Top := 34;
  FCmbAgentExecutor.Width := 240;
  FCmbAgentExecutor.Style := csDropDownList;
  FCmbAgentExecutor.Items.Add('RadIA native agent');
  FCmbAgentExecutor.Items.Add('Selected CLI');
  FCmbAgentExecutor.ItemIndex := 0;

  CreateLabel(FPnlCliMcp, 'CLI client:', 16, 16);
  FCmbCliClient := TComboBox.Create(Self);
  FCmbCliClient.Parent := FPnlCliMcp;
  FCmbCliClient.Left := 16;
  FCmbCliClient.Top := 34;
  FCmbCliClient.Width := 240;
  FCmbCliClient.Style := csDropDownList;
  FCmbCliClient.OnChange := CliClientChange;
  for LDefinition in TRadIACliCatalog.All do
    FCmbCliClient.Items.Add(LDefinition.DisplayName);

  CreateLabel(FPnlCliMcp, 'CLI executable override (optional):', 16, 70);
  FEdtCliExecutable := CreateEdit(FPnlCliMcp, 16, 88, 520);

  FLblCliStatus := CreateLabel(FPnlCliMcp, 'CLI status: not checked', 16, 120);
  FBtnCliRefresh := TButton.Create(Self);
  FBtnCliRefresh.Parent := FPnlCliMcp;
  FBtnCliRefresh.Left := 548;
  FBtnCliRefresh.Top := 86;
  FBtnCliRefresh.Width := 96;
  FBtnCliRefresh.Height := 25;
  FBtnCliRefresh.Caption := 'Diagnose';
  FBtnCliRefresh.OnClick := BtnCliRefreshClick;

  FBtnCliInstall := TButton.Create(Self);
  FBtnCliInstall.Parent := FPnlCliMcp;
  FBtnCliInstall.Left := 534;
  FBtnCliInstall.Top := 116;
  FBtnCliInstall.Width := 110;
  FBtnCliInstall.Height := 25;
  FBtnCliInstall.Caption := 'Install / Update';
  FBtnCliInstall.OnClick := BtnCliInstallClick;

  CreateLabel(FPnlCliMcp, 'MCP client configuration:', 16, 152);
  FEdtMcpConfig := CreateEdit(FPnlCliMcp, 16, 170, 628);
  CreateLabel(FPnlCliMcp, 'RadIA MCP bridge:', 16, 206);
  FEdtMcpBridge := CreateEdit(FPnlCliMcp, 16, 224, 628);

  FLblMcpStatus := CreateLabel(FPnlCliMcp, 'MCP status: not checked', 16, 256);
  FBtnMcpPreview := TButton.Create(Self);
  FBtnMcpPreview.Parent := FPnlCliMcp;
  FBtnMcpPreview.Left := 16;
  FBtnMcpPreview.Top := 282;
  FBtnMcpPreview.Width := 104;
  FBtnMcpPreview.Height := 27;
  FBtnMcpPreview.Caption := 'Preview';
  FBtnMcpPreview.OnClick := BtnMcpPreviewClick;

  FBtnMcpProvision := TButton.Create(Self);
  FBtnMcpProvision.Parent := FPnlCliMcp;
  FBtnMcpProvision.Left := 128;
  FBtnMcpProvision.Top := 282;
  FBtnMcpProvision.Width := 136;
  FBtnMcpProvision.Height := 27;
  FBtnMcpProvision.Caption := 'Connect / Repair';
  FBtnMcpProvision.OnClick := BtnMcpProvisionClick;

  FBtnMcpRemove := TButton.Create(Self);
  FBtnMcpRemove.Parent := FPnlCliMcp;
  FBtnMcpRemove.Left := 272;
  FBtnMcpRemove.Top := 282;
  FBtnMcpRemove.Width := 104;
  FBtnMcpRemove.Height := 27;
  FBtnMcpRemove.Caption := 'Disconnect';
  FBtnMcpRemove.OnClick := BtnMcpRemoveClick;

  FBtnMcpHandshake := TButton.Create(Self);
  FBtnMcpHandshake.Parent := FPnlCliMcp;
  FBtnMcpHandshake.Left := 384;
  FBtnMcpHandshake.Top := 282;
  FBtnMcpHandshake.Width := 130;
  FBtnMcpHandshake.Height := 27;
  FBtnMcpHandshake.Caption := 'Test Handshake';
  FBtnMcpHandshake.OnClick := BtnMcpHandshakeClick;

  FMemoMcpPreview := TMemo.Create(Self);
  FMemoMcpPreview.Parent := FPnlCliMcp;
  FMemoMcpPreview.Left := 16;
  FMemoMcpPreview.Top := 320;
  FMemoMcpPreview.Width := 628;
  FMemoMcpPreview.Height := 150;
  FMemoMcpPreview.ReadOnly := True;
  FMemoMcpPreview.ScrollBars := ssBoth;
  FMemoMcpPreview.WordWrap := False;

  if FCmbCliClient.Items.Count > 0 then
    FCmbCliClient.ItemIndex := 0;
  CliClientChange(FCmbCliClient);
end;

constructor TRadIAFrameAIConfig.Create(AOwner: TComponent);
var
  LThemingServices: IOTAIDEThemingServices;
  LActiveTheme: string;
  LUseIDETheme: Boolean;
begin
  inherited Create(AOwner);
  FPresenter := TRadIAConfigPresenter.Create(Self);
  FAgentExecutorSettings := TRadIAAgentExecutorSettingsStore.Create;
  FCliMcpSettings := TRadIACliMcpSettings.Create;
  FCliInstallGuard := TRadIAConfigLifecycleGuard.Create;

  // Update RadioGroup text in runtime for OAuth
  if grpGeminiAuthType.Items.Count > 1 then
    grpGeminiAuthType.Items[1] := 'Sign in with Google (OAuth)';
  if grpOpenAIAuthType.Items.Count > 1 then
    grpOpenAIAuthType.Items[1] := 'Sign in with ChatGPT (OAuth)';

  CreateTemplateOriginLabel;

  FEdtTemperatures := TDictionary<string, TEdit>.Create;
  FEdtMaxTokens := TDictionary<string, TEdit>.Create;
  FEdtTimeouts := TDictionary<string, TEdit>.Create;

  CreateProviderAdvancedControls(tsGemini, 'Gemini');
  CreateProviderAdvancedControls(tsOpenAI, 'OpenAI');
  CreateProviderAdvancedControls(tsClaude, 'Claude');
  CreateProviderAdvancedControls(tsDeepSeek, 'DeepSeek');
  CreateProviderAdvancedControls(tsGroq, 'Groq');
  CreateProviderAdvancedControls(tsOllama, 'Ollama');
  CreateProviderAdvancedControls(tsOpenRouter, 'OpenRouter');
  CreateProviderAdvancedControls(tsLMStudio, 'LMStudio');
  CreateProviderAdvancedControls(tsGithubCopilot, 'GithubCopilot');
  CreateProviderAdvancedControls(tsAzureOpenAI, 'AzureOpenAI');
  CreateProviderAdvancedControls(tsQwen, 'Qwen');
  CreateProviderAdvancedControls(tsMistral, 'Mistral');
  CreateProviderAdvancedControls(tsBedrock, 'Bedrock');

  CreateGeneralTab;
  CreateSecurityTab;
  CreateCliMcpTab;
  LoadAgentExecutorSettings;

  LActiveTheme := 'light';
  LUseIDETheme := False;
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    if LThemingServices.IDEThemingEnabled then
    begin
      LThemingServices.ApplyTheme(Self);
      LActiveTheme := LThemingServices.ActiveTheme;
      LUseIDETheme := True;
    end;
  end;

  if not LUseIDETheme then
    UpdateVCLColors(LActiveTheme);

  FPresenter.LoadConfig;
end;

destructor TRadIAFrameAIConfig.Destroy;
begin
  (FCliInstallGuard as IRadIAConfigLifecycleGuard).Invalidate;
  if Assigned(FCliInstallSession) then
    FCliInstallSession.Cancel;
  if Assigned(FCliVersionSession) then
    FCliVersionSession.Cancel;
  if Assigned(FMcpHandshakeSession) then
    FMcpHandshakeSession.Cancel;
  FCliInstallSession := nil;
  FCliVersionSession := nil;
  FMcpHandshakeSession := nil;
  FCliInstallGuard := nil;
  FAgentExecutorSettings.Free;
  FCliMcpSettings.Free;
  FPresenter.Free;
  FEdtTemperatures.Free;
  FEdtMaxTokens.Free;
  FEdtTimeouts.Free;
  inherited Destroy;
end;

procedure TRadIAFrameAIConfig.CreateProviderAdvancedControls(ATabSheet: TTabSheet; const AProviderId: string);
var
  LGroupBox: TGroupBox;
  LLabel: TLabel;
  LParent: TWinControl;
  I: Integer;
  LEdtTemp, LEdtMax, LEdtTime: TEdit;
begin
  LParent := ATabSheet;
  for I := 0 to ATabSheet.ControlCount - 1 do
  begin
    if ATabSheet.Controls[I] is TPanel then
    begin
      LParent := TWinControl(ATabSheet.Controls[I]);
      Break;
    end;
  end;

  LGroupBox := TGroupBox.Create(Self);
  LGroupBox.Parent := LParent;
  LGroupBox.Align := alBottom;
  LGroupBox.Height := 90;
  LGroupBox.Caption := ' Advanced Settings ';
  LGroupBox.Margins.Left := 8;
  LGroupBox.Margins.Right := 8;
  LGroupBox.Margins.Bottom := 8;
  LGroupBox.AlignWithMargins := True;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LGroupBox;
  LLabel.Left := 16;
  LLabel.Top := 24;
  LLabel.Caption := 'Temperature (0.0 - 1.0):';

  LEdtTemp := TEdit.Create(Self);
  LEdtTemp.Parent := LGroupBox;
  LEdtTemp.Left := 16;
  LEdtTemp.Top := 42;
  LEdtTemp.Width := 100;
  FEdtTemperatures.Add(AProviderId, LEdtTemp);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LGroupBox;
  LLabel.Left := 140;
  LLabel.Top := 24;
  LLabel.Caption := 'Max Output Tokens:';

  LEdtMax := TEdit.Create(Self);
  LEdtMax.Parent := LGroupBox;
  LEdtMax.Left := 140;
  LEdtMax.Top := 42;
  LEdtMax.Width := 100;
  LEdtMax.NumbersOnly := True;
  FEdtMaxTokens.Add(AProviderId, LEdtMax);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LGroupBox;
  LLabel.Left := 264;
  LLabel.Top := 24;
  LLabel.Caption := 'Timeout (seconds):';

  LEdtTime := TEdit.Create(Self);
  LEdtTime.Parent := LGroupBox;
  LEdtTime.Left := 264;
  LEdtTime.Top := 42;
  LEdtTime.Width := 100;
  LEdtTime.NumbersOnly := True;
  FEdtTimeouts.Add(AProviderId, LEdtTime);
end;

procedure ApplyThemeToPanels(const APanels: array of TPanel; const AColors: TRadIAThemeColors);
var
  LPanel: TPanel;
  I: Integer;
begin
  for I := Low(APanels) to High(APanels) do
  begin
    LPanel := APanels[I];
    if Assigned(LPanel) then
    begin
      LPanel.StyleElements := LPanel.StyleElements - [seClient, seBorder];
      LPanel.Color := AColors.BgBase;
      LPanel.ParentBackground := False;
    end;
  end;
end;

procedure ApplyThemeToEdits(const AEdits: array of TEdit; const AColors: TRadIAThemeColors);
var
  LEdit: TEdit;
  I: Integer;
begin
  for I := Low(AEdits) to High(AEdits) do
  begin
    LEdit := AEdits[I];
    if Assigned(LEdit) then
    begin
      LEdit.StyleElements := LEdit.StyleElements - [seClient, seBorder];
      LEdit.Color := AColors.InputBgColor;
      LEdit.Font.Color := AColors.TextColor;
    end;
  end;
end;

procedure ApplyThemeToLabels(const ALabels: array of TLabel; const AColors: TRadIAThemeColors;
  AAccent: Boolean = False);
var
  LLabel: TLabel;
  I: Integer;
begin
  for I := Low(ALabels) to High(ALabels) do
  begin
    LLabel := ALabels[I];
    if Assigned(LLabel) then
    begin
      LLabel.StyleElements := LLabel.StyleElements - [seClient, seBorder];
      if AAccent then
        LLabel.Font.Color := AColors.AccentColor
      else
        LLabel.Font.Color := AColors.TextColor;
    end;
  end;
end;

procedure ApplyThemeToCheckboxes(const ACheckboxes: array of TCheckBox; const AColors: TRadIAThemeColors);
var
  LCheck: TCheckBox;
  I: Integer;
begin
  for I := Low(ACheckboxes) to High(ACheckboxes) do
  begin
    LCheck := ACheckboxes[I];
    if Assigned(LCheck) then
    begin
      LCheck.StyleElements := LCheck.StyleElements - [seClient, seBorder];
      LCheck.Font.Color := AColors.TextColor;
    end;
  end;
end;

procedure ApplyThemeToGroupBoxes(const AGroupBoxes: array of TGroupBox; const AColors: TRadIAThemeColors);
var
  LGrp: TGroupBox;
  I: Integer;
begin
  for I := Low(AGroupBoxes) to High(AGroupBoxes) do
  begin
    LGrp := AGroupBoxes[I];
    if Assigned(LGrp) then
    begin
      LGrp.StyleElements := LGrp.StyleElements - [seClient, seBorder];
      LGrp.Font.Color := AColors.TextColor;
    end;
  end;
end;

procedure ApplyThemeToRadioGroups(const ARadioGroups: array of TRadioGroup; const AColors: TRadIAThemeColors);
var
  LRad: TRadioGroup;
  I: Integer;
begin
  for I := Low(ARadioGroups) to High(ARadioGroups) do
  begin
    LRad := ARadioGroups[I];
    if Assigned(LRad) then
    begin
      LRad.StyleElements := LRad.StyleElements - [seClient, seBorder];
      LRad.Font.Color := AColors.TextColor;
    end;
  end;
end;

procedure TRadIAFrameAIConfig.UpdateVCLColors(const AThemeName: string);
var
  LColors: TRadIAThemeColors;
  I: Integer;
  LEditD: TEdit;
begin
  LColors := TRadIAThemeColors.GetColorsForTheme(AThemeName);

  Self.StyleElements := Self.StyleElements - [seClient, seBorder];
  Self.SetColor(LColors.BgBase);
  pgcSettings.StyleElements := pgcSettings.StyleElements - [seClient, seBorder];
  pgcSettings.SetColor(LColors.BgBase);

  Self.SetParentBackground(False);
  pgcSettings.SetParentBackground(False);

  for I := 0 to pgcSettings.PageCount - 1 do
  begin
    pgcSettings.Pages[I].StyleElements := pgcSettings.Pages[I].StyleElements - [seClient, seBorder];
    pgcSettings.Pages[I].SetParentBackground(False);
    pgcSettings.Pages[I].SetColor(LColors.BgBase);
  end;

  if Assigned(FTsGeneral) then
  begin
    FTsGeneral.StyleElements := FTsGeneral.StyleElements - [seClient, seBorder];
    FTsGeneral.SetParentBackground(False);
    FTsGeneral.SetColor(LColors.BgBase);
  end;
  if Assigned(FTsSecurity) then
  begin
    FTsSecurity.StyleElements :=
      FTsSecurity.StyleElements - [seClient, seBorder];
    FTsSecurity.SetParentBackground(False);
    FTsSecurity.SetColor(LColors.BgBase);
  end;
  if Assigned(FPnlSecurity) then
  begin
    FPnlSecurity.StyleElements :=
      FPnlSecurity.StyleElements - [seClient, seBorder];
    FPnlSecurity.Color := LColors.BgBase;
    FPnlSecurity.Font.Color := LColors.TextColor;
  end;
  if Assigned(FTsCliMcp) then
  begin
    FTsCliMcp.StyleElements :=
      FTsCliMcp.StyleElements - [seClient, seBorder];
    FTsCliMcp.SetParentBackground(False);
    FTsCliMcp.SetColor(LColors.BgBase);
  end;

  ApplyThemeToPanels([pnlGemini, pnlOpenAI, pnlClaude, pnlDeepSeek, pnlGroq, pnlOllama,
    pnlOpenRouter, pnlLMStudio,
    pnlGithubCopilot, pnlAzureOpenAI, pnlQwen,
    pnlMistral, pnlBedrock, pnlSystemPrompt,
    pnlTemplatesLeft, pnlTemplatesLeftButtons, pnlTemplatesClient, FPnlGeneral,
    FPnlCliMcp], LColors);

  for LEditD in FEdtTemperatures.Values do ApplyThemeToEdits([LEditD], LColors);
  for LEditD in FEdtMaxTokens.Values do ApplyThemeToEdits([LEditD], LColors);
  for LEditD in FEdtTimeouts.Values do ApplyThemeToEdits([LEditD], LColors);

  ApplyThemeToEdits([edtGeminiKey, edtOpenAIKey, edtOpenAICustomUrl, edtClaudeKey,
    edtDeepSeekKey, edtGroqKey, edtOllamaUrl, edtOpenRouterKey, edtLMStudioUrl,
    edtGithubCopilotKey, edtAzureKey, edtAzureUrl, edtAzureModel, edtAzureApiVersion,
    edtQwenKey, edtMistralKey, edtAwsAccessKeyId, edtAwsSecretAccessKey,
    edtAwsRegion, edtAwsSessionToken, edtTemplateName, edtTemplateDesc, edtTemplateSlash,
    FEdtLogPath, FEdtLogMaxSize, FEdtQuotaLimit, FEdtConsentTimeout,
    FEdtInlineCompletionDelay, FEdtInlineCompletionExcludedFiles,
    FEdtInlineCompletionExcludedLanguages,
    FEdtInlineCompletionExcludedProjects, FEdtKnowledgeExcludedFiles,
    FEdtKnowledgeExcludedProjects,
    FEdtKnowledgeRemoteEndpoint, FEdtKnowledgeRemoteModel,
    FEdtKnowledgeRemoteApiKey, FEdtKnowledgeRemoteDimensions,
    FEdtKnowledgeRemoteTimeout, FEdtKnowledgeRemoteInputLimit,
    FEdtInlineShortcutProfile,
    FEdtCliExecutable, FEdtMcpConfig, FEdtMcpBridge], LColors);

  ApplyThemeToLabels([lblGeminiKey, lblOpenAIKey, lblOpenAICustomUrl, lblClaudeKey,
    lblDeepSeekKey, lblGroqKey, lblOllamaUrl, lblOpenRouterKey, lblLMStudioUrl,
    lblAzureKey, lblAzureUrl, lblAzureModel, lblAzureApiVersion, lblQwenKey,
    lblMistralKey, lblAwsAccessKeyId, lblAwsSecretAccessKey, lblAwsRegion,
    lblAwsSessionToken, lblTemplateName, lblTemplateDesc, lblTemplateSlash,
    lblTemplateBody, FLblTemplateOrigin, FLblLogPath, FLblQuotaLimit, FLblQuotaUsed,
    FLblConsentSummary, FLblConsentTimeout, FLblCliStatus,
    FLblInlineCompletionDelay, FLblInlineCompletionExcludedFiles,
    FLblInlineCompletionExcludedLanguages,
    FLblInlineCompletionExcludedProjects, FLblKnowledgeExcludedFiles,
    FLblKnowledgeExcludedProjects,
    FLblKnowledgeRemoteEndpoint, FLblKnowledgeRemoteModel,
    FLblKnowledgeRemoteApiKey, FLblKnowledgeRemoteLimits,
    FLblInlineShortcutProfile,
    FLblMcpStatus], LColors, False);

  ApplyThemeToLabels([lnkGeminiGetKey, lnkOpenAIGetKey, lnkClaudeGetKey, lnkDeepSeekGetKey,
    lnkGroqGetKey, lnkOpenRouterGetKey, lnkQwenGetKey, lnkMistralGetKey, lnkBedrockGetKey], LColors, True);

  memSystemPrompt.StyleElements := memSystemPrompt.StyleElements - [seClient, seBorder];
  memSystemPrompt.Color := LColors.InputBgColor;
  memSystemPrompt.Font.Color := LColors.TextColor;

  memTemplateBody.StyleElements := memTemplateBody.StyleElements - [seClient, seBorder];
  memTemplateBody.Color := LColors.InputBgColor;
  memTemplateBody.Font.Color := LColors.TextColor;

  lstTemplates.StyleElements := lstTemplates.StyleElements - [seClient, seBorder];
  lstTemplates.Color := LColors.InputBgColor;
  lstTemplates.Font.Color := LColors.TextColor;

  FMemoMcpPreview.StyleElements :=
    FMemoMcpPreview.StyleElements - [seClient, seBorder];
  FMemoMcpPreview.Color := LColors.InputBgColor;
  FMemoMcpPreview.Font.Color := LColors.TextColor;
  FCmbCliClient.StyleElements :=
    FCmbCliClient.StyleElements - [seClient, seBorder];
  FCmbCliClient.Color := LColors.InputBgColor;
  FCmbCliClient.Font.Color := LColors.TextColor;
  FCmbAgentExecutor.StyleElements :=
    FCmbAgentExecutor.StyleElements - [seClient, seBorder];
  FCmbAgentExecutor.Color := LColors.InputBgColor;
  FCmbAgentExecutor.Font.Color := LColors.TextColor;

  ApplyThemeToCheckboxes([chkIsProjectGenerator, FChkSmartConfig, FChkInjectDelphiVersion,
    FChkConciseResponses, FChkLogEnabled, FChkQuotaEnabled,
    FChkConsentShowArguments, FChkConsentRememberReversible,
    FChkConsentRememberStructural, FChkConsentRememberExecution,
    FChkKnowledgeSemanticEnabled, FChkKnowledgeApprovedHistoryEnabled,
    FChkKnowledgeRemoteEnabled, FChkKnowledgeRemoteConsent,
    FChkInlineCompletionEnabled], LColors);

  ApplyThemeToRadioGroups([grpGeminiAuthType, grpOpenAIAuthType], LColors);
  ApplyThemeToGroupBoxes([FGrpQuota], LColors);
end;

procedure TRadIAFrameAIConfig.LoadConfig;
begin
  FPresenter.LoadConfig;
end;

procedure TRadIAFrameAIConfig.lstTemplatesClick(Sender: TObject);
begin
  FPresenter.HandleTemplateSelected;
end;

procedure TRadIAFrameAIConfig.btnNewTemplateClick(Sender: TObject);
begin
  FPresenter.CreateNewTemplate;
end;

procedure TRadIAFrameAIConfig.btnDeleteTemplateClick(Sender: TObject);
var
  LConfirmMsg: string;
begin
  if lstTemplates.ItemIndex < 0 then
  begin
    ShowMessage('Please select a template.');
    Exit;
  end;

  if SameText(btnDeleteTemplate.Caption, 'Restore Default') then
    LConfirmMsg := 'Do you really want to restore the default template "' +
                   lstTemplates.Items[lstTemplates.ItemIndex] + '"' +
        ' ' +
        '' +
        'to its original content?'
  else
    LConfirmMsg := 'Are you sure you want to delete the template "' + lstTemplates.Items[lstTemplates.ItemIndex] + '"?';

  if MessageDlg(LConfirmMsg, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FPresenter.DeleteTemplate;
  end;
end;

procedure TRadIAFrameAIConfig.btnSaveTemplateClick(Sender: TObject);
begin
  FPresenter.SaveTemplate;
end;

procedure TRadIAFrameAIConfig.btnRestoreDefaultsClick(Sender: TObject);
begin
  if MessageDlg('Are you sure you want to restore default templates? This will overwrite your changes.',
    mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    FPresenter.RestoreDefaultTemplates;
  end;
end;

procedure TRadIAFrameAIConfig.btnExportTemplatesClick(Sender: TObject);
begin
  FPresenter.ExportTemplates;
end;

procedure TRadIAFrameAIConfig.btnImportTemplatesClick(Sender: TObject);
var
  LErrorMsg: string;
  LMerge: Boolean;
  LConfirm: Integer;
begin
  if dlgsTemplatesOpen.Execute then
  begin
    LConfirm := MessageDlg('Do you want to merge imported templates with the current ones?' + sLineBreak +
      'Choose "Yes" to merge or "No" to delete current templates and use only the imported ones.',
      mtConfirmation, [mbYes, mbNo, mbCancel], 0);

    if LConfirm = mrCancel then
      Exit;

    LMerge := LConfirm = mrYes;

    if FPresenter.TemplateManager.ImportFromFile(dlgsTemplatesOpen.FileName, LMerge, LErrorMsg) then
    begin
      FPresenter.LoadConfig;
      ShowMessage('Templates imported successfully.');
    end
    else
    begin
      ShowMessage('Import failed: ' + LErrorMsg);
    end;
  end;
end;

procedure TRadIAFrameAIConfig.BtnBrowseLogPathClick(Sender: TObject);
begin
  FPresenter.BrowseLogPath;
end;

procedure TRadIAFrameAIConfig.AppendCliInstallOutput(
  const AText: string
);
begin
  FMemoMcpPreview.SelStart := Length(FMemoMcpPreview.Text);
  FMemoMcpPreview.SelText := AText;
  SendMessage(FMemoMcpPreview.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TRadIAFrameAIConfig.BtnCliInstallClick(Sender: TObject);
var
  LDefinition: TRadIACliDefinition;
  LGuard: IRadIAConfigLifecycleGuard;
  LInvocation: TRadIACliInvocation;
  LPlan: TRadIACliInstallPlan;
  LPrompt: string;
begin
  if not GetSelectedCliDefinition(LDefinition) then
    Exit;
  LPlan := TRadIACliInstaller.BuildPlan(LDefinition);
  LPrompt := Format(
    'Install or update %s through its official channel?' + sLineBreak +
    sLineBreak + 'Command:' + sLineBreak + '%s' + sLineBreak +
    sLineBreak + 'Prerequisites: %s',
    [
      LDefinition.DisplayName,
      LPlan.Preview,
      string.Join(', ', LDefinition.Prerequisites)
    ]
  );
  if MessageDlg(LPrompt, mtConfirmation, [mbYes, mbNo], 0) <> mrYes then
    Exit;
  FMemoMcpPreview.Text := LPlan.Preview + sLineBreak + sLineBreak;
  LInvocation := TRadIACliInvocation.Create(
    LPlan.ExecutablePath,
    LPlan.Arguments,
    GetCurrentDir,
    'text'
  );
  LGuard := FCliInstallGuard as IRadIAConfigLifecycleGuard;
  SetCliInstallRunning(True);
  FCliInstallSession := TRadIACliProcessRunner.Start(
    LInvocation,
    10 * 60 * 1000,
    procedure(AChunk: string)
    begin
      TThread.Queue(
        nil,
        TThreadProcedure(
          procedure
          begin
            if LGuard.IsAlive then
              AppendCliInstallOutput(AChunk);
          end
        )
      );
    end,
    procedure(AChunk: string)
    begin
      TThread.Queue(
        nil,
        TThreadProcedure(
          procedure
          begin
            if LGuard.IsAlive then
              AppendCliInstallOutput(AChunk);
          end
        )
      );
    end,
    procedure(AResult: TRadIACliProcessResult)
    begin
      TThread.Queue(
        nil,
        TThreadProcedure(
          procedure
          begin
            if LGuard.IsAlive then
              CompleteCliInstall(AResult);
          end
        )
      );
    end
  );
end;

procedure TRadIAFrameAIConfig.BtnResetQuotaClick(Sender: TObject);
begin
  FPresenter.ResetQuota;
end;

procedure TRadIAFrameAIConfig.BtnRevokeConsentClick(Sender: TObject);
var
  LPolicyExecutor: IRadIAToolPolicyExecutor;
begin
  if not TRadIAContainer.TryResolve<IRadIAToolPolicyExecutor>(
    LPolicyExecutor
  ) then
  begin
    ShowMessage('The consent policy service is not available.');
    Exit;
  end;
  LPolicyExecutor.RevokeSessionPermissions;
  ShowMessage('All session permissions were revoked.');
end;

procedure TRadIAFrameAIConfig.BtnCliRefreshClick(Sender: TObject);
begin
  RefreshCliMcpDiagnostics;
end;

procedure TRadIAFrameAIConfig.BtnMcpHandshakeClick(Sender: TObject);
var
  LGuard: IRadIAConfigLifecycleGuard;
  LInvocation: TRadIACliInvocation;
begin
  SaveCliMcpSettings;
  if not TFile.Exists(FEdtMcpBridge.Text) then
  begin
    ShowMessage('The Rad IA MCP bridge executable was not found.');
    Exit;
  end;
  if not TFile.Exists(GetMcpConnectionPath) then
  begin
    ShowMessage('The MCP discovery file for this IDE instance was not found.');
    Exit;
  end;
  LInvocation := TRadIACliInvocation.Create(
    FEdtMcpBridge.Text,
    [GetMcpConnectionPath],
    TPath.GetDirectoryName(FEdtMcpBridge.Text),
    'jsonl'
  );
  FMemoMcpPreview.Text := 'Testing initialize, ping, and tools/list...' + sLineBreak;
  FLblMcpStatus.Caption := 'MCP status: testing live handshake...';
  FBtnMcpHandshake.Enabled := False;
  LGuard := FCliInstallGuard as IRadIAConfigLifecycleGuard;
  FMcpHandshakeSession := TRadIACliProcessRunner.StartWithInput(
    LInvocation,
    TRadIAMcpHandshake.BuildInput,
    30000,
    nil,
    nil,
    procedure(AResult: TRadIACliProcessResult)
    begin
      TThread.Queue(
        nil,
        TThreadProcedure(
          procedure
          begin
            if LGuard.IsAlive then
              CompleteMcpHandshake(AResult);
          end
        )
      );
    end
  );
end;

procedure TRadIAFrameAIConfig.CompleteCliInstall(
  const AResult: TRadIACliProcessResult
);
begin
  FCliInstallSession := nil;
  SetCliInstallRunning(False);
  if AResult.Succeeded then
    AppendCliInstallOutput(
      sLineBreak + 'Official installation completed successfully.' +
      sLineBreak
    )
  else if AResult.TimedOut then
    AppendCliInstallOutput(sLineBreak + 'Installation timed out.' + sLineBreak)
  else if AResult.Cancelled then
    AppendCliInstallOutput(sLineBreak + 'Installation cancelled.' + sLineBreak)
  else
    AppendCliInstallOutput(
      Format(
        sLineBreak + 'Installation failed with exit code %d.' + sLineBreak,
        [AResult.ExitCode]
      )
    );
  RefreshCliMcpDiagnostics;
end;

procedure TRadIAFrameAIConfig.CompleteMcpHandshake(
  const AResult: TRadIACliProcessResult
);
var
  LHandshake: TRadIAMcpHandshakeResult;
begin
  FMcpHandshakeSession := nil;
  FBtnMcpHandshake.Enabled := True;
  if not AResult.Succeeded then
  begin
    FLblMcpStatus.Caption := 'MCP status: live handshake failed.';
    FMemoMcpPreview.Text := Trim(AResult.StdErr);
    Exit;
  end;
  LHandshake := TRadIAMcpHandshake.ParseOutput(AResult.StdOut);
  FMemoMcpPreview.Text := LHandshake.Message;
  if LHandshake.Succeeded then
    FLblMcpStatus.Caption := Format(
      'MCP status: live handshake verified (%d tools).',
      [LHandshake.ToolCount]
    )
  else
    FLblMcpStatus.Caption := 'MCP status: ' + LHandshake.Message;
end;

procedure TRadIAFrameAIConfig.BtnMcpPreviewClick(Sender: TObject);
begin
  SaveCliMcpSettings;
  RefreshMcpPreview;
end;

procedure TRadIAFrameAIConfig.BtnMcpProvisionClick(Sender: TObject);
var
  LProfile: TRadIAMcpClientProfile;
  LProvisioner: TRadIAMcpProvisioner;
  LPreview: TRadIAMcpProvisionPreview;
  LResult: TRadIAMcpProvisionResult;
  LConfirmation: string;
begin
  if not GetSelectedMcpProfile(LProfile) then
    Exit;
  SaveCliMcpSettings;
  LProvisioner := TRadIAMcpProvisioner.Create;
  try
    LPreview := LProvisioner.Preview(
      LProfile,
      FEdtMcpConfig.Text,
      FEdtMcpBridge.Text
    );
    FMemoMcpPreview.Text := LPreview.ProposedContent;
    if LPreview.State = mpsInvalid then
    begin
      ShowMessage(LPreview.Summary);
      Exit;
    end;
    if not LPreview.Changed then
    begin
      ShowMessage('The RadIA MCP bridge is already configured.');
      Exit;
    end;
    LConfirmation := Format(
      'Connect or repair RadIA MCP for %s?' + sLineBreak + sLineBreak +
      'Configuration: %s' + sLineBreak +
      'Backup: %s.radia.bak',
      [
        LProfile.DisplayName,
        FEdtMcpConfig.Text,
        FEdtMcpConfig.Text
      ]
    );
    if MessageDlg(
      LConfirmation,
      mtConfirmation,
      [mbYes, mbNo],
      0
    ) <> mrYes then
      Exit;
    LResult := LProvisioner.Provision(
      LProfile,
      FEdtMcpConfig.Text,
      FEdtMcpBridge.Text
    );
    ShowMessage(LResult.Message);
  finally
    LProvisioner.Free;
  end;
  RefreshCliMcpDiagnostics;
end;

procedure TRadIAFrameAIConfig.BtnMcpRemoveClick(Sender: TObject);
var
  LProfile: TRadIAMcpClientProfile;
  LProvisioner: TRadIAMcpProvisioner;
  LResult: TRadIAMcpProvisionResult;
begin
  if not GetSelectedMcpProfile(LProfile) then
    Exit;
  SaveCliMcpSettings;
  if MessageDlg(
    Format(
      'Disconnect RadIA MCP from %s?' + sLineBreak + sLineBreak +
      'Only the managed RadIA entry will be removed.' + sLineBreak +
      'Configuration: %s',
      [LProfile.DisplayName, FEdtMcpConfig.Text]
    ),
    mtConfirmation,
    [mbYes, mbNo],
    0
  ) <> mrYes then
    Exit;
  LProvisioner := TRadIAMcpProvisioner.Create;
  try
    LResult := LProvisioner.Remove(
      LProfile,
      FEdtMcpConfig.Text
    );
    ShowMessage(LResult.Message);
  finally
    LProvisioner.Free;
  end;
  RefreshCliMcpDiagnostics;
end;

procedure TRadIAFrameAIConfig.CliClientChange(Sender: TObject);
var
  LDefinition: TRadIACliDefinition;
  LSettings: TRadIACliMcpClientSettings;
begin
  if not GetSelectedCliDefinition(LDefinition) then
    Exit;
  LSettings := FCliMcpSettings.Load(
    LDefinition.Id,
    GetDefaultMcpConfigPath(LDefinition.Id),
    GetBridgePath
  );
  FEdtCliExecutable.Text := LSettings.CliExecutablePath;
  FEdtMcpConfig.Text := LSettings.McpConfigPath;
  FEdtMcpBridge.Text := LSettings.McpBridgePath;
  RefreshCliMcpDiagnostics;
end;

function TRadIAFrameAIConfig.GetBridgePath: string;
var
  LBuffer: array[0..MAX_PATH] of Char;
  LModuleFile: string;
begin
  SetString(
    LModuleFile,
    LBuffer,
    GetModuleFileName(HInstance, LBuffer, Length(LBuffer))
  );
  Result := TPath.Combine(
    TPath.GetDirectoryName(LModuleFile),
    'RadIA.MCP.Bridge.exe'
  );
end;

function TRadIAFrameAIConfig.GetDefaultMcpConfigPath(
  const AClientId: string
): string;
var
  LHomePath: string;
begin
  LHomePath := TPath.GetHomePath;
  if SameText(AClientId, 'codex') then
    Exit(TPath.Combine(LHomePath, '.codex\config.toml'));
  if SameText(AClientId, 'claude') then
    Exit(TPath.Combine(LHomePath, '.claude.json'));
  if SameText(AClientId, 'gemini') then
    Exit(TPath.Combine(LHomePath, '.gemini\settings.json'));
  if SameText(AClientId, 'copilot') then
    Exit(TPath.Combine(LHomePath, '.copilot\mcp-config.json'));
  Result := '';
end;

function TRadIAFrameAIConfig.GetMcpConnectionPath: string;
begin
  Result := TPath.Combine(
    TPath.Combine(TPath.GetHomePath, 'RadIA'),
    Format('mcp.%d.json', [GetCurrentProcessId])
  );
end;

function TRadIAFrameAIConfig.GetSelectedCliDefinition(
  out ADefinition: TRadIACliDefinition
): Boolean;
var
  LDefinitions: TArray<TRadIACliDefinition>;
begin
  LDefinitions := TRadIACliCatalog.All;
  Result :=
    (FCmbCliClient.ItemIndex >= Low(LDefinitions)) and
    (FCmbCliClient.ItemIndex <= High(LDefinitions));
  if Result then
    ADefinition := LDefinitions[FCmbCliClient.ItemIndex]
  else
    ADefinition := Default(TRadIACliDefinition);
end;

function TRadIAFrameAIConfig.GetSelectedMcpProfile(
  out AProfile: TRadIAMcpClientProfile
): Boolean;
var
  LDefinition: TRadIACliDefinition;
begin
  Result :=
    GetSelectedCliDefinition(LDefinition) and
    TRadIAMcpClientCatalog.FindById(LDefinition.Id, AProfile);
  if not Result then
    AProfile := Default(TRadIAMcpClientProfile);
end;

function TRadIAFrameAIConfig.McpStateText(
  const AState: TRadIAMcpProvisionState
): string;
begin
  case AState of
    mpsMissing:
      Result := 'not configured';
    mpsConfigured:
      Result := 'configured and verified';
    mpsDrifted:
      Result := 'configuration differs; repair is available';
    mpsInvalid:
      Result := 'invalid configuration; no write will be performed';
  else
    Result := 'unknown';
  end;
end;

procedure TRadIAFrameAIConfig.RefreshCliMcpDiagnostics;
var
  LDefinition: TRadIACliDefinition;
  LDetection: TRadIACliDetection;
  LDetector: TRadIACliDetector;
begin
  if not GetSelectedCliDefinition(LDefinition) then
    Exit;
  SaveCliMcpSettings;
  LDetector := TRadIACliDetector.Create;
  try
    LDetection := LDetector.Detect(
      LDefinition,
      FEdtCliExecutable.Text
    );
  finally
    LDetector.Free;
  end;
  if LDetection.Installed then
  begin
    FLblCliStatus.Caption := Format(
      'CLI status: detected via %s at %s; reading version...',
      [LDetection.Source, LDetection.ExecutablePath]
    );
    FBtnCliInstall.Caption := 'Update';
    StartCliVersionProbe(
      LDefinition,
      LDetection.ExecutablePath
    );
  end
  else
  begin
    FLblCliStatus.Caption :=
      'CLI status: not detected. Install it through the official channel.';
    FBtnCliInstall.Caption := 'Install';
  end;
  FBtnCliInstall.Enabled := not Assigned(FCliInstallSession);
  RefreshMcpPreview;
end;

procedure TRadIAFrameAIConfig.CompleteCliVersionProbe(
  const ACliId: string;
  const AExecutablePath: string;
  const ARequestId: Integer;
  const AResult: TRadIACliProcessResult
);
var
  LDefinition: TRadIACliDefinition;
  LVersion: string;
begin
  if ARequestId <> FCliVersionRequestId then
    Exit;
  FCliVersionSession := nil;
  if not GetSelectedCliDefinition(LDefinition) then
    Exit;
  if not SameText(LDefinition.Id, ACliId) then
    Exit;
  LVersion := TRadIACliHealth.NormalizeVersionOutput(
    AResult.StdOut,
    AResult.StdErr
  );
  if AResult.Succeeded and (LVersion <> '') then
    FLblCliStatus.Caption := Format(
      'CLI status: %s detected at %s (%s)',
      [LDefinition.DisplayName, AExecutablePath, LVersion]
    )
  else
    FLblCliStatus.Caption := Format(
      'CLI status: detected at %s, but the version check failed.',
      [AExecutablePath]
    );
end;

procedure TRadIAFrameAIConfig.RefreshMcpPreview;
var
  LProfile: TRadIAMcpClientProfile;
  LPreview: TRadIAMcpProvisionPreview;
  LProvisioner: TRadIAMcpProvisioner;
begin
  if not GetSelectedMcpProfile(LProfile) then
    Exit;
  LProvisioner := TRadIAMcpProvisioner.Create;
  try
    LPreview := LProvisioner.Preview(
      LProfile,
      FEdtMcpConfig.Text,
      FEdtMcpBridge.Text
    );
  finally
    LProvisioner.Free;
  end;
  if not TFile.Exists(FEdtMcpBridge.Text) then
    FLblMcpStatus.Caption :=
      'MCP status: RadIA.MCP.Bridge.exe was not found at the selected path.'
  else
    FLblMcpStatus.Caption := 'MCP status: ' + McpStateText(LPreview.State);
  FBtnMcpProvision.Enabled :=
    TFile.Exists(FEdtMcpBridge.Text) and
    (LPreview.State <> mpsInvalid) and
    LPreview.Changed;
  FBtnMcpRemove.Enabled :=
    (LPreview.State <> mpsMissing) and
    (LPreview.State <> mpsInvalid);
  FBtnMcpHandshake.Enabled :=
    TFile.Exists(FEdtMcpBridge.Text) and
    TFile.Exists(GetMcpConnectionPath) and
    not Assigned(FMcpHandshakeSession);
  if LPreview.State = mpsInvalid then
    FMemoMcpPreview.Text := LPreview.Summary
  else
    FMemoMcpPreview.Text := LPreview.ProposedContent;
end;

procedure TRadIAFrameAIConfig.SaveCliMcpSettings;
var
  LDefinition: TRadIACliDefinition;
begin
  if not GetSelectedCliDefinition(LDefinition) then
    Exit;
  FCliMcpSettings.Save(
    LDefinition.Id,
    TRadIACliMcpClientSettings.Create(
      Trim(FEdtCliExecutable.Text),
      Trim(FEdtMcpConfig.Text),
      Trim(FEdtMcpBridge.Text)
    )
  );
end;

procedure TRadIAFrameAIConfig.SetCliInstallRunning(
  const ARunning: Boolean
);
begin
  FCmbCliClient.Enabled := not ARunning;
  FBtnCliRefresh.Enabled := not ARunning;
  FBtnCliInstall.Enabled := not ARunning;
  if ARunning then
    FLblCliStatus.Caption := 'CLI status: installing through the official channel...';
end;

procedure TRadIAFrameAIConfig.StartCliVersionProbe(
  const ADefinition: TRadIACliDefinition;
  const AExecutablePath: string
);
var
  LGuard: IRadIAConfigLifecycleGuard;
  LInvocation: TRadIACliInvocation;
  LRequestId: Integer;
begin
  if Assigned(FCliVersionSession) then
    FCliVersionSession.Cancel;
  Inc(FCliVersionRequestId);
  LRequestId := FCliVersionRequestId;
  LInvocation := TRadIACliInvocation.Create(
    AExecutablePath,
    ['--version'],
    GetCurrentDir,
    'text'
  );
  LGuard := FCliInstallGuard as IRadIAConfigLifecycleGuard;
  FCliVersionSession := TRadIACliProcessRunner.Start(
    LInvocation,
    10000,
    nil,
    nil,
    procedure(AResult: TRadIACliProcessResult)
    begin
      TThread.Queue(
        nil,
        TThreadProcedure(
          procedure
          begin
            if LGuard.IsAlive then
              CompleteCliVersionProbe(
                ADefinition.Id,
                AExecutablePath,
                LRequestId,
                AResult
              );
          end
        )
      );
    end
  );
end;

procedure TRadIAFrameAIConfig.LoadAgentExecutorSettings;
var
  LDefinition: TRadIACliDefinition;
  LDefinitions: TArray<TRadIACliDefinition>;
  LIndex: Integer;
  LSettings: TRadIAAgentExecutorSettings;
begin
  LSettings := FAgentExecutorSettings.Load;
  FCmbAgentExecutor.ItemIndex := Ord(LSettings.Kind);
  LDefinitions := TRadIACliCatalog.All;
  for LIndex := Low(LDefinitions) to High(LDefinitions) do
  begin
    LDefinition := LDefinitions[LIndex];
    if SameText(LDefinition.Id, LSettings.CliClientId) then
    begin
      FCmbCliClient.ItemIndex := LIndex;
      CliClientChange(FCmbCliClient);
      Break;
    end;
  end;
end;

procedure TRadIAFrameAIConfig.SaveAgentExecutorSettings;
var
  LDefinition: TRadIACliDefinition;
  LKind: TRadIAAgentExecutorKind;
begin
  if not GetSelectedCliDefinition(LDefinition) then
    Exit;
  if FCmbAgentExecutor.ItemIndex = Ord(aekCli) then
    LKind := aekCli
  else
    LKind := aekNative;
  FAgentExecutorSettings.Save(
    TRadIAAgentExecutorSettings.Create(LKind, LDefinition.Id)
  );
end;

procedure TRadIAFrameAIConfig.TvCategoriesChange(Sender: TObject; Node: TTreeNode);
begin
  if Assigned(Node) then
    SelectCategoryByName(Node.Text);
end;

procedure TRadIAFrameAIConfig.SelectCategoryByName(const ACategoryName: string);
var
  LNames: TArray<string>;
  LPages: TArray<TTabSheet>;
  I: Integer;
begin
  LNames := ['General / Logs', 'Security & Consent', 'CLI & MCP',
             'System Prompt', 'Templates',
             'Gemini', 'OpenAI',
             'Claude', 'DeepSeek', 'Groq', 'Ollama', 'OpenRouter', 'LM Studio',
             'GitHub Copilot', 'Azure OpenAI', 'Alibaba Qwen', 'Mistral AI', 'AWS Bedrock'];

  LPages := [FTsGeneral, FTsSecurity, FTsCliMcp, tsSystemPrompt,
             tsTemplates, tsGemini, tsOpenAI,
             tsClaude, tsDeepSeek, tsGroq, tsOllama, tsOpenRouter, tsLMStudio,
             tsGithubCopilot, tsAzureOpenAI, tsQwen, tsMistral, tsBedrock];

  for I := Low(LNames) to High(LNames) do
  begin
    if SameText(LNames[I], ACategoryName) then
    begin
      pgcSettings.ActivePage := LPages[I];
      Exit;
    end;
  end;
end;

procedure TRadIAFrameAIConfig.grpGeminiAuthTypeClick(Sender: TObject);
var
  LIsApiKey: Boolean;
begin
  LIsApiKey := grpGeminiAuthType.ItemIndex = 0;
  edtGeminiKey.Enabled := LIsApiKey;
  lblGeminiKey.Enabled := LIsApiKey;
  btnGeminiWebLogin.Enabled := not LIsApiKey;
  if not LIsApiKey then
    edtGeminiKey.Text := '';
end;

procedure TRadIAFrameAIConfig.grpOpenAIAuthTypeClick(Sender: TObject);
var
  LIsApiKey: Boolean;
begin
  LIsApiKey := grpOpenAIAuthType.ItemIndex = 0;
  edtOpenAIKey.Enabled := LIsApiKey;
  lblOpenAIKey.Enabled := LIsApiKey;
  edtOpenAICustomUrl.Enabled := LIsApiKey;
  lblOpenAICustomUrl.Enabled := LIsApiKey;
  btnOpenAIWebLogin.Enabled := not LIsApiKey;
  if not LIsApiKey then
  begin
    edtOpenAIKey.Text := '';
    edtOpenAICustomUrl.Text := '';
  end;
end;

procedure TRadIAFrameAIConfig.OpenUrl(const AUrl: string);
begin
  ShellExecute(0, 'open', PChar(AUrl), nil, nil, SW_SHOWNORMAL);
end;

procedure TRadIAFrameAIConfig.lnkGeminiGetKeyClick(Sender: TObject);
begin
  OpenUrl('https://aistudio.google.com/app/apikey');
end;

procedure TRadIAFrameAIConfig.lnkOpenAIGetKeyClick(Sender: TObject);
begin
  OpenUrl('https://platform.openai.com/api-keys');
end;

procedure TRadIAFrameAIConfig.lnkClaudeGetKeyClick(Sender: TObject);
begin
  OpenUrl('https://console.anthropic.com/settings/keys');
end;

procedure TRadIAFrameAIConfig.lnkDeepSeekGetKeyClick(Sender: TObject);
begin
  OpenUrl('https://platform.deepseek.com/api_keys');
end;

procedure TRadIAFrameAIConfig.lnkGroqGetKeyClick(Sender: TObject);
begin
  OpenUrl('https://console.groq.com/keys');
end;

procedure TRadIAFrameAIConfig.lnkOpenRouterGetKeyClick(Sender: TObject);
begin
  OpenUrl('https://openrouter.ai/keys');
end;

procedure TRadIAFrameAIConfig.lnkQwenGetKeyClick(Sender: TObject);
begin
  OpenUrl('https://bailian.console.aliyun.com/');
end;

procedure TRadIAFrameAIConfig.lnkMistralGetKeyClick(Sender: TObject);
begin
  OpenUrl('https://console.mistral.ai/api-keys/');
end;

procedure TRadIAFrameAIConfig.lnkBedrockGetKeyClick(Sender: TObject);
begin
  OpenUrl('https://console.aws.amazon.com/iam/');
end;

procedure TRadIAFrameAIConfig.btnConnectGithubClick(Sender: TObject);
var
  LToken: string;
begin
  if TRadIAFormGithubAuth.Execute(Self, LToken) then
  begin
    FPresenter.ConnectGithub(LToken);
  end;
end;

procedure TRadIAFrameAIConfig.btnImportVSCodeClick(Sender: TObject);
var
  LPath, LJsonStr, LToken, LUser: string;
  LJson, LGitHubNode: TJSONObject;
  LValue: TJSONValue;
begin
  LPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) +
    'Code\User\globalStorage\github.copilot\hosts.json';
  if not TFile.Exists(LPath) then
    LPath := IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) +
      'Code\User\globalStorage\github.copilot-insiders\hosts.json';

  if not TFile.Exists(LPath) then
  begin
    ShowMessage('Could not find the Copilot configuration in VS Code.');
    Exit;
  end;

  try
    LJsonStr := TFile.ReadAllText(LPath, TEncoding.UTF8);
    LJson := TJSONObject.ParseJSONValue(LJsonStr) as TJSONObject;
  except
    on E: Exception do
    begin
      ShowMessage('Erro ao ler credenciais do VS Code: ' + E.Message);
      Exit;
    end;
  end;

  if not Assigned(LJson) then Exit;
  try
    LGitHubNode := LJson.GetValue('github.com') as TJSONObject;
    if not Assigned(LGitHubNode) then
    begin
      ShowMessage('The VS Code credentials file was found, but it did not contain a valid token.');
      Exit;
    end;

    LToken := '';
    LValue := LGitHubNode.GetValue('oauth_token');
    if Assigned(LValue) then LToken := LValue.Value;

    LUser := '';
    LValue := LGitHubNode.GetValue('user');
    if Assigned(LValue) then LUser := LValue.Value;

    if not LToken.IsEmpty then
      FPresenter.ImportVSCodeCopilotToken(LToken, LUser)
    else
      ShowMessage('The VS Code credentials file was found, but it did not contain a valid token.');
  finally
    LJson.Free;
  end;
end;

procedure TRadIAFrameAIConfig.btnGeminiWebLoginClick(Sender: TObject);
begin
  if SameText(btnGeminiWebLogin.Caption, 'Sign Out') then
    FPresenter.PerformOAuthLogoff('Gemini')
  else
    FPresenter.StartOAuthLogin('Gemini');
end;

procedure TRadIAFrameAIConfig.btnOpenAIWebLoginClick(Sender: TObject);
begin
  if SameText(btnOpenAIWebLogin.Caption, 'Sign Out') then
    FPresenter.PerformOAuthLogoff('OpenAI')
  else
    FPresenter.StartOAuthLogin('OpenAI');
end;

procedure TRadIAFrameAIConfig.UpdateOAuthState(const AProviderId: string; const AIsLoggedIn: Boolean);
begin
  if SameText(AProviderId, 'Gemini') then
  begin
    if AIsLoggedIn then
      btnGeminiWebLogin.Caption := 'Sign Out'
    else
      btnGeminiWebLogin.Caption := 'Sign In with Google';
  end
  else if SameText(AProviderId, 'OpenAI') then
  begin
    if AIsLoggedIn then
      btnOpenAIWebLogin.Caption := 'Sign Out'
    else
      btnOpenAIWebLogin.Caption := 'Sign In with ChatGPT';
  end;
end;

procedure TRadIAFrameAIConfig.BtnSaveClick(Sender: TObject);
begin
  SaveCliMcpSettings;
  SaveAgentExecutorSettings;
  FPresenter.SaveConfig;
end;

procedure TRadIAFrameAIConfig.BtnCancelClick(Sender: TObject);
begin
  FPresenter.CancelConfig;
end;

{ IRadIAConfigView Implementation }

function TRadIAFrameAIConfig.GetApiKey(const AProviderId: string): string;
begin
  if SameText(AProviderId, 'Gemini') then Result := edtGeminiKey.Text
  else if SameText(AProviderId, 'OpenAI') then Result := edtOpenAIKey.Text
  else if SameText(AProviderId, 'Claude') then Result := edtClaudeKey.Text
  else if SameText(AProviderId, 'DeepSeek') then Result := edtDeepSeekKey.Text
  else if SameText(AProviderId, 'Groq') then Result := edtGroqKey.Text
  else if SameText(AProviderId, 'OpenRouter') then Result := edtOpenRouterKey.Text
  else if SameText(AProviderId, 'GithubCopilot') then Result := edtGithubCopilotKey.Text
  else if SameText(AProviderId, 'AzureOpenAI') then Result := edtAzureKey.Text
  else if SameText(AProviderId, 'Qwen') then Result := edtQwenKey.Text
  else if SameText(AProviderId, 'Mistral') then Result := edtMistralKey.Text
  else Result := '';
end;

procedure TRadIAFrameAIConfig.SetApiKey(const AProviderId: string; const AKey: string);
begin
  if SameText(AProviderId, 'Gemini') then edtGeminiKey.Text := AKey
  else if SameText(AProviderId, 'OpenAI') then edtOpenAIKey.Text := AKey
  else if SameText(AProviderId, 'Claude') then edtClaudeKey.Text := AKey
  else if SameText(AProviderId, 'DeepSeek') then edtDeepSeekKey.Text := AKey
  else if SameText(AProviderId, 'Groq') then edtGroqKey.Text := AKey
  else if SameText(AProviderId, 'OpenRouter') then edtOpenRouterKey.Text := AKey
  else if SameText(AProviderId, 'GithubCopilot') then edtGithubCopilotKey.Text := AKey
  else if SameText(AProviderId, 'AzureOpenAI') then edtAzureKey.Text := AKey
  else if SameText(AProviderId, 'Qwen') then edtQwenKey.Text := AKey
  else if SameText(AProviderId, 'Mistral') then edtMistralKey.Text := AKey;
end;

function TRadIAFrameAIConfig.GetCustomUrl(const AProviderId: string): string;
begin
  if SameText(AProviderId, 'OpenAI') then Result := edtOpenAICustomUrl.Text
  else if SameText(AProviderId, 'Ollama') then Result := edtOllamaUrl.Text
  else if SameText(AProviderId, 'LMStudio') then Result := edtLMStudioUrl.Text
  else if SameText(AProviderId, 'AzureOpenAI') then Result := edtAzureUrl.Text
  else Result := '';
end;

procedure TRadIAFrameAIConfig.SetCustomUrl(const AProviderId: string; const AUrl: string);
begin
  if SameText(AProviderId, 'OpenAI') then edtOpenAICustomUrl.Text := AUrl
  else if SameText(AProviderId, 'Ollama') then edtOllamaUrl.Text := AUrl
  else if SameText(AProviderId, 'LMStudio') then edtLMStudioUrl.Text := AUrl
  else if SameText(AProviderId, 'AzureOpenAI') then edtAzureUrl.Text := AUrl;
end;

function TRadIAFrameAIConfig.GetAuthTypeIndex(const AProviderId: string): Integer;
begin
  if SameText(AProviderId, 'Gemini') then Result := grpGeminiAuthType.ItemIndex
  else if SameText(AProviderId, 'OpenAI') then Result := grpOpenAIAuthType.ItemIndex
  else Result := 0;
end;

procedure TRadIAFrameAIConfig.SetAuthTypeIndex(const AProviderId: string; const AIndex: Integer);
begin
  if SameText(AProviderId, 'Gemini') then
  begin
    grpGeminiAuthType.ItemIndex := AIndex;
    grpGeminiAuthTypeClick(grpGeminiAuthType);
  end
  else if SameText(AProviderId, 'OpenAI') then
  begin
    grpOpenAIAuthType.ItemIndex := AIndex;
    grpOpenAIAuthTypeClick(grpOpenAIAuthType);
  end;
end;

function TRadIAFrameAIConfig.GetTemperatureInput(const AProviderId: string): string;
var
  LEdit: TEdit;
begin
  if FEdtTemperatures.TryGetValue(AProviderId, LEdit) then Result := LEdit.Text else Result := '0.7';
end;

procedure TRadIAFrameAIConfig.SetTemperatureInput(const AProviderId: string; const AValue: string);
var
  LEdit: TEdit;
begin
  if FEdtTemperatures.TryGetValue(AProviderId, LEdit) then LEdit.Text := AValue;
end;

function TRadIAFrameAIConfig.GetMaxTokensInput(const AProviderId: string): string;
var
  LEdit: TEdit;
begin
  if FEdtMaxTokens.TryGetValue(AProviderId, LEdit) then Result := LEdit.Text else Result := '2048';
end;

procedure TRadIAFrameAIConfig.SetMaxTokensInput(const AProviderId: string; const AValue: string);
var
  LEdit: TEdit;
begin
  if FEdtMaxTokens.TryGetValue(AProviderId, LEdit) then LEdit.Text := AValue;
end;

function TRadIAFrameAIConfig.GetTimeoutInput(const AProviderId: string): string;
var
  LEdit: TEdit;
begin
  if FEdtTimeouts.TryGetValue(AProviderId, LEdit) then Result := LEdit.Text else Result := '60';
end;

procedure TRadIAFrameAIConfig.SetTimeoutInput(const AProviderId: string; const AValue: string);
var
  LEdit: TEdit;
begin
  if FEdtTimeouts.TryGetValue(AProviderId, LEdit) then LEdit.Text := AValue;
end;

function TRadIAFrameAIConfig.GetAzureModel: string;
begin
  Result := edtAzureModel.Text;
end;

procedure TRadIAFrameAIConfig.SetAzureModel(const AValue: string);
begin
  edtAzureModel.Text := AValue;
end;

function TRadIAFrameAIConfig.GetAzureApiVersion: string;
begin
  Result := edtAzureApiVersion.Text;
end;

procedure TRadIAFrameAIConfig.SetAzureApiVersion(const AValue: string);
begin
  edtAzureApiVersion.Text := AValue;
end;

function TRadIAFrameAIConfig.GetAwsAccessKeyId: string;
begin
  Result := edtAwsAccessKeyId.Text;
end;

procedure TRadIAFrameAIConfig.SetAwsAccessKeyId(const AValue: string);
begin
  edtAwsAccessKeyId.Text := AValue;
end;

function TRadIAFrameAIConfig.GetAwsSecretAccessKey: string;
begin
  Result := edtAwsSecretAccessKey.Text;
end;

procedure TRadIAFrameAIConfig.SetAwsSecretAccessKey(const AValue: string);
begin
  edtAwsSecretAccessKey.Text := AValue;
end;

function TRadIAFrameAIConfig.GetAwsRegion: string;
begin
  Result := edtAwsRegion.Text;
end;

procedure TRadIAFrameAIConfig.SetAwsRegion(const AValue: string);
begin
  edtAwsRegion.Text := AValue;
end;

function TRadIAFrameAIConfig.GetAwsSessionToken: string;
begin
  Result := edtAwsSessionToken.Text;
end;

procedure TRadIAFrameAIConfig.SetAwsSessionToken(const AValue: string);
begin
  edtAwsSessionToken.Text := AValue;
end;

function TRadIAFrameAIConfig.GetSystemPrompt: string;
begin
  Result := memSystemPrompt.Text;
end;

procedure TRadIAFrameAIConfig.SetSystemPrompt(const AValue: string);
begin
  memSystemPrompt.Text := AValue;
end;

function TRadIAFrameAIConfig.GetSmartConfigEnabled: Boolean;
begin
  Result := FChkSmartConfig.Checked;
end;

procedure TRadIAFrameAIConfig.SetSmartConfigEnabled(const AValue: Boolean);
begin
  FChkSmartConfig.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetInjectDelphiVersion: Boolean;
begin
  Result := FChkInjectDelphiVersion.Checked;
end;

procedure TRadIAFrameAIConfig.SetInjectDelphiVersion(const AValue: Boolean);
begin
  FChkInjectDelphiVersion.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetConciseResponses: Boolean;
begin
  Result := FChkConciseResponses.Checked;
end;

procedure TRadIAFrameAIConfig.SetConciseResponses(const AValue: Boolean);
begin
  FChkConciseResponses.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetLogEnabled: Boolean;
begin
  Result := FChkLogEnabled.Checked;
end;

procedure TRadIAFrameAIConfig.SetLogEnabled(const AValue: Boolean);
begin
  FChkLogEnabled.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetLogPath: string;
begin
  Result := FEdtLogPath.Text;
end;

procedure TRadIAFrameAIConfig.SetLogPath(const AValue: string);
begin
  FEdtLogPath.Text := AValue;
end;

function TRadIAFrameAIConfig.GetLogMaxSize: string;
begin
  Result := FEdtLogMaxSize.Text;
end;

procedure TRadIAFrameAIConfig.SetLogMaxSize(const AValue: string);
begin
  FEdtLogMaxSize.Text := AValue;
end;

function TRadIAFrameAIConfig.GetConsentTimeoutSeconds: string;
begin
  Result := FEdtConsentTimeout.Text;
end;

procedure TRadIAFrameAIConfig.SetConsentTimeoutSeconds(
  const AValue: string
);
begin
  FEdtConsentTimeout.Text := AValue;
end;

function TRadIAFrameAIConfig.GetConsentShowArguments: Boolean;
begin
  Result := FChkConsentShowArguments.Checked;
end;

procedure TRadIAFrameAIConfig.SetConsentShowArguments(
  const AValue: Boolean
);
begin
  FChkConsentShowArguments.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetConsentRememberReversible: Boolean;
begin
  Result := FChkConsentRememberReversible.Checked;
end;

procedure TRadIAFrameAIConfig.SetConsentRememberReversible(
  const AValue: Boolean
);
begin
  FChkConsentRememberReversible.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetConsentRememberStructural: Boolean;
begin
  Result := FChkConsentRememberStructural.Checked;
end;

procedure TRadIAFrameAIConfig.SetConsentRememberStructural(
  const AValue: Boolean
);
begin
  FChkConsentRememberStructural.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetConsentRememberExecution: Boolean;
begin
  Result := FChkConsentRememberExecution.Checked;
end;

procedure TRadIAFrameAIConfig.SetConsentRememberExecution(
  const AValue: Boolean
);
begin
  FChkConsentRememberExecution.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeSemanticEnabled: Boolean;
begin
  Result := FChkKnowledgeSemanticEnabled.Checked;
end;

function TRadIAFrameAIConfig.GetKnowledgeApprovedHistoryEnabled: Boolean;
begin
  Result := FChkKnowledgeApprovedHistoryEnabled.Checked;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeSemanticEnabled(
  const AValue: Boolean
);
begin
  FChkKnowledgeSemanticEnabled.Checked := AValue;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeApprovedHistoryEnabled(
  const AValue: Boolean
);
begin
  FChkKnowledgeApprovedHistoryEnabled.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeExcludedFiles: string;
begin
  Result := FEdtKnowledgeExcludedFiles.Text;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeExcludedFiles(
  const AValue: string
);
begin
  FEdtKnowledgeExcludedFiles.Text := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeExcludedProjects: string;
begin
  Result := FEdtKnowledgeExcludedProjects.Text;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeExcludedProjects(
  const AValue: string
);
begin
  FEdtKnowledgeExcludedProjects.Text := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeRemoteEnabled: Boolean;
begin
  Result := FChkKnowledgeRemoteEnabled.Checked;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeRemoteEnabled(
  const AValue: Boolean
);
begin
  FChkKnowledgeRemoteEnabled.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeRemoteConsent: Boolean;
begin
  Result := FChkKnowledgeRemoteConsent.Checked;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeRemoteConsent(
  const AValue: Boolean
);
begin
  FChkKnowledgeRemoteConsent.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeRemoteEndpoint: string;
begin
  Result := FEdtKnowledgeRemoteEndpoint.Text;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeRemoteEndpoint(
  const AValue: string
);
begin
  FEdtKnowledgeRemoteEndpoint.Text := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeRemoteModel: string;
begin
  Result := FEdtKnowledgeRemoteModel.Text;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeRemoteModel(
  const AValue: string
);
begin
  FEdtKnowledgeRemoteModel.Text := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeRemoteApiKey: string;
begin
  Result := FEdtKnowledgeRemoteApiKey.Text;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeRemoteApiKey(
  const AValue: string
);
begin
  FEdtKnowledgeRemoteApiKey.Text := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeRemoteDimensions: string;
begin
  Result := FEdtKnowledgeRemoteDimensions.Text;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeRemoteDimensions(
  const AValue: string
);
begin
  FEdtKnowledgeRemoteDimensions.Text := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeRemoteTimeout: string;
begin
  Result := FEdtKnowledgeRemoteTimeout.Text;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeRemoteTimeout(
  const AValue: string
);
begin
  FEdtKnowledgeRemoteTimeout.Text := AValue;
end;

function TRadIAFrameAIConfig.GetKnowledgeRemoteInputLimit: string;
begin
  Result := FEdtKnowledgeRemoteInputLimit.Text;
end;

procedure TRadIAFrameAIConfig.SetKnowledgeRemoteInputLimit(
  const AValue: string
);
begin
  FEdtKnowledgeRemoteInputLimit.Text := AValue;
end;

function TRadIAFrameAIConfig.GetInlineCompletionEnabled: Boolean;
begin
  Result := FChkInlineCompletionEnabled.Checked;
end;

procedure TRadIAFrameAIConfig.SetInlineCompletionEnabled(
  const AValue: Boolean
);
begin
  FChkInlineCompletionEnabled.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetInlineCompletionDelay: string;
begin
  Result := FEdtInlineCompletionDelay.Text;
end;

procedure TRadIAFrameAIConfig.SetInlineCompletionDelay(
  const AValue: string
);
begin
  FEdtInlineCompletionDelay.Text := AValue;
end;

function TRadIAFrameAIConfig.GetInlineCompletionExcludedFiles: string;
begin
  Result := FEdtInlineCompletionExcludedFiles.Text;
end;

procedure TRadIAFrameAIConfig.SetInlineCompletionExcludedFiles(
  const AValue: string
);
begin
  FEdtInlineCompletionExcludedFiles.Text := AValue;
end;

function TRadIAFrameAIConfig.GetInlineCompletionExcludedLanguages:
  string;
begin
  Result := FEdtInlineCompletionExcludedLanguages.Text;
end;

procedure TRadIAFrameAIConfig.SetInlineCompletionExcludedLanguages(
  const AValue: string
);
begin
  FEdtInlineCompletionExcludedLanguages.Text := AValue;
end;

function TRadIAFrameAIConfig.GetInlineCompletionExcludedProjects:
  string;
begin
  Result := FEdtInlineCompletionExcludedProjects.Text;
end;

procedure TRadIAFrameAIConfig.SetInlineCompletionExcludedProjects(
  const AValue: string
);
begin
  FEdtInlineCompletionExcludedProjects.Text := AValue;
end;

function TRadIAFrameAIConfig.GetInlineShortcutProfile: string;
begin
  Result := FEdtInlineShortcutProfile.Text;
end;

procedure TRadIAFrameAIConfig.SetInlineShortcutProfile(
  const AValue: string
);
begin
  FEdtInlineShortcutProfile.Text := AValue;
end;

function TRadIAFrameAIConfig.GetQuotaEnabled: Boolean;
begin
  Result := FChkQuotaEnabled.Checked;
end;

procedure TRadIAFrameAIConfig.SetQuotaEnabled(const AValue: Boolean);
begin
  FChkQuotaEnabled.Checked := AValue;
end;

function TRadIAFrameAIConfig.GetQuotaLimit: string;
begin
  Result := FEdtQuotaLimit.Text;
end;

procedure TRadIAFrameAIConfig.SetQuotaLimit(const AValue: string);
begin
  FEdtQuotaLimit.Text := AValue;
end;

procedure TRadIAFrameAIConfig.SetQuotaUsedText(const AText: string);
begin
  FLblQuotaUsed.Caption := AText;
end;

procedure TRadIAFrameAIConfig.ShowMessageDialog(const AMessage: string);
begin
  ShowMessage(AMessage);
end;

function TRadIAFrameAIConfig.SaveDialogExecute(out AFileName: string): Boolean;
begin
  Result := dlgsTemplatesSave.Execute;
  if Result then AFileName := dlgsTemplatesSave.FileName;
end;

function TRadIAFrameAIConfig.OpenDialogExecute(out AFileName: string): Boolean;
begin
  Result := dlgsTemplatesOpen.Execute;
  if Result then AFileName := dlgsTemplatesOpen.FileName;
end;

function TRadIAFrameAIConfig.FolderDialogExecute(out AFolderName: string): Boolean;
begin
  Result := Vcl.FileCtrl.SelectDirectory('Select Log Folder', '', AFolderName, [sdNewUI, sdNewFolder]);
end;

procedure TRadIAFrameAIConfig.CloseView(const AModalResult: Integer);
var
  LForm: TCustomForm;
begin
  LForm := GetParentForm(Self);
  if Assigned(LForm) and SameText(LForm.ClassName, 'TRadIAFormAIConfig') then
    LForm.ModalResult := AModalResult;
end;

procedure TRadIAFrameAIConfig.UpdateTemplatesList(const ATemplateNames: TArray<string>; const ASelectedIndex: Integer);
var
  LName: string;
begin
  lstTemplates.Items.BeginUpdate;
  try
    lstTemplates.Items.Clear;
    for LName in ATemplateNames do
      lstTemplates.Items.Add(LName);
  finally
    lstTemplates.Items.EndUpdate;
  end;
  lstTemplates.ItemIndex := ASelectedIndex;
end;

procedure TRadIAFrameAIConfig.GetTemplateEditorFields(out AName, ADesc, ABody, ASlash: string; out AIsProjGen: Boolean);
begin
  AName := Trim(edtTemplateName.Text);
  ADesc := Trim(edtTemplateDesc.Text);
  ABody := memTemplateBody.Text;
  ASlash := Trim(edtTemplateSlash.Text);
  AIsProjGen := chkIsProjectGenerator.Checked;
end;

procedure TRadIAFrameAIConfig.SetTemplateFields(const AName, ADesc, ABody, ASlash: string;
    const AIsProjGen: Boolean; const AIsSystem,

    AIsCustomized: Boolean);
begin
  edtTemplateName.Text := AName;
  edtTemplateDesc.Text := ADesc;
  memTemplateBody.Text := ABody;
  edtTemplateSlash.Text := ASlash;
  chkIsProjectGenerator.Checked := AIsProjGen;
  edtTemplateName.ReadOnly := AIsSystem;
end;

procedure TRadIAFrameAIConfig.ClearTemplateFields;
begin
  edtTemplateName.Text := '';
  edtTemplateDesc.Text := '';
  memTemplateBody.Text := '';
  edtTemplateSlash.Text := '';
  chkIsProjectGenerator.Checked := False;
  edtTemplateName.ReadOnly := False;
end;

procedure TRadIAFrameAIConfig.FocusTemplateName;
begin
  edtTemplateName.SetFocus;
end;

function TRadIAFrameAIConfig.GetSelectedTemplateIndex: Integer;
begin
  Result := lstTemplates.ItemIndex;
end;

procedure TRadIAFrameAIConfig.SetSelectedTemplateIndex(const AIndex: Integer);
begin
  lstTemplates.ItemIndex := AIndex;
end;

procedure TRadIAFrameAIConfig.SetDeleteTemplateButtonState(const ACaption: string; const AEnabled: Boolean);
begin
  btnDeleteTemplate.Caption := ACaption;
  btnDeleteTemplate.Enabled := AEnabled;
end;

procedure TRadIAFrameAIConfig.SetTemplateOriginLabel(const AText: string; const AColor: TColor);
begin
  FLblTemplateOrigin.Caption := AText;
  FLblTemplateOrigin.Font.Color := AColor;
end;

end.
