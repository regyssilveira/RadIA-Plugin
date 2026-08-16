unit RadIA.Core.TerminalDiagnostics;

interface

uses
  RadIA.Core.ToolSecurity;

type
  TRadIATerminalDiagnostic = record
  private
    FColumn: Integer;
    FFileName: string;
    FLine: Integer;
    FMessage: string;
  public
    constructor Create(
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer;
      const AMessage: string
    );
    function ToChatPrompt(const ARedactor: IRadIASecretRedactor): string;
    property Column: Integer read FColumn;
    property FileName: string read FFileName;
    property Line: Integer read FLine;
    property Message: string read FMessage;
  end;

  TRadIATerminalDiagnosticParser = class
  private
    class function IsSupportedFile(const AFileName: string): Boolean; static;
    class function TryMatch(
      const AText: string;
      const APattern: string;
      out ADiagnostic: TRadIATerminalDiagnostic
    ): Boolean; static;
  public
    class function TryParse(
      const AText: string;
      out ADiagnostic: TRadIATerminalDiagnostic
    ): Boolean; static;
  end;

implementation

uses
  System.IOUtils,
  System.Math,
  System.RegularExpressions,
  System.SysUtils;

const
  CMaximumColumn = 100000;
  CMaximumInputLength = 4096;
  CMaximumLine = 10000000;
  CMaximumMessageLength = 512;

constructor TRadIATerminalDiagnostic.Create(
  const AFileName: string;
  const ALine: Integer;
  const AColumn: Integer;
  const AMessage: string
);
begin
  FFileName := AFileName;
  FLine := ALine;
  FColumn := AColumn;
  FMessage := AMessage;
end;

function TRadIATerminalDiagnostic.ToChatPrompt(
  const ARedactor: IRadIASecretRedactor
): string;
var
  LPrompt: string;
begin
  LPrompt := 'Analyze this Delphi diagnostic and propose the smallest reviewable fix:' +
    sLineBreak + 'File: ' + FFileName + sLineBreak +
    Format('Position: %d:%d', [FLine, FColumn]) + sLineBreak +
    'Diagnostic: ' + FMessage.Substring(
      0,
      Min(FMessage.Length, CMaximumMessageLength)
    );
  if Assigned(ARedactor) then
    LPrompt := ARedactor.Redact(LPrompt);
  Result := LPrompt;
end;

class function TRadIATerminalDiagnosticParser.IsSupportedFile(
  const AFileName: string
): Boolean;
var
  LExtension: string;
begin
  LExtension := TPath.GetExtension(AFileName).ToLower;
  Result := (LExtension = '.pas') or (LExtension = '.dpr') or
    (LExtension = '.dpk') or (LExtension = '.dfm');
end;

class function TRadIATerminalDiagnosticParser.TryMatch(
  const AText: string;
  const APattern: string;
  out ADiagnostic: TRadIATerminalDiagnostic
): Boolean;
var
  LColumn: Integer;
  LFileName: string;
  LLine: Integer;
  LMatch: TMatch;
  LMessage: string;
begin
  Result := False;
  LMatch := TRegEx.Match(AText, APattern, [roIgnoreCase]);
  if not LMatch.Success then
    Exit;
  LFileName := LMatch.Groups['file'].Value.Trim.Trim(['"']);
  if not IsSupportedFile(LFileName) or
    not TryStrToInt(LMatch.Groups['line'].Value, LLine) or
    (LLine < 1) or (LLine > CMaximumLine) then
    Exit;
  LColumn := 1;
  if not LMatch.Groups['column'].Value.IsEmpty then
    if not TryStrToInt(LMatch.Groups['column'].Value, LColumn) then
      Exit;
  if (LColumn < 1) or (LColumn > CMaximumColumn) then
    Exit;
  LMessage := LMatch.Groups['message'].Value.Trim;
  if LMessage.IsEmpty then
    Exit;
  ADiagnostic := TRadIATerminalDiagnostic.Create(
    LFileName,
    LLine,
    LColumn,
    LMessage.Substring(0, Min(LMessage.Length, CMaximumMessageLength))
  );
  Result := True;
end;

class function TRadIATerminalDiagnosticParser.TryParse(
  const AText: string;
  out ADiagnostic: TRadIATerminalDiagnostic
): Boolean;
const
  CFilePattern =
    '(?<file>.+?\.(?:pas|dpr|dpk|dfm))';
  CParenthesizedPattern =
    '^\s*' + CFilePattern + '\((?<line>\d+)' +
    '(?:,(?<column>\d+))?\)\s*:?\s*(?<message>.+)$';
  CColonPattern =
    '^\s*' + CFilePattern + ':(?<line>\d+)' +
    '(?::(?<column>\d+))?\s*:?\s*(?<message>.+)$';
var
  LText: string;
begin
  ADiagnostic := Default(TRadIATerminalDiagnostic);
  LText := TRegEx.Replace(AText, #27 + '\[[0-?]*[ -/]*[@-~]', '').Trim;
  if LText.IsEmpty or (LText.Length > CMaximumInputLength) or
    LText.Contains(#0) or LText.Contains(#13) or LText.Contains(#10) then
    Exit(False);
  Result := TryMatch(LText, CParenthesizedPattern, ADiagnostic) or
    TryMatch(LText, CColonPattern, ADiagnostic);
end;

end.
