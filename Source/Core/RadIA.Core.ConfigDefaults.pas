unit RadIA.Core.ConfigDefaults;

interface

const
  CDefaultSystemPrompt =
    'You are a Delphi Senior Software Architect. Always reply in the user''s language.' + sLineBreak +
    'When generating, refactoring, or optimizing code:' + sLineBreak +
    '1. Output ONLY the specific Pascal code block requested (e.g., a procedure, function, class, or ' +
        'code snippet).' + sLineBreak +
    '2. Do NOT wrap the code in a complete Delphi unit (no "unit", "interface", "implementation", or ' +
        '"end.") unless I explicitly ask you to create a full file.' + sLineBreak +
    '3. Do NOT include any conversational preamble, intro, or concluding remarks before or after the ' +
        'code block.' + sLineBreak +
    '4. If technical explanation is necessary, keep it extremely brief, bulleted, and placed after the ' +
        'code.' + sLineBreak +
    '5. Adhere strictly to Clean Code, SOLID principles, and proper Delphi resource management (e.g., ' +
        'try..finally).' + sLineBreak +
    '6. Always wrap the Pascal code in a standard markdown code block using triple backticks and the ' +
        '"pascal" language identifier (e.g., ```pascal ... ```). Do NOT output raw unformatted code ' +
        'or inline single backticks.';

type
  TConfigDefaults = record
  public
    class function ActiveProvider: string; static;
    class function AutocompleteDelay: Integer; static;
    class function AutocompleteModel: string; static;
    class function AutocompleteProvider: string; static;
    class function AzureApiVersion: string; static;
    class function AwsRegion: string; static;
    class function LogMaxSizeKB: Integer; static;
    class function LogPath: string; static;
    class function MaxHistoryMessages: Integer; static;
    class function MaxTokens: Integer; static;
    class function OllamaBaseUrl: string; static;
    class function ProviderAuthType: string; static;
    class function QuotaLimit: Int64; static;
    class function Temperature: Double; static;
    class function Timeout: Integer; static;
  end;

implementation


uses
  System.SysUtils, System.IOUtils;

class function TConfigDefaults.ActiveProvider: string;
begin
  Result := 'Gemini';
end;

class function TConfigDefaults.AutocompleteDelay: Integer;
begin
  Result := 300;
end;

class function TConfigDefaults.AutocompleteModel: string;
begin
  Result := 'gemini-3.6-flash';
end;

class function TConfigDefaults.AutocompleteProvider: string;
begin
  Result := 'Gemini';
end;

class function TConfigDefaults.AzureApiVersion: string;
begin
  Result := '2024-02-15-preview';
end;

class function TConfigDefaults.AwsRegion: string;
begin
  Result := 'us-east-1';
end;

class function TConfigDefaults.LogMaxSizeKB: Integer;
begin
  Result := 1024;
end;

class function TConfigDefaults.LogPath: string;
begin
  Result := TPath.Combine(
    IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) + 'RadIA',
    'Logs');
end;

class function TConfigDefaults.MaxHistoryMessages: Integer;
begin
  Result := 20;
end;

class function TConfigDefaults.MaxTokens: Integer;
begin
  Result := 2048;
end;

class function TConfigDefaults.OllamaBaseUrl: string;
begin
  Result := 'http://localhost:11434';
end;

class function TConfigDefaults.ProviderAuthType: string;
begin
  Result := 'api_key';
end;

class function TConfigDefaults.QuotaLimit: Int64;
begin
  Result := 1000000;
end;

class function TConfigDefaults.Temperature: Double;
begin
  Result := 0.7;
end;

class function TConfigDefaults.Timeout: Integer;
begin
  Result := 60;
end;

end.
