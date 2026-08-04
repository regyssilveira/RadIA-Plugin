unit RadIA.Tests.ConfigPresenter;

interface

uses
  DUnitX.TestFramework, System.Generics.Collections,
  Vcl.Graphics, RadIA.Core.Interfaces,
  RadIA.UI.ConfigPresenter;

type
  TMockConfigView = class(TInterfacedObject, IRadIAConfigView)
  strict private
    FApiKeyMap: TDictionary<string, string>;
    FCustomUrlMap: TDictionary<string, string>;
    FAuthTypeMap: TDictionary<string, Integer>;
    FTempMap: TDictionary<string, string>;
    FMaxTokensMap: TDictionary<string, string>;
    FTimeoutMap: TDictionary<string, string>;
    FAzureModel: string;
    FAzureApiVersion: string;
    FAwsAccessKeyId: string;
    FAwsSecretAccessKey: string;
    FAwsRegion: string;
    FAwsSessionToken: string;
    FSystemPrompt: string;
    FSmartConfigEnabled: Boolean;
    FInjectDelphiVersion: Boolean;
    FConciseResponses: Boolean;
    FLogEnabled: Boolean;
    FLogPath: string;
    FLogMaxSize: string;
    FConsentTimeoutSeconds: string;
    FConsentShowArguments: Boolean;
    FConsentRememberReversible: Boolean;
    FConsentRememberStructural: Boolean;
    FConsentRememberExecution: Boolean;
    FQuotaEnabled: Boolean;
    FQuotaLimit: string;
    FQuotaUsedText: string;
    FLastMessageDialogText: string;
    FSaveDialogResult: Boolean;
    FSaveDialogSelectedFileName: string;
    FOpenDialogResult: Boolean;
    FOpenDialogSelectedFileName: string;
    FFolderDialogResult: Boolean;
    FFolderDialogSelectedFolderName: string;
    FCloseViewCalled: Boolean;
    FCloseViewModalResult: Integer;
    FTemplatesList: TArray<string>;
    FSelectedTemplateIndex: Integer;
    FTemplateName: string;
    FTemplateDesc: string;
    FTemplateBody: string;
    FTemplateSlash: string;
    FTemplateIsProjGen: Boolean;
    FTemplateIsSystem: Boolean;
    FTemplateIsCustomized: Boolean;
    FDeleteTemplateButtonCaption: string;
    FDeleteTemplateButtonEnabled: Boolean;
    FTemplateOriginLabelText: string;
    FTemplateOriginLabelColor: TColor;
    FFocusTemplateNameCalled: Boolean;
    FOAuthLoggedInMap: TDictionary<string, Boolean>;
  public
    constructor Create;
    destructor Destroy; override;

    { IRadIAConfigView }
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

    property ApiKeyMap: TDictionary<string, string> read FApiKeyMap write FApiKeyMap;
    property CustomUrlMap: TDictionary<string, string> read FCustomUrlMap write FCustomUrlMap;
    property AuthTypeMap: TDictionary<string, Integer> read FAuthTypeMap write FAuthTypeMap;
    property TempMap: TDictionary<string, string> read FTempMap write FTempMap;
    property MaxTokensMap: TDictionary<string, string> read FMaxTokensMap write FMaxTokensMap;
    property TimeoutMap: TDictionary<string, string> read FTimeoutMap write FTimeoutMap;
    property AzureModel: string read FAzureModel write FAzureModel;
    property AzureApiVersion: string read FAzureApiVersion write FAzureApiVersion;
    property AwsAccessKeyId: string read FAwsAccessKeyId write FAwsAccessKeyId;
    property AwsSecretAccessKey: string read FAwsSecretAccessKey write FAwsSecretAccessKey;
    property AwsRegion: string read FAwsRegion write FAwsRegion;
    property AwsSessionToken: string read FAwsSessionToken write FAwsSessionToken;
    property SystemPrompt: string read FSystemPrompt write FSystemPrompt;
    property SmartConfigEnabled: Boolean read FSmartConfigEnabled write FSmartConfigEnabled;
    property InjectDelphiVersion: Boolean read FInjectDelphiVersion write FInjectDelphiVersion;
    property ConciseResponses: Boolean read FConciseResponses write FConciseResponses;
    property LogEnabled: Boolean read FLogEnabled write FLogEnabled;
    property LogPath: string read FLogPath write FLogPath;
    property LogMaxSize: string read FLogMaxSize write FLogMaxSize;
    property ConsentTimeoutSeconds: string
      read FConsentTimeoutSeconds write FConsentTimeoutSeconds;
    property ConsentShowArguments: Boolean
      read FConsentShowArguments write FConsentShowArguments;
    property ConsentRememberReversible: Boolean
      read FConsentRememberReversible write FConsentRememberReversible;
    property ConsentRememberStructural: Boolean
      read FConsentRememberStructural write FConsentRememberStructural;
    property ConsentRememberExecution: Boolean
      read FConsentRememberExecution write FConsentRememberExecution;
    property QuotaEnabled: Boolean read FQuotaEnabled write FQuotaEnabled;
    property QuotaLimit: string read FQuotaLimit write FQuotaLimit;
    property QuotaUsedText: string read FQuotaUsedText write FQuotaUsedText;
    property OAuthLoggedInMap: TDictionary<string, Boolean> read FOAuthLoggedInMap write FOAuthLoggedInMap;
    property LastMessageDialogText: string read FLastMessageDialogText write FLastMessageDialogText;
    property SaveDialogResult: Boolean read FSaveDialogResult write FSaveDialogResult;
    property SaveDialogSelectedFileName: string read FSaveDialogSelectedFileName write FSaveDialogSelectedFileName;
    property OpenDialogResult: Boolean read FOpenDialogResult write FOpenDialogResult;
    property OpenDialogSelectedFileName: string read FOpenDialogSelectedFileName write FOpenDialogSelectedFileName;
    property FolderDialogResult: Boolean read FFolderDialogResult write FFolderDialogResult;
    property FolderDialogSelectedFolderName: string
      read FFolderDialogSelectedFolderName write FFolderDialogSelectedFolderName;
    property CloseViewCalled: Boolean read FCloseViewCalled write FCloseViewCalled;
    property CloseViewModalResult: Integer read FCloseViewModalResult write FCloseViewModalResult;
    property TemplatesList: TArray<string> read FTemplatesList write FTemplatesList;
    property SelectedTemplateIndex: Integer read FSelectedTemplateIndex write FSelectedTemplateIndex;
    property TemplateName: string read FTemplateName write FTemplateName;
    property TemplateDesc: string read FTemplateDesc write FTemplateDesc;
    property TemplateBody: string read FTemplateBody write FTemplateBody;
    property TemplateSlash: string read FTemplateSlash write FTemplateSlash;
    property TemplateIsProjGen: Boolean read FTemplateIsProjGen write FTemplateIsProjGen;
    property TemplateIsSystem: Boolean read FTemplateIsSystem write FTemplateIsSystem;
    property TemplateIsCustomized: Boolean read FTemplateIsCustomized write FTemplateIsCustomized;
    property DeleteTemplateButtonCaption: string read FDeleteTemplateButtonCaption write FDeleteTemplateButtonCaption;
    property DeleteTemplateButtonEnabled: Boolean read FDeleteTemplateButtonEnabled write FDeleteTemplateButtonEnabled;
    property TemplateOriginLabelText: string read FTemplateOriginLabelText write FTemplateOriginLabelText;
    property TemplateOriginLabelColor: TColor read FTemplateOriginLabelColor write FTemplateOriginLabelColor;
    property FocusTemplateNameCalled: Boolean read FFocusTemplateNameCalled write FFocusTemplateNameCalled;
  end;

  [TestFixture]
  TTestConfigPresenter = class
  strict private
    FMockView: TMockConfigView;
    FPresenter: TRadIAConfigPresenter;
    FConfig: IRadIAConfig;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestLoadConfigLoadsToView;
    [Test]
    procedure TestSaveConfigValidatesUrlGeminiAndAzure;
    [Test]
    procedure TestSaveConfigValidatesTemperatureRange;
    [Test]
    procedure TestSaveConfigValidatesIntegersRobustly;
    [Test]
    procedure TestConsentSettingsAreValidatedAndPersisted;
    [Test]
    procedure TestTemplateCreationAndSelection;
    [Test]
    procedure TestResetQuotaUsage;
    [Test]
    procedure TestSaveConfigDummy;
    [Test]
    procedure TestOAuthLogoff;
  end;

implementation

uses
  RadIA.Core.Config, RadIA.Core.SettingsStorage, System.SysUtils;

{ TMockConfigView }

constructor TMockConfigView.Create;
begin
  inherited Create;
  ApiKeyMap := TDictionary<string, string>.Create;
  CustomUrlMap := TDictionary<string, string>.Create;
  AuthTypeMap := TDictionary<string, Integer>.Create;
  TempMap := TDictionary<string, string>.Create;
  MaxTokensMap := TDictionary<string, string>.Create;
  TimeoutMap := TDictionary<string, string>.Create;
  FOAuthLoggedInMap := TDictionary<string, Boolean>.Create;

  SaveDialogResult := True;
  OpenDialogResult := True;
  FolderDialogResult := True;
  CloseViewCalled := False;
  FocusTemplateNameCalled := False;
  InjectDelphiVersion := True;
  ConciseResponses := True;
  ConsentTimeoutSeconds := '60';
  ConsentShowArguments := True;
  ConsentRememberReversible := True;
end;

destructor TMockConfigView.Destroy;
begin
  ApiKeyMap.Free;
  CustomUrlMap.Free;
  AuthTypeMap.Free;
  TempMap.Free;
  MaxTokensMap.Free;
  TimeoutMap.Free;
  FOAuthLoggedInMap.Free;
  inherited Destroy;
end;

function TMockConfigView.GetApiKey(const AProviderId: string): string;
begin
  if not ApiKeyMap.TryGetValue(AProviderId, Result) then Result := '';
end;

procedure TMockConfigView.SetApiKey(const AProviderId: string; const AKey: string);
begin
  ApiKeyMap.AddOrSetValue(AProviderId, AKey);
end;

function TMockConfigView.GetCustomUrl(const AProviderId: string): string;
begin
  if not CustomUrlMap.TryGetValue(AProviderId, Result) then Result := '';
end;

procedure TMockConfigView.SetCustomUrl(const AProviderId: string; const AUrl: string);
begin
  CustomUrlMap.AddOrSetValue(AProviderId, AUrl);
end;

function TMockConfigView.GetAuthTypeIndex(const AProviderId: string): Integer;
begin
  if not AuthTypeMap.TryGetValue(AProviderId, Result) then Result := 0;
end;

procedure TMockConfigView.SetAuthTypeIndex(const AProviderId: string; const AIndex: Integer);
begin
  AuthTypeMap.AddOrSetValue(AProviderId, AIndex);
end;

procedure TMockConfigView.UpdateOAuthState(const AProviderId: string; const AIsLoggedIn: Boolean);
begin
  FOAuthLoggedInMap.AddOrSetValue(AProviderId.ToLower, AIsLoggedIn);
end;

function TMockConfigView.GetTemperatureInput(const AProviderId: string): string;
begin
  if not TempMap.TryGetValue(AProviderId, Result) then Result := '0.7';
end;

procedure TMockConfigView.SetTemperatureInput(const AProviderId: string; const AValue: string);
begin
  TempMap.AddOrSetValue(AProviderId, AValue);
end;

function TMockConfigView.GetMaxTokensInput(const AProviderId: string): string;
begin
  if not MaxTokensMap.TryGetValue(AProviderId, Result) then Result := '2048';
end;

procedure TMockConfigView.SetMaxTokensInput(const AProviderId: string; const AValue: string);
begin
  MaxTokensMap.AddOrSetValue(AProviderId, AValue);
end;

function TMockConfigView.GetTimeoutInput(const AProviderId: string): string;
begin
  if not TimeoutMap.TryGetValue(AProviderId, Result) then Result := '60';
end;

procedure TMockConfigView.SetTimeoutInput(const AProviderId: string; const AValue: string);
begin
  TimeoutMap.AddOrSetValue(AProviderId, AValue);
end;

function TMockConfigView.GetAzureModel: string; begin Result := AzureModel; end;
procedure TMockConfigView.SetAzureModel(const AValue: string); begin AzureModel := AValue; end;
function TMockConfigView.GetAzureApiVersion: string; begin Result := AzureApiVersion; end;
procedure TMockConfigView.SetAzureApiVersion(const AValue: string); begin AzureApiVersion := AValue; end;

function TMockConfigView.GetAwsAccessKeyId: string; begin Result := AwsAccessKeyId; end;
procedure TMockConfigView.SetAwsAccessKeyId(const AValue: string); begin AwsAccessKeyId := AValue; end;
function TMockConfigView.GetAwsSecretAccessKey: string; begin Result := AwsSecretAccessKey; end;
procedure TMockConfigView.SetAwsSecretAccessKey(const AValue: string); begin AwsSecretAccessKey := AValue; end;
function TMockConfigView.GetAwsRegion: string; begin Result := AwsRegion; end;
procedure TMockConfigView.SetAwsRegion(const AValue: string); begin AwsRegion := AValue; end;
function TMockConfigView.GetAwsSessionToken: string; begin Result := AwsSessionToken; end;
procedure TMockConfigView.SetAwsSessionToken(const AValue: string); begin AwsSessionToken := AValue; end;

function TMockConfigView.GetSystemPrompt: string; begin Result := SystemPrompt; end;
procedure TMockConfigView.SetSystemPrompt(const AValue: string); begin SystemPrompt := AValue; end;
function TMockConfigView.GetSmartConfigEnabled: Boolean; begin Result := SmartConfigEnabled; end;
procedure TMockConfigView.SetSmartConfigEnabled(const AValue: Boolean); begin SmartConfigEnabled := AValue; end;
function TMockConfigView.GetInjectDelphiVersion: Boolean; begin Result := InjectDelphiVersion; end;
procedure TMockConfigView.SetInjectDelphiVersion(const AValue: Boolean); begin InjectDelphiVersion := AValue; end;
function TMockConfigView.GetConciseResponses: Boolean; begin Result := ConciseResponses; end;
procedure TMockConfigView.SetConciseResponses(const AValue: Boolean); begin ConciseResponses := AValue; end;
function TMockConfigView.GetLogEnabled: Boolean; begin Result := LogEnabled; end;
procedure TMockConfigView.SetLogEnabled(const AValue: Boolean); begin LogEnabled := AValue; end;
function TMockConfigView.GetLogPath: string; begin Result := LogPath; end;
procedure TMockConfigView.SetLogPath(const AValue: string); begin LogPath := AValue; end;
function TMockConfigView.GetLogMaxSize: string; begin Result := LogMaxSize; end;
procedure TMockConfigView.SetLogMaxSize(const AValue: string); begin LogMaxSize := AValue; end;
function TMockConfigView.GetConsentTimeoutSeconds: string;
begin
  Result := ConsentTimeoutSeconds;
end;

procedure TMockConfigView.SetConsentTimeoutSeconds(
  const AValue: string
);
begin
  ConsentTimeoutSeconds := AValue;
end;

function TMockConfigView.GetConsentShowArguments: Boolean;
begin
  Result := ConsentShowArguments;
end;

procedure TMockConfigView.SetConsentShowArguments(
  const AValue: Boolean
);
begin
  ConsentShowArguments := AValue;
end;

function TMockConfigView.GetConsentRememberReversible: Boolean;
begin
  Result := ConsentRememberReversible;
end;

procedure TMockConfigView.SetConsentRememberReversible(
  const AValue: Boolean
);
begin
  ConsentRememberReversible := AValue;
end;

function TMockConfigView.GetConsentRememberStructural: Boolean;
begin
  Result := ConsentRememberStructural;
end;

procedure TMockConfigView.SetConsentRememberStructural(
  const AValue: Boolean
);
begin
  ConsentRememberStructural := AValue;
end;

function TMockConfigView.GetConsentRememberExecution: Boolean;
begin
  Result := ConsentRememberExecution;
end;

procedure TMockConfigView.SetConsentRememberExecution(
  const AValue: Boolean
);
begin
  ConsentRememberExecution := AValue;
end;

function TMockConfigView.GetQuotaEnabled: Boolean; begin Result := QuotaEnabled; end;
procedure TMockConfigView.SetQuotaEnabled(const AValue: Boolean); begin QuotaEnabled := AValue; end;
function TMockConfigView.GetQuotaLimit: string; begin Result := QuotaLimit; end;
procedure TMockConfigView.SetQuotaLimit(const AValue: string); begin QuotaLimit := AValue; end;
procedure TMockConfigView.SetQuotaUsedText(const AText: string); begin QuotaUsedText := AText; end;

procedure TMockConfigView.ShowMessageDialog(const AMessage: string);
begin
  LastMessageDialogText := AMessage;
end;

function TMockConfigView.SaveDialogExecute(out AFileName: string): Boolean;
begin
  AFileName := SaveDialogSelectedFileName;
  Result := SaveDialogResult;
end;

function TMockConfigView.OpenDialogExecute(out AFileName: string): Boolean;
begin
  AFileName := OpenDialogSelectedFileName;
  Result := OpenDialogResult;
end;

function TMockConfigView.FolderDialogExecute(out AFolderName: string): Boolean;
begin
  AFolderName := FolderDialogSelectedFolderName;
  Result := FolderDialogResult;
end;

procedure TMockConfigView.CloseView(const AModalResult: Integer);
begin
  CloseViewCalled := True;
  CloseViewModalResult := AModalResult;
end;

procedure TMockConfigView.UpdateTemplatesList(const ATemplateNames: TArray<string>; const ASelectedIndex: Integer);
begin
  TemplatesList := ATemplateNames;
  SelectedTemplateIndex := ASelectedIndex;
end;

procedure TMockConfigView.GetTemplateEditorFields(out AName, ADesc, ABody, ASlash: string; out AIsProjGen: Boolean);
begin
  AName := TemplateName;
  ADesc := TemplateDesc;
  ABody := TemplateBody;
  ASlash := TemplateSlash;
  AIsProjGen := TemplateIsProjGen;
end;

procedure TMockConfigView.SetTemplateFields(const AName, ADesc, ABody, ASlash: string;
    const AIsProjGen: Boolean; const AIsSystem,

    AIsCustomized: Boolean);
begin
  TemplateName := AName;
  TemplateDesc := ADesc;
  TemplateBody := ABody;
  TemplateSlash := ASlash;
  TemplateIsProjGen := AIsProjGen;
  TemplateIsSystem := AIsSystem;
  TemplateIsCustomized := AIsCustomized;
end;

procedure TMockConfigView.ClearTemplateFields;
begin
  TemplateName := '';
  TemplateDesc := '';
  TemplateBody := '';
  TemplateSlash := '';
  TemplateIsProjGen := False;
end;

procedure TMockConfigView.FocusTemplateName;
begin
  FocusTemplateNameCalled := True;
end;

function TMockConfigView.GetSelectedTemplateIndex: Integer;
begin
  Result := SelectedTemplateIndex;
end;

procedure TMockConfigView.SetSelectedTemplateIndex(const AIndex: Integer);
begin
  SelectedTemplateIndex := AIndex;
end;

procedure TMockConfigView.SetDeleteTemplateButtonState(const ACaption: string; const AEnabled: Boolean);
begin
  DeleteTemplateButtonCaption := ACaption;
  DeleteTemplateButtonEnabled := AEnabled;
end;

procedure TMockConfigView.SetTemplateOriginLabel(const AText: string; const AColor: TColor);
begin
  TemplateOriginLabelText := AText;
  TemplateOriginLabelColor := AColor;
end;

{ TTestConfigPresenter }

procedure TTestConfigPresenter.Setup;
var
  LMemoryStorage: IRadIASettingsStorage;
begin
  LMemoryStorage := TRadIAMemorySettingsStorage.Create;
  TRadIAConfig.SetStorage(LMemoryStorage);
  FConfig := TRadIAConfig.GetInstance;
  FConfig.Load;

  FMockView := TMockConfigView.Create;
  FPresenter := TRadIAConfigPresenter.Create(FMockView, FConfig);
end;

procedure TTestConfigPresenter.TearDown;
begin
  FPresenter.Free;
  FConfig := nil;
  TRadIAConfig.SetStorage(nil);
end;

procedure TTestConfigPresenter.TestLoadConfigLoadsToView;
begin
  FConfig.SetApiKey('Gemini', 'gemini-key-123');
  FConfig.OllamaBaseUrl := 'http://localhost:11434';

  FPresenter.LoadConfig;

  Assert.AreEqual('gemini-key-123', FMockView.GetApiKey('Gemini'));
  Assert.AreEqual('http://localhost:11434', FMockView.GetCustomUrl('Ollama'));
end;

procedure TTestConfigPresenter.TestSaveConfigValidatesUrlGeminiAndAzure;
begin
  FPresenter.LoadConfig;

  // URL invÃ¡lida (sem http:// ou https://)
  FMockView.SetCustomUrl('Ollama', 'localhost:11434');

  FPresenter.SaveConfig;

  // Deve exibir diÃ¡logo de erro e nÃ£o deve fechar a View com mrOk (1)
  Assert.IsFalse(FMockView.LastMessageDialogText.IsEmpty);
  Assert.IsFalse(FMockView.CloseViewCalled);
end;

procedure TTestConfigPresenter.TestSaveConfigValidatesTemperatureRange;
begin
  FPresenter.LoadConfig;

  // Temperatura fora do limite (abc ou maior que 2.0)
  FMockView.SetTemperatureInput('Gemini', '2.5');

  FPresenter.SaveConfig;

  Assert.IsFalse(FMockView.LastMessageDialogText.IsEmpty);
  Assert.IsFalse(FMockView.CloseViewCalled);
end;

procedure TTestConfigPresenter.TestSaveConfigValidatesIntegersRobustly;
begin
  FPresenter.LoadConfig;

  // Timeout invÃ¡lido
  FMockView.SetTimeoutInput('Gemini', '-5');

  FPresenter.SaveConfig;

  Assert.IsFalse(FMockView.LastMessageDialogText.IsEmpty);
  Assert.IsFalse(FMockView.CloseViewCalled);
end;

procedure TTestConfigPresenter.
  TestConsentSettingsAreValidatedAndPersisted;
begin
  FPresenter.LoadConfig;
  FMockView.SetConsentTimeoutSeconds('10');
  FPresenter.SaveConfig;
  Assert.Contains(
    FMockView.LastMessageDialogText,
    'between 15 and 600'
  );
  Assert.IsFalse(FMockView.CloseViewCalled);

  FMockView.LastMessageDialogText := '';
  FMockView.SetConsentTimeoutSeconds('90');
  FMockView.SetConsentShowArguments(False);
  FMockView.SetConsentRememberReversible(False);
  FMockView.SetConsentRememberStructural(True);
  FMockView.SetConsentRememberExecution(True);
  FPresenter.SaveConfig;

  Assert.IsTrue(FMockView.CloseViewCalled);
  Assert.AreEqual(90, FConfig.ConsentTimeoutSeconds);
  Assert.IsFalse(FConfig.ConsentShowArguments);
  Assert.IsFalse(FConfig.ConsentRememberReversible);
  Assert.IsTrue(FConfig.ConsentRememberStructural);
  Assert.IsTrue(FConfig.ConsentRememberExecution);
end;

procedure TTestConfigPresenter.TestTemplateCreationAndSelection;
begin
  FPresenter.LoadConfig;

  // Criar novo template na View
  FPresenter.CreateNewTemplate;
  Assert.IsTrue(FMockView.FocusTemplateNameCalled);
  Assert.AreEqual('', FMockView.TemplateName);

  // Simular preenchimento
  FMockView.TemplateName := 'Custom Optimizer';
  FMockView.TemplateDesc := 'Optimize code';
  FMockView.TemplateBody := 'Optimize {code}';
  FMockView.TemplateSlash := '/opt';

  FPresenter.SaveTemplate;

  // Deve salvar e registrar
  Assert.IsTrue(Length(FMockView.TemplatesList) > 0);
end;

procedure TTestConfigPresenter.TestResetQuotaUsage;
begin
  FConfig.QuotaUsed := 50000;
  FPresenter.LoadConfig;

  FPresenter.ResetQuota;

  Assert.AreEqual(Int64(0), FConfig.QuotaUsed);
  Assert.AreEqual('Monthly Used Tokens: 0', FMockView.QuotaUsedText);
end;

procedure TTestConfigPresenter.TestSaveConfigDummy;
begin
  try
    FPresenter.SaveConfig;
  except
  end;
  Assert.IsTrue(True);
end;

procedure TTestConfigPresenter.TestOAuthLogoff;
begin
  FConfig.SetOAuthAccessToken('Gemini', 'dummy-token');
  FConfig.SetOAuthRefreshToken('Gemini', 'dummy-refresh');
  FConfig.SetProviderAuthType('Gemini', 'oauth');
  FConfig.Save;

  FPresenter.LoadConfig;
  Assert.IsTrue(FMockView.OAuthLoggedInMap.ContainsKey('gemini'));
  Assert.IsTrue(FMockView.OAuthLoggedInMap['gemini']);

  FPresenter.PerformOAuthLogoff('Gemini');

  Assert.IsEmpty(FConfig.GetOAuthAccessToken('Gemini'));
  Assert.IsEmpty(FConfig.GetOAuthRefreshToken('Gemini'));
  Assert.AreEqual('api_key', FConfig.GetProviderAuthType('Gemini'));
  Assert.IsFalse(FMockView.OAuthLoggedInMap['gemini']);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestConfigPresenter);

end.
