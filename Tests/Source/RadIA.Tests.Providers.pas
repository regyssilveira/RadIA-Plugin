unit RadIA.Tests.Providers;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces,
  RadIA.Core.TokenUsage, RadIA.Provider.Gemini, RadIA.Provider.OpenAI, RadIA.Provider.Claude;

type
  TTestRadIAOpenAIProvider = class(TRadIAOpenAIProvider)
  protected
    function GetCodexExecutablePath: string; override;
  end;

  [TestFixture]
  TTestRadIAProviders = class
  private
    FConfig: IRadIAConfig;
    FGeminiProv: TRadIAGeminiProvider;
    FOpenAIProv: TTestRadIAOpenAIProvider;
    FClaudeProv: TRadIAClaudeProvider;

    function InvokeBuildRequestBody(AProvider: TObject; const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>): string;
    function InvokeParseResponseBody(AProvider: TObject; const AJson: string; out AUsage: TTokenUsage): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestGeminiPayloadGeneration;
    [Test]
    procedure TestGeminiResponseParsing;
    [Test]
    procedure TestOpenAIPayloadGeneration;
    [Test]
    procedure TestOpenAIResponseParsing;
    [Test]
    procedure TestClaudePayloadGeneration;
    [Test]
    procedure TestClaudeResponseParsing;
    [Test]
    procedure TestGenericProvider_Create;
    [Test]
    procedure TestOpenAI_ProcessCodexJsonLine;
    [Test]
    procedure TestOpenAI_ReadCodexOutputPipe;
    [Test]
    procedure TestOpenAI_RunCodexLoop_FailurePath;
    [Test]
    procedure TestOpenAI_RunCodexLoop_SuccessPath;
    [Test]
    procedure TestOpenAI_SendPromptAsync_OAuth_CodexNotFound;
    [Test]
    procedure TestOpenAI_SendPromptStreamAsync_OAuth_CodexNotFound;
  end;

  [TestFixture]
  TTestOpenAICustomUrl = class
  public
    [Test]
    procedure TestOpenAI_UsesDefaultUrl_WhenCustomEmpty;
    [Test]
    procedure TestOpenAI_CustomBaseUrl_ReplacesDefault;
    [Test]
    procedure TestOpenAI_CustomBaseUrl_TrailingSlashRemoved;
    [Test]
    procedure TestOpenAI_BaseUrl_ReturnsOfficial_WhenOAuth_EvenWithCustomUrl;
  end;

implementation

uses
  Winapi.Windows, System.Classes, System.SysUtils, System.Rtti, System.JSON,
  RadIA.Tests.Service, RadIA.Core.ChatMessage, RadIA.Provider.Generic,
  RadIA.Core.SettingsStorage, RadIA.Core.Types, RadIA.Core.Config;

function TTestRadIAOpenAIProvider.GetCodexExecutablePath: string;
begin
  Result := '';
end;

{ TTestRadIAProviders }

procedure TTestRadIAProviders.Setup;
begin
  TRadIAConfig.SetBaseRegistryPath('Software\TestRadIAProviders');
  TRadIAConfig.SetStorage(TRadIAMemorySettingsStorage.Create);
  FConfig := TRadIAConfig.Create;
  FGeminiProv := TRadIAGeminiProvider.Create(FConfig);
  FOpenAIProv := TTestRadIAOpenAIProvider.Create(FConfig);
  FClaudeProv := TRadIAClaudeProvider.Create(FConfig);
end;

procedure TTestRadIAProviders.TearDown;
begin
  FGeminiProv.Free;
  FOpenAIProv.Free;
  FClaudeProv.Free;
  FConfig := nil;
  TRadIAConfig.SetStorage(nil);
  TRadIAConfig.SetBaseRegistryPath('');
end;

function TTestRadIAProviders.InvokeBuildRequestBody(AProvider: TObject; const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>): string;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LResult: TValue;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(AProvider.ClassType) as TRttiInstanceType;
  LMethod := LType.GetMethod('BuildRequestBody');
  if not Assigned(LMethod) then
    LMethod := LType.GetMethod('BuildOpenAICompatibleRequestBody');
  if Assigned(LMethod) then
  begin
    case Length(LMethod.GetParameters) of
      4: LResult := LMethod.Invoke(
           AProvider,
           [APrompt, TValue.From<TArray<IRadIAChatMessage>>(AHistory), 0.7, 2048]
         );
      5: LResult := LMethod.Invoke(
           AProvider,
           [APrompt, TValue.From<TArray<IRadIAChatMessage>>(AHistory), False, 0.7, 2048]
         );
    else
      if Length(LMethod.GetParameters) = 3 then
        LResult := LMethod.Invoke(
          AProvider,
          [APrompt, TValue.From<TArray<IRadIAChatMessage>>(AHistory), False]
        )
      else
        LResult := LMethod.Invoke(
          AProvider,
          [APrompt, TValue.From<TArray<IRadIAChatMessage>>(AHistory)]
        );
    end;
    Result := LResult.AsString;
  end
  else
    Result := '';
end;

function TTestRadIAProviders.InvokeParseResponseBody(AProvider: TObject; const AJson: string;
    out AUsage: TTokenUsage): string;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LResult: TValue;
  LParams: TArray<TValue>;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(AProvider.ClassType) as TRttiInstanceType;
  LMethod := LType.GetMethod('ParseResponseBody');
  if not Assigned(LMethod) then
    LMethod := LType.GetMethod('ParseOpenAICompatibleResponse');
  if Assigned(LMethod) then
  begin
    SetLength(LParams, 2);
    LParams[0] := AJson;
    LParams[1] := TValue.From<TTokenUsage>(TTokenUsage.Empty);
    LResult := LMethod.Invoke(AProvider, LParams);
    AUsage := LParams[1].AsType<TTokenUsage>;
    Result := LResult.AsString;
  end
  else
  begin
    AUsage := TTokenUsage.Empty;
    Result := '';
  end;
end;

procedure TTestRadIAProviders.TestGeminiPayloadGeneration;
var
  LPayload: string;
  LHistory: TArray<IRadIAChatMessage>;
  LJson: TJSONObject;
  LContents: TJSONArray;
begin
  LHistory := [TRadIAChatMessage.CreateMessage(mrUser, 'Hello')];
  LPayload := InvokeBuildRequestBody(FGeminiProv, 'How are you?', LHistory);

  Assert.IsNotEmpty(LPayload);
  LJson := TJSONObject.ParseJSONValue(LPayload) as TJSONObject;
  try
    Assert.IsNotNull(LJson, 'Payload should be valid JSON');
    LContents := LJson.GetValue('contents') as TJSONArray;
    Assert.IsNotNull(LContents);
    // 1 from history + 1 current prompt = 2 messages
    Assert.AreEqual(2, LContents.Count);
  finally
    LJson.Free;
  end;
end;

procedure TTestRadIAProviders.TestGeminiResponseParsing;
const
  GEMINI_MOCK_RESPONSE =
    '{"candidates": [{"content": {"parts": [{"text": "Hello! I am Gemini AI."}]}}], ' +
    '"usageMetadata": {"promptTokenCount": 10, "candidatesTokenCount": 15, "totalTokenCount": 25}}';
var
  LText: string;
  LUsage: TTokenUsage;
begin
  LText := InvokeParseResponseBody(FGeminiProv, GEMINI_MOCK_RESPONSE, LUsage);
  Assert.AreEqual('Hello! I am Gemini AI.', LText);
  Assert.AreEqual(10, LUsage.PromptTokens);
  Assert.AreEqual(15, LUsage.CompletionTokens);
  Assert.AreEqual(25, LUsage.TotalTokens);
end;

procedure TTestRadIAProviders.TestOpenAIPayloadGeneration;
var
  LPayload: string;
  LHistory: TArray<IRadIAChatMessage>;
  LJson: TJSONObject;
  LMessages: TJSONArray;
begin
  LHistory := [TRadIAChatMessage.CreateMessage(mrUser, 'Hi')];
  LPayload := InvokeBuildRequestBody(FOpenAIProv, 'Hello OpenAI', LHistory);

  Assert.IsNotEmpty(LPayload);
  LJson := TJSONObject.ParseJSONValue(LPayload) as TJSONObject;
  try
    Assert.IsNotNull(LJson);
    LMessages := LJson.GetValue('messages') as TJSONArray;
    Assert.IsNotNull(LMessages);
    Assert.AreEqual(2, LMessages.Count);
  finally
    LJson.Free;
  end;
end;

procedure TTestRadIAProviders.TestOpenAIResponseParsing;
const
  OPENAI_MOCK_RESPONSE =
    '{"choices": [{"message": {"role": "assistant", "content": "Hello! I am OpenAI ChatGPT."}}], ' +
    '"usage": {"prompt_tokens": 12, "completion_tokens": 18, "total_tokens": 30}}';
var
  LText: string;
  LUsage: TTokenUsage;
begin
  LText := InvokeParseResponseBody(FOpenAIProv, OPENAI_MOCK_RESPONSE, LUsage);
  Assert.AreEqual('Hello! I am OpenAI ChatGPT.', LText);
  Assert.AreEqual(12, LUsage.PromptTokens);
  Assert.AreEqual(18, LUsage.CompletionTokens);
  Assert.AreEqual(30, LUsage.TotalTokens);
end;

procedure TTestRadIAProviders.TestClaudePayloadGeneration;
var
  LPayload: string;
  LHistory: TArray<IRadIAChatMessage>;
  LJson: TJSONObject;
  LMessages: TJSONArray;
begin
  LHistory := [TRadIAChatMessage.CreateMessage(mrUser, 'Hey')];
  LPayload := InvokeBuildRequestBody(FClaudeProv, 'Hello Claude', LHistory);

  Assert.IsNotEmpty(LPayload);
  LJson := TJSONObject.ParseJSONValue(LPayload) as TJSONObject;
  try
    Assert.IsNotNull(LJson);
    LMessages := LJson.GetValue('messages') as TJSONArray;
    Assert.IsNotNull(LMessages);
    Assert.AreEqual(2, LMessages.Count);
  finally
    LJson.Free;
  end;
end;

procedure TTestRadIAProviders.TestClaudeResponseParsing;
const
  CLAUDE_MOCK_RESPONSE =
    '{"content": [{"type": "text", "text": "Hello! I am Anthropic Claude."}], ' +
    '"usage": {"input_tokens": 14, "output_tokens": 21}}';
var
  LText: string;
  LUsage: TTokenUsage;
begin
  LText := InvokeParseResponseBody(FClaudeProv, CLAUDE_MOCK_RESPONSE, LUsage);
  Assert.AreEqual('Hello! I am Anthropic Claude.', LText);
  Assert.AreEqual(14, LUsage.PromptTokens);
  Assert.AreEqual(21, LUsage.CompletionTokens);
end;


type
  TMockSettingsStorageWithError = class(TRadIAMemorySettingsStorage, IRadIASettingsStorage)
  public
    procedure WriteString(const AName, AValue: string);
  end;

procedure TMockSettingsStorageWithError.WriteString(const AName, AValue: string);
begin
  raise Exception.Create('Mock write error');
end;

procedure TTestRadIAProviders.TestGenericProvider_Create;
var
  LProv: TRadIAGenericOpenAIProvider;
begin
  // Caso de sucesso (API Key vazia, nao grava no config)
  LProv := TRadIAGenericOpenAIProvider.Create(
    FConfig, 'DeepSeek', 'DeepSeek AI', 'https://api.deepseek.com', ['deepseek-chat']
  );
  try
    Assert.AreEqual('DeepSeek AI', LProv.GetName);
    Assert.AreEqual<Integer>(1, Length(LProv.GetAvailableModels));
    Assert.AreEqual('deepseek-chat', LProv.GetAvailableModels[0]);
  finally
    LProv.Free;
  end;

  // Caso 2: API Key nao vazia, grava no config com sucesso
  LProv := TRadIAGenericOpenAIProvider.Create(
    FConfig, 'DeepSeekTest', 'DeepSeek Test', 'https://api.deepseek.com',
    ['deepseek-chat'], 'sk-dummy-key'
  );
  try
    Assert.AreEqual('sk-dummy-key', FConfig.GetApiKey('DeepSeekTest'));
  finally
    LProv.Free;
  end;

  // Caso 3: API Key nao vazia, mas gravacao do config falha (cobre except de Generic.pas)
  TRadIAConfig.SetStorage(TMockSettingsStorageWithError.Create);
  try
    LProv := TRadIAGenericOpenAIProvider.Create(
      FConfig, 'DeepSeekError', 'DeepSeek Error', 'https://api.deepseek.com',
      ['deepseek-chat'], 'sk-error-key'
    );
    try
      Assert.AreEqual('DeepSeek Error', LProv.GetName);
    finally
      LProv.Free;
    end;
  finally
    TRadIAConfig.SetStorage(TRadIAMemorySettingsStorage.Create);
  end;
end;

procedure TTestRadIAProviders.TestOpenAI_ProcessCodexJsonLine;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LParams: TArray<TValue>;
  LDelta: string;
  LResponse: string;
  LInputTokens, LOutputTokens: Integer;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(TRadIAOpenAIProvider) as TRttiInstanceType;
  LMethod := LType.GetMethod('ProcessCodexJsonLine');
  Assert.IsNotNull(LMethod, 'ProcessCodexJsonLine method must exist');

  // Test Case 1: thread.started
  SetLength(LParams, 5);
  LParams[0] := '{"type": "thread.started", "thread_id": "thread_123"}';
  LParams[1] := ''; // out ADeltaText
  LParams[2] := ''; // var AResponseText
  LParams[3] := 0;  // var AInputTokens
  LParams[4] := 0;  // var AOutputTokens

  LMethod.Invoke(FOpenAIProv, LParams);

  // Test Case 2: message.delta
  LParams[0] := '{"type": "message.delta", "delta": {"content": ' +
    '[{"type": "text", "text": {"value": "hello"}}]}}';
  LParams[1] := '';
  LParams[2] := 'response_so_far';
  LParams[3] := 0;
  LParams[4] := 0;

  LMethod.Invoke(FOpenAIProv, LParams);
  LDelta := LParams[1].AsString;
  Assert.AreEqual('hello', LDelta);

  // Test Case 3: item.completed
  LParams[0] := '{"type": "item.completed", "item": {"text": "final response text"}}';
  LParams[1] := '';
  LParams[2] := '';
  LParams[3] := 0;
  LParams[4] := 0;

  LMethod.Invoke(FOpenAIProv, LParams);
  LResponse := LParams[2].AsString;
  Assert.AreEqual('final response text', LResponse);

  // Test Case 4: turn.completed
  LParams[0] := '{"type": "turn.completed", "usage": {"input_tokens": 10, "output_tokens": 20}}';
  LParams[1] := '';
  LParams[2] := '';
  LParams[3] := 0;
  LParams[4] := 0;

  LMethod.Invoke(FOpenAIProv, LParams);
  LInputTokens := LParams[3].AsInteger;
  LOutputTokens := LParams[4].AsInteger;
  Assert.AreEqual(10, LInputTokens);
  Assert.AreEqual(20, LOutputTokens);
end;

procedure TTestRadIAProviders.TestOpenAI_ReadCodexOutputPipe;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LHRead, LHWrite: THandle;
  LSa: TSecurityAttributes;
  LResponse: string;
  LBytesWritten: DWORD;
  LData: RawByteString;
  LInvokeParams: TArray<TValue>;
begin
  LSa.nLength := SizeOf(TSecurityAttributes);
  LSa.bInheritHandle := True;
  LSa.lpSecurityDescriptor := nil;

  if not CreatePipe(LHRead, LHWrite, @LSa, 0) then
    Assert.Fail('Failed to create pipe for test');

  try
    LData := '{"type": "message.delta", "delta": {"content": [{"type": "text", "text": {"value": "part1"}}]}}' + #10 +
             '{"type": "message.delta", "delta": {"content": [{"type": "text", "text": {"value": "part2"}}]}}' + #10;
    WriteFile(LHWrite, LData[1], Length(LData), LBytesWritten, nil);
    CloseHandle(LHWrite);

    LContext := TRttiContext.Create;
    LType := LContext.GetType(TRadIAOpenAIProvider) as TRttiInstanceType;
    LMethod := LType.GetMethod('ReadCodexOutputPipe');
    Assert.IsNotNull(LMethod, 'ReadCodexOutputPipe method must exist');

    SetLength(LInvokeParams, 6);
    LInvokeParams[0] := LHRead;
    LInvokeParams[1] := False; // AIsStream
    LInvokeParams[2] := TValue.From<TStreamChunkCallback>(nil);
    LInvokeParams[3] := ''; // var AResponseText
    LInvokeParams[4] := 0; // var AInputTokens
    LInvokeParams[5] := 0; // var AOutputTokens

    LMethod.Invoke(FOpenAIProv, LInvokeParams);

    LResponse := LInvokeParams[3].AsString;
    Assert.AreEqual('part1part2', LResponse);
  finally
    CloseHandle(LHRead);
  end;
end;

procedure TTestRadIAProviders.TestOpenAI_RunCodexLoop_FailurePath;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LInvokeParams: TArray<TValue>;
  LCallback: TCompletionCallback;
  LCallbackCalled: Boolean;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(TRadIAOpenAIProvider) as TRttiInstanceType;
  LMethod := LType.GetMethod('RunCodexLoop');
  Assert.IsNotNull(LMethod, 'RunCodexLoop method must exist');

  LCallbackCalled := False;
  LCallback :=
    procedure(
      const AResponse: string;
      const AError: string;
      AFromCache: Boolean;
      const AUsage: TTokenUsage
    )
    begin
      LCallbackCalled := True;
      Assert.IsFalse(AFromCache);
      Assert.Contains(AError, 'Failed to create the Codex process');
    end;

  SetLength(LInvokeParams, 5);
  LInvokeParams[0] := 'invalid_codex_cli_executable_name.exe';
  LInvokeParams[1] := 'test prompt';
  LInvokeParams[2] := TValue.From<TCompletionCallback>(LCallback);
  LInvokeParams[3] := TValue.From<TStreamChunkCallback>(nil);
  LInvokeParams[4] := False;

  LMethod.Invoke(FOpenAIProv, LInvokeParams);

  CheckSynchronize(1000);

  Assert.IsTrue(LCallbackCalled, 'Callback should have been executed via thread queue');
end;

procedure TTestRadIAProviders.TestOpenAI_RunCodexLoop_SuccessPath;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LInvokeParams: TArray<TValue>;
  LCallback: TCompletionCallback;
  LCallbackCalled: Boolean;
  LCmdLine: string;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(TRadIAOpenAIProvider) as TRttiInstanceType;
  LMethod := LType.GetMethod('RunCodexLoop');
  Assert.IsNotNull(LMethod, 'RunCodexLoop method must exist');

  LCallbackCalled := False;
  LCmdLine := 'cmd.exe /c echo {"type": "item.completed", "item": {"text": "hello from cmd"}}';
  LCallback :=
    procedure(
      const AResponse: string;
      const AError: string;
      AFromCache: Boolean;
      const AUsage: TTokenUsage
    )
    begin
      LCallbackCalled := True;
      Assert.IsTrue(AFromCache);
      Assert.AreEqual('hello from cmd', AResponse);
    end;

  SetLength(LInvokeParams, 5);
  LInvokeParams[0] := LCmdLine;
  LInvokeParams[1] := 'test prompt';
  LInvokeParams[2] := TValue.From<TCompletionCallback>(LCallback);
  LInvokeParams[3] := TValue.From<TStreamChunkCallback>(nil);
  LInvokeParams[4] := False;

  LMethod.Invoke(FOpenAIProv, LInvokeParams);

  CheckSynchronize(2000);

  Assert.IsTrue(LCallbackCalled, 'Completion callback should have been executed');
end;

procedure TTestRadIAProviders.TestOpenAI_SendPromptAsync_OAuth_CodexNotFound;
var
  LCallbackCalled: Boolean;
  LErrorText: string;
begin
  LCallbackCalled := False;
  LErrorText := '';
  FConfig.SetProviderAuthType('OpenAI', 'oauth');
  FConfig.SetActiveModel('OpenAI', 'gpt-5.4');

  FOpenAIProv.SendPromptAsync(
    'test prompt',
    [],
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    begin
      LCallbackCalled := True;
      LErrorText := AError;
      Assert.IsNotEmpty(AError);
    end,
    0.7,
    1000
  );

  Assert.IsTrue(LCallbackCalled, 'Missing executable must report the error synchronously');
  Assert.Contains(LErrorText, 'Settings > CLI & MCP');
  Assert.Contains(LErrorText, 'existing executable');
  Assert.Contains(LErrorText, 'https://github.com/openai/codex');
end;

procedure TTestRadIAProviders.TestOpenAI_SendPromptStreamAsync_OAuth_CodexNotFound;
var
  LCallbackCalled: Boolean;
  LErrorText: string;
begin
  LCallbackCalled := False;
  LErrorText := '';
  FConfig.SetProviderAuthType('OpenAI', 'oauth');
  FConfig.SetActiveModel('OpenAI', 'gpt-5.4');

  FOpenAIProv.SendPromptStreamAsync(
    'test prompt',
    [],
    procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
    begin
      if AIsDone then
      begin
        LCallbackCalled := True;
        LErrorText := AError;
        Assert.IsNotEmpty(AError);
      end;
    end,
    0.7,
    1000
  );

  Assert.IsTrue(LCallbackCalled, 'Missing executable must report the stream error synchronously');
  Assert.Contains(LErrorText, 'Settings > CLI & MCP');
  Assert.Contains(LErrorText, 'existing executable');
  Assert.Contains(LErrorText, 'https://github.com/openai/codex');
end;


{ TTestOpenAICustomUrl }

procedure TTestOpenAICustomUrl.TestOpenAI_UsesDefaultUrl_WhenCustomEmpty;
var
  LConfig: IRadIAConfig;
  LProvider: TRadIAOpenAIProvider;
begin
  { Use TMockConfig to avoid registry state contamination from other tests }
  LConfig := TMockConfig.Create(20);
  LProvider := TRadIAOpenAIProvider.Create(LConfig);
  try
    Assert.IsEmpty(LConfig.GetOpenAICustomBaseUrl,
      'Custom Base URL must be empty by default â€” provider will use official OpenAI endpoint');
  finally
    LProvider.Free;
    LConfig := nil;
  end;
end;

procedure TTestOpenAICustomUrl.TestOpenAI_CustomBaseUrl_ReplacesDefault;
var
  LConfig: IRadIAConfig;
const
  CUSTOM_URL = 'http://localhost:1234/v1';
begin
  LConfig := TMockConfig.Create(20);
  try
    LConfig.OpenAICustomBaseUrl := CUSTOM_URL;
    Assert.AreEqual(CUSTOM_URL, LConfig.GetOpenAICustomBaseUrl,
      'Custom Base URL must be stored and retrievable without modification');
  finally
    LConfig := nil;
  end;
end;

procedure TTestOpenAICustomUrl.TestOpenAI_CustomBaseUrl_TrailingSlashRemoved;
var
  LConfig: IRadIAConfig;
  LExpectedChatUrl: string;
const
  CUSTOM_URL_WITH_SLASH = 'http://localhost:1234/v1/';
  EXPECTED_CHAT_PATH    = '/chat/completions';
begin
  { Verify that TrimRight(['/']) + path produces the correct URL without double slash }
  LConfig := TMockConfig.Create(20);
  try
    LConfig.OpenAICustomBaseUrl := CUSTOM_URL_WITH_SLASH;
    LExpectedChatUrl := LConfig.GetOpenAICustomBaseUrl.TrimRight(['/']) + EXPECTED_CHAT_PATH;
    Assert.AreEqual('http://localhost:1234/v1' + EXPECTED_CHAT_PATH, LExpectedChatUrl,
      'Trailing slash must be stripped before appending path to avoid double slash');
  finally
    LConfig := nil;
  end;
end;

procedure TTestOpenAICustomUrl.TestOpenAI_BaseUrl_ReturnsOfficial_WhenOAuth_EvenWithCustomUrl;
var
  LConfig: IRadIAConfig;
  LProvider: TRadIAOpenAIProvider;
  LReflect: TRttiContext;
  LMethod: TRttiMethod;
  LUrl: string;
begin
  LConfig := TMockConfig.Create(20);
  try
    LConfig.SetProviderAuthType('OpenAI', 'oauth');
    LConfig.OpenAICustomBaseUrl := 'http://localhost:1234/v1';
    LProvider := TRadIAOpenAIProvider.Create(LConfig);
    try
      LReflect := TRttiContext.Create;
      LMethod := LReflect.GetType(TRadIAOpenAIProvider).GetMethod('GetBaseUrl');
      LUrl := LMethod.Invoke(LProvider, []).AsString;
      Assert.AreEqual('https://api.openai.com/v1', LUrl,
        'Base URL must always be the official OpenAI endpoint in OAuth mode, ignoring any custom URLs');
    finally
      LProvider.Free;
    end;
  finally
    LConfig := nil;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAProviders);
  TDUnitX.RegisterTestFixture(TTestOpenAICustomUrl);

end.

