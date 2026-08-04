unit RadIA.Core.Config;

interface

uses
  System.Classes, RadIA.Core.Interfaces, RadIA.Core.TokenUsage,
  RadIA.Core.SettingsStorage;

type
  TRadIAConfig = class(TInterfacedObject, IRadIAConfig)
  private
    class var FBaseRegistryPath: string;
    class var FInstance: TRadIAConfig;
    class var FStorage: IRadIASettingsStorage;
    FActiveProvider: string;
    FSystemPrompt: string;
    FOllamaBaseUrl: string;
    FMaxHistoryMessages: Integer;
    FOpenAICustomBaseUrl: string;
    FSmartConfigEnabled: Boolean;
    FLogEnabled: Boolean;
    FLogPath: string;
    FLogMaxSizeKB: Integer;
    FQuotaEnabled: Boolean;
    FQuotaLimit: Int64;
    FQuotaUsed: Int64;
    FQuotaCycleStart: TDateTime;
    FActiveSessionId: string;
    FAutocompleteEnabled: Boolean;
    FAutocompleteProvider: string;
    FAutocompleteModel: string;
    FAutocompleteDelay: Integer;
    FAutocompleteExcludedFiles: string;
    FAutocompleteExcludedLanguages: string;
    FAutocompleteExcludedProjects: string;
    FAzureApiVersion: string;
    FAwsAccessKeyId: string;
    FAwsSecretAccessKey: string;
    FAwsRegion: string;
    FAwsSessionToken: string;
    FInjectDelphiVersion: Boolean;
    FConciseResponses: Boolean;
    FConsentTimeoutSeconds: Integer;
    FConsentShowArguments: Boolean;
    FConsentRememberReversible: Boolean;
    FConsentRememberStructural: Boolean;
    FConsentRememberExecution: Boolean;

    { Dynamic String-based settings (avoiding TDictionary generics due to BPL RTL unloading bugs) }
    FApiKeysList: TStringList;
    FModelsList: TStringList;
    FTemperaturesList: TStringList;
    FMaxTokensList: TStringList;
    FTimeoutsList: TStringList;
    FBaseUrlsList: TStringList;
    FAuthTypesList: TStringList;
    FOAuthAccessTokensList: TStringList;
    FOAuthRefreshTokensList: TStringList;
    FOAuthTokenExpirationsList: TStringList;

    function TryMigrateLegacyPath(const APath: string; out AMigratedPath: string): Boolean;
    procedure LoadGlobalSettings(const APath: string);
    procedure LoadBedrockSettings(const AProviderName: string);
    procedure LoadApiKey(const AProviderName: string);
    procedure LoadBaseUrl(const AProviderName: string);
    procedure LoadNumericSettings(const AProviderName: string);
    procedure LoadOAuthSettings(const AProviderName: string);
    procedure LoadModelSettings(const AProviderName: string);
    procedure LoadProviderSettings(const AProviderPath, AProviderName: string);
    procedure LoadFromPath(const APath: string);
    procedure SaveToPath(const APath: string);
    function ProtectString(const AValue: string): string;
    function UnprotectString(const AValue: string): string;
    function ReadRegString(const AKey: string; const ADefault: string): string;
    function ReadRegInt(const AKey: string; const ADefault: Integer): Integer;
    function ReadRegDouble(const AKey: string; const ADefault: Double): Double;
    procedure CheckAndResetQuotaCycle;
  protected
    function _AddRef: Integer; stdcall;
    function _Release: Integer; stdcall;
  public
    constructor Create;
    destructor Destroy; override;
    class function GetInstance: IRadIAConfig;
    class procedure SetBaseRegistryPath(const APath: string);
    class function GetRegistryPath: string;
    class procedure SetStorage(const AStorage: IRadIASettingsStorage);

    { IRadIAConfig implementation }
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
  end;

implementation

uses
  System.SysUtils, System.Math, ToolsAPI, RadIA.Core.Logger,
  RadIA.Core.ProviderRegistry, RadIA.Core.ConfigDefaults,
  RadIA.Core.CredentialProtector;

{ TRadIAConfig }

procedure LogDebug(const AMsg: string);
begin
  TLogger.Log(AMsg, 'Config');
end;

constructor TRadIAConfig.Create;
begin
  inherited Create;
  if not Assigned(FStorage) then
    FStorage := TRadIARegistrySettingsStorage.Create;

  LogDebug('TRadIAConfig.Create: Active path = ' + GetRegistryPath);

  FApiKeysList := TStringList.Create;
  FModelsList := TStringList.Create;
  FTemperaturesList := TStringList.Create;
  FMaxTokensList := TStringList.Create;
  FTimeoutsList := TStringList.Create;
  FBaseUrlsList := TStringList.Create;
  FAuthTypesList := TStringList.Create;
  FOAuthAccessTokensList := TStringList.Create;
  FOAuthRefreshTokensList := TStringList.Create;
  FOAuthTokenExpirationsList := TStringList.Create;

  FActiveProvider := TConfigDefaults.ActiveProvider;
  FSystemPrompt := CDefaultSystemPrompt;
  FOllamaBaseUrl := TConfigDefaults.OllamaBaseUrl;
  FMaxHistoryMessages := TConfigDefaults.MaxHistoryMessages;
  FOpenAICustomBaseUrl := '';
  FAzureApiVersion := TConfigDefaults.AzureApiVersion;
  FAwsAccessKeyId := '';
  FAwsSecretAccessKey := '';
  FAwsRegion := TConfigDefaults.AwsRegion;
  FAwsSessionToken := '';

  FSmartConfigEnabled := True;
  FLogEnabled := True;
  FLogPath := TConfigDefaults.LogPath;
  FLogMaxSizeKB := TConfigDefaults.LogMaxSizeKB;

  FQuotaEnabled := False;
  FQuotaLimit := TConfigDefaults.QuotaLimit;
  FQuotaUsed := 0;
  FQuotaCycleStart := Now;
  FActiveSessionId := '';

  FAutocompleteEnabled := False;
  FAutocompleteProvider := TConfigDefaults.AutocompleteProvider;
  FAutocompleteModel := TConfigDefaults.AutocompleteModel;
  FAutocompleteDelay := TConfigDefaults.AutocompleteDelay;
  FAutocompleteExcludedFiles := '';
  FAutocompleteExcludedLanguages := '';
  FAutocompleteExcludedProjects := '';
  FInjectDelphiVersion := True;
  FConciseResponses := True;
  FConsentTimeoutSeconds := 60;
  FConsentShowArguments := True;
  FConsentRememberReversible := True;
  FConsentRememberStructural := False;
  FConsentRememberExecution := False;

  Load;
end;

destructor TRadIAConfig.Destroy;
begin
  FApiKeysList.Free;
  FModelsList.Free;
  FTemperaturesList.Free;
  FMaxTokensList.Free;
  FTimeoutsList.Free;
  FBaseUrlsList.Free;
  FAuthTypesList.Free;
  FOAuthAccessTokensList.Free;
  FOAuthRefreshTokensList.Free;
  FOAuthTokenExpirationsList.Free;
  inherited Destroy;
end;

class procedure TRadIAConfig.SetBaseRegistryPath(const APath: string);
begin
  FBaseRegistryPath := APath;
end;

function TRadIAConfig.GetActiveProvider: string;
begin
  Result := FActiveProvider;
end;

function TRadIAConfig.GetSystemPrompt: string;
begin
  Result := FSystemPrompt;
end;

{ Registry read helpers â€” encapsulate the try/except boilerplate }

function TRadIAConfig.ReadRegString(const AKey: string; const ADefault: string): string;
begin
  Result := FStorage.ReadString(AKey, ADefault);
end;

function TRadIAConfig.ReadRegInt(const AKey: string; const ADefault: Integer): Integer;
begin
  Result := FStorage.ReadInteger(AKey, ADefault);
end;

function TRadIAConfig.ReadRegDouble(const AKey: string; const ADefault: Double): Double;
begin
  Result := FStorage.ReadFloat(AKey, ADefault);
end;

class function TRadIAConfig.GetRegistryPath: string;
var
  LOTAServices: IOTAServices;
  LSettings: TFormatSettings;
  LBdsVersion: Double;
begin
  if not FBaseRegistryPath.IsEmpty then
  begin
    Result := FBaseRegistryPath;
    Exit;
  end;

  if Assigned(BorlandIDEServices) and Supports(BorlandIDEServices, IOTAServices, LOTAServices) then
  begin
    Result := LOTAServices.GetBaseRegistryKey + '\RadIA';
    Exit;
  end;

  LSettings := TFormatSettings.Create('en-US');
  if CompilerVersion >= 37.0 then
    LBdsVersion := CompilerVersion
  else
    LBdsVersion := CompilerVersion - 13.0;

  Result := Format('Software\Embarcadero\BDS\%0.1f\RadIA', [LBdsVersion], LSettings);
end;

procedure TRadIAConfig.Load;
begin
  LoadFromPath(GetRegistryPath);
end;

function TRadIAConfig.TryMigrateLegacyPath(const APath: string; out AMigratedPath: string): Boolean;
var
  LParentPath: string;
begin
  Result := False;
  AMigratedPath := '';

  if FStorage.KeyExists(APath) then
    Exit;

  LogDebug('TRadIAConfig.Load: Path does not exist, checking for migration path...');

  { 1. If the path contains a backslash, try IDE-relative legacy paths. }
  if Pos('\', APath) > 0 then
  begin
    LParentPath := Copy(APath, 1, LastDelimiter('\', APath));
    if FStorage.KeyExists(LParentPath + 'AIPlugin') then
      AMigratedPath := LParentPath + 'AIPlugin'
    else if FStorage.KeyExists(LParentPath + 'RadIA') then
      AMigratedPath := LParentPath + 'RadIA';
  end;

  { 2. Global fallbacks. }
  if AMigratedPath.IsEmpty then
  begin
    if FStorage.KeyExists('Software\RadIA') then
      AMigratedPath := 'Software\RadIA'
    else if FStorage.KeyExists('Software\RadAI') then
      AMigratedPath := 'Software\RadAI';
  end;

  Result := not AMigratedPath.IsEmpty and (AMigratedPath <> APath);
end;

procedure TRadIAConfig.LoadGlobalSettings(const APath: string);
var
  LMaxHist: Integer;
begin
  if FStorage.OpenKey(APath, False) then
  begin
    LogDebug('TRadIAConfig.Load: Opened root path ' + APath);
    FActiveProvider := FStorage.ReadString('ActiveProvider', TConfigDefaults.ActiveProvider);
    FSystemPrompt      := ReadRegString('SystemPrompt', CDefaultSystemPrompt);

    LMaxHist := ReadRegInt('MaxHistoryMessages', TConfigDefaults.MaxHistoryMessages);
    FMaxHistoryMessages := IfThen(LMaxHist > 0, LMaxHist, TConfigDefaults.MaxHistoryMessages);
    FSmartConfigEnabled := ReadRegInt('SmartConfigEnabled', 1) <> 0;
    FLogEnabled := ReadRegInt('LogEnabled', 1) <> 0;
    FLogPath := ReadRegString('LogPath', TConfigDefaults.LogPath);
    FLogMaxSizeKB := ReadRegInt('LogMaxSizeKB', TConfigDefaults.LogMaxSizeKB);
    FQuotaEnabled := ReadRegInt('QuotaEnabled', 0) <> 0;
    FQuotaLimit := StrToInt64Def(
      ReadRegString('QuotaLimit', TConfigDefaults.QuotaLimit.ToString),
      TConfigDefaults.QuotaLimit);
    FQuotaUsed := StrToInt64Def(ReadRegString('QuotaUsed', '0'), 0);
    FQuotaCycleStart := ReadRegDouble('QuotaCycleStart', Now);
    FActiveSessionId := ReadRegString('ActiveSessionId', '');

    FAutocompleteEnabled := ReadRegInt(
      'InlineCompletionEnabled',
      0
    ) <> 0;
    FAutocompleteProvider := FStorage.ReadString('AutocompleteProvider', TConfigDefaults.AutocompleteProvider);
    FAutocompleteModel := ReadRegString('AutocompleteModel', TConfigDefaults.AutocompleteModel);
    FAutocompleteDelay := EnsureRange(
      ReadRegInt(
        'AutocompleteDelay',
        TConfigDefaults.AutocompleteDelay
      ),
      250,
      5000
    );
    FAutocompleteExcludedFiles := ReadRegString(
      'AutocompleteExcludedFiles',
      ''
    );
    FAutocompleteExcludedLanguages := ReadRegString(
      'AutocompleteExcludedLanguages',
      ''
    );
    FAutocompleteExcludedProjects := ReadRegString(
      'AutocompleteExcludedProjects',
      ''
    );
    FInjectDelphiVersion := ReadRegInt('InjectDelphiVersion', 1) <> 0;
    FConciseResponses := ReadRegInt('ConciseResponses', 1) <> 0;
    FConsentTimeoutSeconds := EnsureRange(
      ReadRegInt('ConsentTimeoutSeconds', 60),
      15,
      600
    );
    FConsentShowArguments := ReadRegInt('ConsentShowArguments', 1) <> 0;
    FConsentRememberReversible :=
      ReadRegInt('ConsentRememberReversible', 1) <> 0;
    FConsentRememberStructural :=
      ReadRegInt('ConsentRememberStructural', 0) <> 0;
    FConsentRememberExecution :=
      ReadRegInt('ConsentRememberExecution', 0) <> 0;

    FStorage.CloseKey;

    CheckAndResetQuotaCycle;
    TLogger.Configure(FLogEnabled, FLogPath, FLogMaxSizeKB);
  end
  else
    LogDebug('TRadIAConfig.Load: Failed to open root path ' + APath);
end;

procedure TRadIAConfig.LoadBedrockSettings(const AProviderName: string);
begin
  FAwsRegion := ReadRegString('Region', TConfigDefaults.AwsRegion);
  try
    if FStorage.ValueExists('AccessKeyId') then
      FAwsAccessKeyId := UnprotectString(FStorage.ReadString('AccessKeyId', ''));
  except
    on E: Exception do
    begin
      LogDebug('TRadIAConfig.Load: Failed to unprotect Bedrock AccessKeyId: ' + E.Message);
      FAwsAccessKeyId := '';
    end;
  end;
  try
    if FStorage.ValueExists('SecretAccessKey') then
      FAwsSecretAccessKey := UnprotectString(FStorage.ReadString('SecretAccessKey', ''));
  except
    on E: Exception do
    begin
      LogDebug('TRadIAConfig.Load: Failed to unprotect Bedrock SecretAccessKey: ' + E.Message);
      FAwsSecretAccessKey := '';
    end;
  end;
  try
    if FStorage.ValueExists('SessionToken') then
      FAwsSessionToken := UnprotectString(FStorage.ReadString('SessionToken', ''));
  except
    on E: Exception do
    begin
      LogDebug('TRadIAConfig.Load: Failed to unprotect Bedrock SessionToken: ' + E.Message);
      FAwsSessionToken := '';
    end;
  end;
end;

procedure TRadIAConfig.LoadNumericSettings(const AProviderName: string);
begin
  FTemperaturesList.Values[AProviderName.ToLower] := FloatToStr(
    ReadRegDouble('Temperature', TConfigDefaults.Temperature),
    TFormatSettings.Invariant);
  FMaxTokensList.Values[AProviderName.ToLower] := IntToStr(
    ReadRegInt('MaxTokens', TConfigDefaults.MaxTokens));
  FTimeoutsList.Values[AProviderName.ToLower] := IntToStr(
    ReadRegInt('Timeout', TConfigDefaults.Timeout));
  FAuthTypesList.Values[AProviderName.ToLower] := ReadRegString(
    'AuthType',
    TConfigDefaults.ProviderAuthType);
end;

procedure TRadIAConfig.LoadApiKey(const AProviderName: string);
begin
  if FStorage.ValueExists('ApiKey') then
  begin
    try
      FApiKeysList.Values[AProviderName.ToLower] := UnprotectString(FStorage.ReadString('ApiKey', ''));
    except
      on E: Exception do
      begin
        LogDebug('TRadIAConfig.Load: Failed to unprotect API key for ' + AProviderName + ': ' + E.Message);
        FApiKeysList.Values[AProviderName.ToLower] := '';
      end;
    end;
  end;
end;

procedure TRadIAConfig.LoadBaseUrl(const AProviderName: string);
begin
  if FStorage.ValueExists('BaseURL') then
  begin
    FBaseUrlsList.Values[AProviderName.ToLower] := FStorage.ReadString('BaseURL', '');
    if SameText(AProviderName, 'openai') then
      FOpenAICustomBaseUrl := FStorage.ReadString('BaseURL', '')
    else if SameText(AProviderName, 'ollama') then
      FOllamaBaseUrl := FStorage.ReadString('BaseURL', '');
  end;
end;

procedure TRadIAConfig.LoadModelSettings(const AProviderName: string);
begin
  if FStorage.ValueExists('Model') then
    FModelsList.Values[AProviderName.ToLower] := FStorage.ReadString('Model', '')
  else if FStorage.ValueExists('ActiveModel') then
    FModelsList.Values[AProviderName.ToLower] := FStorage.ReadString('ActiveModel', '');
end;

procedure TRadIAConfig.LoadOAuthSettings(const AProviderName: string);
begin
  if FStorage.ValueExists('OAuthAccessToken') then
  begin
    try
      FOAuthAccessTokensList.Values[AProviderName.ToLower] := UnprotectString(
        FStorage.ReadString('OAuthAccessToken', '')
      );
    except
      on E: Exception do
        LogDebug('Failed to unprotect OAuthAccessToken for ' + AProviderName + ': ' + E.Message);
    end;
  end;

  if FStorage.ValueExists('OAuthRefreshToken') then
  begin
    try
      FOAuthRefreshTokensList.Values[AProviderName.ToLower] := UnprotectString(
        FStorage.ReadString('OAuthRefreshToken', '')
      );
    except
      on E: Exception do
        LogDebug('Failed to unprotect OAuthRefreshToken for ' + AProviderName + ': ' + E.Message);
    end;
  end;

  if FStorage.ValueExists('OAuthTokenExpiry') then
  begin
    FOAuthTokenExpirationsList.Values[AProviderName.ToLower] := FloatToStr(
      FStorage.ReadFloat('OAuthTokenExpiry', 0),
      TFormatSettings.Invariant
    );
  end;
end;

procedure TRadIAConfig.LoadProviderSettings(const AProviderPath, AProviderName: string);
begin
  LogDebug('TRadIAConfig.Load: Reading subkey for provider ' + AProviderName);
  if FStorage.OpenKey(AProviderPath, False) then
  begin
    LoadApiKey(AProviderName);
    LoadModelSettings(AProviderName);
    LoadBaseUrl(AProviderName);
    LoadOAuthSettings(AProviderName);

    if SameText(AProviderName, 'AzureOpenAI') then
      FAzureApiVersion := ReadRegString('ApiVersion', TConfigDefaults.AzureApiVersion);
    if SameText(AProviderName, 'Bedrock') then
      LoadBedrockSettings(AProviderName);

    LoadNumericSettings(AProviderName);
    FStorage.CloseKey;
  end;
end;

procedure TRadIAConfig.LoadFromPath(const APath: string);
var
  LProvPath: string;
  LMigratedPath: string;
  LSubKeys: TStringList;
  LSubKey: string;
  LProviders: TArray<TProviderMetadata>;
  LMeta: TProviderMetadata;
begin
  LogDebug('TRadIAConfig.Load starting. Path = ' + APath);

  { If the new key does not exist, try to migrate legacy keys. }
  if TryMigrateLegacyPath(APath, LMigratedPath) then
  begin
    LogDebug('TRadIAConfig.Load: Found migration path: ' + LMigratedPath);
    LoadFromPath(LMigratedPath);
    SaveToPath(APath);
    Exit;
  end;

  { 1. Read global keys from the root path. }
  LoadGlobalSettings(APath);

  { Initialize default fallback models before loading subkeys }
  LProviders := TProviderRegistry.GetProviders;
  for LMeta in LProviders do
  begin
    if Length(LMeta.DefaultModels) > 0 then
      FModelsList.Values[LMeta.Id.ToLower] := LMeta.DefaultModels[0];
  end;

  { 2. Read registered provider-specific settings from dedicated subkeys. }
  LSubKeys := TStringList.Create;
  try
    if FStorage.OpenKey(APath, False) then
    begin
      FStorage.GetKeyNames(LSubKeys);
      FStorage.CloseKey;
    end;

    for LSubKey in LSubKeys do
    begin
      LProvPath := APath + '\' + LSubKey;
      LoadProviderSettings(LProvPath, LSubKey);
    end;
  finally
    LSubKeys.Free;
  end;
end;

function TRadIAConfig.ProtectString(const AValue: string): string;
begin
  Result := TCredentialProtector.Protect(AValue);
end;

procedure TRadIAConfig.Save;
begin
  SaveToPath(GetRegistryPath);
end;

procedure TRadIAConfig.SaveToPath(const APath: string);
var
  LKey: string;
  LProvPath: string;
  LProviders: TArray<TProviderMetadata>;
  LMeta: TProviderMetadata;
begin
  LogDebug('TRadIAConfig.Save starting. Path = ' + APath);

  { 1. Salvar chaves globais na raiz }
  if FStorage.OpenKey(APath, True) then
  begin
    FStorage.WriteString('ActiveProvider', FActiveProvider);
    FStorage.WriteString('SystemPrompt', FSystemPrompt);
    FStorage.WriteInteger('MaxHistoryMessages', FMaxHistoryMessages);
    FStorage.WriteInteger('SmartConfigEnabled', IfThen(FSmartConfigEnabled, 1, 0));
    FStorage.WriteInteger('LogEnabled', IfThen(FLogEnabled, 1, 0));
    FStorage.WriteString('LogPath', FLogPath);
    FStorage.WriteInteger('LogMaxSizeKB', FLogMaxSizeKB);
    FStorage.WriteInteger('QuotaEnabled', IfThen(FQuotaEnabled, 1, 0));
    FStorage.WriteString('QuotaLimit', FQuotaLimit.ToString);
    FStorage.WriteString('QuotaUsed', FQuotaUsed.ToString);
    FStorage.WriteFloat('QuotaCycleStart', FQuotaCycleStart);
    FStorage.WriteString('ActiveSessionId', FActiveSessionId);

    FStorage.WriteInteger(
      'InlineCompletionEnabled',
      IfThen(FAutocompleteEnabled, 1, 0)
    );
    FStorage.WriteString('AutocompleteProvider', FAutocompleteProvider);
    FStorage.WriteString('AutocompleteModel', FAutocompleteModel);
    FStorage.WriteInteger('AutocompleteDelay', FAutocompleteDelay);
    FStorage.WriteString(
      'AutocompleteExcludedFiles',
      FAutocompleteExcludedFiles
    );
    FStorage.WriteString(
      'AutocompleteExcludedLanguages',
      FAutocompleteExcludedLanguages
    );
    FStorage.WriteString(
      'AutocompleteExcludedProjects',
      FAutocompleteExcludedProjects
    );
    FStorage.WriteInteger('InjectDelphiVersion', IfThen(FInjectDelphiVersion, 1, 0));
    FStorage.WriteInteger('ConciseResponses', IfThen(FConciseResponses, 1, 0));
    FStorage.WriteInteger('ConsentTimeoutSeconds', FConsentTimeoutSeconds);
    FStorage.WriteInteger(
      'ConsentShowArguments',
      IfThen(FConsentShowArguments, 1, 0)
    );
    FStorage.WriteInteger(
      'ConsentRememberReversible',
      IfThen(FConsentRememberReversible, 1, 0)
    );
    FStorage.WriteInteger(
      'ConsentRememberStructural',
      IfThen(FConsentRememberStructural, 1, 0)
    );
    FStorage.WriteInteger(
      'ConsentRememberExecution',
      IfThen(FConsentRememberExecution, 1, 0)
    );
    FStorage.CloseKey;

    TLogger.Configure(FLogEnabled, FLogPath, FLogMaxSizeKB);
  end;

  { Keep legacy public properties backed by provider-specific values. }
  SetProviderBaseUrl('openai', FOpenAICustomBaseUrl);
  SetProviderBaseUrl('ollama', FOllamaBaseUrl);

  { 2. Salvar chaves de todos os provedores em subchaves dedicadas }
  LProviders := TProviderRegistry.GetProviders;
  for LMeta in LProviders do
  begin
    LKey := LMeta.Id;
    LProvPath := APath + '\' + LKey;
    if FStorage.OpenKey(LProvPath, True) then
    begin
      FStorage.WriteString('ApiKey', ProtectString(GetApiKey(LKey)));
      FStorage.WriteString('Model', GetActiveModel(LKey));

      if FBaseUrlsList.IndexOfName(LKey.ToLower) >= 0 then
        FStorage.WriteString('BaseURL', GetProviderBaseUrl(LKey));

      if SameText(LKey, 'AzureOpenAI') then
        FStorage.WriteString('ApiVersion', GetAzureApiVersion);

      if SameText(LKey, 'Bedrock') then
      begin
        FStorage.WriteString('Region', GetAwsRegion);
        FStorage.WriteString('AccessKeyId', ProtectString(GetAwsAccessKeyId));
        FStorage.WriteString('SecretAccessKey', ProtectString(GetAwsSecretAccessKey));
        FStorage.WriteString('SessionToken', ProtectString(GetAwsSessionToken));
      end;

      FStorage.WriteFloat('Temperature', GetTemperature(LKey));
      FStorage.WriteInteger('MaxTokens', GetMaxTokens(LKey));
      FStorage.WriteInteger('Timeout', GetTimeout(LKey));
      FStorage.WriteString('AuthType', GetProviderAuthType(LKey));

      FStorage.WriteString('OAuthAccessToken', ProtectString(GetOAuthAccessToken(LKey)));
      FStorage.WriteString('OAuthRefreshToken', ProtectString(GetOAuthRefreshToken(LKey)));
      FStorage.WriteFloat('OAuthTokenExpiry', GetOAuthTokenExpiry(LKey));

      FStorage.CloseKey;
      LogDebug('TRadIAConfig.Save: Saved ApiKey and Model (' + GetActiveModel(LKey) + ') for ' + LKey);
    end;
  end;
end;

procedure TRadIAConfig.SetActiveProvider(const AProvider: string);
begin
  FActiveProvider := AProvider;
end;

procedure TRadIAConfig.SetSystemPrompt(const AValue: string);
begin
  FSystemPrompt := AValue;
end;

function TRadIAConfig.GetOllamaBaseUrl: string;
begin
  Result := FOllamaBaseUrl;
end;

procedure TRadIAConfig.SetOllamaBaseUrl(const AValue: string);
var
  LVal: string;
begin
  LVal := AValue.Trim;
  if LVal.EndsWith('/') then
    LVal := LVal.Substring(0, LVal.Length - 1);
  FOllamaBaseUrl := LVal;
  SetProviderBaseUrl('ollama', LVal);
end;

function TRadIAConfig.GetMaxHistoryMessages: Integer;
begin
  Result := FMaxHistoryMessages;
end;

procedure TRadIAConfig.SetMaxHistoryMessages(const AValue: Integer);
begin
  if AValue > 0 then
    FMaxHistoryMessages := AValue
  else
    FMaxHistoryMessages := 20;
end;

function TRadIAConfig.GetOpenAICustomBaseUrl: string;
begin
  Result := FOpenAICustomBaseUrl;
end;

procedure TRadIAConfig.SetOpenAICustomBaseUrl(const AValue: string);
var
  LVal: string;
begin
  LVal := AValue.Trim;
  if LVal.EndsWith('/') then
    LVal := LVal.Substring(0, LVal.Length - 1);
  FOpenAICustomBaseUrl := LVal;
  SetProviderBaseUrl('openai', LVal);
end;

function TRadIAConfig.GetAzureApiVersion: string;
begin
  Result := FAzureApiVersion;
  if Result.IsEmpty then
    Result := TConfigDefaults.AzureApiVersion;
end;

procedure TRadIAConfig.SetAzureApiVersion(const AValue: string);
begin
  FAzureApiVersion := AValue.Trim;
end;

function TRadIAConfig.GetAwsAccessKeyId: string;
begin
  Result := FAwsAccessKeyId;
end;

procedure TRadIAConfig.SetAwsAccessKeyId(const AValue: string);
begin
  FAwsAccessKeyId := AValue.Trim;
end;

function TRadIAConfig.GetAwsSecretAccessKey: string;
begin
  Result := FAwsSecretAccessKey;
end;

procedure TRadIAConfig.SetAwsSecretAccessKey(const AValue: string);
begin
  FAwsSecretAccessKey := AValue.Trim;
end;

function TRadIAConfig.GetAwsRegion: string;
begin
  Result := FAwsRegion;
  if Result.IsEmpty then
    Result := TConfigDefaults.AwsRegion;
end;

procedure TRadIAConfig.SetAwsRegion(const AValue: string);
begin
  FAwsRegion := AValue.Trim;
end;

function TRadIAConfig.GetAwsSessionToken: string;
begin
  Result := FAwsSessionToken;
end;

procedure TRadIAConfig.SetAwsSessionToken(const AValue: string);
begin
  FAwsSessionToken := AValue.Trim;
end;

{ Dynamic String-based getters and setters }

function TRadIAConfig.GetApiKey(const AProviderName: string): string;
begin
  if AProviderName.IsEmpty then
    Exit('');
  Result := FApiKeysList.Values[AProviderName.ToLower];
end;

procedure TRadIAConfig.SetApiKey(const AProviderName: string; const AKey: string);
begin
  if AProviderName.IsEmpty then
    Exit;
  FApiKeysList.Values[AProviderName.ToLower] := TCredentialProtector.CleanApiKey(AKey);
end;

function TRadIAConfig.GetActiveModel(const AProviderName: string): string;
begin
  if AProviderName.IsEmpty then
    Exit('');
  Result := FModelsList.Values[AProviderName.ToLower];
end;

procedure TRadIAConfig.SetActiveModel(const AProviderName: string; const AModel: string);
begin
  if AProviderName.IsEmpty then
    Exit;
  FModelsList.Values[AProviderName.ToLower] := AModel;
end;

function TRadIAConfig.GetTemperature(const AProviderName: string): Double;
var
  LStr: string;
begin
  if AProviderName.IsEmpty then
    Exit(TConfigDefaults.Temperature);
  LStr := FTemperaturesList.Values[AProviderName.ToLower];
  Result := StrToFloatDef(LStr, TConfigDefaults.Temperature, TFormatSettings.Invariant);
end;

procedure TRadIAConfig.SetTemperature(const AProviderName: string; const AValue: Double);
begin
  if AProviderName.IsEmpty then
    Exit;
  FTemperaturesList.Values[AProviderName.ToLower] := FloatToStr(AValue, TFormatSettings.Invariant);
end;

function TRadIAConfig.GetMaxTokens(const AProviderName: string): Integer;
var
  LStr: string;
begin
  if AProviderName.IsEmpty then
    Exit(TConfigDefaults.MaxTokens);
  LStr := FMaxTokensList.Values[AProviderName.ToLower];
  Result := StrToIntDef(LStr, TConfigDefaults.MaxTokens);
end;

procedure TRadIAConfig.SetMaxTokens(const AProviderName: string; const AValue: Integer);
begin
  if AProviderName.IsEmpty then
    Exit;
  FMaxTokensList.Values[AProviderName.ToLower] := IntToStr(AValue);
end;

function TRadIAConfig.GetTimeout(const AProviderName: string): Integer;
var
  LStr: string;
begin
  if AProviderName.IsEmpty then
    Exit(TConfigDefaults.Timeout);
  LStr := FTimeoutsList.Values[AProviderName.ToLower];
  Result := StrToIntDef(LStr, TConfigDefaults.Timeout);
end;

procedure TRadIAConfig.SetTimeout(const AProviderName: string; const AValue: Integer);
begin
  if AProviderName.IsEmpty then
    Exit;
  FTimeoutsList.Values[AProviderName.ToLower] := IntToStr(AValue);
end;

function TRadIAConfig.GetProviderBaseUrl(const AProviderName: string): string;
begin
  if AProviderName.IsEmpty then
    Exit('');
  Result := FBaseUrlsList.Values[AProviderName.ToLower];
end;

procedure TRadIAConfig.SetProviderBaseUrl(const AProviderName: string; const AUrl: string);
begin
  if AProviderName.IsEmpty then
    Exit;
  FBaseUrlsList.Values[AProviderName.ToLower] := AUrl;
end;

function TRadIAConfig.GetProviderAuthType(const AProviderName: string): string;
begin
  if AProviderName.IsEmpty then
    Exit(TConfigDefaults.ProviderAuthType);
  Result := FAuthTypesList.Values[AProviderName.ToLower];
  if Result.IsEmpty then
    Result := TConfigDefaults.ProviderAuthType;
end;

procedure TRadIAConfig.SetProviderAuthType(const AProviderName: string; const AValue: string);
begin
  if AProviderName.IsEmpty then
    Exit;
  FAuthTypesList.Values[AProviderName.ToLower] := AValue;
end;

function TRadIAConfig.GetInjectDelphiVersion: Boolean;
begin
  Result := FInjectDelphiVersion;
end;

procedure TRadIAConfig.SetInjectDelphiVersion(const AValue: Boolean);
begin
  FInjectDelphiVersion := AValue;
end;

function TRadIAConfig.GetConciseResponses: Boolean;
begin
  Result := FConciseResponses;
end;

procedure TRadIAConfig.SetConciseResponses(const AValue: Boolean);
begin
  FConciseResponses := AValue;
end;

function TRadIAConfig.GetConsentTimeoutSeconds: Integer;
begin
  Result := FConsentTimeoutSeconds;
end;

procedure TRadIAConfig.SetConsentTimeoutSeconds(const AValue: Integer);
begin
  FConsentTimeoutSeconds := EnsureRange(AValue, 15, 600);
end;

function TRadIAConfig.GetConsentShowArguments: Boolean;
begin
  Result := FConsentShowArguments;
end;

procedure TRadIAConfig.SetConsentShowArguments(const AValue: Boolean);
begin
  FConsentShowArguments := AValue;
end;

function TRadIAConfig.GetConsentRememberReversible: Boolean;
begin
  Result := FConsentRememberReversible;
end;

procedure TRadIAConfig.SetConsentRememberReversible(
  const AValue: Boolean
);
begin
  FConsentRememberReversible := AValue;
end;

function TRadIAConfig.GetConsentRememberStructural: Boolean;
begin
  Result := FConsentRememberStructural;
end;

procedure TRadIAConfig.SetConsentRememberStructural(
  const AValue: Boolean
);
begin
  FConsentRememberStructural := AValue;
end;

function TRadIAConfig.GetConsentRememberExecution: Boolean;
begin
  Result := FConsentRememberExecution;
end;

procedure TRadIAConfig.SetConsentRememberExecution(
  const AValue: Boolean
);
begin
  FConsentRememberExecution := AValue;
end;

function TRadIAConfig.GetAutocompleteEnabled: Boolean;
begin
  Result := FAutocompleteEnabled;
end;

procedure TRadIAConfig.SetAutocompleteEnabled(const AValue: Boolean);
begin
  FAutocompleteEnabled := AValue;
end;

function TRadIAConfig.GetAutocompleteProvider: string;
begin
  Result := FAutocompleteProvider;
end;

procedure TRadIAConfig.SetAutocompleteProvider(const AProvider: string);
begin
  FAutocompleteProvider := AProvider;
end;

function TRadIAConfig.GetAutocompleteModel: string;
begin
  Result := FAutocompleteModel;
end;

procedure TRadIAConfig.SetAutocompleteModel(const AModel: string);
begin
  FAutocompleteModel := AModel;
end;

function TRadIAConfig.GetAutocompleteDelay: Integer;
begin
  Result := FAutocompleteDelay;
end;

function TRadIAConfig.GetAutocompleteExcludedFiles: string;
begin
  Result := FAutocompleteExcludedFiles;
end;

function TRadIAConfig.GetAutocompleteExcludedLanguages: string;
begin
  Result := FAutocompleteExcludedLanguages;
end;

function TRadIAConfig.GetAutocompleteExcludedProjects: string;
begin
  Result := FAutocompleteExcludedProjects;
end;

procedure TRadIAConfig.SetAutocompleteDelay(const AValue: Integer);
begin
  FAutocompleteDelay := EnsureRange(AValue, 250, 5000);
end;

procedure TRadIAConfig.SetAutocompleteExcludedFiles(
  const AValue: string
);
begin
  FAutocompleteExcludedFiles := AValue.Trim;
end;

procedure TRadIAConfig.SetAutocompleteExcludedLanguages(
  const AValue: string
);
begin
  FAutocompleteExcludedLanguages := AValue.Trim;
end;

procedure TRadIAConfig.SetAutocompleteExcludedProjects(
  const AValue: string
);
begin
  FAutocompleteExcludedProjects := AValue.Trim;
end;

function TRadIAConfig.GetSmartConfigEnabled: Boolean;
begin
  Result := FSmartConfigEnabled;
end;

procedure TRadIAConfig.SetSmartConfigEnabled(const AValue: Boolean);
begin
  FSmartConfigEnabled := AValue;
end;

function TRadIAConfig.GetLogEnabled: Boolean;
begin
  Result := FLogEnabled;
end;

procedure TRadIAConfig.SetLogEnabled(const AValue: Boolean);
begin
  FLogEnabled := AValue;
end;

function TRadIAConfig.GetLogPath: string;
begin
  Result := FLogPath;
end;

procedure TRadIAConfig.SetLogPath(const AValue: string);
begin
  FLogPath := AValue;
end;

function TRadIAConfig.GetLogMaxSizeKB: Integer;
begin
  Result := FLogMaxSizeKB;
end;

procedure TRadIAConfig.SetLogMaxSizeKB(const AValue: Integer);
begin
  FLogMaxSizeKB := AValue;
end;

function TRadIAConfig.GetQuotaEnabled: Boolean;
begin
  Result := FQuotaEnabled;
end;

procedure TRadIAConfig.SetQuotaEnabled(const AValue: Boolean);
begin
  FQuotaEnabled := AValue;
end;

function TRadIAConfig.GetQuotaLimit: Int64;
begin
  Result := FQuotaLimit;
end;

procedure TRadIAConfig.SetQuotaLimit(const AValue: Int64);
begin
  FQuotaLimit := AValue;
end;

function TRadIAConfig.GetQuotaUsed: Int64;
begin
  Result := FQuotaUsed;
end;

procedure TRadIAConfig.SetQuotaUsed(const AValue: Int64);
begin
  FQuotaUsed := AValue;
end;

function TRadIAConfig.GetQuotaCycleStart: TDateTime;
begin
  Result := FQuotaCycleStart;
end;

procedure TRadIAConfig.SetQuotaCycleStart(const AValue: TDateTime);
begin
  FQuotaCycleStart := AValue;
end;

function TRadIAConfig.GetActiveSessionId: string;
begin
  Result := FActiveSessionId;
end;

procedure TRadIAConfig.SetActiveSessionId(const AValue: string);
begin
  FActiveSessionId := AValue;
end;

procedure TRadIAConfig.AddToQuotaUsage(const AUsage: TTokenUsage);
begin
  if not FQuotaEnabled then
    Exit;

  CheckAndResetQuotaCycle;
  FQuotaUsed := FQuotaUsed + AUsage.TotalTokens;
  Save;
end;

procedure TRadIAConfig.CheckAndResetQuotaCycle;
var
  LYear, LMonth, LDay: Word;
  LCycleYear, LCycleMonth, LCycleDay: Word;
begin
  DecodeDate(Now, LYear, LMonth, LDay);
  DecodeDate(FQuotaCycleStart, LCycleYear, LCycleMonth, LCycleDay);

  if (LYear <> LCycleYear) or (LMonth <> LCycleMonth) then
  begin
    FQuotaUsed := 0;
    FQuotaCycleStart := Now;
    Save;
  end;
end;

function TRadIAConfig.IsWebLoginProvider(const AProviderName: string): Boolean;
begin
  Result := False;
end;

function TRadIAConfig.GetOAuthAccessToken(const AProviderName: string): string;
begin
  if AProviderName.IsEmpty then
    Exit('');
  Result := FOAuthAccessTokensList.Values[AProviderName.ToLower];
end;

procedure TRadIAConfig.SetOAuthAccessToken(const AProviderName: string; const AValue: string);
begin
  if AProviderName.IsEmpty then
    Exit;
  FOAuthAccessTokensList.Values[AProviderName.ToLower] := AValue;
end;

procedure TRadIAConfig.ClearOAuthTokens(const AProviderName: string);
begin
  if AProviderName.IsEmpty then
    Exit;
  FOAuthAccessTokensList.Values[AProviderName.ToLower] := '';
  FOAuthRefreshTokensList.Values[AProviderName.ToLower] := '';
  FOAuthTokenExpirationsList.Values[AProviderName.ToLower] := '';
  Save;
end;

function TRadIAConfig.GetOAuthRefreshToken(const AProviderName: string): string;
begin
  if AProviderName.IsEmpty then
    Exit('');
  Result := FOAuthRefreshTokensList.Values[AProviderName.ToLower];
end;

procedure TRadIAConfig.SetOAuthRefreshToken(const AProviderName: string; const AValue: string);
begin
  if AProviderName.IsEmpty then
    Exit;
  FOAuthRefreshTokensList.Values[AProviderName.ToLower] := AValue;
end;

function TRadIAConfig.GetOAuthTokenExpiry(const AProviderName: string): TDateTime;
var
  LStr: string;
begin
  if AProviderName.IsEmpty then
    Exit(0);
  LStr := FOAuthTokenExpirationsList.Values[AProviderName.ToLower];
  if LStr.IsEmpty then
    Result := 0
  else
    Result := StrToFloatDef(LStr, 0, TFormatSettings.Invariant);
end;

procedure TRadIAConfig.SetOAuthTokenExpiry(const AProviderName: string; const AValue: TDateTime);
begin
  if AProviderName.IsEmpty then
    Exit;
  FOAuthTokenExpirationsList.Values[AProviderName.ToLower] := FloatToStr(AValue, TFormatSettings.Invariant);
end;

function TRadIAConfig.UnprotectString(const AValue: string): string;
begin
  Result := TCredentialProtector.Unprotect(AValue);
end;

class function TRadIAConfig.GetInstance: IRadIAConfig;
begin
  if not Assigned(FInstance) then
    FInstance := TRadIAConfig.Create;
  Result := FInstance;
end;

class procedure TRadIAConfig.SetStorage(const AStorage: IRadIASettingsStorage);
begin
  FStorage := AStorage;
  if not Assigned(FStorage) then
    FStorage := TRadIARegistrySettingsStorage.Create;
  if Assigned(FInstance) then
    FInstance.Load;
end;

function TRadIAConfig._AddRef: Integer;
begin
  Result := -1;
end;

function TRadIAConfig._Release: Integer;
begin
  Result := -1;
end;

initialization

finalization
  FreeAndNil(TRadIAConfig.FInstance);

end.
