unit RadIA.Provider.OpenAI;

interface

uses
  System.SysUtils, System.JSON, RadIA.Core.Interfaces, RadIA.Provider.Base;

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
    procedure ProcessCodexEvent(
      const AJson: TJSONObject;
      const AFallback: string;
      out ADeltaText: string;
      var AResponseText: string;
      var AInputTokens: Integer;
      var AOutputTokens: Integer
    );
    function ExtractCodexError(
      const AJson: TJSONObject;
      const AFallback: string
    ): string;
    procedure ExecuteCodexCli(const APrompt: string; const ACallback: TCompletionCallback;
      const AStreamCallback: TStreamChunkCallback; const AIsStream: Boolean);
    function BuildCodexExecutableError(const AReason: string): string;
    function GetEffectiveSystemPrompt: string;
    function GetCodexModelData(const AJson: TJSONObject): TJSONArray;
    function GetCodexModelId(const AValue: TJSONValue): string;
    function ParseCodexModelLine(const ALine: string): TArray<string>;
    function ParseCodexModelList(const AOutput: string): TArray<string>;
  protected
    function GetCodexExecutablePath: string; virtual;
    function UsesCodexCliTransport: Boolean;
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

    procedure FetchAvailableModelsAsync(const ACallback: TProc<TArray<string>, string>); override;
    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
  end;

implementation

uses
  System.Classes, Winapi.Windows,
  System.Generics.Collections, RadIA.Core.ProviderRegistry, RadIA.Core.Types,
  RadIA.Core.TokenUsage, RadIA.Core.Logger, RadIA.Core.Container,
  RadIA.Core.CliManager, RadIA.Core.AgentExecutors, RadIA.Core.CliProcess;

{ TRadIAOpenAIProvider }

constructor TRadIAOpenAIProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  FProviderId := 'OpenAI';
end;

function TRadIAOpenAIProvider.GetBaseUrl: string;
begin
  if SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') or
    SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth_cli') then
    Result := 'https://api.openai.com/v1'
  else if not FConfig.GetOpenAICustomBaseUrl.IsEmpty then
    Result := FConfig.GetOpenAICustomBaseUrl
  else
    Result := 'https://api.openai.com/v1';
end;

function TRadIAOpenAIProvider.UsesCodexCliTransport: Boolean;
begin
  Result := SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth_cli') or
    SameText(FConfig.GetProviderAuthType(FProviderId), 'oauth') or
    SameText(FConfig.GetProviderAuthType(FProviderId), 'web_login');
end;

function TRadIAOpenAIProvider.GetAvailableModels: TArray<string>;
begin
  Result := TArray<string>.Create(
    MODEL_OPENAI_GPT56_TERRA,
    MODEL_OPENAI_GPT56_SOL,
    MODEL_OPENAI_GPT56_LUNA
  );
end;

function TRadIAOpenAIProvider.ParseCodexModelList(const AOutput: string): TArray<string>;
var
  LLines: TStringList;
  LLine: string;
  LModelId: string;
  LModelIds: TArray<string>;
  LModels: TList<string>;
begin
  LLines := TStringList.Create;
  LModels := TList<string>.Create;
  try
    LLines.Text := AOutput;
    for LLine in LLines do
    begin
      LModelIds := ParseCodexModelLine(LLine);
      for LModelId in LModelIds do
        if not LModels.Contains(LModelId) then
          LModels.Add(LModelId);
    end;
    Result := LModels.ToArray;
  finally
    LModels.Free;
    LLines.Free;
  end;
end;

function TRadIAOpenAIProvider.ParseCodexModelLine(
  const ALine: string
): TArray<string>;
var
  LData: TJSONArray;
  LJson: TJSONObject;
  LModelId: string;
  LModels: TList<string>;
  LValue: TJSONValue;
begin
  LModels := TList<string>.Create;
  LJson := TJSONObject.ParseJSONValue(ALine.Trim) as TJSONObject;
  try
    if not Assigned(LJson) then
      Exit(nil);
    LData := GetCodexModelData(LJson);
    if not Assigned(LData) then
      Exit(nil);
    for LValue in LData do
    begin
      LModelId := GetCodexModelId(LValue);
      if LModelId <> '' then
        LModels.Add(LModelId);
    end;
    Result := LModels.ToArray;
  finally
    LJson.Free;
    LModels.Free;
  end;
end;

function TRadIAOpenAIProvider.GetCodexModelData(
  const AJson: TJSONObject
): TJSONArray;
var
  LResult: TJSONObject;
begin
  Result := nil;
  if AJson.GetValue<Integer>('id', 0) <> 2 then
    Exit;
  LResult := AJson.GetValue('result') as TJSONObject;
  if Assigned(LResult) then
    Result := LResult.GetValue('data') as TJSONArray;
end;

function TRadIAOpenAIProvider.GetCodexModelId(
  const AValue: TJSONValue
): string;
begin
  Result := '';
  if not (AValue is TJSONObject) then
    Exit;
  Result := TJSONObject(AValue).GetValue<string>('model', '');
  if Result.IsEmpty then
    Result := TJSONObject(AValue).GetValue<string>('id', '');
end;

procedure TRadIAOpenAIProvider.FetchAvailableModelsAsync(
  const ACallback: TProc<TArray<string>, string>);
const
  CDiscoveryTimeoutMs = 10000;
var
  LCodexPath: string;
  LInput: string;
  LInvocation: TRadIACliInvocation;
  LProviderRef: IRadIAProvider;
begin
  if not UsesCodexCliTransport then
  begin
    inherited FetchAvailableModelsAsync(ACallback);
    Exit;
  end;

  LCodexPath := GetCodexExecutablePath;
  if LCodexPath.IsEmpty then
  begin
    ACallback(GetAvailableModels, 'Codex CLI executable was not found.');
    Exit;
  end;

  LInput := '{"method":"initialize","id":1,"params":{"clientInfo":' +
    '{"name":"radia","title":"Rad IA","version":"2.2"},"capabilities":{}}}' + sLineBreak +
    '{"method":"initialized","params":{}}' + sLineBreak +
    '{"method":"model/list","id":2,"params":{"limit":100,"includeHidden":false}}' + sLineBreak;
  LInvocation := TRadIACliInvocation.Create(LCodexPath, ['app-server'], '', 'jsonl');
  LProviderRef := Self;
  TRadIACliProcessRunner.StartWithInput(
    LInvocation,
    LInput,
    CDiscoveryTimeoutMs,
    nil,
    nil,
    procedure(AResult: TRadIACliProcessResult)
    var
      LModels: TArray<string>;
    begin
      LProviderRef.GetProviderId;
      LModels := ParseCodexModelList(AResult.StdOut);
      if Length(LModels) > 0 then
        ACallback(LModels, '')
      else if AResult.TimedOut then
        ACallback(GetAvailableModels, 'Codex model discovery timed out.')
      else
        ACallback(GetAvailableModels, 'Codex model discovery returned no visible models.');
    end
  );
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
  if UsesCodexCliTransport then
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
  if UsesCodexCliTransport then
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

function TRadIAOpenAIProvider.BuildCodexExecutableError(const AReason: string): string;
var
  LExpectedPath: string;
  LResolvedPath: string;
begin
  LExpectedPath := TRadIACliResolver.ExpectedExecutablePath('codex');
  LResolvedPath := GetCodexExecutablePath;
  Result := 'Error: ' + AReason + ' ';
  if not LResolvedPath.IsEmpty then
    Result := Result + 'Resolved executable: `' + LResolvedPath + '`. ';
  Result := Result + 'Expected global npm executable: `' + LExpectedPath + '`. ' +
    'Open Settings > CLI & MCP, select Codex CLI, and use Browse if the executable is installed ' +
    'elsewhere. The executable bundled inside the Windows Store Codex app may be protected by Windows.';
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

    LUsage.PromptTokens := LInputTokens;
    LUsage.CompletionTokens := LOutputTokens;
    LUsage.TotalTokens := LInputTokens + LOutputTokens;
    if LExitCode <> 0 then
    begin
      if LResponseText.IsEmpty then
        LResponseText := Format(
          'Codex CLI exited with code %d without diagnostic output.',
          [LExitCode]
        );
      QueueError(
        AIsStream,
        AStreamCallback,
        ACallback,
        LResponseText
      );
    end
    else if LResponseText.StartsWith('Codex CLI error:', True) then
      QueueError(
        AIsStream,
        AStreamCallback,
        ACallback,
        LResponseText
      )
    else if LResponseText.IsEmpty then
      QueueError(
        AIsStream,
        AStreamCallback,
        ACallback,
        'Codex CLI completed without returning an assistant response.'
      )
    else
      QueueCompletion(
        AIsStream,
        AStreamCallback,
        ACallback,
        LResponseText,
        LUsage
      );
  end
  else
  begin
    QueueError(
      AIsStream,
      AStreamCallback,
      ACallback,
      BuildCodexExecutableError('Failed to create the Codex process.')
    );
  end;
end;

procedure TRadIAOpenAIProvider.ProcessCodexJsonLine(const AJsonStr: string;
  out ADeltaText: string; var AResponseText: string; var AInputTokens, AOutputTokens: Integer);
var
  LJson: TJSONObject;
begin
  ADeltaText := '';
  try
    LJson := TJSONObject.ParseJSONValue(AJsonStr) as TJSONObject;
  except
    on E: Exception do
    begin
      TLogger.Log('Error parsing Codex JSON: ' + E.Message, 'OpenAI');
      if not AJsonStr.Trim.IsEmpty then
        AResponseText := 'Codex CLI error: ' + AJsonStr.Trim;
      Exit;
    end;
  end;

  if not Assigned(LJson) then
  begin
    if not AJsonStr.Trim.IsEmpty then
      AResponseText := 'Codex CLI error: ' + AJsonStr.Trim;
    Exit;
  end;

  try
    ProcessCodexEvent(
      LJson,
      AJsonStr,
      ADeltaText,
      AResponseText,
      AInputTokens,
      AOutputTokens
    );
  finally
    LJson.Free;
  end;
end;

function TRadIAOpenAIProvider.ExtractCodexError(
  const AJson: TJSONObject;
  const AFallback: string
): string;
var
  LError: TJSONObject;
begin
  Result := AJson.GetValue<string>('message', '');
  LError := AJson.GetValue('error') as TJSONObject;
  if Result.IsEmpty and Assigned(LError) then
    Result := LError.GetValue<string>('message', '');
  if Result.IsEmpty then
    Result := AFallback;
  Result := 'Codex CLI error: ' + Result.Trim;
end;

procedure TRadIAOpenAIProvider.ProcessCodexEvent(
  const AJson: TJSONObject;
  const AFallback: string;
  out ADeltaText: string;
  var AResponseText: string;
  var AInputTokens: Integer;
  var AOutputTokens: Integer
);
var
  LType: string;
begin
  ADeltaText := '';
  LType := AJson.GetValue<string>('type', '');
  if LType.IsEmpty then
    LType := AJson.GetValue<string>('object', '');
  if SameText(LType, 'thread.started') then
    ProcessThreadStarted(AJson, FThreadId)
  else if SameText(LType, 'thread.message.delta') or
    SameText(LType, 'message.delta') then
    ADeltaText := ProcessMessageDelta(AJson, Self)
  else if SameText(LType, 'item.completed') then
    ProcessItemCompleted(AJson, AResponseText)
  else if SameText(LType, 'turn.completed') then
    ProcessTurnCompleted(AJson, AInputTokens, AOutputTokens)
  else if SameText(LType, 'error') or SameText(LType, 'turn.failed') then
    AResponseText := ExtractCodexError(AJson, AFallback);
  if ADeltaText.IsEmpty then
    ADeltaText := AJson.GetValue<string>('text', '');
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

  LCodexPath := GetCodexExecutablePath;

  if LCodexPath.IsEmpty then
  begin
    if AIsStream then
      AStreamCallback(
        '',
        True,
        BuildCodexExecutableError(
          'ChatGPT OAuth uses Codex CLI as its transport, but the executable was not found.'
        )
      )
    else
      ACallback(
        '',
        BuildCodexExecutableError(
          'ChatGPT OAuth uses Codex CLI as its transport, but the executable was not found.'
        ),
        False,
        TTokenUsage.Empty
      );
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
      '"%s" -m %s exec resume --json --skip-git-repo-check "%s" -',
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
      [MODEL_OPENAI_GPT56_TERRA, MODEL_OPENAI_GPT56_SOL, MODEL_OPENAI_GPT56_LUNA],
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIAOpenAIProvider.Create(ACfg);
      end
    )
  );

end.
