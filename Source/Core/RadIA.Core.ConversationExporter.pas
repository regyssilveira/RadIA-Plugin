unit RadIA.Core.ConversationExporter;

interface

uses
  RadIA.Core.Interfaces,
  RadIA.Core.ToolSecurity;

type
  { Core class responsible for formatting conversation history to Markdown and HTML }
  TConversationExporter = class
  private
    class function MarkdownToSimpleHTML(const AMarkdownText: string): string; static;
    { Applies the supplied redactor or a secure default redactor }
    class function RedactContent(const AContent: string;
      const ARedactor: IRadIASecretRedactor): string; static;
  public
    { Formats the history as a Markdown document.
      A secure default redactor is used when none is supplied. }
    class function ExportToMarkdown(const AHistory: TArray<IRadIAChatMessage>;
      const AProviderName, AModelName: string;
      const ARedactor: IRadIASecretRedactor = nil): string; static;

    { Formats the history as a standalone HTML document.
      A secure default redactor is used when none is supplied. }
    class function ExportToHTML(const AHistory: TArray<IRadIAChatMessage>;
      const AProviderName, AModelName: string;
      const ARedactor: IRadIASecretRedactor = nil): string; static;
  end;

implementation

uses
  System.SysUtils, RadIA.Core.Types;

{ TConversationExporter }

class function TConversationExporter.RedactContent(const AContent: string;
  const ARedactor: IRadIASecretRedactor): string;
var
  LRedactor: IRadIASecretRedactor;
begin
  if Assigned(ARedactor) then
    Exit(ARedactor.Redact(AContent));
  LRedactor := TRadIASecretRedactor.Create;
  Result := LRedactor.Redact(AContent);
end;

class function TConversationExporter.MarkdownToSimpleHTML(const AMarkdownText: string): string;
var
  LInputLines: TArray<string>;
  LSb: TStringBuilder;
  I: Integer;
  LInCodeBlock: Boolean;
  LLine: string;
begin
  { Handle CRLF robustly by normalizing to LF and splitting }
  LInputLines := AMarkdownText.Replace(#13, '').Split([#10]);
  LSb := TStringBuilder.Create;
  try
    LInCodeBlock := False;
    for I := 0 to High(LInputLines) do
    begin
      LLine := LInputLines[I];

      { Handle Code Blocks }
      if LLine.StartsWith('```') then
      begin
        if LInCodeBlock then
        begin
          LSb.AppendLine('</code></pre>');
          LInCodeBlock := False;
        end
        else
        begin
          LSb.AppendLine('<pre><code>');
          LInCodeBlock := True;
        end;
        Continue;
      end;

      { Escape HTML tags }
      LLine := LLine.Replace('&', '&amp;')
                    .Replace('<', '&lt;')
                    .Replace('>', '&gt;');

      if LInCodeBlock then
      begin
        LSb.AppendLine(LLine);
      end
      else
      begin
        if LLine.Trim.IsEmpty then
          LSb.AppendLine('<br/>')
        else
          LSb.AppendLine('<p>' + LLine + '</p>');
      end;
    end;

    if LInCodeBlock then
      LSb.AppendLine('</code></pre>');

    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

class function TConversationExporter.ExportToMarkdown(const AHistory: TArray<IRadIAChatMessage>;
  const AProviderName, AModelName: string;
  const ARedactor: IRadIASecretRedactor): string;
var
  LSb: TStringBuilder;
  LMsg: IRadIAChatMessage;
begin
  LSb := TStringBuilder.Create;
  try
    LSb.AppendLine('# Conversation History - Rad IA');
    LSb.AppendLine(Format('- **Date**: %s', [DateTimeToStr(Now)]));
    LSb.AppendLine(Format('- **Provider**: %s', [AProviderName]));
    LSb.AppendLine(Format('- **Model**: %s', [AModelName]));
    LSb.AppendLine;
    LSb.AppendLine('---');
    LSb.AppendLine;

    for LMsg in AHistory do
    begin
      if LMsg.Role = mrSystem then
        Continue;

      if LMsg.Role = mrUser then
      begin
        LSb.AppendLine('### 👤 User');
        LSb.AppendLine(RedactContent(LMsg.Content, ARedactor));
      end
      else
      begin
        LSb.AppendLine('### 🤖 Assistant (Rad IA)');
        LSb.AppendLine(RedactContent(LMsg.Content, ARedactor));
      end;
      LSb.AppendLine;
      LSb.AppendLine('---');
      LSb.AppendLine;
    end;

    Result := LSb.ToString.Trim;
  finally
    LSb.Free;
  end;
end;

class function TConversationExporter.ExportToHTML(const AHistory: TArray<IRadIAChatMessage>;
  const AProviderName, AModelName: string;
  const ARedactor: IRadIASecretRedactor): string;
var
  LSb: TStringBuilder;
  LMsg: IRadIAChatMessage;
  LRoleName: string;
  LRoleClass: string;
begin
  LSb := TStringBuilder.Create;
  try
    LSb.AppendLine('<!DOCTYPE html>');
    LSb.AppendLine('<html>');
    LSb.AppendLine('<head>');
    LSb.AppendLine('  <meta charset="utf-8">');
    LSb.AppendLine('  <title>Conversation History - Rad IA</title>');
    LSb.AppendLine('  <style>');
    LSb.AppendLine('    body {');
    LSb.AppendLine('      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;');
    LSb.AppendLine('      background-color: #1e1e1e;');
    LSb.AppendLine('      color: #d4d4d4;');
    LSb.AppendLine('      max-width: 800px;');
    LSb.AppendLine('      margin: 0 auto;');
    LSb.AppendLine('      padding: 20px;');
    LSb.AppendLine('      line-height: 1.6;');
    LSb.AppendLine('    }');
    LSb.AppendLine('    h1 { color: #007acc; border-bottom: 1px solid #3c3c3c; padding-bottom: 10px; ' +
        'margin-bottom: 20px; }');
    LSb.AppendLine('    .meta { color: #858585; font-size: 13px; margin-bottom: 30px; background: #252526; ' +
        'padding: 12px; border-radius: 4px; border: 1px solid #3c3c3c; }');
    LSb.AppendLine('    .meta p { margin: 4px 0; }');
    LSb.AppendLine('    .message { margin-bottom: 24px; padding: 16px; border-radius: 6px; border: 1px ' +
        'solid #3c3c3c; }');
    LSb.AppendLine('    .message.user { background-color: #0b253a; border-color: #007acc; }');
    LSb.AppendLine('    .message.assistant { background-color: #252526; }');
    LSb.AppendLine('    .role { font-weight: bold; font-size: 11px; text-transform: uppercase; margin-bottom: ' +
        '10px; letter-spacing: 0.5px; }');
    LSb.AppendLine('    .message.user .role { color: #007acc; }');
    LSb.AppendLine('    .message.assistant .role { color: #858585; }');
    LSb.AppendLine('    pre { background-color: #111; padding: 12px; border-radius: 4px; overflow-x: ' +
        'auto; border: 1px solid #2d2d2d; }');
    LSb.AppendLine('    code { font-family: "Consolas", "Monaco", monospace; font-size: 13px; color: #9cdcfe; }');
    LSb.AppendLine('    p { margin: 0 0 10px 0; }');
    LSb.AppendLine('    p:last-child { margin-bottom: 0; }');
    LSb.AppendLine('  </style>');
    LSb.AppendLine('</head>');
    LSb.AppendLine('<body>');
    LSb.AppendLine('  <h1>Conversation History - Rad IA</h1>');
    LSb.AppendLine('  <div class="meta">');
    LSb.AppendLine(Format('    <p><strong>Date:</strong> %s</p>', [DateTimeToStr(Now)]));
    LSb.AppendLine(Format('    <p><strong>Provider:</strong> %s</p>', [AProviderName]));
    LSb.AppendLine(Format('    <p><strong>Model:</strong> %s</p>', [AModelName]));
    LSb.AppendLine('  </div>');

    for LMsg in AHistory do
    begin
      if LMsg.Role = mrSystem then
        Continue;

      if LMsg.Role = mrUser then
      begin
        LRoleName := 'User';
        LRoleClass := 'user';
      end
      else
      begin
        LRoleName := 'Assistant (Rad IA)';
        LRoleClass := 'assistant';
      end;

      LSb.AppendLine(Format('  <div class="message %s">', [LRoleClass]));
      LSb.AppendLine(Format('    <div class="role">%s</div>', [LRoleName]));
      { Redact before the HTML conversion so the escaping does not break the patterns }
      LSb.AppendLine('    ' + MarkdownToSimpleHTML(RedactContent(LMsg.Content, ARedactor)));
      LSb.AppendLine('  </div>');
    end;

    LSb.AppendLine('</body>');
    LSb.AppendLine('</html>');

    Result := LSb.ToString;
  finally
    LSb.Free;
  end;
end;

end.
