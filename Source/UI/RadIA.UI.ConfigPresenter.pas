unit RadIA.UI.ConfigPresenter;

interface

uses
  Vcl.Graphics, RadIA.Core.Interfaces, RadIA.Core.PromptTemplates;

type
  IRadIAConfigView = interface
    ['{AFB8E0CA-7186-4F18-A7EE-3E081BE27FDF}']
    // General Provider Inputs
    function GetApiKey(const AProviderId: string): string;
    procedure SetApiKey(const AProviderId: string; const AKey: string);
    function GetCustomUrl(const AProviderId: string): string;
    procedure SetCustomUrl(const AProviderId: string; const AUrl: string);
    function GetAuthTypeIndex(const AProviderId: string): Integer;
    procedure SetAuthTypeIndex(const AProviderId: string; const AIndex: Integer);

    // Advanced Inputs
    function GetTemperatureInput(const AProviderId: string): string;
    procedure SetTemperatureInput(const AProviderId: string; const AValue: string);
    function GetMaxTokensInput(const AProviderId: string): string;
    procedure SetMaxTokensInput(const AProviderId: string; const AValue: string);
    function GetTimeoutInput(const AProviderId: string): string;
    procedure SetTimeoutInput(const AProviderId: string; const AValue: string);

    // Azure Specific
    function GetAzureModel: string;
    procedure SetAzureModel(const AValue: string);
    function GetAzureApiVersion: string;
    procedure SetAzureApiVersion(const AValue: string);

    // Bedrock Specific
    function GetAwsAccessKeyId: string;
    procedure SetAwsAccessKeyId(const AValue: string);
    function GetAwsSecretAccessKey: string;
    procedure SetAwsSecretAccessKey(const AValue: string);
    function GetAwsRegion: string;
    procedure SetAwsRegion(const AValue: string);
    function GetAwsSessionToken: string;
    procedure SetAwsSessionToken(const AValue: string);

    // System Prompt and General
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
    procedure UpdateOAuthState(const AProviderId: string; const AIsLoggedIn: Boolean);

    // Dialogs and lifecycle
    procedure ShowMessageDialog(const AMessage: string);
    function SaveDialogExecute(out AFileName: string): Boolean;
    function OpenDialogExecute(out AFileName: string): Boolean;
    function FolderDialogExecute(out AFolderName: string): Boolean;
    procedure CloseView(const AModalResult: Integer);

    // Templates UI
    procedure UpdateTemplatesList(const ATemplateNames: TArray<string>; const ASelectedIndex: Integer);
    procedure GetTemplateEditorFields(out AName, ADesc, ABody, ASlash: string; out AIsProjGen: Boolean);
    procedure SetTemplateFields(const AName, ADesc, ABody, ASlash: string; const AIsProjGen: Boolean; const AIsSystem,
        AIsCustomized: Boolean);
    procedure ClearTemplateFields;
    procedure FocusTemplateName;
    function GetSelectedTemplateIndex: Integer;
    procedure SetSelectedTemplateIndex(const AIndex: Integer);
    procedure SetDeleteTemplateButtonState(const ACaption: string; const AEnabled: Boolean);
    procedure SetTemplateOriginLabel(const AText: string; const AColor: TColor);
  end;

  TRadIAConfigPresenter = class
  private
    FView: IRadIAConfigView;
    FConfig: IRadIAConfig;
    FTemplateManager: TPromptTemplateManager;
    FOwnsTemplateManager: Boolean;
    FProvidersList: TArray<string>;
    FOAuthManager: TObject;

    function ValidateUrl(const AUrl: string; const AFieldName: string): Boolean;
    function ValidateUrls(const AOllamaUrl, AOpenAIUrl, ALMStudioUrl, AAzureUrl: string): Boolean;
    function ValidateProvidersParams: Boolean;
    function ValidateQuota: Boolean;
    function ValidateConsent: Boolean;
    function ValidateInlineCompletion: Boolean;
    procedure PersistConfig(const AOllamaUrl, AOpenAIUrl, ALMStudioUrl, AAzureUrl: string);
    procedure PopulateTemplatesList;
  public
    constructor Create(const AView: IRadIAConfigView; const AConfig: IRadIAConfig = nil;
        const ATemplateManager: TPromptTemplateManager = nil);
    destructor Destroy; override;

    procedure LoadConfig;
    procedure SaveConfig;
    procedure CancelConfig;

    // Templates Actions
    procedure HandleTemplateSelected;
    procedure CreateNewTemplate;
    procedure DeleteTemplate;
    procedure SaveTemplate;
    procedure RestoreDefaultTemplates;
    procedure ExportTemplates;

    // General Actions
    procedure BrowseLogPath;
    procedure ResetQuota;
    procedure ConnectGithub(const AToken: string);
    procedure ImportVSCodeCopilotToken(const AToken: string; const AUser: string);
    procedure StartOAuthLogin(const AProviderName: string);
    procedure PerformOAuthLogoff(const AProviderName: string);

    property TemplateManager: TPromptTemplateManager read FTemplateManager;
  end;

implementation

uses
  RadIA.Core.InlineShortcuts,
  System.Classes, System.SysUtils, RadIA.Core.Config, RadIA.Core.Container,
  RadIA.Core.IndyLoopback, RadIA.Core.OAuth, System.StrUtils;

{ TRadIAConfigPresenter }

constructor TRadIAConfigPresenter.Create(const AView: IRadIAConfigView; const AConfig: IRadIAConfig;
    const ATemplateManager: TPromptTemplateManager);
begin
  inherited Create;
  FView := AView;
  FOAuthManager := nil;
  FProvidersList := [
    'Gemini', 'OpenAI', 'Claude', 'DeepSeek', 'Groq', 'Ollama',
    'OpenRouter', 'LMStudio', 'GithubCopilot', 'AzureOpenAI',
    'Qwen', 'Mistral', 'Bedrock'
  ];

  if Assigned(AConfig) then
    FConfig := AConfig
  else if not TRadIAContainer.TryResolve<IRadIAConfig>(FConfig) then
    FConfig := TRadIAConfig.GetInstance;

  if Assigned(ATemplateManager) then
  begin
    FTemplateManager := ATemplateManager;
    FOwnsTemplateManager := False;
  end
  else
  begin
    FTemplateManager := TPromptTemplateManager.Create;
    FTemplateManager.Load;
    FOwnsTemplateManager := True;
  end;
end;

destructor TRadIAConfigPresenter.Destroy;
begin
  if FOwnsTemplateManager then
    FTemplateManager.Free;
  FOAuthManager.Free;
  inherited Destroy;
end;

function TRadIAConfigPresenter.ValidateUrl(const AUrl: string; const AFieldName: string): Boolean;
begin
  Result := True;
  if not AUrl.Trim.IsEmpty then
  begin
    if not (AUrl.StartsWith('http://', True) or AUrl.StartsWith('https://', True)) then
    begin
      FView.ShowMessageDialog(AFieldName + ' must start with http:// or https://');
      Exit(False);
    end;
  end;
end;

procedure TRadIAConfigPresenter.LoadConfig;
var
  LFormatSettings: TFormatSettings;
  LProviderId: string;
  LShortcutConfig: IRadIAInlineShortcutConfig;
begin
  LFormatSettings := TFormatSettings.Invariant;

  if SameText(FConfig.GetProviderAuthType('Gemini'), 'oauth') or
     SameText(FConfig.GetProviderAuthType('Gemini'), 'web_login') then
  begin
    FView.SetAuthTypeIndex('Gemini', 1);
    FView.UpdateOAuthState('Gemini', not FConfig.GetOAuthAccessToken('Gemini').IsEmpty);
  end
  else
  begin
    FView.SetAuthTypeIndex('Gemini', 0);
    FView.UpdateOAuthState('Gemini', False);
  end;

  if SameText(FConfig.GetProviderAuthType('OpenAI'), 'oauth') or
     SameText(FConfig.GetProviderAuthType('OpenAI'), 'web_login') then
  begin
    FView.SetAuthTypeIndex('OpenAI', 1);
    FView.UpdateOAuthState('OpenAI', not FConfig.GetOAuthAccessToken('OpenAI').IsEmpty);
  end
  else
  begin
    FView.SetAuthTypeIndex('OpenAI', 0);
    FView.UpdateOAuthState('OpenAI', False);
  end;

  FView.SetApiKey('Gemini', FConfig.GetApiKey('Gemini'));
  FView.SetApiKey('OpenAI', FConfig.GetApiKey('OpenAI'));
  FView.SetCustomUrl('OpenAI', FConfig.OpenAICustomBaseUrl);
  FView.SetApiKey('Claude', FConfig.GetApiKey('Claude'));
  FView.SetApiKey('DeepSeek', FConfig.GetApiKey('DeepSeek'));
  FView.SetApiKey('Groq', FConfig.GetApiKey('Groq'));
  FView.SetApiKey('OpenRouter', FConfig.GetApiKey('OpenRouter'));
  FView.SetSystemPrompt(FConfig.SystemPrompt);
  FView.SetCustomUrl('Ollama', FConfig.OllamaBaseUrl);

  FView.SetCustomUrl('LMStudio', FConfig.GetProviderBaseUrl('LMStudio'));
  FView.SetApiKey('GithubCopilot', FConfig.GetApiKey('GithubCopilot'));

  FView.SetApiKey('AzureOpenAI', FConfig.GetApiKey('AzureOpenAI'));
  FView.SetCustomUrl('AzureOpenAI', FConfig.GetProviderBaseUrl('AzureOpenAI'));
  FView.SetAzureModel(FConfig.GetActiveModel('AzureOpenAI'));
  FView.SetAzureApiVersion(FConfig.AzureApiVersion);

  FView.SetApiKey('Qwen', FConfig.GetApiKey('Qwen'));
  FView.SetApiKey('Mistral', FConfig.GetApiKey('Mistral'));
  FView.SetAwsAccessKeyId(FConfig.AwsAccessKeyId);
  FView.SetAwsSecretAccessKey(FConfig.AwsSecretAccessKey);
  FView.SetAwsRegion(FConfig.AwsRegion);
  FView.SetAwsSessionToken(FConfig.AwsSessionToken);

  FView.SetSmartConfigEnabled(FConfig.SmartConfigEnabled);
  FView.SetInjectDelphiVersion(FConfig.InjectDelphiVersion);
  FView.SetConciseResponses(FConfig.ConciseResponses);
  FView.SetConsentTimeoutSeconds(
    IntToStr(FConfig.ConsentTimeoutSeconds)
  );
  FView.SetConsentShowArguments(FConfig.ConsentShowArguments);
  FView.SetConsentRememberReversible(
    FConfig.ConsentRememberReversible
  );
  FView.SetConsentRememberStructural(
    FConfig.ConsentRememberStructural
  );
  FView.SetConsentRememberExecution(
    FConfig.ConsentRememberExecution
  );
  FView.SetKnowledgeSemanticEnabled(
    FConfig.KnowledgeSemanticEnabled
  );
  FView.SetKnowledgeApprovedHistoryEnabled(
    FConfig.KnowledgeApprovedHistoryEnabled
  );
  FView.SetKnowledgeExcludedFiles(
    FConfig.KnowledgeExcludedFiles
  );
  FView.SetKnowledgeExcludedProjects(
    FConfig.KnowledgeExcludedProjects
  );
  FView.SetInlineCompletionEnabled(FConfig.AutocompleteEnabled);
  FView.SetInlineCompletionDelay(
    IntToStr(FConfig.AutocompleteDelay)
  );
  FView.SetInlineCompletionExcludedFiles(
    FConfig.AutocompleteExcludedFiles
  );
  FView.SetInlineCompletionExcludedLanguages(
    FConfig.AutocompleteExcludedLanguages
  );
  FView.SetInlineCompletionExcludedProjects(
    FConfig.AutocompleteExcludedProjects
  );
  if Supports(FConfig, IRadIAInlineShortcutConfig, LShortcutConfig) then
    FView.SetInlineShortcutProfile(
      LShortcutConfig.InlineShortcutProfile
    )
  else
    FView.SetInlineShortcutProfile(
      TRadIAInlineShortcutProfile.DefaultText
    );

  // Load Advanced Parameters for registered providers
  for LProviderId in FProvidersList do
  begin
    FView.SetTemperatureInput(LProviderId, FormatFloat('0.0', FConfig.GetTemperature(LProviderId), LFormatSettings));
    FView.SetMaxTokensInput(LProviderId, IntToStr(FConfig.GetMaxTokens(LProviderId)));
    FView.SetTimeoutInput(LProviderId, IntToStr(FConfig.GetTimeout(LProviderId)));
  end;

  FView.SetLogEnabled(FConfig.LogEnabled);
  FView.SetLogPath(FConfig.LogPath);
  FView.SetLogMaxSize(IntToStr(FConfig.LogMaxSizeKB));

  FView.SetQuotaEnabled(FConfig.QuotaEnabled);
  FView.SetQuotaLimit(FConfig.QuotaLimit.ToString);
  FView.SetQuotaUsedText(Format('Monthly Used Tokens: %s', [FormatFloat('#,##0', FConfig.QuotaUsed, LFormatSettings)]));

  PopulateTemplatesList;
end;

function TRadIAConfigPresenter.ValidateUrls(const AOllamaUrl, AOpenAIUrl, ALMStudioUrl, AAzureUrl: string): Boolean;
begin
  if not ValidateUrl(AOllamaUrl, 'Ollama URL') then Exit(False);
  if not ValidateUrl(AOpenAIUrl, 'OpenAI Custom Base URL') then Exit(False);
  if not ValidateUrl(ALMStudioUrl, 'LM Studio URL') then Exit(False);
  if not ValidateUrl(AAzureUrl, 'Azure OpenAI Endpoint URL') then Exit(False);
  Result := True;
end;

function TRadIAConfigPresenter.ValidateProvidersParams: Boolean;
var
  LProviderId: string;
  LFormatSettings: TFormatSettings;
  LTemp: Double;
  LMax: Integer;
  LTime: Integer;
begin
  LFormatSettings := TFormatSettings.Invariant;
  for LProviderId in FProvidersList do
  begin
    if not TryStrToFloat(FView.GetTemperatureInput(LProviderId), LTemp, LFormatSettings) or
       (LTemp < 0.0) or (LTemp > 2.0) then
    begin
      FView.ShowMessageDialog(Format('Temperature for %s must be a valid number between 0.0 and 2.0', [LProviderId]));
      Exit(False);
    end;

    if not TryStrToInt(FView.GetMaxTokensInput(LProviderId), LMax) or (LMax <= 0) then
    begin
      FView.ShowMessageDialog(Format('Max Tokens for %s must be a valid positive integer', [LProviderId]));
      Exit(False);
    end;

    if not TryStrToInt(FView.GetTimeoutInput(LProviderId), LTime) or (LTime <= 0) then
    begin
      FView.ShowMessageDialog(Format('Timeout for %s must be a valid positive integer', [LProviderId]));
      Exit(False);
    end;
  end;
  Result := True;
end;

function TRadIAConfigPresenter.ValidateQuota: Boolean;
var
  LLimit: Int64;
begin
  if FView.GetQuotaEnabled then
  begin
    if not TryStrToInt64(FView.GetQuotaLimit, LLimit) or (LLimit <= 0) then
    begin
      FView.ShowMessageDialog('Monthly Token Limit must be a valid positive integer');
      Exit(False);
    end;
  end;
  Result := True;
end;

function TRadIAConfigPresenter.ValidateConsent: Boolean;
var
  LTimeout: Integer;
begin
  Result := TryStrToInt(
    FView.GetConsentTimeoutSeconds,
    LTimeout
  ) and (LTimeout >= 15) and (LTimeout <= 600);
  if not Result then
  begin
    FView.ShowMessageDialog(
      'Consent timeout must be between 15 and 600 seconds.'
    );
  end;
end;

function TRadIAConfigPresenter.ValidateInlineCompletion: Boolean;
var
  LDelay: Integer;
  LError: string;
  LProfile: TRadIAInlineShortcutProfile;
begin
  Result := TryStrToInt(
    FView.GetInlineCompletionDelay,
    LDelay
  ) and (LDelay >= 250) and (LDelay <= 5000);
  if not Result then
  begin
    FView.ShowMessageDialog(
      'Inline completion delay must be between 250 and 5000 milliseconds.'
    );
    Exit;
  end;
  Result := TRadIAInlineShortcutProfile.TryParse(
    FView.GetInlineShortcutProfile,
    LProfile,
    LError
  );
  if not Result then
    FView.ShowMessageDialog(
      'Invalid inline shortcut profile: ' + LError
    );
end;

procedure TRadIAConfigPresenter.PersistConfig(const AOllamaUrl, AOpenAIUrl, ALMStudioUrl, AAzureUrl: string);
var
  LFormatSettings: TFormatSettings;
  LProviderId: string;
  LShortcutConfig: IRadIAInlineShortcutConfig;
  LTemp: Double;
  LMax: Integer;
  LTime: Integer;
begin
  LFormatSettings := TFormatSettings.Invariant;

  if FView.GetAuthTypeIndex('Gemini') = 1 then
    FConfig.SetProviderAuthType('Gemini', 'oauth')
  else
    FConfig.SetProviderAuthType('Gemini', 'api_key');

  if FView.GetAuthTypeIndex('OpenAI') = 1 then
    FConfig.SetProviderAuthType('OpenAI', 'oauth')
  else
    FConfig.SetProviderAuthType('OpenAI', 'api_key');

  FConfig.SetApiKey('Gemini', Trim(FView.GetApiKey('Gemini')));
  FConfig.SetApiKey('OpenAI', Trim(FView.GetApiKey('OpenAI')));
  FConfig.OpenAICustomBaseUrl := AOpenAIUrl;
  FConfig.SetApiKey('Claude', Trim(FView.GetApiKey('Claude')));
  FConfig.SetApiKey('DeepSeek', Trim(FView.GetApiKey('DeepSeek')));
  FConfig.SetApiKey('Groq', Trim(FView.GetApiKey('Groq')));
  FConfig.SetApiKey('OpenRouter', Trim(FView.GetApiKey('OpenRouter')));
  FConfig.SetApiKey('GithubCopilot', Trim(FView.GetApiKey('GithubCopilot')));

  FConfig.SetApiKey('AzureOpenAI', Trim(FView.GetApiKey('AzureOpenAI')));
  FConfig.SetProviderBaseUrl('AzureOpenAI', AAzureUrl);
  FConfig.SetActiveModel('AzureOpenAI', Trim(FView.GetAzureModel));
  FConfig.AzureApiVersion := Trim(FView.GetAzureApiVersion);

  FConfig.SetApiKey('Qwen', Trim(FView.GetApiKey('Qwen')));
  FConfig.SetApiKey('Mistral', Trim(FView.GetApiKey('Mistral')));
  FConfig.AwsAccessKeyId := Trim(FView.GetAwsAccessKeyId);
  FConfig.AwsSecretAccessKey := Trim(FView.GetAwsSecretAccessKey);
  FConfig.AwsRegion := Trim(FView.GetAwsRegion);
  FConfig.AwsSessionToken := Trim(FView.GetAwsSessionToken);

  FConfig.SystemPrompt := FView.GetSystemPrompt;
  FConfig.OllamaBaseUrl := AOllamaUrl;
  FConfig.SetProviderBaseUrl('LMStudio', ALMStudioUrl);
  FConfig.SmartConfigEnabled := FView.GetSmartConfigEnabled;
  FConfig.InjectDelphiVersion := FView.GetInjectDelphiVersion;
  FConfig.ConciseResponses := FView.GetConciseResponses;
  FConfig.ConsentTimeoutSeconds := StrToInt(
    FView.GetConsentTimeoutSeconds
  );
  FConfig.ConsentShowArguments := FView.GetConsentShowArguments;
  FConfig.ConsentRememberReversible :=
    FView.GetConsentRememberReversible;
  FConfig.ConsentRememberStructural :=
    FView.GetConsentRememberStructural;
  FConfig.ConsentRememberExecution :=
    FView.GetConsentRememberExecution;
  FConfig.KnowledgeSemanticEnabled :=
    FView.GetKnowledgeSemanticEnabled;
  FConfig.KnowledgeApprovedHistoryEnabled :=
    FView.GetKnowledgeApprovedHistoryEnabled;
  FConfig.KnowledgeExcludedFiles := Trim(
    FView.GetKnowledgeExcludedFiles
  );
  FConfig.KnowledgeExcludedProjects := Trim(
    FView.GetKnowledgeExcludedProjects
  );
  FConfig.AutocompleteEnabled :=
    FView.GetInlineCompletionEnabled;
  FConfig.AutocompleteDelay := StrToInt(
    FView.GetInlineCompletionDelay
  );
  FConfig.AutocompleteExcludedFiles := Trim(
    FView.GetInlineCompletionExcludedFiles
  );
  FConfig.AutocompleteExcludedLanguages := Trim(
    FView.GetInlineCompletionExcludedLanguages
  );
  FConfig.AutocompleteExcludedProjects := Trim(
    FView.GetInlineCompletionExcludedProjects
  );
  if Supports(FConfig, IRadIAInlineShortcutConfig, LShortcutConfig) then
    LShortcutConfig.InlineShortcutProfile := Trim(
      FView.GetInlineShortcutProfile
    );

  for LProviderId in FProvidersList do
  begin
    TryStrToFloat(FView.GetTemperatureInput(LProviderId), LTemp, LFormatSettings);
    FConfig.SetTemperature(LProviderId, LTemp);

    TryStrToInt(FView.GetMaxTokensInput(LProviderId), LMax);
    FConfig.SetMaxTokens(LProviderId, LMax);

    TryStrToInt(FView.GetTimeoutInput(LProviderId), LTime);
    FConfig.SetTimeout(LProviderId, LTime);
  end;

  FConfig.LogEnabled := FView.GetLogEnabled;
  FConfig.LogPath := Trim(FView.GetLogPath);
  FConfig.LogMaxSizeKB := StrToIntDef(FView.GetLogMaxSize, 1024);

  FConfig.QuotaEnabled := FView.GetQuotaEnabled;
  FConfig.QuotaLimit := StrToInt64Def(FView.GetQuotaLimit, 1000000);

  FConfig.Save;
  FTemplateManager.Save;

  FView.CloseView(1); // mrOk
end;

procedure TRadIAConfigPresenter.SaveConfig;
var
  LOllamaUrl: string;
  LOpenAIUrl: string;
  LLMStudioUrl: string;
  LAzureUrl: string;
begin
  LOllamaUrl := Trim(FView.GetCustomUrl('Ollama'));
  LOpenAIUrl := Trim(FView.GetCustomUrl('OpenAI'));
  LLMStudioUrl := Trim(FView.GetCustomUrl('LMStudio'));
  LAzureUrl := Trim(FView.GetCustomUrl('AzureOpenAI'));

  if not ValidateUrls(LOllamaUrl, LOpenAIUrl, LLMStudioUrl, LAzureUrl) then Exit;
  if not ValidateProvidersParams then Exit;
  if not ValidateQuota then Exit;
  if not ValidateConsent then Exit;
  if not ValidateInlineCompletion then Exit;

  PersistConfig(LOllamaUrl, LOpenAIUrl, LLMStudioUrl, LAzureUrl);
end;

procedure TRadIAConfigPresenter.CancelConfig;
begin
  LoadConfig;
  FView.CloseView(2); // mrCancel
end;



procedure TRadIAConfigPresenter.PopulateTemplatesList;
var
  LTemplate: TPromptTemplate;
  LNames: TArray<string>;
  LSelectedIndex: Integer;
begin
  LSelectedIndex := FView.GetSelectedTemplateIndex;
  LNames := [];
  for LTemplate in FTemplateManager.GetTemplates do
  begin
    LNames := LNames + [LTemplate.Name];
  end;

  if (LSelectedIndex < 0) and (Length(LNames) > 0) then
    LSelectedIndex := 0;

  FView.UpdateTemplatesList(LNames, LSelectedIndex);
end;

procedure TRadIAConfigPresenter.HandleTemplateSelected;
var
  LIndex: Integer;
  LNames: TArray<string>;
  LName: string;
  LTemplate: TPromptTemplate;
begin
  LIndex := FView.GetSelectedTemplateIndex;
  if LIndex < 0 then
  begin
    FView.ClearTemplateFields;
    FView.SetDeleteTemplateButtonState('Delete', False);
    FView.SetTemplateOriginLabel('', clBlack);
    Exit;
  end;

  LNames := [];
  for LTemplate in FTemplateManager.GetTemplates do
    LNames := LNames + [LTemplate.Name];

  if (LIndex >= 0) and (LIndex < Length(LNames)) then
  begin
    LName := LNames[LIndex];
    if FTemplateManager.FindTemplate(LName, LTemplate) then
    begin
      FView.SetTemplateFields(
        LTemplate.Name,
        LTemplate.Description,
        LTemplate.Template,
        LTemplate.SlashCommand,
        LTemplate.IsProjectGenerator,
        LTemplate.IsSystem,
        LTemplate.IsCustomized
      );

      if LTemplate.IsSystem then
      begin
        if LTemplate.IsCustomized then
        begin
          FView.SetDeleteTemplateButtonState('Restore Default', True);
          FView.SetTemplateOriginLabel('System (Customized)', $00008CFF);
        end
        else
        begin
          FView.SetDeleteTemplateButtonState('Delete', False);
          FView.SetTemplateOriginLabel('System (Read-Only)', clGrayText);
        end;
      end
      else
      begin
        FView.SetDeleteTemplateButtonState('Delete', True);
        FView.SetTemplateOriginLabel('User', clHighlight);
      end;
    end;
  end;
end;

procedure TRadIAConfigPresenter.CreateNewTemplate;
begin
  FView.SetSelectedTemplateIndex(-1);
  FView.ClearTemplateFields;
  FView.SetDeleteTemplateButtonState('Delete', False);
  FView.SetTemplateOriginLabel('', clBlack);
  FView.FocusTemplateName;
end;

procedure TRadIAConfigPresenter.DeleteTemplate;
var
  LIndex: Integer;
  LNames: TArray<string>;
  LName: string;
  LTemplate: TPromptTemplate;
begin
  LIndex := FView.GetSelectedTemplateIndex;
  if LIndex < 0 then
  begin
    FView.ShowMessageDialog('Please select a template.');
    Exit;
  end;

  LNames := [];
  for LTemplate in FTemplateManager.GetTemplates do
    LNames := LNames + [LTemplate.Name];

  LName := LNames[LIndex];
  if FTemplateManager.FindTemplate(LName, LTemplate) then
  begin
    if LTemplate.IsSystem then
    begin
      if LTemplate.IsCustomized then
      begin
        FTemplateManager.RestoreDefaultTemplate(LName);
        PopulateTemplatesList;
        HandleTemplateSelected;
      end;
    end
    else
    begin
      FTemplateManager.DeleteTemplate(LName);
      FTemplateManager.Save;
      PopulateTemplatesList;
      HandleTemplateSelected;
    end;
  end;
end;

procedure TRadIAConfigPresenter.SaveTemplate;
var
  LName, LDesc, LBody, LSlash: string;
  LIsProjGen: Boolean;
  LNames: TArray<string>;
  LTemplate: TPromptTemplate;
  LIndex: Integer;
  I: Integer;
begin
  FView.GetTemplateEditorFields(LName, LDesc, LBody, LSlash, LIsProjGen);

  if LName.Trim.IsEmpty then
  begin
    FView.ShowMessageDialog('Template Name cannot be empty.');
    Exit;
  end;

  FTemplateManager.AddTemplate(LName, LDesc, LBody, LIsProjGen, LSlash);
  FTemplateManager.Save;
  PopulateTemplatesList;

  LNames := [];
  for LTemplate in FTemplateManager.GetTemplates do
    LNames := LNames + [LTemplate.Name];

  LIndex := -1;
  for I := Low(LNames) to High(LNames) do
  begin
    if SameText(LNames[I], LName) then
    begin
      LIndex := I;
      Break;
    end;
  end;

  if LIndex >= 0 then
  begin
    FView.SetSelectedTemplateIndex(LIndex);
    HandleTemplateSelected;
  end;

  FView.ShowMessageDialog('Template saved successfully.');
end;

procedure TRadIAConfigPresenter.RestoreDefaultTemplates;
begin
  FTemplateManager.RestoreDefaultTemplates;
  PopulateTemplatesList;
  HandleTemplateSelected;
  FView.ShowMessageDialog('Default templates restored successfully.');
end;

procedure TRadIAConfigPresenter.ExportTemplates;
var
  LFileName: string;
begin
  if FView.SaveDialogExecute(LFileName) then
  begin
    try
      FTemplateManager.ExportToFile(LFileName);
      FView.ShowMessageDialog('Templates exported successfully.');
    except
      on E: Exception do
        FView.ShowMessageDialog('Failed to export templates: ' + E.Message);
    end;
  end;
end;

procedure TRadIAConfigPresenter.BrowseLogPath;
var
  LFolder: string;
begin
  if FView.FolderDialogExecute(LFolder) then
    FView.SetLogPath(LFolder);
end;

procedure TRadIAConfigPresenter.ResetQuota;
begin
  FConfig.QuotaUsed := 0;
  FConfig.QuotaCycleStart := Now;
  FConfig.Save;

  FView.SetQuotaUsedText('Monthly Used Tokens: 0');
  FView.ShowMessageDialog('Token usage counter reset successfully.');
end;

procedure TRadIAConfigPresenter.ConnectGithub(const AToken: string);
begin
  FView.SetApiKey('GithubCopilot', AToken);
  FView.ShowMessageDialog('Successfully authenticated on GitHub Copilot!');
end;

procedure TRadIAConfigPresenter.ImportVSCodeCopilotToken(const AToken: string; const AUser: string);
begin
  FView.SetApiKey('GithubCopilot', AToken);
  if not AUser.IsEmpty then
    FView.ShowMessageDialog(Format('Token successfully imported from GitHub account "%s" of VS Code!', [AUser]))
  else
    FView.ShowMessageDialog('Token successfully imported from VS Code!');
end;

procedure TRadIAConfigPresenter.StartOAuthLogin(const AProviderName: string);
var
  LAuthUrl, LTokenUrl, LClientId, LClientSecret: string;
  LPort: Word;
begin
  if SameText(AProviderName, 'Gemini') then
  begin
    FView.ShowMessageDialog(
      'Google Gemini OAuth authentication is currently pending approval.' + sLineBreak +
      'Please use an API Key for now.'
    );
    Exit;
  end;

  if SameText(AProviderName, 'OpenAI') then
  begin
    LAuthUrl := 'https://auth.openai.com/oauth/authorize';
    LTokenUrl := 'https://auth.openai.com/oauth/token';
    LClientId := 'app_EMoamEEZ73f0CkXaXp7hrann';
    LClientSecret := '';
    LPort := 1455;
  end
  else if SameText(AProviderName, 'Gemini') then
  begin
    LAuthUrl := 'https://accounts.google.com/o/oauth2/v2/auth';
    LTokenUrl := 'https://oauth2.googleapis.com/token';
    LClientId := System.StrUtils.ReverseString(
      'moc.tnetnocresuelgoog.sppa.bm93j27b6j1mhfoujc93iftrt8p1od3c-8145760122101');
    LClientSecret := System.StrUtils.ReverseString(
      'WcEIfowAsH-6TninMcAapRtWvzkI-XPSCOG');
    LPort := 59183;
  end
  else
    Exit;

  if not Assigned(FOAuthManager) then
    FOAuthManager := TRadIAOAuthManager.Create(FConfig, TRadIAIndyLoopbackServer.Create);

  try
    TRadIAOAuthManager(FOAuthManager).StartLogin(
      AProviderName,
      TRadIAOAuthParams.Create(
        LAuthUrl,
        LTokenUrl,
        LClientId,
        LClientSecret,
        LPort
      ),
      procedure
      begin
        TThread.Queue(nil,
          procedure
          begin
            FConfig.SetProviderAuthType(AProviderName, 'oauth');
            FConfig.Save;
            FView.UpdateOAuthState(AProviderName, True);
            FView.ShowMessageDialog('Login completed successfully for ' + AProviderName);
          end);
      end,
      procedure(AError: string)
      begin
        TThread.Queue(nil,
          procedure
          begin
            FView.UpdateOAuthState(AProviderName, False);
            FView.ShowMessageDialog('OAuth login failed: ' + AError);
          end);
      end
    );
    FView.ShowMessageDialog('Please complete login in the opened browser window...');
  except
    on E: Exception do
    begin
      FView.ShowMessageDialog('Failed to start OAuth flow: ' + E.Message);
    end;
  end;
end;

procedure TRadIAConfigPresenter.PerformOAuthLogoff(const AProviderName: string);
begin
  FConfig.ClearOAuthTokens(AProviderName);
  FConfig.SetProviderAuthType(AProviderName, 'api_key');
  FConfig.Save;
  FView.UpdateOAuthState(AProviderName, False);
  FView.ShowMessageDialog('Successfully logged out from ' + AProviderName);
end;

end.
