unit RadIA.OTA.Register;

interface

uses
  System.Classes, ToolsAPI, Vcl.ExtCtrls;

type
  { Wizard implementing IOTAWizard to register RadIA into Delphi IDE }
  TRadIAWizard = class(TInterfacedObject, IOTAWizard)
  private
    FEditorHook: TObject;
    FKnowledgeNotifier: TObject;
    FDebugTimelineNotifier: TObject;
    FTimer: TTimer;
    FOptionsPages: TInterfaceList;
    procedure RegisterMenus;
    procedure UnregisterMenus;
    procedure RegisterOptions;
    procedure UnregisterOptions;
    procedure OnExtensionManagerClick(Sender: TObject);
    procedure OnRequestDiff(const AOriginalCode: string; const AReplaceWholeBuffer: Boolean);
    procedure OnProjectWizardClick(Sender: TObject);
    procedure OnTimerEvent(Sender: TObject);
    procedure RestoreWindowVisibility;
    procedure ReleaseDebugTimelineNotifier;
    procedure ReleaseEditorHook;
    procedure ReleaseKnowledgeNotifier;
    procedure ReleasePinnedModule;
  public
    constructor Create;
    destructor Destroy; override;

    { IOTANotifier implementation }
    procedure AfterSave;
    procedure BeforeSave;
    procedure Destroyed;
    procedure Modified;

    { IOTAWizard implementation }
    function GetName: string;
    function GetIDString: string;
    function GetState: TWizardState;
    procedure Execute;
  end;

procedure Register;

implementation

uses
  System.SysUtils, System.IOUtils, Vcl.Menus, Vcl.Controls, Vcl.Graphics, Vcl.Dialogs, Vcl.Forms,
  System.Win.Registry, Winapi.Windows,
  RadIA.OTA.AgentDiagnostic,
  RadIA.OTA.DeclarativeWorkflowDiagnostic,
  RadIA.OTA.MemoryDiagnostic,
  RadIA.OTA.EditorHook,
  RadIA.UI.DiffForm, RadIA.UI.ConfigForm,
  RadIA.UI.ProjectWizard, RadIA.UI.OnboardingForm,
  RadIA.UI.ExtensionManagerForm,
  RadIA.OTA.Helper, RadIA.OTA.Onboarding, RadIA.Core.Types,
  RadIA.Core.Mediator,
  RadIA.Core.Config, RadIA.OTA.DockableForm, RadIA.Core.Interfaces, RadIA.Core.Logger, RadIA.OTA.Options,
  RadIA.Core.Container, RadIA.Core.Service, RadIA.OTA.Adapter, RadIA.Core.TextNormalizer, RadIA.Core.DTO.Generator,
  RadIA.Core.ProjectGenerator, RadIA.Core.HttpClient, RadIA.Core.ErrorDecoder, RadIA.Core.Localizer,
  RadIA.Core.ProjectTemplateService, RadIA.Core.ProjectTemplateTools,
  RadIA.Core.ProjectOpening, RadIA.OTA.ProjectOpening,
  RadIA.Core.ProjectFiles, RadIA.Core.ProjectFileTools,
  RadIA.OTA.ProjectFiles,
  RadIA.Core.EditorAdapter, RadIA.Core.Tools, RadIA.Core.ToolRegistry, RadIA.Core.Workspace,
  RadIA.Core.AgentResultStore, RadIA.Core.AgentResultTools,
  RadIA.Core.ResultCompactor,
  RadIA.Core.Extensions, RadIA.Core.Version,
  RadIA.Core.WorkspaceTools, RadIA.Core.WorkspaceBoundary,
  RadIA.Core.DelphiEnvironment, RadIA.Core.DelphiEnvironmentTools,
  RadIA.Core.DelphiGuidance, RadIA.Core.DelphiGuidanceTools,
  RadIA.Core.DelphiMentor,
  RadIA.Core.DfmPasAudit, RadIA.Core.DfmPasAuditTools,
  RadIA.Core.DesignerVisualDiff, RadIA.Core.DesignerVisualDiffTools,
  RadIA.Core.ToolSecurity, RadIA.Core.Patches, RadIA.Core.PatchTools,
  RadIA.Core.MultiFilePatches, RadIA.Core.MultiFilePatchTools,
  RadIA.Core.LegacyDataMigrationTools,
  RadIA.Core.BlockReviewSessions,
  RadIA.Core.BlockReviewTools,
  RadIA.Core.DevelopmentTransactions,
  RadIA.Core.DevelopmentTransactionTools,
  RadIA.Core.Build, RadIA.Core.BuildTools, RadIA.OTA.Workspace,
  RadIA.Core.DUnitX, RadIA.Core.DUnitXTools, RadIA.OTA.DUnitX,
  RadIA.Core.CoverageTools,
  RadIA.Core.Git, RadIA.Core.GitTools, RadIA.OTA.Git,
  RadIA.Core.Mcp, RadIA.OTA.Consent, RadIA.OTA.Build,
  RadIA.Core.Designer, RadIA.Core.DesignerTools,
  RadIA.Core.DesignerMutations, RadIA.Core.DesignerMutationTools,
  RadIA.Core.DesignerProperties, RadIA.Core.DesignerPropertyTools,
  RadIA.Core.DesignerComponents, RadIA.Core.DesignerComponentTools,
  RadIA.Core.DesignerEvents, RadIA.Core.DesignerEventTools,
  RadIA.Core.Debugger, RadIA.Core.DebuggerTools,
  RadIA.Core.DebugTimeline, RadIA.Core.DebugTimelineTools,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeDebugTools,
  RadIA.Core.RuntimeAutomation, RadIA.Core.RuntimeDiscoveryTools,
  RadIA.Core.RuntimeVisualTools, RadIA.Core.VisualRuntimeSession,
  RadIA.Core.RuntimeScenario, RadIA.Core.RuntimeScenarioTools,
  RadIA.Core.RuntimeEvidence, RadIA.Core.RuntimeEvidenceTools,
  RadIA.Core.RuntimeRegression, RadIA.Core.RuntimeRegressionTools,
  RadIA.Core.DebuggerControlTools, RadIA.Core.DebuggerBreakpointTools,
  RadIA.Core.DebuggerWatches, RadIA.Core.DebuggerInspectionTools,
  RadIA.Core.InlineReviews, RadIA.Core.InlineReviewTools,
  RadIA.Core.InlineCompletion,
  RadIA.Core.JourneyContext,
  RadIA.Core.HierarchicalSettingsStore,
  RadIA.Core.IDENavigation, RadIA.Core.IDENavigationTools,
  RadIA.Core.Knowledge, RadIA.Core.KnowledgeEmbeddings,
  RadIA.Core.KnowledgeEmbeddingSelection,
  RadIA.Core.RemoteKnowledgeSettings,
  RadIA.Core.KnowledgePrivacy,
  RadIA.Core.KnowledgeHistory,
  RadIA.Core.KnowledgeTools,
  RadIA.Core.ProjectHealthTools,
  RadIA.Core.InstallationHealthTools,
  RadIA.Core.ExternalMcpRuntime,
  RadIA.Core.ExternalMcpSettings,
  RadIA.Core.FastMM5,
  RadIA.Core.MemoryInstrumentation,
  RadIA.Core.FastMM5LogParser,
  RadIA.Core.MemoryDiagnosticSession,
  RadIA.Core.MemoryEvidence,
  RadIA.Core.KnowledgeStore, RadIA.Core.KnowledgeScheduler,
  RadIA.OTA.Designer, RadIA.OTA.Debugger, RadIA.OTA.DebugTimeline,
  RadIA.OTA.RuntimeDiscovery,
  RadIA.OTA.DebugTimelineStore,
  RadIA.OTA.Knowledge,
  RadIA.OTA.KnowledgeNotifier, RadIA.OTA.InlineReviews,
  RadIA.OTA.IDENavigation,
  RadIA.MCP.NamedPipe;

const
  GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS = $00000004;

function GetModuleHandleEx(ADwFlags: DWORD; ALpModuleName: PChar; var APhModule: HMODULE): BOOL; stdcall;
  external 'kernel32.dll' name 'GetModuleHandleExW';

var
  GWizardIndex: Integer = -1;
  GAboutBoxIndex: Integer = -1;
  LAboutServices: IOTAAboutBoxServices;
  GModuleHandle: HMODULE = 0;
  GMcpServer: IRadIAMcpServer;

procedure LogDebug(const AMsg: string);
begin
  TLogger.Log(AMsg, 'Register');
end;

function GetRadIAModuleDirectory: string;
var
  LBuffer: array[0..MAX_PATH] of Char;
  LModuleFile: string;
begin
  SetString(
    LModuleFile,
    LBuffer,
    GetModuleFileName(HInstance, LBuffer, Length(LBuffer))
  );
  Result := TPath.GetDirectoryName(LModuleFile);
end;

procedure RegisterSplashAndAbout;
var
  LBitmap: Vcl.Graphics.TBitmap;
begin
  LBitmap := Vcl.Graphics.TBitmap.Create;
  try
    LBitmap.PixelFormat := pf24bit;
    LBitmap.Width := 24;
    LBitmap.Height := 24;

    // Fundo azul escuro (#0F172A -> BGR $002A170F)
    LBitmap.Canvas.Brush.Color := $002A170F;
    LBitmap.Canvas.FillRect(Rect(0, 0, 24, 24));

    // CabeÃ§a do robÃ´ cinza claro (#D1D5DB -> BGR $00DBD5D1)
    LBitmap.Canvas.Pen.Color := $00DBD5D1;
    LBitmap.Canvas.Brush.Color := $00DBD5D1;
    LBitmap.Canvas.RoundRect(4, 6, 20, 18, 4, 4);

    // Antena
    LBitmap.Canvas.Pen.Color := $00DBD5D1;
    LBitmap.Canvas.MoveTo(12, 6);
    LBitmap.Canvas.LineTo(12, 3);
    LBitmap.Canvas.Brush.Color := $00CC7A00; // Azul RadIA (#007ACC -> BGR $00CC7A00)
    LBitmap.Canvas.Ellipse(10, 1, 14, 5);

    // Olhos azuis brilhantes (#3B82F6 -> BGR $00F6823B)
    LBitmap.Canvas.Brush.Color := $00F6823B;
    LBitmap.Canvas.Pen.Color := $00F6823B;
    LBitmap.Canvas.Ellipse(7, 10, 10, 13);
    LBitmap.Canvas.Ellipse(14, 10, 17, 13);

    // Boca
    LBitmap.Canvas.Pen.Color := $009CA3AF;
    LBitmap.Canvas.MoveTo(9, 15);
    LBitmap.Canvas.LineTo(15, 15);

    { 1. Registrar na Splash Screen se disponÃ­vel }
    if Assigned(SplashScreenServices) then
    begin
      SplashScreenServices.AddPluginBitmap(
        'Rad IA AI Assistant',
        LBitmap.Handle,
        False,
        'Open Source (BYOK)'
      );
    end;

    { 2. Registrar no About Box se disponÃ­vel }
    if Supports(BorlandIDEServices, IOTAAboutBoxServices, LAboutServices) then
    begin
      GAboutBoxIndex := LAboutServices.AddPluginInfo(
        'Rad IA AI Assistant',
        'Rad IA - AI Assistant for Delphi IDE' + sLineBreak +
        'Provides sidebar chat, code refactoring, context parsing, and smart diff.' + sLineBreak +
        'Copyright (c) 2026 Rad IA Open Source Project',
        LBitmap.Handle,
        False,
        'Apache 2.0 License',
        'v' + CRadIAVersion
      );
    end;
  finally
    LBitmap.Free;
  end;
end;

procedure Register;
var
  LOTAInstance: IOTAWizard;
  LWizardServices: IOTAWizardServices;
  LOTAServices: IOTAServices;
begin
  LogDebug('Register called');
  if not Assigned(BorlandIDEServices) then
  begin
    LogDebug('Error: BorlandIDEServices is nil');
    Exit;
  end;

  if Supports(BorlandIDEServices, IOTAServices, LOTAServices) then
  begin
    TRadIAConfig.SetBaseRegistryPath(LOTAServices.GetBaseRegistryKey + '\RadIA');
  end;

  if Supports(BorlandIDEServices, IOTAWizardServices, LWizardServices) then
  begin
    LogDebug('IOTAWizardServices supported');
    try
      LOTAInstance := TRadIAWizard.Create;
      GWizardIndex := LWizardServices.AddWizard(LOTAInstance);
      LogDebug(Format('Wizard added successfully with index: %d', [GWizardIndex]));
    except
      on E: Exception do
        LogDebug('Exception during Wizard creation: ' + E.Message);
    end;
  end
  else
  begin
    LogDebug('Error: IOTAWizardServices NOT supported');
  end;
  RegisterSplashAndAbout;
end;

{ TRadIAWizard }

constructor TRadIAWizard.Create;
var
  LThemingServices: IOTAIDEThemingServices;
begin
  LogDebug('TRadIAWizard.Create called');
  GIsShuttingDown := False;

  // Keep the package mapped while background operations finish during IDE shutdown.
  GetModuleHandleEx(
    GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS,
    PChar(@Register),
    GModuleHandle
  );

  inherited Create;

  FOptionsPages := TInterfaceList.Create;

  {$IFNDEF TESTS}
  RadIA.OTA.DockableForm.RegisterDockableForm;
  {$ENDIF}

  { Register custom forms in IDE Theming Services }
  if Supports(BorlandIDEServices, IOTAIDEThemingServices, LThemingServices) then
  begin
    LThemingServices.RegisterFormClass(TRadIAFormAIDiff);
    LThemingServices.RegisterFormClass(TRadIAFormAIConfig);
    LThemingServices.RegisterFormClass(TRadIAProjectWizardForm);
    LThemingServices.RegisterFormClass(TRadIAOnboardingForm);
    LThemingServices.RegisterFormClass(TRadIAExtensionManagerForm);
  end;

  FEditorHook := TRadIAEditorHook.Create(nil);
  TRadIAEditorHook(FEditorHook).Install;
  FKnowledgeNotifier := TRadIAOTAKnowledgeNotifier.Create(
    nil,
    TRadIAContainer.Resolve<IRadIAKnowledgeRefreshScheduler>
  );
  TRadIAOTAKnowledgeNotifier(FKnowledgeNotifier).Install;
  FDebugTimelineNotifier := TRadIAOTADebugTimelineNotifier.Create(
    TRadIAContainer.Resolve<IRadIADebugTimeline>,
    TRadIAContainer.Resolve<IRadIARuntimeDebugSessionCoordinator>
  );
  TRadIAOTADebugTimelineNotifier(FDebugTimelineNotifier).Install;
  RegisterMenus;
  RegisterOptions;

  FTimer := TTimer.Create(nil);
  FTimer.Interval := 1000;
  FTimer.OnTimer := OnTimerEvent;
  FTimer.Enabled := True;

  TRadIAContainer.Resolve<IRadIAMediator>.RegisterDiffHandler(OnRequestDiff);
end;

procedure TRadIAWizard.ReleaseDebugTimelineNotifier;
begin
  if not Assigned(FDebugTimelineNotifier) then
    Exit;
  TRadIAOTADebugTimelineNotifier(FDebugTimelineNotifier).Uninstall;
  if GIsShuttingDown then
    FDebugTimelineNotifier := nil
  else
    FreeAndNil(FDebugTimelineNotifier);
end;

procedure TRadIAWizard.ReleaseEditorHook;
begin
  if not Assigned(FEditorHook) then
    Exit;
  TRadIAEditorHook(FEditorHook).Uninstall;
  if GIsShuttingDown then
    FEditorHook := nil
  else
    FreeAndNil(FEditorHook);
end;

procedure TRadIAWizard.ReleaseKnowledgeNotifier;
begin
  if not Assigned(FKnowledgeNotifier) then
    Exit;
  if GIsShuttingDown then
  begin
    TRadIAOTAKnowledgeNotifier(
      FKnowledgeNotifier
    ).PrepareForShutdown;
    FKnowledgeNotifier := nil;
  end
  else
  begin
    TRadIAOTAKnowledgeNotifier(FKnowledgeNotifier).Uninstall;
    FreeAndNil(FKnowledgeNotifier);
  end;
end;

procedure TRadIAWizard.ReleasePinnedModule;
begin
  if GIsShuttingDown or (GModuleHandle = 0) then
    Exit;
  FreeLibrary(GModuleHandle);
  GModuleHandle := 0;
end;

destructor TRadIAWizard.Destroy;
var
  LMediator: IRadIAMediator;
begin
  LogDebug('TRadIAWizard.Destroy started');
  GIsShuttingDown :=
    Application.Terminated or
    not Assigned(Application.MainForm) or
    not Application.MainForm.HandleAllocated or
    not IsWindowVisible(Application.MainForm.Handle);
  LogDebug(
    'TRadIAWizard.Destroy shutdown state: ' +
    BoolToStr(GIsShuttingDown, True)
  );
  if Assigned(GMcpServer) then
  begin
    LogDebug('TRadIAWizard.Destroy stopping MCP server');
    GMcpServer.Stop;
    LogDebug('TRadIAWizard.Destroy MCP server stopped');
  end;

  {$IFNDEF TESTS}
  RadIA.OTA.Onboarding.ReleaseRadIAOnboarding;
  RadIA.OTA.DockableForm.UnregisterDockableForm;
  LogDebug('TRadIAWizard.Destroy dockable form released');
  {$ENDIF}

  if TRadIAContainer.TryResolve<IRadIAMediator>(LMediator) then
    LMediator.UnregisterDiffHandler;
  LogDebug('TRadIAWizard.Destroy mediator released');
  if Assigned(FTimer) then
  begin
    FTimer.Enabled := False;
    FTimer.Free;
  end;
  LogDebug('TRadIAWizard.Destroy timer released');
  ReleaseKnowledgeNotifier;
  LogDebug('TRadIAWizard.Destroy knowledge notifier released');
  ReleaseDebugTimelineNotifier;
  LogDebug('TRadIAWizard.Destroy debug notifier released');
  UnregisterOptions;
  LogDebug('TRadIAWizard.Destroy options released');
  UnregisterMenus;
  LogDebug('TRadIAWizard.Destroy menus released');
  ReleaseEditorHook;
  LogDebug('TRadIAWizard.Destroy editor hook released');
  FOptionsPages.Free;
  LogDebug('TRadIAWizard.Destroy owned objects released');

  ReleasePinnedModule;

  GWizardIndex := -1;
  LogDebug('TRadIAWizard.Destroy completed');
  inherited Destroy;
end;

procedure TRadIAWizard.RegisterOptions;
var
  LOptionsServices: INTAEnvironmentOptionsServices;

  procedure AddPage(const ATitle: string; ATag: TRadIAPageTag);
  var
    LOptions: INTAAddInOptions;
  begin
    LOptions := TRadIAAddInOptions.Create(ATitle, ATag);
    FOptionsPages.Add(LOptions);
    LOptionsServices.RegisterAddInOptions(LOptions);
  end;

begin
  if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, LOptionsServices) then
  begin
    AddPage('General', ptNone);
    AddPage('System Prompt', ptSystem);
    AddPage('Templates', ptTemplates);
    AddPage('Gemini', ptGemini);
    AddPage('OpenAI', ptOpenAI);
    AddPage('Azure OpenAI', ptAzureOpenAI);
    AddPage('Claude', ptClaude);
    AddPage('DeepSeek', ptDeepSeek);
    AddPage('Groq', ptGroq);
    AddPage('Alibaba Qwen', ptQwen);
    AddPage('Mistral AI', ptMistral);
    AddPage('OpenRouter', ptOpenRouter);
    AddPage('GitHub Copilot', ptGithubCopilot);
    AddPage('AWS Bedrock', ptBedrock);
    AddPage('Ollama', ptOllama);
    AddPage('LM Studio', ptLMStudio);
  end;
end;

procedure TRadIAWizard.UnregisterOptions;
var
  LOptionsServices: INTAEnvironmentOptionsServices;
  I: Integer;
begin
  try
    if Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, LOptionsServices) then
    begin
      for I := FOptionsPages.Count - 1 downto 0 do
      begin
        try
          LOptionsServices.UnregisterAddInOptions(FOptionsPages[I] as INTAAddInOptions);
        except
          on E: Exception do
            OutputDebugString(PChar('RadIA.Register.UnregisterOptions Error: ' + E.Message));
        end;
      end;
      FOptionsPages.Clear;
    end;
  except
    on E: Exception do
      OutputDebugString(PChar('RadIA.Register.UnregisterOptions Main Error: ' + E.Message));
  end;
end;

procedure TRadIAWizard.AfterSave;
begin
  // Intentionally empty: IOTANotifier implementation
end;

procedure TRadIAWizard.BeforeSave;
begin
  // Intentionally empty: IOTANotifier implementation
end;

procedure TRadIAWizard.Destroyed;
begin
  // Intentionally empty: IOTANotifier implementation
end;

procedure TRadIAWizard.Modified;
begin
  // Intentionally empty: IOTANotifier implementation
end;

function TRadIAWizard.GetIDString: string;
begin
  Result := 'RadIA.Wizard.Main';
end;

function TRadIAWizard.GetName: string;
begin
  Result := 'Rad IA';
end;

function TRadIAWizard.GetState: TWizardState;
begin
  Result := [wsEnabled];
end;

procedure TRadIAWizard.Execute;
begin
  // Handled on menu and context clicks, nothing to execute on start
end;

procedure TRadIAWizard.OnProjectWizardClick(Sender: TObject);
var
  LForm: TRadIAProjectWizardForm;
begin
  LForm := TRadIAProjectWizardForm.Create(
    nil,
    TRadIAContainer.Resolve<IRadIAProjectTemplateService>,
    TRadIAContainer.Resolve<IRadIAAuthorizedProjectTemplateService>
  );
  try
    LForm.ShowModal;
  finally
    LForm.Free;
  end;
end;

procedure TRadIAWizard.OnExtensionManagerClick(Sender: TObject);
begin
  ShowRadIAExtensionManager;
end;

procedure TRadIAWizard.OnRequestDiff(const AOriginalCode: string; const AReplaceWholeBuffer: Boolean);
var
  LForm: TRadIAFormAIDiff;
  LActiveFile: string;
  LConfig: IRadIAConfig;
  LAdapter: IRadIAIDEAdapter;
begin
  if not TRadIAContainer.TryResolve<IRadIAConfig>(LConfig) then
  begin
    LConfig := TRadIAConfig.GetInstance;
    LConfig.Load;
  end;

  LForm := TRadIAFormAIDiff.Create(nil);
  try
    LActiveFile := 'ActiveUnit.pas';
    if TRadIAContainer.TryResolve<IRadIAIDEAdapter>(LAdapter) then
    begin
      LActiveFile := LAdapter.GetActiveUnitName;
      if LActiveFile.IsEmpty then
        LActiveFile := 'ActiveUnit.pas'
      else
        LActiveFile := LActiveFile + '.pas';
    end;

    LForm.InitializeDiff(LActiveFile, AOriginalCode);
    if LForm.ShowModal = mrOk then
    begin
      var LSuccess: Boolean;
      if Assigned(LAdapter) then
        LSuccess := LAdapter.ReplaceActiveEditorText(LForm.SuggestedCode, AReplaceWholeBuffer, AOriginalCode)
      else
        LSuccess := TRadIAOTAHelper.ReplaceActiveEditorText(LForm.SuggestedCode, AReplaceWholeBuffer, AOriginalCode);

      if not LSuccess then
        ShowMessage('Could not apply the diff because the original code block was not found in the active editor.');
    end;
  finally
    LForm.Free;
  end;
end;

function FindToolsMenu(const AMainMenu: TMainMenu): TMenuItem;
var
  I: Integer;
  LCaption: string;
begin
  Result := nil;
  if not Assigned(AMainMenu) then
    Exit;

  // 1. Busca pelo nome do componente (independe de traduÃ§Ã£o)
  for I := 0 to AMainMenu.Items.Count - 1 do
  begin
    if SameText(AMainMenu.Items[I].Name, 'ToolsMenu') or
       SameText(AMainMenu.Items[I].Name, 'Tools') then
    begin
      Result := AMainMenu.Items[I];
      Exit;
    end;
  end;

  // 2. Fallbacks de Caption usando buscas exatas limpas de atalhos (&)
  for I := 0 to AMainMenu.Items.Count - 1 do
  begin
    LCaption := StringReplace(AMainMenu.Items[I].Caption, '&', '', [rfReplaceAll]);
    if SameText(LCaption, 'Tools') or
       SameText(LCaption, 'Ferramentas') or
       SameText(LCaption, 'ToolsMenu') then
    begin
      Result := AMainMenu.Items[I];
      Exit;
    end;
  end;

  // 3. Fallback clÃ¡ssico da Open Tools API
  Result := AMainMenu.Items.Find('Tools');
end;

procedure TRadIAWizard.RegisterMenus;
var
  LNTAServices: INTAServices;
  LToolsMenu: TMenuItem;
  I: Integer;
  LToolsAlreadyPopulated: Boolean;
  LHook: TRadIAEditorHook;
  LExtensionManagerItem: TMenuItem;
  LProjectWizardItem: TMenuItem;
begin
  LogDebug('RegisterMenus called');
  LToolsAlreadyPopulated := False;
  LHook := TRadIAEditorHook(FEditorHook);

  if Supports(BorlandIDEServices, INTAServices, LNTAServices) then
  begin
    LogDebug('INTAServices supported');

    { Register tools actions }
    LToolsMenu := FindToolsMenu(LNTAServices.MainMenu);
    if Assigned(LToolsMenu) then
    begin
      for I := 0 to LToolsMenu.Count - 1 do
      begin
        if SameText(LToolsMenu[I].Caption, 'RadIA Chat Panel') or
           SameText(LToolsMenu[I].Caption, 'Rad IA Chat Panel') or
           SameText(LToolsMenu[I].Caption, 'Rad IA Terminal') or
           SameText(LToolsMenu[I].Caption, 'Rad IA Getting Started') or
           SameText(LToolsMenu[I].Caption, 'Fix Last Compiler Error') then
        begin
          LToolsAlreadyPopulated := True;
          Break;
        end;
      end;

      if not LToolsAlreadyPopulated then
      begin
        LogDebug('Tools/Ferramentas menu found');
        LHook.PopulateToolsMenu(LToolsMenu);
        LProjectWizardItem := TMenuItem.Create(LToolsMenu);
        LProjectWizardItem.Caption := 'RadIA New Project...';
        LProjectWizardItem.OnClick := OnProjectWizardClick;
        LToolsMenu.Add(LProjectWizardItem);
        LExtensionManagerItem := TMenuItem.Create(LToolsMenu);
        LExtensionManagerItem.Caption := 'Rad IA Extensions...';
        LExtensionManagerItem.OnClick := OnExtensionManagerClick;
        LToolsMenu.Add(LExtensionManagerItem);
        LogDebug('Tools menu populated');
      end;
    end
    else
    begin
      LogDebug('Error: Tools/Ferramentas menu NOT found');
    end;
  end;
end;

procedure TRadIAWizard.OnTimerEvent(Sender: TObject);
var
  LNTAServices: INTAServices;
  LToolsMenu: TMenuItem;
  LToolsPopulated: Boolean;
  I: Integer;
  LHook: TRadIAEditorHook;
begin
  LToolsPopulated := False;
  LHook := TRadIAEditorHook(FEditorHook);

  if Supports(BorlandIDEServices, INTAServices, LNTAServices) then
  begin
    // 1. Verificar e popular o menu Tools
    LToolsMenu := FindToolsMenu(LNTAServices.MainMenu);
    if Assigned(LToolsMenu) then
    begin
      for I := 0 to LToolsMenu.Count - 1 do
      begin
        if SameText(LToolsMenu[I].Caption, 'RadIA Chat Panel') or
           SameText(LToolsMenu[I].Caption, 'Rad IA Chat Panel') or
           SameText(LToolsMenu[I].Caption, 'Rad IA Terminal') or
           SameText(LToolsMenu[I].Caption, 'Rad IA Getting Started') or
           SameText(LToolsMenu[I].Caption, 'Fix Last Compiler Error') then
        begin
          LToolsPopulated := True;
          Break;
        end;
      end;

      if not LToolsPopulated then
      begin
        LogDebug('Tools menu not populated or reset. Populating now...');
        LHook.PopulateToolsMenu(LToolsMenu);
        LToolsPopulated := True;
        LogDebug('Tools menu populated successfully');
      end;
    end;
  end;

  // Desliga o timer assim que o menu Tools estiver populado
  if LToolsPopulated then
  begin
    LogDebug('Tools menu populated. Disabling timer.');
    FTimer.Enabled := False;
    RestoreWindowVisibility;
    ShowRadIAOnboarding(False);
  end;
end;

procedure TRadIAWizard.UnregisterMenus;
  procedure RemoveRadIAMenuItems(const AToolsMenu: TMenuItem);
  var
    I: Integer;
    LItem: TMenuItem;
  begin
    for I := AToolsMenu.Count - 1 downto 0 do
    begin
      try
        LItem := AToolsMenu[I];
        if SameText(LItem.Caption, 'RadIA Chat Panel') or
           SameText(LItem.Caption, 'Rad IA Chat Panel') or
           SameText(LItem.Caption, 'Rad IA Terminal') or
           SameText(LItem.Caption, 'Rad IA Getting Started') or
           SameText(LItem.Caption, 'Rad IA Extensions...') or
           SameText(LItem.Caption, 'Fix Last Compiler Error') or
           SameText(LItem.Caption, 'RadIA New Project...') then
        begin
          LItem.Free;
        end;
      except
        on E: Exception do
          OutputDebugString(PChar('RadIA.Register.UnregisterMenus Item Error: ' + E.Message));
      end;
    end;
  end;

var
  LNTAServices: INTAServices;
  LToolsMenu: TMenuItem;
begin
  LogDebug('UnregisterMenus called');
  if not Assigned(FEditorHook) then
    Exit;

  try
    if Supports(BorlandIDEServices, INTAServices, LNTAServices) then
    begin
      LToolsMenu := FindToolsMenu(LNTAServices.MainMenu);
      if Assigned(LToolsMenu) then
      begin
        RemoveRadIAMenuItems(LToolsMenu);
      end;
    end;
  except
    on E: Exception do
      OutputDebugString(PChar('RadIA.Register.UnregisterMenus Main Error: ' + E.Message));
  end;
end;

procedure TRadIAWizard.RestoreWindowVisibility;
var
  LReg: TRegistry;
  LRegPath: string;
  LVisible: Boolean;
begin
  LVisible := False;
  LReg := TRegistry.Create;
  try
    LReg.RootKey := HKEY_CURRENT_USER;
    LRegPath := TRadIAConfig.GetRegistryPath;
    if LReg.OpenKeyReadOnly(LRegPath) then
    begin
      if LReg.ValueExists('WindowVisible') then
        LVisible := LReg.ReadBool('WindowVisible');
      LReg.CloseKey;
    end;
  finally
    LReg.Free;
  end;

  if LVisible then
  begin
    LogDebug('Queueing window visibility restoration from registry');
    TThread.ForceQueue(
      nil,
      procedure
      begin
        if GIsShuttingDown then
          Exit;
        LogDebug('Applying deferred window visibility restoration');
        ShowRadIAChat;
      end
    );
  end;
end;

procedure RegisterRadIAResultStore;
var
  LResultStore: IRadIAAgentResultStore;
begin
  LResultStore := TRadIAAgentFileResultStore.Create(
    TPath.Combine(
      TPath.Combine(TPath.GetHomePath, 'RadIA'),
      'agent-results'
    )
  );
  try
    LResultStore.CleanupExpired;
  except
    on E: Exception do
      LogDebug('Result artifact cleanup skipped: ' + E.Message);
  end;
  TRadIAContainer.Register<IRadIAAgentResultStore>(LResultStore);
end;

procedure RegisterRadIABlockReviewSession;
var
  LBlockVisual: IRadIABlockReviewVisualFacade;
  LInlineVisual: IRadIAInlineReviewVisualFacade;
  LSession: IRadIABlockReviewSession;
begin
  LInlineVisual := TRadIAContainer.Resolve<IRadIAInlineReviewVisualFacade>;
  if not Supports(LInlineVisual, IRadIABlockReviewVisualFacade, LBlockVisual) then
    raise EInvalidCast.Create(
      'The inline review facade does not support block review rendering.'
    );
  LSession := TRadIABlockReviewSession.Create(
    TRadIAContainer.Resolve<IRadIAMultiFilePatchService>,
    LBlockVisual
  );
  TRadIAContainer.Register<IRadIABlockReviewSession>(LSession);
end;

procedure RegisterRadIAExternalMcpRuntime;
var
  LError: string;
  LRuntime: IRadIAExternalMcpRuntime;
begin
  LRuntime := TRadIAExternalMcpRuntime.Create(
    TRadIAExternalMcpSettingsStore.Create(
      TPath.Combine(
        TPath.Combine(TPath.GetHomePath, 'RadIA'),
        'external-mcp.settings'
      )
    ),
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAExternalMcpWorkspaceRootProvider.Create(
      TRadIAContainer.Resolve<IRadIAIDEAdapter>
    ),
    TRadIAWorkspaceBoundary.Create,
    TRadIAExternalMcpClientFactory.Create
  );
  TRadIAContainer.Register<IRadIAExternalMcpRuntime>(LRuntime);
  if not LRuntime.Refresh(LError) then
    LogDebug('External MCP runtime requires configuration attention.');
end;

initialization
  TRadIAContainer.Register<IRadIAConfig>(TRadIAConfig.GetInstance);
  TRadIAContainer.Register<IRadIALogger>(TConcreteLogger.Create);
  TLogger.SetActiveLogger(TRadIAContainer.Resolve<IRadIALogger>);
  TRadIAContainer.Register<IRadIAIDEAdapter>(TRadIAConcreteIDEAdapter.Create);
  TRadIAContainer.Register<IRadIAEditorAdapter>(TRadIAOTAEditorAdapter.Create);
  TRadIAContainer.Register<IRadIAJourneyContextCoordinator>(
    TRadIAJourneyContextCoordinator.Create
  );
  TRadIAContainer.Register<IRadIAHierarchicalSettingsStore>(
    TRadIAJsonHierarchicalSettingsStore.Create
  );
  TRadIAContainer.Register<IRadIAToolRegistry>(TRadIAToolRegistry.Create);
  TRadIAContainer.Register<IRadIAResultCompactor>(
    TRadIAResultCompactor.Create
  );
  RegisterRadIAResultStore;
  TRadIAContainer.Register<IRadIAToolExtensionHost>(
    TRadIAToolExtensionHost.Create(
      TRadIAContainer.Resolve<IRadIAToolRegistry>
    )
  );
  SetRadIAToolExtensionHost(
    TRadIAContainer.Resolve<IRadIAToolExtensionHost>
  );
  TRadIAContainer.Register<IRadIASecretRedactor>(
    TRadIASecretRedactor.Create
  );
  TRadIAContainer.Register<IRadIAConsentProvider>(
    TRadIAOTAConsentProvider.Create(
      0,
      TRadIAContainer.Resolve<IRadIAConfig>,
      TRadIAContainer.Resolve<IRadIASecretRedactor>,
      nil
    )
  );
  TRadIAContainer.Register<IRadIAToolAuditSink>(
    TRadIAJsonLinesToolAuditSink.Create(
      TPath.Combine(
        TPath.Combine(TPath.GetHomePath, 'RadIA'),
        'audit\tools.jsonl'
      )
    )
  );
  TRadIAContainer.Register<IRadIAToolExecutor>(
    TRadIAToolPolicyExecutor.Create(
      TRadIAContainer.Resolve<IRadIAToolRegistry>,
      TRadIAToolExecutor.Create(
        TRadIAContainer.Resolve<IRadIAToolRegistry>
      ),
      TRadIAContainer.Resolve<IRadIAConsentProvider>,
      TRadIAContainer.Resolve<IRadIAToolAuditSink>,
      TRadIAContainer.Resolve<IRadIASecretRedactor>
    ) as IRadIAToolExecutor
  );
  TRadIAContainer.Register<IRadIAToolPolicyExecutor>(
    TRadIAContainer.Resolve<IRadIAToolExecutor> as
      IRadIAToolPolicyExecutor
  );
  TRadIAContainer.Register<IRadIAToolAuthorizationPolicy>(
    TRadIAContainer.Resolve<IRadIAToolExecutor> as
      IRadIAToolAuthorizationPolicy
  );
  TRadIAContainer.Register<IRadIAWorkspaceFacade>(
    TRadIAOTAWorkspaceFacade.Create(
      TRadIAContainer.Resolve<IRadIAIDEAdapter>,
      TRadIAContainer.Resolve<IRadIAEditorAdapter>
    )
  );
  TRadIAContainer.Register<IRadIAEditorMutationFacade>(
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade> as
      IRadIAEditorMutationFacade
  );
  TRadIAContainer.Register<IRadIAEditorPersistenceFacade>(
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade> as
      IRadIAEditorPersistenceFacade
  );
  TRadIAContainer.Register<IRadIAFormDesignerFacade>(
    TRadIAOTAFormDesignerFacade.Create
  );
  TRadIAContainer.Register<IRadIAFormDesignerMutationFacade>(
    TRadIAContainer.Resolve<IRadIAFormDesignerFacade> as
      IRadIAFormDesignerMutationFacade
  );
  TRadIAContainer.Register<IRadIAFormDesignerComponentFacade>(
    TRadIAContainer.Resolve<IRadIAFormDesignerFacade> as
      IRadIAFormDesignerComponentFacade
  );
  TRadIAContainer.Register<IRadIAFormDesignerEventFacade>(
    TRadIAContainer.Resolve<IRadIAFormDesignerFacade> as
      IRadIAFormDesignerEventFacade
  );
  TRadIAContainer.Register<IRadIAFormEventService>(
    TRadIAFormEventService.Create(
      TRadIAContainer.Resolve<IRadIAFormDesignerEventFacade>
    )
  );
  TRadIAContainer.Register<IRadIAComponentChangeService>(
    TRadIAComponentChangeService.Create(
      TRadIAContainer.Resolve<IRadIAFormDesignerComponentFacade>
    )
  );
  TRadIAContainer.Register<IRadIAComponentLayoutService>(
    TRadIAComponentLayoutService.Create(
      TRadIAContainer.Resolve<IRadIAFormDesignerMutationFacade>
    )
  );
  TRadIAContainer.Register<IRadIAComponentPropertyService>(
    TRadIAComponentPropertyService.Create(
      TRadIAContainer.Resolve<IRadIAFormDesignerMutationFacade>
    )
  );
  TRadIAContainer.Register<IRadIADebuggerFacade>(
    TRadIAOTADebuggerFacade.Create
  );
  TRadIAContainer.Register<IRadIAIDENavigationFacade>(
    TRadIAOTAIDENavigationFacade.Create(
      TRadIAContainer.Resolve<IRadIAEditorAdapter>
    )
  );
  TRadIAContainer.Register<IRadIADebuggerControlFacade>(
    TRadIAContainer.Resolve<IRadIADebuggerFacade> as
      IRadIADebuggerControlFacade
  );
  TRadIAContainer.Register<IRadIADebuggerBreakpointFacade>(
    TRadIAContainer.Resolve<IRadIADebuggerFacade> as
      IRadIADebuggerBreakpointFacade
  );
  TRadIAContainer.Register<IRadIADebuggerEvaluationFacade>(
    TRadIAContainer.Resolve<IRadIADebuggerFacade> as
      IRadIADebuggerEvaluationFacade
  );
  TRadIAContainer.Register<IRadIADebuggerSessionFacade>(
    TRadIAContainer.Resolve<IRadIADebuggerFacade> as
      IRadIADebuggerSessionFacade
  );
  TRadIAContainer.Register<IRadIADebuggerWatchService>(
    TRadIADebuggerWatchService.Create(
      TRadIAContainer.Resolve<IRadIADebuggerEvaluationFacade>
    )
  );
  TRadIAContainer.Register<IRadIAWorkspaceBoundary>(
    TRadIAWorkspaceBoundary.Create
  );
  TRadIAContainer.Register<IRadIADebugTimelineStore>(
    TRadIAOTADebugTimelineStore.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>
    )
  );
  TRadIAContainer.Register<IRadIADebugTimeline>(
    TRadIADebugTimeline.Create(
      500,
      TRadIAContainer.Resolve<IRadIADebugTimelineStore>
    )
  );
  TRadIAContainer.Register<IRadIARuntimeDebugSessionCoordinator>(
    TRadIARuntimeDebugSessionCoordinator.Create
  );
  TRadIAContainer.Register<IRadIARuntimeDiscoveryFacade>(
    TRadIAWindowsRuntimeDiscoveryFacade.Create
  );
  TRadIAContainer.Register<IRadIARuntimeActionFacade>(
    TRadIAContainer.Resolve<IRadIARuntimeDiscoveryFacade> as
      IRadIARuntimeActionFacade
  );
  TRadIAContainer.Register<IRadIARuntimeVisualCaptureFacade>(
    TRadIAContainer.Resolve<IRadIARuntimeDiscoveryFacade> as
      IRadIARuntimeVisualCaptureFacade
  );
  TRadIAContainer.Register<IRadIAVisualRuntimeSession>(
    TRadIAVisualRuntimeSession.Create
  );
  TRadIAContainer.Register<IRadIARuntimeScenarioCoordinator>(
    TRadIARuntimeScenarioCoordinator.Create(
      TRadIAContainer.Resolve<IRadIARuntimeActionFacade>,
      TRadIAContainer.Resolve<IRadIAVisualRuntimeSession> as
        IRadIARuntimeScenarioEventSink
    )
  );
  TRadIAContainer.Register<IRadIARuntimeEvidenceCoordinator>(
    TRadIARuntimeEvidenceCoordinator.Create(
      TRadIAContainer.Resolve<IRadIARuntimeDebugSessionCoordinator>,
      TRadIAContainer.Resolve<IRadIARuntimeScenarioCoordinator>,
      TRadIAContainer.Resolve<IRadIADebuggerFacade>,
      TRadIAContainer.Resolve<IRadIADebuggerEvaluationFacade>,
      TRadIAContainer.Resolve<IRadIASecretRedactor>
    )
  );
  TRadIAContainer.Register<IRadIARuntimeRegressionCoordinator>(
    TRadIARuntimeRegressionCoordinator.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>,
      TRadIAContainer.Resolve<IRadIASecretRedactor>
    )
  );
  TRadIAContainer.Register<IRadIAKnowledgeSource>(
    TRadIAConfigurableKnowledgeSource.Create(
      TRadIAConfig.GetInstance,
      TRadIAApprovedHistoryKnowledgeSource.Create(
        TRadIAConfig.GetInstance,
        TRadIAOTAKnowledgeSource.Create(
          TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
          TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>
        ),
        TPath.Combine(
          TPath.Combine(TPath.GetHomePath, 'RadIA'),
          'agent-checkpoints'
        )
      )
    )
  );
  TRadIAContainer.Register<IRadIAKnowledgeStore>(
    TRadIAJsonKnowledgeStore.Create(
      TPath.Combine(
        TPath.Combine(TPath.GetHomePath, 'RadIA'),
        'Knowledge'
      )
    )
  );
  TRadIAContainer.Register<IRadIAKnowledgeService>(
    TRadIAConfigurableKnowledgeService.Create(
      TRadIAConfig.GetInstance,
      TRadIALocalKnowledgeService.Create(
        TRadIAContainer.Resolve<IRadIAKnowledgeSource>,
        TRadIAContainer.Resolve<IRadIAKnowledgeStore>,
        TRadIAConfigurableKnowledgeEmbeddingProvider.Create(
          TRadIAConfig.GetInstance,
          TRadIAKnowledgeEmbeddingSelector.Create(
            TRadIALocalHashEmbeddingProvider.Create,
            TRadIARemoteKnowledgeSettings.Create
          )
        )
      )
    )
  );
  TRadIAContainer.Register<IRadIAKnowledgeRefreshScheduler>(
    TRadIAKnowledgeRefreshScheduler.Create(
      TRadIAContainer.Resolve<IRadIAKnowledgeService>
    )
  );
  TRadIAContainer.Register<IRadIAPatchService>(
    TRadIAPatchService.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAEditorMutationFacade>,
      TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>
    )
  );
  TRadIAContainer.Register<IRadIAMemoryInstrumentationCoordinator>(
    TRadIAMemoryInstrumentationCoordinator.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAEditorMutationFacade>,
      TRadIAContainer.Resolve<IRadIAIDENavigationFacade>,
      TRadIAContainer.Resolve<IRadIAPatchService>
    )
  );
  TRadIAContainer.Register<IRadIAInlineReviewVisualFacade>(
    TRadIAOTAInlineReviewFacade.Create
  );
  TRadIAContainer.Register<IRadIAInlineReviewService>(
    TRadIAInlineReviewService.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>,
      TRadIAContainer.Resolve<IRadIAPatchService>,
      TRadIAContainer.Resolve<IRadIAInlineReviewVisualFacade>
    )
  );
  TRadIAContainer.Register<IRadIABuildFacade>(
    TRadIAOTABuildFacade.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>
    )
  );
  TRadIAContainer.Register<IRadIAMemoryDiagnosticSessionCoordinator>(
    TRadIAMemoryDiagnosticSessionCoordinator.Create(
      TRadIAMemoryDiagnosticSessionDependencies.Create(
        TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
        TRadIAContainer.Resolve<IRadIAMemoryInstrumentationCoordinator>,
        TRadIAContainer.Resolve<IRadIABuildFacade>,
        TRadIAContainer.Resolve<IRadIADebuggerSessionFacade>,
        TRadIAContainer.Resolve<IRadIARuntimeDebugSessionCoordinator>,
        TRadIAContainer.Resolve<IRadIARuntimeScenarioCoordinator>
      )
    )
  );
  TRadIAContainer.Register<IRadIADUnitXRunner>(
    TRadIAOTADUnitXRunner.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>
    )
  );
  TRadIAContainer.Register<IRadIAGitFacade>(
    TRadIAOTAGitFacade.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>
    )
  );
  TRadIAContainer.Register<IRadIAMultiFilePatchService>(
    TRadIAMultiFilePatchService.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAEditorMutationFacade>,
      TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>
    )
  );
  RegisterRadIABlockReviewSession;
  TRadIAContainer.Register<IRadIAProjectOpeningFacade>(
    TRadIAOTAProjectOpeningFacade.Create
  );
  TRadIAContainer.Register<IRadIAProjectFileFacade>(
    TRadIAOTAProjectFileFacade.Create
  );
  TRadIAContainer.Register<IRadIAProjectFileService>(
    TRadIAProjectFileService.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>,
      TRadIAContainer.Resolve<IRadIAProjectFileFacade>
    )
  );
  TRadIAContainer.Register<IRadIADevelopmentOperationAdapter>(
    TRadIADevelopmentOperationAdapter.Create(
      TRadIAContainer.Resolve<IRadIAMultiFilePatchService>,
      TRadIAContainer.Resolve<IRadIAProjectFileService>,
      TRadIAContainer.Resolve<IRadIAComponentChangeService>,
      TRadIAContainer.Resolve<IRadIAComponentLayoutService>,
      TRadIAContainer.Resolve<IRadIAComponentPropertyService>,
      TRadIAContainer.Resolve<IRadIAFormEventService>
    )
  );
  TRadIAContainer.Register<IRadIADevelopmentTransactionService>(
    TRadIADevelopmentTransactionService.Create(
      TRadIAContainer.Resolve<IRadIADevelopmentOperationAdapter>
    )
  );
  TRadIAContainer.Register<IRadIAProjectTemplateService>(
    TRadIAProjectTemplateService.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>,
      TRadIAContainer.Resolve<IRadIAProjectOpeningFacade>
    )
  );
  TRadIAContainer.Register<IRadIAAuthorizedProjectTemplateService>(
    TRadIAContainer.Resolve<IRadIAProjectTemplateService> as
      IRadIAAuthorizedProjectTemplateService
  );
  TRadIAContainer.Register<IRadIADelphiEnvironmentService>(
    TRadIADelphiEnvironmentService.Create(
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>
    )
  );
  TRadIAContainer.Register<IRadIADelphiGuidanceCatalog>(
    TRadIADelphiGuidanceCatalog.Create
  );
  TRadIAContainer.Register<IRadIADfmPasAuditor>(
    TRadIADfmPasAuditor.Create
  );
  TRadIAContainer.Register<IRadIADesignerVisualDiffService>(
    TRadIADesignerVisualDiffService.Create(
      TRadIAContainer.Resolve<IRadIAFormDesignerFacade>
    )
  );
  RegisterRadIAWorkspaceTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade>
  );
  RegisterRadIADelphiEnvironmentTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADelphiEnvironmentService>
  );
  RegisterRadIADelphiGuidanceTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADelphiGuidanceCatalog>
  );
  RegisterRadIADelphiMentorTool(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
    TRadIAContainer.Resolve<IRadIADelphiGuidanceCatalog>
  );
  RegisterRadIADfmPasAuditTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAFormDesignerFacade>,
    TRadIAContainer.Resolve<IRadIAEditorMutationFacade>,
    TRadIAContainer.Resolve<IRadIADfmPasAuditor>,
    TRadIAContainer.Resolve<IRadIAPatchService>
  );
  RegisterRadIADesignerVisualDiffTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADesignerVisualDiffService>
  );
  RegisterRadIAAgentResultTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAAgentResultStore>
  );
  RegisterRadIAIDENavigationTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAIDENavigationFacade>
  );
  RegisterRadIAProjectTemplateTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAProjectTemplateService>,
    TRadIAContainer.Resolve<IRadIABuildFacade>
  );
  RegisterRadIAProjectFileTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAProjectFileService>
  );
  RegisterRadIAPatchTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAPatchService>,
    TRadIAContainer.Resolve<IRadIABlockReviewSession>
  );
  RegisterRadIAMemoryInstrumentationTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAMemoryInstrumentationCoordinator>
  );
  RegisterRadIAFastMM5LogTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
    TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>
  );
  RegisterRadIAMemoryDiagnosticSessionTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAMemoryDiagnosticSessionCoordinator>,
    TRadIAContainer.Resolve<IRadIARuntimeDebugSessionCoordinator>,
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade>
  );
  RegisterRadIAMemoryEvidenceTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAMemoryEvidenceService.Create
  );
  RegisterRadIAMultiFilePatchTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAMultiFilePatchService>,
    TRadIAContainer.Resolve<IRadIABlockReviewSession>
  );
  RegisterRadIALegacyDataMigrationTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
    TRadIAContainer.Resolve<IRadIAEditorMutationFacade>,
    TRadIAContainer.Resolve<IRadIAMultiFilePatchService>
  );
  RegisterRadIABlockReviewTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIABlockReviewSession>
  );
  RegisterRadIADevelopmentTransactionTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADevelopmentTransactionService>
  );
  RegisterRadIAInlineReviewTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAInlineReviewService>
  );
  RegisterRadIABuildTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIABuildFacade>
  );
  RegisterRadIADUnitXTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADUnitXRunner>
  );
  RegisterRadIACoverageTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
    TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>
  );
  RegisterRadIAGitTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAGitFacade>
  );
  RegisterRadIADesignerTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAFormDesignerFacade>
  );
  RegisterRadIADesignerMutationTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAComponentLayoutService>
  );
  RegisterRadIADesignerPropertyTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAComponentPropertyService>
  );
  RegisterRadIADesignerComponentTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAComponentChangeService>
  );
  RegisterRadIADesignerEventTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAFormEventService>
  );
  RegisterRadIADebuggerTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADebuggerFacade>
  );
  RegisterRadIADebuggerControlTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADebuggerControlFacade>
  );
  RegisterRadIADebuggerBreakpointTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADebuggerBreakpointFacade>,
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
    TRadIAContainer.Resolve<IRadIAWorkspaceBoundary>
  );
  RegisterRadIADebuggerInspectionTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADebuggerEvaluationFacade>,
    TRadIAContainer.Resolve<IRadIADebuggerWatchService>,
    TRadIAContainer.Resolve<IRadIADebuggerSessionFacade>
  );
  RegisterRadIADebugTimelineTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIADebugTimeline>
  );
  RegisterRadIARuntimeDebugTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIARuntimeDebugSessionCoordinator>,
    TRadIAContainer.Resolve<IRadIADebuggerFacade>
  );
  RegisterRadIARuntimeDiscoveryTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIARuntimeDebugSessionCoordinator>,
    TRadIAContainer.Resolve<IRadIARuntimeDiscoveryFacade>
  );
  RegisterRadIARuntimeVisualTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIARuntimeDebugSessionCoordinator>,
    TRadIAContainer.Resolve<IRadIARuntimeVisualCaptureFacade>,
    TRadIAContainer.Resolve<IRadIAVisualRuntimeSession>
  );
  RegisterRadIARuntimeScenarioTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIARuntimeDebugSessionCoordinator>,
    TRadIAContainer.Resolve<IRadIARuntimeScenarioCoordinator>
  );
  RegisterRadIARuntimeEvidenceTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIARuntimeEvidenceCoordinator>
  );
  RegisterRadIARuntimeRegressionTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIARuntimeRegressionCoordinator>,
    TRadIAContainer.Resolve<IRadIARuntimeDebugSessionCoordinator>,
    TRadIAContainer.Resolve<IRadIARuntimeScenarioCoordinator>
  );
  RegisterRadIAKnowledgeTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAKnowledgeService>
  );
  RegisterRadIAProjectHealthTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
    TRadIAContainer.Resolve<IRadIABuildFacade>,
    TRadIAContainer.Resolve<IRadIADUnitXRunner>,
    TRadIAContainer.Resolve<IRadIAKnowledgeService>
  );
  RegisterRadIAExternalMcpRuntime;
  RegisterRadIAInstallationHealthTools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>,
    TRadIAInstallationHealthProbe.Create(
      TRadIAConfig.GetInstance,
      TPath.Combine(
        GetRadIAModuleDirectory,
        'RadIA.MCP.Bridge.exe'
      ),
      TPath.Combine(
        TPath.Combine(TPath.GetHomePath, 'RadIA'),
        'Web'
      ),
      TRadIAContainer.Resolve<IRadIAToolRegistry>,
      TRadIAContainer.Resolve<IRadIAExternalMcpRuntime>
    )
  );
  RegisterRadIAFastMM5Tools(
    TRadIAContainer.Resolve<IRadIAToolRegistry>
  );
  TRadIAContainer.Register<IRadIAMcpProtocol>(
    TRadIAMcpProtocol.Create(
      TRadIAContainer.Resolve<IRadIAToolRegistry>,
      TRadIAContainer.Resolve<IRadIAToolExecutor>
    )
  );
  TRadIAContainer.Register<IRadIAMcpServer>(
    TRadIANamedPipeMcpServer.Create(
      TRadIAContainer.Resolve<IRadIAMcpProtocol>,
      TRadIAContainer.Resolve<IRadIAWorkspaceFacade>,
      TPath.Combine(
        TPath.Combine(TPath.GetHomePath, 'RadIA'),
        'mcp.json'
      )
    )
  );
  GMcpServer := TRadIAContainer.Resolve<IRadIAMcpServer>;
  GMcpServer.Start;
  TRadIAContainer.Register<IRadIAService>(TRadIAService.Create(TRadIAContainer.Resolve<IRadIAConfig>));
  TRadIAContainer.Register<IRadIAInlineCompletionProvider>(
    TRadIAServiceInlineCompletionProvider.Create(
      TRadIAContainer.Resolve<IRadIAService>,
      TRadIAContainer.Resolve<IRadIAConfig>,
      30000
    )
  );
  TRadIAContainer.Register<IRadIATextNormalizer>(TRadIATextNormalizer.Create);
  TRadIAContainer.Register<IRadIAMediator>(TRadIAMediator.Instance);
  TRadIAContainer.Register<IRadIADTOBuilder>(TRadIADTOBuilder.Create);
  TRadIAContainer.Register<IRadIAProjectGenerator>(TRadIAProjectGenerator.Create);
  TRadIAContainer.Register<IRadIAHttpClient>(TRadIAConcreteHttpClient.Create);
  TRadIAContainer.Register<IRadIAErrorDecoder>(TRadIAErrorDecoder.Create);
  TRadIAContainer.Register<IRadIALocalizer>(TRadIALocalizer.Create);
  StartRadIAAgentRuntimeDiagnosticIfRequested;
  StartRadIADeclarativeWorkflowDiagnosticIfRequested;
  StartRadIAMemoryDiagnosticIfRequested;

finalization
  if not GIsShuttingDown then
  begin
    SetRadIAToolExtensionHost(nil);
    if Assigned(GMcpServer) then
      GMcpServer.Stop;
    GMcpServer := nil;
    TLogger.SetActiveLogger(nil);
    TRadIAContainer.Clear;
  end;

end.
