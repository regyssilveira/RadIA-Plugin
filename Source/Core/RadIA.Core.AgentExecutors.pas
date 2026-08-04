unit RadIA.Core.AgentExecutors;

interface

uses
  RadIA.Core.CliManager,
  RadIA.Core.SettingsStorage;

type
  TRadIAAgentExecutorKind = (
    aekNative,
    aekCli
  );

  TRadIAAgentExecutorSettings = record
  private
    FKind: TRadIAAgentExecutorKind;
    FCliClientId: string;
  public
    constructor Create(
      const AKind: TRadIAAgentExecutorKind;
      const ACliClientId: string
    );
    property Kind: TRadIAAgentExecutorKind read FKind;
    property CliClientId: string read FCliClientId;
  end;

  TRadIAAgentExecutorSettingsStore = class
  private
    FStorage: IRadIASettingsStorage;
    FSettingsPath: string;
    procedure Validate(const ASettings: TRadIAAgentExecutorSettings);
  public
    constructor Create(
      const AStorage: IRadIASettingsStorage = nil;
      const ASettingsPath: string = ''
    );
    function Load: TRadIAAgentExecutorSettings;
    procedure Save(const ASettings: TRadIAAgentExecutorSettings);
  end;

  TRadIACliInvocation = record
  private
    FExecutablePath: string;
    FArguments: TArray<string>;
    FWorkingDirectory: string;
    FOutputFormat: string;
  public
    constructor Create(
      const AExecutablePath: string;
      const AArguments: TArray<string>;
      const AWorkingDirectory: string;
      const AOutputFormat: string
    );
    function ToCommandLine: string;
    property ExecutablePath: string read FExecutablePath;
    property Arguments: TArray<string> read FArguments;
    property WorkingDirectory: string read FWorkingDirectory;
    property OutputFormat: string read FOutputFormat;
  end;

  TRadIACliInvocationBuilder = class
  private
    class function BuildArguments(
      const AKind: TRadIACliKind;
      const APrompt: string
    ): TArray<string>; static;
    class function QuoteWindowsArgument(const AValue: string): string; static;
    class procedure ValidateInput(
      const AExecutablePath: string;
      const APrompt: string;
      const AWorkingDirectory: string
    ); static;
  public
    class function Build(
      const ADefinition: TRadIACliDefinition;
      const AExecutablePath: string;
      const APrompt: string;
      const AWorkingDirectory: string
    ): TRadIACliInvocation; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.SysUtils,
  RadIA.Core.Config;

const
  CDefaultCliClientId = 'codex';
  CMaxPromptLength = 1024 * 1024;

{ TRadIAAgentExecutorSettings }

constructor TRadIAAgentExecutorSettings.Create(
  const AKind: TRadIAAgentExecutorKind;
  const ACliClientId: string
);
begin
  FKind := AKind;
  FCliClientId := LowerCase(Trim(ACliClientId));
end;

{ TRadIAAgentExecutorSettingsStore }

constructor TRadIAAgentExecutorSettingsStore.Create(
  const AStorage: IRadIASettingsStorage;
  const ASettingsPath: string
);
begin
  inherited Create;
  if Assigned(AStorage) then
    FStorage := AStorage
  else
    FStorage := TRadIARegistrySettingsStorage.Create;
  FSettingsPath := Trim(ASettingsPath);
  if FSettingsPath = '' then
    FSettingsPath := TRadIAConfig.GetRegistryPath + '\AgentExecutor';
end;

function TRadIAAgentExecutorSettingsStore.Load: TRadIAAgentExecutorSettings;
var
  LClientId: string;
  LKindValue: Integer;
begin
  if not FStorage.OpenKey(FSettingsPath, False) then
    Exit(TRadIAAgentExecutorSettings.Create(aekNative, CDefaultCliClientId));
  try
    LKindValue := FStorage.ReadInteger('Kind', Ord(aekNative));
    if (LKindValue < Ord(Low(TRadIAAgentExecutorKind))) or
      (LKindValue > Ord(High(TRadIAAgentExecutorKind))) then
      LKindValue := Ord(aekNative);
    LClientId := FStorage.ReadString('CliClientId', CDefaultCliClientId);
    Result := TRadIAAgentExecutorSettings.Create(
      TRadIAAgentExecutorKind(LKindValue),
      LClientId
    );
    try
      Validate(Result);
    except
      Result := TRadIAAgentExecutorSettings.Create(
        aekNative,
        CDefaultCliClientId
      );
    end;
  finally
    FStorage.CloseKey;
  end;
end;

procedure TRadIAAgentExecutorSettingsStore.Save(
  const ASettings: TRadIAAgentExecutorSettings
);
begin
  Validate(ASettings);
  if not FStorage.OpenKey(FSettingsPath, True) then
    raise EInOutError.Create('Unable to open the agent executor settings.');
  try
    FStorage.WriteInteger('Kind', Ord(ASettings.Kind));
    FStorage.WriteString('CliClientId', ASettings.CliClientId);
  finally
    FStorage.CloseKey;
  end;
end;

procedure TRadIAAgentExecutorSettingsStore.Validate(
  const ASettings: TRadIAAgentExecutorSettings
);
var
  LDefinition: TRadIACliDefinition;
begin
  if ASettings.Kind = aekNative then
    Exit;
  if not TRadIACliCatalog.FindById(ASettings.CliClientId, LDefinition) then
    raise EArgumentException.Create('The selected CLI executor is not supported.');
end;

{ TRadIACliInvocation }

constructor TRadIACliInvocation.Create(
  const AExecutablePath: string;
  const AArguments: TArray<string>;
  const AWorkingDirectory: string;
  const AOutputFormat: string
);
begin
  FExecutablePath := AExecutablePath;
  FArguments := AArguments;
  FWorkingDirectory := AWorkingDirectory;
  FOutputFormat := AOutputFormat;
end;

function TRadIACliInvocation.ToCommandLine: string;
var
  LArgument: string;
  LParts: TList<string>;
begin
  if WorkingDirectory = '' then
    raise EInvalidOpException.Create('The CLI working directory is unavailable.');
  if OutputFormat = '' then
    raise EInvalidOpException.Create('The CLI output format is unavailable.');
  LParts := TList<string>.Create;
  try
    LParts.Add(TRadIACliInvocationBuilder.QuoteWindowsArgument(ExecutablePath));
    for LArgument in Arguments do
      LParts.Add(TRadIACliInvocationBuilder.QuoteWindowsArgument(LArgument));
    Result := string.Join(' ', LParts.ToArray);
  finally
    LParts.Free;
  end;
end;

{ TRadIACliInvocationBuilder }

class function TRadIACliInvocationBuilder.Build(
  const ADefinition: TRadIACliDefinition;
  const AExecutablePath: string;
  const APrompt: string;
  const AWorkingDirectory: string
): TRadIACliInvocation;
begin
  ValidateInput(AExecutablePath, APrompt, AWorkingDirectory);
  Result := TRadIACliInvocation.Create(
    Trim(AExecutablePath),
    BuildArguments(ADefinition.Kind, APrompt),
    Trim(AWorkingDirectory),
    'stream-json'
  );
end;

class function TRadIACliInvocationBuilder.BuildArguments(
  const AKind: TRadIACliKind;
  const APrompt: string
): TArray<string>;
begin
  case AKind of
    ckCodex:
      Result := ['exec', '--json', APrompt];
    ckClaude:
      Result := ['-p', APrompt, '--output-format', 'stream-json'];
    ckGemini:
      Result := ['-p', APrompt, '--output-format', 'stream-json'];
    ckCopilot:
      Result := ['-p', APrompt, '--output-format=json', '--no-color'];
  else
    raise EArgumentException.Create('The CLI executor kind is not supported.');
  end;
end;

class function TRadIACliInvocationBuilder.QuoteWindowsArgument(
  const AValue: string
): string;
var
  LBackslashCount: Integer;
  LCharacter: Char;
begin
  if AValue = '' then
    Exit('""');
  if not AValue.Contains(' ') and
    not AValue.Contains(#9) and
    not AValue.Contains('"') then
    Exit(AValue);

  Result := '"';
  LBackslashCount := 0;
  for LCharacter in AValue do
  begin
    if LCharacter = '\' then
    begin
      Inc(LBackslashCount);
      Continue;
    end;
    if LCharacter = '"' then
    begin
      Result := Result + StringOfChar('\', (LBackslashCount * 2) + 1) + '"';
      LBackslashCount := 0;
      Continue;
    end;
    Result := Result + StringOfChar('\', LBackslashCount) + LCharacter;
    LBackslashCount := 0;
  end;
  Result := Result + StringOfChar('\', LBackslashCount * 2) + '"';
end;

class procedure TRadIACliInvocationBuilder.ValidateInput(
  const AExecutablePath: string;
  const APrompt: string;
  const AWorkingDirectory: string
);
begin
  if Trim(AExecutablePath) = '' then
    raise EArgumentException.Create('The CLI executable path is required.');
  if Trim(APrompt) = '' then
    raise EArgumentException.Create('The CLI prompt is required.');
  if Length(APrompt) > CMaxPromptLength then
    raise EArgumentOutOfRangeException.Create('The CLI prompt exceeds the supported limit.');
  if Trim(AWorkingDirectory) = '' then
    raise EArgumentException.Create('The CLI working directory is required.');
end;

end.
