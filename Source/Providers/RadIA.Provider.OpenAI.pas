unit RadIA.Provider.OpenAI;

interface

uses  System.JSON, RadIA.Core.Interfaces, RadIA.Provider.Base;

type
  {$RTTI EXPLICIT METHODS([vcPrivate, vcProtected, vcPublic, vcPublished])}
  TRadIAOpenAIProvider = class(TRadIAOpenAICompatibleProvider)
  private
    FThreadId: string;
    function ExtractDeltaText(const ADeltaObj: TJSONObject): string;
    procedure WritePromptToPipe(AWriteHandle: THandle; const APrompt: string);
    procedure ReadCodexOutputPipe(AReadHandle: THandle; const AIsStream: Boolean;
      const AStreamCallback: TStreamChunkCallback; var AResponseText: string;
      var AInputTokens, AOutputTokens: Integer);
    procedure RunCodexLoop(const ACmdLine: string; const APrompt: string;
      const ACallback: TCompletionCallback; const AStreamCallback: TStreamChunkCallback;
      const AIsStream: Boolean);
    procedure ProcessCodexJsonLine(const AJsonStr: string; out ADeltaText: string;
      var AResponseText: string; var AInputTokens, AOutputTokens: Integer);
    procedure ExecuteCodexCli(const APrompt: string; const ACallback: TCompletionCallback;
      const AStreamCallback: TStreamChunkCallback; const AIsStream: Boolean);
    function GetEffectiveSystemPrompt: string;
  protected
    function GetCodexExecutablePath: string; virtual;
    function GetBaseUrl: string; override;
    function GetModelsDiscoveryUrl: string; override;
    function FilterModelId(const AId: string): Boolean; override;
    function GetOAuthTokenUrl: string; override;
    function GetOAuthClientId: string; override;
  public
    constructor Create(const AConfig: IRadIAConfig); override;

    procedure SendPromptAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TCompletionCallback; const ATemperature: Double; const AMaxTokens: Integer); override;
    procedure SendPromptStreamAsync(const APrompt: string; const AHistory: TArray<IRadIAChatMessage>;
      const ACallback: TStreamChunkCallback; const ATemperature: Double; const AMaxTokens: Integer); override;

    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
  end;

implementation

uses
  System.SysUtils, System.Classes, Winapi.Windows,
  System.Generics.Collections, RadIA.Core.ProviderRegistry, RadIA.Core.Types,
  RadIA.Core.TokenUsage, RadIA.Core.Logger, RadIA.Core.Container,
  RadIA.Core.CliManager;

{ TRadIAOpenAIProvider }

constructor TRadIAOpenAIProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'OpenAI';
end;

function TRadIAOpenAIProvider.GetBaseUrl: string;
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
    Result := 'https://api.openai.com/v1'
  else if not FConfig.GetOpenAICustomBaseUrl.IsEmpty then
    Result := FConfig.GetOpenAICustomBaseUrl
  else
    Result := 'https://api.openai.com/v1';
end;

function TRadIAOpenAIProvider.GetAvailableModels: TArray<string>;
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
    Result := TArray<string>.Create(MODEL_OPENAI_GPT54_MINI, MODEL_OPENAI_GPT54)
  else
    Result := TArray<string>.Create(MODEL_OPENAI_GPT4O_MINI, MODEL_OPENAI_GPT4O);
end;

function TRadIAOpenAIProvider.GetName: string;
begin
  Result := 'OpenAI ChatGPT';
end;

function TRadIAOpenAIProvider.GetModelsDiscoveryUrl: string;
begin
  Result := GetBaseUrl.TrimRight(['/']) + '/models';
end;

function TRadIAOpenAIProvider.FilterModelId(const AId: string): Boolean;
begin
  { Accept only GPT and O-series reasoning models }
  Result := not AId.IsEmpty and
    (AId.StartsWith('gpt-') or AId.StartsWith('o1-') or AId.StartsWith('o3-'));
end;

function TRadIAOpenAIProvider.GetOAuthTokenUrl: string;
begin
  Result := 'https://auth.openai.com/oauth/token';
end;

function TRadIAOpenAIProvider.GetOAuthClientId: string;
begin
  Result := 'app_EMoamEEZ73f0CkXaXp7hrann';
end;



procedure TRadIAOpenAIProvider.SendPromptAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TCompletionCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
  begin
    if Length(AHistory) = 0 then
      FThreadId := '';
    ExecuteCodexCli(APrompt, ACallback, nil, False);
  end
  else
  begin
    inherited SendPromptAsync(APrompt, AHistory, ACallback, ATemperature, AMaxTokens);
  end;
end;

procedure TRadIAOpenAIProvider.SendPromptStreamAsync(const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const ACallback: TStreamChunkCallback;
  const ATemperature: Double; const AMaxTokens: Integer);
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') then
  begin
    if Length(AHistory) = 0 then
      FThreadId := '';
    ExecuteCodexCli(APrompt, nil, ACallback, True);
  end
  else
  begin
    inherited SendPromptStreamAsync(APrompt, AHistory, ACallback, ATemperature, AMaxTokens);
  end;
end;

function TRadIAOpenAIProvider.GetCodexExecutablePath: string;
var
  LDetection: TRadIACliDetection;
begin
  LDetection := TRadIACliResolver.Resolve('codex');
  if LDetection.Installed then
    Result := LDetection.ExecutablePath
  else
    Result := '';
end;

function TRadIAOpenAIProvider.ExtractDeltaText(const ADeltaObj: TJSONObject): string;
var
  LContentArr: TJSONArray;
  LContentObj: TJSONObject;
  LTextObj: TJSONObject;
begin
  Result := '';
  if not Assigned(ADeltaObj) then
    Exit;

  LContentArr := ADeltaObj.GetValue('content') as TJSONArray;
  if Assigned(LContentArr) and (LContentArr.Count > 0) then
  begin
    LContentObj := LContentArr[0] as TJSONObject;
    if Assigned(LContentObj) then
    begin
      LTextObj := LContentObj.GetValue('text') as TJSONObject;
      if Assigned(LTextObj) then
      begin
        Result := LTextObj.GetValue<string>('value', '');
      end;
    end;
  end;
end;

procedure TRadIAOpenAIProvider.WritePromptToPipe(AWriteHandle: THandle; const APrompt: string);
var
  LUtf8Prompt: RawByteString;
  LBytesWritten: DWORD;
begin
  LUtf8Prompt := UTF8Encode(APrompt);
  if Length(LUtf8Prompt) > 0 then
  begin
    WriteFile(AWriteHandle, LUtf8Prompt[1], Length(LUtf8Prompt), LBytesWritten, nil);
  end;
  CloseHandle(AWriteHandle);
end;

procedure ProcessThreadStarted(LJson: TJSONObject; var AThreadId: string);
begin
  AThreadId := LJson.GetValue<string>('thread_id', '');
end;

function ProcessMessageDelta(LJson: TJSONObject; AProvider: TRadIAOpenAIProvider): string;
var
  LDeltaObj: TJSONObject;
begin
  Result := '';
  LDeltaObj := LJson.GetValue('delta') as TJSONObject;
  if Assigned(LDeltaObj) then
    Result := AProvider.ExtractDeltaText(LDeltaObj);
end;

procedure ProcessItemCompleted(LJson: TJSONObject; var AResponseText: string);
var
  LItemObj: TJSONObject;
begin
  LItemObj := LJson.GetValue('item') as TJSONObject;
  if Assigned(LItemObj) then
  begin
    AResponseText := LItemObj.GetValue<string>('text', '');
  end;
end;

procedure ProcessTurnCompleted(LJson: TJSONObject; var AInputTokens, AOutputTokens: Integer);
var
  LUsageObj: TJSONObject;
begin
  LUsageObj := LJson.GetValue('usage') as TJSONObject;
  if Assigned(LUsageObj) then
  begin
    AInputTokens := LUsageObj.GetValue<Integer>('input_tokens', 0);
    AOutputTokens := LUsageObj.GetValue<Integer>('output_tokens', 0);
  end;
end;

procedure ProcessSingleCodexLine(const AJsonStr: string; AProvider: TRadIAOpenAIProvider;
  const AIsStream: Boolean; const AStreamCallback: TStreamChunkCallback;
  var AResponseText: string; var AInputTokens, AOutputTokens: Integer);
var
  LDeltaText: string;
begin
  if AJsonStr.IsEmpty then
    Exit;

  LDeltaText := '';
  AProvider.ProcessCodexJsonLine(AJsonStr, LDeltaText, AResponseText, AInputTokens, AOutputTokens);
  if not LDeltaText.IsEmpty then
  begin
    if AIsStream and not GIsShuttingDown then
    begin
      TThread.Queue(nil,
        TThreadProcedure(
        procedure
        begin
          if Assigned(AStreamCallback) then
            AStreamCallback(LDeltaText, False, '');
        end));
    end;
    AResponseText := AResponseText + LDeltaText;
  end;
end;

function CreateCodexProcess(const ACmdLine: string; out AHReadOut, AHWriteIn: THandle;
  out APi: TProcessInformation): Boolean;
var
  LSa: TSecurityAttributes;
  LSi: TStartupInfo;
  LHWriteOut, LHReadIn: THandle;
begin
  Result := False;
  AHReadOut := 0;
  AHWriteIn := 0;
  ZeroMemory(@APi, SizeOf(TProcessInformation));

  LSa.nLength := SizeOf(TSecurityAttributes);
  LSa.bInheritHandle := True;
  LSa.lpSecurityDescriptor := nil;

  if not CreatePipe(AHReadOut, LHWriteOut, @LSa, 0) then Exit;
  if not CreatePipe(LHReadIn, AHWriteIn, @LSa, 0) then
  begin
    CloseHandle(AHReadOut);
    CloseHandle(LHWriteOut);
    Exit;
  end;

  SetHandleInformation(AHReadOut, HANDLE_FLAG_INHERIT, 0);
  SetHandleInformation(AHWriteIn, HANDLE_FLAG_INHERIT, 0);

  ZeroMemory(@LSi, SizeOf(TStartupInfo));
  LSi.cb := SizeOf(TStartupInfo);
  LSi.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
  LSi.wShowWindow := SW_HIDE;
  LSi.hStdOutput := LHWriteOut;
  LSi.hStdError := LHWriteOut;
  LSi.hStdInput := LHReadIn;

  if CreateProcess(nil, PChar(ACmdLine), nil, nil, True,
    CREATE_NO_WINDOW, nil, nil, LSi, APi) then
  begin
    CloseHandle(LHWriteOut);
    CloseHandle(LHReadIn);
    Result := True;
  end
  else
  begin
    CloseHandle(LHWriteOut);
    CloseHandle(AHReadOut);
    CloseHandle(LHReadIn);
    CloseHandle(AHWriteIn);
  end;
end;

procedure QueueCompletion(const AIsStream: Boolean; const AStreamCallback: TStreamChunkCallback;
  const ACallback: TCompletionCallback; const AResponseText: string; const AUsage: TTokenUsage);
begin
  if GIsShuttingDown then Exit;
  TThread.Queue(nil,
    TThreadProcedure(
      procedure
      begin
        if AIsStream then
        begin
          if Assigned(AStreamCallback) then
          begin
            AStreamCallback(AResponseText, False, '');
            AStreamCallback('', True, '');
          end;
        end
        else
        begin
          if Assigned(ACallback) then
            ACallback(AResponseText, '', True, AUsage);
        end;
      end
    )
  );
end;

procedure QueueError(const AIsStream: Boolean; const AStreamCallback: TStreamChunkCallback;
  const ACallback: TCompletionCallback; const AErrorMsg: string);
begin
  if GIsShuttingDown then Exit;
  TThread.Queue(nil,
    TThreadProcedure(
      procedure
      begin
        if AIsStream then
        begin
          if Assigned(AStreamCallback) then
            AStreamCallback('', True, AErrorMsg);
        end
        else
        begin
          if Assigned(ACallback) then
            ACallback('', AErrorMsg, False, TTokenUsage.Empty);
        end;
      end
    )
  );
end;

procedure TRadIAOpenAIProvider.ReadCodexOutputPipe(AReadHandle: THandle; const AIsStream: Boolean;
  const AStreamCallback: TStreamChunkCallback; var AResponseText: string;
  var AInputTokens, AOutputTokens: Integer);
var
  LBuffer: array[0..4095] of Byte;
  LBytesRead: DWORD;
  LLineBytes: TList<Byte>;
  LJsonStr: string;
  I: Integer;

  procedure ProcessBufferByte(AByte: Byte);
  var
    LJsonStrLocal: string;
  begin
    if AByte = 10 then
    begin
      if LLineBytes.Count > 0 then
      begin
        LJsonStrLocal := TEncoding.UTF8.GetString(LLineBytes.ToArray).Trim;
        LLineBytes.Clear;
      end
      else
        LJsonStrLocal := '';

      ProcessSingleCodexLine(LJsonStrLocal, Self, AIsStream, AStreamCallback,
        AResponseText, AInputTokens, AOutputTokens);
    end
    else if AByte <> 13 then
    begin
      LLineBytes.Add(AByte);
    end;
  end;

begin
  LLineBytes := TList<Byte>.Create;
  try
    while ReadFile(AReadHandle, LBuffer[0], SizeOf(LBuffer), LBytesRead, nil) and (LBytesRead > 0) do
    begin
      for I := 0 to LBytesRead - 1 do
      begin
        ProcessBufferByte(LBuffer[I]);
      end;
    end;

    if LLineBytes.Count > 0 then
    begin
      LJsonStr := TEncoding.UTF8.GetString(LLineBytes.ToArray).Trim;
      ProcessSingleCodexLine(LJsonStr, Self, AIsStream, AStreamCallback,
        AResponseText, AInputTokens, AOutputTokens);
    end;
  finally
    LLineBytes.Free;
  end;
end;

procedure TRadIAOpenAIProvider.RunCodexLoop(const ACmdLine: string; const APrompt: string;
  const ACallback: TCompletionCallback; const AStreamCallback: TStreamChunkCallback;
  const AIsStream: Boolean);
var
  LHReadOut, LHWriteIn: THandle;
  LPi: TProcessInformation;
  LResponseText: string;
  LInputTokens, LOutputTokens: Integer;
  LUsage: TTokenUsage;
  LExitCode: DWORD;
begin
  if CreateCodexProcess(ACmdLine, LHReadOut, LHWriteIn, LPi) then
  begin
    WritePromptToPipe(LHWriteIn, APrompt);

    LResponseText := '';
    LInputTokens := 0;
    LOutputTokens := 0;

    ReadCodexOutputPipe(LHReadOut, AIsStream, AStreamCallback, LResponseText, LInputTokens, LOutputTokens);
    CloseHandle(LHReadOut);

    WaitForSingleObject(LPi.hProcess, INFINITE);
    GetExitCodeProcess(LPi.hProcess, LExitCode);
    CloseHandle(LPi.hProcess);
    CloseHandle(LPi.hThread);

    if LResponseText.IsEmpty then
      LResponseText := 'Error: No response generated by Codex.';

    LUsage.PromptTokens := LInputTokens;
    LUsage.CompletionTokens := LOutputTokens;
    LUsage.TotalTokens := LInputTokens + LOutputTokens;

    QueueCompletion(AIsStream, AStreamCallback, ACallback, LResponseText, LUsage);
  end
  else
  begin
    QueueError(AIsStream, AStreamCallback, ACallback, 'Error: Failed to create the Codex process.');
  end;
end;

procedure TRadIAOpenAIProvider.ProcessCodexJsonLine(const AJsonStr: string;
  out ADeltaText: string; var AResponseText: string; var AInputTokens, AOutputTokens: Integer);
var
  LJson: TJSONObject;
  LType: string;
begin
  ADeltaText := '';
  try
    LJson := TJSONObject.ParseJSONValue(AJsonStr) as TJSONObject;
  except
    on E: Exception do
    begin
      TLogger.Log('Error parsing Codex JSON: ' + E.Message, 'OpenAI');
      Exit;
    end;
  end;

  if not Assigned(LJson) then
    Exit;

  try
    LType := LJson.GetValue<string>('type', '');
    if LType.IsEmpty then
      LType := LJson.GetValue<string>('object', '');

    if SameText(LType, 'thread.started') then
      ProcessThreadStarted(LJson, FThreadId)
    else if SameText(LType, 'thread.message.delta') or SameText(LType, 'message.delta') then
      ADeltaText := ProcessMessageDelta(LJson, Self)
    else if SameText(LType, 'item.completed') then
      ProcessItemCompleted(LJson, AResponseText)
    else if SameText(LType, 'turn.completed') then
      ProcessTurnCompleted(LJson, AInputTokens, AOutputTokens);

    if ADeltaText.IsEmpty then
      ADeltaText := LJson.GetValue<string>('text', '');
  finally
    LJson.Free;
  end;
end;

function TRadIAOpenAIProvider.GetEffectiveSystemPrompt: string;
var
  LSystemPrompt: string;
  LAdapter: IRadIAIDEAdapter;
  LDelphiVersionName: string;
  LPreferredLanguage: string;
  LDelphiVersionPrompt: string;
begin
  LSystemPrompt := FConfig.SystemPrompt;

  LDelphiVersionName := 'Delphi';
  LPreferredLanguage := '';

  if TRadIAContainer.TryResolve<IRadIAIDEAdapter>(LAdapter) then
  begin
    LDelphiVersionName := LAdapter.GetDelphiVersionName;
    LPreferredLanguage := LAdapter.GetPreferredLanguageInstruction;
  end;

  if FConfig.InjectDelphiVersion then
  begin
    LDelphiVersionPrompt := 'The user is writing code using Embarcadero ' + LDelphiVersionName + '. ' +
                            'Make sure any code, syntax, keywords, and RTL components you generate are ' +
                            'fully compatible and compile in this version. Avoid newer language features ' +
                            'that are not supported in ' + LDelphiVersionName + '. ';
    if not LPreferredLanguage.IsEmpty then
      LDelphiVersionPrompt := LDelphiVersionPrompt + LPreferredLanguage;

    if LSystemPrompt.IsEmpty then
      LSystemPrompt := LDelphiVersionPrompt
    else
      LSystemPrompt := LSystemPrompt + sLineBreak + sLineBreak + LDelphiVersionPrompt;
  end;

  Result := LSystemPrompt;
end;

procedure TRadIAOpenAIProvider.ExecuteCodexCli(const APrompt: string;
  const ACallback: TCompletionCallback; const AStreamCallback: TStreamChunkCallback;
  const AIsStream: Boolean);
var
  LActiveModel: string;
  LCodexPath: string;
  LCmdLine: string;
  LThread: TThread;
  LSystemPrompt: string;
  LPromptToSend: string;
begin
  LActiveModel := GetActiveModel;

  if not (SameText(LActiveModel, MODEL_OPENAI_GPT54) or
          SameText(LActiveModel, MODEL_OPENAI_GPT54_MINI)) then
  begin
    if AIsStream then
      AStreamCallback('', True, Format(
        'Error: The selected model ''%s'' is not supported in ChatGPT Plus (OAuth) mode. ' +
        'Please select a compatible model (gpt-5.4 or gpt-5.4-mini) in the chat panel.',
        [LActiveModel]))
    else
      ACallback('', Format(
        'Error: The selected model ''%s'' is not supported in ChatGPT Plus (OAuth) mode. ' +
        'Please select a compatible model (gpt-5.4 or gpt-5.4-mini) in the chat panel.',
        [LActiveModel]), False, TTokenUsage.Empty);
    Exit;
  end;

  LCodexPath := GetCodexExecutablePath;

  if LCodexPath.IsEmpty then
  begin
    if AIsStream then
      AStreamCallback('', True,
        'Error: ChatGPT OAuth uses Codex CLI as its transport, but the executable was not found. ' +
        'Select an existing portable codex.exe in Settings > CLI & MCP, or review the optional ' +
        '[installation instructions](https://github.com/openai/codex). Node.js and npm are not ' +
        'required when you provide an existing executable.')
    else
      ACallback('',
        'Error: ChatGPT OAuth uses Codex CLI as its transport, but the executable was not found. ' +
        'Select an existing portable codex.exe in Settings > CLI & MCP, or review the optional ' +
        '[installation instructions](https://github.com/openai/codex). Node.js and npm are not ' +
        'required when you provide an existing executable.',
        False, TTokenUsage.Empty);
    Exit;
  end;

  if FThreadId.IsEmpty then
  begin
    LCmdLine := Format(
      '"%s" -m %s exec --json --sandbox read-only --ephemeral --skip-git-repo-check -',
      [LCodexPath, LActiveModel]);
  end
  else
  begin
    LCmdLine := Format(
      '"%s" -m %s exec resume --json "%s" -',
      [LCodexPath, LActiveModel, FThreadId]);
  end;

  LPromptToSend := APrompt;
  if FThreadId.IsEmpty then
  begin
    LSystemPrompt := GetEffectiveSystemPrompt;
    if not LSystemPrompt.IsEmpty then
      LPromptToSend := LSystemPrompt + sLineBreak + sLineBreak + APrompt;
  end;

  LThread := TThread.CreateAnonymousThread(
    procedure
    begin
      RunCodexLoop(LCmdLine, LPromptToSend, ACallback, AStreamCallback, AIsStream);
    end
  );

  LThread.FreeOnTerminate := True;
  LThread.Start;
end;

initialization
  TProviderRegistry.RegisterProvider(
    TProviderMetadata.Create(
      'OpenAI',
      'OpenAI ChatGPT',
      'https://api.openai.com/v1',
      True, // HasApiKey
      True, // HasCustomUrl
      [MODEL_OPENAI_GPT4O_MINI, MODEL_OPENAI_GPT4O, MODEL_OPENAI_GPT54_MINI, MODEL_OPENAI_GPT54],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIAOpenAIProvider.Create(ACfg);
      end
    )
  );

end.
