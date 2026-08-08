unit RadIA.Core.ResultCompactionSettings;

interface

uses
  RadIA.Core.SettingsStorage;

type
  TRadIAResultCompactionSettings = record
  private
    FMaximumDecisionContextCharacters: Integer;
    FProfileName: string;
  public
    constructor Create(
      const AProfileName: string;
      const AMaximumDecisionContextCharacters: Integer
    );
    property MaximumDecisionContextCharacters: Integer
      read FMaximumDecisionContextCharacters;
    property ProfileName: string read FProfileName;
  end;

  TRadIAResultCompactionSettingsStore = class
  private
    FBasePath: string;
    FStorage: IRadIASettingsStorage;
    class function NormalizeProfileName(const AValue: string): string; static;
  public
    constructor Create(
      const AStorage: IRadIASettingsStorage = nil;
      const ABasePath: string = ''
    );
    function Load: TRadIAResultCompactionSettings;
    procedure Save(const ASettings: TRadIAResultCompactionSettings);
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.Config;

const
  CDefaultDecisionContextCharacters = 120000;
  CMinimumDecisionContextCharacters = 16000;
  CMaximumDecisionContextCharacters = 1000000;

constructor TRadIAResultCompactionSettings.Create(
  const AProfileName: string;
  const AMaximumDecisionContextCharacters: Integer
);
begin
  FProfileName := AProfileName;
  FMaximumDecisionContextCharacters := AMaximumDecisionContextCharacters;
end;

constructor TRadIAResultCompactionSettingsStore.Create(
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
    FBasePath := TRadIAConfig.GetRegistryPath + '\ResultCompaction';
end;

function TRadIAResultCompactionSettingsStore.Load:
  TRadIAResultCompactionSettings;
var
  LMaximumCharacters: Integer;
  LProfileName: string;
begin
  if not FStorage.OpenKey(FBasePath, False) then
    Exit(
      TRadIAResultCompactionSettings.Create(
        'Conservative',
        CDefaultDecisionContextCharacters
      )
    );
  try
    LProfileName := NormalizeProfileName(
      FStorage.ReadString('Profile', 'Conservative')
    );
    LMaximumCharacters := FStorage.ReadInteger(
      'MaximumDecisionContextCharacters',
      CDefaultDecisionContextCharacters
    );
  finally
    FStorage.CloseKey;
  end;
  if (LMaximumCharacters < CMinimumDecisionContextCharacters) or
    (LMaximumCharacters > CMaximumDecisionContextCharacters) then
    LMaximumCharacters := CDefaultDecisionContextCharacters;
  Result := TRadIAResultCompactionSettings.Create(
    LProfileName,
    LMaximumCharacters
  );
end;

class function TRadIAResultCompactionSettingsStore.NormalizeProfileName(
  const AValue: string
): string;
begin
  if SameText(Trim(AValue), 'Off') then
    Exit('Off');
  if SameText(Trim(AValue), 'Balanced') then
    Exit('Balanced');
  Result := 'Conservative';
end;

procedure TRadIAResultCompactionSettingsStore.Save(
  const ASettings: TRadIAResultCompactionSettings
);
var
  LProfileName: string;
begin
  if (ASettings.MaximumDecisionContextCharacters <
    CMinimumDecisionContextCharacters) or
    (ASettings.MaximumDecisionContextCharacters >
    CMaximumDecisionContextCharacters) then
    raise EArgumentOutOfRangeException.Create(
      'AMaximumDecisionContextCharacters'
    );
  LProfileName := NormalizeProfileName(ASettings.ProfileName);
  if not FStorage.OpenKey(FBasePath, True) then
    raise EInvalidOpException.Create(
      'Unable to open result compaction settings.'
    );
  try
    FStorage.WriteString('Profile', LProfileName);
    FStorage.WriteInteger(
      'MaximumDecisionContextCharacters',
      ASettings.MaximumDecisionContextCharacters
    );
  finally
    FStorage.CloseKey;
  end;
end;

end.
