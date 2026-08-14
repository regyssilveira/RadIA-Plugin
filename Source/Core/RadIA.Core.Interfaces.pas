unit RadIA.Core.Interfaces;

interface

uses
  System.SysUtils, System.Net.URLClient,
  RadIA.Core.Cache,
  RadIA.Core.Types, RadIA.Core.TokenUsage,
  RadIA.Core.HierarchicalSettings;

type
  IRadIALifecycleGuard = interface
    ['{F4EED9A6-6CBA-43B6-9E39-1E38AA2C7301}']
    function GetIsAlive: Boolean;
    procedure Invalidate;
    property IsAlive: Boolean read GetIsAlive;
  end;

  TLifecycleGuard = class(TInterfacedObject, IRadIALifecycleGuard)
  private
    FIsAlive: Boolean;
    function GetIsAlive: Boolean;
  public
    constructor Create;
    procedure Invalidate;
  end;

  IRadIALogger = interface
    ['{E8FD28D3-874C-40BD-BBDF-3FE573F4F138}']
    procedure Log(const AMsg: string; const ATag: string = 'Debug');
    procedure Configure(const AEnabled: Boolean; const APath: string; const AMaxSizeKB: Integer);
  end;

  { Callback type for asynchronous AI responses.
    AResponse   : Text returned by the AI (empty on error)
    AError      : Error description (empty on success)
    AFromCache  : True when the response was served from local cache
    AUsage      : Token counters (may be empty for providers that do not report usage) }
  TCompletionCallback = reference to procedure(
    const AResponse: string;
    const AError: string;
    AFromCache: Boolean;
    const AUsage: TTokenUsage);

  { Callback type for incremental streaming of AI responses }
  TStreamChunkCallback = reference to procedure(
    const AChunk: string;
    const AIsDone: Boolean;
    const AError: string);

  { Callback function for loopback server events }
  TLoopbackCallback = reference to procedure(const ACode: string; const AError: string);

  { Interface defining the local loopback HTTP server for OAuth callbacks }
  IRadIALoopbackServer = interface
    ['{E27C9482-1D5B-4C6C-81AB-C096BA6277FF}']
    procedure Start(const APort: Word; const ACallback: TLoopbackCallback);
    procedure Stop;
    function GetActivePort: Word;
    function IsRunning: Boolean;
  end;


  { Interface representing a message in the chat history }
  IRadIAChatMessage = interface
    ['{69A8A5DC-0F88-46E1-AD7A-8A46101EA97D}']
    function GetRole: TAIMessageRole;
    function GetContent: string;
    procedure SetContent(const AValue: string);
    function GetProvider: string;
    procedure SetProvider(const AValue: string);
    function GetModel: string;
    procedure SetModel(const AValue: string);
    property Role: TAIMessageRole read GetRole;
    property Content: string read GetContent write SetContent;
    property Provider: string read GetProvider write SetProvider;
    property Model: string read GetModel write SetModel;
  end;

  { Interface representing an AI Provider }
  IRadIAProvider = interface
    ['{A2833F50-9A0B-432D-8B8D-20DFF15FF25D}']
    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer);
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer);
    procedure FetchAvailableModelsAsync(const ACallback: TProc<TArray<string>, string>);
    function GetAvailableModels: TArray<string>;
    function GetName: string;
    function GetProviderId: string;
    procedure CancelCurrentRequest;
  end;

  { Interface representing Configuration Management }
  IRadIAConfig = interface
    ['{88A9678F-520E-4BF5-BFB4-5C04A5826A6F}']
    function GetActiveProvider: string;
    procedure SetActiveProvider(const AProvider: string);
    function GetSystemPrompt: string;
    procedure SetSystemPrompt(const AValue: string);
    function GetOllamaBaseUrl: string;
    procedure SetOllamaBaseUrl(const AValue: string);
    function GetMaxHistoryMessages: Integer;
    procedure SetMaxHistoryMessages(const AValue: Integer);
    function GetOpenAICustomBaseUrl: string;
    procedure SetOpenAICustomBaseUrl(const AValue: string);

    { String-based dynamic provider APIs }
    function GetApiKey(const AProviderName: string): string;
    procedure SetApiKey(const AProviderName: string; const AKey: string);
    function GetActiveModel(const AProviderName: string): string;
    procedure SetActiveModel(const AProviderName: string; const AModel: string);
    function GetTemperature(const AProviderName: string): Double;
    procedure SetTemperature(const AProviderName: string; const AValue: Double);
    function GetMaxTokens(const AProviderName: string): Integer;
    procedure SetMaxTokens(const AProviderName: string; const AValue: Integer);
    function GetTimeout(const AProviderName: string): Integer;
    procedure SetTimeout(const AProviderName: string; const AValue: Integer);
    function GetProviderBaseUrl(const AProviderName: string): string;
    procedure SetProviderBaseUrl(const AProviderName: string; const AUrl: string);
    function GetProviderAuthType(const AProviderName: string): string;
    procedure SetProviderAuthType(const AProviderName: string; const AValue: string);

    function GetAutocompleteEnabled: Boolean;
    procedure SetAutocompleteEnabled(const AValue: Boolean);
    function GetAutocompleteProvider: string;
    procedure SetAutocompleteProvider(const AProvider: string);
    function GetAutocompleteModel: string;
    procedure SetAutocompleteModel(const AModel: string);
    function GetAutocompleteDelay: Integer;
    procedure SetAutocompleteDelay(const AValue: Integer);
    function GetAutocompleteExcludedFiles: string;
    procedure SetAutocompleteExcludedFiles(const AValue: string);
    function GetAutocompleteExcludedLanguages: string;
    procedure SetAutocompleteExcludedLanguages(const AValue: string);
    function GetAutocompleteExcludedProjects: string;
    procedure SetAutocompleteExcludedProjects(const AValue: string);
    function GetKnowledgeSemanticEnabled: Boolean;
    procedure SetKnowledgeSemanticEnabled(const AValue: Boolean);
    function GetKnowledgeApprovedHistoryEnabled: Boolean;
    procedure SetKnowledgeApprovedHistoryEnabled(const AValue: Boolean);
    function GetKnowledgeExcludedFiles: string;
    procedure SetKnowledgeExcludedFiles(const AValue: string);
    function GetKnowledgeExcludedProjects: string;
    procedure SetKnowledgeExcludedProjects(const AValue: string);

    function GetSmartConfigEnabled: Boolean;
    procedure SetSmartConfigEnabled(const AValue: Boolean);
    function GetLogEnabled: Boolean;
    procedure SetLogEnabled(const AValue: Boolean);
    function GetLogPath: string;
    procedure SetLogPath(const AValue: string);
    function GetLogMaxSizeKB: Integer;
    procedure SetLogMaxSizeKB(const AValue: Integer);
    function GetQuotaEnabled: Boolean;
    procedure SetQuotaEnabled(const AValue: Boolean);
    function GetQuotaLimit: Int64;
    procedure SetQuotaLimit(const AValue: Int64);
    function GetQuotaUsed: Int64;
    procedure SetQuotaUsed(const AValue: Int64);
    function GetQuotaCycleStart: TDateTime;
    procedure SetQuotaCycleStart(const AValue: TDateTime);
    function GetActiveSessionId: string;
    procedure SetActiveSessionId(const AValue: string);
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
    function GetInjectDelphiVersion: Boolean;
    procedure SetInjectDelphiVersion(const AValue: Boolean);
    function GetConciseResponses: Boolean;
    procedure SetConciseResponses(const AValue: Boolean);
    function GetConsentTimeoutSeconds: Integer;
    procedure SetConsentTimeoutSeconds(const AValue: Integer);
    function GetConsentShowArguments: Boolean;
    procedure SetConsentShowArguments(const AValue: Boolean);
    function GetConsentRememberReversible: Boolean;
    procedure SetConsentRememberReversible(const AValue: Boolean);
    function GetConsentRememberStructural: Boolean;
    procedure SetConsentRememberStructural(const AValue: Boolean);
    function GetConsentRememberExecution: Boolean;
    procedure SetConsentRememberExecution(const AValue: Boolean);
    procedure AddToQuotaUsage(const AUsage: TTokenUsage);
    procedure Save;
    procedure Load;
    function IsWebLoginProvider(const AProviderName: string): Boolean;
    function GetOAuthAccessToken(const AProviderName: string): string;
    procedure SetOAuthAccessToken(const AProviderName: string; const AValue: string);
    procedure ClearOAuthTokens(const AProviderName: string);
    function GetOAuthRefreshToken(const AProviderName: string): string;
    procedure SetOAuthRefreshToken(const AProviderName: string; const AValue: string);
    function GetOAuthTokenExpiry(const AProviderName: string): TDateTime;
    procedure SetOAuthTokenExpiry(const AProviderName: string; const AValue: TDateTime);
    property SystemPrompt: string read GetSystemPrompt write SetSystemPrompt;
    property OllamaBaseUrl: string read GetOllamaBaseUrl write SetOllamaBaseUrl;
    property MaxHistoryMessages: Integer read GetMaxHistoryMessages write SetMaxHistoryMessages;
    property OpenAICustomBaseUrl: string read GetOpenAICustomBaseUrl write SetOpenAICustomBaseUrl;
    property AzureApiVersion: string read GetAzureApiVersion write SetAzureApiVersion;
    property AwsAccessKeyId: string read GetAwsAccessKeyId write SetAwsAccessKeyId;
    property AwsSecretAccessKey: string read GetAwsSecretAccessKey write SetAwsSecretAccessKey;
    property AwsRegion: string read GetAwsRegion write SetAwsRegion;
    property AwsSessionToken: string read GetAwsSessionToken write SetAwsSessionToken;
    property AutocompleteEnabled: Boolean read GetAutocompleteEnabled write SetAutocompleteEnabled;
    property AutocompleteProvider: string read GetAutocompleteProvider write SetAutocompleteProvider;
    property AutocompleteModel: string read GetAutocompleteModel write SetAutocompleteModel;
    property AutocompleteDelay: Integer read GetAutocompleteDelay write SetAutocompleteDelay;
    property AutocompleteExcludedFiles: string
      read GetAutocompleteExcludedFiles write SetAutocompleteExcludedFiles;
    property AutocompleteExcludedLanguages: string
      read GetAutocompleteExcludedLanguages write SetAutocompleteExcludedLanguages;
    property AutocompleteExcludedProjects: string
      read GetAutocompleteExcludedProjects write SetAutocompleteExcludedProjects;
    property KnowledgeSemanticEnabled: Boolean
      read GetKnowledgeSemanticEnabled write SetKnowledgeSemanticEnabled;
    property KnowledgeApprovedHistoryEnabled: Boolean
      read GetKnowledgeApprovedHistoryEnabled
      write SetKnowledgeApprovedHistoryEnabled;
    property KnowledgeExcludedFiles: string
      read GetKnowledgeExcludedFiles write SetKnowledgeExcludedFiles;
    property KnowledgeExcludedProjects: string
      read GetKnowledgeExcludedProjects write SetKnowledgeExcludedProjects;
    property SmartConfigEnabled: Boolean read GetSmartConfigEnabled write SetSmartConfigEnabled;
    property LogEnabled: Boolean read GetLogEnabled write SetLogEnabled;
    property LogPath: string read GetLogPath write SetLogPath;
    property LogMaxSizeKB: Integer read GetLogMaxSizeKB write SetLogMaxSizeKB;
    property QuotaEnabled: Boolean read GetQuotaEnabled write SetQuotaEnabled;
    property QuotaLimit: Int64 read GetQuotaLimit write SetQuotaLimit;
    property QuotaUsed: Int64 read GetQuotaUsed write SetQuotaUsed;
    property QuotaCycleStart: TDateTime read GetQuotaCycleStart write SetQuotaCycleStart;
    property ActiveSessionId: string read GetActiveSessionId write SetActiveSessionId;
    property InjectDelphiVersion: Boolean read GetInjectDelphiVersion write SetInjectDelphiVersion;
    property ConciseResponses: Boolean read GetConciseResponses write SetConciseResponses;
    property ConsentTimeoutSeconds: Integer
      read GetConsentTimeoutSeconds write SetConsentTimeoutSeconds;
    property ConsentShowArguments: Boolean
      read GetConsentShowArguments write SetConsentShowArguments;
    property ConsentRememberReversible: Boolean
      read GetConsentRememberReversible write SetConsentRememberReversible;
    property ConsentRememberStructural: Boolean
      read GetConsentRememberStructural write SetConsentRememberStructural;
    property ConsentRememberExecution: Boolean
      read GetConsentRememberExecution write SetConsentRememberExecution;
  end;

  IRadIAService = interface
    ['{6E7E91FB-E1AD-4A0B-971A-54F5E6CC3B4C}']
    function GetEffectiveSystemPrompt: string;
    procedure ResolveParameters(const AProviderName: string; const AProfile: TAIRequestProfile;
      out ATemperature: Double; out AMaxTokens: Integer);
    function CreateActiveProvider: IRadIAProvider;
    function TrimHistory(const AHistory: TArray<IRadIAChatMessage>): TArray<IRadIAChatMessage>;
    procedure SendPrompt(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const AProfile: TAIRequestProfile = rpGeneralChat);
    procedure SendPromptStream(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const AProfile: TAIRequestProfile = rpGeneralChat);
    procedure SendPromptStreamWithSettings(
      const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback;
      const AProfile: TAIRequestProfile;
      const ASettings: TRadIAExecutionSettings
    );
    procedure CancelCurrentRequest;
    procedure ClearCache;
    function ListCacheEntries: TArray<TRadIACacheEntrySnapshot>;
    function RemoveCacheEntry(const AHash: string): Boolean;
  end;

  IRadIAIDEAdapter = interface
    ['{20B2F2A9-4B52-4731-9BA0-4F296D4D1D41}']
    function GetActiveEditorText(out AText: string; const ASelectedOnly: Boolean = True): Boolean;
    function ReplaceActiveEditorText(const ANewText: string; const AReplaceWholeBuffer: Boolean = False;
      const AOriginalText: string = ''): Boolean;
    function InsertTextAtCursor(const AText: string): Boolean;
    function InsertTextAtLineColumn(const AText: string; const ALine, AColumn: Integer): Boolean;
    function GetCurrentCursorLine: Integer;
    function GetActiveUnitName: string;
    function GetActiveProjectName: string;
    function GetActiveProjectFolder: string;
    function OpenProjectInIDE(const AProjectPath: string): Boolean;
    function GetDelphiVersionName: string;
    function GetPreferredLanguageInstruction: string;
    function GetLastCompilerError(out AErrorMsg: string; out AFileName: string; out ALine: Integer): Boolean;
  end;

  IRadIAEditorAdapter = interface
    ['{8A4F1D72-E4BC-4A20-9D7A-7D15A20CE942}']
    function GetText: string;
    function GetSelectedText: string;
    procedure ReplaceSelection(const AText: string);
    procedure ReplaceText(const AOffset, ALength: Integer; const AText: string);
    procedure InsertText(const AText: string);
    procedure InsertTextAt(const ALine, AColumn: Integer; const AText: string);
    function GetCursorLine: Integer;
    function GetCursorColumn: Integer;
    procedure SetCursorPosition(const ALine, AColumn: Integer);
    function GetLineText(const ALine: Integer): string;
    function GetAutoIndent: Boolean;
    procedure SetAutoIndent(const AValue: Boolean);
    procedure RefreshView;
    function GetActiveUnitName: string;
    function GetActiveProjectName: string;
    function GetActiveProjectFolder: string;
    function OpenProject(const AProjectPath: string): Boolean;
  end;

  IRadIATextNormalizer = interface
    ['{E3FA7BCE-9FBA-4A2D-BE1E-D7C6FBFA9A2B}']
    function NormalizeLineBreaks(const AText: string): string;
  end;

  TOnRequestPromptProc = reference to procedure(const APrompt: string; const AOpenChat: Boolean);
  TOnRequestDiffProc   = reference to procedure(const AOriginalCode: string; const AReplaceWholeBuffer: Boolean);

  IRadIAMediator = interface
    ['{3C4D9E2B-0FEE-4AE2-9BE3-4F296D4D1D43}']
    procedure RegisterPromptHandler(const AHandler: TOnRequestPromptProc);
    procedure RegisterDiffHandler(const AHandler: TOnRequestDiffProc);
    procedure RequestPrompt(const APrompt: string; const AOpenChat: Boolean);
    procedure RequestDiff(const AOriginalCode: string; const AReplaceWholeBuffer: Boolean = False);
    procedure UnregisterPromptHandler;
    procedure UnregisterDiffHandler;
  end;

  IRadIADTOBuilder = interface
    ['{E12C8D9E-0FDA-4B2D-BE1E-D7C6FBFA9A2C}']
    function BuildPrompt(const AInput, AInputType, AOutputType: string): string;
  end;

  IRadIAProjectGenerator = interface
    ['{C28D9E3B-0FEA-4B2D-BE1E-D7C6FBFA9A2D}']
    function GenerateFromJSON(const AFilesJSON: string; out AErrorMsg: string; const ADestDir: string = ''): Boolean;
  end;

  ERadIAHttpException = class(Exception)
  private
    FStatusCode: Integer;
    FContent: string;
  public
    constructor Create(const AMessage: string; const AStatusCode: Integer; const AContent: string);
    property StatusCode: Integer read FStatusCode;
    property Content: string read FContent;
  end;

  IRadIAHttpClient = interface
    ['{7468E6A2-0FBE-4BD2-BE1E-D7C6FBFA9A2E}']
    function Get(const AUrl: string; const AHeaders: TNetHeaders; const ATimeoutMs: Integer = 0): string;
    function Post(const AUrl: string; const AHeaders: TNetHeaders; const ARequestBody: string;
        const ATimeoutMs: Integer = 0): string;
    procedure PostStream(const AUrl: string; const AHeaders: TNetHeaders; const ARequestBody: string;
      const AOnWrite: TProc<TBytes>; const ATimeoutMs: Integer = 0);
    procedure Cancel;
  end;

  IRadIAErrorDecoder = interface
    ['{E3FA7BCE-9FBA-4A2D-BE1E-D7C6FBFA9A2F}']
    function DecodeError(const AStatusCode: Integer; const AResponseContent: string): string;
  end;

  IRadIALocalizer = interface
    ['{F4EED9A6-6CBA-43B6-9E39-1E38AA2C7302}']
    function GetText(const AKey: string; const ADefault: string = ''): string;
    function GetLanguage: string;
    procedure SetLanguage(const ALang: string);
  end;

implementation

{ TLifecycleGuard }

constructor TLifecycleGuard.Create;
begin
  inherited Create;
  FIsAlive := True;
end;

function TLifecycleGuard.GetIsAlive: Boolean;
begin
  Result := FIsAlive;
end;

procedure TLifecycleGuard.Invalidate;
begin
  FIsAlive := False;
end;

{ ERadIAHttpException }

constructor ERadIAHttpException.Create(const AMessage: string; const AStatusCode: Integer; const AContent: string);
begin
  inherited Create(AMessage);
  FStatusCode := AStatusCode;
  FContent := AContent;
end;

end.
