unit RadIA.Semantic.Lexer;

interface

type
  TRadIASemanticTokenKind = (
    stkWhitespace,
    stkIdentifier,
    stkNumber,
    stkString,
    stkComment,
    stkDirective,
    stkSymbol,
    stkUnknown
  );

  TRadIASemanticToken = record
  private
    FKind: TRadIASemanticTokenKind;
    FLength: Integer;
    FStartOffset: Integer;
    FText: string;
  public
    constructor Create(
      const AKind: TRadIASemanticTokenKind;
      const AStartOffset: Integer;
      const AText: string
    );
    property Kind: TRadIASemanticTokenKind read FKind;
    property Length: Integer read FLength;
    property StartOffset: Integer read FStartOffset;
    property Text: string read FText;
  end;

  TRadIASemanticLexer = class
  private
    class function IsIdentifierStart(const AValue: Char): Boolean; static;
  public
    class function Tokenize(const ASource: string): TArray<TRadIASemanticToken>; static;
    class function TokenKindName(const AKind: TRadIASemanticTokenKind): string; static;
  end;

implementation

uses
  System.Character,
  System.Generics.Collections,
  System.SysUtils;

function IsLineBreak(const AValue: Char): Boolean;
begin
  Result := (AValue = #10) or (AValue = #13);
end;

function ReadBraceBlock(const ASource: string; const AStart: Integer): Integer;
begin
  Result := AStart + 1;
  while (Result <= Length(ASource)) and (ASource[Result] <> '}') do
    Inc(Result);
  if Result <= Length(ASource) then
    Inc(Result);
end;

function ReadParenComment(const ASource: string; const AStart: Integer): Integer;
begin
  Result := AStart + 2;
  while Result <= Length(ASource) do
  begin
    if (ASource[Result] = '*') and
      (Result < Length(ASource)) and
      (ASource[Result + 1] = ')') then
      Exit(Result + 2);
    Inc(Result);
  end;
end;

function ReadStringLiteral(const ASource: string; const AStart: Integer): Integer;
begin
  Result := AStart + 1;
  while Result <= Length(ASource) do
  begin
    if ASource[Result] = '''' then
    begin
      if (Result < Length(ASource)) and (ASource[Result + 1] = '''') then
        Inc(Result, 2)
      else
        Exit(Result + 1);
    end
    else
      Inc(Result);
  end;
end;

function ReadWhitespace(const ASource: string; const AStart: Integer): Integer;
begin
  Result := AStart;
  while (Result <= Length(ASource)) and ASource[Result].IsWhiteSpace do
    Inc(Result);
end;

function ReadIdentifier(const ASource: string; const AStart: Integer): Integer;
begin
  Result := AStart;
  while (Result <= Length(ASource)) and
    ((ASource[Result] = '_') or
     ASource[Result].IsLetter or
     ASource[Result].IsNumber) do
    Inc(Result);
end;

function ReadNumber(const ASource: string; const AStart: Integer): Integer;
begin
  Result := AStart;
  while (Result <= Length(ASource)) and
    (ASource[Result].IsLetterOrDigit or
     CharInSet(ASource[Result], ['.', '$'])) do
    Inc(Result);
end;

procedure AddToken(
  const ATokens: TList<TRadIASemanticToken>;
  const ASource: string;
  const AKind: TRadIASemanticTokenKind;
  const AStart: Integer;
  const AEndExclusive: Integer
);
begin
  ATokens.Add(
    TRadIASemanticToken.Create(
      AKind,
      AStart - 1,
      Copy(ASource, AStart, AEndExclusive - AStart)
    )
  );
end;

function TryReadWhitespace(
  const ASource: string;
  const AIndex: Integer;
  out AEnd: Integer;
  out AKind: TRadIASemanticTokenKind
): Boolean;
begin
  Result := ASource[AIndex].IsWhiteSpace;
  if Result then
  begin
    AKind := stkWhitespace;
    AEnd := ReadWhitespace(ASource, AIndex);
  end;
end;

function TryReadIdentifierToken(
  const ASource: string;
  const AIndex: Integer;
  out AEnd: Integer;
  out AKind: TRadIASemanticTokenKind
): Boolean;
begin
  Result := TRadIASemanticLexer.IsIdentifierStart(ASource[AIndex]);
  if Result then
  begin
    AKind := stkIdentifier;
    AEnd := ReadIdentifier(ASource, AIndex);
  end;
end;

function TryReadNumberToken(
  const ASource: string;
  const AIndex: Integer;
  out AEnd: Integer;
  out AKind: TRadIASemanticTokenKind
): Boolean;
begin
  Result := ASource[AIndex].IsNumber;
  if Result then
  begin
    AKind := stkNumber;
    AEnd := ReadNumber(ASource, AIndex);
  end;
end;

function TryReadStringToken(
  const ASource: string;
  const AIndex: Integer;
  out AEnd: Integer;
  out AKind: TRadIASemanticTokenKind
): Boolean;
begin
  Result := ASource[AIndex] = '''';
  if Result then
  begin
    AKind := stkString;
    AEnd := ReadStringLiteral(ASource, AIndex);
  end;
end;

function TryReadLineComment(
  const ASource: string;
  const AIndex: Integer;
  out AEnd: Integer;
  out AKind: TRadIASemanticTokenKind
): Boolean;
begin
  Result := (ASource[AIndex] = '/') and
    (AIndex < Length(ASource)) and (ASource[AIndex + 1] = '/');
  if not Result then
    Exit;
  AKind := stkComment;
  AEnd := AIndex + 2;
  while (AEnd <= Length(ASource)) and not IsLineBreak(ASource[AEnd]) do
    Inc(AEnd);
end;

function TryReadBraceToken(
  const ASource: string;
  const AIndex: Integer;
  out AEnd: Integer;
  out AKind: TRadIASemanticTokenKind
): Boolean;
begin
  Result := ASource[AIndex] = '{';
  if not Result then
    Exit;
  AEnd := ReadBraceBlock(ASource, AIndex);
  if (AIndex < Length(ASource)) and (ASource[AIndex + 1] = '$') then
    AKind := stkDirective
  else
    AKind := stkComment;
end;

function TryReadParenToken(
  const ASource: string;
  const AIndex: Integer;
  out AEnd: Integer;
  out AKind: TRadIASemanticTokenKind
): Boolean;
begin
  Result := (ASource[AIndex] = '(') and
    (AIndex < Length(ASource)) and (ASource[AIndex + 1] = '*');
  if not Result then
    Exit;
  AEnd := ReadParenComment(ASource, AIndex);
  if (AIndex + 1 < Length(ASource)) and (ASource[AIndex + 2] = '$') then
    AKind := stkDirective
  else
    AKind := stkComment;
end;

procedure ReadToken(
  const ASource: string;
  const AIndex: Integer;
  out AEnd: Integer;
  out AKind: TRadIASemanticTokenKind
);
begin
  if TryReadWhitespace(ASource, AIndex, AEnd, AKind) then
    Exit;
  if TryReadIdentifierToken(ASource, AIndex, AEnd, AKind) then
    Exit;
  if TryReadNumberToken(ASource, AIndex, AEnd, AKind) then
    Exit;
  if TryReadStringToken(ASource, AIndex, AEnd, AKind) then
    Exit;
  if TryReadLineComment(ASource, AIndex, AEnd, AKind) then
    Exit;
  if TryReadBraceToken(ASource, AIndex, AEnd, AKind) then
    Exit;
  if TryReadParenToken(ASource, AIndex, AEnd, AKind) then
    Exit;
  AKind := stkSymbol;
  AEnd := AIndex + 1;
end;

{ TRadIASemanticToken }

constructor TRadIASemanticToken.Create(
  const AKind: TRadIASemanticTokenKind;
  const AStartOffset: Integer;
  const AText: string
);
begin
  FKind := AKind;
  FStartOffset := AStartOffset;
  FText := AText;
  FLength := System.Length(AText);
end;

{ TRadIASemanticLexer }

class function TRadIASemanticLexer.IsIdentifierStart(
  const AValue: Char
): Boolean;
begin
  Result := (AValue = '_') or AValue.IsLetter;
end;

class function TRadIASemanticLexer.Tokenize(
  const ASource: string
): TArray<TRadIASemanticToken>;
var
  LEnd: Integer;
  LIndex: Integer;
  LKind: TRadIASemanticTokenKind;
  LStart: Integer;
  LTokens: TList<TRadIASemanticToken>;
begin
  LTokens := TList<TRadIASemanticToken>.Create;
  try
    LIndex := 1;
    while LIndex <= Length(ASource) do
    begin
      LStart := LIndex;
      ReadToken(ASource, LIndex, LEnd, LKind);
      AddToken(LTokens, ASource, LKind, LStart, LEnd);
      LIndex := LEnd;
    end;
    Result := LTokens.ToArray;
  finally
    LTokens.Free;
  end;
end;

class function TRadIASemanticLexer.TokenKindName(
  const AKind: TRadIASemanticTokenKind
): string;
begin
  case AKind of
    stkWhitespace: Result := 'whitespace';
    stkIdentifier: Result := 'identifier';
    stkNumber: Result := 'number';
    stkString: Result := 'string';
    stkComment: Result := 'comment';
    stkDirective: Result := 'directive';
    stkSymbol: Result := 'symbol';
  else
    Result := 'unknown';
  end;
end;

end.
