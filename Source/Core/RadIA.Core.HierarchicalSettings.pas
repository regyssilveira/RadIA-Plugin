unit RadIA.Core.HierarchicalSettings;

interface

type
  TRadIASettingOrigin = (
    rsoDefault,
    rsoGlobal,
    rsoProject,
    rsoSession,
    rsoRequest
  );

  TRadIAExecutionSettingField = (
    resfProvider,
    resfModel,
    resfExecutor,
    resfMaxTokens,
    resfTimeoutMs,
    resfTokenBudget
  );

  TRadIAExecutionSettings = record
  private
    FExecutorId: string;
    FMaxTokens: Integer;
    FModelId: string;
    FProviderId: string;
    FTimeoutMs: Integer;
    FTokenBudget: Int64;
  public
    constructor Create(
      const AProviderId: string;
      const AModelId: string;
      const AExecutorId: string;
      const AMaxTokens: Integer;
      const ATimeoutMs: Integer;
      const ATokenBudget: Int64
    );
    class function Empty: TRadIAExecutionSettings; static;
    function HasExecutor: Boolean;
    function HasMaxTokens: Boolean;
    function HasModel: Boolean;
    function HasProvider: Boolean;
    function HasTimeout: Boolean;
    function HasTokenBudget: Boolean;
    property ExecutorId: string read FExecutorId;
    property MaxTokens: Integer read FMaxTokens;
    property ModelId: string read FModelId;
    property ProviderId: string read FProviderId;
    property TimeoutMs: Integer read FTimeoutMs;
    property TokenBudget: Int64 read FTokenBudget;
  end;

  IRadIAExecutionSettingsAwareProvider = interface
    ['{04C224E1-61A4-4841-A56D-3D4899B28D5A}']
    procedure ApplyExecutionSettings(
      const ASettings: TRadIAExecutionSettings
    );
  end;

  TRadIAResolvedExecutionSettings = record
  private
    FExecutorOrigin: TRadIASettingOrigin;
    FMaxTokensOrigin: TRadIASettingOrigin;
    FModelOrigin: TRadIASettingOrigin;
    FProviderOrigin: TRadIASettingOrigin;
    FTimeoutOrigin: TRadIASettingOrigin;
    FTokenBudgetOrigin: TRadIASettingOrigin;
    FValues: TRadIAExecutionSettings;
  public
    procedure Apply(
      const AValues: TRadIAExecutionSettings;
      const AOrigin: TRadIASettingOrigin
    );
    property ExecutorOrigin: TRadIASettingOrigin read FExecutorOrigin;
    property MaxTokensOrigin: TRadIASettingOrigin read FMaxTokensOrigin;
    property ModelOrigin: TRadIASettingOrigin read FModelOrigin;
    property ProviderOrigin: TRadIASettingOrigin read FProviderOrigin;
    property TimeoutOrigin: TRadIASettingOrigin read FTimeoutOrigin;
    property TokenBudgetOrigin: TRadIASettingOrigin read FTokenBudgetOrigin;
    property Values: TRadIAExecutionSettings read FValues;
  end;

  TRadIAExecutionSettingsResolver = class
  public
    class function Resolve(
      const ADefaults: TRadIAExecutionSettings;
      const AGlobal: TRadIAExecutionSettings;
      const AProject: TRadIAExecutionSettings;
      const ASession: TRadIAExecutionSettings;
      const ARequest: TRadIAExecutionSettings
    ): TRadIAResolvedExecutionSettings; static;
    class function OriginName(const AOrigin: TRadIASettingOrigin): string; static;
  end;

  TRadIAExecutionSettingsEditor = class
  public
    class function TryParseField(
      const AName: string;
      out AField: TRadIAExecutionSettingField
    ): Boolean; static;
    class function FieldName(
      const AField: TRadIAExecutionSettingField
    ): string; static;
    class function TryUpdate(
      const ACurrent: TRadIAExecutionSettings;
      const AField: TRadIAExecutionSettingField;
      const AValue: string;
      out AUpdated: TRadIAExecutionSettings;
      out AError: string
    ): Boolean; static;
    class function Clear(
      const ACurrent: TRadIAExecutionSettings;
      const AField: TRadIAExecutionSettingField
    ): TRadIAExecutionSettings; static;
  end;

implementation

uses
  System.SysUtils;

{ TRadIAExecutionSettings }

constructor TRadIAExecutionSettings.Create(
  const AProviderId: string;
  const AModelId: string;
  const AExecutorId: string;
  const AMaxTokens: Integer;
  const ATimeoutMs: Integer;
  const ATokenBudget: Int64
);
begin
  FProviderId := Trim(AProviderId);
  FModelId := Trim(AModelId);
  FExecutorId := LowerCase(Trim(AExecutorId));
  FMaxTokens := AMaxTokens;
  FTimeoutMs := ATimeoutMs;
  FTokenBudget := ATokenBudget;
end;

class function TRadIAExecutionSettings.Empty: TRadIAExecutionSettings;
begin
  Result := TRadIAExecutionSettings.Create('', '', '', -1, -1, -1);
end;

function TRadIAExecutionSettings.HasExecutor: Boolean;
begin
  Result := FExecutorId <> '';
end;

function TRadIAExecutionSettings.HasMaxTokens: Boolean;
begin
  Result := FMaxTokens >= 0;
end;

function TRadIAExecutionSettings.HasModel: Boolean;
begin
  Result := FModelId <> '';
end;

function TRadIAExecutionSettings.HasProvider: Boolean;
begin
  Result := FProviderId <> '';
end;

function TRadIAExecutionSettings.HasTimeout: Boolean;
begin
  Result := FTimeoutMs >= 0;
end;

function TRadIAExecutionSettings.HasTokenBudget: Boolean;
begin
  Result := FTokenBudget >= 0;
end;

{ TRadIAResolvedExecutionSettings }

procedure TRadIAResolvedExecutionSettings.Apply(
  const AValues: TRadIAExecutionSettings;
  const AOrigin: TRadIASettingOrigin
);
var
  LExecutorId: string;
  LMaxTokens: Integer;
  LModelId: string;
  LProviderId: string;
  LTimeoutMs: Integer;
  LTokenBudget: Int64;
begin
  LProviderId := FValues.ProviderId;
  LModelId := FValues.ModelId;
  LExecutorId := FValues.ExecutorId;
  LMaxTokens := FValues.MaxTokens;
  LTimeoutMs := FValues.TimeoutMs;
  LTokenBudget := FValues.TokenBudget;
  if AValues.HasProvider then
  begin
    LProviderId := AValues.ProviderId;
    FProviderOrigin := AOrigin;
  end;
  if AValues.HasModel then
  begin
    LModelId := AValues.ModelId;
    FModelOrigin := AOrigin;
  end;
  if AValues.HasExecutor then
  begin
    LExecutorId := AValues.ExecutorId;
    FExecutorOrigin := AOrigin;
  end;
  if AValues.HasMaxTokens then
  begin
    LMaxTokens := AValues.MaxTokens;
    FMaxTokensOrigin := AOrigin;
  end;
  if AValues.HasTimeout then
  begin
    LTimeoutMs := AValues.TimeoutMs;
    FTimeoutOrigin := AOrigin;
  end;
  if AValues.HasTokenBudget then
  begin
    LTokenBudget := AValues.TokenBudget;
    FTokenBudgetOrigin := AOrigin;
  end;
  FValues := TRadIAExecutionSettings.Create(
    LProviderId,
    LModelId,
    LExecutorId,
    LMaxTokens,
    LTimeoutMs,
    LTokenBudget
  );
end;

{ TRadIAExecutionSettingsResolver }

class function TRadIAExecutionSettingsResolver.Resolve(
  const ADefaults: TRadIAExecutionSettings;
  const AGlobal: TRadIAExecutionSettings;
  const AProject: TRadIAExecutionSettings;
  const ASession: TRadIAExecutionSettings;
  const ARequest: TRadIAExecutionSettings
): TRadIAResolvedExecutionSettings;
begin
  Result := Default(TRadIAResolvedExecutionSettings);
  Result.Apply(ADefaults, rsoDefault);
  Result.Apply(AGlobal, rsoGlobal);
  Result.Apply(AProject, rsoProject);
  Result.Apply(ASession, rsoSession);
  Result.Apply(ARequest, rsoRequest);
end;

class function TRadIAExecutionSettingsResolver.OriginName(
  const AOrigin: TRadIASettingOrigin
): string;
begin
  case AOrigin of
    rsoGlobal:
      Result := 'global';
    rsoProject:
      Result := 'project';
    rsoSession:
      Result := 'session';
    rsoRequest:
      Result := 'request';
  else
    Result := 'default';
  end;
end;

{ TRadIAExecutionSettingsEditor }

class function TRadIAExecutionSettingsEditor.TryParseField(
  const AName: string;
  out AField: TRadIAExecutionSettingField
): Boolean;
var
  LName: string;
begin
  LName := LowerCase(Trim(AName));
  Result := True;
  if LName = 'provider' then
    AField := resfProvider
  else if LName = 'model' then
    AField := resfModel
  else if LName = 'executor' then
    AField := resfExecutor
  else if (LName = 'max-tokens') or (LName = 'maxtokens') then
    AField := resfMaxTokens
  else if (LName = 'timeout-ms') or (LName = 'timeoutms') or
    (LName = 'timeout') then
    AField := resfTimeoutMs
  else if (LName = 'token-budget') or (LName = 'tokenbudget') then
    AField := resfTokenBudget
  else
    Result := False;
end;

class function TRadIAExecutionSettingsEditor.FieldName(
  const AField: TRadIAExecutionSettingField
): string;
begin
  case AField of
    resfProvider:
      Result := 'provider';
    resfModel:
      Result := 'model';
    resfExecutor:
      Result := 'executor';
    resfMaxTokens:
      Result := 'max-tokens';
    resfTimeoutMs:
      Result := 'timeout-ms';
  else
    Result := 'token-budget';
  end;
end;

class function TRadIAExecutionSettingsEditor.TryUpdate(
  const ACurrent: TRadIAExecutionSettings;
  const AField: TRadIAExecutionSettingField;
  const AValue: string;
  out AUpdated: TRadIAExecutionSettings;
  out AError: string
): Boolean;
var
  LExecutor: string;
  LMaxTokens: Integer;
  LModel: string;
  LProvider: string;
  LTimeoutMs: Integer;
  LTokenBudget: Int64;
begin
  AError := '';
  LProvider := ACurrent.ProviderId;
  LModel := ACurrent.ModelId;
  LExecutor := ACurrent.ExecutorId;
  LMaxTokens := ACurrent.MaxTokens;
  LTimeoutMs := ACurrent.TimeoutMs;
  LTokenBudget := ACurrent.TokenBudget;
  case AField of
    resfProvider:
      LProvider := Trim(AValue);
    resfModel:
      LModel := Trim(AValue);
    resfExecutor:
      LExecutor := LowerCase(Trim(AValue));
    resfMaxTokens:
      if not TryStrToInt(AValue, LMaxTokens) or (LMaxTokens < 0) then
        AError := 'max-tokens must be a non-negative integer.';
    resfTimeoutMs:
      if not TryStrToInt(AValue, LTimeoutMs) or (LTimeoutMs < 1) then
        AError := 'timeout-ms must be a positive integer.';
    resfTokenBudget:
      if not TryStrToInt64(AValue, LTokenBudget) or (LTokenBudget < 0) then
        AError := 'token-budget must be a non-negative integer.';
  end;
  if (AError = '') and
    (AField in [resfProvider, resfModel, resfExecutor]) and
    (Trim(AValue) = '') then
    AError := FieldName(AField) + ' cannot be empty; use inherit instead.';
  Result := AError = '';
  if Result then
    AUpdated := TRadIAExecutionSettings.Create(
      LProvider,
      LModel,
      LExecutor,
      LMaxTokens,
      LTimeoutMs,
      LTokenBudget
    )
  else
    AUpdated := ACurrent;
end;

class function TRadIAExecutionSettingsEditor.Clear(
  const ACurrent: TRadIAExecutionSettings;
  const AField: TRadIAExecutionSettingField
): TRadIAExecutionSettings;
var
  LExecutor: string;
  LMaxTokens: Integer;
  LModel: string;
  LProvider: string;
  LTimeoutMs: Integer;
  LTokenBudget: Int64;
begin
  LProvider := ACurrent.ProviderId;
  LModel := ACurrent.ModelId;
  LExecutor := ACurrent.ExecutorId;
  LMaxTokens := ACurrent.MaxTokens;
  LTimeoutMs := ACurrent.TimeoutMs;
  LTokenBudget := ACurrent.TokenBudget;
  case AField of
    resfProvider:
      LProvider := '';
    resfModel:
      LModel := '';
    resfExecutor:
      LExecutor := '';
    resfMaxTokens:
      LMaxTokens := -1;
    resfTimeoutMs:
      LTimeoutMs := -1;
    resfTokenBudget:
      LTokenBudget := -1;
  end;
  Result := TRadIAExecutionSettings.Create(
    LProvider,
    LModel,
    LExecutor,
    LMaxTokens,
    LTimeoutMs,
    LTokenBudget
  );
end;

end.
