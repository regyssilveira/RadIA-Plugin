unit RadIA.Core.ConsentSettings;

interface

uses
  RadIA.Core.SettingsStorage;

type
  TRadIAConsentGrantLevel = (
    cglStrict,
    cglTool,
    cglCategory,
    cglTrusted
  );

  TRadIAConsentSettingsStore = class
  private
    FBasePath: string;
    FStorage: IRadIASettingsStorage;
  public
    constructor Create(
      const AStorage: IRadIASettingsStorage = nil;
      const ABasePath: string = ''
    );
    function LoadGrantLevel: TRadIAConsentGrantLevel;
    procedure SaveGrantLevel(const ALevel: TRadIAConsentGrantLevel);
    class function GrantLevelName(
      const ALevel: TRadIAConsentGrantLevel
    ): string; static;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.Config;

constructor TRadIAConsentSettingsStore.Create(
  const AStorage: IRadIASettingsStorage;
  const ABasePath: string
);
begin
  inherited Create;
  if Assigned(AStorage) then
    FStorage := AStorage
  else
    FStorage := TRadIARegistrySettingsStorage.Create;
  FBasePath := Trim(ABasePath);
  if FBasePath = '' then
    FBasePath := TRadIAConfig.GetRegistryPath + '\Consent';
end;

class function TRadIAConsentSettingsStore.GrantLevelName(
  const ALevel: TRadIAConsentGrantLevel
): string;
begin
  case ALevel of
    cglStrict: Result := 'Strict';
    cglTool: Result := 'Tool';
    cglTrusted: Result := 'Trusted';
  else
    Result := 'Category';
  end;
end;

function TRadIAConsentSettingsStore.LoadGrantLevel:
  TRadIAConsentGrantLevel;
var
  LValue: string;
begin
  Result := cglCategory;
  if not FStorage.OpenKey(FBasePath, False) then
    Exit;
  try
    LValue := FStorage.ReadString('GrantLevel', 'Category');
  finally
    FStorage.CloseKey;
  end;
  if SameText(LValue, 'Strict') then
    Result := cglStrict
  else if SameText(LValue, 'Tool') then
    Result := cglTool
  else if SameText(LValue, 'Trusted') then
    Result := cglTrusted;
end;

procedure TRadIAConsentSettingsStore.SaveGrantLevel(
  const ALevel: TRadIAConsentGrantLevel
);
begin
  if not FStorage.OpenKey(FBasePath, True) then
    raise EInvalidOpException.Create('Unable to open consent settings.');
  try
    FStorage.WriteString('GrantLevel', GrantLevelName(ALevel));
  finally
    FStorage.CloseKey;
  end;
end;

end.
