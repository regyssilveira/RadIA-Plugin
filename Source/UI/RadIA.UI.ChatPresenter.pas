unit RadIA.UI.ChatPresenter;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, RadIA.Core.Interfaces,
  RadIA.Core.Sessions, RadIA.Core.PromptTemplates,
  RadIA.Core.TokenUsage, RadIA.Core.PromptHistory, RadIA.Core.Types,
  RadIA.Core.AgentController, RadIA.Core.AgentRuntime,
  RadIA.Core.AgentExecutors, RadIA.Core.CliProcess,
  RadIA.Core.Tools, RadIA.Core.ToolSecurity, RadIA.Core.Workspace;

type
  IRadIAChatView = interface
    ['{479812B4-9226-4D20-8867-0A6F05C947D7}']
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
  end;

  TStreamChunkCtx = record
    Chunk: string;
    IsDone: Boolean;
    Error: string;
    SessionId: string;
    ActiveProvider: string;
    ActiveModel: string;
  end;

  TRadIAChatPresenter = class
  private
    FView: IRadIAChatView;
    FConfig: IRadIAConfig;
    FAIService: IRadIAService;
    FSessionManager: TRadIASessionManager;
    FPromptHistoryManager: TPromptHistoryManager;
    FTemplateManager: TPromptTemplateManager;
    FAccumulatedUsage: TTokenUsage;
    FHistory: TArray<IRadIAChatMessage>;
    FRequestInProgress: Boolean;
    FCancelledByUser: Boolean;
    FLoadingConfig: Boolean;
    FWebViewReady: Boolean;
    FPendingWebMessages: TList<string>;
    FWebFilesDir: string;
    FLifecycleGuard: IInterface;
    FActiveModels: TArray<string>;
    FPendingPrompt: string;
    FLoginPopupOpen: Boolean;
    FOwnsService: Boolean;
    FModelsProvider: IRadIAProvider;
    FDataDir: string;
    FDTOBuilder: IRadIADTOBuilder;
    FProjectGenerator: IRadIAProjectGenerator;
    FToolRegistry: IRadIAToolRegistry;
    FToolExecutor: IRadIAToolExecutor;
    FToolPolicyExecutor: IRadIAToolPolicyExecutor;
    FWorkspace: IRadIAWorkspaceFacade;
    FAgentModeEnabled: Boolean;
    FAgentController: IRadIAAgentRunController;
    FAgentExecutorSettings: TRadIAAgentExecutorSettingsStore;
    FCliProcessSession: IRadIACliProcessSession;

    procedure UpdateModelsCombo;

    procedure HandleUpdateModelsComboResult(AModels: TArray<string>; AProvider: IRadIAProvider);
    function BuildProvidersJsonArray: TJSONArray;
    function BuildModelsJsonArray(
  const AActiveProvider: string;
   LIsWebLogin: Boolean;
   out AActiveModel: string): TJSONArray;

    function BuildSlashCommandsJsonArray: TJSONArray;
    function BuildToolsJsonArray: TJSONArray;
    function ToolRiskName(const ARisk: TRadIAToolRisk): string;

    procedure LoadChatHistory;
    procedure SaveChatHistory;
    procedure LoadPromptHistory;
    procedure SavePromptHistory;
    function GetVisibleSessions: TArray<TSessionInfo>;
    procedure UpdateSessionsList;
    function PreProcessPrompt(const APromptText: string): string;

    function ExtractCodeArgument(const AArgument: string): string;
    function FindTemplateForCommand(const ACommand, AArgument: string; out ATemplate: TPromptTemplate): Boolean;

    function IsProviderConfigured(const AProviderId: string): Boolean;
    function CanChangeSession: Boolean;

    procedure SendInitialConfigToWeb;
    procedure SendModelsUpdateToWeb(const AModels: TArray<string>; const AActiveModel: string);
    procedure SendSessionsUpdateToWeb;
    procedure PostToWebView(const AAction, ARole, AText: string; const AProvider: string = '';
        const AModel: string = ''); overload;
    procedure PostToWebView(const AAction, ARole, AText: string; const AIsDone: Boolean;
        const AProvider: string = ''; const AModel: string = ''); overload;

    procedure QueueOnUI(const AProcedure: TProc);
    procedure DispatchSystemMessage(const AAction: string; const AJson: TJSONObject; var AHandled: Boolean);
    procedure DispatchSessionMessage(const AAction: string; const AJson: TJSONObject; var AHandled: Boolean);
    procedure DispatchInteractionMessage(const AAction: string; const AJson: TJSONObject; var AHandled: Boolean);
    function TryDispatchAgentInteraction(
      const AAction: string;
      const AJson: TJSONObject
    ): Boolean;
    procedure DispatchWebMessage(const AAction: string; const AJson: TJSONObject);
    function CheckQuotaAvailability: Boolean;
    function DetermineRequestProfile(const APromptText: string): TAIRequestProfile;
    procedure HandleInsertCodeMessage(const ACode: string);
    procedure HandleReadyMessage;
    procedure HandleNewChatMessage;
    procedure HandleLoadHistoryMessage;
    procedure HandleToggleHistoryMessage;
    procedure HandleOpenSettingsMessage;
    procedure HandleChangeProviderMessage(const AProvider: string);
    procedure HandleChangeModelMessage(const AModel: string);
    procedure HandleSelectSessionMessage(const ASessionId: string);
    procedure HandleRenameSessionMessage(const ASessionId, AName: string);
    procedure HandleDeleteSessionMessage(const ASessionId: string);
    procedure HandleErrorMessage(const AText: string);
    procedure HandleUpdateStreamMessage(const AText: string; const AIsDone: Boolean);
    procedure HandleSendPromptMessage(const AText: string);
    procedure HandleExecuteToolMessage(
      const AName: string;
      const AArgumentsJson: string
    );
    procedure SetAgentModeEnabled(const AEnabled: Boolean);
    procedure PostAgentModeToWeb;
    procedure StartAgentRun(const AObjective: string);
    function TryStartCliAgentRun(const AObjective: string): Boolean;
    procedure HandleCliAgentFinished(
      const AResult: TRadIACliProcessResult;
      const AClientName: string
    );
    procedure PauseAgentRun;
    procedure ResumeAgentRun;
    procedure ReplayAgentStep(const AStepIndex: Integer);
    procedure UpdateAgentPlan(const APlanJson: string);
    procedure PostAgentHistoryToWeb(const AQuery: string);
    procedure PostAgentStateToWeb(const ASnapshotJson: string);
    procedure HandleAgentFinished(
      const AResult: TRadIAAgentRunResult;
      const AProvider: string;
      const AModel: string
    );
    function BuildAgentToolCatalogJson: string;
    procedure HandleGenerateDTOMessage(const AInput, AInputType, AOutputType: string);
    procedure HandleCreateProjectMessage(const AFilesJson: string);
    procedure HandleCancelRequestMessage;
    procedure HandleClearChatMessage;
    procedure HandleStreamChunkMessage(const AText: string; const AIsDone: Boolean; const AError: string);
    function TryHandleAgentCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryHandleAgentHistoryCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryHandleAgentPlanCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryHandleAgentPreparationCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryHandleAgentReplayCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryHandleCatalogCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    procedure HandleExplicitToolCommand(
      const APromptText: string;
      const ACommandText: string
    );
    function TryHandleToolPrompt(const APromptText: string): Boolean;
    procedure ExecuteRegisteredTool(
      const AName: string;
      const AArgumentsJson: string
    );
    procedure PostToolCallToWeb(
      const AName: string;
      const AArgumentsJson: string;
      const ACorrelationId: string
    );
    procedure PostToolResultToWeb(
      const AName: string;
      const ACorrelationId: string;
      const AResult: TRadIAToolResult
    );
    class function SerializeToolResult(
      const AName: string;
      const ACorrelationId: string;
      const AResult: TRadIAToolResult
    ): string; static;
    procedure PostToolsCatalogToWeb(const AAction: string);
    procedure PostJsonToWeb(const AJson: TJSONObject);
  public
    constructor Create(
      const AView: IRadIAChatView;
      const AConfig: IRadIAConfig;
      const AService: IRadIAService = nil;
      const ADataDir: string = ''
    ); overload;
    constructor Create(
      const AView: IRadIAChatView;
      const AConfig: IRadIAConfig;
      const AService: IRadIAService;
      const ADataDir: string;
      const AToolRegistry: IRadIAToolRegistry;
      const AToolExecutor: IRadIAToolExecutor
    ); overload;
    destructor Destroy; override;

    procedure Initialize(const AWebFilesDir: string);
    procedure LoadConfig;
    procedure ProcessWebMessage(const AMessage: string);
    procedure OnWebViewReady;

    procedure SendPrompt;
    procedure SendPromptText(const APromptText: string);
    procedure SendPromptToAI(const APromptText: string);

    procedure HandleStreamSessionChange(
  AIsDone: Boolean;

  const ASessionId, AFullResponse, AActiveProvider, AActiveModel: string);

    procedure HandleStreamCancel(const AActiveProvider, AActiveModel: string; var AFullResponse: string);
    procedure HandleStreamError(const AError, AActiveProvider, AActiveModel: string; var AFullResponse: string);
    procedure HandleStreamDone(const APromptText, AActiveProvider, AActiveModel, AFullResponse: string);
    procedure ProcessStreamChunk(const ACtx: TStreamChunkCtx; var ADoneHandled: Boolean; var AFullResponse: string);
    procedure ProcessDTOGeneratorChunk(const AChunk, AError: string; const AIsDone: Boolean;
      var ADoneHandled: Boolean; const APromptText, AActiveProvider: string);

    procedure CancelRequest;
    procedure ClearChat;

    procedure ChangeProvider(const AProviderName: string);
    procedure ChangeModel(const AModelName: string);

    procedure ToggleSessions;
    procedure CreateNewSession;
    procedure RenameSession(const ASessionId, ANewName: string);
    procedure DeleteSession(const ASessionId: string);
    procedure SelectSession(const ASessionId: string);

    procedure ExportChat;
    procedure OpenSettings;

    procedure HandlePromptInputKeyDown(var Key: Word; const Shift: TShiftState);
    procedure HandleTemplateSelected(const ATemplateName: string);
    procedure HandleGlobalPromptRequest(const APrompt: string; const AOpenChat: Boolean);

    procedure GenerateDTO(const AInput, AInputType, AOutputType: string);

    procedure HandleGenerateDTOCancel;
    procedure HandleGenerateDTOError(const AError: string);
    procedure HandleGenerateDTODone(const APromptText, AActiveProvider: string);


    // Deprecated WebViewBridge methods

    {$IFDEF TESTS}
    function TestPreProcessPrompt(const APromptText: string): string;
    {$ENDIF}

    property SessionManager: TRadIASessionManager read FSessionManager;
    property WebViewReady: Boolean read FWebViewReady write FWebViewReady;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, RadIA.Core.Config, RadIA.Core.Logger,
  RadIA.Core.ProviderRegistry, RadIA.Core.ConversationExporter,
  RadIA.Core.DTO.Generator, RadIA.Core.ProjectGenerator,
  System.SyncObjs, RadIA.Core.Container, RadIA.Core.ChatMessage, RadIA.Core.Service,
  RadIA.Core.AgentPricing, RadIA.Core.AgentProvider,
  RadIA.Core.CliManager, RadIA.Core.CliMcpSettings,
  RadIA.Core.Mediator, RadIA.OTA.Helper;

{ Helper Functions }

function IndexOfString(const AArray: TArray<string>; const AValue: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(AArray) to High(AArray) do
  begin
    if SameText(AArray[I], AValue) then
      Exit(I);
  end;
end;

{ TRadIAChatPresenter }

constructor TRadIAChatPresenter.Create(
  const AView: IRadIAChatView;
  const AConfig: IRadIAConfig;
  const AService: IRadIAService;
  const ADataDir: string
);
begin
  Create(
    AView,
    AConfig,
    AService,
    ADataDir,
    nil,
    nil
  );
end;

constructor TRadIAChatPresenter.Create(
  const AView: IRadIAChatView;
  const AConfig: IRadIAConfig;
  const AService: IRadIAService;
  const ADataDir: string;
  const AToolRegistry: IRadIAToolRegistry;
  const AToolExecutor: IRadIAToolExecutor
);
begin
  inherited Create;
  FView := AView;
  FHistory := [];
  FRequestInProgress := False;
  FCancelledByUser := False;
  FLoadingConfig := False;
  FWebViewReady := False;
  FPendingWebMessages := TList<string>.Create;
  FLifecycleGuard := TLifecycleGuard.Create;
  FActiveModels := [];
  FPendingPrompt := '';
  FLoginPopupOpen := False;
  FAgentModeEnabled := True;
  FAgentExecutorSettings := TRadIAAgentExecutorSettingsStore.Create;

  // WebViewBridge events removed

  if Assigned(AConfig) then
    FConfig := AConfig
  else if not TRadIAContainer.TryResolve<IRadIAConfig>(FConfig) then
    FConfig := TRadIAConfig.GetInstance;

  if Assigned(AService) then
  begin
    FAIService := AService;
    FOwnsService := False;
  end
  else if TRadIAContainer.TryResolve<IRadIAService>(FAIService) then
  begin
    FOwnsService := False;
  end
  else
  begin
    FAIService := TRadIAService.Create(FConfig);
    FOwnsService := True;
  end;

  if not TRadIAContainer.TryResolve<IRadIADTOBuilder>(FDTOBuilder) then
    FDTOBuilder := TRadIADTOBuilder.Create;
  if not TRadIAContainer.TryResolve<IRadIAProjectGenerator>(FProjectGenerator) then
    FProjectGenerator := TRadIAProjectGenerator.Create;

  if Assigned(AToolRegistry) then
    FToolRegistry := AToolRegistry
  else
    TRadIAContainer.TryResolve<IRadIAToolRegistry>(FToolRegistry);

  if Assigned(AToolExecutor) then
    FToolExecutor := AToolExecutor
  else
    TRadIAContainer.TryResolve<IRadIAToolExecutor>(FToolExecutor);
  TRadIAContainer.TryResolve<IRadIAToolPolicyExecutor>(
    FToolPolicyExecutor
  );
  TRadIAContainer.TryResolve<IRadIAWorkspaceFacade>(FWorkspace);

  if ADataDir.IsEmpty then
    FDataDir := TPath.Combine(TPath.GetHomePath, 'RadIA')
  else
    FDataDir := ADataDir;

  FPromptHistoryManager := TPromptHistoryManager.Create;
  FAccumulatedUsage := TTokenUsage.Empty;

  FTemplateManager := TPromptTemplateManager.Create(FDataDir);
  FTemplateManager.Load;

  FSessionManager := TRadIASessionManager.Create(TPath.Combine(FDataDir, 'sessions'));
  FSessionManager.ActiveSessionId := FConfig.ActiveSessionId;
end;

destructor TRadIAChatPresenter.Destroy;
begin
  if Assigned(FCliProcessSession) then
  begin
    FCliProcessSession.Cancel;
    FCliProcessSession := nil;
  end;
  if Assigned(FAgentController) then
  begin
    FAgentController.Cancel;
    FAgentController := nil;
  end;

  if Assigned(FModelsProvider) then
  begin
    try
      FModelsProvider.CancelCurrentRequest;
    except
      on E: Exception do
        TLogger.Log('Destroy: Error cancelling model provider: ' + E.Message, 'UI');
    end;
    FModelsProvider := nil;
  end;

  if Assigned(FLifecycleGuard) then
    (FLifecycleGuard as IRadIALifecycleGuard).Invalidate;

  if Assigned(FAIService) then
    FAIService.CancelCurrentRequest;

  FPromptHistoryManager.Free;
  FTemplateManager.Free;
  FSessionManager.Free;
  FPendingWebMessages.Free;
  FAgentExecutorSettings.Free;

  if FOwnsService and Assigned(FAIService) then
    FAIService := nil;

  inherited Destroy;
end;

procedure TRadIAChatPresenter.Initialize(const AWebFilesDir: string);
var
  LTemplate: TPromptTemplate;
  LTemplateNames: TArray<string>;
begin
  FWebFilesDir := AWebFilesDir;

  LTemplateNames := [];
  for LTemplate in FTemplateManager.GetTemplates do
  begin
    LTemplateNames := LTemplateNames + [LTemplate.Name];
  end;
  FView.UpdateTemplates(LTemplateNames);

  LoadConfig;
  UpdateSessionsList;
  LoadPromptHistory;
end;

function TRadIAChatPresenter.IsProviderConfigured(const AProviderId: string): Boolean;
var
  LMeta: TProviderMetadata;
begin
  if SameText(AProviderId, 'Ollama') then
    Result := not FConfig.GetOllamaBaseUrl.Trim.IsEmpty
  else if SameText(AProviderId, 'LMStudio') then
    Result := not FConfig.GetProviderBaseUrl('LMStudio').Trim.IsEmpty
  else
  begin
    if TProviderRegistry.GetProvider(AProviderId, LMeta) and LMeta.IsDynamic then
      Exit(True);

    if FConfig.IsWebLoginProvider(AProviderId) then
      Exit(True);

    if SameText(FConfig.GetProviderAuthType(AProviderId), 'oauth') then
      Exit(not FConfig.GetOAuthAccessToken(AProviderId).Trim.IsEmpty or
           not FConfig.GetOAuthRefreshToken(AProviderId).Trim.IsEmpty);

    Result := not FConfig.GetApiKey(AProviderId).Trim.IsEmpty;
  end;
end;



function TRadIAChatPresenter.CanChangeSession: Boolean;
begin
  Result := not FRequestInProgress;
  if not Result then
    FView.ShowMessageDialog('Wait for the current response to finish, or cancel it before switching chats.');
end;

procedure TRadIAChatPresenter.LoadConfig;
var
  LProviders: TArray<TProviderMetadata>;
  LActiveProvider: string;
  LConfiguredProviders: TArray<string>;
  I: Integer;
begin
  FLoadingConfig := True;
  try
    LConfiguredProviders := [];
    LProviders := TProviderRegistry.GetProviders;
    for I := 0 to Length(LProviders) - 1 do
    begin
      if IsProviderConfigured(LProviders[I].Id) then
        LConfiguredProviders := LConfiguredProviders + [LProviders[I].Id];
    end;

    if Length(LConfiguredProviders) = 0 then
    begin
      for I := 0 to Length(LProviders) - 1 do
        LConfiguredProviders := LConfiguredProviders + [LProviders[I].Id];
    end;

    LActiveProvider := FConfig.GetActiveProvider;
    FView.UpdateProviders(LConfiguredProviders, LActiveProvider);

    UpdateModelsCombo;
  finally
    FLoadingConfig := False;
  end;
end;


procedure TRadIAChatPresenter.HandleUpdateModelsComboResult(AModels: TArray<string>; AProvider: IRadIAProvider);
var
  LActiveModel: string;
  LProvId: string;
begin
  if FModelsProvider = AProvider then
    FModelsProvider := nil;

  if Assigned(AProvider) then
  begin
    Self.FActiveModels := AModels;
    LProvId := AProvider.GetProviderId;
    LActiveModel := Self.FConfig.GetActiveModel(LProvId);

    if (Length(AModels) > 0) and (LActiveModel.IsEmpty or (IndexOfString(AModels, LActiveModel) = -1)) then
    begin
      LActiveModel := AModels[0];
      Self.FConfig.SetActiveModel(LProvId, LActiveModel);
      Self.FConfig.Save;
    end;

    Self.FView.UpdateModels(AModels, LActiveModel, True);
    Self.SendModelsUpdateToWeb(AModels, LActiveModel);
  end;
end;

function TRadIAChatPresenter.BuildProvidersJsonArray: TJSONArray;
var
  LProviders: TArray<TProviderMetadata>;
  LProvObj: TJSONObject;
  I: Integer;
begin
  Result := TJSONArray.Create;
  LProviders := TProviderRegistry.GetProviders;
  for I := 0 to Length(LProviders) - 1 do
  begin
    if IsProviderConfigured(LProviders[I].Id) then
    begin
      LProvObj := TJSONObject.Create;
      LProvObj.AddPair('name', LProviders[I].DisplayName);
      LProvObj.AddPair('value', LProviders[I].Id);
      Result.AddElement(LProvObj);
    end;
  end;
end;

function TRadIAChatPresenter.BuildModelsJsonArray(
  const AActiveProvider: string;
   LIsWebLogin: Boolean;
   out AActiveModel: string): TJSONArray;

var
  LMeta: TProviderMetadata;
  LDefaultModels: TArray<string>;
  LModel: string;
begin
  Result := TJSONArray.Create;
  AActiveModel := FConfig.GetActiveModel(AActiveProvider);

  if LIsWebLogin then
  begin
    if TProviderRegistry.GetProvider('WebViewBridge', LMeta) then
      LDefaultModels := LMeta.DefaultModels
    else
      LDefaultModels := ['Web-Browser'];
    AActiveModel := 'Web-Browser';
  end
  else
  begin
    if Length(FActiveModels) > 0 then
      LDefaultModels := FActiveModels
    else if TProviderRegistry.GetProvider(AActiveProvider, LMeta) then
      LDefaultModels := LMeta.DefaultModels
    else
      LDefaultModels := [];
  end;

  for LModel in LDefaultModels do
  begin
    Result.Add(LModel);
  end;
end;

function TRadIAChatPresenter.BuildSlashCommandsJsonArray: TJSONArray;
var
  LTemplate: TPromptTemplate;
  LSlashObj: TJSONObject;
begin
  Result := TJSONArray.Create;
  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/agent');
  LSlashObj.AddPair(
    'description',
    'Toggles agent mode or sets it with on/off.'
  );
  LSlashObj.AddPair('name', 'Agent Mode');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/agent run');
  LSlashObj.AddPair(
    'description',
    'Starts an observable agent run for an explicit objective.'
  );
  LSlashObj.AddPair('name', 'Run Agent');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/agent plan');
  LSlashObj.AddPair(
    'description',
    'Replaces the pending plan with a validated JSON step array.'
  );
  LSlashObj.AddPair('name', 'Edit Agent Plan');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/agent replay');
  LSlashObj.AddPair(
    'description',
    'Replays one audited tool step while the agent run is paused.'
  );
  LSlashObj.AddPair('name', 'Replay Agent Step');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/agent pause');
  LSlashObj.AddPair('description', 'Pauses the active agent run.');
  LSlashObj.AddPair('name', 'Pause Agent');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/agent resume');
  LSlashObj.AddPair('description', 'Resumes the paused agent checkpoint.');
  LSlashObj.AddPair('name', 'Resume Agent');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/agent cancel');
  LSlashObj.AddPair('description', 'Cancels the active agent run.');
  LSlashObj.AddPair('name', 'Cancel Agent');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/agent history');
  LSlashObj.AddPair(
    'description',
    'Searches persisted agent runs without exposing tool payloads.'
  );
  LSlashObj.AddPair('name', 'Agent Run History');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/terminal');
  LSlashObj.AddPair('description', 'Opens the integrated terminal.');
  LSlashObj.AddPair('name', 'Open Terminal');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/tools');
  LSlashObj.AddPair('description', 'Lists available read-only IDE tools.');
  LSlashObj.AddPair('name', 'IDE Tools');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/revoke-tools');
  LSlashObj.AddPair(
    'description',
    'Revokes all IDE tool permissions granted for this session.'
  );
  LSlashObj.AddPair('name', 'Revoke Tool Permissions');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/tool');
  LSlashObj.AddPair(
    'description',
    'Runs a read-only IDE tool with optional JSON arguments.'
  );
  LSlashObj.AddPair('name', 'Run IDE Tool');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  for LTemplate in FTemplateManager.GetTemplates do
  begin
    if not LTemplate.SlashCommand.IsEmpty then
    begin
      LSlashObj := TJSONObject.Create;
      LSlashObj.AddPair('command', LTemplate.SlashCommand);
      LSlashObj.AddPair('description', LTemplate.Description);
      LSlashObj.AddPair('name', LTemplate.Name);
      LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(LTemplate.IsProjectGenerator));
      Result.AddElement(LSlashObj);
    end;
  end;
end;

function TRadIAChatPresenter.BuildToolsJsonArray: TJSONArray;
var
  LDescriptor: TRadIAToolDescriptor;
  LJson: TJSONObject;
begin
  Result := TJSONArray.Create;
  if not Assigned(FToolRegistry) then
    Exit;

  for LDescriptor in FToolRegistry.GetDescriptors do
  begin
    LJson := TJSONObject.Create;
    LJson.AddPair('name', LDescriptor.Name);
    LJson.AddPair('version', LDescriptor.Version);
    LJson.AddPair('description', LDescriptor.Description);
    LJson.AddPair('inputSchema', LDescriptor.InputSchema);
    LJson.AddPair('risk', ToolRiskName(LDescriptor.Risk));
    Result.AddElement(LJson);
  end;
end;

function TRadIAChatPresenter.ToolRiskName(
  const ARisk: TRadIAToolRisk
): string;
begin
  case ARisk of
    trReadOnly: Result := 'readOnly';
    trReversibleWrite: Result := 'reversibleWrite';
    trStructuralWrite: Result := 'structuralWrite';
    trExecution: Result := 'execution';
    trDestructive: Result := 'destructive';
  else
    Result := 'sensitive';
  end;
end;
procedure TRadIAChatPresenter.UpdateModelsCombo;
var
  LProvider: IRadIAProvider;
  LGuard: IRadIALifecycleGuard;
begin
  FView.UpdateModels(['Loading...'], 'Loading...', False);
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;

  try
    if Assigned(FModelsProvider) then
    begin
      try
        FModelsProvider.CancelCurrentRequest;
      except
        on E: Exception do
          TLogger.Log('UpdateModelsCombo: Error cancelling previous model provider: ' + E.Message, 'UI');
      end;
      FModelsProvider := nil;
    end;

    FModelsProvider := FAIService.CreateActiveProvider;
    LProvider := FModelsProvider;
    LProvider.FetchAvailableModelsAsync(
      procedure(AModels: TArray<string>; AError: string)
      var
        LProc: TThreadProcedure;
      begin
        LProc := procedure
                 begin
                   if not LGuard.IsAlive then
                     Exit;
                   Self.HandleUpdateModelsComboResult(AModels, LProvider);
                 end;
        TThread.Queue(nil, LProc);
      end);
  except
    on E: Exception do
    begin
      FView.UpdateModels(['Error loading models'], 'Error loading models', True);
    end;
  end;
end;

procedure TRadIAChatPresenter.ChangeProvider(const AProviderName: string);
begin
  if FLoadingConfig then
    Exit;

  FActiveModels := [];
  FConfig.SetActiveProvider(AProviderName);
  FConfig.Save;
  UpdateModelsCombo;
end;

procedure TRadIAChatPresenter.ChangeModel(const AModelName: string);
var
  LSelectedProvider: string;
begin
  if FLoadingConfig then
    Exit;

  LSelectedProvider := FConfig.GetActiveProvider;
  FConfig.SetActiveModel(LSelectedProvider, AModelName);
  FConfig.Save;
end;

procedure TRadIAChatPresenter.ClearChat;
begin
  if not CanChangeSession then
    Exit;

  FHistory := [];
  FAccumulatedUsage := TTokenUsage.Empty;
  PostToWebView('clear_chat', '', '');
  PostToWebView('update_tokens', '', '');

  if Assigned(FAIService) then
    FAIService.ClearCache;

  if not FSessionManager.ActiveSessionId.IsEmpty then
  begin
    try
      FSessionManager.SaveSessionHistory(FSessionManager.ActiveSessionId, []);
    except
      on E: Exception do
        TLogger.Log('ClearChat: Error saving cleared session: ' + E.Message, 'UI');
    end;
  end;
end;

procedure TRadIAChatPresenter.ToggleSessions;
begin
  if not CanChangeSession then
    Exit;

  FView.ToggleSessionsPanel;
end;

procedure TRadIAChatPresenter.CreateNewSession;
var
  LSession: TSessionInfo;
begin
  if not CanChangeSession then
    Exit;

  SaveChatHistory;
  LSession := FSessionManager.CreateSession('Initial Chat');
  FSessionManager.ActiveSessionId := LSession.Id;
  FConfig.ActiveSessionId := LSession.Id;
  FConfig.Save;

  FHistory := [];
  FAccumulatedUsage := TTokenUsage.Empty;
  PostToWebView('clear_chat', '', '');
  PostToWebView('update_tokens', '', '');

  UpdateSessionsList;
  SendSessionsUpdateToWeb;
end;

procedure TRadIAChatPresenter.RenameSession(const ASessionId, ANewName: string);
begin
  if not CanChangeSession then
    Exit;

  if not ANewName.Trim.IsEmpty then
  begin
    FSessionManager.RenameSession(ASessionId, ANewName);
    UpdateSessionsList;
    SendSessionsUpdateToWeb;
  end;
end;

procedure TRadIAChatPresenter.DeleteSession(const ASessionId: string);
begin
  if not CanChangeSession then
    Exit;

  FSessionManager.DeleteSession(ASessionId);

  if SameText(FSessionManager.ActiveSessionId, ASessionId) then
  begin
    FSessionManager.ActiveSessionId := '';
    FConfig.ActiveSessionId := '';
    FConfig.Save;
  end;

  UpdateSessionsList;

  FHistory := [];
  FAccumulatedUsage := TTokenUsage.Empty;
  PostToWebView('clear_chat', '', '');
  PostToWebView('update_tokens', '', '');

  LoadChatHistory;
  SendSessionsUpdateToWeb;
end;

procedure TRadIAChatPresenter.SelectSession(const ASessionId: string);
begin
  if not CanChangeSession then
    Exit;

  if not FSessionManager.ActiveSessionId.IsEmpty and not SameText(FSessionManager.ActiveSessionId, ASessionId) then
    SaveChatHistory;

  FSessionManager.ActiveSessionId := ASessionId;
  FSessionManager.UpdateSessionActivity(ASessionId);
  FConfig.ActiveSessionId := ASessionId;
  FConfig.Save;

  UpdateSessionsList;

  FHistory := [];
  FAccumulatedUsage := TTokenUsage.Empty;
  PostToWebView('clear_chat', '', '');
  PostToWebView('update_tokens', '', '');

  LoadChatHistory;
  SendSessionsUpdateToWeb;
end;

procedure TRadIAChatPresenter.ExportChat;
var
  LContent: string;
  LProviderName: string;
  LModelName: string;
  LFileName: string;
begin
  if Length(FHistory) = 0 then
  begin
    FView.ShowMessageDialog('There is no conversation history to export.');
    Exit;
  end;

  if FView.SaveDialogExecute(LFileName) then
  begin
    LProviderName := FConfig.GetActiveProvider;
    LModelName := FConfig.GetActiveModel(LProviderName);

    if SameText(ExtractFileExt(LFileName), '.html') then
      LContent := TConversationExporter.ExportToHTML(FHistory, LProviderName, LModelName)
    else
      LContent := TConversationExporter.ExportToMarkdown(FHistory, LProviderName, LModelName);

    try
      TFile.WriteAllText(LFileName, LContent, TEncoding.UTF8);
      FView.ShowMessageDialog('Conversation exported successfully!');
    except
      on E: Exception do
        FView.ShowMessageDialog('Error exporting conversation: ' + E.Message);
    end;
  end;
end;

procedure TRadIAChatPresenter.OpenSettings;
begin
  FView.OpenSettingsDialog;
  FConfig.Load;
  LoadConfig;

  FTemplateManager.Load;
  Initialize(FWebFilesDir);

  if FWebViewReady then
    SendInitialConfigToWeb;
end;

procedure TRadIAChatPresenter.HandlePromptInputKeyDown(var Key: Word; const Shift: TShiftState);
var
  LPrompt: string;
begin
  if (Key = 13) and (Shift = [ssCtrl]) then
  begin
    SendPrompt;
    Key := 0;
    Exit;
  end;

  if Shift <> [] then
    Exit;

  if Key = 38 then
  begin
    LPrompt := FPromptHistoryManager.NavigateUp;
    FView.SetPromptInput(LPrompt);
    Key := 0;
  end
  else if Key = 40 then
  begin
    LPrompt := FPromptHistoryManager.NavigateDown;
    FView.SetPromptInput(LPrompt);
    Key := 0;
  end;
end;

procedure TRadIAChatPresenter.HandleTemplateSelected(const ATemplateName: string);
var
  LActiveCode: string;
  LResolved: string;
begin
  if not Assigned(FTemplateManager) then
    Exit;

  if not FView.GetActiveEditorText(LActiveCode, True) or LActiveCode.Trim.IsEmpty then
    FView.GetActiveEditorText(LActiveCode, False);

  LResolved := FTemplateManager.ResolveTemplate(ATemplateName, LActiveCode);

  FView.SetPromptInput(LResolved);
  FView.FocusPromptInput;
end;

procedure TRadIAChatPresenter.HandleGlobalPromptRequest(const APrompt: string; const AOpenChat: Boolean);
var
  LProcessed: string;
begin
  LProcessed := PreProcessPrompt(APrompt);
  PostToWebView('add_message', 'user', APrompt);
  SendPromptToAI(LProcessed);
end;

procedure TRadIAChatPresenter.SendPrompt;
var
  LText: string;
  LProcessed: string;
begin
  if FRequestInProgress then
  begin
    FCancelledByUser := True;
    TLogger.Log('SendPrompt: User requested cancellation of active request.', 'UI');
    FView.SetRequestState(False);
    FAIService.CancelCurrentRequest;
    Exit;
  end;

  LText := Trim(FView.GetPromptInput);
  if LText.IsEmpty then
    Exit;

  FPromptHistoryManager.Add(FView.GetPromptInput);
  SavePromptHistory;

  FView.SetPromptInput('');
  if TryHandleToolPrompt(LText) then
    Exit;

  LProcessed := PreProcessPrompt(LText);
  PostToWebView('add_message', 'user', LText);
  SendPromptToAI(LProcessed);
end;

procedure TRadIAChatPresenter.SendPromptText(const APromptText: string);
var
  LProcessed: string;
begin
  if TryHandleToolPrompt(APromptText) then
    Exit;

  LProcessed := PreProcessPrompt(APromptText);
  PostToWebView('add_message', 'user', APromptText);
  SendPromptToAI(LProcessed);
end;


procedure TRadIAChatPresenter.HandleStreamSessionChange(
  AIsDone: Boolean;

  const ASessionId, AFullResponse, AActiveProvider, AActiveModel: string);

begin
  TLogger.Log(Format('SendPromptToAI: Session changed from %s to %s. Discarding UI callback.',
      [ASessionId, Self.FSessionManager.ActiveSessionId]), 'UI');
  if AIsDone and (not AFullResponse.IsEmpty) and (not GIsShuttingDown) then
  begin
    TInterlocked.Increment(GActiveThreadCount);
    TThread.CreateAnonymousThread(
      procedure
      var
        LOrigHistory: TArray<IRadIAChatMessage>;
        LAssistantMsg: IRadIAChatMessage;
      begin
        try
          try
            LOrigHistory := Self.FSessionManager.LoadSessionHistory(ASessionId);
            LAssistantMsg := TRadIAChatMessage.CreateMessage(mrAssistant, AFullResponse,
                AActiveProvider, AActiveModel);
            LOrigHistory := LOrigHistory + [LAssistantMsg];
            Self.FSessionManager.SaveSessionHistory(ASessionId, LOrigHistory);
          except
            on E: Exception do
              TLogger.Log('SendPromptToAI background thread: Error saving history: ' + E.Message, 'UI');
          end;
        finally
          TInterlocked.Decrement(GActiveThreadCount);
        end;
      end).Start;
  end;
end;

procedure TRadIAChatPresenter.HandleStreamCancel(
  const AActiveProvider, AActiveModel: string;
   var AFullResponse: string);

var
  LAssistantMsg: IRadIAChatMessage;
begin
  Self.FRequestInProgress := False;
  Self.FView.SetRequestState(False);
  TLogger.Log('SendPromptToAI: Handling user cancellation in UI callback.', 'UI');

  if not AFullResponse.IsEmpty then
  begin
    LAssistantMsg := TRadIAChatMessage.CreateMessage(mrAssistant, AFullResponse + ' [Cancelled ' +
        'by user]', AActiveProvider, AActiveModel);
    Self.FHistory := Self.FHistory + [LAssistantMsg];
    Self.SaveChatHistory;
  end;

  Self.PostToWebView('add_message', 'assistant', '*Requisicao cancelada pelo usuario.*',
      False, AActiveProvider, AActiveModel);
  Self.PostToWebView('append_message', 'assistant', '', True, AActiveProvider, AActiveModel);
end;

procedure TRadIAChatPresenter.HandleStreamDone(const APromptText, AActiveProvider, AActiveModel, AFullResponse: string);
var
  LAssistantMsg: IRadIAChatMessage;
  LUsage: TTokenUsage;
  LStats: string;
begin
  Self.FRequestInProgress := False;
  Self.FView.SetRequestState(False);
  TLogger.Log(Format('SendPromptToAI completed. TotalResponseLength=%d', [Length(AFullResponse)]), 'UI');

  if AFullResponse.IsEmpty then
  begin
    TLogger.Log('SendPromptToAI: Empty response from AI provider', 'UI');
    Self.PostToWebView('add_message', 'assistant', '**Error:** The provider returned empty ' +
        'response.', False, AActiveProvider, AActiveModel);
    Self.PostToWebView('append_message', 'assistant', '', True, AActiveProvider, AActiveModel);
    Exit;
  end;

  LAssistantMsg := TRadIAChatMessage.CreateMessage(mrAssistant, AFullResponse, AActiveProvider,
      AActiveModel);
  Self.FHistory := Self.FHistory + [LAssistantMsg];
  Self.SaveChatHistory;

  LUsage.PromptTokens := Length(APromptText) div 4;
  LUsage.CompletionTokens := Length(AFullResponse) div 4;
  LUsage.TotalTokens := LUsage.PromptTokens + LUsage.CompletionTokens;

  if LUsage.TotalTokens > 0 then
  begin
    Self.FAccumulatedUsage.PromptTokens := Self.FAccumulatedUsage.PromptTokens + LUsage.PromptTokens;
    Self.FAccumulatedUsage.CompletionTokens :=
      Self.FAccumulatedUsage.CompletionTokens + LUsage.CompletionTokens;

    Self.FAccumulatedUsage.TotalTokens := Self.FAccumulatedUsage.TotalTokens + LUsage.TotalTokens;

    if not Self.FConfig.IsWebLoginProvider(AActiveProvider) then
      Self.FConfig.AddToQuotaUsage(LUsage);

    LStats := Self.FAccumulatedUsage.FormatStats;
    if Self.FConfig.QuotaEnabled and (not Self.FConfig.IsWebLoginProvider(AActiveProvider)) then
    begin
      LStats := LStats + Format(' ' + #$00B7 + ' Quota %d%%',
        [Round((Self.FConfig.QuotaUsed / Self.FConfig.QuotaLimit) * 100)]);
    end;

    Self.PostToWebView('update_tokens', '', LStats);
  end;

  Self.PostToWebView('append_message', 'assistant', '', True, AActiveProvider, AActiveModel);
end;

procedure TRadIAChatPresenter.HandleStreamError(
  const AError, AActiveProvider, AActiveModel: string;
   var AFullResponse: string);
var
  LAssistantMsg: IRadIAChatMessage;
begin
  Self.FRequestInProgress := False;
  Self.FView.SetRequestState(False);
  TLogger.Log(Format('SendPromptToAI error callback: %s', [AError]), 'UI');

  if not AFullResponse.IsEmpty then
  begin
    AFullResponse := AFullResponse + #13#10#13#10 + '**Error:** ' + AError;
    Self.PostToWebView('append_message', 'assistant', #13#10#13#10 + '**Error:** ' + AError,
        True, AActiveProvider, AActiveModel);

    LAssistantMsg := TRadIAChatMessage.CreateMessage(mrAssistant, AFullResponse, AActiveProvider,
        AActiveModel);
    Self.FHistory := Self.FHistory + [LAssistantMsg];
    Self.SaveChatHistory;
  end
  else
  begin
    Self.PostToWebView('add_message', 'assistant', '**Error:** ' + AError, False, AActiveProvider,
        AActiveModel);
    Self.PostToWebView('append_message', 'assistant', '', True, AActiveProvider, AActiveModel);
  end;

  // Web error handling removed
end;

procedure TRadIAChatPresenter.ProcessStreamChunk(const ACtx: TStreamChunkCtx;
  var ADoneHandled: Boolean; var AFullResponse: string);
var
  LReplaceTarget: string;
  LCode: string;
begin
  if ADoneHandled then
    Exit;

  if not (FLifecycleGuard as IRadIALifecycleGuard).IsAlive then
    Exit;

  if not SameText(Self.FSessionManager.ActiveSessionId, ACtx.SessionId) then
  begin
    Self.HandleStreamSessionChange(ACtx.IsDone, ACtx.SessionId, AFullResponse, ACtx.ActiveProvider, ACtx.ActiveModel);
    Exit;
  end;

  if Self.FCancelledByUser then
  begin
    ADoneHandled := True;
    Self.HandleStreamCancel(ACtx.ActiveProvider, ACtx.ActiveModel, AFullResponse);
    Exit;
  end;

  if not ACtx.Error.IsEmpty then
  begin
    ADoneHandled := True;
    Self.HandleStreamError(ACtx.Error, ACtx.ActiveProvider, ACtx.ActiveModel, AFullResponse);
    Exit;
  end;

  if not ACtx.Chunk.IsEmpty then
  begin
    AFullResponse := AFullResponse + ACtx.Chunk;
    if not Self.FConfig.IsWebLoginProvider(ACtx.ActiveProvider) then
      Self.PostToWebView('append_message', 'assistant', ACtx.Chunk, False, ACtx.ActiveProvider, ACtx.ActiveModel);
  end;

  if ACtx.IsDone then
  begin
    ADoneHandled := True;
    Self.HandleStreamDone(FPendingPrompt, ACtx.ActiveProvider, ACtx.ActiveModel, AFullResponse);

    if not TRadIAMediator.Instance.AutoReplaceTarget.IsEmpty then
    begin
      LReplaceTarget := TRadIAMediator.Instance.AutoReplaceTarget;
      TRadIAMediator.Instance.AutoReplaceTarget := '';

      LCode := TRadIAOTAHelper.CleanCodeResponse(AFullResponse, '');
      if not LCode.IsEmpty then
      begin
        TLogger.Log('ProcessStreamChunk: Auto-replacing target method in editor.', 'UI');
        FView.ReplaceActiveEditorText(LCode, False, LReplaceTarget);
      end;
    end;
  end;
end;

function TRadIAChatPresenter.CheckQuotaAvailability: Boolean;
begin
  Result := True;
  if FConfig.QuotaEnabled and (not FConfig.IsWebLoginProvider(FConfig.GetActiveProvider)) then
  begin
    FConfig.Load;
    if FConfig.QuotaUsed >= FConfig.QuotaLimit then
    begin
      FView.ShowMessageDialog(Format('Could not send the request: monthly token quota exceeded (local ' +
          'limit of %s tokens reached).',
        [FormatFloat('#,##0', FConfig.QuotaLimit, TFormatSettings.Invariant)]));
      Result := False;
    end;
  end;
end;

function TRadIAChatPresenter.DetermineRequestProfile(const APromptText: string): TAIRequestProfile;
begin
  Result := rpGeneralChat;
  if APromptText.StartsWith('/refactor', True) or APromptText.StartsWith('/optimize', True) then
    Result := rpRefactorCode
  else if APromptText.StartsWith('/bugs', True) or APromptText.StartsWith('Perform a comprehensive static ' +
      'analysis', True) then
    Result := rpFindBugs
  else if APromptText.StartsWith('/test', True) then
    Result := rpGenerateTests
  else if APromptText.StartsWith('/explain', True) or APromptText.StartsWith('/doc',
      True) or APromptText.StartsWith('/fix',
      True) or APromptText.StartsWith('Analyze the following Delphi stack trace', True) then
    Result := rpExplainCode;
end;

procedure TRadIAChatPresenter.SendPromptToAI(const APromptText: string);
var
  LUserMsg: IRadIAChatMessage;
  LFullResponse: string;
  LProfile: TAIRequestProfile;
  LDoneHandled: Boolean;
  LActiveProvider: string;
  LActiveModel: string;
  LSessionId: string;
  LGuard: IRadIALifecycleGuard;
  HandleStreamCallback: TStreamChunkCallback;
begin
  LActiveProvider := FConfig.GetActiveProvider;
  if SameText(LActiveProvider, 'Gemini') and SameText(FConfig.GetProviderAuthType('Gemini'), 'oauth') then
  begin
    FView.ShowMessageDialog(
      'Google Gemini OAuth authentication is currently pending approval.' + sLineBreak +
      'Please use an API Key for now.'
    );
    Exit;
  end;

  if not CheckQuotaAvailability then
    Exit;

  FPendingPrompt := APromptText;
  LDoneHandled := False;
  FRequestInProgress := True;
  FCancelledByUser := False;
  FView.SetRequestState(True);

  LActiveProvider := FConfig.GetActiveProvider;
  LActiveModel := FConfig.GetActiveModel(LActiveProvider);
  if FConfig.IsWebLoginProvider(LActiveProvider) then
    LActiveModel := 'Web Login';
  LSessionId := FSessionManager.ActiveSessionId;
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;

  TLogger.Log(Format('SendPromptToAI started. Provider=%s, Model=%s, PromptLength=%d, Session=%s',
    [LActiveProvider, LActiveModel, Length(APromptText), LSessionId]), 'UI');

  LProfile := DetermineRequestProfile(APromptText);

  LUserMsg := TRadIAChatMessage.CreateMessage(mrUser, APromptText, LActiveProvider, LActiveModel);
  FHistory := FHistory + [LUserMsg];
  SaveChatHistory;

  LFullResponse := '';

  PostToWebView('show_typing', '', '');

  HandleStreamCallback := procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
  begin
    TThread.Queue(nil,
      TThreadProcedure(
      procedure
        var LCtx: TStreamChunkCtx;
        begin
          if not LGuard.IsAlive then
            Exit;
          LCtx.Chunk := AChunk; LCtx.IsDone := AIsDone; LCtx.Error := AError;
          LCtx.SessionId := LSessionId; LCtx.ActiveProvider := LActiveProvider;
          LCtx.ActiveModel := LActiveModel;
          ProcessStreamChunk(LCtx, LDoneHandled, LFullResponse);
        end));
  end;

  try
    FAIService.SendPromptStream(APromptText, FHistory, HandleStreamCallback, LProfile);
  except
    on E: Exception do
    begin
      FRequestInProgress := False;
      FView.SetRequestState(False);
      PostToWebView('add_message', 'assistant', '**Error:** ' + E.Message, False, LActiveProvider, LActiveModel);
      PostToWebView('append_message', 'assistant', '', True, LActiveProvider, LActiveModel);
    end;
  end;
end;

procedure TRadIAChatPresenter.CancelRequest;
begin
  if FRequestInProgress then
  begin
    FCancelledByUser := True;
    TLogger.Log('CancelRequest: User requested cancellation.', 'UI');
    FView.SetRequestState(False);
    if Assigned(FCliProcessSession) and FCliProcessSession.IsRunning then
      FCliProcessSession.Cancel
    else if Assigned(FAgentController) and FAgentController.IsRunning then
      FAgentController.Cancel
    else
      FAIService.CancelCurrentRequest;
  end;
end;


procedure TRadIAChatPresenter.HandleGenerateDTOCancel;
begin
  Self.FRequestInProgress := False;
  Self.FView.SetRequestState(False);
  Self.PostToWebView('append_generator_code', '', ' [Cancelled by user]', True);
end;

procedure TRadIAChatPresenter.HandleGenerateDTOError(const AError: string);
begin
  Self.FRequestInProgress := False;
  Self.FView.SetRequestState(False);
  Self.PostToWebView('append_generator_code', '', #13#10 + '// Error: ' + AError, True);
end;

procedure TRadIAChatPresenter.HandleGenerateDTODone(const APromptText, AActiveProvider: string);
var
  LUsage: TTokenUsage;
  LStats: string;
begin
  Self.FRequestInProgress := False;
  Self.FView.SetRequestState(False);

  LUsage.PromptTokens := Length(APromptText) div 4;
  LUsage.CompletionTokens := 1000;
  LUsage.TotalTokens := LUsage.PromptTokens + LUsage.CompletionTokens;

  if LUsage.TotalTokens > 0 then
  begin
    if not Self.FConfig.IsWebLoginProvider(AActiveProvider) then
      Self.FConfig.AddToQuotaUsage(LUsage);
    LStats := Self.FAccumulatedUsage.FormatStats;
    if Self.FConfig.QuotaEnabled and (not Self.FConfig.IsWebLoginProvider(AActiveProvider)) then
      LStats := LStats + Format(' ' + #$00B7 + ' Quota %d%%',
        [Round((Self.FConfig.QuotaUsed / Self.FConfig.QuotaLimit) * 100)]);
    Self.PostToWebView('update_tokens', '', LStats);
  end;

  Self.PostToWebView('append_generator_code', '', '', True);
end;

procedure TRadIAChatPresenter.ProcessDTOGeneratorChunk(const AChunk, AError: string;
  const AIsDone: Boolean; var ADoneHandled: Boolean; const APromptText, AActiveProvider: string);
begin
  if ADoneHandled then
    Exit;

  if not (FLifecycleGuard as IRadIALifecycleGuard).IsAlive then
    Exit;

  if Self.FCancelledByUser then
  begin
    ADoneHandled := True;
    Self.HandleGenerateDTOCancel;
    Exit;
  end;

  if not AError.IsEmpty then
  begin
    ADoneHandled := True;
    Self.HandleGenerateDTOError(AError);
    Exit;
  end;

  if not AChunk.IsEmpty then
  begin
    Self.PostToWebView('append_generator_code', '', AChunk, False);
  end;

  if AIsDone then
  begin
    ADoneHandled := True;
    Self.HandleGenerateDTODone(APromptText, AActiveProvider);
  end;
end;

procedure TRadIAChatPresenter.GenerateDTO(const AInput, AInputType, AOutputType: string);
var
  LPromptText: string;
  LDoneHandled: Boolean;
  LActiveProvider: string;
  LActiveModel: string;
  LGuard: IRadIALifecycleGuard;
begin
  if not CheckQuotaAvailability then
    Exit;

  LDoneHandled := False;
  FRequestInProgress := True;
  FCancelledByUser := False;
  FView.SetRequestState(True);

  LActiveProvider := FConfig.GetActiveProvider;
  LActiveModel := FConfig.GetActiveModel(LActiveProvider);
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;

  TLogger.Log(Format('GenerateDTO started. Provider=%s, Model=%s, InputLength=%d, InputType=%s, OutputType=%s',
    [LActiveProvider, LActiveModel, Length(AInput), AInputType, AOutputType]), 'UI');

  LPromptText := FDTOBuilder.BuildPrompt(AInput, AInputType, AOutputType);

  try
    FAIService.SendPromptStream(LPromptText, [],
      procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
      begin
        TThread.Queue(nil,
          TThreadProcedure(
          procedure
          begin
            if not LGuard.IsAlive then
              Exit;
            ProcessDTOGeneratorChunk(AChunk, AError, AIsDone, LDoneHandled, LPromptText, LActiveProvider);
          end));
      end);
  except
    on E: Exception do
    begin
      FRequestInProgress := False;
      FView.SetRequestState(False);
      PostToWebView('append_generator_code', '', '// Error: ' + E.Message, True);
    end;
  end;
end;


procedure TRadIAChatPresenter.OnWebViewReady;
var
  LMsgStr: string;
begin
  FWebViewReady := True;
  FView.ApplyCurrentTheme;
  SendInitialConfigToWeb;

  for LMsgStr in FPendingWebMessages do
  begin
    FView.PostMessageToWeb(LMsgStr);
  end;
  FPendingWebMessages.Clear;

  if FRequestInProgress then
  begin
    FView.SetRequestState(True);
    PostToWebView('show_typing', '', '');
  end;
end;

procedure TRadIAChatPresenter.QueueOnUI(const AProcedure: TProc);
var
  LGuard: IRadIALifecycleGuard;
begin
  if not Assigned(AProcedure) then
    Exit;

  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  TThread.ForceQueue(nil,
    TThreadProcedure(
    procedure
    begin
      if LGuard.IsAlive then
        AProcedure;
    end));
end;

procedure TRadIAChatPresenter.HandleInsertCodeMessage(const ACode: string);
begin
  QueueOnUI(
    procedure
    begin
      FView.ReplaceActiveEditorText(ACode);
    end);
end;

procedure TRadIAChatPresenter.HandleReadyMessage;
begin
  QueueOnUI(
    procedure
    begin
      OnWebViewReady;
    end);
end;

procedure TRadIAChatPresenter.HandleNewChatMessage;
begin
  QueueOnUI(
    procedure
    begin
      CreateNewSession;
    end);
end;

procedure TRadIAChatPresenter.HandleLoadHistoryMessage;
begin
  QueueOnUI(
    procedure
    begin
      PostToWebView('clear_chat', '', '');
      LoadChatHistory;
      SendSessionsUpdateToWeb;
    end);
end;

procedure TRadIAChatPresenter.HandleToggleHistoryMessage;
begin
  QueueOnUI(
    procedure
    begin
      ToggleSessions;
    end);
end;

procedure TRadIAChatPresenter.HandleOpenSettingsMessage;
begin
  QueueOnUI(
    procedure
    begin
      OpenSettings;
    end);
end;

procedure TRadIAChatPresenter.HandleChangeProviderMessage(const AProvider: string);
begin
  QueueOnUI(
    procedure
    begin
      ChangeProvider(AProvider);
    end);
end;

procedure TRadIAChatPresenter.HandleChangeModelMessage(const AModel: string);
begin
  QueueOnUI(
    procedure
    begin
      ChangeModel(AModel);
    end);
end;

procedure TRadIAChatPresenter.HandleSelectSessionMessage(const ASessionId: string);
begin
  QueueOnUI(
    procedure
    begin
      SelectSession(ASessionId);
    end);
end;

procedure TRadIAChatPresenter.HandleRenameSessionMessage(const ASessionId, AName: string);
begin
  QueueOnUI(
    procedure
    begin
      RenameSession(ASessionId, AName);
    end);
end;

procedure TRadIAChatPresenter.HandleDeleteSessionMessage(const ASessionId: string);
begin
  QueueOnUI(
    procedure
    begin
      DeleteSession(ASessionId);
    end);
end;

procedure TRadIAChatPresenter.HandleErrorMessage(const AText: string);
begin
  if True then ; // Error handling
end;

procedure TRadIAChatPresenter.HandleUpdateStreamMessage(const AText: string; const AIsDone: Boolean);
begin
  QueueOnUI(
    procedure
    var
      LActiveProvider: string;
      LActiveModel: string;
    begin
      LActiveProvider := FConfig.GetActiveProvider;
      LActiveModel := FConfig.GetActiveModel(LActiveProvider);
      if FConfig.IsWebLoginProvider(LActiveProvider) then
        LActiveModel := 'Web Login';

      PostToWebView('update_message', 'assistant', AText, AIsDone, LActiveProvider, LActiveModel);

    end);
end;

procedure TRadIAChatPresenter.HandleSendPromptMessage(const AText: string);
begin
  QueueOnUI(
    procedure
    begin
      SendPromptText(AText);
    end);
end;

procedure TRadIAChatPresenter.HandleExecuteToolMessage(
  const AName: string;
  const AArgumentsJson: string
);
begin
  QueueOnUI(
    procedure
    begin
      ExecuteRegisteredTool(AName, AArgumentsJson);
    end
  );
end;

procedure TRadIAChatPresenter.HandleGenerateDTOMessage(const AInput, AInputType, AOutputType: string);
begin
  QueueOnUI(
    procedure
    begin
      GenerateDTO(AInput, AInputType, AOutputType);
    end);
end;

procedure TRadIAChatPresenter.HandleCreateProjectMessage(const AFilesJson: string);
begin
  QueueOnUI(
    procedure
    var
      LErrorMsg: string;
    begin
      if not AFilesJson.IsEmpty then
      begin
        if not FProjectGenerator.GenerateFromJSON(AFilesJson, LErrorMsg) then
        begin
          if not LErrorMsg.IsEmpty then
            FView.ShowMessageDialog(LErrorMsg);
        end;
      end
      else
      begin
        FView.ShowMessageDialog('No files data received.');
      end;
    end);
end;

procedure TRadIAChatPresenter.HandleCancelRequestMessage;
begin
  QueueOnUI(
    procedure
    begin
      CancelRequest;
    end);
end;

procedure TRadIAChatPresenter.HandleClearChatMessage;
begin
  QueueOnUI(
    procedure
    begin
      ClearChat;
    end);
end;

procedure TRadIAChatPresenter.HandleStreamChunkMessage(const AText: string; const AIsDone: Boolean;
    const AError: string);
begin
  if True then ; // WebViewBridge streaming deprecated
end;

procedure TRadIAChatPresenter.DispatchSystemMessage(const AAction: string;
  const AJson: TJSONObject; var AHandled: Boolean);
var
  LFiles: TJSONArray;
begin
  AHandled := True;
  if SameText(AAction, 'insert_code') or SameText(AAction, 'apply_code') then
    HandleInsertCodeMessage(AJson.GetValue<string>('code', ''))
  else if AAction = 'log' then
    TLogger.Log('JS Console: ' + AJson.GetValue<string>('text', ''), 'WebView')
  else if AAction = 'ready' then
    HandleReadyMessage
  else if AAction = 'open_settings' then
    HandleOpenSettingsMessage
  else if AAction = 'open_terminal' then
    FView.OpenTerminal
  else if AAction = 'change_provider' then
    HandleChangeProviderMessage(AJson.GetValue<string>('provider', ''))
  else if AAction = 'change_model' then
    HandleChangeModelMessage(AJson.GetValue<string>('model', ''))
  else if AAction = 'error' then
    HandleErrorMessage(AJson.GetValue<string>('text', ''))
  else if AAction = 'create_project' then
  begin
    LFiles := AJson.GetValue('files') as TJSONArray;
    if Assigned(LFiles) then
      HandleCreateProjectMessage(LFiles.ToJSON)
    else
      HandleCreateProjectMessage('');
  end
  else
    AHandled := False;
end;

procedure TRadIAChatPresenter.DispatchSessionMessage(const AAction: string;
  const AJson: TJSONObject; var AHandled: Boolean);
begin
  AHandled := True;
  if (AAction = 'new_chat') or (AAction = 'new_session') then
    HandleNewChatMessage
  else if AAction = 'load_history' then
    HandleLoadHistoryMessage
  else if AAction = 'toggle_history' then
    HandleToggleHistoryMessage
  else if AAction = 'select_session' then
    HandleSelectSessionMessage(AJson.GetValue<string>('id', ''))
  else if AAction = 'rename_session' then
    HandleRenameSessionMessage(AJson.GetValue<string>('id', ''), AJson.GetValue<string>('name', ''))
  else if AAction = 'delete_session' then
    HandleDeleteSessionMessage(AJson.GetValue<string>('id', ''))
  else if AAction = 'clear_chat' then
    HandleClearChatMessage
  else
    AHandled := False;
end;

procedure TRadIAChatPresenter.DispatchInteractionMessage(const AAction: string;
  const AJson: TJSONObject; var AHandled: Boolean);
var
  LArguments: TJSONValue;
  LArgumentsJson: string;
begin
  AHandled := True;
  if AAction = 'update_stream' then
    HandleUpdateStreamMessage(
      AJson.GetValue<string>('text', ''),
      AJson.GetValue<Boolean>('isDone', False))
  else if AAction = 'send_prompt' then
    HandleSendPromptMessage(AJson.GetValue<string>('text', ''))
  else if AAction = 'generate_dto' then
    HandleGenerateDTOMessage(
      AJson.GetValue<string>('input', ''),
      AJson.GetValue<string>('inputType', ''),
      AJson.GetValue<string>('outputType', ''))
  else if AAction = 'cancel_request' then
    HandleCancelRequestMessage
  else if AAction = 'execute_tool' then
  begin
    LArguments := AJson.GetValue('arguments');
    if Assigned(LArguments) then
      LArgumentsJson := LArguments.ToJSON
    else
      LArgumentsJson := '{}';
    HandleExecuteToolMessage(
      AJson.GetValue<string>('name', ''),
      LArgumentsJson
    );
  end
  else if AAction = 'stream_chunk' then
    HandleStreamChunkMessage(
      AJson.GetValue<string>('text', ''),
      AJson.GetValue<Boolean>('isDone', False),
      AJson.GetValue<string>('error', ''))
  else if not TryDispatchAgentInteraction(AAction, AJson) then
    AHandled := False;
end;

function TRadIAChatPresenter.TryDispatchAgentInteraction(
  const AAction: string;
  const AJson: TJSONObject
): Boolean;
var
  LPlan: TJSONValue;
begin
  Result := True;
  if AAction = 'set_agent_mode' then
    SetAgentModeEnabled(AJson.GetValue<Boolean>('enabled', True))
  else if AAction = 'pause_agent' then
    PauseAgentRun
  else if (AAction = 'resume_agent') or (AAction = 'approve_agent') then
    ResumeAgentRun
  else if AAction = 'search_agent_history' then
    PostAgentHistoryToWeb(AJson.GetValue<string>('query', ''))
  else if AAction = 'update_agent_plan' then
  begin
    LPlan := AJson.GetValue('plan');
    if Assigned(LPlan) then
      UpdateAgentPlan(LPlan.ToJSON)
    else
      UpdateAgentPlan('');
  end
  else if AAction = 'replay_agent_step' then
    ReplayAgentStep(AJson.GetValue<Integer>('stepIndex', 0))
  else
    Result := False;
end;

function TRadIAChatPresenter.TryHandleAgentCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
begin
  Result := True;
  if TryHandleAgentPreparationCommand(APromptText, ACommandText) then
    Exit;
  if ACommandText.StartsWith('/agent run ', True) then
  begin
    PostToWebView('add_message', 'user', APromptText);
    if not FAgentModeEnabled then
    begin
      PostToWebView(
        'add_message',
        'assistant',
        'Agent mode is off. Enable it before starting an agent run.'
      );
      Exit(True);
    end;
    StartAgentRun(
      Trim(Copy(ACommandText, Length('/agent run ') + 1, MaxInt))
    );
    Exit;
  end;

  if SameText(ACommandText, '/agent pause') then
  begin
    PauseAgentRun;
    Exit;
  end;

  if SameText(ACommandText, '/agent resume') then
  begin
    ResumeAgentRun;
    Exit;
  end;

  if SameText(ACommandText, '/agent cancel') then
  begin
    CancelRequest;
    Exit;
  end;

  if SameText(ACommandText, '/agent') or
    SameText(ACommandText, '/agent on') or
    SameText(ACommandText, '/agent off') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    if SameText(ACommandText, '/agent on') then
      SetAgentModeEnabled(True)
    else if SameText(ACommandText, '/agent off') then
      SetAgentModeEnabled(False)
    else
      SetAgentModeEnabled(not FAgentModeEnabled);
    Exit;
  end;
  Result := False;
end;

function TRadIAChatPresenter.TryHandleAgentHistoryCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
begin
  Result := SameText(ACommandText, '/agent history') or
    ACommandText.StartsWith('/agent history ', True);
  if not Result then
    Exit;
  PostToWebView('add_message', 'user', APromptText);
  PostAgentHistoryToWeb(
    Trim(Copy(ACommandText, Length('/agent history') + 1, MaxInt))
  );
end;

function TRadIAChatPresenter.TryHandleAgentPreparationCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
begin
  Result := TryHandleAgentHistoryCommand(APromptText, ACommandText);
  if not Result then
    Result := TryHandleAgentPlanCommand(APromptText, ACommandText);
  if not Result then
    Result := TryHandleAgentReplayCommand(APromptText, ACommandText);
end;

function TRadIAChatPresenter.TryHandleAgentPlanCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
begin
  Result := ACommandText.StartsWith('/agent plan ', True);
  if not Result then
    Exit;
  PostToWebView('add_message', 'user', APromptText);
  UpdateAgentPlan(
    Trim(Copy(ACommandText, Length('/agent plan ') + 1, MaxInt))
  );
end;

function TRadIAChatPresenter.TryHandleAgentReplayCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
var
  LStepIndex: Integer;
  LValue: string;
begin
  Result := ACommandText.StartsWith('/agent replay ', True);
  if not Result then
    Exit;
  PostToWebView('add_message', 'user', APromptText);
  LValue := Trim(Copy(
    ACommandText,
    Length('/agent replay ') + 1,
    MaxInt
  ));
  if not TryStrToInt(LValue, LStepIndex) then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      'Agent replay requires a numeric step index.'
    );
    Exit;
  end;
  ReplayAgentStep(LStepIndex);
end;

function TRadIAChatPresenter.TryHandleCatalogCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
begin
  Result := True;
  if SameText(ACommandText, '/terminal') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    FView.OpenTerminal;
    Exit;
  end;

  if SameText(ACommandText, '/tools') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    PostToolsCatalogToWeb('show_tools');
    Exit;
  end;

  if SameText(ACommandText, '/revoke-tools') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    if Assigned(FToolPolicyExecutor) then
      FToolPolicyExecutor.RevokeSessionPermissions;
    PostToWebView(
      'add_message',
      'assistant',
      'All session tool permissions were revoked.'
    );
    Exit;
  end;
  Result := False;
end;

procedure TRadIAChatPresenter.HandleExplicitToolCommand(
  const APromptText: string;
  const ACommandText: string
);
var
  LArgumentsJson: string;
  LCommand: string;
  LSeparator: Integer;
  LToolName: string;
begin
  PostToWebView('add_message', 'user', APromptText);
  LCommand := Trim(Copy(ACommandText, Length('/tool') + 1, MaxInt));
  LSeparator := Pos(' ', LCommand);
  if LSeparator > 0 then
  begin
    LToolName := Trim(Copy(LCommand, Low(LCommand), LSeparator - 1));
    LArgumentsJson := Trim(Copy(LCommand, LSeparator + 1, MaxInt));
  end
  else
  begin
    LToolName := LCommand;
    LArgumentsJson := '{}';
  end;

  if LArgumentsJson = '' then
    LArgumentsJson := '{}';
  ExecuteRegisteredTool(LToolName, LArgumentsJson);
end;

function TRadIAChatPresenter.TryHandleToolPrompt(
  const APromptText: string
): Boolean;
var
  LText: string;
begin
  LText := Trim(APromptText);
  if TryHandleAgentCommand(APromptText, LText) then
    Exit(True);
  if TryHandleCatalogCommand(APromptText, LText) then
    Exit(True);
  Result := SameText(LText, '/tool') or
    LText.StartsWith('/tool ', True);
  if Result then
    HandleExplicitToolCommand(APromptText, LText);
end;

procedure TRadIAChatPresenter.ExecuteRegisteredTool(
  const AName: string;
  const AArgumentsJson: string
);
var
  LCorrelationId: string;
  LExecutor: IRadIAToolExecutor;
  LGuard: IRadIALifecycleGuard;
  LProjectId: string;
  LProject: TRadIAProjectSnapshot;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
begin
  if not FAgentModeEnabled then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      'Agent mode is off. Enable it with the Agent button or /agent on.'
    );
    Exit;
  end;

  LCorrelationId := TGUID.NewGuid.ToString;
  PostToolCallToWeb(AName, AArgumentsJson, LCorrelationId);

  if not Assigned(FToolRegistry) or not Assigned(FToolExecutor) then
  begin
    LResult := TRadIAToolResult.Failed(
      'tools_unavailable',
      'The IDE tool service is not available.'
    );
    PostToolResultToWeb(AName, LCorrelationId, LResult);
    Exit;
  end;

  LProjectId := '';
  if Assigned(FWorkspace) then
  begin
    LProject := FWorkspace.GetActiveProject;
    LProjectId := LProject.FileName;
  end;

  LRequest := TRadIAToolRequest.Create(
    AName,
    AArgumentsJson,
    LCorrelationId,
    'chat',
    FSessionManager.ActiveSessionId,
    LProjectId,
    'workspace'
  );
  LExecutor := FToolExecutor;
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  TInterlocked.Increment(GActiveThreadCount);
  TThread.CreateAnonymousThread(
    procedure
    var
      LResultJson: string;
      LToolResult: TRadIAToolResult;
    begin
      try
        LToolResult := LExecutor.Execute(LRequest);
        LResultJson := SerializeToolResult(
          AName,
          LCorrelationId,
          LToolResult
        );
        TThread.Queue(
          nil,
          TThreadProcedure(
            procedure
            begin
              if LGuard.IsAlive then
              begin
                if not GIsShuttingDown then
                  Self.FView.PostMessageToWeb(LResultJson);
              end;
            end
          )
        );
      finally
        TInterlocked.Decrement(GActiveThreadCount);
      end;
    end
  ).Start;
end;

procedure TRadIAChatPresenter.PostJsonToWeb(
  const AJson: TJSONObject
);
var
  LSerialized: string;
begin
  LSerialized := AJson.ToJSON;
  if not FWebViewReady then
    FPendingWebMessages.Add(LSerialized)
  else
    FView.PostMessageToWeb(LSerialized);
end;

procedure TRadIAChatPresenter.PostToolCallToWeb(
  const AName: string;
  const AArgumentsJson: string;
  const ACorrelationId: string
);
var
  LArguments: TJSONValue;
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'tool_call');
    LJson.AddPair('name', AName);
    LJson.AddPair('correlationId', ACorrelationId);
    LArguments := TJSONObject.ParseJSONValue(AArgumentsJson);
    if Assigned(LArguments) then
      LJson.AddPair('arguments', LArguments)
    else
      LJson.AddPair('argumentsText', AArgumentsJson);
    PostJsonToWeb(LJson);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.PostToolResultToWeb(
  const AName: string;
  const ACorrelationId: string;
  const AResult: TRadIAToolResult
);
begin
  FView.PostMessageToWeb(
    SerializeToolResult(AName, ACorrelationId, AResult)
  );
end;

class function TRadIAChatPresenter.SerializeToolResult(
  const AName: string;
  const ACorrelationId: string;
  const AResult: TRadIAToolResult
): string;
var
  LContent: TJSONValue;
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'tool_result');
    LJson.AddPair('name', AName);
    LJson.AddPair('correlationId', ACorrelationId);
    LJson.AddPair('success', TJSONBool.Create(AResult.Success));
    LJson.AddPair('truncated', TJSONBool.Create(AResult.Truncated));
    if AResult.Success then
    begin
      LContent := TJSONObject.ParseJSONValue(AResult.ContentJson);
      if Assigned(LContent) then
        LJson.AddPair('result', LContent)
      else
        LJson.AddPair('resultText', AResult.ContentJson);
    end
    else
    begin
      LJson.AddPair('errorCode', AResult.ErrorCode);
      LJson.AddPair('errorMessage', AResult.ErrorMessage);
    end;
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.SetAgentModeEnabled(const AEnabled: Boolean);
begin
  if not AEnabled and Assigned(FAgentController) and
    FAgentController.IsRunning then
    FAgentController.Cancel;
  FAgentModeEnabled := AEnabled;
  PostAgentModeToWeb;
  if FAgentModeEnabled then
    PostToWebView('add_message', 'assistant', 'Agent mode is enabled.')
  else
    PostToWebView('add_message', 'assistant', 'Agent mode is disabled.');
end;

function TRadIAChatPresenter.BuildAgentToolCatalogJson: string;
var
  LTools: TJSONArray;
begin
  LTools := BuildToolsJsonArray;
  try
    Result := LTools.ToJSON;
  finally
    LTools.Free;
  end;
end;

procedure TRadIAChatPresenter.HandleAgentFinished(
  const AResult: TRadIAAgentRunResult;
  const AProvider: string;
  const AModel: string
);
var
  LAssistantMessage: IRadIAChatMessage;
  LGuard: IRadIALifecycleGuard;
begin
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  TThread.Queue(
    nil,
    TThreadProcedure(
      procedure
      begin
        if not LGuard.IsAlive then
          Exit;
        FRequestInProgress := False;
        FCancelledByUser := AResult.Status = asCancelled;
        FView.SetRequestState(False);
        LAssistantMessage := TRadIAChatMessage.CreateMessage(
          mrAssistant,
          AResult.Message,
          AProvider,
          AModel
        );
        FHistory := FHistory + [LAssistantMessage];
        SaveChatHistory;
        PostToWebView(
          'add_message',
          'assistant',
          AResult.Message,
          AProvider,
          AModel
        );
      end
    )
  );
end;

procedure TRadIAChatPresenter.PauseAgentRun;
begin
  if Assigned(FAgentController) and FAgentController.IsRunning then
    FAgentController.Pause;
end;

procedure TRadIAChatPresenter.PostAgentStateToWeb(
  const ASnapshotJson: string
);
var
  LGuard: IRadIALifecycleGuard;
begin
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  TThread.Queue(
    nil,
    TThreadProcedure(
      procedure
      var
        LJson: TJSONObject;
        LState: TJSONValue;
      begin
        if not LGuard.IsAlive then
          Exit;
        LState := TJSONObject.ParseJSONValue(ASnapshotJson);
        if not Assigned(LState) then
          Exit;
        LJson := TJSONObject.Create;
        try
          LJson.AddPair('action', 'agent_state');
          LJson.AddPair('state', LState);
          PostJsonToWeb(LJson);
        finally
          LJson.Free;
        end;
      end
    )
  );
end;

procedure TRadIAChatPresenter.PostAgentHistoryToWeb(
  const AQuery: string
);
const
  MAX_VISIBLE_RUNS = 50;
var
  LArray: TJSONArray;
  LCheckpointDirectory: string;
  LIndex: Integer;
  LJson: TJSONObject;
  LLastVisibleIndex: Integer;
  LRunJson: TJSONObject;
  LRuns: TArray<TRadIAAgentCheckpointSummary>;
  LStore: TRadIAAgentFileCheckpointStore;
begin
  LCheckpointDirectory := TPath.Combine(FDataDir, 'agent-checkpoints');
  LStore := TRadIAAgentFileCheckpointStore.Create(LCheckpointDirectory);
  try
    LRuns := LStore.Search(AQuery);
  finally
    LStore.Free;
  end;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'agent_history');
    LJson.AddPair('query', AQuery);
    LJson.AddPair('total', TJSONNumber.Create(Length(LRuns)));
    LArray := TJSONArray.Create;
    LJson.AddPair('runs', LArray);
    LLastVisibleIndex := High(LRuns);
    if LLastVisibleIndex >= MAX_VISIBLE_RUNS then
      LLastVisibleIndex := MAX_VISIBLE_RUNS - 1;
    for LIndex := 0 to LLastVisibleIndex do
    begin
      LRunJson := TJSONObject.Create;
      LRunJson.AddPair('sessionId', LRuns[LIndex].SessionId);
      LRunJson.AddPair('objective', LRuns[LIndex].Objective);
      LRunJson.AddPair('status', LRuns[LIndex].Status);
      LRunJson.AddPair(
        'stepCount',
        TJSONNumber.Create(LRuns[LIndex].StepCount)
      );
      LRunJson.AddPair('updatedAtUtc', LRuns[LIndex].UpdatedAtUtc);
      LArray.AddElement(LRunJson);
    end;
    PostJsonToWeb(LJson);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.ResumeAgentRun;
begin
  if not Assigned(FAgentController) or FAgentController.IsRunning then
    Exit;
  FRequestInProgress := True;
  FCancelledByUser := False;
  FView.SetRequestState(True);
  FAgentController.Resume(FSessionManager.ActiveSessionId);
end;

procedure TRadIAChatPresenter.ReplayAgentStep(
  const AStepIndex: Integer
);
begin
  if AStepIndex < 1 then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      'Agent replay requires a positive step index.'
    );
    Exit;
  end;
  if not Assigned(FAgentController) or FAgentController.IsRunning then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      'Pause an active agent run before replaying one of its steps.'
    );
    Exit;
  end;
  FRequestInProgress := True;
  FCancelledByUser := False;
  FView.SetRequestState(True);
  FAgentController.ReplayStep(
    FSessionManager.ActiveSessionId,
    AStepIndex
  );
end;

procedure TRadIAChatPresenter.UpdateAgentPlan(
  const APlanJson: string
);
var
  LCheckpointDirectory: string;
  LSessionId: string;
  LSnapshot: string;
  LStore: TRadIAAgentFileCheckpointStore;
begin
  LSessionId := FSessionManager.ActiveSessionId;
  if LSessionId = '' then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      'There is no active chat session whose agent plan can be edited.'
    );
    Exit;
  end;
  LCheckpointDirectory := TPath.Combine(FDataDir, 'agent-checkpoints');
  LStore := TRadIAAgentFileCheckpointStore.Create(LCheckpointDirectory);
  try
    try
      LSnapshot := LStore.UpdatePlan(LSessionId, APlanJson);
      PostAgentStateToWeb(LSnapshot);
    except
      on E: Exception do
        PostToWebView(
          'add_message',
          'assistant',
          'The agent plan was not updated: ' + E.Message
        );
    end;
  finally
    LStore.Free;
  end;
end;

procedure TRadIAChatPresenter.StartAgentRun(
  const AObjective: string
);
var
  LActiveModel: string;
  LActiveProvider: string;
  LCheckpointDirectory: string;
  LDecisionProvider: IRadIAAgentDecisionProvider;
  LGuard: IRadIALifecycleGuard;
  LLimits: TRadIAAgentLimits;
  LPricing: TRadIAAgentPricing;
  LPricingCatalog: TRadIAAgentPricingCatalog;
  LProviderSettings: TRadIAAgentProviderSettings;
  LProject: TRadIAProjectSnapshot;
  LProjectId: string;
  LSessionId: string;
  LStore: IRadIAAgentCheckpointStore;
  LUserMessage: IRadIAChatMessage;
begin
  if TryStartCliAgentRun(AObjective) then
    Exit;
  if not Assigned(FToolExecutor) or not Assigned(FToolRegistry) then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      'Agent runtime is unavailable because the IDE tool service is not ready.'
    );
    Exit;
  end;
  if not CheckQuotaAvailability then
    Exit;

  LActiveProvider := FConfig.GetActiveProvider;
  LActiveModel := FConfig.GetActiveModel(LActiveProvider);
  if FConfig.IsWebLoginProvider(LActiveProvider) then
    LActiveModel := 'Web Login';
  LSessionId := FSessionManager.ActiveSessionId;
  if LSessionId = '' then
  begin
    CreateNewSession;
    LSessionId := FSessionManager.ActiveSessionId;
  end;

  LProjectId := '';
  if Assigned(FWorkspace) then
  begin
    LProject := FWorkspace.GetActiveProject;
    LProjectId := LProject.FileName;
  end;
  LPricingCatalog := TRadIAAgentPricingCatalog.Create(
    TPath.Combine(FDataDir, 'agent-pricing.json')
  );
  try
    if LPricingCatalog.TryResolve(
      LActiveProvider,
      LActiveModel,
      LPricing
    ) then
    begin
      LProviderSettings := TRadIAAgentProviderSettings.WithPricing(
        BuildAgentToolCatalogJson,
        LPricing
      );
      LLimits := TRadIAAgentLimits.Create(
        20,
        3,
        15 * 60 * 1000,
        100000,
        LPricingCatalog.DefaultRunBudgetMicros
      );
    end
    else
    begin
      LProviderSettings := TRadIAAgentProviderSettings.Default(
        BuildAgentToolCatalogJson
      );
      LLimits := TRadIAAgentLimits.Default;
    end;
  finally
    LPricingCatalog.Free;
  end;
  LDecisionProvider := TRadIAAgentServiceDecisionProvider.Create(
    FAIService,
    FHistory,
    LProviderSettings
  );
  LCheckpointDirectory := TPath.Combine(FDataDir, 'agent-checkpoints');
  LStore := TRadIAAgentFileCheckpointStore.Create(LCheckpointDirectory);
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  FAgentController := TRadIAAgentRunController.Create(
    FToolExecutor,
    LDecisionProvider,
    LStore,
    procedure(const ASnapshotJson: string)
    begin
      if LGuard.IsAlive then
        PostAgentStateToWeb(ASnapshotJson);
    end,
    procedure(const AResult: TRadIAAgentRunResult)
    begin
      if LGuard.IsAlive then
        HandleAgentFinished(AResult, LActiveProvider, LActiveModel);
    end
  );

  LUserMessage := TRadIAChatMessage.CreateMessage(
    mrUser,
    AObjective,
    LActiveProvider,
    LActiveModel
  );
  FHistory := FHistory + [LUserMessage];
  SaveChatHistory;
  FRequestInProgress := True;
  FCancelledByUser := False;
  FView.SetRequestState(True);
  FAgentController.Start(
    AObjective,
    LSessionId,
    LProjectId,
    LLimits
  );
end;

function TRadIAChatPresenter.TryStartCliAgentRun(
  const AObjective: string
): Boolean;
var
  LClientSettings: TRadIACliMcpClientSettings;
  LClientStore: TRadIACliMcpSettings;
  LDefinition: TRadIACliDefinition;
  LDetection: TRadIACliDetection;
  LDetector: TRadIACliDetector;
  LGuard: IRadIALifecycleGuard;
  LInvocation: TRadIACliInvocation;
  LProject: TRadIAProjectSnapshot;
  LSettings: TRadIAAgentExecutorSettings;
  LUserMessage: IRadIAChatMessage;
  LWorkingDirectory: string;
begin
  LSettings := FAgentExecutorSettings.Load;
  Result := LSettings.Kind = aekCli;
  if not Result then
    Exit;
  if not CheckQuotaAvailability then
    Exit;
  if not TRadIACliCatalog.FindById(LSettings.CliClientId, LDefinition) then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      'The selected CLI executor is no longer supported.'
    );
    Exit;
  end;
  LProject := Default(TRadIAProjectSnapshot);
  if Assigned(FWorkspace) then
    LProject := FWorkspace.GetActiveProject;
  LWorkingDirectory := ExtractFileDir(LProject.FileName);
  if LWorkingDirectory = '' then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      'Open a Delphi project before starting an external CLI agent.'
    );
    Exit;
  end;

  LClientStore := TRadIACliMcpSettings.Create;
  try
    LClientSettings := LClientStore.Load(LDefinition.Id, '', '');
  finally
    LClientStore.Free;
  end;
  LDetector := TRadIACliDetector.Create;
  try
    LDetection := LDetector.Detect(
      LDefinition,
      LClientSettings.CliExecutablePath
    );
  finally
    LDetector.Free;
  end;
  if not LDetection.Installed then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      LDefinition.DisplayName +
        ' was not found. Open Settings > CLI & MCP to diagnose it.'
    );
    Exit;
  end;

  LInvocation := TRadIACliInvocationBuilder.Build(
    LDefinition,
    LDetection.ExecutablePath,
    AObjective,
    LWorkingDirectory
  );
  LUserMessage := TRadIAChatMessage.CreateMessage(
    mrUser,
    AObjective,
    LDefinition.DisplayName,
    'CLI'
  );
  FHistory := FHistory + [LUserMessage];
  SaveChatHistory;
  FRequestInProgress := True;
  FCancelledByUser := False;
  FView.SetRequestState(True);
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  FCliProcessSession := TRadIACliProcessRunner.Start(
    LInvocation,
    15 * 60 * 1000,
    nil,
    nil,
    procedure(AResult: TRadIACliProcessResult)
    begin
      TThread.Queue(
        nil,
        procedure
        begin
          if LGuard.IsAlive then
            Self.HandleCliAgentFinished(
              AResult,
              LDefinition.DisplayName
            );
        end
      );
    end
  );
end;

procedure TRadIAChatPresenter.HandleCliAgentFinished(
  const AResult: TRadIACliProcessResult;
  const AClientName: string
);
var
  LMessage: IRadIAChatMessage;
  LResponse: string;
begin
  FCliProcessSession := nil;
  FRequestInProgress := False;
  FView.SetRequestState(False);
  if AResult.Cancelled or FCancelledByUser then
    LResponse := 'CLI agent execution was cancelled.'
  else if AResult.TimedOut then
    LResponse := 'CLI agent execution exceeded the 15-minute limit.'
  else if not AResult.Succeeded then
  begin
    LResponse := Trim(AResult.StdErr);
    if LResponse = '' then
      LResponse := Trim(AResult.StdOut);
    if LResponse = '' then
      LResponse := Format(
        'CLI agent failed with exit code %d.',
        [AResult.ExitCode]
      );
  end
  else
    LResponse := TRadIACliOutputParser.ExtractFinalText(AResult.StdOut);
  LMessage := TRadIAChatMessage.CreateMessage(
    mrAssistant,
    LResponse,
    AClientName,
    'CLI'
  );
  FHistory := FHistory + [LMessage];
  SaveChatHistory;
  PostToWebView(
    'add_message',
    'assistant',
    LResponse,
    AClientName,
    'CLI'
  );
end;

procedure TRadIAChatPresenter.PostAgentModeToWeb;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'agent_mode_changed');
    LJson.AddPair('enabled', TJSONBool.Create(FAgentModeEnabled));
    PostJsonToWeb(LJson);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.PostToolsCatalogToWeb(
  const AAction: string
);
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', AAction);
    LJson.AddPair('tools', BuildToolsJsonArray);
    PostJsonToWeb(LJson);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.DispatchWebMessage(const AAction: string; const AJson: TJSONObject);
var
  LHandled: Boolean;
begin
  DispatchSystemMessage(AAction, AJson, LHandled);
  if LHandled then Exit;

  DispatchSessionMessage(AAction, AJson, LHandled);
  if LHandled then Exit;

  DispatchInteractionMessage(AAction, AJson, LHandled);
end;

procedure TRadIAChatPresenter.ProcessWebMessage(const AMessage: string);
var
  LParsed: TJSONValue;
  LNestedParsed: TJSONValue;
  LJson: TJSONObject;
  LAction: string;
  LMessage: string;
begin
  TLogger.Log('ProcessWebMessage raw: ' + AMessage, 'UI');
  LMessage := AMessage.Trim;
  LParsed := TJSONObject.ParseJSONValue(LMessage);
  if not Assigned(LParsed) then
    Exit;

  try
    if LParsed is TJSONString then
    begin
      LNestedParsed := TJSONObject.ParseJSONValue(TJSONString(LParsed).Value);
      if Assigned(LNestedParsed) then
      begin
        LParsed.Free;
        LParsed := LNestedParsed;
      end;
    end;

    if not (LParsed is TJSONObject) then
      Exit;

    LJson := TJSONObject(LParsed);
    LAction := LJson.GetValue<string>('action', '');
    DispatchWebMessage(LAction, LJson);
  finally
    LParsed.Free;
  end;
end;

// Deprecated Web Login / WebViewBridge implementations removed


function TRadIAChatPresenter.ExtractCodeArgument(const AArgument: string): string;
var
  LText: string;
  LFenceStart: Integer;
  LCodeStart: Integer;
  LFenceEnd: Integer;
begin
  Result := AArgument.Trim;
  LText := AArgument.Replace(#13#10, #10).Replace(#13, #10);
  LFenceStart := Pos('```', LText);
  if LFenceStart <= 0 then
    Exit;

  LCodeStart := PosEx(#10, LText, LFenceStart + 3);
  if LCodeStart <= 0 then
    Exit;

  Inc(LCodeStart);
  LFenceEnd := PosEx('```', LText, LCodeStart);
  if LFenceEnd > 0 then
    Result := Copy(LText, LCodeStart, LFenceEnd - LCodeStart).TrimRight
  else
    Result := Copy(LText, LCodeStart, MaxInt).TrimRight;
end;

function TRadIAChatPresenter.FindTemplateForCommand(const ACommand, AArgument: string;
  out ATemplate: TPromptTemplate): Boolean;
var
  LTemp: TPromptTemplate;
  LFallbackNames: TArray<string>;
  LFallbackCommands: TArray<string>;
  I: Integer;
begin
  if not ACommand.StartsWith('/') then
    Exit(False);

  if SameText(ACommand, '/template') then
  begin
    if not AArgument.IsEmpty then
      Exit(FTemplateManager.FindTemplate(AArgument, ATemplate));
    Exit(False);
  end;

  for LTemp in FTemplateManager.GetTemplates do
  begin
    if SameText(LTemp.SlashCommand, ACommand) then
    begin
      ATemplate := LTemp;
      Exit(True);
    end;
  end;

  LFallbackCommands := ['/review', '/explain', '/refactor', '/optimize'];
  LFallbackNames := ['Review Leaks and SOLID', 'Explain Code',
     'Review Clean Code Delphi', 'Analyze Performance'];

  for I := Low(LFallbackCommands) to High(LFallbackCommands) do
  begin
    if SameText(ACommand, LFallbackCommands[I]) then
      Exit(FTemplateManager.FindTemplate(LFallbackNames[I], ATemplate));
  end;

  Result := False;
end;

function TRadIAChatPresenter.PreProcessPrompt(const APromptText: string): string;
var
  LTemplate: TPromptTemplate;
  LFound: Boolean;
  LCommand: string;
  LArgument: string;

  procedure ParseCommandAndArgument(const APrompt: string; var ACmd, AArg: string);
  var
    LFirstSeparator: Integer;
    I: Integer;
  begin
    ACmd := Trim(APrompt);
    AArg := '';
    LFirstSeparator := -1;
    for I := Low(APrompt) to High(APrompt) do
    begin
      if CharInSet(APrompt[I], [#9, #10, #13, ' ']) then
      begin
        LFirstSeparator := I - 1;
        Break;
      end;
    end;

    if LFirstSeparator > 0 then
    begin
      ACmd := APrompt.Substring(0, LFirstSeparator).Trim;
      AArg := APrompt.Substring(LFirstSeparator + 1).Trim;
    end;
  end;

  function ApplyTemplateVariables(const ATplText, AArgText: string): string;
  var
    LActiveCode: string;
  begin
    Result := ATplText;
    LActiveCode := '';

    if Result.Contains('{code}') then
    begin
      if not AArgText.IsEmpty then
        LActiveCode := ExtractCodeArgument(AArgText);

      if LActiveCode.IsEmpty then
      begin
        if not FView.GetActiveEditorText(LActiveCode, True) or LActiveCode.Trim.IsEmpty then
          FView.GetActiveEditorText(LActiveCode, False);
      end;

      Result := Result.Replace('{code}', LActiveCode);
    end;

    if Result.Contains('{specification}') then
      Result := Result.Replace('{specification}', AArgText)
    else if Result.Contains('{stacktrace}') then
      Result := Result.Replace('{stacktrace}', AArgText)
    else if Result.Contains('{argument}') then
      Result := Result.Replace('{argument}', AArgText);
  end;

begin
  Result := APromptText;
  ParseCommandAndArgument(APromptText, LCommand, LArgument);

  LFound := FindTemplateForCommand(LCommand, LArgument, LTemplate);
  if LFound then
    Result := ApplyTemplateVariables(LTemplate.Template, LArgument);
end;

{$IFDEF TESTS}
function TRadIAChatPresenter.TestPreProcessPrompt(const APromptText: string): string;
begin
  Result := PreProcessPrompt(APromptText);
end;
{$ENDIF}

procedure TRadIAChatPresenter.LoadChatHistory;
var
  LMsg: IRadIAChatMessage;
begin
  FHistory := [];
  if FSessionManager.ActiveSessionId.IsEmpty then
    Exit;

  try
    FHistory := FSessionManager.LoadSessionHistory(FSessionManager.ActiveSessionId);
    for LMsg in FHistory do
    begin
      PostToWebView('add_message', MessageRoleToString(LMsg.Role), LMsg.Content, False, LMsg.Provider, LMsg.Model);
    end;
    TLogger.Log(Format('LoadChatHistory: Loaded %d messages successfully from session %s',
      [Length(FHistory), FSessionManager.ActiveSessionId]), 'UI');
  except
    on E: Exception do
    begin
      TLogger.Log(Format('LoadChatHistory exception: %s', [E.Message]), 'UI');
      FHistory := [];
    end;
  end;
end;

procedure TRadIAChatPresenter.SaveChatHistory;
begin
  if FSessionManager.ActiveSessionId.IsEmpty then
    Exit;

  try
    FSessionManager.SaveSessionHistory(FSessionManager.ActiveSessionId, FHistory);
    TLogger.Log('SaveChatHistory: History saved successfully for session ' + FSessionManager.ActiveSessionId, 'UI');
  except
    on E: Exception do
      TLogger.Log(Format('SaveChatHistory write exception: %s', [E.Message]), 'UI');
  end;
end;

procedure TRadIAChatPresenter.LoadPromptHistory;
var
  LHistoryFile: string;
begin
  LHistoryFile := TPath.Combine(FDataDir, 'prompt_history.json');
  FPromptHistoryManager.LoadFromFile(LHistoryFile);
end;

procedure TRadIAChatPresenter.SavePromptHistory;
var
  LHistoryFile: string;
begin
  LHistoryFile := TPath.Combine(FDataDir, 'prompt_history.json');
  FPromptHistoryManager.SaveToFile(LHistoryFile);
end;

procedure TRadIAChatPresenter.UpdateSessionsList;
var
  LSessionsArray: TArray<TSessionInfo>;
begin
  if FSessionManager.Sessions.Count = 0 then
  begin
    FSessionManager.CreateSession('Initial Chat');
  end;

  LSessionsArray := FSessionManager.Sessions.ToArray;

  if FSessionManager.ActiveSessionId.IsEmpty and (Length(LSessionsArray) > 0) then
  begin
    FSessionManager.ActiveSessionId := LSessionsArray[0].Id;
    FConfig.ActiveSessionId := FSessionManager.ActiveSessionId;
    FConfig.Save;
  end;

  FView.UpdateSessions(GetVisibleSessions, FSessionManager.ActiveSessionId);
end;

function TRadIAChatPresenter.GetVisibleSessions: TArray<TSessionInfo>;
var
  LSession: TSessionInfo;
begin
  Result := [];
  for LSession in FSessionManager.Sessions do
  begin
    if SameText(LSession.Id, FSessionManager.ActiveSessionId) or
       FSessionManager.SessionHasHistory(LSession.Id) then
      Result := Result + [LSession];
  end;
end;

procedure TRadIAChatPresenter.PostToWebView(const AAction, ARole, AText: string;
    const AProvider: string; const AModel: string);
begin
  PostToWebView(AAction, ARole, AText, False, AProvider, AModel);
end;

procedure TRadIAChatPresenter.PostToWebView(const AAction, ARole, AText: string;
    const AIsDone: Boolean; const AProvider: string; const AModel: string);
var
  LJson: TJSONObject;
  LDisplayModel: string;
begin
  LDisplayModel := AModel;
  if (not AProvider.IsEmpty) and FConfig.IsWebLoginProvider(AProvider) then
    LDisplayModel := 'Web Login';

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', AAction);
    if not ARole.IsEmpty then
      LJson.AddPair('role', ARole);
    if not AText.IsEmpty then
      LJson.AddPair('text', AText);
    LJson.AddPair('isDone', TJSONBool.Create(AIsDone));
    if not AProvider.IsEmpty then
      LJson.AddPair('provider', AProvider);
    if not LDisplayModel.IsEmpty then
      LJson.AddPair('model', LDisplayModel);

    if not FWebViewReady then
    begin
      FPendingWebMessages.Add(LJson.ToJSON);
      Exit;
    end;

    TLogger.Log(Format('PostToWebView: Action=%s, Role=%s, TextLen=%d, IsDone=%s, Provider=%s, Model=%s',
      [AAction, ARole, Length(AText), BoolToStr(AIsDone, True), AProvider, LDisplayModel]), 'UI');

    FView.PostMessageToWeb(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.SendInitialConfigToWeb;
var
  LJson: TJSONObject;
  LActiveProvider: string;
  LActiveModel: string;
  LIsWebLogin: Boolean;
begin
  if not FWebViewReady then Exit;

  LActiveProvider := FConfig.GetActiveProvider;
  LIsWebLogin := FConfig.IsWebLoginProvider(LActiveProvider);

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'initialize_config');
    LJson.AddPair('providers', BuildProvidersJsonArray);
    LJson.AddPair('models', BuildModelsJsonArray(LActiveProvider, LIsWebLogin, LActiveModel));
    LJson.AddPair('slashCommands', BuildSlashCommandsJsonArray);
    LJson.AddPair('tools', BuildToolsJsonArray);
    LJson.AddPair('agentModeEnabled', TJSONBool.Create(FAgentModeEnabled));
    LJson.AddPair('activeProvider', LActiveProvider);
    LJson.AddPair('activeModel', LActiveModel);
    LJson.AddPair('isWebLogin', TJSONBool.Create(LIsWebLogin));

    FView.PostMessageToWeb(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.SendModelsUpdateToWeb(const AModels: TArray<string>; const AActiveModel: string);
var
  LJson: TJSONObject;
  LModels: TJSONArray;
  LModel: string;
begin
  if not FWebViewReady then Exit;

  LJson := TJSONObject.Create;
  LModels := TJSONArray.Create;
  try
    for LModel in AModels do
    begin
      LModels.Add(LModel);
    end;

    LJson.AddPair('action', 'update_models');
    LJson.AddPair('models', LModels);
    LJson.AddPair('activeModel', AActiveModel);

    FView.PostMessageToWeb(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.SendSessionsUpdateToWeb;
var
  LJson: TJSONObject;
  LArr: TJSONArray;
  LSession: TSessionInfo;
  LObj: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'update_sessions');
    LArr := TJSONArray.Create;
    for LSession in GetVisibleSessions do
    begin
      LObj := TJSONObject.Create;
      LObj.AddPair('id', LSession.Id);
      LObj.AddPair('name', LSession.Name);
      LObj.AddPair('isActive', TJSONBool.Create(SameText(LSession.Id, FSessionManager.ActiveSessionId)));
      LArr.AddElement(LObj);
    end;
    LJson.AddPair('sessions', LArr);
    LJson.AddPair('activeSessionId', FSessionManager.ActiveSessionId);
    FView.PostMessageToWeb(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

end.
