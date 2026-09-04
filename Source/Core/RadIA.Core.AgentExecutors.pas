unit RadIA.Core.AgentExecutors;

interface

uses
  System.JSON,
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
    FReasoningEffort: string;
  public
    constructor Create(
      const AKind: TRadIAAgentExecutorKind;
      const ACliClientId: string;
      const AReasoningEffort: string = 'medium'
    );
    property Kind: TRadIAAgentExecutorKind read FKind;
    property CliClientId: string read FCliClientId;
    property ReasoningEffort: string read FReasoningEffort;
  end;

  TRadIAModelSelectionState = record
  private
    FEnabled: Boolean;
    FDisplayText: string;
  public
    class function FromExecutor(
      const ASettings: TRadIAAgentExecutorSettings
    ): TRadIAModelSelectionState; static;
    property Enabled: Boolean read FEnabled;
    property DisplayText: string read FDisplayText;
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
      const APrompt: string;
      const AWorkingDirectory: string;
      const AResumeSessionId: string;
      const AReasoningEffort: string
    ): TArray<string>; static;
    class procedure ValidateSessionId(
      const ASessionId: string
    ); static;
    class procedure ValidateInput(
      const AExecutablePath: string;
      const APrompt: string;
      const AWorkingDirectory: string
    ); static;
  public
    class function QuoteWindowsArgument(
      const AValue: string
    ): string; static;
    class function Build(
      const ADefinition: TRadIACliDefinition;
      const AExecutablePath: string;
      const APrompt: string;
      const AWorkingDirectory: string;
      const AResumeSessionId: string = '';
      const AReasoningEffort: string = 'medium'
    ): TRadIACliInvocation; static;
  end;

  TRadIACliOutputParser = class
  private
    class function FindArrayText(
      const AArray: TJSONArray;
      out AText: string
    ): Boolean; static;
    class function FindObjectText(
      const AObject: TJSONObject;
      out AText: string
    ): Boolean; static;
    class function FindText(
      const AValue: TObject;
      out AText: string
    ): Boolean; static;
  public
    class function ExtractFinalText(const AOutput: string): string; static;
    class function TryExtractSessionId(
      const AKind: TRadIACliKind;
      const AOutput: string;
      out ASessionId: string
    ): Boolean; static;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.AgentExecutorContracts,
  RadIA.Core.Config;

const
  CDefaultCliClientId = 'codex';
  CMaxPromptLength = 1024 * 1024;

{ TRadIAAgentExecutorSettings }

constructor TRadIAAgentExecutorSettings.Create(
  const AKind: TRadIAAgentExecutorKind;
  const ACliClientId: string;
  const AReasoningEffort: string
);
begin
  FKind := AKind;
  FCliClientId := LowerCase(Trim(ACliClientId));
  FReasoningEffort := LowerCase(Trim(AReasoningEffort));
  if FReasoningEffort = '' then
    FReasoningEffort := 'medium';
end;

{ TRadIAModelSelectionState }

class function TRadIAModelSelectionState.FromExecutor(
  const ASettings: TRadIAAgentExecutorSettings
): TRadIAModelSelectionState;
var
  LDefinition: TRadIACliDefinition;
begin
  Result.FEnabled := ASettings.Kind = aekNative;
  Result.FDisplayText := '';
  if Result.FEnabled then
    Exit;
  if TRadIACliCatalog.FindById(ASettings.CliClientId, LDefinition) then
    Result.FDisplayText := 'Model managed by ' + LDefinition.DisplayName
  else
    Result.FDisplayText := 'Model managed by external CLI';
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
      LClientId,
      FStorage.ReadString('ReasoningEffort', 'medium')
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
    FStorage.WriteString('ReasoningEffort', ASettings.ReasoningEffort);
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
  if not MatchText(
    ASettings.ReasoningEffort,
    ['low', 'medium', 'high', 'xhigh']
  ) then
    raise EArgumentException.Create('The reasoning effort is not supported.');
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
  const AWorkingDirectory: string;
  const AResumeSessionId: string;
  const AReasoningEffort: string
): TRadIACliInvocation;
var
  LContract: TRadIAExecutorContract;
begin
  ValidateInput(AExecutablePath, APrompt, AWorkingDirectory);
  ValidateSessionId(AResumeSessionId);
  if (AResumeSessionId <> '') and
    (not TRadIAExecutorContractCatalog.FindByClientId(
      ADefinition.Id,
      LContract
    ) or not LContract.Supports(ecStableResume)) then
    raise EArgumentException.Create(
      'The CLI executor does not support conversation resume.'
    );
  Result := TRadIACliInvocation.Create(
    Trim(AExecutablePath),
    BuildArguments(
      ADefinition.Kind,
      APrompt,
      AWorkingDirectory,
      AResumeSessionId,
      AReasoningEffort
    ),
    Trim(AWorkingDirectory),
    'stream-json'
  );
end;

class function TRadIACliInvocationBuilder.BuildArguments(
  const AKind: TRadIACliKind;
  const APrompt: string;
  const AWorkingDirectory: string;
  const AResumeSessionId: string;
  const AReasoningEffort: string
): TArray<string>;
begin
  if AResumeSessionId <> '' then
  begin
    case AKind of
      ckCodex:
        Result := [
          'exec',
          'resume',
          '--json',
          '--skip-git-repo-check',
          '--ignore-user-config',
          '--sandbox',
          'workspace-write',
          '-c',
          'model_reasoning_effort=' + AReasoningEffort,
          AResumeSessionId,
          APrompt
        ];
      ckClaude,
      ckGemini:
        Result := [
          '-p',
          APrompt,
          '--output-format',
          'stream-json',
          '--resume',
          AResumeSessionId
        ];
      ckCopilot:
        Result := [
          '-p',
          APrompt,
          '--output-format=json',
          '--no-color',
          '--resume=' + AResumeSessionId
        ];
    else
      raise EArgumentException.Create('The CLI executor kind is not supported.');
    end;
    Exit;
  end;
  case AKind of
    ckCodex:
      Result := [
        'exec',
        '--json',
        '--skip-git-repo-check',
        '--ignore-user-config',
        '--sandbox',
        'workspace-write',
        '-c',
        'model_reasoning_effort=' + AReasoningEffort,
        '--cd',
        AWorkingDirectory,
        APrompt
      ];
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

class procedure TRadIACliInvocationBuilder.ValidateSessionId(
  const ASessionId: string
);
var
  LCharacter: Char;
begin
  if ASessionId = '' then
    Exit;
  if (Length(ASessionId) > 256) or (Trim(ASessionId) <> ASessionId) then
    raise EArgumentException.Create('The CLI session id is invalid.');
  for LCharacter in ASessionId do
    if not CharInSet(
      LCharacter,
      ['a'..'z', 'A'..'Z', '0'..'9', '-', '_', '.', ':']
    ) then
      raise EArgumentException.Create('The CLI session id is invalid.');
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

{ TRadIACliOutputParser }

class function TRadIACliOutputParser.ExtractFinalText(
  const AOutput: string
): string;
var
  LCandidate: string;
  LJson: TJSONValue;
  LLine: string;
  LLines: TStringList;
begin
  Result := '';
  LLines := TStringList.Create;
  try
    LLines.Text := AOutput;
    for LLine in LLines do
    begin
      LJson := TJSONObject.ParseJSONValue(Trim(LLine));
      try
        if Assigned(LJson) and FindText(LJson, LCandidate) and
          (Trim(LCandidate) <> '') then
          Result := LCandidate;
      finally
        LJson.Free;
      end;
    end;
  finally
    LLines.Free;
  end;
  if Result = '' then
    Result := Trim(AOutput);
end;

class function TRadIACliOutputParser.TryExtractSessionId(
  const AKind: TRadIACliKind;
  const AOutput: string;
  out ASessionId: string
): Boolean;
const
  CSessionNames: array[0..4] of string = (
    'thread_id',
    'session_id',
    'sessionId',
    'conversation_id',
    'conversationId'
  );
var
  LJson: TJSONValue;
  LLine: string;
  LLines: TStringList;
  LName: string;
  LObject: TJSONObject;
  LResumeIndex: Integer;
  LValue: TJSONValue;
begin
  ASessionId := '';
  LLines := TStringList.Create;
  try
    LLines.Text := AOutput;
    for LLine in LLines do
    begin
      LJson := TJSONObject.ParseJSONValue(Trim(LLine));
      try
        if not (LJson is TJSONObject) then
          Continue;
        LObject := TJSONObject(LJson);
        for LName in CSessionNames do
        begin
          LValue := LObject.GetValue(LName);
          if LValue is TJSONString then
          begin
            ASessionId := TJSONString(LValue).Value;
            try
              TRadIACliInvocationBuilder.ValidateSessionId(ASessionId);
              Exit(True);
            except
              on EArgumentException do
                ASessionId := '';
            end;
          end;
        end;
      finally
        LJson.Free;
      end;
    end;
  finally
    LLines.Free;
  end;
  if AKind <> ckCopilot then
    Exit(False);
  LResumeIndex := LowerCase(AOutput).IndexOf('copilot --resume=');
  if LResumeIndex < 0 then
    Exit(False);
  ASessionId := AOutput.Substring(LResumeIndex + Length('copilot --resume='));
  ASessionId := ASessionId.Split([#13, #10, ' ', #9])[0].Trim;
  try
    TRadIACliInvocationBuilder.ValidateSessionId(ASessionId);
    Result := ASessionId <> '';
  except
    on EArgumentException do
    begin
      ASessionId := '';
      Result := False;
    end;
  end;
end;

class function TRadIACliOutputParser.FindText(
  const AValue: TObject;
  out AText: string
): Boolean;
begin
  AText := '';
  if AValue is TJSONObject then
    Exit(FindObjectText(TJSONObject(AValue), AText));
  if AValue is TJSONArray then
    Exit(FindArrayText(TJSONArray(AValue), AText));
  Result := False;
end;

class function TRadIACliOutputParser.FindArrayText(
  const AArray: TJSONArray;
  out AText: string
): Boolean;
var
  LChild: TJSONValue;
begin
  for LChild in AArray do
    if FindText(LChild, AText) then
      Exit(True);
  AText := '';
  Result := False;
end;

class function TRadIACliOutputParser.FindObjectText(
  const AObject: TJSONObject;
  out AText: string
): Boolean;
const
  CPreferredNames: array[0..4] of string = (
    'result',
    'response',
    'text',
    'message',
    'content'
  );
var
  LName: string;
  LPair: TJSONPair;
  LPreferred: TJSONValue;
begin
  AText := '';
  for LName in CPreferredNames do
  begin
    LPreferred := AObject.GetValue(LName);
    if LPreferred is TJSONString then
    begin
      AText := TJSONString(LPreferred).Value;
      Exit(True);
    end;
  end;
  for LPair in AObject do
    if FindText(LPair.JsonValue, AText) then
      Exit(True);
  Result := False;
end;

end.
