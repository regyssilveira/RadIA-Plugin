unit RadIA.Core.Types;

interface

type
  { Enum representing the message role in chat conversations }
  TAIMessageRole = (mrUser, mrAssistant, mrSystem);

  { Enum representing the AI request profiles for dynamic configuration }
  TAIRequestProfile = (rpGeneralChat, rpExplainCode, rpRefactorCode, rpFindBugs, rpGenerateTests, rpOptimizeSQL,
      rpScanWarnings);

const
  { Current fallback models for Google Gemini }
  MODEL_GEMINI_36_FLASH      = 'gemini-3.6-flash';
  MODEL_GEMINI_35_FLASH      = 'gemini-3.5-flash';
  MODEL_GEMINI_35_FLASH_LITE = 'gemini-3.5-flash-lite';

  { Standard models for OpenAI }
  MODEL_OPENAI_GPT56_SOL   = 'gpt-5.6-sol';
  MODEL_OPENAI_GPT56_TERRA = 'gpt-5.6-terra';
  MODEL_OPENAI_GPT56_LUNA  = 'gpt-5.6-luna';
  { Current fallback models for Anthropic Claude }
  MODEL_CLAUDE_FABLE_5  = 'claude-fable-5';
  MODEL_CLAUDE_OPUS_5   = 'claude-opus-5';
  MODEL_CLAUDE_SONNET_5 = 'claude-sonnet-5';

  { Standard models for DeepSeek }
  MODEL_DEEPSEEK_CHAT      = 'deepseek-chat';
  MODEL_DEEPSEEK_REASONING = 'deepseek-reasoning';

  { Standard models for Groq }
  MODEL_GROQ_LLAMA33       = 'llama-3.3-70b-versatile';
  MODEL_GROQ_MIXTRAL       = 'mixtral-8x7b-32768';
  MODEL_GROQ_GEMMA2        = 'gemma2-9b-it';

  { Standard models for OpenRouter }
  MODEL_OPENROUTER_GEMINI25_PRO = 'google/gemini-2.5-pro';
  MODEL_OPENROUTER_LLAMA33      = 'meta-llama/llama-3.3-70b-instruct';
  MODEL_OPENROUTER_DEEPSEEK_R1  = 'deepseek/deepseek-r1';

  { Standard models for Alibaba Qwen }
  MODEL_QWEN_25_CODER_32B = 'qwen2.5-coder-32b-instruct';
  MODEL_QWEN_25_CODER_7B  = 'qwen2.5-coder-7b-instruct';
  MODEL_QWEN_25_PLUS      = 'qwen2.5-plus';

  { Standard models for Mistral AI }
  MODEL_MISTRAL_CODESTRAL = 'codestral-latest';
  MODEL_MISTRAL_LARGE     = 'mistral-large-latest';
  MODEL_MISTRAL_OPEN_7B   = 'open-codestral-7b';

function MessageRoleToString(const ARole: TAIMessageRole): string;
function StringToMessageRole(const AString: string): TAIMessageRole;

var
  GIsShuttingDown: Boolean = False;
  GActiveThreadCount: Integer = 0;
  GProjectTransitionCount: Integer = 0;

implementation

uses
  System.SysUtils;

function MessageRoleToString(const ARole: TAIMessageRole): string;
begin
  case ARole of
    mrUser: Result := 'user';
    mrAssistant: Result := 'assistant';
    mrSystem: Result := 'system';
  else
    Result := '';
  end;
end;

function StringToMessageRole(const AString: string): TAIMessageRole;
begin
  if SameText(AString, 'user') then
    Result := mrUser
  else if SameText(AString, 'assistant') then
    Result := mrAssistant
  else if SameText(AString, 'system') then
    Result := mrSystem
  else
    raise EConvertError.CreateFmt('Invalid message role string: %s', [AString]);
end;

end.
