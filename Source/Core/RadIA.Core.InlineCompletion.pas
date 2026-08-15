unit RadIA.Core.InlineCompletion;

interface

uses
  System.SysUtils,
  RadIA.Core.Interfaces,
  RadIA.Core.SemanticCompletion,
  RadIA.Core.SemanticQueries;

type
  TRadIAInlineGhostLine = record
  private
    FLineOffset: Integer;
    FText: string;
  public
    constructor Create(
      const ALineOffset: Integer;
      const AText: string
    );
    property LineOffset: Integer read FLineOffset;
    property Text: string read FText;
  end;

  TRadIAInlineGhostLayout = class
  public
    class function Build(
      const ASuggestion: string
    ): TArray<TRadIAInlineGhostLine>; static;
    class function TryGetLine(
      const ALines: TArray<TRadIAInlineGhostLine>;
      const ALineOffset: Integer;
      out ALine: TRadIAInlineGhostLine
    ): Boolean; static;
  end;

  TRadIAInlineCompletionContext = record
  private
    FFileName: string;
    FLanguage: string;
    FCursorColumn: Integer;
    FCursorLine: Integer;
    FPrefix: string;
    FProjectContext: string;
    FRevision: string;
    FSymbolName: string;
    FSuffix: string;
  public
    constructor Create(
      const AFileName: string;
      const ALanguage: string;
      const APrefix: string;
      const ASuffix: string;
      const ASymbolName: string;
      const AProjectContext: string;
      const ARevision: string
    );
    function CacheKey: string;
    function IsValid: Boolean;
    function Limited(const AMaxCharacters: Integer):
      TRadIAInlineCompletionContext;
    function WithCursor(
      const ALine: Integer;
      const AColumn: Integer
    ): TRadIAInlineCompletionContext;
    function WithProjectContext(
      const AProjectContext: string
    ): TRadIAInlineCompletionContext;
    property CursorColumn: Integer read FCursorColumn;
    property CursorLine: Integer read FCursorLine;
    property FileName: string read FFileName;
    property Language: string read FLanguage;
    property Prefix: string read FPrefix;
    property ProjectContext: string read FProjectContext;
    property Revision: string read FRevision;
    property SymbolName: string read FSymbolName;
    property Suffix: string read FSuffix;
  end;

  TRadIAInlineSemanticContextEnricher = class
  public
    class function Enrich(
      const AContext: TRadIAInlineCompletionContext;
      const ASemanticQueries: IRadIASemanticQueryService;
      const AMaxCharacters: Integer
    ): TRadIAInlineCompletionContext; static;
  end;

  TRadIAFimRouteKind = (
    frkSemanticLocal,
    frkDedicated,
    frkTraditionalFallback
  );

  TRadIAFimDiagnostic = record
  private
    FFallbackReason: string;
    FLatencyMs: Int64;
    FModelId: string;
    FProviderId: string;
    FRouteKind: TRadIAFimRouteKind;
  public
    constructor Create(
      const AProviderId: string;
      const AModelId: string;
      const ARouteKind: TRadIAFimRouteKind;
      const AFallbackReason: string;
      const ALatencyMs: Int64
    );
    function RouteName: string;
    property FallbackReason: string read FFallbackReason;
    property LatencyMs: Int64 read FLatencyMs;
    property ModelId: string read FModelId;
    property ProviderId: string read FProviderId;
  end;

  TRadIAFimCompletionCallback = reference to procedure(
    const AResponse: string;
    const AError: string
  );

  IRadIADedicatedFimProvider = interface
    ['{7A5D62B0-F99E-4A24-A06E-33746058A24D}']
    procedure SendFimAsync(
      const AContext: TRadIAInlineCompletionContext;
      const ACallback: TRadIAFimCompletionCallback;
      const AMaxTokens: Integer
    );
  end;

  IRadIAInlineCompletionDiagnostics = interface
    ['{27A28C3D-E286-436D-BE88-D9D061FCADCB}']
    function GetLastDiagnostic: TRadIAFimDiagnostic;
  end;

  TRadIAFimCapabilityDiscovery = class
  public
    class function TryResolve(
      const AProvider: IRadIAProvider;
      out AProviderContract: IRadIADedicatedFimProvider;
      out AFallbackReason: string
    ): Boolean; static;
  end;

  TRadIAInlineCompletionOptions = record
  private
    FDebounceMs: Cardinal;
    FMaxContextCharacters: Integer;
    FMaxSuggestionCharacters: Integer;
  public
    constructor Create(
      const ADebounceMs: Cardinal;
      const AMaxContextCharacters: Integer;
      const AMaxSuggestionCharacters: Integer
    );
    class function Default: TRadIAInlineCompletionOptions; static;
    property DebounceMs: Cardinal read FDebounceMs;
    property MaxContextCharacters: Integer read FMaxContextCharacters;
    property MaxSuggestionCharacters: Integer
      read FMaxSuggestionCharacters;
  end;

  TRadIAInlineCompletionPolicy = class
  private
    class function IsListed(
      const AValue: string;
      const AList: string;
      const AExactMatch: Boolean
    ): Boolean; static;
  public
    class function IsAllowed(
      const AContext: TRadIAInlineCompletionContext;
      const AExcludedLanguages: string;
      const AExcludedFiles: string;
      const AExcludedProjects: string
    ): Boolean; static;
  end;

  IRadIAInlineCompletionCancellationToken = interface
    ['{17FB756B-D196-4F4B-A53D-C3D2AF4EB875}']
    function IsCancellationRequested: Boolean;
  end;

  IRadIAInlineCompletionCancellationSource = interface(
    IRadIAInlineCompletionCancellationToken
  )
    ['{6C4C6B51-B4CE-45E5-9A02-773E857BD2A9}']
    procedure Cancel;
  end;

  IRadIAInlineCompletionProvider = interface
    ['{1F0C2DD1-2E24-46A4-8B92-199301C7D8EE}']
    function Complete(
      const AContext: TRadIAInlineCompletionContext;
      const ACancellation: IRadIAInlineCompletionCancellationToken
    ): string;
  end;

  TRadIAServiceInlineCompletionProvider = class(
    TInterfacedObject,
    IRadIAInlineCompletionProvider,
    IRadIAInlineCompletionDiagnostics
  )
  private
    FConfig: IRadIAConfig;
    FDiagnosticLock: TObject;
    FLastDiagnostic: TRadIAFimDiagnostic;
    FSemanticQueries: IRadIASemanticQueryService;
    FSemanticCompletion: IRadIASemanticCompletionService;
    FService: IRadIAService;
    FTimeoutMs: Cardinal;
    procedure Initialize(
      const AService: IRadIAService;
      const AConfig: IRadIAConfig;
      const ASemanticQueries: IRadIASemanticQueryService;
      const ASemanticCompletion: IRadIASemanticCompletionService;
      const ATimeoutMs: Cardinal
    );
    function CompleteWithProvider(
      const AContext: TRadIAInlineCompletionContext;
      const ACancellation: IRadIAInlineCompletionCancellationToken;
      const AProvider: IRadIAProvider;
      const AModelId: string;
      const AMaxTokens: Integer
    ): string;
    function CompleteWithSemanticIndex(
      const AContext: TRadIAInlineCompletionContext;
      const ACancellation: IRadIAInlineCompletionCancellationToken;
      out AHandled: Boolean
    ): string;
    procedure StoreDiagnostic(
      const ADiagnostic: TRadIAFimDiagnostic
    );
  public
    constructor Create(
      const AService: IRadIAService;
      const AConfig: IRadIAConfig;
      const ASemanticQueries: IRadIASemanticQueryService;
      const ASemanticCompletion: IRadIASemanticCompletionService;
      const ATimeoutMs: Cardinal
    );
    destructor Destroy; override;
    class function BuildPrompt(
      const AContext: TRadIAInlineCompletionContext
    ): string; static;
    function Complete(
      const AContext: TRadIAInlineCompletionContext;
      const ACancellation: IRadIAInlineCompletionCancellationToken
    ): string;
    function GetLastDiagnostic: TRadIAFimDiagnostic;
  end;

  IRadIAInlineCompletionView = interface
    ['{76F72D1C-2B17-4C88-A08A-A14B7FE4ED8D}']
    function Apply(
      const AContext: TRadIAInlineCompletionContext;
      const AText: string;
      out AUpdatedContext: TRadIAInlineCompletionContext
    ): Boolean;
    procedure Clear;
    procedure Show(
      const AContext: TRadIAInlineCompletionContext;
      const ASuggestion: string
    );
    procedure ShowAlternatives(
      const AContext: TRadIAInlineCompletionContext;
      const AAlternatives: TArray<string>;
      const ASelectedIndex: Integer
    );
  end;

  TRadIAInlineCompletionRunner = reference to procedure(
    const AAction: TProc
  );

  TRadIAInlineCompletionDispatcher = reference to procedure(
    const AAction: TProc
  );

  IRadIAInlineCompletionController = interface
    ['{72C5A323-EC59-49DC-91DF-56C2AA21688A}']
    procedure Request(
      const AContext: TRadIAInlineCompletionContext
    );
    procedure Preview(
      const AContext: TRadIAInlineCompletionContext;
      const ASuggestion: string
    );
    procedure PreviewAlternatives(
      const AContext: TRadIAInlineCompletionContext;
      const AAlternatives: TArray<string>;
      const ASelectedIndex: Integer
    );
    procedure RequestAlternative;
    function SelectNextAlternative: Boolean;
    function SelectPreviousAlternative: Boolean;
    procedure Configure(
      const AOptions: TRadIAInlineCompletionOptions
    );
    function AcceptAll: Boolean;
    function AcceptNextWord: Boolean;
    procedure Reject;
    procedure Stop;
  end;

  TRadIAInlineCompletionController = class(
    TInterfacedObject,
    IRadIAInlineCompletionController
  )
  private type
    TRadIACancellation = class(
      TInterfacedObject,
      IRadIAInlineCompletionCancellationSource,
      IRadIAInlineCompletionCancellationToken
    )
    private
      FCancelled: Integer;
    public
      procedure Cancel;
      function IsCancellationRequested: Boolean;
  end;
  private
    FAlternatives: TArray<string>;
    FCache: TObject;
    FCancellation: IRadIAInlineCompletionCancellationSource;
    FContext: TRadIAInlineCompletionContext;
    FDispatcher: TRadIAInlineCompletionDispatcher;
    FGeneration: Integer;
    FLock: TObject;
    FOptions: TRadIAInlineCompletionOptions;
    FProvider: IRadIAInlineCompletionProvider;
    FRunner: TRadIAInlineCompletionRunner;
    FSelectedAlternative: Integer;
    FStopped: Boolean;
    FSuggestion: string;
    FView: IRadIAInlineCompletionView;
    function CachedSuggestion(
      const AContext: TRadIAInlineCompletionContext
    ): string;
    procedure AddAlternative(const ASuggestion: string);
    procedure Deliver(
      const AContext: TRadIAInlineCompletionContext;
      const ASuggestion: string;
      const AGeneration: Integer
    );
    procedure DisplaySelection;
    function ExtractNextWord(const AText: string): string;
    function IsCurrent(const AGeneration: Integer): Boolean;
    procedure RunRequest(
      const AContext: TRadIAInlineCompletionContext;
      const AGeneration: Integer;
      const ACancellation: IRadIAInlineCompletionCancellationToken
    );
    function SanitizeSuggestion(
      const AContext: TRadIAInlineCompletionContext;
      const AValue: string
    ): string;
    procedure StoreSuggestion(
      const AContext: TRadIAInlineCompletionContext;
      const ASuggestion: string
    );
  public
    constructor Create(
      const AProvider: IRadIAInlineCompletionProvider;
      const AView: IRadIAInlineCompletionView;
      const AOptions: TRadIAInlineCompletionOptions;
      const ARunner: TRadIAInlineCompletionRunner;
      const ADispatcher: TRadIAInlineCompletionDispatcher
    );
    destructor Destroy; override;
    procedure Request(
      const AContext: TRadIAInlineCompletionContext
    );
    procedure Preview(
      const AContext: TRadIAInlineCompletionContext;
      const ASuggestion: string
    );
    procedure PreviewAlternatives(
      const AContext: TRadIAInlineCompletionContext;
      const AAlternatives: TArray<string>;
      const ASelectedIndex: Integer
    );
    procedure RequestAlternative;
    function SelectNextAlternative: Boolean;
    function SelectPreviousAlternative: Boolean;
    procedure Configure(
      const AOptions: TRadIAInlineCompletionOptions
    );
    function AcceptAll: Boolean;
    function AcceptNextWord: Boolean;
    procedure Reject;
    procedure Stop;
  end;

implementation

uses
  System.Classes,
  System.Diagnostics,
  System.Generics.Collections,
  System.Hash,
  System.Math,
  System.SyncObjs,
  RadIA.Core.HierarchicalSettings,
  RadIA.Core.Logger,
  RadIA.Core.ProviderRegistry,
  RadIA.Core.TokenUsage,
  RadIA.Core.Types;

const
  CDefaultDebounceMs = 350;
  CDefaultMaxContextCharacters = 24000;
  CDefaultMaxSuggestionCharacters = 4000;
  CMaximumCacheEntries = 64;
  CMaximumCompletionAlternatives = 3;

type
  IRadIAInlineCompletionResponse = interface
    ['{ED4FB623-FE45-4AC2-812F-C6A78B472615}']
    procedure Complete(
      const AResponse: string;
      const AError: string
    );
    function GetError: string;
    function GetResponse: string;
    function Wait(const ATimeoutMs: Cardinal): TWaitResult;
  end;

  TRadIAInlineCompletionResponse = class(
    TInterfacedObject,
    IRadIAInlineCompletionResponse
  )
  private
    FError: string;
    FEvent: TEvent;
    FResponse: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Complete(
      const AResponse: string;
      const AError: string
    );
    function GetError: string;
    function GetResponse: string;
    function Wait(const ATimeoutMs: Cardinal): TWaitResult;
  end;

  TRadIAInlineCompletionCache = class
  private
    FItems: TDictionary<string, string>;
    FOrder: TQueue<string>;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const AKey: string): string;
    procedure Put(const AKey: string; const AValue: string);
    procedure Remove(const AKey: string);
  end;

{ TRadIAInlineGhostLine }

constructor TRadIAInlineGhostLine.Create(
  const ALineOffset: Integer;
  const AText: string
);
begin
  FLineOffset := ALineOffset;
  FText := AText;
end;

{ TRadIAInlineGhostLayout }

class function TRadIAInlineGhostLayout.Build(
  const ASuggestion: string
): TArray<TRadIAInlineGhostLine>;
var
  LIndex: Integer;
  LLines: TStringList;
  LNormalized: string;
begin
  Result := [];
  if ASuggestion.IsEmpty then
    Exit;
  LNormalized := ASuggestion.Replace(#13#10, #10).Replace(#13, #10);
  LLines := TStringList.Create;
  try
    LLines.LineBreak := #10;
    LLines.Text := LNormalized;
    SetLength(Result, LLines.Count);
    for LIndex := 0 to LLines.Count - 1 do
      Result[LIndex] := TRadIAInlineGhostLine.Create(
        LIndex,
        LLines[LIndex]
      );
  finally
    LLines.Free;
  end;
end;

class function TRadIAInlineGhostLayout.TryGetLine(
  const ALines: TArray<TRadIAInlineGhostLine>;
  const ALineOffset: Integer;
  out ALine: TRadIAInlineGhostLine
): Boolean;
begin
  ALine := Default(TRadIAInlineGhostLine);
  Result := (ALineOffset >= 0) and
    (ALineOffset < Length(ALines));
  if Result then
    ALine := ALines[ALineOffset];
end;

{ TRadIAInlineCompletionContext }

function TRadIAInlineCompletionContext.CacheKey: string;
begin
  Result := THashSHA2.GetHashString(
    LowerCase(FFileName) + #0 +
    FLanguage + #0 +
    FPrefix + #0 +
    FSuffix + #0 +
    FSymbolName + #0 +
    FProjectContext
  );
end;

{ TRadIAFimDiagnostic }

constructor TRadIAFimDiagnostic.Create(
  const AProviderId: string;
  const AModelId: string;
  const ARouteKind: TRadIAFimRouteKind;
  const AFallbackReason: string;
  const ALatencyMs: Int64
);
begin
  FProviderId := AProviderId;
  FModelId := AModelId;
  FRouteKind := ARouteKind;
  FFallbackReason := AFallbackReason;
  FLatencyMs := ALatencyMs;
end;

{ TRadIAFimCapabilityDiscovery }

class function TRadIAFimCapabilityDiscovery.TryResolve(
  const AProvider: IRadIAProvider;
  out AProviderContract: IRadIADedicatedFimProvider;
  out AFallbackReason: string
): Boolean;
begin
  AProviderContract := nil;
  AFallbackReason := '';
  Result := Assigned(AProvider) and Supports(
    AProvider,
    IRadIADedicatedFimProvider,
    AProviderContract
  );
  if not Result then
    AFallbackReason :=
      'The selected provider does not expose the dedicated FIM contract.';
end;

function TRadIAFimDiagnostic.RouteName: string;
begin
  case FRouteKind of
    frkSemanticLocal: Result := 'local semantic completion';
    frkDedicated: Result := 'dedicated FIM';
  else
    Result := 'traditional completion fallback';
  end;
end;

constructor TRadIAInlineCompletionContext.Create(
  const AFileName: string;
  const ALanguage: string;
  const APrefix: string;
  const ASuffix: string;
  const ASymbolName: string;
  const AProjectContext: string;
  const ARevision: string
);
begin
  FFileName := AFileName;
  FLanguage := ALanguage;
  FPrefix := APrefix;
  FSuffix := ASuffix;
  FSymbolName := ASymbolName;
  FProjectContext := AProjectContext;
  FRevision := ARevision;
  FCursorLine := 0;
  FCursorColumn := 0;
end;

function TRadIAInlineCompletionContext.IsValid: Boolean;
begin
  Result := (Trim(FFileName) <> '') and
    (Trim(FLanguage) <> '') and
    (Trim(FRevision) <> '') and
    ((FPrefix <> '') or (FSuffix <> ''));
end;

function TRadIAInlineCompletionContext.Limited(
  const AMaxCharacters: Integer
): TRadIAInlineCompletionContext;
var
  LPrefix: string;
  LProjectContext: string;
  LRemaining: Integer;
  LSuffix: string;
begin
  LPrefix := FPrefix;
  LSuffix := FSuffix;
  LProjectContext := FProjectContext;
  if Length(LPrefix) > AMaxCharacters div 2 then
    LPrefix := LPrefix.Substring(
      Length(LPrefix) - (AMaxCharacters div 2)
    );
  LRemaining := AMaxCharacters - Length(LPrefix);
  if Length(LSuffix) > LRemaining div 2 then
    LSuffix := LSuffix.Substring(0, LRemaining div 2);
  LRemaining := AMaxCharacters - Length(LPrefix) - Length(LSuffix);
  if Length(LProjectContext) > LRemaining then
    LProjectContext := LProjectContext.Substring(0, LRemaining);
  Result := TRadIAInlineCompletionContext.Create(
    FFileName,
    FLanguage,
    LPrefix,
    LSuffix,
    FSymbolName,
    LProjectContext,
    FRevision
  );
  Result.FCursorLine := FCursorLine;
  Result.FCursorColumn := FCursorColumn;
end;

function TRadIAInlineCompletionContext.WithCursor(
  const ALine: Integer;
  const AColumn: Integer
): TRadIAInlineCompletionContext;
begin
  Result := Self;
  Result.FCursorLine := ALine;
  Result.FCursorColumn := AColumn;
end;

function TRadIAInlineCompletionContext.WithProjectContext(
  const AProjectContext: string
): TRadIAInlineCompletionContext;
begin
  Result := Self;
  Result.FProjectContext := AProjectContext;
end;

{ TRadIAInlineSemanticContextEnricher }

class function TRadIAInlineSemanticContextEnricher.Enrich(
  const AContext: TRadIAInlineCompletionContext;
  const ASemanticQueries: IRadIASemanticQueryService;
  const AMaxCharacters: Integer
): TRadIAInlineCompletionContext;
var
  LError: string;
  LProjectContext: string;
  LSemanticContext: string;
begin
  Result := AContext;
  if not Assigned(ASemanticQueries) or
    (Trim(AContext.SymbolName) = '') or
    (AMaxCharacters <= 0) then
    Exit;
  if not ASemanticQueries.BuildContext(
    AContext.SymbolName,
    AMaxCharacters,
    LSemanticContext,
    LError
  ) then
    Exit;
  LProjectContext := AContext.ProjectContext;
  if LProjectContext <> '' then
    LProjectContext := LProjectContext + sLineBreak;
  LProjectContext := LProjectContext +
    'Indexed semantic context:' + sLineBreak + LSemanticContext;
  Result := AContext.WithProjectContext(LProjectContext);
end;

{ TRadIAInlineCompletionResponse }

procedure TRadIAInlineCompletionResponse.Complete(
  const AResponse: string;
  const AError: string
);
begin
  FResponse := AResponse;
  FError := AError;
  FEvent.SetEvent;
end;

constructor TRadIAInlineCompletionResponse.Create;
begin
  inherited Create;
  FEvent := TEvent.Create(nil, True, False, '');
end;

destructor TRadIAInlineCompletionResponse.Destroy;
begin
  FEvent.Free;
  inherited Destroy;
end;

function TRadIAInlineCompletionResponse.GetError: string;
begin
  Result := FError;
end;

function TRadIAInlineCompletionResponse.GetResponse: string;
begin
  Result := FResponse;
end;

function TRadIAInlineCompletionResponse.Wait(
  const ATimeoutMs: Cardinal
): TWaitResult;
begin
  Result := FEvent.WaitFor(ATimeoutMs);
end;

{ TRadIAServiceInlineCompletionProvider }

class function TRadIAServiceInlineCompletionProvider.BuildPrompt(
  const AContext: TRadIAInlineCompletionContext
): string;
begin
  Result :=
    'Complete the code at <CURSOR> using fill-in-the-middle. ' +
    'Return only the missing code, without Markdown fences or explanation.' +
    sLineBreak +
    'Language: ' + AContext.Language + sLineBreak +
    'File: ' + AContext.FileName + sLineBreak +
    'Symbol: ' + AContext.SymbolName + sLineBreak +
    'Revision: ' + AContext.Revision + sLineBreak +
    '<PROJECT_CONTEXT>' + sLineBreak +
    AContext.ProjectContext + sLineBreak +
    '</PROJECT_CONTEXT>' + sLineBreak +
    '<PREFIX>' + sLineBreak +
    AContext.Prefix + '<CURSOR>' + sLineBreak +
    '</PREFIX>' + sLineBreak +
    '<SUFFIX>' + sLineBreak +
    AContext.Suffix + sLineBreak +
    '</SUFFIX>';
end;

function TRadIAServiceInlineCompletionProvider.Complete(
  const AContext: TRadIAInlineCompletionContext;
  const ACancellation: IRadIAInlineCompletionCancellationToken
): string;
var
  LAwareProvider: IRadIAExecutionSettingsAwareProvider;
  LMaxTokens: Integer;
  LModelId: string;
  LProvider: IRadIAProvider;
  LProviderId: string;
  LTemperature: Double;
  LSettings: TRadIAExecutionSettings;
  LSemanticContext: TRadIAInlineCompletionContext;
  LSemanticHandled: Boolean;
begin
  Result := CompleteWithSemanticIndex(AContext, ACancellation, LSemanticHandled);
  if LSemanticHandled then
    Exit;
  LProviderId := Trim(FConfig.AutocompleteProvider);
  if LProviderId = '' then
    LProviderId := FConfig.GetActiveProvider;
  LModelId := Trim(FConfig.AutocompleteModel);
  if LModelId = '' then
    LModelId := FConfig.GetActiveModel(LProviderId);
  if FConfig.QuotaEnabled and
    not FConfig.IsWebLoginProvider(LProviderId) and
    (FConfig.QuotaUsed >= FConfig.QuotaLimit) then
  begin
    StoreDiagnostic(
      TRadIAFimDiagnostic.Create(
        LProviderId,
        LModelId,
        frkTraditionalFallback,
        'The local monthly token quota is exhausted.',
        0
      )
    );
    Exit('');
  end;
  if FConfig.IsWebLoginProvider(LProviderId) then
    LProvider := TProviderRegistry.CreateProvider('WebViewBridge', FConfig)
  else
    LProvider := TProviderRegistry.CreateProvider(LProviderId, FConfig);
  LSettings := TRadIAExecutionSettings.Create(
    LProviderId,
    LModelId,
    '',
    -1,
    FTimeoutMs,
    -1
  );
  if Supports(LProvider, IRadIAExecutionSettingsAwareProvider, LAwareProvider) then
    LAwareProvider.ApplyExecutionSettings(LSettings);
  FService.ResolveParameters(
    LProvider.GetProviderId,
    rpRefactorCode,
    LTemperature,
    LMaxTokens
  );
  LSemanticContext := TRadIAInlineSemanticContextEnricher.Enrich(
    AContext,
    FSemanticQueries,
    8192
  );
  Result := CompleteWithProvider(
    LSemanticContext,
    ACancellation,
    LProvider,
    LModelId,
    LMaxTokens
  );
end;

function TRadIAServiceInlineCompletionProvider.CompleteWithSemanticIndex(
  const AContext: TRadIAInlineCompletionContext;
  const ACancellation: IRadIAInlineCompletionCancellationToken;
  out AHandled: Boolean
): string;
var
  LCancellationCheck: TFunc<Boolean>;
  LContainerName: string;
  LDotIndex: Integer;
  LPrefix: string;
  LPrefixIndex: Integer;
  LSemanticResult: TRadIASemanticCompletionResult;
begin
  Result := '';
  AHandled := False;
  LPrefixIndex := Length(AContext.Prefix);
  while (LPrefixIndex > 0) and
    CharInSet(AContext.Prefix[LPrefixIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
    Dec(LPrefixIndex);
  LPrefix := Copy(AContext.Prefix, LPrefixIndex + 1, MaxInt);
  LContainerName := AContext.SymbolName;
  LDotIndex := Pos('.', LContainerName);
  if LDotIndex > 0 then
    LContainerName := Copy(LContainerName, 1, LDotIndex - 1);
  if not Assigned(FSemanticCompletion) or
    (LPrefixIndex = 0) or
    (AContext.Prefix[LPrefixIndex] <> '.') or
    (LContainerName = '') then
    Exit;
  LCancellationCheck :=
    function: Boolean
    begin
      Result := ACancellation.IsCancellationRequested;
    end;
  LSemanticResult := FSemanticCompletion.Complete(
    LContainerName,
    LPrefix,
    LCancellationCheck
  );
  AHandled := LSemanticResult.Status = 'cancelled';
  if (LSemanticResult.Status <> 'ready') or
    (LSemanticResult.Suggestion = '') then
    Exit;
  StoreDiagnostic(TRadIAFimDiagnostic.Create(
    'RadIA Semantic Engine',
    'structural-index',
    frkSemanticLocal,
    '',
    LSemanticResult.LatencyMs
  ));
  AHandled := True;
  Result := LSemanticResult.Suggestion;
end;

function TRadIAServiceInlineCompletionProvider.CompleteWithProvider(
  const AContext: TRadIAInlineCompletionContext;
  const ACancellation: IRadIAInlineCompletionCancellationToken;
  const AProvider: IRadIAProvider;
  const AModelId: string;
  const AMaxTokens: Integer
): string;
const
  CPollIntervalMs = 50;
var
  LDedicatedProvider: IRadIADedicatedFimProvider;
  LCallback: TCompletionCallback;
  LError: string;
  LFallbackReason: string;
  LFimCallback: TRadIAFimCompletionCallback;
  LResponse: IRadIAInlineCompletionResponse;
  LRouteKind: TRadIAFimRouteKind;
  LStopwatch: TStopwatch;
  function WaitForResponse(
    const AResponse: IRadIAInlineCompletionResponse;
    out AError: string
  ): string;
  var
    LElapsedMs: Cardinal;
    LWaitMs: Cardinal;
  begin
    Result := '';
    AError := '';
    LElapsedMs := 0;
    while LElapsedMs < FTimeoutMs do
    begin
      if ACancellation.IsCancellationRequested then
      begin
        AProvider.CancelCurrentRequest;
        AError := 'cancelled';
        Exit;
      end;
      LWaitMs := CPollIntervalMs;
      if FTimeoutMs - LElapsedMs < LWaitMs then
        LWaitMs := FTimeoutMs - LElapsedMs;
      if AResponse.Wait(LWaitMs) = wrSignaled then
      begin
        AError := AResponse.GetError;
        if AError = '' then
          Result := AResponse.GetResponse;
        Exit;
      end;
      Inc(LElapsedMs, LWaitMs);
    end;
    AProvider.CancelCurrentRequest;
    AError := 'timeout';
  end;
  procedure StartTraditionalCompletion;
  begin
    LCallback :=
      procedure(
        const AResponse: string;
        const AError: string;
        AFromCache: Boolean;
        const AUsage: TTokenUsage
      )
      begin
        LResponse.Complete(AResponse, AError);
      end;
    AProvider.SendPromptAsync(
      BuildPrompt(AContext),
      [],
      LCallback,
      0.0,
      AMaxTokens
    );
  end;
begin
  Result := '';
  LStopwatch := TStopwatch.StartNew;
  LResponse := TRadIAInlineCompletionResponse.Create;
  if TRadIAFimCapabilityDiscovery.TryResolve(
    AProvider,
    LDedicatedProvider,
    LFallbackReason
  ) then
  begin
    LRouteKind := frkDedicated;
    LFimCallback :=
      procedure(const AResponse: string; const AError: string)
      begin
        LResponse.Complete(AResponse, AError);
      end;
    LDedicatedProvider.SendFimAsync(AContext, LFimCallback, AMaxTokens);
  end
  else
  begin
    LRouteKind := frkTraditionalFallback;
    StartTraditionalCompletion;
  end;
  Result := WaitForResponse(LResponse, LError);
  if (LRouteKind = frkDedicated) and
    (LError <> '') and
    not SameText(LError, 'cancelled') then
  begin
    LRouteKind := frkTraditionalFallback;
    LFallbackReason := 'Dedicated FIM failed: ' + LError;
    LResponse := TRadIAInlineCompletionResponse.Create;
    StartTraditionalCompletion;
    Result := WaitForResponse(LResponse, LError);
  end;
  if SameText(LError, 'cancelled') then
    LFallbackReason :=
      'The request was cancelled because the editor context changed.'
  else if SameText(LError, 'timeout') then
    LFallbackReason := 'The completion request reached its local timeout.';
  LStopwatch.Stop;
  StoreDiagnostic(
    TRadIAFimDiagnostic.Create(
      AProvider.GetProviderId,
      AModelId,
      LRouteKind,
      LFallbackReason,
      LStopwatch.ElapsedMilliseconds
    )
  );
end;

procedure TRadIAServiceInlineCompletionProvider.StoreDiagnostic(
  const ADiagnostic: TRadIAFimDiagnostic
);
begin
  TMonitor.Enter(FDiagnosticLock);
  try
    FLastDiagnostic := ADiagnostic;
    TLogger.Log(
      'Inline completion route=' + FLastDiagnostic.RouteName +
      ' provider=' + FLastDiagnostic.ProviderId +
      ' model=' + FLastDiagnostic.ModelId +
      ' latencyMs=' + FLastDiagnostic.LatencyMs.ToString +
      ' fallbackReason=' + FLastDiagnostic.FallbackReason,
      'InlineCompletion'
    );
  finally
    TMonitor.Exit(FDiagnosticLock);
  end;
end;

constructor TRadIAServiceInlineCompletionProvider.Create(
  const AService: IRadIAService;
  const AConfig: IRadIAConfig;
  const ASemanticQueries: IRadIASemanticQueryService;
  const ASemanticCompletion: IRadIASemanticCompletionService;
  const ATimeoutMs: Cardinal
);
begin
  inherited Create;
  Initialize(
    AService,
    AConfig,
    ASemanticQueries,
    ASemanticCompletion,
    ATimeoutMs
  );
end;

procedure TRadIAServiceInlineCompletionProvider.Initialize(
  const AService: IRadIAService;
  const AConfig: IRadIAConfig;
  const ASemanticQueries: IRadIASemanticQueryService;
  const ASemanticCompletion: IRadIASemanticCompletionService;
  const ATimeoutMs: Cardinal
);
begin
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  if not Assigned(AConfig) then
    raise EArgumentNilException.Create('AConfig');
  if ATimeoutMs = 0 then
    raise EArgumentOutOfRangeException.Create('ATimeoutMs');
  FService := AService;
  FConfig := AConfig;
  FSemanticQueries := ASemanticQueries;
  FSemanticCompletion := ASemanticCompletion;
  FTimeoutMs := ATimeoutMs;
  FDiagnosticLock := TObject.Create;
end;

destructor TRadIAServiceInlineCompletionProvider.Destroy;
begin
  FDiagnosticLock.Free;
  inherited Destroy;
end;

function TRadIAServiceInlineCompletionProvider.GetLastDiagnostic:
  TRadIAFimDiagnostic;
begin
  TMonitor.Enter(FDiagnosticLock);
  try
    Result := FLastDiagnostic;
  finally
    TMonitor.Exit(FDiagnosticLock);
  end;
end;

{ TRadIAInlineCompletionOptions }

constructor TRadIAInlineCompletionOptions.Create(
  const ADebounceMs: Cardinal;
  const AMaxContextCharacters: Integer;
  const AMaxSuggestionCharacters: Integer
);
begin
  if AMaxContextCharacters < 256 then
    raise EArgumentOutOfRangeException.Create('AMaxContextCharacters');
  if AMaxSuggestionCharacters < 1 then
    raise EArgumentOutOfRangeException.Create('AMaxSuggestionCharacters');
  FDebounceMs := ADebounceMs;
  FMaxContextCharacters := AMaxContextCharacters;
  FMaxSuggestionCharacters := AMaxSuggestionCharacters;
end;

class function TRadIAInlineCompletionOptions.Default:
  TRadIAInlineCompletionOptions;
begin
  Result := TRadIAInlineCompletionOptions.Create(
    CDefaultDebounceMs,
    CDefaultMaxContextCharacters,
    CDefaultMaxSuggestionCharacters
  );
end;

{ TRadIAInlineCompletionPolicy }

class function TRadIAInlineCompletionPolicy.IsAllowed(
  const AContext: TRadIAInlineCompletionContext;
  const AExcludedLanguages: string;
  const AExcludedFiles: string;
  const AExcludedProjects: string
): Boolean;
begin
  Result := AContext.IsValid and
    not IsListed(
      AContext.Language,
      AExcludedLanguages,
      True
    ) and
    not IsListed(
      AContext.FileName,
      AExcludedFiles,
      False
    ) and
    not IsListed(
      AContext.ProjectContext,
      AExcludedProjects,
      False
    );
end;

class function TRadIAInlineCompletionPolicy.IsListed(
  const AValue: string;
  const AList: string;
  const AExactMatch: Boolean
): Boolean;
var
  LItem: string;
  LItems: TStringList;
  LNormalizedItem: string;
  LNormalizedList: string;
  LNormalizedValue: string;
begin
  Result := False;
  if AList.Trim.IsEmpty then
    Exit;
  LNormalizedList := AList.Replace(',', ';')
    .Replace(#13, ';')
    .Replace(#10, ';');
  LNormalizedValue := AValue.Trim.ToLower;
  LItems := TStringList.Create;
  try
    LItems.StrictDelimiter := True;
    LItems.Delimiter := ';';
    LItems.DelimitedText := LNormalizedList;
    for LItem in LItems do
    begin
      LNormalizedItem := LItem.Trim.ToLower;
      if LNormalizedItem.IsEmpty then
        Continue;
      if AExactMatch and
        SameText(LNormalizedValue, LNormalizedItem) then
        Exit(True);
      if not AExactMatch and
        LNormalizedValue.Contains(LNormalizedItem) then
        Exit(True);
    end;
  finally
    LItems.Free;
  end;
end;

{ TRadIAInlineCompletionCache }

constructor TRadIAInlineCompletionCache.Create;
begin
  inherited Create;
  FItems := TDictionary<string, string>.Create;
  FOrder := TQueue<string>.Create;
end;

destructor TRadIAInlineCompletionCache.Destroy;
begin
  FOrder.Free;
  FItems.Free;
  inherited Destroy;
end;

function TRadIAInlineCompletionCache.Get(const AKey: string): string;
begin
  if not FItems.TryGetValue(AKey, Result) then
    Result := '';
end;

procedure TRadIAInlineCompletionCache.Put(
  const AKey: string;
  const AValue: string
);
var
  LOldestKey: string;
begin
  if FItems.ContainsKey(AKey) then
  begin
    FItems[AKey] := AValue;
    Exit;
  end;
  while FItems.Count >= CMaximumCacheEntries do
  begin
    LOldestKey := FOrder.Dequeue;
    FItems.Remove(LOldestKey);
  end;
  FItems.Add(AKey, AValue);
  FOrder.Enqueue(AKey);
end;

procedure TRadIAInlineCompletionCache.Remove(const AKey: string);
begin
  FItems.Remove(AKey);
end;

{ TRadIAInlineCompletionController.TRadIACancellation }

procedure TRadIAInlineCompletionController.TRadIACancellation.Cancel;
begin
  TInterlocked.Exchange(FCancelled, 1);
end;

function TRadIAInlineCompletionController.TRadIACancellation.
  IsCancellationRequested: Boolean;
begin
  Result := TInterlocked.CompareExchange(FCancelled, 0, 0) <> 0;
end;

{ TRadIAInlineCompletionController }

procedure TRadIAInlineCompletionController.AddAlternative(
  const ASuggestion: string
);
var
  LAlternative: string;
  LIndex: Integer;
begin
  if ASuggestion = '' then
    Exit;
  TMonitor.Enter(FLock);
  try
    for LAlternative in FAlternatives do
      if SameText(LAlternative, ASuggestion) then
        Exit;
    if Length(FAlternatives) >= CMaximumCompletionAlternatives then
    begin
      for LIndex := 1 to High(FAlternatives) do
        FAlternatives[LIndex - 1] := FAlternatives[LIndex];
      SetLength(
        FAlternatives,
        CMaximumCompletionAlternatives - 1
      );
    end;
    LIndex := Length(FAlternatives);
    SetLength(FAlternatives, LIndex + 1);
    FAlternatives[LIndex] := ASuggestion;
    FSelectedAlternative := LIndex;
    FSuggestion := ASuggestion;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TRadIAInlineCompletionController.AcceptAll: Boolean;
var
  LContext: TRadIAInlineCompletionContext;
  LSuggestion: string;
  LUpdatedContext: TRadIAInlineCompletionContext;
begin
  TMonitor.Enter(FLock);
  try
    LContext := FContext;
    LSuggestion := FSuggestion;
    FSuggestion := '';
    FAlternatives := nil;
    FSelectedAlternative := -1;
  finally
    TMonitor.Exit(FLock);
  end;
  Result := (LSuggestion <> '') and
    FView.Apply(LContext, LSuggestion, LUpdatedContext);
  FView.Clear;
end;

function TRadIAInlineCompletionController.AcceptNextWord: Boolean;
var
  LAcceptedText: string;
  LContext: TRadIAInlineCompletionContext;
  LRemainingText: string;
  LUpdatedContext: TRadIAInlineCompletionContext;
begin
  TMonitor.Enter(FLock);
  try
    LAcceptedText := ExtractNextWord(FSuggestion);
    Result := LAcceptedText <> '';
    if not Result then
      Exit;
    LContext := FContext;
    Delete(FSuggestion, 1, Length(LAcceptedText));
    LRemainingText := FSuggestion;
    FAlternatives := nil;
    FSelectedAlternative := -1;
  finally
    TMonitor.Exit(FLock);
  end;
  if not FView.Apply(
    LContext,
    LAcceptedText,
    LUpdatedContext
  ) then
  begin
    Reject;
    Exit(False);
  end;
  TMonitor.Enter(FLock);
  try
    FContext := LUpdatedContext;
  finally
    TMonitor.Exit(FLock);
  end;
  if LRemainingText = '' then
    FView.Clear
  else
    FView.Show(LUpdatedContext, LRemainingText);
end;

procedure TRadIAInlineCompletionController.DisplaySelection;
var
  LAlternatives: TArray<string>;
  LContext: TRadIAInlineCompletionContext;
  LSelectedIndex: Integer;
begin
  TMonitor.Enter(FLock);
  try
    LAlternatives := Copy(FAlternatives);
    LContext := FContext;
    LSelectedIndex := FSelectedAlternative;
  finally
    TMonitor.Exit(FLock);
  end;
  if Length(LAlternatives) = 0 then
    FView.Clear
  else
    FView.ShowAlternatives(
      LContext,
      LAlternatives,
      LSelectedIndex
    );
end;

function TRadIAInlineCompletionController.CachedSuggestion(
  const AContext: TRadIAInlineCompletionContext
): string;
begin
  TMonitor.Enter(FLock);
  try
    Result := TRadIAInlineCompletionCache(FCache).Get(
      AContext.CacheKey
    );
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAInlineCompletionController.Configure(
  const AOptions: TRadIAInlineCompletionOptions
);
begin
  TMonitor.Enter(FLock);
  try
    if AOptions.MaxContextCharacters = 0 then
      FOptions := TRadIAInlineCompletionOptions.Default
    else
      FOptions := AOptions;
  finally
    TMonitor.Exit(FLock);
  end;
end;

constructor TRadIAInlineCompletionController.Create(
  const AProvider: IRadIAInlineCompletionProvider;
  const AView: IRadIAInlineCompletionView;
  const AOptions: TRadIAInlineCompletionOptions;
  const ARunner: TRadIAInlineCompletionRunner;
  const ADispatcher: TRadIAInlineCompletionDispatcher
);
begin
  inherited Create;
  if not Assigned(AProvider) then
    raise EArgumentNilException.Create('AProvider');
  if not Assigned(AView) then
    raise EArgumentNilException.Create('AView');
  FProvider := AProvider;
  FView := AView;
  if AOptions.MaxContextCharacters = 0 then
    FOptions := TRadIAInlineCompletionOptions.Default
  else
    FOptions := AOptions;
  FRunner := ARunner;
  FDispatcher := ADispatcher;
  FSelectedAlternative := -1;
  FLock := TObject.Create;
  FCache := TRadIAInlineCompletionCache.Create;
end;

procedure TRadIAInlineCompletionController.Deliver(
  const AContext: TRadIAInlineCompletionContext;
  const ASuggestion: string;
  const AGeneration: Integer
);
var
  LAction: TProc;
begin
  LAction :=
    procedure
    begin
      if not IsCurrent(AGeneration) then
        Exit;
      TMonitor.Enter(FLock);
      try
        FContext := AContext;
      finally
        TMonitor.Exit(FLock);
      end;
      if ASuggestion = '' then
        FView.Clear
      else
      begin
        AddAlternative(ASuggestion);
        DisplaySelection;
      end;
    end;
  if Assigned(FDispatcher) then
    FDispatcher(LAction)
  else
    LAction();
end;

destructor TRadIAInlineCompletionController.Destroy;
begin
  Stop;
  FCache.Free;
  FLock.Free;
  inherited Destroy;
end;

function TRadIAInlineCompletionController.ExtractNextWord(
  const AText: string
): string;
var
  LIndex: Integer;
  LSeenWordCharacter: Boolean;
begin
  Result := '';
  LSeenWordCharacter := False;
  for LIndex := Low(AText) to High(AText) do
  begin
    Result := Result + AText[LIndex];
    if CharInSet(AText[LIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      LSeenWordCharacter := True
    else if LSeenWordCharacter then
      Break;
  end;
end;

function TRadIAInlineCompletionController.IsCurrent(
  const AGeneration: Integer
): Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := not FStopped and (FGeneration = AGeneration);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TRadIAInlineCompletionController.Reject;
begin
  TMonitor.Enter(FLock);
  try
    Inc(FGeneration);
    if Assigned(FCancellation) then
      FCancellation.Cancel;
    FCancellation := nil;
    FSuggestion := '';
    FAlternatives := nil;
    FSelectedAlternative := -1;
  finally
    TMonitor.Exit(FLock);
  end;
  FView.Clear;
end;

procedure TRadIAInlineCompletionController.Preview(
  const AContext: TRadIAInlineCompletionContext;
  const ASuggestion: string
);
var
  LSuggestion: string;
begin
  if not AContext.IsValid then
  begin
    Reject;
    Exit;
  end;
  LSuggestion := SanitizeSuggestion(AContext, ASuggestion);
  TMonitor.Enter(FLock);
  try
    FStopped := False;
    Inc(FGeneration);
    if Assigned(FCancellation) then
      FCancellation.Cancel;
    FCancellation := nil;
    FContext := AContext;
    FSuggestion := LSuggestion;
    FAlternatives := nil;
    FSelectedAlternative := -1;
  finally
    TMonitor.Exit(FLock);
  end;
  if LSuggestion = '' then
    FView.Clear
  else
  begin
    AddAlternative(LSuggestion);
    DisplaySelection;
  end;
end;

procedure TRadIAInlineCompletionController.Request(
  const AContext: TRadIAInlineCompletionContext
);
var
  LAction: TProc;
  LCancellation: IRadIAInlineCompletionCancellationToken;
  LContext: TRadIAInlineCompletionContext;
  LGeneration: Integer;
  LKeepAlive: IInterface;
  LMaxContextCharacters: Integer;
begin
  if not AContext.IsValid then
  begin
    Reject;
    Exit;
  end;
  TMonitor.Enter(FLock);
  try
    LMaxContextCharacters := FOptions.MaxContextCharacters;
  finally
    TMonitor.Exit(FLock);
  end;
  LContext := AContext.Limited(LMaxContextCharacters);
  TMonitor.Enter(FLock);
  try
    if FContext.CacheKey <> LContext.CacheKey then
    begin
      FAlternatives := nil;
      FSelectedAlternative := -1;
    end;
    FStopped := False;
    Inc(FGeneration);
    LGeneration := FGeneration;
    if Assigned(FCancellation) then
      FCancellation.Cancel;
    FCancellation := TRadIACancellation.Create;
    LCancellation := FCancellation;
    FContext := LContext;
    FSuggestion := '';
  finally
    TMonitor.Exit(FLock);
  end;
  FView.Clear;
  LKeepAlive := Self;
  LAction :=
    procedure
    begin
      if not Assigned(LKeepAlive) then
        Exit;
      try
        RunRequest(LContext, LGeneration, LCancellation);
      finally
        LKeepAlive := nil;
      end;
    end;
  if Assigned(FRunner) then
    FRunner(LAction)
  else
    TThread.CreateAnonymousThread(LAction).Start;
end;

procedure TRadIAInlineCompletionController.RequestAlternative;
var
  LContext: TRadIAInlineCompletionContext;
begin
  TMonitor.Enter(FLock);
  try
    LContext := FContext;
  finally
    TMonitor.Exit(FLock);
  end;
  TMonitor.Enter(FLock);
  try
    TRadIAInlineCompletionCache(FCache).Remove(LContext.CacheKey);
  finally
    TMonitor.Exit(FLock);
  end;
  Request(LContext);
end;

procedure TRadIAInlineCompletionController.PreviewAlternatives(
  const AContext: TRadIAInlineCompletionContext;
  const AAlternatives: TArray<string>;
  const ASelectedIndex: Integer
);
var
  LAlternative: string;
begin
  if not AContext.IsValid then
  begin
    Reject;
    Exit;
  end;
  TMonitor.Enter(FLock);
  try
    FStopped := False;
    Inc(FGeneration);
    if Assigned(FCancellation) then
      FCancellation.Cancel;
    FCancellation := nil;
    FContext := AContext;
    FSuggestion := '';
    FAlternatives := nil;
    FSelectedAlternative := -1;
  finally
    TMonitor.Exit(FLock);
  end;
  for LAlternative in AAlternatives do
    AddAlternative(SanitizeSuggestion(AContext, LAlternative));
  TMonitor.Enter(FLock);
  try
    if Length(FAlternatives) > 0 then
    begin
      FSelectedAlternative := EnsureRange(
        ASelectedIndex,
        0,
        Length(FAlternatives) - 1
      );
      FSuggestion := FAlternatives[FSelectedAlternative];
    end;
  finally
    TMonitor.Exit(FLock);
  end;
  DisplaySelection;
end;

function TRadIAInlineCompletionController.SelectNextAlternative: Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := Length(FAlternatives) > 1;
    if not Result then
      Exit;
    FSelectedAlternative :=
      (FSelectedAlternative + 1) mod Length(FAlternatives);
    FSuggestion := FAlternatives[FSelectedAlternative];
  finally
    TMonitor.Exit(FLock);
  end;
  DisplaySelection;
end;

function TRadIAInlineCompletionController.SelectPreviousAlternative:
  Boolean;
begin
  TMonitor.Enter(FLock);
  try
    Result := Length(FAlternatives) > 1;
    if not Result then
      Exit;
    Dec(FSelectedAlternative);
    if FSelectedAlternative < 0 then
      FSelectedAlternative := Length(FAlternatives) - 1;
    FSuggestion := FAlternatives[FSelectedAlternative];
  finally
    TMonitor.Exit(FLock);
  end;
  DisplaySelection;
end;

procedure TRadIAInlineCompletionController.RunRequest(
  const AContext: TRadIAInlineCompletionContext;
  const AGeneration: Integer;
  const ACancellation: IRadIAInlineCompletionCancellationToken
);
var
  LDebounceMs: Cardinal;
  LSuggestion: string;
begin
  TMonitor.Enter(FLock);
  try
    LDebounceMs := FOptions.DebounceMs;
  finally
    TMonitor.Exit(FLock);
  end;
  if LDebounceMs > 0 then
    TThread.Sleep(LDebounceMs);
  if ACancellation.IsCancellationRequested or
    not IsCurrent(AGeneration) then
    Exit;
  LSuggestion := CachedSuggestion(AContext);
  if LSuggestion = '' then
  begin
    LSuggestion := FProvider.Complete(AContext, ACancellation);
    if ACancellation.IsCancellationRequested then
      Exit;
    LSuggestion := SanitizeSuggestion(AContext, LSuggestion);
    if LSuggestion <> '' then
      StoreSuggestion(AContext, LSuggestion);
  end;
  Deliver(AContext, LSuggestion, AGeneration);
end;

function TRadIAInlineCompletionController.SanitizeSuggestion(
  const AContext: TRadIAInlineCompletionContext;
  const AValue: string
): string;
var
  LFenceEnd: Integer;
  LMaxSuggestionCharacters: Integer;
begin
  Result := AValue.Replace(#13#10, #10)
    .Replace(#13, #10)
    .Replace(#10, sLineBreak)
    .Trim;
  if Result.StartsWith('```') then
  begin
    LFenceEnd := Result.IndexOf(#10);
    if LFenceEnd >= 0 then
      Result := Result.Substring(LFenceEnd + 1);
    if Result.EndsWith('```') then
      Result := Result.Substring(0, Result.Length - 3).TrimRight;
  end;
  if (AContext.Suffix <> '') and Result.EndsWith(AContext.Suffix) then
    Delete(
      Result,
      Length(Result) - Length(AContext.Suffix) + 1,
      Length(AContext.Suffix)
    );
  TMonitor.Enter(FLock);
  try
    LMaxSuggestionCharacters := FOptions.MaxSuggestionCharacters;
  finally
    TMonitor.Exit(FLock);
  end;
  if Length(Result) > LMaxSuggestionCharacters then
    SetLength(Result, LMaxSuggestionCharacters);
end;

procedure TRadIAInlineCompletionController.Stop;
begin
  TMonitor.Enter(FLock);
  try
    FStopped := True;
    Inc(FGeneration);
    if Assigned(FCancellation) then
      FCancellation.Cancel;
    FCancellation := nil;
    FSuggestion := '';
    FAlternatives := nil;
    FSelectedAlternative := -1;
  finally
    TMonitor.Exit(FLock);
  end;
  FView.Clear;
end;

procedure TRadIAInlineCompletionController.StoreSuggestion(
  const AContext: TRadIAInlineCompletionContext;
  const ASuggestion: string
);
begin
  TMonitor.Enter(FLock);
  try
    TRadIAInlineCompletionCache(FCache).Put(
      AContext.CacheKey,
      ASuggestion
    );
  finally
    TMonitor.Exit(FLock);
  end;
end;

end.
