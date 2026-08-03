unit RadIA.Tests.ProvidersEx;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces,
  RadIA.Core.TokenUsage, RadIA.Provider.DeepSeek, RadIA.Provider.Groq, RadIA.Provider.OpenRouter,
  RadIA.Provider.LMStudio, RadIA.Provider.AzureOpenAI, RadIA.Provider.Qwen, RadIA.Provider.Mistral,
  RadIA.Provider.Bedrock,
  RadIA.Provider.GithubCopilot,
  RadIA.Provider.Gemini, RadIA.Provider.Claude, RadIA.Provider.Ollama,
  System.SysUtils, System.Net.URLClient;

type
  TMockHttpClient = class(TInterfacedObject, IRadIAHttpClient)
  private
    FResponseStr: string;
    FStreamChunks: TArray<string>;
    FLastUrl: string;
    FStatusCodeToThrow: Integer;
    FErrorContentToThrow: string;
    FCancelled: Boolean;
  public
    procedure SetResponse(const AResponse: string);
    procedure SetStreamChunks(const AChunks: TArray<string>);
    procedure SetErrorResponse(const AStatusCode: Integer; const AContent: string);

    function Get(const AUrl: string; const AHeaders: TNetHeaders; const ATimeoutMs: Integer = 0): string;
    function Post(const AUrl: string; const AHeaders: TNetHeaders;
      const ARequestBody: string; const ATimeoutMs: Integer = 0): string;
    procedure PostStream(const AUrl: string; const AHeaders: TNetHeaders; const ARequestBody: string;
      const AOnWrite: TProc<TBytes>; const ATimeoutMs: Integer = 0);
    procedure Cancel;

    property LastUrl: string read FLastUrl;
  end;

  [TestFixture]
  TTestRadIAProvidersEx = class
  private
    FConfig: IRadIAConfig;
    FDeepSeekProv: TRadIADeepSeekProvider;
    FGroqProv: TRadIAGroqProvider;
    FOpenRouterProv: TRadIAOpenRouterProvider;
    FLMStudioProv: TRadIALMStudioProvider;
    FAzureProv: TRadIAAzureOpenAIProvider;
    FQwenProv: TRadIAQwenProvider;
    FMistralProv: TRadIAMistralProvider;
    FBedrockProv: TRadIABedrockProvider;
    FGithubCopilotProv: TRadIAGithubCopilotProvider;
    FGeminiProv: TRadIAGeminiProvider;
    FClaudeProv: TRadIAClaudeProvider;
    FOllamaProv: TRadIAOllamaProvider;
    FDeepSeekProvRef: IRadIAProvider;
    FGroqProvRef: IRadIAProvider;
    FOpenRouterProvRef: IRadIAProvider;
    FLMStudioProvRef: IRadIAProvider;
    FAzureProvRef: IRadIAProvider;
    FQwenProvRef: IRadIAProvider;
    FMistralProvRef: IRadIAProvider;
    FBedrockProvRef: IRadIAProvider;
    FGithubCopilotProvRef: IRadIAProvider;
    FGeminiProvRef: IRadIAProvider;
    FClaudeProvRef: IRadIAProvider;
    FOllamaProvRef: IRadIAProvider;
    FMockHttpClient: TMockHttpClient;
    FUsageResult: TTokenUsage;

    procedure RunProviderSendPromptAsyncTest(AProvider: IRadIAProvider; const AProviderId: string;
      const AMockResponse: string; const AExpectedResponse: string);
    procedure RunProviderSendPromptStreamAsyncTest(AProvider: IRadIAProvider; const AProviderId: string;
      const AStreamChunks: TArray<string>; const AExpectedText: string);

    function InvokeBuildRequestBody(AProvider: TObject; const APrompt: string;
      const AHistory: TArray<IRadIAChatMessage>; const AStream: Boolean = False): string;
    function InvokeParseResponseBody(AProvider: TObject; const AJson: string; out AUsage: TTokenUsage): string;
    procedure InvokeProcessStreamBuffer(AProvider: TObject; var ABuffer: string; const ACallback: TStreamChunkCallback);
    procedure RunOpenAIPayloadTest(AProvider: TObject; const APrompt: string;
      const AHistoryQuery: string; const AMockResponse: string; const AExpectedModel: string;
      const AExpectedResponse: string; const AStream: Boolean;
      APromptTokens, ACompletionTokens, ATotalTokens: Integer);
    procedure RunOpenAIStreamingTest(AProvider: TObject; const AInputBuffer: string;
      const AExpectedText: string; AExpectedCallbackCount: Integer);
    function InvokeGetBaseUrl(AProvider: TObject): string;
    function InvokeGetModelsDiscoveryUrl(AProvider: TObject): string;
    function InvokeFilterModelId(AProvider: TObject; const AModelId: string): Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TestChatMessageProperties;
    [Test]
    procedure TestDeepSeek_PayloadAndParsing;
    [Test]
    procedure TestDeepSeek_StreamingSSE;
    [Test]
    procedure TestDeepSeek_SendPromptAsync;
    [Test]
    procedure TestDeepSeek_SendPromptStreamAsync;
    [Test]
    procedure TestGroq_PayloadAndParsing;
    [Test]
    procedure TestGroq_StreamingSSE;
    [Test]
    procedure TestGroq_SendPromptAsync;
    [Test]
    procedure TestGroq_SendPromptStreamAsync;
    [Test]
    procedure TestOpenRouter_PayloadAndParsing;
    [Test]
    procedure TestOpenRouter_StreamingSSE;
    [Test]
    procedure TestOpenRouter_SendPromptAsync;
    [Test]
    procedure TestOpenRouter_SendPromptStreamAsync;
    [Test]
    procedure TestLMStudio_PayloadAndParsing;
    [Test]
    procedure TestLMStudio_StreamingSSE;
    [Test]
    procedure TestLMStudio_SendPromptAsync;
    [Test]
    procedure TestLMStudio_SendPromptStreamAsync;
    [Test]
    procedure TestAzureOpenAI_PayloadAndParsing;
    [Test]
    procedure TestAzureOpenAI_StreamingSSE;
    [Test]
    procedure TestAzureOpenAI_SendPromptAsync;
    [Test]
    procedure TestAzureOpenAI_SendPromptStreamAsync;
    [Test]
    procedure TestQwen_PayloadAndParsing;
    [Test]
    procedure TestQwen_StreamingSSE;
    [Test]
    procedure TestQwen_SendPromptAsync;
    [Test]
    procedure TestQwen_SendPromptStreamAsync;
    [Test]
    procedure TestMistral_PayloadAndParsing;
    [Test]
    procedure TestMistral_StreamingSSE;
    [Test]
    procedure TestMistral_SendPromptAsync;
    [Test]
    procedure TestMistral_SendPromptStreamAsync;
    [Test]
    procedure TestBedrock_PayloadAndParsing;
    [Test]
    procedure TestBedrock_AwsSignerSigV4;
    [Test]
    procedure TestBedrock_EventStreamParser;
    [Test]
    procedure TestGithubCopilot_PayloadAndParsing;
    [Test]
    procedure TestGithubCopilot_StreamingSSE;
    [Test]
    procedure TestGithubCopilot_SendPromptAsync;
    [Test]
    procedure TestGithubCopilot_SendPromptStreamAsync;
    [Test]
    procedure TestGemini_SendPromptAsync;
    [Test]
    procedure TestGemini_SendPromptStreamAsync;
    [Test]
    procedure TestClaude_SendPromptAsync;
    [Test]
    procedure TestClaude_SendPromptStreamAsync;
    [Test]
    procedure TestOllama_SendPromptAsync;
    [Test]
    procedure TestOllama_SendPromptStreamAsync;
    [Test]
    procedure TestBedrock_SendPromptAsync;
    [Test]
    procedure TestBedrock_SendPromptStreamAsync;
    [Test]
    procedure TestProviderBase_HttpExceptionsPart1;
    [Test]
    procedure TestProviderBase_HttpExceptionsPart2;
    [Test]
    procedure TestOllama_FetchAvailableModels;
    [Test]
    procedure TestGithubCopilot_HttpExceptions;
    [Test]
    procedure TestProvidersDiscoveryAndFiltering;
    [Test]
    procedure TestGemini_FetchAvailableModels;
    [Test]
    procedure TestProviderBase_ErrorParsing;
    [Test]
    procedure TestProviderBase_CancellationAndTimeout;
  end;

implementation

uses
  System.Classes, System.Rtti, System.JSON, System.Net.HttpClient, System.NetEncoding, RadIA.Core.ChatMessage,
  RadIA.Core.Container, RadIA.Core.Types, RadIA.Core.Config, RadIA.Core.AwsSigner, RadIA.Core.SettingsStorage,
  RadIA.Provider.OpenAI;

{ TTestRadIAProvidersEx }

procedure TTestRadIAProvidersEx.TestChatMessageProperties;
var
  LMsg: IRadIAChatMessage;
begin
  LMsg := TRadIAChatMessage.CreateMessage(mrUser, 'content', 'provider', 'model');
  Assert.AreEqual(mrUser, LMsg.Role);
  Assert.AreEqual('content', LMsg.Content);
  Assert.AreEqual('provider', LMsg.Provider);
  Assert.AreEqual('model', LMsg.Model);

  LMsg.Content := 'new content';
  LMsg.Provider := 'new provider';
  LMsg.Model := 'new model';

  Assert.AreEqual('new content', LMsg.Content);
  Assert.AreEqual('new provider', LMsg.Provider);
  Assert.AreEqual('new model', LMsg.Model);
end;

procedure TTestRadIAProvidersEx.Setup;
begin
  TRadIAConfig.SetBaseRegistryPath('Software\TestRadIAProvidersEx');
  TRadIAConfig.SetStorage(TRadIAMemorySettingsStorage.Create);
  FConfig := TRadIAConfig.Create;
  FConfig.SetActiveModel('DeepSeek', MODEL_DEEPSEEK_CHAT);
  FConfig.SetActiveModel('Groq', MODEL_GROQ_LLAMA33);
  FConfig.SetActiveModel('OpenRouter', MODEL_OPENROUTER_GEMINI25_PRO);
  FConfig.SetActiveModel('LMStudio', 'lms-default');
  FConfig.SetActiveModel('Qwen', MODEL_QWEN_25_CODER_32B);
  FConfig.SetActiveModel('Mistral', MODEL_MISTRAL_CODESTRAL);
  FConfig.SetActiveModel('Gemini', MODEL_GEMINI_15_FLASH);
  FConfig.SetActiveModel('Claude', MODEL_CLAUDE_3_HAIKU);
  FConfig.SetActiveModel('Ollama', 'llama3:latest');
  FConfig.SetActiveModel('Bedrock', 'anthropic.claude-3-5-sonnet-20241022-v2:0');

  FMockHttpClient := TMockHttpClient.Create;
  TRadIAContainer.Register<IRadIAHttpClient>(FMockHttpClient as IRadIAHttpClient);

  FDeepSeekProv := TRadIADeepSeekProvider.Create(FConfig);
  FDeepSeekProvRef := FDeepSeekProv;
  FGroqProv := TRadIAGroqProvider.Create(FConfig);
  FGroqProvRef := FGroqProv;
  FOpenRouterProv := TRadIAOpenRouterProvider.Create(FConfig);
  FOpenRouterProvRef := FOpenRouterProv;
  FLMStudioProv := TRadIALMStudioProvider.Create(FConfig);
  FLMStudioProvRef := FLMStudioProv;
  FAzureProv := TRadIAAzureOpenAIProvider.Create(FConfig);
  FAzureProvRef := FAzureProv;
  FQwenProv := TRadIAQwenProvider.Create(FConfig);
  FQwenProvRef := FQwenProv;
  FMistralProv := TRadIAMistralProvider.Create(FConfig);
  FMistralProvRef := FMistralProv;
  FBedrockProv := TRadIABedrockProvider.Create(FConfig);
  FBedrockProvRef := FBedrockProv;
  FGithubCopilotProv := TRadIAGithubCopilotProvider.Create(FConfig);
  FGithubCopilotProvRef := FGithubCopilotProv;
  FGeminiProv := TRadIAGeminiProvider.Create(FConfig);
  FGeminiProvRef := FGeminiProv;
  FClaudeProv := TRadIAClaudeProvider.Create(FConfig);
  FClaudeProvRef := FClaudeProv;
  FOllamaProv := TRadIAOllamaProvider.Create(FConfig);
  FOllamaProvRef := FOllamaProv;
end;

procedure TTestRadIAProvidersEx.TearDown;
var
  LTimeout: Integer;
begin
  LTimeout := 0;
  while (GActiveThreadCount > 0) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
  end;
  Sleep(100); // Aguarda a conclusÃ£o da limpeza fÃ­sica de threads de pool

  FDeepSeekProvRef := nil;
  FGroqProvRef := nil;
  FOpenRouterProvRef := nil;
  FLMStudioProvRef := nil;
  FAzureProvRef := nil;
  FQwenProvRef := nil;
  FMistralProvRef := nil;
  FBedrockProvRef := nil;
  FGithubCopilotProvRef := nil;
  FGeminiProvRef := nil;
  FClaudeProvRef := nil;
  FOllamaProvRef := nil;

  FDeepSeekProv := nil;
  FGroqProv := nil;
  FOpenRouterProv := nil;
  FLMStudioProv := nil;
  FAzureProv := nil;
  FQwenProv := nil;
  FMistralProv := nil;
  FBedrockProv := nil;
  FGithubCopilotProv := nil;
  FGeminiProv := nil;
  FClaudeProv := nil;
  FOllamaProv := nil;

  FConfig := nil;
  TRadIAContainer.Register<IRadIAHttpClient>(nil);
  FMockHttpClient := nil;
  TRadIAConfig.SetStorage(nil);
  TRadIAConfig.SetBaseRegistryPath('');
end;

function TTestRadIAProvidersEx.InvokeBuildRequestBody(AProvider: TObject; const APrompt: string;
  const AHistory: TArray<IRadIAChatMessage>; const AStream: Boolean): string;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LResult: TValue;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(AProvider.ClassType) as TRttiInstanceType;
  LMethod := LType.GetMethod('BuildBedrockRequestBody');
  if not Assigned(LMethod) then
    LMethod := LType.GetMethod('BuildRequestBody');
  if not Assigned(LMethod) then
    LMethod := LType.GetMethod('BuildOpenAICompatibleRequestBody');
  if Assigned(LMethod) then
  begin
    case Length(LMethod.GetParameters) of
      4: LResult := LMethod.Invoke(AProvider, [APrompt, TValue.From<TArray<IRadIAChatMessage>>(AHistory),
          TValue.From<Double>(0.7), TValue.From<Integer>(2048)]);
      5: LResult := LMethod.Invoke(AProvider, [APrompt, TValue.From<TArray<IRadIAChatMessage>>(AHistory),
          AStream, TValue.From<Double>(0.7), TValue.From<Integer>(2048)]);
    else
      LResult := LMethod.Invoke(AProvider, [APrompt, TValue.From<TArray<IRadIAChatMessage>>(AHistory), AStream]);
    end;
    Result := LResult.AsString;
  end
  else
    Result := '';
end;

function TTestRadIAProvidersEx.InvokeParseResponseBody(AProvider: TObject; const AJson: string;
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
  LMethod := LType.GetMethod('ParseBedrockResponse');
  if not Assigned(LMethod) then
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

procedure TTestRadIAProvidersEx.InvokeProcessStreamBuffer(AProvider: TObject; var ABuffer: string;
  const ACallback: TStreamChunkCallback);
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LParams: TArray<TValue>;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(AProvider.ClassType) as TRttiInstanceType;
  LMethod := LType.GetMethod('ProcessStreamBuffer');
  if not Assigned(LMethod) then
    LMethod := LType.GetMethod('ProcessOpenAICompatibleStreamBuffer');
  if Assigned(LMethod) then
  begin
    SetLength(LParams, 2);
    LParams[0] := ABuffer;
    LParams[1] := TValue.From<TStreamChunkCallback>(ACallback);
    LMethod.Invoke(AProvider, LParams);
    ABuffer := LParams[0].AsString;
  end
  else
    raise Exception.Create('ProcessStreamBuffer method not found via RTTI');
end;

procedure TTestRadIAProvidersEx.RunOpenAIPayloadTest(AProvider: TObject; const APrompt: string;
  const AHistoryQuery: string; const AMockResponse: string; const AExpectedModel: string;
  const AExpectedResponse: string; const AStream: Boolean;
  APromptTokens, ACompletionTokens, ATotalTokens: Integer);
var
  LPayload: string;
  LHistory: TArray<IRadIAChatMessage>;
  LJsonObj: TJSONObject;
  LMessages: TJSONArray;
  LText: string;
  LUsage: TTokenUsage;
begin
  LHistory := [TRadIAChatMessage.CreateMessage(mrUser, AHistoryQuery)];
  LPayload := InvokeBuildRequestBody(AProvider, APrompt, LHistory, AStream);

  Assert.IsNotEmpty(LPayload);
  LJsonObj := TJSONObject.ParseJSONValue(LPayload) as TJSONObject;
  try
    Assert.IsNotNull(LJsonObj);
    Assert.AreEqual(AExpectedModel, LJsonObj.GetValue('model').Value);

    if AStream then
      Assert.IsTrue(LJsonObj.GetValue<Boolean>('stream'))
    else
      Assert.IsNull(LJsonObj.GetValue('stream'));

    LMessages := LJsonObj.GetValue('messages') as TJSONArray;
    Assert.IsNotNull(LMessages);
    Assert.AreEqual(2, LMessages.Count);
  finally
    LJsonObj.Free;
  end;

  LText := InvokeParseResponseBody(AProvider, AMockResponse, LUsage);
  Assert.AreEqual(AExpectedResponse, LText);
  Assert.AreEqual(APromptTokens, LUsage.PromptTokens);
  Assert.AreEqual(ACompletionTokens, LUsage.CompletionTokens);
  Assert.AreEqual(ATotalTokens, LUsage.TotalTokens);
end;

procedure TTestRadIAProvidersEx.RunOpenAIStreamingTest(AProvider: TObject; const AInputBuffer: string;
  const AExpectedText: string; AExpectedCallbackCount: Integer);
var
  LBuffer: string;
  LReceivedText: string;
  LCallbackCount: Integer;
  LIsDone: Boolean;
begin
  LBuffer := AInputBuffer;
  LReceivedText := '';
  LCallbackCount := 0;
  LIsDone := False;

  InvokeProcessStreamBuffer(AProvider, LBuffer,
    procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
    begin
      Inc(LCallbackCount);
      if AIsDone then
        LIsDone := True
      else
        LReceivedText := LReceivedText + AChunk;
      Assert.IsEmpty(AError);
    end);

  Assert.AreEqual(AExpectedCallbackCount, LCallbackCount);
  Assert.AreEqual(AExpectedText, LReceivedText);
  Assert.IsTrue(LIsDone);
  Assert.IsEmpty(LBuffer);
end;

procedure TTestRadIAProvidersEx.TestDeepSeek_PayloadAndParsing;
const
  MOCK_DEEPSEEK_RESPONSE =
    '{"choices": [{"message": {"role": "assistant", "content": "DeepSeek response text"}}], ' +
    '"usage": {"prompt_tokens": 15, "completion_tokens": 25, "total_tokens": 40}}';
begin
  RunOpenAIPayloadTest(FDeepSeekProv, 'How is the weather?', 'DeepSeek Query',
    MOCK_DEEPSEEK_RESPONSE, 'deepseek-chat', 'DeepSeek response text', True, 15, 25, 40);
end;

procedure TTestRadIAProvidersEx.TestDeepSeek_StreamingSSE;
begin
  RunOpenAIStreamingTest(FDeepSeekProv,
    'data: {"choices":[{"delta":{"content":"Deep"}}]}' + #10 + 'data: {"choices":[{"delta":{"content' +
        '":"Seek"}}]}' + #10 + 'data: ' +
        '' +
        '[DONE]' + #10,
    'DeepSeek', 3);
end;

procedure TTestRadIAProvidersEx.TestGroq_PayloadAndParsing;
const
  MOCK_GROQ_RESPONSE =
    '{"choices": [{"message": {"role": "assistant", "content": "Groq response text"}}], ' +
    '"usage": {"prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30}}';
begin
  RunOpenAIPayloadTest(FGroqProv, 'Analyze this code', 'Groq Query',
    MOCK_GROQ_RESPONSE, 'llama-3.3-70b-versatile', 'Groq response text', False, 10, 20, 30);
end;

procedure TTestRadIAProvidersEx.TestGroq_StreamingSSE;
begin
  RunOpenAIStreamingTest(FGroqProv,
    'data: {"choices":[{"delta":{"content":"Gro"}}]}' + #10 + 'data: {"choices":[{"delta":{"content"' +
        ':"q"}}]}' + #10 + 'data: ' +
        '' +
        '[DONE]' + #10,
    'Groq', 3);
end;

procedure TTestRadIAProvidersEx.TestOpenRouter_PayloadAndParsing;
const
  MOCK_OPENROUTER_RESPONSE =
    '{"choices": [{"message": {"role": "assistant", "content": "OpenRouter response text"}}], ' +
    '"usage": {"prompt_tokens": 8, "completion_tokens": 12, "total_tokens": 20}}';
begin
  RunOpenAIPayloadTest(FOpenRouterProv, 'Hello', 'OpenRouter Query',
    MOCK_OPENROUTER_RESPONSE, 'google/gemini-2.5-pro', 'OpenRouter response text', True, 8, 12, 20);
end;

procedure TTestRadIAProvidersEx.TestOpenRouter_StreamingSSE;
begin
  RunOpenAIStreamingTest(FOpenRouterProv,
    'data: {"choices":[{"delta":{"content":"Open"}}]}' + #10 + 'data: {"choices":[{"delta":{"content' +
        '":"Router"}}]}' + #10 + 'data: ' +
        '' +
        '[DONE]' + #10,
    'OpenRouter', 3);
end;

procedure TTestRadIAProvidersEx.TestLMStudio_PayloadAndParsing;
const
  MOCK_LMSTUDIO_RESPONSE =
    '{"choices": [{"message": {"role": "assistant", "content": "LM Studio response text"}}], ' +
    '"usage": {"prompt_tokens": 12, "completion_tokens": 16, "total_tokens": 28}}';
begin
  RunOpenAIPayloadTest(FLMStudioProv, 'Test prompt', 'LM Studio Query',
    MOCK_LMSTUDIO_RESPONSE, 'lms-default', 'LM Studio response text', True, 12, 16, 28);
end;

procedure TTestRadIAProvidersEx.TestLMStudio_StreamingSSE;
begin
  RunOpenAIStreamingTest(FLMStudioProv,
    'data: {"choices":[{"delta":{"content":"LM"}}]}' + #10 + 'data: {"choices":[{"delta":{"content":" ' +
        'Studio"}}]}' + #10 + 'data: [DONE]' + #10,
    'LM Studio', 3);
end;

procedure TTestRadIAProvidersEx.TestAzureOpenAI_PayloadAndParsing;
const
  MOCK_AZURE_RESPONSE =
    '{"choices": [{"message": {"role": "assistant", "content": "Azure response text"}}], ' +
    '"usage": {"prompt_tokens": 5, "completion_tokens": 10, "total_tokens": 15}}';
begin
  FConfig.SetActiveModel('AzureOpenAI', 'gpt-4o');
  RunOpenAIPayloadTest(FAzureProv, 'Deploy application', 'Azure Query',
    MOCK_AZURE_RESPONSE, 'gpt-4o', 'Azure response text', True, 5, 10, 15);
end;

procedure TTestRadIAProvidersEx.TestAzureOpenAI_StreamingSSE;
begin
  RunOpenAIStreamingTest(FAzureProv,
    'data: {"choices":[{"delta":{"content":"Azure"}}]}' + #10 + 'data: {"choices":[{"delta":{"content":" ' +
        'OpenAI"}}]}' + #10 + 'data: [DONE]' + #10,
    'Azure OpenAI', 3);
end;

procedure TTestRadIAProvidersEx.TestQwen_PayloadAndParsing;
const
  MOCK_QWEN_RESPONSE =
    '{"choices": [{"message": {"role": "assistant", "content": "Qwen response text"}}], ' +
    '"usage": {"prompt_tokens": 12, "completion_tokens": 18, "total_tokens": 30}}';
begin
  RunOpenAIPayloadTest(FQwenProv, 'Write code', 'Qwen Query',
    MOCK_QWEN_RESPONSE, 'qwen2.5-coder-32b-instruct', 'Qwen response text', True, 12, 18, 30);
end;

procedure TTestRadIAProvidersEx.TestQwen_StreamingSSE;
begin
  RunOpenAIStreamingTest(FQwenProv,
    'data: {"choices":[{"delta":{"content":"Ali"}}]}' + #10 + 'data: {"choices":[{"delta":{"content"' +
        ':"baba"}}]}' + #10 + 'data: ' +
        '' +
        '[DONE]' + #10,
    'Alibaba', 3);
end;

procedure TTestRadIAProvidersEx.TestMistral_PayloadAndParsing;
const
  MOCK_MISTRAL_RESPONSE =
    '{"choices": [{"message": {"role": "assistant", "content": "Mistral response text"}}], ' +
    '"usage": {"prompt_tokens": 20, "completion_tokens": 15, "total_tokens": 35}}';
begin
  RunOpenAIPayloadTest(FMistralProv, 'Translate', 'Mistral Query',
    MOCK_MISTRAL_RESPONSE, 'codestral-latest', 'Mistral response text', True, 20, 15, 35);
end;

procedure TTestRadIAProvidersEx.TestMistral_StreamingSSE;
begin
  RunOpenAIStreamingTest(FMistralProv,
    'data: {"choices":[{"delta":{"content":"Mis"}}]}' + #10 + 'data: {"choices":[{"delta":{"content"' +
        ':"tral"}}]}' + #10 + 'data: ' +
        '' +
        '[DONE]' + #10,
    'Mistral', 3);
end;

procedure TTestRadIAProvidersEx.TestBedrock_PayloadAndParsing;
var
  LPayload: string;
  LHistory: TArray<IRadIAChatMessage>;
  LJsonObj: TJSONObject;
  LMessages: TJSONArray;
  LText: string;
  LUsage: TTokenUsage;
const
  MOCK_BEDROCK_RESPONSE =
    '{"content": [{"type": "text", "text": "Bedrock Claude response text"}], ' +
    '"usage": {"input_tokens": 14, "output_tokens": 26}}';
begin
  // 1. Test Payload Generation
  LHistory := [TRadIAChatMessage.CreateMessage(mrUser, 'Bedrock Query')];
  LPayload := InvokeBuildRequestBody(FBedrockProv, 'Code review this class', LHistory, False);

  Assert.IsNotEmpty(LPayload);
  LJsonObj := TJSONObject.ParseJSONValue(LPayload) as TJSONObject;
  try
    Assert.IsNotNull(LJsonObj);
    Assert.AreEqual('bedrock-2023-05-31', LJsonObj.GetValue('anthropic_version').Value);
    LMessages := LJsonObj.GetValue('messages') as TJSONArray;
    Assert.IsNotNull(LMessages);
    Assert.AreEqual(2, LMessages.Count);
  finally
    LJsonObj.Free;
  end;

  // 2. Test Response Parsing
  LText := InvokeParseResponseBody(FBedrockProv, MOCK_BEDROCK_RESPONSE, LUsage);
  Assert.AreEqual('Bedrock Claude response text', LText);
  Assert.AreEqual(14, LUsage.PromptTokens);
  Assert.AreEqual(26, LUsage.CompletionTokens);
  Assert.AreEqual(40, LUsage.TotalTokens);
end;

procedure TTestRadIAProvidersEx.TestBedrock_AwsSignerSigV4;
var
  LHeaders: TStringList;
  LReq: TAwsSignRequest;
const
  MOCK_DATE = '20260608T170000Z';
  MOCK_STAMP = '20260608';
  MOCK_ACCESS_KEY = 'AKIAIOSFODNN7EXAMPLE';
  MOCK_SECRET_KEY = 'wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY';
  MOCK_REGION = 'us-east-1';
  MOCK_SERVICE = 'bedrock';
  MOCK_METHOD = 'POST';
  MOCK_URI = '/model/anthropic.claude-v2/invoke';
  MOCK_PAYLOAD = '{"prompt":"hello"}';
begin
  LReq.AccessKeyId := MOCK_ACCESS_KEY;
  LReq.SecretAccessKey := MOCK_SECRET_KEY;
  LReq.Region := MOCK_REGION;
  LReq.Service := MOCK_SERVICE;
  LReq.Method := MOCK_METHOD;
  LReq.Uri := MOCK_URI;
  LReq.Payload := MOCK_PAYLOAD;
  LReq.AmzDate := MOCK_DATE;
  LReq.DateStamp := MOCK_STAMP;
  LReq.SessionToken := '';

  LHeaders := TAwsSigV4Signer.ComputeSignatureHeaders(LReq);
  try
    Assert.IsNotNull(LHeaders);
    Assert.AreEqual('application/json', LHeaders.Values['content-type']);
    Assert.AreEqual(MOCK_DATE, LHeaders.Values['x-amz-date']);
    Assert.IsNotEmpty(LHeaders.Values['x-amz-content-sha256']);
    Assert.IsNotEmpty(LHeaders.Values['Authorization']);
    Assert.IsTrue(LHeaders.Values['Authorization'].StartsWith(
      'AWS4-HMAC-SHA256 Credential=AKIAIOSFODNN7EXAMPLE/20260608/us-east-1/bedrock/aws4_request'));
  finally
    LHeaders.Free;
  end;

  // Test with session token
  LReq.SessionToken := 'session-token-123';
  LHeaders := TAwsSigV4Signer.ComputeSignatureHeaders(LReq);
  try
    Assert.AreEqual('session-token-123', LHeaders.Values['x-amz-security-token']);
    Assert.IsTrue(LHeaders.Values['Authorization'].Contains('x-amz-security-token'));
  finally
    LHeaders.Free;
  end;
end;

procedure TTestRadIAProvidersEx.TestBedrock_EventStreamParser;
  function CreateMockEventStreamFrame(const AText: string): TBytes;
  var
    LInnerJson: TJSONObject;
    LOuterJson: TJSONObject;
    LInnerStr: string;
    LOuterStr: string;
    LPayloadBytes: TBytes;
    LBase64: string;
    LTotalLength: Cardinal;
    LHeadersLength: Cardinal;
    LPayloadLen: Cardinal;
  begin
    LInnerJson := TJSONObject.Create;
    try
      LInnerJson.AddPair('type', 'content_block_delta');
      var LDelta := TJSONObject.Create;
      LDelta.AddPair('text', AText);
      LInnerJson.AddPair('delta', LDelta);
      LInnerStr := LInnerJson.ToJSON;
    finally
      LInnerJson.Free;
    end;

    LBase64 := TNetEncoding.Base64.EncodeBytesToString(TEncoding.UTF8.GetBytes(LInnerStr));
    LBase64 := LBase64.Replace(#13, '').Replace(#10, '');

    LOuterJson := TJSONObject.Create;
    try
      LOuterJson.AddPair('bytes', LBase64);
      LOuterStr := LOuterJson.ToJSON;
    finally
      LOuterJson.Free;
    end;

    LPayloadBytes := TEncoding.UTF8.GetBytes(LOuterStr);
    LPayloadLen := Length(LPayloadBytes);
    LHeadersLength := 0;
    LTotalLength := LPayloadLen + LHeadersLength + 16;

    SetLength(Result, LTotalLength);

    // Set total length (Big Endian)
    Result[0] := Byte((LTotalLength shl 0) shr 24);
    Result[1] := Byte((LTotalLength shl 8) shr 24);
    Result[2] := Byte((LTotalLength shl 16) shr 24);
    Result[3] := Byte((LTotalLength shl 24) shr 24);

    // Set headers length (0)
    Result[4] := 0;
    Result[5] := 0;
    Result[6] := 0;
    Result[7] := 0;

    // Prelude CRC (0)
    Result[8] := 0;
    Result[9] := 0;
    Result[10] := 0;
    Result[11] := 0;

    // Payload
    Move(LPayloadBytes[0], Result[12], LPayloadLen);

    // Message CRC (0)
    Result[LTotalLength - 4] := 0;
    Result[LTotalLength - 3] := 0;
    Result[LTotalLength - 2] := 0;
    Result[LTotalLength - 1] := 0;
  end;

var
  LParser: TRadIAAwsEventStreamParser;
  LChunk1, LChunk2: TBytes;
  LReceivedText: string;
  LCallbackCount: Integer;
begin
  LReceivedText := '';
  LCallbackCount := 0;

  LParser := TRadIAAwsEventStreamParser.Create(
    procedure(const AChunk: string; AIsDone: Boolean; const AError: string)
    begin
      Inc(LCallbackCount);
      LReceivedText := LReceivedText + AChunk;
      Assert.IsEmpty(AError);
    end
  );
  try
    LChunk1 := CreateMockEventStreamFrame('Claude ');
    LChunk2 := CreateMockEventStreamFrame('says hello!');

    // 1. Process first frame
    LParser.ProcessBytes(LChunk1);
    Assert.AreEqual('Claude ', LReceivedText);
    Assert.AreEqual(1, LCallbackCount);

    // 2. Process second frame
    LParser.ProcessBytes(LChunk2);
    Assert.AreEqual('Claude says hello!', LReceivedText);
    Assert.AreEqual(2, LCallbackCount);

    // 3. Process incremental bytes (simulate network fragmentation)
    LReceivedText := '';
    LCallbackCount := 0;
    var LFrame := CreateMockEventStreamFrame('Incremental!');
    var LHalf := Length(LFrame) div 2;
    var LPart1: TBytes;
    var LPart2: TBytes;
    SetLength(LPart1, LHalf);
    Move(LFrame[0], LPart1[0], LHalf);
    SetLength(LPart2, Length(LFrame) - LHalf);
    Move(LFrame[LHalf], LPart2[0], Length(LFrame) - LHalf);

    LParser.ProcessBytes(LPart1);
    Assert.AreEqual('', LReceivedText); // Shouldn't fire callback yet since frame is incomplete

    LParser.ProcessBytes(LPart2);
    Assert.AreEqual('Incremental!', LReceivedText); // Fires after second half arrives
    Assert.AreEqual(1, LCallbackCount);
  finally
    LParser.Free;
  end;
end;

procedure TTestRadIAProvidersEx.TestGithubCopilot_PayloadAndParsing;
const
  MOCK_COPILOT_RESPONSE =
    '{"choices": [{"message": {"role": "assistant", "content": "Copilot response text"}}], ' +
    '"usage": {"prompt_tokens": 10, "completion_tokens": 20, "total_tokens": 30}}';
begin
  RunOpenAIPayloadTest(FGithubCopilotProv, 'Fix this code', 'Copilot Query',
    MOCK_COPILOT_RESPONSE, 'gpt-4', 'Copilot response text', True, 10, 20, 30);
end;

procedure TTestRadIAProvidersEx.TestGithubCopilot_StreamingSSE;
begin
  RunOpenAIStreamingTest(FGithubCopilotProv,
    'data: {"choices":[{"delta":{"content":"Github"}}]}' + #10 +
    'data: {"choices":[{"delta":{"content":" Copilot"}}]}' + #10 +
    'data: [DONE]' + #10,
    'Github Copilot', 3);
end;

procedure TTestRadIAProvidersEx.RunProviderSendPromptAsyncTest(AProvider: IRadIAProvider;
  const AProviderId: string; const AMockResponse: string; const AExpectedResponse: string);
var
  LFinished: Boolean;
  LTimeout: Integer;
  LResponse: string;
  LError: string;
begin
  FConfig.SetApiKey(AProviderId, 'dummy-key');
  FMockHttpClient.SetResponse(AMockResponse);
  LFinished := False;
  LResponse := '';
  LError := '';
  FUsageResult := TTokenUsage.Empty;

  AProvider.SendPromptAsync('Test prompt', [],
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    begin
      LResponse := AResponse;
      LError := AError;
      FUsageResult := AUsage;
      LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LFinished, 'Async request timed out for ' + AProviderId);
  Assert.AreEqual(AExpectedResponse, LResponse);
  Assert.IsEmpty(LError);
  if AProviderId = 'Gemini' then
    Assert.IsTrue(FMockHttpClient.LastUrl.Contains(':generateContent'))
  else if AProviderId = 'Claude' then
    Assert.IsTrue(FMockHttpClient.LastUrl.Contains('/v1/messages'))
  else if AProviderId = 'Ollama' then
    Assert.IsTrue(FMockHttpClient.LastUrl.Contains('/api/chat'))
  else if AProviderId = 'Bedrock' then
    Assert.IsTrue(FMockHttpClient.LastUrl.Contains('/invoke'))
  else
    Assert.IsTrue(FMockHttpClient.LastUrl.Contains('/chat/completions'));
  Sleep(50);
  System.Classes.CheckSynchronize(50);
end;

procedure TTestRadIAProvidersEx.RunProviderSendPromptStreamAsyncTest(AProvider: IRadIAProvider;
  const AProviderId: string; const AStreamChunks: TArray<string>; const AExpectedText: string);
var
  LFinished: Boolean;
  LTimeout: Integer;
  LText: string;
  LError: string;
begin
  FConfig.SetApiKey(AProviderId, 'dummy-key');
  FMockHttpClient.SetStreamChunks(AStreamChunks);
  LFinished := False;
  LText := '';
  LError := '';

  AProvider.SendPromptStreamAsync('Test prompt', [],
    procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
    begin
      LText := LText + AChunk;
      LError := AError;
      if AIsDone then
        LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LFinished, 'Async stream request timed out for ' + AProviderId);
  Assert.AreEqual(AExpectedText, LText);
  Assert.IsEmpty(LError);
  Sleep(50);
  System.Classes.CheckSynchronize(50);
end;

// TestWebViewBridge_Workflow removed as WebViewBridge is deprecated.

{ TMockHttpClient }

procedure TMockHttpClient.SetResponse(const AResponse: string);
begin
  FResponseStr := AResponse;
  FStatusCodeToThrow := 0;
end;

procedure TMockHttpClient.SetStreamChunks(const AChunks: TArray<string>);
begin
  FStreamChunks := AChunks;
  FStatusCodeToThrow := 0;
end;

procedure TMockHttpClient.SetErrorResponse(const AStatusCode: Integer; const AContent: string);
begin
  FStatusCodeToThrow := AStatusCode;
  FErrorContentToThrow := AContent;
end;

function TMockHttpClient.Get(const AUrl: string; const AHeaders: TNetHeaders; const ATimeoutMs: Integer = 0): string;
begin
  FLastUrl := AUrl;
  if FStatusCodeToThrow <> 0 then
  begin
    if FStatusCodeToThrow = -2 then
      raise ENetHTTPClientException.Create(FErrorContentToThrow)
    else if FStatusCodeToThrow < 0 then
      raise Exception.Create(FErrorContentToThrow)
    else
      raise ERadIAHttpException.Create('Mock HTTP Error', FStatusCodeToThrow, FErrorContentToThrow);
  end;

  if AUrl.Contains('/copilot_internal/v2/token') then
    Result := '{"token": "mock-gh-session-token", "refresh_in": 1800}'
  else
    Result := FResponseStr;
end;

function TMockHttpClient.Post(const AUrl: string; const AHeaders: TNetHeaders;
  const ARequestBody: string; const ATimeoutMs: Integer = 0): string;
begin
  FLastUrl := AUrl;
  if FStatusCodeToThrow <> 0 then
  begin
    if FStatusCodeToThrow = -2 then
      raise ENetHTTPClientException.Create(FErrorContentToThrow)
    else if FStatusCodeToThrow < 0 then
      raise Exception.Create(FErrorContentToThrow)
    else
      raise ERadIAHttpException.Create('Mock HTTP Error', FStatusCodeToThrow, FErrorContentToThrow);
  end;

  Result := FResponseStr;
end;

procedure TMockHttpClient.PostStream(const AUrl: string; const AHeaders: TNetHeaders; const ARequestBody: string;
  const AOnWrite: TProc<TBytes>; const ATimeoutMs: Integer = 0);
var
  LChunk: string;
  LBytes: TBytes;
begin
  FLastUrl := AUrl;
  FCancelled := False;

  for LChunk in FStreamChunks do
  begin
    if FCancelled then
      Break;

    if AUrl.Contains('bedrock') then
      LBytes := TNetEncoding.Base64.DecodeStringToBytes(LChunk)
    else
      LBytes := TEncoding.UTF8.GetBytes(LChunk);
    AOnWrite(LBytes);
    Sleep(5);
  end;

  if FCancelled then
    raise ENetHTTPClientException.Create('Request cancelled');

  if FStatusCodeToThrow <> 0 then
  begin
    if FStatusCodeToThrow = -2 then
      raise ENetHTTPClientException.Create(FErrorContentToThrow)
    else if FStatusCodeToThrow < 0 then
      raise Exception.Create(FErrorContentToThrow)
    else
      raise ERadIAHttpException.Create('Mock HTTP Error', FStatusCodeToThrow, FErrorContentToThrow);
  end;
end;

procedure TMockHttpClient.Cancel;
begin
  FCancelled := True;
end;

procedure TTestRadIAProvidersEx.TestLMStudio_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FLMStudioProvRef, 'LMStudio',
    '{"choices": [{"message": {"role": "assistant", "content": "LM Studio response text"}}], ' +
    '"usage": {"prompt_tokens": 12, "completion_tokens": 16, "total_tokens": 28}}',
    'LM Studio response text');
end;

procedure TTestRadIAProvidersEx.TestLMStudio_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FLMStudioProvRef, 'LMStudio', [
    'data: {"choices":[{"delta":{"content":"LM"}}]}' + #10,
    'data: {"choices":[{"delta":{"content":" Studio"}}]}' + #10,
    'data: [DONE]' + #10
  ], 'LM Studio');
end;

procedure TTestRadIAProvidersEx.TestAzureOpenAI_SendPromptAsync;
begin
  FConfig.SetActiveModel('AzureOpenAI', 'gpt-4o');
  FConfig.SetProviderBaseUrl('AzureOpenAI', 'https://my-azure.openai.azure.com/');
  RunProviderSendPromptAsyncTest(FAzureProvRef, 'AzureOpenAI',
    '{"choices": [{"message": {"role": "assistant", "content": "Azure OpenAI response"}}], ' +
    '"usage": {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20}}',
    'Azure OpenAI response');
end;

procedure TTestRadIAProvidersEx.TestAzureOpenAI_SendPromptStreamAsync;
begin
  FConfig.SetActiveModel('AzureOpenAI', 'gpt-4o');
  FConfig.SetProviderBaseUrl('AzureOpenAI', 'https://my-azure.openai.azure.com/');
  RunProviderSendPromptStreamAsyncTest(FAzureProvRef, 'AzureOpenAI', [
    'data: {"choices":[{"delta":{"content":"Azure"}}]}' + #10,
    'data: {"choices":[{"delta":{"content":" OpenAI"}}]}' + #10,
    'data: [DONE]' + #10
  ], 'Azure OpenAI');
end;

procedure TTestRadIAProvidersEx.TestGithubCopilot_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FGithubCopilotProvRef, 'GithubCopilot',
    '{"choices": [{"message": {"role": "assistant", "content": "Copilot response"}}], ' +
    '"usage": {"prompt_tokens": 15, "completion_tokens": 15, "total_tokens": 30}}',
    'Copilot response');
end;

procedure TTestRadIAProvidersEx.TestGithubCopilot_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FGithubCopilotProvRef, 'GithubCopilot', [
    'data: {"choices":[{"delta":{"content":"Github"}}]}' + #10,
    'data: {"choices":[{"delta":{"content":" Copilot"}}]}' + #10,
    'data: [DONE]' + #10
  ], 'Github Copilot');
end;

procedure TTestRadIAProvidersEx.TestDeepSeek_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FDeepSeekProvRef, 'DeepSeek',
    '{"choices": [{"message": {"role": "assistant", "content": "DeepSeek response"}}], ' +
    '"usage": {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20}}',
    'DeepSeek response');
end;

procedure TTestRadIAProvidersEx.TestDeepSeek_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FDeepSeekProvRef, 'DeepSeek', [
    'data: {"choices":[{"delta":{"content":"Deep"}}]}' + #10,
    'data: {"choices":[{"delta":{"content":"Seek"}}]}' + #10,
    'data: [DONE]' + #10
  ], 'DeepSeek');
end;

procedure TTestRadIAProvidersEx.TestGroq_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FGroqProvRef, 'Groq',
    '{"choices": [{"message": {"role": "assistant", "content": "Groq response"}}], ' +
    '"usage": {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20}}',
    'Groq response');
end;

procedure TTestRadIAProvidersEx.TestGroq_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FGroqProvRef, 'Groq', [
    'data: {"choices":[{"delta":{"content":"Gro"}}]}' + #10,
    'data: {"choices":[{"delta":{"content":"q"}}]}' + #10,
    'data: [DONE]' + #10
  ], 'Groq');
end;

procedure TTestRadIAProvidersEx.TestOpenRouter_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FOpenRouterProvRef, 'OpenRouter',
    '{"choices": [{"message": {"role": "assistant", "content": "OpenRouter response"}}], ' +
    '"usage": {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20}}',
    'OpenRouter response');
end;

procedure TTestRadIAProvidersEx.TestOpenRouter_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FOpenRouterProvRef, 'OpenRouter', [
    'data: {"choices":[{"delta":{"content":"Open"}}]}' + #10,
    'data: {"choices":[{"delta":{"content":"Router"}}]}' + #10,
    'data: [DONE]' + #10
  ], 'OpenRouter');
end;

procedure TTestRadIAProvidersEx.TestQwen_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FQwenProvRef, 'Qwen',
    '{"choices": [{"message": {"role": "assistant", "content": "Qwen response"}}], ' +
    '"usage": {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20}}',
    'Qwen response');
end;

procedure TTestRadIAProvidersEx.TestQwen_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FQwenProvRef, 'Qwen', [
    'data: {"choices":[{"delta":{"content":"Ali"}}]}' + #10,
    'data: {"choices":[{"delta":{"content":"baba"}}]}' + #10,
    'data: [DONE]' + #10
  ], 'Alibaba');
end;

procedure TTestRadIAProvidersEx.TestMistral_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FMistralProvRef, 'Mistral',
    '{"choices": [{"message": {"role": "assistant", "content": "Mistral response"}}], ' +
    '"usage": {"prompt_tokens": 10, "completion_tokens": 10, "total_tokens": 20}}',
    'Mistral response');
end;

procedure TTestRadIAProvidersEx.TestMistral_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FMistralProvRef, 'Mistral', [
    'data: {"choices":[{"delta":{"content":"Mis"}}]}' + #10,
    'data: {"choices":[{"delta":{"content":"tral"}}]}' + #10,
    'data: [DONE]' + #10
  ], 'Mistral');
end;

procedure TTestRadIAProvidersEx.TestGemini_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FGeminiProvRef, 'Gemini',
    '{"candidates": [{"content": {"parts": [{"text": "Gemini response"}]}}], ' +
    '"usageMetadata": {"promptTokenCount": 10, "candidatesTokenCount": 10, "totalTokenCount": 20}}',
    'Gemini response');
end;

procedure TTestRadIAProvidersEx.TestGemini_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FGeminiProvRef, 'Gemini', [
    '[{"candidates":[{"content":{"parts":[{"text":"Gem"}]}}], ' +
    '"usageMetadata": {"promptTokenCount": 5, "candidatesTokenCount": 5, "totalTokenCount": 10}}' + #10,
    ',{"candidates":[{"content":{"parts":[{"text":"ini"}]}}], ' +
    '"usageMetadata": {"promptTokenCount": 5, "candidatesTokenCount": 5, "totalTokenCount": 10}}' + #10,
    ']' + #10
  ], 'Gemini');
end;

procedure TTestRadIAProvidersEx.TestClaude_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FClaudeProvRef, 'Claude',
    '{"content": [{"type": "text", "text": "Claude response"}], ' +
    '"usage": {"input_tokens": 10, "output_tokens": 10}}',
    'Claude response');
end;

procedure TTestRadIAProvidersEx.TestClaude_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FClaudeProvRef, 'Claude', [
    'data: {"type":"content_block_delta","delta":{"text":"Cla"}}' + #10,
    'data: {"type":"content_block_delta","delta":{"text":"ude"}}' + #10,
    'data: {"type":"message_stop"}' + #10
  ], 'Claude');
end;

procedure TTestRadIAProvidersEx.TestOllama_SendPromptAsync;
begin
  RunProviderSendPromptAsyncTest(FOllamaProvRef, 'Ollama',
    '{"message": {"content": "Ollama response"}, ' +
    '"prompt_eval_count": 10, "eval_count": 10}',
    'Ollama response');
end;

procedure TTestRadIAProvidersEx.TestOllama_SendPromptStreamAsync;
begin
  RunProviderSendPromptStreamAsyncTest(FOllamaProvRef, 'Ollama', [
    '{"message":{"content":"Olla"},"done":false}' + #10,
    '{"message":{"content":"ma"},"done":false}' + #10,
    '{"done":true}' + #10
  ], 'Ollama');
end;

procedure TTestRadIAProvidersEx.TestBedrock_SendPromptAsync;
begin
  FConfig.SetAwsAccessKeyId('dummy');
  FConfig.SetAwsSecretAccessKey('dummy');
  FConfig.SetAwsRegion('us-east-1');
  RunProviderSendPromptAsyncTest(FBedrockProvRef, 'Bedrock',
    '{"content": [{"type": "text", "text": "Bedrock response"}], ' +
    '"usage": {"input_tokens": 10, "output_tokens": 10}}',
    'Bedrock response');
end;

procedure TTestRadIAProvidersEx.TestBedrock_SendPromptStreamAsync;
  function CreateMockFrameB64(const AText: string): string;
  var
    LInnerJson: TJSONObject;
    LOuterJson: TJSONObject;
    LInnerStr: string;
    LOuterStr: string;
    LPayloadBytes: TBytes;
    LBase64: string;
    LTotalLength: Cardinal;
    LHeadersLength: Cardinal;
    LPayloadLen: Cardinal;
    LFrameBytes: TBytes;
  begin
    LInnerJson := TJSONObject.Create;
    try
      LInnerJson.AddPair('type', 'content_block_delta');
      var LDelta := TJSONObject.Create;
      LDelta.AddPair('text', AText);
      LInnerJson.AddPair('delta', LDelta);
      LInnerStr := LInnerJson.ToJSON;
    finally
      LInnerJson.Free;
    end;

    LBase64 := TNetEncoding.Base64.EncodeBytesToString(TEncoding.UTF8.GetBytes(LInnerStr));
    LBase64 := LBase64.Replace(#13, '').Replace(#10, '');

    LOuterJson := TJSONObject.Create;
    try
      LOuterJson.AddPair('bytes', LBase64);
      LOuterStr := LOuterJson.ToJSON;
    finally
      LOuterJson.Free;
    end;

    LPayloadBytes := TEncoding.UTF8.GetBytes(LOuterStr);
    LPayloadLen := Length(LPayloadBytes);
    LHeadersLength := 0;
    LTotalLength := LPayloadLen + LHeadersLength + 16;

    SetLength(LFrameBytes, LTotalLength);
    LFrameBytes[0] := Byte((LTotalLength shl 0) shr 24);
    LFrameBytes[1] := Byte((LTotalLength shl 8) shr 24);
    LFrameBytes[2] := Byte((LTotalLength shl 16) shr 24);
    LFrameBytes[3] := Byte((LTotalLength shl 24) shr 24);
    LFrameBytes[4] := 0;
    LFrameBytes[5] := 0;
    LFrameBytes[6] := 0;
    LFrameBytes[7] := 0;
    LFrameBytes[8] := 0;
    LFrameBytes[9] := 0;
    LFrameBytes[10] := 0;
    LFrameBytes[11] := 0;
    Move(LPayloadBytes[0], LFrameBytes[12], LPayloadLen);
    LFrameBytes[LTotalLength - 4] := 0;
    LFrameBytes[LTotalLength - 3] := 0;
    LFrameBytes[LTotalLength - 2] := 0;
    LFrameBytes[LTotalLength - 1] := 0;

    Result := TNetEncoding.Base64.EncodeBytesToString(LFrameBytes);
    Result := Result.Replace(#13, '').Replace(#10, '');
  end;
begin
  FConfig.SetAwsAccessKeyId('dummy');
  FConfig.SetAwsSecretAccessKey('dummy');
  FConfig.SetAwsRegion('us-east-1');

  RunProviderSendPromptStreamAsyncTest(FBedrockProvRef, 'Bedrock', [
    CreateMockFrameB64('Bedrock '),
    CreateMockFrameB64('response')
  ], 'Bedrock response');
end;

procedure TTestRadIAProvidersEx.TestProviderBase_HttpExceptionsPart1;
var
  LFinished: Boolean;
  LTimeout: Integer;
begin
  // 1. Testar ExtractErrorMessageFromJson e exceptions do HTTPClient no Gemini
  FMockHttpClient.SetErrorResponse(500, '{invalid-json-error-response');
  LFinished := False;
  FGeminiProvRef.SendPromptAsync('Test prompt', [],
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    begin
      LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  // 2. Testar ProcessOpenAICompatibleStreamBuffer exception no OpenAI/DeepSeek
  FMockHttpClient.SetStreamChunks(['data: {invalid-json-chunk-data']);
  LFinished := False;
  FDeepSeekProvRef.SendPromptStreamAsync('Test prompt', [],
    procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
    begin
      if AIsDone or (not AError.IsEmpty) then
        LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;
end;

procedure TTestRadIAProvidersEx.TestProviderBase_HttpExceptionsPart2;
var
  LFinished: Boolean;
  LTimeout: Integer;
begin
  // 3. Testar exception de parsing no Ollama stream
  FMockHttpClient.SetStreamChunks(['{invalid-ollama-json']);
  LFinished := False;
  FOllamaProvRef.SendPromptStreamAsync('Test prompt', [],
    procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
    begin
      if AIsDone or (not AError.IsEmpty) then
        LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  // 4. Testar ENetHTTPClientException e ExtractErrorMessageFromJson no stream
  FMockHttpClient.SetStreamChunks(['{invalid-json-error-response']);
  FMockHttpClient.SetErrorResponse(-2, 'Connection dropped');
  LFinished := False;
  FDeepSeekProvRef.SendPromptStreamAsync('Test prompt', [],
    procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
    begin
      if AIsDone or (not AError.IsEmpty) then
        LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  // 5. Testar exception de parsing no Claude stream
  FMockHttpClient.SetStreamChunks(['data: {invalid-claude-json']);
  LFinished := False;
  FClaudeProvRef.SendPromptStreamAsync('Test prompt', [],
    procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
    begin
      if AIsDone or (not AError.IsEmpty) then
        LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;
end;

procedure TTestRadIAProvidersEx.TestOllama_FetchAvailableModels;
var
  LFinished: Boolean;
  LTimeout: Integer;
  LModels: TArray<string>;
  LError: string;
begin
  FConfig.SetOllamaBaseUrl('http://127.0.0.1:11434');

  // Case 1: Success with valid models JSON
  FMockHttpClient.SetResponse('{"models": [{"name": "llama3:latest"}, {"name": "phi3:latest"}]}');
  LFinished := False;
  LModels := [];
  LError := '';

  (FOllamaProvRef as TRadIAOllamaProvider).FetchAvailableModelsAsync(
    procedure(AModels: TArray<string>; AError: string)
    begin
      LModels := AModels;
      LError := AError;
      LFinished := True;
    end);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LFinished, 'Fetch should have finished');
  Assert.AreEqual(2, Integer(Length(LModels)));
  Assert.AreEqual('llama3:latest', LModels[0]);
  Assert.AreEqual('phi3:latest', LModels[1]);
  Assert.IsTrue(LError.IsEmpty);

  // Case 2: Network failure to cover DoGetRequest except
  FMockHttpClient.SetErrorResponse(-1, 'Connection refused');
  LFinished := False;
  LModels := [];
  LError := '';

  (FOllamaProvRef as TRadIAOllamaProvider).FetchAvailableModelsAsync(
    procedure(AModels: TArray<string>; AError: string)
    begin
      LModels := AModels;
      LError := AError;
      LFinished := True;
    end);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LFinished, 'Fetch should have finished with error');
  Assert.IsTrue(Length(LModels) > 0);
  Assert.IsFalse(LError.IsEmpty);
end;

procedure TTestRadIAProvidersEx.TestGithubCopilot_HttpExceptions;
var
  LFinished: Boolean;
  LTimeout: Integer;
begin
  FConfig.SetApiKey('GithubCopilot', 'ghu_dummy_token');

  // Case 1: ERadIAHttpException on EnsureSessionToken
  TRadIAGithubCopilotProvider.ClearSessionToken;

  FMockHttpClient.SetErrorResponse(401, '{"error": "Unauthorized Copilot Key"}');
  LFinished := False;
  FGithubCopilotProvRef.SendPromptAsync('Test prompt', [],
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    begin
      LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  // Case 2: Generic Exception on EnsureSessionToken
  TRadIAGithubCopilotProvider.ClearSessionToken;

  FMockHttpClient.SetErrorResponse(-1, 'Generic network failure');
  LFinished := False;
  FGithubCopilotProvRef.SendPromptAsync('Test prompt', [],
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    begin
      LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;
end;

function TTestRadIAProvidersEx.InvokeGetBaseUrl(AProvider: TObject): string;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LResult: TValue;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(AProvider.ClassType) as TRttiInstanceType;
  LMethod := LType.GetMethod('GetBaseUrl');
  if Assigned(LMethod) then
  begin
    LResult := LMethod.Invoke(AProvider, []);
    Result := LResult.AsString;
  end
  else
    Result := '';
end;

function TTestRadIAProvidersEx.InvokeGetModelsDiscoveryUrl(AProvider: TObject): string;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LResult: TValue;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(AProvider.ClassType) as TRttiInstanceType;
  LMethod := LType.GetMethod('GetModelsDiscoveryUrl');
  if Assigned(LMethod) then
  begin
    LResult := LMethod.Invoke(AProvider, []);
    Result := LResult.AsString;
  end
  else
    Result := '';
end;

function TTestRadIAProvidersEx.InvokeFilterModelId(AProvider: TObject; const AModelId: string): Boolean;
var
  LContext: TRttiContext;
  LType: TRttiInstanceType;
  LMethod: TRttiMethod;
  LResult: TValue;
begin
  LContext := TRttiContext.Create;
  LType := LContext.GetType(AProvider.ClassType) as TRttiInstanceType;
  LMethod := LType.GetMethod('FilterModelId');
  if Assigned(LMethod) then
  begin
    LResult := LMethod.Invoke(AProvider, [AModelId]);
    Result := LResult.AsBoolean;
  end
  else
    Result := True;
end;

procedure TTestRadIAProvidersEx.TestProvidersDiscoveryAndFiltering;
var
  LOpenAI: TRadIAOpenAIProvider;
begin
  // 1. OpenAI
  LOpenAI := TRadIAOpenAIProvider.Create(FConfig);
  try
    FConfig.OpenAICustomBaseUrl := '';
    Assert.AreEqual('https://api.openai.com/v1', InvokeGetBaseUrl(LOpenAI));
    Assert.AreEqual(
      'https://api.openai.com/v1/models',
      InvokeGetModelsDiscoveryUrl(LOpenAI)
    );
    Assert.IsTrue(InvokeFilterModelId(LOpenAI, 'gpt-4o'));
    Assert.IsTrue(InvokeFilterModelId(LOpenAI, 'o1-mini'));
    Assert.IsFalse(InvokeFilterModelId(LOpenAI, 'claude-3'));

    FConfig.OpenAICustomBaseUrl := 'https://custom-openai.com/';
    Assert.AreEqual('https://custom-openai.com', InvokeGetBaseUrl(LOpenAI));
    Assert.AreEqual(
      'https://custom-openai.com/models',
      InvokeGetModelsDiscoveryUrl(LOpenAI)
    );
  finally
    LOpenAI.Free;
  end;

  // 2. DeepSeek
  Assert.AreEqual('https://api.deepseek.com', InvokeGetBaseUrl(FDeepSeekProv));
  Assert.AreEqual(
    'https://api.deepseek.com/models',
    InvokeGetModelsDiscoveryUrl(FDeepSeekProv)
  );
  Assert.IsTrue(InvokeFilterModelId(FDeepSeekProv, 'deepseek-chat'));

  // 3. Groq
  Assert.AreEqual('https://api.groq.com/openai/v1', InvokeGetBaseUrl(FGroqProv));
  Assert.AreEqual(
    'https://api.groq.com/openai/v1/models',
    InvokeGetModelsDiscoveryUrl(FGroqProv)
  );
  Assert.IsTrue(InvokeFilterModelId(FGroqProv, 'llama3-8b'));
  Assert.IsTrue(InvokeFilterModelId(FGroqProv, 'mixtral-8x7b'));
  Assert.IsFalse(InvokeFilterModelId(FGroqProv, 'gpt-4'));

  // 4. OpenRouter
  Assert.AreEqual('https://openrouter.ai/api/v1', InvokeGetBaseUrl(FOpenRouterProv));
  Assert.AreEqual(
    'https://openrouter.ai/api/v1/models',
    InvokeGetModelsDiscoveryUrl(FOpenRouterProv)
  );

  // 5. Qwen
  Assert.AreEqual(
    'https://dashscope.aliyuncs.com/compatible-mode/v1',
    InvokeGetBaseUrl(FQwenProv)
  );
  Assert.AreEqual(
    'https://dashscope.aliyuncs.com/compatible-mode/v1/models',
    InvokeGetModelsDiscoveryUrl(FQwenProv)
  );

  // 6. Mistral
  Assert.AreEqual('https://api.mistral.ai/v1', InvokeGetBaseUrl(FMistralProv));
  Assert.AreEqual(
    'https://api.mistral.ai/v1/models',
    InvokeGetModelsDiscoveryUrl(FMistralProv)
  );

  // 7. LMStudio (com e sem custom base URL)
  FConfig.SetProviderBaseUrl('LMStudio', '');
  Assert.AreEqual('http://localhost:1234/v1', InvokeGetBaseUrl(FLMStudioProv));
  FConfig.SetProviderBaseUrl('LMStudio', 'http://custom-lms:1234/v1/');
  Assert.AreEqual('http://custom-lms:1234/v1/', InvokeGetBaseUrl(FLMStudioProv));

  // 8. AzureOpenAI (com e sem custom base URL)
  FConfig.SetProviderBaseUrl('AzureOpenAI', 'https://my-azure.openai.azure.com');
  Assert.AreEqual('https://my-azure.openai.azure.com', InvokeGetBaseUrl(FAzureProv));
end;

procedure TTestRadIAProvidersEx.TestGemini_FetchAvailableModels;
var
  LFinished: Boolean;
  LTimeout: Integer;
  LModels: TArray<string>;
  LError: string;
begin
  FConfig.SetApiKey('Gemini', 'dummy-gemini-key');

  // Case 1: Success with valid models JSON and support for generateContent
  FMockHttpClient.SetResponse(
    '{"models": [' +
    '  {"name": "models/gemini-1.5-flash", "supportedGenerationMethods": ["generateContent"]},' +
    '  {"name": "models/gemini-1.5-pro", "supportedGenerationMethods": ["generateContent"]},' +
    '  {"name": "models/other-model", "supportedGenerationMethods": ["otherMethod"]}' +
    ']}'
  );
  LFinished := False;
  LModels := [];
  LError := '';

  FGeminiProvRef.FetchAvailableModelsAsync(
    procedure(AModels: TArray<string>; AError: string)
    begin
      LModels := AModels;
      LError := AError;
      LFinished := True;
    end);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LFinished, 'Gemini Fetch should have finished');
  Assert.AreEqual(2, Integer(Length(LModels)));
  Assert.AreEqual('gemini-1.5-flash', LModels[0]);
  Assert.AreEqual('gemini-1.5-pro', LModels[1]);
  Assert.IsTrue(LError.IsEmpty);

  // Case 2: Error when API Key is empty
  FConfig.SetApiKey('Gemini', '');
  LFinished := False;
  LModels := [];
  LError := '';

  FGeminiProvRef.FetchAvailableModelsAsync(
    procedure(AModels: TArray<string>; AError: string)
    begin
      LModels := AModels;
      LError := AError;
      LFinished := True;
    end);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LFinished, 'Gemini Fetch should have finished with empty key');
  Assert.IsTrue(Length(LModels) > 0);
  Assert.IsFalse(LError.IsEmpty);

  // Case 3: Network failure to cover DoGetRequest except
  FConfig.SetApiKey('Gemini', 'dummy-gemini-key');
  FMockHttpClient.SetErrorResponse(-1, 'Connection refused');
  LFinished := False;
  LModels := [];
  LError := '';

  FGeminiProvRef.FetchAvailableModelsAsync(
    procedure(AModels: TArray<string>; AError: string)
    begin
      LModels := AModels;
      LError := AError;
      LFinished := True;
    end);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LFinished, 'Gemini Fetch should have finished with network error');
  Assert.IsTrue(Length(LModels) > 0);
  Assert.IsFalse(LError.IsEmpty);
end;

procedure TTestRadIAProvidersEx.TestProviderBase_ErrorParsing;
var
  LFinished: Boolean;
  LTimeout: Integer;
  LError: string;
begin
  // Caso 1: {"error": {"message": "API Error MSG 1"}}
  FConfig.SetApiKey('Gemini', 'dummy-key');
  FMockHttpClient.SetErrorResponse(500, '{"error": {"message": "API Error MSG 1"}}');
  LFinished := False;
  LError := '';

  FGeminiProvRef.SendPromptAsync('Test', [],
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    begin
      LError := AError;
      LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LError.Contains('API Error MSG 1'));

  // Caso 2: {"error": "API Error MSG 2"}
  FMockHttpClient.SetErrorResponse(500, '{"error": "API Error MSG 2"}');
  LFinished := False;
  LError := '';

  FGeminiProvRef.SendPromptAsync('Test', [],
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    begin
      LError := AError;
      LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LError.Contains('API Error MSG 2'));

  // Caso 3: {"message": "API Error MSG 3"}
  FMockHttpClient.SetErrorResponse(500, '{"message": "API Error MSG 3"}');
  LFinished := False;
  LError := '';

  FGeminiProvRef.SendPromptAsync('Test', [],
    procedure(const AResponse: string; const AError: string; AFromCache: Boolean; const AUsage: TTokenUsage)
    begin
      LError := AError;
      LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LError.Contains('API Error MSG 3'));
end;

procedure TTestRadIAProvidersEx.TestProviderBase_CancellationAndTimeout;
var
  LFinished: Boolean;
  LTimeout: Integer;
  LChunks: TArray<string>;
  LText: string;
begin
  FConfig.SetApiKey('DeepSeek', 'dummy-key');
  LChunks := [
    'data: {"choices":[{"delta":{"content":"Chunk 1"}}]}' + #10,
    'data: {"choices":[{"delta":{"content":"Chunk 2"}}]}' + #10,
    'data: [DONE]' + #10
  ];
  FMockHttpClient.SetStreamChunks(LChunks);

  LFinished := False;
  LText := '';

  FDeepSeekProvRef.SendPromptStreamAsync('Test', [],
    procedure(const AChunk: string; const AIsDone: Boolean; const AError: string)
    begin
      LText := LText + AChunk;

      // Dispara o cancelamento após receber o primeiro chunk
      if not LText.IsEmpty then
      begin
        FDeepSeekProvRef.CancelCurrentRequest;
      end;

      if AIsDone or (not AError.IsEmpty) then
        LFinished := True;
    end, 0.7, 100);

  LTimeout := 0;
  while (not LFinished) and (LTimeout < 2000) do
  begin
    Sleep(10);
    Inc(LTimeout, 10);
    System.Classes.CheckSynchronize(10);
  end;

  Assert.IsTrue(LFinished);
  Assert.IsTrue(LText.Contains('Chunk 1'));
  Assert.IsFalse(LText.Contains('Chunk 2'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAProvidersEx);

end.
