unit RadIA.UI.ChatPresenter;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections, RadIA.Core.Interfaces,
  RadIA.Core.Sessions, RadIA.Core.PromptTemplates,
  RadIA.Core.DeclarativeExtensions,
  RadIA.Core.DeclarativeTools,
  RadIA.Core.TokenUsage, RadIA.Core.PromptHistory, RadIA.Core.Types,
  RadIA.Core.AgentController, RadIA.Core.AgentRuntime,
  RadIA.Core.AgentProvider,
  RadIA.Core.AgentExecutors, RadIA.Core.CliManager, RadIA.Core.CliProcess,
  RadIA.Core.Journeys, RadIA.Core.IntentRouter, RadIA.Core.Tools, RadIA.Core.ToolSecurity,
  RadIA.Core.Workspace, RadIA.Core.JourneyContext,
  RadIA.Core.VisualRuntimeSession,
  RadIA.Core.HierarchicalSettings,
  RadIA.Core.HierarchicalSettingsStore;

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
    procedure OpenExtensionManager;
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
    FDeclarativeExtensionManager:
      TRadIADeclarativeExtensionManager;
    FDeclarativeToolBinder: TRadIADeclarativeToolBinder;
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
    FJourneyContext: IRadIAJourneyContextCoordinator;
    FHierarchicalSettingsStore: IRadIAHierarchicalSettingsStore;
    FPendingRequestSettings: TRadIAExecutionSettings;
    FPendingRequestConversationId: string;
    FPendingRequestProjectId: string;
    FAgentModeEnabled: Boolean;
    FAgentController: IRadIAAgentRunController;
    FAgentExecutorSettings: TRadIAAgentExecutorSettingsStore;
    FCliProcessSession: IRadIACliProcessSession;
    FPendingJourneyActive: Boolean;
    FPendingJourneyContext: string;
    FPendingJourneyDeclarativePrompt: string;
    FPendingJourneyDefinition: TRadIAJourneyDefinition;
    FPendingJourneyField: string;
    FPendingJourneyNative: Boolean;
    FPendingIntentActive: Boolean;
    FPendingIntentCommand: string;
    FPendingIntentConfidence: string;
    FPendingIntentName: string;
    FPendingIntentPrompt: string;
    FVisualRuntimeSession: IRadIAVisualRuntimeSession;
    FLastVisualSessionId: string;
    FLastVisualSequence: Int64;

    procedure UpdateModelsCombo;

    procedure HandleUpdateModelsComboResult(AModels: TArray<string>; AProvider: IRadIAProvider);
    function BuildProvidersJsonArray: TJSONArray;
    function BuildModelsJsonArray(
  const AActiveProvider: string;
   LIsWebLogin: Boolean;
   out AActiveModel: string): TJSONArray;

    function BuildSlashCommandsJsonArray: TJSONArray;
    procedure AddUtilitySlashCommands(const ACommands: TJSONArray);
    function BuildReservedSlashCommands: TArray<string>;
    function BuildDeclarativeExtensionStatus: string;
    function BuildHelpText: string;
    procedure ReloadDeclarativeExtensions;
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
    function IsProviderAuthenticationConfigured(
      const AProviderId: string;
      const AAuthType: string
    ): Boolean;
    function CheckChatPreflight(
      const ASettings: TRadIAResolvedExecutionSettings;
      out AMessage: string
    ): Boolean;
    function CheckRequiredCli(
      const ACliId: string;
      out AMessage: string
    ): Boolean;
    function ProviderRequiresCodex(const AProviderId: string): Boolean;
    procedure ShowChatPreflightFailure(
      const APromptText: string;
      const AMessage: string
    );
    function CanChangeSession: Boolean;

    procedure SendInitialConfigToWeb;
    procedure SendModelsUpdateToWeb(
      const AModels: TArray<string>;
      const AActiveModel: string;
      const AEnabled: Boolean
    );
    function GetModelSelectionState: TRadIAModelSelectionState;
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
    function TryDispatchAgentSettingsInteraction(
      const AAction: string;
      const AJson: TJSONObject
    ): Boolean;
    function TryDispatchExecutionScopeInteraction(
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
    procedure SetAgentExecutor(const AExecutorId: string);
    procedure SetReasoningEffort(const AEffort: string);
    procedure PostAgentModeToWeb;
    procedure PostExecutionRouteToWeb;
    procedure PostExecutionScopeToWeb;
    procedure HandleExecutionScopeAction(
      const AJson: TJSONObject
    );
    procedure ExportExecutionScope(const AScopeName: string);
    procedure ResolveExecutionRoute(
      const AProvider: string;
      const AAuthType: string;
      const ASettings: TRadIAAgentExecutorSettings;
      out AMode: string;
      out AOrchestrator: string;
      out ATransport: string;
      out ADisplayName: string
    );
    function BuildExecutionRouteLabel(
      const AMode: string;
      const AOrchestrator: string;
      const ATransport: string;
      const AProvider: string;
      const ACliClientId: string
    ): string;
    function BuildExecutionRouteJson: TJSONObject;
    function GetAgentTokenLimit: Integer;
    function ResolveScopedAgentTokenLimit(
      const ASettings: TRadIAResolvedExecutionSettings
    ): Integer;
    procedure ResolveAgentRuntimeSettings(
      const AProvider: string;
      const AModel: string;
      const ATokenLimit: Integer;
      const AMaxSteps: Integer;
      out AProviderSettings: TRadIAAgentProviderSettings;
      out ALimits: TRadIAAgentLimits
    );
    procedure StartAgentRun(const AObjective: string);
    function TryStartCliAgentRun(
      const AObjective: string;
      const ASettings: TRadIAResolvedExecutionSettings;
      const AConversational: Boolean = False
    ): Boolean;
    function BuildConversationalCliPrompt(const APromptText: string): string;
    procedure HandleCliAgentFinished(
      const AResult: TRadIACliProcessResult;
      const ADefinition: TRadIACliDefinition;
      const ALocalSessionId: string;
      const AWorkingDirectory: string;
      const AWasResumed: Boolean
    );
    procedure PostCliActivity(
      const APhase: string;
      const AText: string;
      const ACliName: string;
      const AWorkingDirectory: string
    );
    procedure PostCliCompletionActivity(
      const AResult: TRadIACliProcessResult;
      const ADefinition: TRadIACliDefinition;
      const AWorkingDirectory: string
    );
    function BuildCliAgentResponse(
      const AResult: TRadIACliProcessResult;
      const ADefinition: TRadIACliDefinition;
      const ALocalSessionId: string;
      const AWorkingDirectory: string
    ): string;
    procedure PauseAgentRun;
    procedure ResumeAgentRun;
    procedure ReplayAgentStep(const AStepIndex: Integer);
    procedure UpdateAgentPlan(const APlanJson: string);
    procedure PostAgentHistoryToWeb(const AQuery: string);
    procedure PostAgentStateToWeb(const ASnapshotJson: string);
    procedure PostVisualRuntimeSessionToWeb;
    procedure PostDirectToolResultToWeb(
      const AName: string;
      const AResultJson: string
    );
    function BuildVisualRuntimeSessionJson(
      const ASnapshot: TRadIAVisualSessionSnapshot
    ): TJSONObject;
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
    function TryHandleCliCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    procedure PostCliSessionStatus;
    function CurrentExecutorId: string;
    function CurrentProjectId: string;
    procedure SyncJourneyContext;
    procedure EnsureJourneyProjectBoundary;
    procedure PostJourneyContextStatus;
    procedure ToggleJourneyContext;
    procedure CompleteJourneyActivity;
    function BuildGlobalExecutionSettings: TRadIAExecutionSettings;
    function ResolveEffectiveExecutionSettings:
      TRadIAResolvedExecutionSettings;
    procedure ResetPendingRequestSettings;
    function BuildExecutionSettingsStatus(
      const ASettings: TRadIAResolvedExecutionSettings
    ): string;
    function TryHandleScopeCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryUpdateScopeSettings(
      const AScopeName: string;
      const AFieldName: string;
      const AValue: string;
      out AError: string
    ): Boolean;
    function TryClearScopeSettings(
      const AScopeName: string;
      const AFieldName: string;
      out AError: string
    ): Boolean;
    function TryHandleJourneyContextCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryHandleStatusCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryHandleDoctorCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryHandleJourneyCommand(
      const APromptText: string;
      const ACommandText: string
    ): Boolean;
    function TryHandlePendingJourneyInput(const APromptText: string): Boolean;
    procedure ResetPendingJourney;
    procedure AskForPendingJourneyInput(const AQuestion: string);
    procedure StartPendingJourney;
    function TryBeginJourneyIntake(
      const AIsNative: Boolean;
      const ADefinition: TRadIAJourneyDefinition;
      const ADeclarative: TRadIADeclarativeCommand;
      const AContext: string
    ): Boolean;
    procedure HandleExplicitToolCommand(
      const APromptText: string;
      const ACommandText: string
    );
    function TryHandleToolPrompt(const APromptText: string): Boolean;
    function TryHandleIntentRecommendation(
      const APromptText: string
    ): Boolean;
    procedure HandleIntentRecommendation(const AAction: string);
    procedure PostIntentRecommendation(
      const ARecommendation: TRadIAIntentRecommendation
    );
    procedure PostUserMessageIfPresent(const AText: string);
    procedure ClearPendingIntent;
    procedure SendPendingIntentToChat;
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
    function TestBuildConversationalCliPrompt(const APromptText: string): string;
    {$ENDIF}

    property SessionManager: TRadIASessionManager read FSessionManager;
    property WebViewReady: Boolean read FWebViewReady write FWebViewReady;
  end;

implementation

uses
  System.IOUtils, System.NetEncoding, System.StrUtils,
  RadIA.Core.Config, RadIA.Core.Logger,
  RadIA.Core.ProviderRegistry, RadIA.Core.ConversationExporter,
  RadIA.Core.DTO.Generator, RadIA.Core.ProjectGenerator,
  System.SyncObjs, RadIA.Core.Container, RadIA.Core.ChatMessage, RadIA.Core.Service,
  RadIA.Core.AgentPricing,
  RadIA.Core.AgentResultStore,
  RadIA.Core.ResultCompactionSettings,
  RadIA.Core.ResultCompactor,
  RadIA.Core.IntentTelemetry,
  RadIA.Core.ConfigDefaults,
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
  ResetPendingRequestSettings;
  ResetPendingJourney;

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
  TRadIAContainer.TryResolve<IRadIAJourneyContextCoordinator>(
    FJourneyContext
  );
  TRadIAContainer.TryResolve<IRadIAHierarchicalSettingsStore>(
    FHierarchicalSettingsStore
  );
  TRadIAContainer.TryResolve<IRadIAVisualRuntimeSession>(
    FVisualRuntimeSession
  );
  FLastVisualSessionId := '';
  FLastVisualSequence := 0;

  if ADataDir.IsEmpty then
    FDataDir := TPath.Combine(TPath.GetHomePath, 'RadIA')
  else
    FDataDir := ADataDir;

  FPromptHistoryManager := TPromptHistoryManager.Create;
  FAccumulatedUsage := TTokenUsage.Empty;

  FTemplateManager := TPromptTemplateManager.Create(FDataDir);
  FTemplateManager.Load;
  FDeclarativeExtensionManager :=
    TRadIADeclarativeExtensionManager.Create(
      TPath.Combine(FDataDir, 'extensions')
    );
  if Assigned(FToolRegistry) and Assigned(FToolExecutor) then
    FDeclarativeToolBinder := TRadIADeclarativeToolBinder.Create(
      FToolRegistry,
      FToolExecutor
    );
  ReloadDeclarativeExtensions;

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
  FDeclarativeToolBinder.Free;
  FDeclarativeExtensionManager.Free;
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
  SyncJourneyContext;
  LoadPromptHistory;
end;

function TRadIAChatPresenter.IsProviderConfigured(const AProviderId: string): Boolean;
var
  LAuthType: string;
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

    LAuthType := FConfig.GetProviderAuthType(AProviderId);
    if not SameText(LAuthType, 'api_key') then
      Exit(IsProviderAuthenticationConfigured(AProviderId, LAuthType));

    Result := not FConfig.GetApiKey(AProviderId).Trim.IsEmpty;
  end;
end;

function TRadIAChatPresenter.IsProviderAuthenticationConfigured(
  const AProviderId: string;
  const AAuthType: string
): Boolean;
begin
  if SameText(AAuthType, 'oauth_cli') or
    SameText(AAuthType, 'web_login') then
    Exit(True);
  if not SameText(AAuthType, 'oauth') then
    Exit(False);
  if SameText(AProviderId, 'OpenAI') then
    Exit(True);
  Result := not FConfig.GetOAuthAccessToken(AProviderId).Trim.IsEmpty or
    not FConfig.GetOAuthRefreshToken(AProviderId).Trim.IsEmpty;
end;



function TRadIAChatPresenter.CanChangeSession: Boolean;
begin
  Result := not FRequestInProgress and not FPendingJourneyActive;
  if FRequestInProgress then
    FView.ShowMessageDialog('Wait for the current response to finish, or cancel it before switching chats.');
  if FPendingJourneyActive then
    FView.ShowMessageDialog(
      'Finish the current journey input or use /journey cancel before switching chats.'
    );
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
    FConfig.Load;
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
  LEffective: TRadIAResolvedExecutionSettings;
  LModelState: TRadIAModelSelectionState;
  LProvId: string;
begin
  if FModelsProvider <> AProvider then
    Exit;
  FModelsProvider := nil;

  LModelState := GetModelSelectionState;
  if not LModelState.Enabled then
    Exit;

  if Assigned(AProvider) then
  begin
    Self.FActiveModels := AModels;
    LProvId := AProvider.GetProviderId;
    LEffective := ResolveEffectiveExecutionSettings;
    LActiveModel := LEffective.Values.ModelId;

    if (Length(AModels) > 0) and (LActiveModel.IsEmpty or (IndexOfString(AModels, LActiveModel) = -1)) then
    begin
      LActiveModel := AModels[0];
      if LEffective.ModelOrigin = rsoGlobal then
      begin
        Self.FConfig.SetActiveModel(LProvId, LActiveModel);
        Self.FConfig.Save;
      end;
    end;

    Self.FView.UpdateModels(AModels, LActiveModel, True);
    Self.SendModelsUpdateToWeb(AModels, LActiveModel, True);
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

function TRadIAChatPresenter.BuildDeclarativeExtensionStatus: string;
var
  LDiagnostic: TRadIADeclarativeExtensionDiagnostic;
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
  LSourceName: string;
begin
  LDiagnostics := FDeclarativeExtensionManager.GetDiagnostics;
  if Length(LDiagnostics) = 0 then
    Exit('No declarative extension manifests were found.');
  Result := '';
  for LDiagnostic in LDiagnostics do
  begin
    if Result <> '' then
      Result := Result + sLineBreak;
    LSourceName := ExtractFileName(LDiagnostic.FileName);
    if LSourceName.IsEmpty then
      LSourceName := 'declarative tools';
    Result := Result + '[' + LDiagnostic.Status + '] ' +
      LSourceName + ': ' +
      LDiagnostic.Message;
  end;
end;

function TRadIAChatPresenter.BuildReservedSlashCommands:
  TArray<string>;
const
  CNativeCommands: array[0..24] of string = (
    '/agent',
    '/agent run',
    '/agent plan',
    '/agent replay',
    '/agent pause',
    '/agent resume',
    '/agent cancel',
    '/agent history',
    '/help',
    '/terminal',
    '/settings',
    '/extensions',
    '/health',
    '/doctor',
    '/doctor --deep',
    '/status',
    '/tools',
    '/revoke-tools',
    '/cli session',
    '/cli new',
    '/context',
    '/context new',
    '/context detach',
    '/context switch',
    '/scope'
  );
var
  LCommand: string;
  LCommands: TList<string>;
  LJourney: TRadIAJourneyDefinition;
  LTemplate: TPromptTemplate;
begin
  LCommands := TList<string>.Create;
  try
    for LCommand in CNativeCommands do
      LCommands.Add(LCommand);
    LCommands.Add('/tool');
    LCommands.Add('/extensions reload');
    LCommands.Add('/journey');
    LCommands.Add('/journey cancel');
    for LJourney in TRadIAJourneyCatalog.All do
      LCommands.Add(LJourney.Command);
    for LTemplate in FTemplateManager.GetTemplates do
      if not LTemplate.SlashCommand.IsEmpty then
        LCommands.Add(LTemplate.SlashCommand);
    Result := LCommands.ToArray;
  finally
    LCommands.Free;
  end;
end;

procedure TRadIAChatPresenter.ReloadDeclarativeExtensions;
begin
  FDeclarativeExtensionManager.Reload(
    BuildReservedSlashCommands
  );
  if not Assigned(FDeclarativeToolBinder) then
    Exit;
  try
    FDeclarativeToolBinder.Reload(
      FDeclarativeExtensionManager.GetTools,
      FDeclarativeExtensionManager.GetWorkflows
    );
  except
    on E: Exception do
    begin
      FDeclarativeExtensionManager.ReportRuntimeError(E.Message);
      TLogger.Log(
        'Declarative tool reload rejected: ' + E.Message,
        'Extensions'
      );
    end;
  end;
end;

function TRadIAChatPresenter.BuildSlashCommandsJsonArray: TJSONArray;
var
  LCommand: TRadIADeclarativeCommand;
  LJourney: TRadIAJourneyDefinition;
  LTemplate: TPromptTemplate;
  LSlashObj: TJSONObject;
begin
  ReloadDeclarativeExtensions;
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

  AddUtilitySlashCommands(Result);

  LSlashObj := TJSONObject.Create;
  LSlashObj.AddPair('command', '/journey cancel');
  LSlashObj.AddPair('description', 'Abandons the active journey input collection.');
  LSlashObj.AddPair('name', 'Cancel Journey');
  LSlashObj.AddPair('isProjectGenerator', TJSONBool.Create(False));
  Result.AddElement(LSlashObj);

  for LJourney in TRadIAJourneyCatalog.All do
  begin
    LSlashObj := TJSONObject.Create;
    LSlashObj.AddPair('command', LJourney.Command);
    LSlashObj.AddPair('description', LJourney.Description);
    LSlashObj.AddPair('usage', LJourney.Usage);
    LSlashObj.AddPair('example', LJourney.Example);
    LSlashObj.AddPair('name', LJourney.Name);
    LSlashObj.AddPair(
      'isProjectGenerator',
      TJSONBool.Create(False)
    );
    Result.AddElement(LSlashObj);
  end;

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
  for LCommand in FDeclarativeExtensionManager.GetCommands do
  begin
    LSlashObj := TJSONObject.Create;
    LSlashObj.AddPair('command', LCommand.SlashCommand);
    LSlashObj.AddPair('description', LCommand.Description);
    LSlashObj.AddPair(
      'name',
      LCommand.Name + ' (' + LCommand.Kind + ': ' +
      LCommand.ExtensionId + ')'
    );
    LSlashObj.AddPair(
      'isProjectGenerator',
      TJSONBool.Create(False)
    );
    Result.AddElement(LSlashObj);
  end;
end;

procedure TRadIAChatPresenter.AddUtilitySlashCommands(
  const ACommands: TJSONArray
);
  procedure AddCommand(
    const ACommand: string;
    const ADescription: string;
    const AName: string
  );
  var
    LSlashObj: TJSONObject;
  begin
    LSlashObj := TJSONObject.Create;
    LSlashObj.AddPair('command', ACommand);
    LSlashObj.AddPair('description', ADescription);
    LSlashObj.AddPair('name', AName);
    LSlashObj.AddPair(
      'isProjectGenerator',
      TJSONBool.Create(False)
    );
    ACommands.AddElement(LSlashObj);
  end;
begin
  AddCommand('/help', 'Shows RadIA capabilities and documentation links.', 'RadIA Help');
  AddCommand('/terminal', 'Opens the integrated terminal.', 'Open Terminal');
  AddCommand('/settings', 'Opens RadIA settings.', 'Open Settings');
  AddCommand(
    '/extensions',
    'Opens the extension manager.',
    'Manage Extensions'
  );
  AddCommand(
    '/health',
    'Summarizes project health and prioritized risks.',
    'Project Health'
  );
  AddCommand(
    '/doctor',
    'Checks readiness and recommends the next corrective action.',
    'Installation Doctor'
  );
  AddCommand(
    '/doctor --deep',
    'Runs consented active CLI and MCP readiness probes.',
    'Deep Installation Doctor'
  );
  AddCommand(
    '/status',
    'Shows a sanitized snapshot of RadIA configuration and readiness.',
    'RadIA Status'
  );
  AddCommand('/tools', 'Lists available read-only IDE tools.', 'IDE Tools');
  AddCommand(
    '/cli session',
    'Shows the external CLI session linked to the active conversation.',
    'CLI Session Status'
  );
  AddCommand(
    '/cli new',
    'Detaches the external CLI session so the next request starts fresh.',
    'New CLI Session'
  );
  AddCommand(
    '/context',
    'Shows the journey shared by chat, terminal, and editor.',
    'Journey Context'
  );
  AddCommand(
    '/context new',
    'Creates a new journey for the active conversation and project.',
    'New Journey Context'
  );
  AddCommand(
    '/context detach',
    'Detaches the active conversation from its shared journey.',
    'Detach Journey Context'
  );
  AddCommand(
    '/context switch',
    'Switches to a journey from the active project by identifier.',
    'Switch Journey Context'
  );
  AddCommand(
    '/scope',
    'Shows effective execution settings, their sources, and override commands.',
    'Execution Settings Scope'
  );
  AddCommand(
    '/revoke-tools',
    'Revokes all IDE tool permissions granted for this session.',
    'Revoke Tool Permissions'
  );
  AddCommand(
    '/tool',
    'Runs a read-only IDE tool with optional JSON arguments.',
    'Run IDE Tool'
  );
  AddCommand(
    '/extensions reload',
    'Reloads and diagnoses declarative command extensions.',
    'Reload Extensions'
  );
end;

function TRadIAChatPresenter.BuildHelpText: string;
const
  CGuidesRoot = 'https://github.com/regyssilveira/RadIA-Plugin/blob/main/docs/guides/';
  CReferenceRoot = 'https://github.com/regyssilveira/RadIA-Plugin/blob/main/docs/reference/';
begin
  Result :=
    '## RadIA help' + sLineBreak + sLineBreak +
    '- **Chat and code:** ask questions or use `/` for code review, tests, documentation, and generators.' +
    sLineBreak +
    '- **Journeys:** use `/journey` for guided, end-to-end work. Missing input is collected one answer ' +
    'at a time; use `/journey cancel` to abandon it.' + sLineBreak +
    '- **Agent:** use `/agent on`, `/agent run <goal>`, pause, resume, inspect, or cancel observable runs.' +
    sLineBreak +
    '- **Project diagnostics:** use `/health`, `/doctor`, and `/status`.' + sLineBreak +
    '- **Scoped execution:** use `/scope` to inspect or override provider, model, executor, and ' +
      'limits by project, session, or next request.' + sLineBreak +
    '- **CLI, MCP, and providers:** open `/settings` to discover executables, authenticate, and choose ' +
    'native, CLI, or MCP execution.' + sLineBreak +
    '- **Tools and extensions:** use `/tools` and `/extensions`.' + sLineBreak + sLineBreak +
    '### Which mode should I use?' + sLineBreak + sLineBreak +
    '| Mode | Best for | IDE tools | Project required |' + sLineBreak +
    '|---|---|---|---|' + sLineBreak +
    '| Chat + RadIA native | Questions and explanations | No | No |' + sLineBreak +
    '| Agent + RadIA native | Create, edit, build, test, debug | With consent | Only for ' +
      'project-specific tools |' + sLineBreak +
    '| Chat + external CLI | Direct CLI conversation | CLI capabilities | No |' + sLineBreak +
    '| Agent + external CLI | Delegate an objective to a CLI | CLI capabilities | No |' + sLineBreak +
    '| MCP | Expose or consume registered tools | By tool policy | Depends on the tool |' +
      sLineBreak + sLineBreak +
    'To approve a pending plan, select **Approve plan** or type `/agent resume`.' +
      sLineBreak + sLineBreak +
    '### Documentation' + sLineBreak + sLineBreak +
    '- [Getting started](https://github.com/regyssilveira/RadIA-Plugin#readme)' + sLineBreak +
    '- [Slash commands](' + CReferenceRoot + 'slash_commands.md)' + sLineBreak +
    '- [Journeys](' + CGuidesRoot + 'user_guide_journeys.md)' + sLineBreak +
    '- [DEXT journeys](' + CGuidesRoot + 'user_guide_dext_journeys.md)' + sLineBreak +
    '- [Settings reference](' + CReferenceRoot + 'settings_reference.md)' + sLineBreak +
    '- [Scoped execution settings](' + CGuidesRoot + 'hierarchical_settings.md)';
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
  LAwareProvider: IRadIAExecutionSettingsAwareProvider;
  LEffective: TRadIAResolvedExecutionSettings;
  LModelState: TRadIAModelSelectionState;
  LProvider: IRadIAProvider;
  LGuard: IRadIALifecycleGuard;
begin
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

    LModelState := GetModelSelectionState;
    if not LModelState.Enabled then
    begin
      FActiveModels := [LModelState.DisplayText];
      FView.UpdateModels(FActiveModels, LModelState.DisplayText, False);
      SendModelsUpdateToWeb(FActiveModels, LModelState.DisplayText, False);
      Exit;
    end;

    FView.UpdateModels(['Loading...'], 'Loading...', False);

    LEffective := ResolveEffectiveExecutionSettings;
    if FConfig.IsWebLoginProvider(LEffective.Values.ProviderId) then
      FModelsProvider := TProviderRegistry.CreateProvider('WebViewBridge', FConfig)
    else
      FModelsProvider := TProviderRegistry.CreateProvider(
        LEffective.Values.ProviderId,
        FConfig
      );
    if Supports(
      FModelsProvider,
      IRadIAExecutionSettingsAwareProvider,
      LAwareProvider
    ) then
      LAwareProvider.ApplyExecutionSettings(LEffective.Values);
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
  PostExecutionRouteToWeb;
end;

procedure TRadIAChatPresenter.ChangeModel(const AModelName: string);
var
  LSelectedProvider: string;
begin
  if FLoadingConfig or not GetModelSelectionState.Enabled then
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
  ResetPendingJourney;
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
  SyncJourneyContext;
  PostExecutionRouteToWeb;

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
  if Assigned(FJourneyContext) then
    FJourneyContext.Detach(ASessionId);

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
  SyncJourneyContext;
  PostExecutionRouteToWeb;

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
  LRedactor: IRadIASecretRedactor;
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
    { Exported files are commonly shared, so strip secrets from the content }
    if not TRadIAContainer.TryResolve<IRadIASecretRedactor>(LRedactor) then
      LRedactor := TRadIASecretRedactor.Create;

    if SameText(ExtractFileExt(LFileName), '.html') then
      LContent := TConversationExporter.ExportToHTML(
        FHistory, LProviderName, LModelName, LRedactor)
    else
      LContent := TConversationExporter.ExportToMarkdown(
        FHistory, LProviderName, LModelName, LRedactor);

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
begin
  SendPromptText(APrompt);
end;

procedure TRadIAChatPresenter.SendPrompt;
var
  LEffectiveSettings: TRadIAResolvedExecutionSettings;
  LPreflightMessage: string;
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
  LEffectiveSettings := ResolveEffectiveExecutionSettings;
  if not CheckChatPreflight(LEffectiveSettings, LPreflightMessage) then
  begin
    FView.SetPromptInput(LText);
    ShowChatPreflightFailure(LText, LPreflightMessage);
    Exit;
  end;
  PostToWebView('add_message', 'user', LText);
  SendPromptToAI(LProcessed);
end;

procedure TRadIAChatPresenter.SendPromptText(const APromptText: string);
var
  LConversational: Boolean;
  LEffectiveSettings: TRadIAResolvedExecutionSettings;
  LPreflightMessage: string;
  LProcessed: string;
begin
  if TryHandleToolPrompt(APromptText) then
    Exit;

  EnsureJourneyProjectBoundary;
  LConversational := TRadIAIntentRouter.IsConversationalPrompt(APromptText);
  LProcessed := PreProcessPrompt(APromptText);
  LEffectiveSettings := ResolveEffectiveExecutionSettings;
  if not CheckChatPreflight(LEffectiveSettings, LPreflightMessage) then
  begin
    ShowChatPreflightFailure(APromptText, LPreflightMessage);
    Exit;
  end;
  PostToWebView('add_message', 'user', APromptText);
  if FAgentModeEnabled and not LConversational then
  begin
    StartAgentRun(LProcessed);
    Exit;
  end;
  if TryStartCliAgentRun(LProcessed, LEffectiveSettings, LConversational) then
    Exit;
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
  if Assigned(Self.FJourneyContext) then
    Self.FJourneyContext.CompleteActivity;
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

procedure TRadIAChatPresenter.HandleStreamDone(
  const APromptText, AActiveProvider, AActiveModel, AFullResponse: string
);
var
  LAssistantMsg: IRadIAChatMessage;
  LUsage: TTokenUsage;
  LStats: string;
begin
  Self.FRequestInProgress := False;
  if Assigned(Self.FJourneyContext) then
    Self.FJourneyContext.CompleteActivity;
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
  LDisplayError: string;
begin
  Self.FRequestInProgress := False;
  if Assigned(Self.FJourneyContext) then
    Self.FJourneyContext.CompleteActivity;
  Self.FView.SetRequestState(False);
  TLogger.Log(Format('SendPromptToAI error callback: %s', [AError]), 'UI');
  LDisplayError := AError;
  if not AFullResponse.IsEmpty then
  begin
    AFullResponse := AFullResponse + #13#10#13#10 + '**Error:** ' + LDisplayError;
    Self.PostToWebView('append_message', 'assistant', #13#10#13#10 + '**Error:** ' + LDisplayError,
        True, AActiveProvider, AActiveModel);

    LAssistantMsg := TRadIAChatMessage.CreateMessage(mrAssistant, AFullResponse, AActiveProvider,
        AActiveModel);
    Self.FHistory := Self.FHistory + [LAssistantMsg];
    Self.SaveChatHistory;
  end
  else
  begin
    Self.PostToWebView('add_message', 'assistant', '**Error:** ' + LDisplayError, False, AActiveProvider,
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
  LEffectiveSettings: TRadIAResolvedExecutionSettings;
  LActiveProvider: string;
  LActiveModel: string;
  LSessionId: string;
  LGuard: IRadIALifecycleGuard;
  HandleStreamCallback: TStreamChunkCallback;
begin
  { Settings can persist OAuth credentials even when its modal dialog is closed
    without OK. Reload before every native request to avoid stale credentials. }
  FConfig.Load;
  LEffectiveSettings := ResolveEffectiveExecutionSettings;
  LActiveProvider := LEffectiveSettings.Values.ProviderId;
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
  if Assigned(FJourneyContext) then
    FJourneyContext.BeginActivity;
  FCancelledByUser := False;
  FView.SetRequestState(True);

  LActiveProvider := LEffectiveSettings.Values.ProviderId;
  LActiveModel := LEffectiveSettings.Values.ModelId;
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
    FAIService.SendPromptStreamWithSettings(
      APromptText,
      FHistory,
      HandleStreamCallback,
      LProfile,
      LEffectiveSettings.Values
    );
    ResetPendingRequestSettings;
  except
    on E: Exception do
    begin
      FRequestInProgress := False;
      if Assigned(FJourneyContext) then
        FJourneyContext.CompleteActivity;
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
    if Assigned(FJourneyContext) then
      FJourneyContext.RequestCancellation;
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
  if Assigned(Self.FJourneyContext) then
    Self.FJourneyContext.CompleteActivity;
  Self.FView.SetRequestState(False);
  Self.PostToWebView('append_generator_code', '', ' [Cancelled by user]', True);
end;

procedure TRadIAChatPresenter.HandleGenerateDTOError(const AError: string);
begin
  Self.FRequestInProgress := False;
  if Assigned(Self.FJourneyContext) then
    Self.FJourneyContext.CompleteActivity;
  Self.FView.SetRequestState(False);
  Self.PostToWebView('append_generator_code', '', #13#10 + '// Error: ' + AError, True);
end;

procedure TRadIAChatPresenter.HandleGenerateDTODone(const APromptText, AActiveProvider: string);
var
  LUsage: TTokenUsage;
  LStats: string;
begin
  Self.FRequestInProgress := False;
  if Assigned(Self.FJourneyContext) then
    Self.FJourneyContext.CompleteActivity;
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
  if Assigned(FJourneyContext) then
    FJourneyContext.BeginActivity;
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
      if Assigned(FJourneyContext) then
        FJourneyContext.CompleteActivity;
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
  if (AAction = 'accept_intent_recommendation') or
    (AAction = 'review_intent_recommendation') or
    (AAction = 'dismiss_intent_recommendation') then
  begin
    HandleIntentRecommendation(AAction);
    Exit;
  end;
  if TryDispatchExecutionScopeInteraction(AAction, AJson) then
    Exit;
  if TryDispatchAgentSettingsInteraction(AAction, AJson) then
    Exit;
  if AAction = 'pause_agent' then
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

function TRadIAChatPresenter.TryDispatchAgentSettingsInteraction(
  const AAction: string;
  const AJson: TJSONObject
): Boolean;
begin
  Result := True;
  if AAction = 'set_agent_mode' then
    SetAgentModeEnabled(AJson.GetValue<Boolean>('enabled', True))
  else if AAction = 'set_agent_executor' then
    SetAgentExecutor(AJson.GetValue<string>('executor', 'native'))
  else if AAction = 'set_reasoning_effort' then
    SetReasoningEffort(AJson.GetValue<string>('effort', 'medium'))
  else if AAction = 'reset_cli_session' then
  begin
    FSessionManager.ClearCliConversation(FSessionManager.ActiveSessionId);
    PostExecutionRouteToWeb;
  end
  else if AAction = 'toggle_journey_context' then
    ToggleJourneyContext
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

function TRadIAChatPresenter.TryHandleCliCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
var
  LCliSession: TSessionInfo;
begin
  Result := True;
  if SameText(ACommandText, '/cli session') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    if FSessionManager.TryGetSession(
      FSessionManager.ActiveSessionId,
      LCliSession
    ) and (LCliSession.CliExternalSessionId <> '') then
      PostToWebView(
        'add_message',
        'assistant',
        'CLI session: `' + LCliSession.CliExternalSessionId + '` (' +
          LCliSession.CliClientId + '). The next compatible request resumes it.'
      )
    else
      PostToWebView(
        'add_message',
        'assistant',
        'No external CLI session is linked. The next CLI request starts a new session.'
      );
    Exit;
  end;
  if SameText(ACommandText, '/cli new') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    FSessionManager.ClearCliConversation(FSessionManager.ActiveSessionId);
    PostExecutionRouteToWeb;
    PostToWebView(
      'add_message',
      'assistant',
      'The external CLI session was detached. The next CLI request starts fresh.'
    );
    Exit;
  end;
  Result := False;
end;

function TRadIAChatPresenter.ProviderRequiresCodex(
  const AProviderId: string
): Boolean;
var
  LAuthType: string;
begin
  Result := False;
  if not SameText(AProviderId, 'OpenAI') then
    Exit;
  LAuthType := FConfig.GetProviderAuthType(AProviderId);
  Result := SameText(LAuthType, 'oauth_cli') or
    SameText(LAuthType, 'oauth') or
    SameText(LAuthType, 'web_login');
end;

function TRadIAChatPresenter.CheckRequiredCli(
  const ACliId: string;
  out AMessage: string
): Boolean;
var
  LDefinition: TRadIACliDefinition;
  LDetection: TRadIACliDetection;
begin
  AMessage := '';
  Result := TRadIACliCatalog.FindById(ACliId, LDefinition);
  if not Result then
  begin
    AMessage := 'The selected CLI is not supported by this RadIA installation. Open Settings and ' +
      'choose another execution route.';
    Exit;
  end;
  LDetection := TRadIACliResolver.Resolve(ACliId);
  Result := LDetection.Installed;
  if Result then
    Exit;
  AMessage := LDefinition.DisplayName + ' is required by the selected route, but it was not found.' +
    sLineBreak + sLineBreak +
    '**You do not need npm to use RadIA.** Choose one of these options:' + sLineBreak +
    '1. Open **Settings > CLI & MCP**, select this CLI, and use **Browse** to point to a portable ' +
    'executable.' + sLineBreak +
    '2. Use the optional guided installation only if you accept its displayed prerequisite and ' +
    'command.' + sLineBreak +
    '3. Select a native provider route and configure its API key; native routes do not require a ' +
    'CLI.' + sLineBreak + sLineBreak +
    'Run `/doctor` for the complete readiness report. Your message was not sent and no installation ' +
    'was started.';
end;

function TRadIAChatPresenter.CheckChatPreflight(
  const ASettings: TRadIAResolvedExecutionSettings;
  out AMessage: string
): Boolean;
var
  LProviderId: string;
begin
  AMessage := '';
  FConfig.Load;
  LProviderId := ASettings.Values.ProviderId;
  if not IsProviderConfigured(LProviderId) then
  begin
    AMessage := 'The selected provider is not configured. Open **Settings > Providers**, choose an ' +
      'authentication method, and complete the fields shown for that method.' + sLineBreak +
      sLineBreak + 'No CLI, npm, or MCP installation is required when you choose a native API route.' +
      sLineBreak + sLineBreak +
      'Run `/doctor` to see the remaining readiness checks. Your message was not sent.';
    Exit(False);
  end;
  if ProviderRequiresCodex(LProviderId) then
    Exit(CheckRequiredCli('codex', AMessage));
  if not SameText(ASettings.Values.ExecutorId, 'native') then
    Exit(CheckRequiredCli(ASettings.Values.ExecutorId, AMessage));
  Result := True;
end;

procedure TRadIAChatPresenter.ShowChatPreflightFailure(
  const APromptText: string;
  const AMessage: string
);
var
  LJson: TJSONObject;
begin
  PostToWebView('add_message', 'user', APromptText);
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'chat_preflight');
    LJson.AddPair('title', 'RadIA setup required');
    LJson.AddPair('message', AMessage);
    LJson.AddPair('pendingPrompt', APromptText);
    PostJsonToWeb(LJson);
  finally
    LJson.Free;
  end;
end;

function TRadIAChatPresenter.TryDispatchExecutionScopeInteraction(
  const AAction: string;
  const AJson: TJSONObject
): Boolean;
begin
  Result := True;
  if AAction = 'show_execution_scope' then
    PostExecutionScopeToWeb
  else if AAction = 'update_execution_scope' then
    HandleExecutionScopeAction(AJson)
  else if AAction = 'export_execution_scope' then
    ExportExecutionScope(AJson.GetValue<string>('scope', 'project'))
  else
    Result := False;
end;

function TRadIAChatPresenter.CurrentExecutorId: string;
var
  LSettings: TRadIAAgentExecutorSettings;
begin
  LSettings := FAgentExecutorSettings.Load;
  if LSettings.Kind = aekNative then
    Result := 'native'
  else
    Result := LSettings.CliClientId;
end;

function TRadIAChatPresenter.CurrentProjectId: string;
var
  LProject: TRadIAProjectSnapshot;
begin
  Result := '';
  if not Assigned(FWorkspace) then
    Exit;
  LProject := FWorkspace.GetActiveProject;
  Result := Trim(LProject.FileName);
end;

procedure TRadIAChatPresenter.SyncJourneyContext;
var
  LConversationId: string;
  LProjectId: string;
begin
  if not Assigned(FJourneyContext) then
    Exit;
  LConversationId := FSessionManager.ActiveSessionId;
  LProjectId := CurrentProjectId;
  if (LConversationId = '') or (LProjectId = '') then
    Exit;
  FJourneyContext.Activate(
    LConversationId,
    LProjectId,
    CurrentExecutorId
  );
end;

procedure TRadIAChatPresenter.EnsureJourneyProjectBoundary;
var
  LContext: TRadIAJourneyContextSnapshot;
begin
  if Assigned(FJourneyContext) and FJourneyContext.TryGetForConversation(
    FSessionManager.ActiveSessionId,
    LContext
  ) then
    SyncJourneyContext;
end;

procedure TRadIAChatPresenter.PostJourneyContextStatus;
var
  LContext: TRadIAJourneyContextSnapshot;
begin
  if Assigned(FJourneyContext) and FJourneyContext.TryGetActive(LContext) and
    LContext.MatchesProject(CurrentProjectId) then
    PostToWebView(
      'add_message',
      'assistant',
      'Active journey: `' + LContext.JourneyId + '`. Conversation: `' +
        LContext.ConversationId + '`. Executor: `' + LContext.ExecutorId + '`.'
    )
  else
    PostToWebView(
      'add_message',
      'assistant',
      'No journey is linked to the active conversation and project.'
    );
end;

procedure TRadIAChatPresenter.ToggleJourneyContext;
var
  LContext: TRadIAJourneyContextSnapshot;
begin
  if Assigned(FJourneyContext) and
    FJourneyContext.TryGetForConversation(
      FSessionManager.ActiveSessionId,
      LContext
    ) and LContext.MatchesProject(CurrentProjectId) then
    FJourneyContext.Detach(FSessionManager.ActiveSessionId)
  else
    SyncJourneyContext;
  PostExecutionRouteToWeb;
end;

procedure TRadIAChatPresenter.CompleteJourneyActivity;
begin
  if Assigned(FJourneyContext) then
    FJourneyContext.CompleteActivity;
end;

function TRadIAChatPresenter.BuildGlobalExecutionSettings:
  TRadIAExecutionSettings;
var
  LProviderId: string;
begin
  LProviderId := FConfig.GetActiveProvider;
  Result := TRadIAExecutionSettings.Create(
    LProviderId,
    FConfig.GetActiveModel(LProviderId),
    CurrentExecutorId,
    FConfig.GetMaxTokens(LProviderId),
    FConfig.GetTimeout(LProviderId) * 1000,
    GetAgentTokenLimit
  );
end;

function TRadIAChatPresenter.ResolveEffectiveExecutionSettings:
  TRadIAResolvedExecutionSettings;
var
  LDefaults: TRadIAExecutionSettings;
  LGlobal: TRadIAExecutionSettings;
  LGlobalTimeoutMs: Integer;
  LProject: TRadIAExecutionSettings;
  LProjectId: string;
  LRequest: TRadIAExecutionSettings;
  LSession: TRadIAExecutionSettings;
  LSessionId: string;
  LProviderResolution: TRadIAResolvedExecutionSettings;
begin
  LProject := TRadIAExecutionSettings.Empty;
  LRequest := TRadIAExecutionSettings.Empty;
  LSession := TRadIAExecutionSettings.Empty;
  LProjectId := CurrentProjectId;
  LSessionId := FSessionManager.ActiveSessionId;
  if Assigned(FHierarchicalSettingsStore) then
  begin
    if LProjectId <> '' then
      LProject := FHierarchicalSettingsStore.Load(rssProject, LProjectId);
    if LSessionId <> '' then
      LSession := FHierarchicalSettingsStore.Load(rssSession, LSessionId);
  end;
  if SameText(FPendingRequestConversationId, LSessionId) and
    SameText(FPendingRequestProjectId, LProjectId) then
    LRequest := FPendingRequestSettings;
  LDefaults := TRadIAExecutionSettings.Create(
    TConfigDefaults.ActiveProvider,
    '',
    'native',
    TConfigDefaults.MaxTokens,
    TConfigDefaults.Timeout * 1000,
    0
  );
  LGlobal := BuildGlobalExecutionSettings;
  LProviderResolution := TRadIAExecutionSettingsResolver.Resolve(
    LDefaults,
    LGlobal,
    LProject,
    LSession,
    LRequest
  );
  LGlobalTimeoutMs := LGlobal.TimeoutMs;
  if not SameText(LProviderResolution.Values.ExecutorId, 'native') then
    LGlobalTimeoutMs := 15 * 60 * 1000;
  LGlobal := TRadIAExecutionSettings.Create(
    LGlobal.ProviderId,
    FConfig.GetActiveModel(LProviderResolution.Values.ProviderId),
    LGlobal.ExecutorId,
    LGlobal.MaxTokens,
    LGlobalTimeoutMs,
    LGlobal.TokenBudget
  );
  Result := TRadIAExecutionSettingsResolver.Resolve(
    LDefaults,
    LGlobal,
    LProject,
    LSession,
    LRequest
  );
end;

procedure TRadIAChatPresenter.ResetPendingRequestSettings;
begin
  FPendingRequestSettings := TRadIAExecutionSettings.Empty;
  FPendingRequestConversationId := '';
  FPendingRequestProjectId := '';
end;

function TRadIAChatPresenter.BuildExecutionSettingsStatus(
  const ASettings: TRadIAResolvedExecutionSettings
): string;
begin
  Result :=
    '### Effective execution settings' + sLineBreak + sLineBreak +
    '| Setting | Effective value | Source |' + sLineBreak +
    '|---|---|---|' + sLineBreak +
    '| Provider | `' + ASettings.Values.ProviderId + '` | ' +
      TRadIAExecutionSettingsResolver.OriginName(ASettings.ProviderOrigin) + ' |' + sLineBreak +
    '| Model | `' + ASettings.Values.ModelId + '` | ' +
      TRadIAExecutionSettingsResolver.OriginName(ASettings.ModelOrigin) + ' |' + sLineBreak +
    '| Executor | `' + ASettings.Values.ExecutorId + '` | ' +
      TRadIAExecutionSettingsResolver.OriginName(ASettings.ExecutorOrigin) + ' |' + sLineBreak +
    '| Maximum tokens | `' + ASettings.Values.MaxTokens.ToString + '` | ' +
      TRadIAExecutionSettingsResolver.OriginName(ASettings.MaxTokensOrigin) + ' |' + sLineBreak +
    '| Timeout (ms) | `' + ASettings.Values.TimeoutMs.ToString + '` | ' +
      TRadIAExecutionSettingsResolver.OriginName(ASettings.TimeoutOrigin) + ' |' + sLineBreak +
    '| Agent token budget | `' + ASettings.Values.TokenBudget.ToString + '` | ' +
      TRadIAExecutionSettingsResolver.OriginName(ASettings.TokenBudgetOrigin) + ' |' + sLineBreak +
    sLineBreak +
    'Use `/scope project|session|request <field> <value>` to override a value, or ' +
    '`/scope project|session|request inherit <field>` to restore inheritance.';
end;

function TRadIAChatPresenter.TryUpdateScopeSettings(
  const AScopeName: string;
  const AFieldName: string;
  const AValue: string;
  out AError: string
): Boolean;
var
  LCurrent: TRadIAExecutionSettings;
  LDefinition: TRadIACliDefinition;
  LField: TRadIAExecutionSettingField;
  LScopeId: string;
  LScopeKind: TRadIASettingsScopeKind;
  LUpdated: TRadIAExecutionSettings;
begin
  Result := False;
  AError := '';
  if not TRadIAExecutionSettingsEditor.TryParseField(AFieldName, LField) then
  begin
    AError := 'Unknown field. Use provider, model, executor, max-tokens, timeout-ms, or token-budget.';
    Exit;
  end;
  if (LField = resfProvider) and not TProviderRegistry.HasProvider(AValue) then
  begin
    AError := 'The provider is not registered: ' + AValue;
    Exit;
  end;
  if (LField = resfExecutor) and not SameText(AValue, 'native') and
    not TRadIACliCatalog.FindById(AValue, LDefinition) then
  begin
    AError := 'The executor is not supported: ' + AValue;
    Exit;
  end;
  if SameText(AScopeName, 'request') then
  begin
    Result := TRadIAExecutionSettingsEditor.TryUpdate(
      FPendingRequestSettings,
      LField,
      AValue,
      LUpdated,
      AError
    );
    if Result then
    begin
      FPendingRequestSettings := LUpdated;
      FPendingRequestConversationId := FSessionManager.ActiveSessionId;
      FPendingRequestProjectId := CurrentProjectId;
    end;
    Exit;
  end;
  if not Assigned(FHierarchicalSettingsStore) then
  begin
    AError := 'Hierarchical settings storage is unavailable.';
    Exit;
  end;
  if SameText(AScopeName, 'project') then
  begin
    LScopeKind := rssProject;
    LScopeId := CurrentProjectId;
  end
  else if SameText(AScopeName, 'session') then
  begin
    LScopeKind := rssSession;
    LScopeId := FSessionManager.ActiveSessionId;
  end
  else
  begin
    AError := 'Unknown scope. Use project, session, or request.';
    Exit;
  end;
  if LScopeId = '' then
  begin
    AError := 'The selected scope is unavailable. Open a project or chat session first.';
    Exit;
  end;
  LCurrent := FHierarchicalSettingsStore.Load(LScopeKind, LScopeId);
  Result := TRadIAExecutionSettingsEditor.TryUpdate(
    LCurrent,
    LField,
    AValue,
    LUpdated,
    AError
  );
  if Result then
    FHierarchicalSettingsStore.Save(LScopeKind, LScopeId, LUpdated);
end;

function TRadIAChatPresenter.TryClearScopeSettings(
  const AScopeName: string;
  const AFieldName: string;
  out AError: string
): Boolean;
var
  LCurrent: TRadIAExecutionSettings;
  LField: TRadIAExecutionSettingField;
  LScopeId: string;
  LScopeKind: TRadIASettingsScopeKind;
begin
  Result := False;
  AError := '';
  if (AFieldName <> '') and
    not TRadIAExecutionSettingsEditor.TryParseField(AFieldName, LField) then
  begin
    AError := 'Unknown field. Use provider, model, executor, max-tokens, timeout-ms, or token-budget.';
    Exit;
  end;
  if SameText(AScopeName, 'request') then
  begin
    if AFieldName = '' then
      ResetPendingRequestSettings
    else
      FPendingRequestSettings := TRadIAExecutionSettingsEditor.Clear(
        FPendingRequestSettings,
        LField
      );
    Exit(True);
  end;
  if not Assigned(FHierarchicalSettingsStore) then
  begin
    AError := 'Hierarchical settings storage is unavailable.';
    Exit;
  end;
  if SameText(AScopeName, 'project') then
  begin
    LScopeKind := rssProject;
    LScopeId := CurrentProjectId;
  end
  else if SameText(AScopeName, 'session') then
  begin
    LScopeKind := rssSession;
    LScopeId := FSessionManager.ActiveSessionId;
  end
  else
  begin
    AError := 'Unknown scope. Use project, session, or request.';
    Exit;
  end;
  if LScopeId = '' then
  begin
    AError := 'The selected scope is unavailable. Open a project or chat session first.';
    Exit;
  end;
  if AFieldName = '' then
    FHierarchicalSettingsStore.Clear(LScopeKind, LScopeId)
  else
  begin
    LCurrent := FHierarchicalSettingsStore.Load(LScopeKind, LScopeId);
    FHierarchicalSettingsStore.Save(
      LScopeKind,
      LScopeId,
      TRadIAExecutionSettingsEditor.Clear(LCurrent, LField)
    );
  end;
  Result := True;
end;

function TRadIAChatPresenter.TryHandleScopeCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
var
  LAction: string;
  LError: string;
  LField: string;
  LParts: TArray<string>;
  LScope: string;
  LValue: string;
begin
  Result := SameText(ACommandText, '/scope') or
    ACommandText.StartsWith('/scope ', True);
  if not Result then
    Exit;
  PostToWebView('add_message', 'user', APromptText);
  if SameText(ACommandText, '/scope') then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      BuildExecutionSettingsStatus(ResolveEffectiveExecutionSettings)
    );
    Exit;
  end;
  LParts := SplitString(
    Trim(Copy(ACommandText, Length('/scope') + 1, MaxInt)),
    ' '
  );
  if Length(LParts) < 2 then
  begin
    PostToWebView('add_message', 'assistant', 'Usage: /scope project|session|request ' +
      '<field> <value> | inherit <field> | clear');
    Exit;
  end;
  LScope := LParts[0];
  LAction := LParts[1];
  if SameText(LAction, 'clear') then
    TryClearScopeSettings(LScope, '', LError)
  else if SameText(LAction, 'inherit') then
  begin
    if Length(LParts) < 3 then
      LError := 'Specify the field that should inherit its value.'
    else
      TryClearScopeSettings(LScope, LParts[2], LError);
  end
  else if Length(LParts) < 3 then
    LError := 'Specify a value for the selected field.'
  else
  begin
    LField := LAction;
    LValue := string.Join(' ', LParts, 2, Length(LParts) - 2);
    TryUpdateScopeSettings(LScope, LField, LValue, LError);
  end;
  if LError <> '' then
    PostToWebView('add_message', 'assistant', '**Scope was not changed:** ' + LError)
  else
  begin
    PostExecutionRouteToWeb;
    UpdateModelsCombo;
    PostToWebView(
      'add_message',
      'assistant',
      BuildExecutionSettingsStatus(ResolveEffectiveExecutionSettings)
    );
  end;
end;

function TRadIAChatPresenter.TryHandleJourneyContextCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
var
  LJourneyId: string;
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  Result := SameText(ACommandText, '/context') or
    SameText(ACommandText, '/context new') or
    SameText(ACommandText, '/context detach') or
    ACommandText.StartsWith('/context switch ', True);
  if not Result then
    Exit;
  PostToWebView('add_message', 'user', APromptText);
  if not Assigned(FJourneyContext) then
  begin
    PostToWebView('add_message', 'assistant', 'Journey context is unavailable.');
    Exit;
  end;
  if SameText(ACommandText, '/context detach') then
  begin
    FJourneyContext.Detach(FSessionManager.ActiveSessionId);
    PostExecutionRouteToWeb;
    PostJourneyContextStatus;
    Exit;
  end;
  if ACommandText.StartsWith('/context switch ', True) then
  begin
    LJourneyId := Trim(Copy(
      ACommandText,
      Length('/context switch ') + 1,
      MaxInt
    ));
    if (LJourneyId = '') or
      not FJourneyContext.SwitchTo(LJourneyId, CurrentProjectId) or
      not FJourneyContext.TryGetByJourney(LJourneyId, LSnapshot) then
    begin
      PostToWebView(
        'add_message',
        'assistant',
        'Journey not found in the active project. Use `/context` to ' +
          'inspect the current link.'
      );
      Exit;
    end;
    SelectSession(LSnapshot.ConversationId);
    PostExecutionRouteToWeb;
    PostJourneyContextStatus;
    Exit;
  end;
  if SameText(ACommandText, '/context new') then
    FJourneyContext.Detach(FSessionManager.ActiveSessionId);
  SyncJourneyContext;
  PostExecutionRouteToWeb;
  PostJourneyContextStatus;
end;

procedure TRadIAChatPresenter.PostCliSessionStatus;
var
  LSession: TSessionInfo;
begin
  if FSessionManager.TryGetSession(
    FSessionManager.ActiveSessionId,
    LSession
  ) and (LSession.CliExternalSessionId <> '') then
    PostToWebView(
      'add_message',
      'assistant',
      'CLI conversation link: resume `' + LSession.CliExternalSessionId +
        '` with ' + LSession.CliClientId + '.'
    )
  else
    PostToWebView(
      'add_message',
      'assistant',
      'CLI conversation link: new session on the next external CLI request.'
    );
end;

function TRadIAChatPresenter.TryHandleCatalogCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
begin
  Result := True;
  if TryHandleDoctorCommand(APromptText, ACommandText) then
    Exit;
  if TryHandleScopeCommand(APromptText, ACommandText) then
    Exit;
  if TryHandleJourneyContextCommand(APromptText, ACommandText) then
    Exit;
  if TryHandleCliCommand(APromptText, ACommandText) then
    Exit;
  if SameText(ACommandText, '/help') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    PostToWebView('add_message', 'assistant', BuildHelpText);
    Exit;
  end;
  if SameText(ACommandText, '/terminal') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    FView.OpenTerminal;
    Exit;
  end;

  if SameText(ACommandText, '/settings') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    FView.OpenSettingsDialog;
    Exit;
  end;

  if SameText(ACommandText, '/extensions') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    FView.OpenExtensionManager;
    Exit;
  end;

  if SameText(ACommandText, '/health') then
  begin
    HandleExplicitToolCommand(
      APromptText,
      '/tool GetProjectHealth {}'
    );
    Exit;
  end;

  if TryHandleStatusCommand(APromptText, ACommandText) then
    Exit;

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

  if SameText(ACommandText, '/extensions reload') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    ReloadDeclarativeExtensions;
    PostToWebView(
      'add_message',
      'assistant',
      BuildDeclarativeExtensionStatus
    );
    SendInitialConfigToWeb;
    Exit;
  end;
  Result := False;
end;

function TRadIAChatPresenter.TryHandleStatusCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
const
  CFilters: array[0..11] of string = (
    'all',
    'provider',
    'agent',
    'cli',
    'mcp',
    'security',
    'editor',
    'project',
    'tools',
    'logging',
    'settings',
    'intent'
  );
var
  LAgentMode: string;
  LFilter: string;
  LKnownFilter: string;
  LValid: Boolean;
begin
  Result := SameText(ACommandText, '/status') or
    ACommandText.StartsWith('/status ', True);
  if not Result then
    Exit;
  LFilter := Trim(Copy(ACommandText, Length('/status') + 1, MaxInt));
  if SameText(LFilter, '--json') or LFilter.IsEmpty then
    LFilter := 'all';
  LValid := False;
  for LKnownFilter in CFilters do
    if SameText(LFilter, LKnownFilter) then
    begin
      LFilter := LKnownFilter;
      LValid := True;
      Break;
    end;
  if not LValid then
  begin
    PostToWebView('add_message', 'user', APromptText);
    PostToWebView(
      'add_message',
      'assistant',
      'Usage: /status [provider|agent|cli|mcp|security|editor|' +
      'project|tools|logging|settings|intent|--json]'
    );
    Exit;
  end;

  if SameText(LFilter, 'settings') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    PostToWebView(
      'add_message',
      'assistant',
      BuildExecutionSettingsStatus(ResolveEffectiveExecutionSettings)
    );
    Exit;
  end;
  if SameText(LFilter, 'intent') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    PostToWebView(
      'add_message',
      'assistant',
      TRadIAIntentTelemetry.SummaryJson
    );
    Exit;
  end;
  if FAgentModeEnabled then
    LAgentMode := 'true'
  else
    LAgentMode := 'false';
  HandleExplicitToolCommand(
    APromptText,
    '/tool GetRadIAStatus {"filter":"' + LFilter + '",' +
    '"agentModeEnabled":' + LAgentMode + '}'
  );
  if SameText(LFilter, 'all') or SameText(LFilter, 'cli') then
    PostCliSessionStatus;
  if SameText(LFilter, 'all') then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      BuildExecutionSettingsStatus(ResolveEffectiveExecutionSettings)
    );
    PostToWebView(
      'add_message',
      'assistant',
      TRadIAIntentTelemetry.SummaryJson
    );
  end;
end;

function TRadIAChatPresenter.TryHandleDoctorCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
begin
  Result := SameText(ACommandText, '/doctor') or
    SameText(ACommandText, '/doctor --deep');
  if not Result then
    Exit;
  if SameText(ACommandText, '/doctor --deep') then
    HandleExplicitToolCommand(
      APromptText,
      '/tool RunInstallationDeepDiagnostic {}'
    )
  else
    HandleExplicitToolCommand(
      APromptText,
      '/tool GetInstallationHealth {}'
    );
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
  if FPendingIntentActive then
  begin
    TRadIAIntentTelemetry.TryRecord(
      riteSuperseded,
      FPendingIntentName,
      FPendingIntentConfidence
    );
    ClearPendingIntent;
  end;
  if TryHandlePendingJourneyInput(APromptText) then
    Exit(True);
  if TryHandleIntentRecommendation(APromptText) then
    Exit(True);
  if TryHandleJourneyCommand(APromptText, LText) then
    Exit(True);
  if TryHandleAgentCommand(APromptText, LText) then
    Exit(True);
  if TryHandleCatalogCommand(APromptText, LText) then
    Exit(True);
  Result := SameText(LText, '/tool') or
    LText.StartsWith('/tool ', True);
  if Result then
    HandleExplicitToolCommand(APromptText, LText);
end;

procedure TRadIAChatPresenter.ResetPendingJourney;
begin
  FPendingJourneyActive := False;
  FPendingJourneyContext := '';
  FPendingJourneyDeclarativePrompt := '';
  FPendingJourneyField := '';
  FPendingJourneyNative := False;
end;

procedure TRadIAChatPresenter.AskForPendingJourneyInput(
  const AQuestion: string
);
begin
  PostToWebView(
    'add_message',
    'assistant',
    AQuestion + sLineBreak + sLineBreak +
    'Reply with the requested value, or type /journey cancel to abandon this journey.'
  );
end;

procedure TRadIAChatPresenter.StartPendingJourney;
var
  LObjective: string;
begin
  if FPendingJourneyNative then
    LObjective := FPendingJourneyDefinition.BuildAgentObjective(
      FPendingJourneyContext
    )
  else
    LObjective := FPendingJourneyDeclarativePrompt + sLineBreak + sLineBreak +
      'User-provided context: ' + FPendingJourneyContext;
  ResetPendingJourney;
  if not FAgentModeEnabled then
    SetAgentModeEnabled(True);
  StartAgentRun(LObjective);
end;

function TRadIAChatPresenter.TryHandlePendingJourneyInput(
  const APromptText: string
): Boolean;
var
  LAnswer: string;
  LField: string;
  LQuestion: string;
begin
  Result := FPendingJourneyActive;
  if not Result then
    Exit;
  LAnswer := Trim(APromptText);
  if SameText(LAnswer, '/journey cancel') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    ResetPendingJourney;
    PostToWebView(
      'add_message',
      'assistant',
      'Journey abandoned. Collected input was discarded.'
    );
    Exit;
  end;
  if LAnswer.StartsWith('/journey ', True) then
  begin
    ResetPendingJourney;
    Exit(False);
  end;
  PostToWebView('add_message', 'user', APromptText);
  if FPendingJourneyField = 'goal' then
    FPendingJourneyContext := LAnswer
  else
  begin
    if not FPendingJourneyContext.IsEmpty then
      FPendingJourneyContext := FPendingJourneyContext + ' ';
    FPendingJourneyContext := FPendingJourneyContext +
      FPendingJourneyField + '="' + LAnswer.Replace('"', '''') + '"';
  end;
  if FPendingJourneyNative and
    FPendingJourneyDefinition.NextRequiredInput(
      FPendingJourneyContext,
      LField,
      LQuestion
    ) then
  begin
    FPendingJourneyField := LField;
    AskForPendingJourneyInput(LQuestion);
    Exit;
  end;
  StartPendingJourney;
end;

function TRadIAChatPresenter.TryBeginJourneyIntake(
  const AIsNative: Boolean;
  const ADefinition: TRadIAJourneyDefinition;
  const ADeclarative: TRadIADeclarativeCommand;
  const AContext: string
): Boolean;
var
  LContext: string;
  LField: string;
  LQuestion: string;
begin
  LContext := AContext;
  if AIsNative and SameText(ADefinition.Command, '/journey create') then
    LContext := TRadIAJourneyCatalog.NormalizeCreateContext(AContext);
  Result := AIsNative and ADefinition.NextRequiredInput(
    LContext,
    LField,
    LQuestion
  );
  if Result then
  begin
    FPendingJourneyActive := True;
    FPendingJourneyContext := LContext;
    FPendingJourneyDefinition := ADefinition;
    FPendingJourneyField := LField;
    FPendingJourneyNative := True;
    AskForPendingJourneyInput(LQuestion);
    Exit;
  end;
  Result := not AIsNative and AContext.Trim.IsEmpty;
  if not Result then
    Exit;
  FPendingJourneyActive := True;
  FPendingJourneyContext := '';
  FPendingJourneyDeclarativePrompt := ADeclarative.Prompt + sLineBreak +
    sLineBreak + 'Mandatory RadIA safety gates:' + sLineBreak +
    '- Inspect the active workspace before proposing changes.' + sLineBreak +
    '- Present a reviewable plan before the first tool call.' + sLineBreak +
    '- Use only registered tools through central consent and auditing.' + sLineBreak +
    '- Preview mutations and preserve independent rollback evidence.' + sLineBreak +
    '- Build and run focused tests before claiming completion.';
  FPendingJourneyField := 'goal';
  FPendingJourneyNative := False;
  AskForPendingJourneyInput(
    'Describe the goal, scope, constraints, and expected result for this journey.'
  );
end;

function TRadIAChatPresenter.TryHandleJourneyCommand(
  const APromptText: string;
  const ACommandText: string
): Boolean;
var
  LContext: string;
  LDeclarative: TRadIADeclarativeCommand;
  LDefinition: TRadIAJourneyDefinition;
  LIsNativeJourney: Boolean;
  LObjective: string;
begin
  Result := True;
  if SameText(ACommandText, '/journey cancel') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    PostToWebView('add_message', 'assistant', 'There is no journey input in progress.');
    Exit;
  end;
  if SameText(ACommandText, '/journey') then
  begin
    PostToWebView('add_message', 'user', APromptText);
    PostToWebView(
      'add_message',
      'assistant',
      TRadIAJourneyCatalog.HelpText
    );
    Exit;
  end;
  try
    LIsNativeJourney := TRadIAJourneyCatalog.Resolve(
      ACommandText,
      LDefinition,
      LContext
    );
    if LIsNativeJourney and
      SameText(LDefinition.Command, '/journey create') then
      LContext := TRadIAJourneyCatalog.NormalizeCreateContext(LContext);
    if not LIsNativeJourney then
    begin
      ReloadDeclarativeExtensions;
      if not FDeclarativeExtensionManager.TryResolveInput(
        ACommandText,
        LDeclarative,
        LContext
      ) or not SameText(LDeclarative.Kind, 'journey') then
        Exit(False);
    end;
  except
    on E: EArgumentException do
    begin
      PostToWebView('add_message', 'user', APromptText);
      PostToWebView('add_message', 'assistant', E.Message);
      Exit;
    end;
  end;
  PostUserMessageIfPresent(APromptText);
  if TryBeginJourneyIntake(
    LIsNativeJourney,
    LDefinition,
    LDeclarative,
    LContext
  ) then
    Exit;
  if not FAgentModeEnabled then
    SetAgentModeEnabled(True);
  if LIsNativeJourney then
    LObjective := LDefinition.BuildAgentObjective(LContext)
  else
  begin
    LObjective := LDeclarative.Prompt + sLineBreak + sLineBreak +
      'Mandatory RadIA safety gates:' + sLineBreak +
      '- Inspect the active workspace before proposing changes.' + sLineBreak +
      '- Present a reviewable plan before the first tool call.' + sLineBreak +
      '- Use only registered tools through central consent and auditing.' + sLineBreak +
      '- Preview mutations and preserve independent rollback evidence.' + sLineBreak +
      '- Build and run focused tests before claiming completion.';
    if not LContext.IsEmpty then
      LObjective := LObjective + sLineBreak + sLineBreak +
        'User-provided context: ' + LContext;
  end;
  StartAgentRun(LObjective);
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
                begin
                  Self.PostDirectToolResultToWeb(AName, LResultJson);
                end;
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

procedure TRadIAChatPresenter.PostDirectToolResultToWeb(
  const AName: string;
  const AResultJson: string
);
begin
  FView.PostMessageToWeb(AResultJson);
  if SameText(AName, 'CaptureRuntimeVisual') or
    SameText(AName, 'RunRuntimeScenario') then
    PostVisualRuntimeSessionToWeb;
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
  if SameText(AName, 'CaptureRuntimeVisual') and AResult.Success then
    PostVisualRuntimeSessionToWeb;
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
  PostExecutionRouteToWeb;
  UpdateModelsCombo;
end;

procedure TRadIAChatPresenter.SetAgentExecutor(const AExecutorId: string);
var
  LCurrent: TRadIAAgentExecutorSettings;
  LDefinition: TRadIACliDefinition;
begin
  if FRequestInProgress then
    Exit;
  LCurrent := FAgentExecutorSettings.Load;
  if SameText(AExecutorId, 'native') then
    FAgentExecutorSettings.Save(
      TRadIAAgentExecutorSettings.Create(
        aekNative,
        LCurrent.CliClientId,
        LCurrent.ReasoningEffort
      )
    )
  else if TRadIACliCatalog.FindById(AExecutorId, LDefinition) then
    FAgentExecutorSettings.Save(
      TRadIAAgentExecutorSettings.Create(
        aekCli,
        LDefinition.Id,
        LCurrent.ReasoningEffort
      )
    )
  else
  begin
    PostToWebView('add_message', 'assistant', 'The selected executor is not supported.');
    Exit;
  end;
  if Assigned(FJourneyContext) then
    FJourneyContext.UpdateExecutor(CurrentExecutorId);
  PostExecutionRouteToWeb;
  UpdateModelsCombo;
end;

procedure TRadIAChatPresenter.SetReasoningEffort(const AEffort: string);
var
  LCurrent: TRadIAAgentExecutorSettings;
begin
  if FRequestInProgress then
    Exit;
  LCurrent := FAgentExecutorSettings.Load;
  try
    FAgentExecutorSettings.Save(
      TRadIAAgentExecutorSettings.Create(
        LCurrent.Kind,
        LCurrent.CliClientId,
        AEffort
      )
    );
    SendInitialConfigToWeb;
  except
    on E: EArgumentException do
      PostToWebView('add_message', 'assistant', E.Message);
  end;
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
        if Assigned(FJourneyContext) then
          FJourneyContext.CompleteActivity;
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
        if AResult.Status <> asAwaitingApproval then
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
          PostVisualRuntimeSessionToWeb;
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
  if Assigned(FJourneyContext) then
    FJourneyContext.BeginActivity;
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
  if Assigned(FJourneyContext) then
    FJourneyContext.BeginActivity;
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
  LEffectiveSettings: TRadIAResolvedExecutionSettings;
  LGuard: IRadIALifecycleGuard;
  LAgentTokenLimit: Integer;
  LAgentMaxSteps: Integer;
  LLimits: TRadIAAgentLimits;
  LProviderSettings: TRadIAAgentProviderSettings;
  LProject: TRadIAProjectSnapshot;
  LProjectId: string;
  LResultCompactor: IRadIAResultCompactor;
  LResultStore: IRadIAAgentResultStore;
  LSessionId: string;
  LStore: IRadIAAgentCheckpointStore;
  LUserMessage: IRadIAChatMessage;
begin
  LEffectiveSettings := ResolveEffectiveExecutionSettings;
  if TryStartCliAgentRun(AObjective, LEffectiveSettings) then
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

  LActiveProvider := LEffectiveSettings.Values.ProviderId;
  LActiveModel := LEffectiveSettings.Values.ModelId;
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
  LAgentTokenLimit := ResolveScopedAgentTokenLimit(LEffectiveSettings);
  LAgentMaxSteps := 20;
  if AObjective.Contains(
    'Create a Delphi project from the user requirements.'
  ) then
    LAgentMaxSteps := 40;
  ResolveAgentRuntimeSettings(
    LActiveProvider,
    LActiveModel,
    LAgentTokenLimit,
    LAgentMaxSteps,
    LProviderSettings,
    LLimits
  );
  LDecisionProvider := TRadIAAgentServiceDecisionProvider.Create(
    FAIService,
    FHistory,
    LProviderSettings
  );
  LCheckpointDirectory := TPath.Combine(FDataDir, 'agent-checkpoints');
  LStore := TRadIAAgentFileCheckpointStore.Create(LCheckpointDirectory);
  if not TRadIAContainer.TryResolve<IRadIAResultCompactor>(LResultCompactor) then
    LResultCompactor := TRadIAResultCompactor.Create;
  if not TRadIAContainer.TryResolve<IRadIAAgentResultStore>(LResultStore) then
    LResultStore := TRadIAAgentFileResultStore.Create(
      TPath.Combine(FDataDir, 'agent-results')
    );
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
    end,
    LResultCompactor,
    LResultStore
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
  if Assigned(FJourneyContext) then
    FJourneyContext.BeginActivity;
  FCancelledByUser := False;
  FView.SetRequestState(True);
  ResetPendingRequestSettings;
  FAgentController.Start(
    AObjective,
    LSessionId,
    LProjectId,
    LLimits
  );
end;

function TRadIAChatPresenter.GetAgentTokenLimit: Integer;
var
  LRemainingQuota: Int64;
begin
  Result := 0;
  if not FConfig.QuotaEnabled then
    Exit;
  LRemainingQuota := FConfig.QuotaLimit - FConfig.QuotaUsed;
  if LRemainingQuota > 1000000 then
    Result := 1000000
  else if LRemainingQuota > 0 then
    Result := Integer(LRemainingQuota);
end;

procedure TRadIAChatPresenter.ResolveAgentRuntimeSettings(
  const AProvider: string;
  const AModel: string;
  const ATokenLimit: Integer;
  const AMaxSteps: Integer;
  out AProviderSettings: TRadIAAgentProviderSettings;
  out ALimits: TRadIAAgentLimits
);
var
  LPricing: TRadIAAgentPricing;
  LPricingCatalog: TRadIAAgentPricingCatalog;
  LResultSettings: TRadIAResultCompactionSettings;
  LResultSettingsStore: TRadIAResultCompactionSettingsStore;
begin
  LResultSettingsStore := TRadIAResultCompactionSettingsStore.Create;
  try
    LResultSettings := LResultSettingsStore.Load;
  finally
    LResultSettingsStore.Free;
  end;
  LPricingCatalog := TRadIAAgentPricingCatalog.Create(
    TPath.Combine(FDataDir, 'agent-pricing.json')
  );
  try
    if LPricingCatalog.TryResolve(AProvider, AModel, LPricing) then
    begin
      AProviderSettings := TRadIAAgentProviderSettings.WithPricing(
        BuildAgentToolCatalogJson,
        LPricing
      );
      ALimits := TRadIAAgentLimits.Create(
        AMaxSteps,
        3,
        15 * 60 * 1000,
        ATokenLimit,
        LPricingCatalog.DefaultRunBudgetMicros,
        LResultSettings.MaximumDecisionContextCharacters
      );
      Exit;
    end;
    AProviderSettings := TRadIAAgentProviderSettings.Default(
      BuildAgentToolCatalogJson
    );
    ALimits := TRadIAAgentLimits.Create(
      AMaxSteps,
      3,
      15 * 60 * 1000,
      ATokenLimit,
      0,
      LResultSettings.MaximumDecisionContextCharacters
    );
  finally
    LPricingCatalog.Free;
  end;
end;

function TRadIAChatPresenter.BuildConversationalCliPrompt(
  const APromptText: string
): string;
begin
  Result :=
    'You are RadIA, the AI assistant integrated into RAD Studio for Delphi development. ' +
    'Answer the user directly in the user''s language. This is a conversational request: ' +
    'do not inspect files, run commands, create a plan, or describe yourself as the CLI executor.' +
    sLineBreak + sLineBreak +
    'User message:' + sLineBreak + APromptText;
end;

function TRadIAChatPresenter.TryStartCliAgentRun(
  const AObjective: string;
  const ASettings: TRadIAResolvedExecutionSettings;
  const AConversational: Boolean
): Boolean;
var
  LDefinition: TRadIACliDefinition;
  LDetection: TRadIACliDetection;
  LExternalSessionId: string;
  LGuard: IRadIALifecycleGuard;
  LInvocation: TRadIACliInvocation;
  LPrompt: string;
  LProject: TRadIAProjectSnapshot;
  LSession: TSessionInfo;
  LSessionId: string;
  LTimeoutMs: Integer;
  LReasoningEffort: string;
  LUserMessage: IRadIAChatMessage;
  LWorkingDirectory: string;
begin
  Result := not SameText(ASettings.Values.ExecutorId, 'native');
  if not Result then
    Exit;
  if not CheckQuotaAvailability then
    Exit;
  if not TRadIACliCatalog.FindById(ASettings.Values.ExecutorId, LDefinition) then
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
  LWorkingDirectory := TRadIACliWorkspace.Resolve(
    LProject.FileName,
    FDataDir
  );

  LDetection := TRadIACliResolver.Resolve(LDefinition.Id);
  if not LDetection.Installed then
  begin
    PostToWebView(
      'add_message',
      'assistant',
      LDefinition.DisplayName +
        ' was not found. Expected executable: `' +
        TRadIACliResolver.ExpectedExecutablePath(LDefinition.Id) +
        '`. Open Settings > CLI & MCP to diagnose it or select another path with Browse.'
    );
    Exit;
  end;

  LExternalSessionId := '';
  LSessionId := FSessionManager.ActiveSessionId;
  if not AConversational and
    FSessionManager.TryGetSession(LSessionId, LSession) and
    SameText(LSession.CliClientId, LDefinition.Id) and
    SameText(LSession.CliWorkingDirectory, LWorkingDirectory) then
    LExternalSessionId := LSession.CliExternalSessionId;
  LPrompt := AObjective;
  LReasoningEffort := FAgentExecutorSettings.Load.ReasoningEffort;
  if AConversational then
  begin
    LPrompt := BuildConversationalCliPrompt(AObjective);
    LReasoningEffort := 'low';
  end;
  LInvocation := TRadIACliInvocationBuilder.Build(
    LDefinition,
    LDetection.ExecutablePath,
    LPrompt,
    LWorkingDirectory,
    LExternalSessionId,
    LReasoningEffort
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
  if Assigned(FJourneyContext) then
    FJourneyContext.BeginActivity;
  FCancelledByUser := False;
  FView.SetRequestState(True);
  ResetPendingRequestSettings;
  PostCliActivity(
    'started',
    'Preparing the CLI workspace and starting the requested task.',
    LDefinition.DisplayName,
    LWorkingDirectory
  );
  LGuard := FLifecycleGuard as IRadIALifecycleGuard;
  LTimeoutMs := ASettings.Values.TimeoutMs;
  if LTimeoutMs < 1 then
    LTimeoutMs := 15 * 60 * 1000;
  FCliProcessSession := TRadIACliProcessRunner.Start(
    LInvocation,
    LTimeoutMs,
    TProc<string>(
    procedure(const AChunk: string)
    begin
      QueueOnUI(
        procedure
        begin
          PostCliActivity(
            'output',
            AChunk,
            LDefinition.DisplayName,
            LWorkingDirectory
          );
        end
      );
    end),
    TProc<string>(
    procedure(const AChunk: string)
    begin
      QueueOnUI(
        procedure
        begin
          PostCliActivity(
            'warning',
            AChunk,
            LDefinition.DisplayName,
            LWorkingDirectory
          );
        end
      );
    end),
    procedure(AResult: TRadIACliProcessResult)
    begin
      TThread.ForceQueue(
        nil,
        TThreadProcedure(
        procedure
        begin
          if LGuard.IsAlive then
            Self.HandleCliAgentFinished(
              AResult,
              LDefinition,
              LSessionId,
              LWorkingDirectory,
              LExternalSessionId <> ''
            );
        end)
      );
    end
  );
end;

procedure TRadIAChatPresenter.HandleCliAgentFinished(
  const AResult: TRadIACliProcessResult;
  const ADefinition: TRadIACliDefinition;
  const ALocalSessionId: string;
  const AWorkingDirectory: string;
  const AWasResumed: Boolean
);
var
  LHistory: TArray<IRadIAChatMessage>;
  LIsActiveSession: Boolean;
  LMessage: IRadIAChatMessage;
  LModelLabel: string;
  LResponse: string;
begin
  FCliProcessSession := nil;
  FRequestInProgress := False;
  CompleteJourneyActivity;
  FView.SetRequestState(False);
  PostCliCompletionActivity(AResult, ADefinition, AWorkingDirectory);
  LResponse := BuildCliAgentResponse(
    AResult,
    ADefinition,
    ALocalSessionId,
    AWorkingDirectory
  );
  if AWasResumed then
    LModelLabel := 'CLI resumed'
  else
    LModelLabel := 'CLI new session';
  LMessage := TRadIAChatMessage.CreateMessage(
    mrAssistant,
    LResponse,
    ADefinition.DisplayName,
    LModelLabel
  );
  LIsActiveSession := SameText(
    FSessionManager.ActiveSessionId,
    ALocalSessionId
  );
  if LIsActiveSession then
  begin
    FHistory := FHistory + [LMessage];
    SaveChatHistory;
    PostToWebView(
      'add_message',
      'assistant',
      LResponse,
      ADefinition.DisplayName,
      LModelLabel
    );
    PostExecutionRouteToWeb;
  end
  else
  begin
    LHistory := FSessionManager.LoadSessionHistory(ALocalSessionId);
    LHistory := LHistory + [LMessage];
    FSessionManager.SaveSessionHistory(ALocalSessionId, LHistory);
  end;
end;

procedure TRadIAChatPresenter.PostCliCompletionActivity(
  const AResult: TRadIACliProcessResult;
  const ADefinition: TRadIACliDefinition;
  const AWorkingDirectory: string
);
var
  LMessage: string;
  LPhase: string;
begin
  LPhase := 'failed';
  if AResult.Cancelled or FCancelledByUser then
  begin
    LPhase := 'cancelled';
    LMessage := 'CLI execution was cancelled.';
  end
  else if AResult.TimedOut then
    LMessage := 'CLI execution exceeded its configured time limit.'
  else if AResult.Succeeded then
  begin
    LPhase := 'completed';
    LMessage := 'CLI execution completed.';
  end
  else
    LMessage := 'CLI execution failed. Expand the activity log for details.';
  PostCliActivity(LPhase, LMessage, ADefinition.DisplayName, AWorkingDirectory);
end;

function TRadIAChatPresenter.BuildCliAgentResponse(
  const AResult: TRadIACliProcessResult;
  const ADefinition: TRadIACliDefinition;
  const ALocalSessionId: string;
  const AWorkingDirectory: string
): string;
var
  LExternalSessionId: string;
begin
  if AResult.Cancelled or FCancelledByUser then
    Exit('CLI execution was cancelled.');
  if AResult.TimedOut then
    Exit('CLI execution exceeded the 15-minute limit.');
  if not AResult.Succeeded then
  begin
    Result := Trim(AResult.StdErr);
    if Result = '' then
      Result := Trim(AResult.StdOut);
    if Result = '' then
      Result := Format('CLI execution failed with exit code %d.', [AResult.ExitCode]);
    Exit;
  end;
  Result := TRadIACliOutputParser.ExtractFinalText(AResult.StdOut);
  if TRadIACliOutputParser.TryExtractSessionId(
    ADefinition.Kind,
    AResult.StdOut,
    LExternalSessionId
  ) then
    FSessionManager.SetCliConversation(
      ALocalSessionId,
      ADefinition.Id,
      LExternalSessionId,
      AWorkingDirectory,
      ''
    );
end;

function TRadIAChatPresenter.TryHandleIntentRecommendation(
  const APromptText: string
): Boolean;
var
  LRecommendation: TRadIAIntentRecommendation;
begin
  Result := TRadIAIntentRouter.TryRecommend(
    APromptText,
    LRecommendation
  );
  if not Result then
    Exit;
  FPendingIntentActive := True;
  FPendingIntentCommand := LRecommendation.Command;
  FPendingIntentConfidence := LRecommendation.ConfidenceName;
  FPendingIntentName := LRecommendation.IntentName;
  FPendingIntentPrompt := APromptText;
  TRadIAIntentTelemetry.TryRecord(
    riteRecommended,
    FPendingIntentName,
    FPendingIntentConfidence
  );
  PostToWebView('add_message', 'user', APromptText);
  PostIntentRecommendation(LRecommendation);
end;

procedure TRadIAChatPresenter.PostIntentRecommendation(
  const ARecommendation: TRadIAIntentRecommendation
);
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'intent_recommendation');
    LJson.AddPair('intent', ARecommendation.IntentName);
    LJson.AddPair('confidence', ARecommendation.ConfidenceName);
    LJson.AddPair('route', ARecommendation.Route);
    LJson.AddPair('command', ARecommendation.Command);
    LJson.AddPair('explanation', ARecommendation.Explanation);
    PostJsonToWeb(LJson);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.PostUserMessageIfPresent(const AText: string);
begin
  if not AText.IsEmpty then
    PostToWebView('add_message', 'user', AText);
end;

procedure TRadIAChatPresenter.HandleIntentRecommendation(
  const AAction: string
);
var
  LCommand: string;
begin
  if not FPendingIntentActive then
  begin
    PostToWebView('add_message', 'assistant', 'This route recommendation is no longer active.');
    Exit;
  end;
  if AAction = 'review_intent_recommendation' then
  begin
    TRadIAIntentTelemetry.TryRecord(
      riteReviewed,
      FPendingIntentName,
      FPendingIntentConfidence
    );
    FView.SetPromptInput(FPendingIntentCommand);
    FView.FocusPromptInput;
    Exit;
  end;
  if AAction = 'dismiss_intent_recommendation' then
  begin
    SendPendingIntentToChat;
    Exit;
  end;
  LCommand := FPendingIntentCommand;
  TRadIAIntentTelemetry.TryRecord(
    riteAccepted,
    FPendingIntentName,
    FPendingIntentConfidence
  );
  ClearPendingIntent;
  TryHandleJourneyCommand('', LCommand);
end;

procedure TRadIAChatPresenter.ClearPendingIntent;
begin
  FPendingIntentActive := False;
  FPendingIntentCommand := '';
  FPendingIntentConfidence := '';
  FPendingIntentName := '';
  FPendingIntentPrompt := '';
end;

procedure TRadIAChatPresenter.SendPendingIntentToChat;
var
  LEffectiveSettings: TRadIAResolvedExecutionSettings;
  LPreflightMessage: string;
  LProcessed: string;
  LPrompt: string;
begin
  LPrompt := FPendingIntentPrompt;
  TRadIAIntentTelemetry.TryRecord(
    riteChatFallback,
    FPendingIntentName,
    FPendingIntentConfidence
  );
  ClearPendingIntent;
  EnsureJourneyProjectBoundary;
  LProcessed := PreProcessPrompt(LPrompt);
  LEffectiveSettings := ResolveEffectiveExecutionSettings;
  if not CheckChatPreflight(LEffectiveSettings, LPreflightMessage) then
  begin
    ShowChatPreflightFailure(LPrompt, LPreflightMessage);
    Exit;
  end;
  if TryStartCliAgentRun(LProcessed, LEffectiveSettings) then
    Exit;
  SendPromptToAI(LProcessed);
end;

procedure TRadIAChatPresenter.PostCliActivity(
  const APhase: string;
  const AText: string;
  const ACliName: string;
  const AWorkingDirectory: string
);
const
  CMaximumActivityChunk = 16384;
var
  LJson: TJSONObject;
  LText: string;
begin
  LText := AText;
  if Length(LText) > CMaximumActivityChunk then
    LText := LText.Substring(0, CMaximumActivityChunk);
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'cli_activity');
    LJson.AddPair('phase', APhase);
    LJson.AddPair('text', LText);
    LJson.AddPair('cli', ACliName);
    LJson.AddPair('workingDirectory', AWorkingDirectory);
    PostJsonToWeb(LJson);
  finally
    LJson.Free;
  end;
end;

function TRadIAChatPresenter.BuildVisualRuntimeSessionJson(
  const ASnapshot: TRadIAVisualSessionSnapshot
): TJSONObject;
var
  LCapture: TRadIAVisualCapture;
  LCaptureArray: TJSONArray;
  LCaptureJson: TJSONObject;
  LEvent: TRadIAVisualSessionEvent;
  LEventArray: TJSONArray;
  LEventJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('action', 'visual_runtime_session');
  Result.AddPair('sessionId', ASnapshot.Session.SessionId);
  Result.AddPair('state', RadIAVisualSessionStateName(ASnapshot.State));
  LEventArray := TJSONArray.Create;
  Result.AddPair('events', LEventArray);
  for LEvent in ASnapshot.Events do
  begin
    LEventJson := TJSONObject.Create;
    LEventJson.AddPair('sequence', TJSONNumber.Create(LEvent.Sequence));
    LEventJson.AddPair('kind', RadIAVisualSessionEventKindName(LEvent.Kind));
    LEventJson.AddPair('actionIndex', TJSONNumber.Create(LEvent.ActionIndex));
    LEventJson.AddPair('status', LEvent.Status);
    LEventJson.AddPair('details', LEvent.Details);
    LEventArray.AddElement(LEventJson);
  end;
  LCaptureArray := TJSONArray.Create;
  Result.AddPair('captures', LCaptureArray);
  for LCapture in ASnapshot.Captures do
  begin
    LCaptureJson := TJSONObject.Create;
    LCaptureJson.AddPair('captureId', LCapture.CaptureId);
    LCaptureJson.AddPair('phase', RadIAVisualCapturePhaseName(LCapture.Phase));
    LCaptureJson.AddPair('mimeType', LCapture.MimeType);
    LCaptureJson.AddPair('width', TJSONNumber.Create(LCapture.Width));
    LCaptureJson.AddPair('height', TJSONNumber.Create(LCapture.Height));
    LCaptureJson.AddPair(
      'dataUrl',
      'data:image/png;base64,' +
      TNetEncoding.Base64.EncodeBytesToString(LCapture.Bytes)
    );
    LCaptureArray.AddElement(LCaptureJson);
  end;
end;

procedure TRadIAChatPresenter.PostVisualRuntimeSessionToWeb;
var
  LJson: TJSONObject;
  LLastSequence: Int64;
  LSnapshot: TRadIAVisualSessionSnapshot;
begin
  if not Assigned(FVisualRuntimeSession) or
    not FVisualRuntimeSession.TryGetSnapshot(LSnapshot) then
    Exit;
  LLastSequence := 0;
  if Length(LSnapshot.Events) > 0 then
    LLastSequence := LSnapshot.Events[High(LSnapshot.Events)].Sequence;
  if SameText(FLastVisualSessionId, LSnapshot.Session.SessionId) and
    (FLastVisualSequence = LLastSequence) then
    Exit;
  LJson := BuildVisualRuntimeSessionJson(LSnapshot);
  try
    PostJsonToWeb(LJson);
    FLastVisualSessionId := LSnapshot.Session.SessionId;
    FLastVisualSequence := LLastSequence;
  finally
    LJson.Free;
  end;
end;

function TRadIAChatPresenter.ResolveScopedAgentTokenLimit(
  const ASettings: TRadIAResolvedExecutionSettings
): Integer;
begin
  if ASettings.Values.TokenBudget > MaxInt then
    Result := MaxInt
  else
    Result := Integer(ASettings.Values.TokenBudget);
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

procedure TRadIAChatPresenter.ResolveExecutionRoute(
  const AProvider: string;
  const AAuthType: string;
  const ASettings: TRadIAAgentExecutorSettings;
  out AMode: string;
  out AOrchestrator: string;
  out ATransport: string;
  out ADisplayName: string
);
begin
  AMode := 'chat';
  AOrchestrator := 'none';
  ATransport := 'native';
  ADisplayName := 'Native';

  if SameText(AAuthType, 'api_key') then
    ADisplayName := 'Native API';

  if SameText(AProvider, 'OpenAI') and SameText(AAuthType, 'oauth_cli') then
  begin
    ATransport := 'codex-cli';
    ADisplayName := 'ChatGPT Pro via Codex CLI';
  end;

  if FAgentModeEnabled then
  begin
    AMode := 'agent';
    AOrchestrator := 'radia-native';
  end;

  if ASettings.Kind = aekCli then
  begin
    AOrchestrator := 'external-cli';
    ATransport := ASettings.CliClientId + '-cli';
    ADisplayName := ASettings.CliClientId + ' CLI';
  end;
end;

function TRadIAChatPresenter.BuildExecutionRouteLabel(
  const AMode: string;
  const AOrchestrator: string;
  const ATransport: string;
  const AProvider: string;
  const ACliClientId: string
): string;
begin
  if AMode = 'chat' then
  begin
    if AOrchestrator = 'external-cli' then
      Exit('Chat | ' + ACliClientId + ' CLI direct');
    if ATransport = 'codex-cli' then
      Exit('Chat | RadIA native | ChatGPT Pro via Codex CLI');
    Exit('Chat | ' + AProvider + ' native');
  end
  else if AOrchestrator = 'external-cli' then
    Result := 'Agent | ' + ACliClientId + ' CLI direct'
  else if ATransport = 'codex-cli' then
    Result := 'Agent | RadIA native | ChatGPT Pro via Codex CLI'
  else
    Result := 'Agent | RadIA native | ' + AProvider;
end;

function TRadIAChatPresenter.BuildExecutionRouteJson: TJSONObject;
var
  LAuthType: string;
  LActivityState: string;
  LCliClientId: string;
  LDetails: string;
  LDisplayName: string;
  LEffective: TRadIAResolvedExecutionSettings;
  LLabel: string;
  LJourney: TRadIAJourneyContextSnapshot;
  LJourneyId: string;
  LJourneyState: string;
  LMode: string;
  LOrchestrator: string;
  LProvider: string;
  LSession: TSessionInfo;
  LSessionState: string;
  LSettings: TRadIAAgentExecutorSettings;
  LTransport: string;
begin
  LEffective := ResolveEffectiveExecutionSettings;
  LProvider := LEffective.Values.ProviderId;
  LAuthType := FConfig.GetProviderAuthType(LProvider);
  if SameText(LEffective.Values.ExecutorId, 'native') then
    LSettings := TRadIAAgentExecutorSettings.Create(aekNative, '')
  else
    LSettings := TRadIAAgentExecutorSettings.Create(
      aekCli,
      LEffective.Values.ExecutorId
    );
  LCliClientId := LSettings.CliClientId;
  LSessionState := 'new';
  LJourneyId := '';
  LJourneyState := 'detached';
  LActivityState := 'idle';
  if Assigned(FJourneyContext) and FJourneyContext.TryGetForConversation(
    FSessionManager.ActiveSessionId,
    LJourney
  ) and LJourney.MatchesProject(CurrentProjectId) then
  begin
    LJourneyId := LJourney.JourneyId;
    LJourneyState := 'linked';
    case LJourney.State of
      jasRunning:
        LActivityState := 'running';
      jasCancellationRequested:
        LActivityState := 'cancelling';
    end;
  end;
  if FSessionManager.TryGetSession(
    FSessionManager.ActiveSessionId,
    LSession
  ) and SameText(LSession.CliClientId, LCliClientId) and
    (LSession.CliExternalSessionId <> '') then
    LSessionState := 'resume';
  ResolveExecutionRoute(
    LProvider,
    LAuthType,
    LSettings,
    LMode,
    LOrchestrator,
    LTransport,
    LDisplayName
  );
  LLabel := BuildExecutionRouteLabel(
    LMode,
    LOrchestrator,
    LTransport,
    LProvider,
    LCliClientId
  );

  LDetails := 'Mode: ' + LMode + '. Orchestrator: ' + LOrchestrator +
    '. Provider transport: ' + LTransport +
    '. CLI session: ' + LSessionState +
    '. Journey: ' + LJourneyState +
    '. Journey activity: ' + LActivityState +
    '. Provider source: ' + TRadIAExecutionSettingsResolver.OriginName(
      LEffective.ProviderOrigin
    ) +
    '. Executor source: ' + TRadIAExecutionSettingsResolver.OriginName(
      LEffective.ExecutorOrigin
    ) +
    '. MCP is a separate external tool bridge and is not this chat route.';
  Result := TJSONObject.Create;
  Result.AddPair('label', LLabel);
  Result.AddPair('displayName', LDisplayName);
  Result.AddPair('details', LDetails);
  Result.AddPair('mode', LMode);
  Result.AddPair('orchestrator', LOrchestrator);
  Result.AddPair('transport', LTransport);
  Result.AddPair('provider', LProvider);
  Result.AddPair('cliClientId', LCliClientId);
  Result.AddPair('cliSessionState', LSessionState);
  Result.AddPair('journeyState', LJourneyState);
  Result.AddPair('journeyId', LJourneyId);
  Result.AddPair('journeyActivity', LActivityState);
  Result.AddPair('mcpRole', 'external-bridge');
end;

procedure TRadIAChatPresenter.PostExecutionRouteToWeb;
var
  LJson: TJSONObject;
begin
  LJson := BuildExecutionRouteJson;
  try
    LJson.AddPair('action', 'execution_route');
    PostJsonToWeb(LJson);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.PostExecutionScopeToWeb;
var
  LJson: TJSONObject;
  LSettings: TRadIAResolvedExecutionSettings;
  procedure AddSetting(
    const AName: string;
    const AValue: string;
    const AOrigin: TRadIASettingOrigin
  );
  var
    LSetting: TJSONObject;
  begin
    LSetting := TJSONObject.Create;
    LSetting.AddPair('value', AValue);
    LSetting.AddPair(
      'origin',
      TRadIAExecutionSettingsResolver.OriginName(AOrigin)
    );
    LJson.AddPair(AName, LSetting);
  end;
begin
  LSettings := ResolveEffectiveExecutionSettings;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'execution_scope');
    AddSetting(
      'provider',
      LSettings.Values.ProviderId,
      LSettings.ProviderOrigin
    );
    AddSetting('model', LSettings.Values.ModelId, LSettings.ModelOrigin);
    AddSetting(
      'executor',
      LSettings.Values.ExecutorId,
      LSettings.ExecutorOrigin
    );
    AddSetting(
      'maxTokens',
      LSettings.Values.MaxTokens.ToString,
      LSettings.MaxTokensOrigin
    );
    AddSetting(
      'timeoutMs',
      LSettings.Values.TimeoutMs.ToString,
      LSettings.TimeoutOrigin
    );
    AddSetting(
      'tokenBudget',
      LSettings.Values.TokenBudget.ToString,
      LSettings.TokenBudgetOrigin
    );
    LJson.AddPair('projectAvailable', TJSONBool.Create(CurrentProjectId <> ''));
    LJson.AddPair(
      'sessionAvailable',
      TJSONBool.Create(FSessionManager.ActiveSessionId <> '')
    );
    PostJsonToWeb(LJson);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.HandleExecutionScopeAction(
  const AJson: TJSONObject
);
var
  LError: string;
  LField: string;
  LOperation: string;
  LScope: string;
begin
  LOperation := AJson.GetValue<string>('operation', 'set');
  LScope := AJson.GetValue<string>('scope', 'session');
  LField := AJson.GetValue<string>('field', '');
  try
    if SameText(LOperation, 'clear') then
      TryClearScopeSettings(LScope, '', LError)
    else if SameText(LOperation, 'inherit') then
      TryClearScopeSettings(LScope, LField, LError)
    else
      TryUpdateScopeSettings(
        LScope,
        LField,
        AJson.GetValue<string>('value', ''),
        LError
      );
  except
    on E: Exception do
      LError := E.Message;
  end;
  if LError <> '' then
    PostToWebView(
      'add_message',
      'assistant',
      '**Execution settings were not changed:** ' + LError
    )
  else
  begin
    PostExecutionRouteToWeb;
    UpdateModelsCombo;
  end;
  PostExecutionScopeToWeb;
end;

procedure TRadIAChatPresenter.ExportExecutionScope(
  const AScopeName: string
);
var
  LFileName: string;
  LJson: TJSONObject;
  LScopeId: string;
  LScopeKind: TRadIASettingsScopeKind;
  LSettings: TRadIAExecutionSettings;
  LSettingsJson: TJSONObject;
begin
  if not Assigned(FHierarchicalSettingsStore) then
  begin
    PostToWebView('add_message', 'assistant', 'Hierarchical settings storage is unavailable.');
    Exit;
  end;
  if SameText(AScopeName, 'project') then
  begin
    LScopeKind := rssProject;
    LScopeId := CurrentProjectId;
  end
  else if SameText(AScopeName, 'session') then
  begin
    LScopeKind := rssSession;
    LScopeId := FSessionManager.ActiveSessionId;
  end
  else
  begin
    PostToWebView('add_message', 'assistant', 'Only project and session scopes can be exported.');
    Exit;
  end;
  if LScopeId = '' then
  begin
    PostToWebView('add_message', 'assistant', 'The selected scope is unavailable.');
    Exit;
  end;
  if not FView.SaveDialogExecute(LFileName) then
    Exit;
  LSettings := FHierarchicalSettingsStore.Load(LScopeKind, LScopeId);
  LJson := TJSONObject.Create;
  try
    LSettingsJson := TJSONObject.Create;
    LJson.AddPair('schemaVersion', TJSONNumber.Create(1));
    LJson.AddPair('scope', LowerCase(AScopeName));
    LJson.AddPair('settings', LSettingsJson);
    if LSettings.HasProvider then
      LSettingsJson.AddPair('provider', LSettings.ProviderId);
    if LSettings.HasModel then
      LSettingsJson.AddPair('model', LSettings.ModelId);
    if LSettings.HasExecutor then
      LSettingsJson.AddPair('executor', LSettings.ExecutorId);
    if LSettings.HasMaxTokens then
      LSettingsJson.AddPair('maxTokens', TJSONNumber.Create(LSettings.MaxTokens));
    if LSettings.HasTimeout then
      LSettingsJson.AddPair('timeoutMs', TJSONNumber.Create(LSettings.TimeoutMs));
    if LSettings.HasTokenBudget then
      LSettingsJson.AddPair('tokenBudget', TJSONNumber.Create(LSettings.TokenBudget));
    TFile.WriteAllText(LFileName, LJson.Format(2), TEncoding.UTF8);
  finally
    LJson.Free;
  end;
  PostToWebView(
    'add_message',
    'assistant',
    'The sanitized ' + LowerCase(AScopeName) + ' scope was exported to `' + LFileName + '`.'
  );
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
  LDeclarativeCommand: TRadIADeclarativeCommand;
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

  ReloadDeclarativeExtensions;
  if FDeclarativeExtensionManager.TryResolve(
    ACommand,
    LDeclarativeCommand
  ) then
  begin
    ATemplate := Default(TPromptTemplate);
    ATemplate.Name := LDeclarativeCommand.Name;
    ATemplate.Description := LDeclarativeCommand.Description;
    ATemplate.Template := LDeclarativeCommand.Prompt;
    ATemplate.SlashCommand := LDeclarativeCommand.SlashCommand;
    ATemplate.IsSystem := False;
    ATemplate.IsCustomized := False;
    Exit(True);
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

function TRadIAChatPresenter.TestBuildConversationalCliPrompt(
  const APromptText: string
): string;
begin
  Result := BuildConversationalCliPrompt(APromptText);
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
  LModels: TJSONArray;
  LActiveProvider: string;
  LActiveModel: string;
  LIsWebLogin: Boolean;
  LModelState: TRadIAModelSelectionState;
begin
  if not FWebViewReady then Exit;

  LActiveProvider := FConfig.GetActiveProvider;
  LIsWebLogin := FConfig.IsWebLoginProvider(LActiveProvider);
  LModelState := GetModelSelectionState;
  if LModelState.Enabled then
    LModels := BuildModelsJsonArray(LActiveProvider, LIsWebLogin, LActiveModel)
  else
  begin
    LModels := TJSONArray.Create;
    LModels.Add(LModelState.DisplayText);
    LActiveModel := LModelState.DisplayText;
  end;

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('action', 'initialize_config');
    LJson.AddPair('providers', BuildProvidersJsonArray);
    LJson.AddPair('models', LModels);
    LJson.AddPair('slashCommands', BuildSlashCommandsJsonArray);
    LJson.AddPair('tools', BuildToolsJsonArray);
    LJson.AddPair('agentModeEnabled', TJSONBool.Create(FAgentModeEnabled));
    LJson.AddPair('modelSelectionEnabled', TJSONBool.Create(LModelState.Enabled));
    LJson.AddPair('activeProvider', LActiveProvider);
    LJson.AddPair('activeModel', LActiveModel);
    LJson.AddPair('isWebLogin', TJSONBool.Create(LIsWebLogin));
    LJson.AddPair('executionRoute', BuildExecutionRouteJson);
    LJson.AddPair(
      'reasoningEffort',
      FAgentExecutorSettings.Load.ReasoningEffort
    );

    FView.PostMessageToWeb(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

procedure TRadIAChatPresenter.SendModelsUpdateToWeb(
  const AModels: TArray<string>;
  const AActiveModel: string;
  const AEnabled: Boolean
);
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
    LJson.AddPair('enabled', TJSONBool.Create(AEnabled));

    FView.PostMessageToWeb(LJson.ToJSON);
  finally
    LJson.Free;
  end;
end;

function TRadIAChatPresenter.GetModelSelectionState: TRadIAModelSelectionState;
var
  LEffective: TRadIAResolvedExecutionSettings;
  LSettings: TRadIAAgentExecutorSettings;
begin
  LEffective := ResolveEffectiveExecutionSettings;
  if SameText(LEffective.Values.ExecutorId, 'native') then
    LSettings := TRadIAAgentExecutorSettings.Create(aekNative, '')
  else
    LSettings := TRadIAAgentExecutorSettings.Create(
      aekCli,
      LEffective.Values.ExecutorId
    );
  Result := TRadIAModelSelectionState.FromExecutor(
    LSettings
  );
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
