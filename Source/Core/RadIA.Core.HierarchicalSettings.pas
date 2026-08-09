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

end.
