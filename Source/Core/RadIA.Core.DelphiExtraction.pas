unit RadIA.Core.DelphiExtraction;

interface

type
  TRadIADelphiExtractSelection = record
  private
    FContent: string;
    FLength: Integer;
    FStartOffset: Integer;
  public
    constructor Create(
      const AContent: string;
      const AStartOffset: Integer
    );
    property Content: string read FContent;
    property Length: Integer read FLength;
    property StartOffset: Integer read FStartOffset;
  end;

  TRadIADelphiExtractionAnalyzer = class
  public
    class function TryAnalyze(
      const ASource: string;
      const ASelectedText: string;
      const ACursorLine: Integer;
      const ACursorColumn: Integer;
      out ASelection: TRadIADelphiExtractSelection;
      out AError: string
    ): Boolean; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.StrUtils,
  System.SysUtils,
  RadIA.Semantic.Lexer;

const
  CMaxSelectionCharacters = 65536;

constructor TRadIADelphiExtractSelection.Create(
  const AContent: string;
  const AStartOffset: Integer
);
begin
  FContent := AContent;
  FStartOffset := AStartOffset;
  FLength := System.Length(AContent);
end;

function OffsetForPosition(
  const ASource: string;
  const ALine: Integer;
  const AColumn: Integer
): Integer;
var
  LColumn: Integer;
  LIndex: Integer;
  LLine: Integer;
begin
  Result := -1;
  if (ALine < 1) or (AColumn < 1) then
    Exit;
  LIndex := 1;
  LLine := 1;
  while (LIndex <= Length(ASource)) and (LLine < ALine) do
  begin
    if ASource[LIndex] = #10 then
      Inc(LLine);
    Inc(LIndex);
  end;
  if LLine <> ALine then
    Exit;
  LColumn := 1;
  while (LIndex <= Length(ASource)) and (LColumn < AColumn) and
    not CharInSet(ASource[LIndex], [#10, #13]) do
  begin
    Inc(LIndex);
    Inc(LColumn);
  end;
  if LColumn = AColumn then
    Result := LIndex - 1;
end;

function FindSelectionOffset(
  const ASource: string;
  const ASelectedText: string;
  const ACursorOffset: Integer;
  out AOffset: Integer;
  out AError: string
): Boolean;
var
  LCandidate: Integer;
  LMatchCount: Integer;
  LSearchOffset: Integer;
begin
  Result := False;
  AOffset := -1;
  AError := '';
  LMatchCount := 0;
  LSearchOffset := 1;
  repeat
    LCandidate := PosEx(ASelectedText, ASource, LSearchOffset);
    if LCandidate = 0 then
      Break;
    if (ACursorOffset >= LCandidate - 1) and
      (ACursorOffset <= LCandidate - 1 + Length(ASelectedText)) then
    begin
      AOffset := LCandidate - 1;
      Inc(LMatchCount);
    end;
    LSearchOffset := LCandidate + 1;
  until LSearchOffset > Length(ASource);
  if LMatchCount = 1 then
    Exit(True);
  if LMatchCount = 0 then
    AError := 'The selected text does not contain the current editor cursor.'
  else
    AError := 'The selected text is ambiguous at the current editor cursor.';
end;

function IsForbiddenControlFlow(const AText: string): Boolean;
begin
  Result := SameText(AText, 'exit') or SameText(AText, 'break') or
    SameText(AText, 'continue') or SameText(AText, 'goto');
end;

function OpeningKind(const AText: string): string;
begin
  if SameText(AText, 'begin') or SameText(AText, 'case') or
    SameText(AText, 'try') or SameText(AText, 'asm') then
    Result := 'end'
  else if SameText(AText, 'repeat') then
    Result := 'until'
  else
    Result := '';
end;

function CheckClosingToken(
  const AText: string;
  const ABlocks: TStack<string>;
  out AError: string
): Boolean;
begin
  Result := True;
  if not SameText(AText, 'end') and not SameText(AText, 'until') then
    Exit;
  if (ABlocks.Count = 0) or not SameText(ABlocks.Peek, AText) then
  begin
    AError := 'The selection cuts across a Delphi control-flow block.';
    Exit(False);
  end;
  ABlocks.Pop;
end;

function CheckSymbolBalance(
  const AText: string;
  const ASymbols: TStack<string>;
  out AError: string
): Boolean;
var
  LExpected: string;
begin
  Result := True;
  if (AText = '(') or (AText = '[') then
  begin
    if AText = '(' then
      ASymbols.Push(')')
    else
      ASymbols.Push(']');
    Exit;
  end;
  if (AText <> ')') and (AText <> ']') then
    Exit;
  if ASymbols.Count > 0 then
    LExpected := ASymbols.Peek
  else
    LExpected := '';
  if LExpected <> AText then
  begin
    AError := 'The selection cuts across a Delphi expression.';
    Exit(False);
  end;
  ASymbols.Pop;
end;

function ValidateExtractionToken(
  const AToken: TRadIASemanticToken;
  const ABlocks: TStack<string>;
  const ASymbols: TStack<string>;
  out AError: string
): Boolean;
var
  LOpening: string;
begin
  Result := False;
  if (AToken.Kind = stkIdentifier) and
    IsForbiddenControlFlow(AToken.Text) then
  begin
    AError := 'The selection contains control flow that cannot be extracted: ' +
      AToken.Text;
    Exit;
  end;
  if AToken.Kind = stkIdentifier then
  begin
    LOpening := OpeningKind(AToken.Text);
    if not LOpening.IsEmpty then
      ABlocks.Push(LOpening)
    else if not CheckClosingToken(AToken.Text, ABlocks, AError) then
      Exit;
  end
  else if (AToken.Kind = stkSymbol) and
    not CheckSymbolBalance(AToken.Text, ASymbols, AError) then
    Exit;
  Result := True;
end;

function ValidateTokens(const ASelectedText: string; out AError: string): Boolean;
var
  LBlocks: TStack<string>;
  LSymbols: TStack<string>;
  LToken: TRadIASemanticToken;
begin
  Result := False;
  AError := '';
  LBlocks := TStack<string>.Create;
  LSymbols := TStack<string>.Create;
  try
    for LToken in TRadIASemanticLexer.Tokenize(ASelectedText) do
      if not ValidateExtractionToken(LToken, LBlocks, LSymbols, AError) then
        Exit;
    if LBlocks.Count > 0 then
      AError := 'The selection does not close every Delphi control-flow block.'
    else if LSymbols.Count > 0 then
      AError := 'The selection does not close every Delphi expression.'
    else
      Result := True;
  finally
    LSymbols.Free;
    LBlocks.Free;
  end;
end;

function ValidateSelectionText(
  const ASelectedText: string;
  out AError: string
): Boolean;
var
  LLastCodeToken: string;
  LToken: TRadIASemanticToken;
  LTrimmed: string;
begin
  Result := False;
  AError := '';
  LTrimmed := Trim(ASelectedText);
  if LTrimmed.IsEmpty then
    AError := 'Select one or more complete Delphi statements first.'
  else if Length(ASelectedText) > CMaxSelectionCharacters then
    AError := 'The selected Delphi block exceeds the 65536-character limit.'
  else
  begin
    LLastCodeToken := '';
    for LToken in TRadIASemanticLexer.Tokenize(ASelectedText) do
      if not (LToken.Kind in [stkWhitespace, stkComment, stkDirective]) then
        LLastCodeToken := LToken.Text;
    if LLastCodeToken <> ';' then
      AError := 'The selected Delphi block must end at a statement boundary.'
    else
      Result := ValidateTokens(ASelectedText, AError);
  end;
end;

class function TRadIADelphiExtractionAnalyzer.TryAnalyze(
  const ASource: string;
  const ASelectedText: string;
  const ACursorLine: Integer;
  const ACursorColumn: Integer;
  out ASelection: TRadIADelphiExtractSelection;
  out AError: string
): Boolean;
var
  LCursorOffset: Integer;
  LSelectionOffset: Integer;
begin
  Result := False;
  ASelection := Default(TRadIADelphiExtractSelection);
  if not ValidateSelectionText(ASelectedText, AError) then
    Exit;
  LCursorOffset := OffsetForPosition(ASource, ACursorLine, ACursorColumn);
  if LCursorOffset < 0 then
  begin
    AError := 'The editor cursor is outside the active buffer.';
    Exit;
  end;
  if not FindSelectionOffset(
    ASource,
    ASelectedText,
    LCursorOffset,
    LSelectionOffset,
    AError
  ) then
    Exit;
  ASelection := TRadIADelphiExtractSelection.Create(
    ASelectedText,
    LSelectionOffset
  );
  Result := True;
end;

end.
