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
      LKind := stkSymbol;
      if ASource[LIndex].IsWhiteSpace then
      begin
        LKind := stkWhitespace;
        LEnd := ReadWhitespace(ASource, LIndex);
      end
      else if IsIdentifierStart(ASource[LIndex]) then
      begin
        LKind := stkIdentifier;
        LEnd := ReadIdentifier(ASource, LIndex);
      end
      else if ASource[LIndex].IsNumber then
      begin
        LKind := stkNumber;
        LEnd := ReadNumber(ASource, LIndex);
      end
      else if ASource[LIndex] = '''' then
      begin
        LKind := stkString;
        LEnd := ReadStringLiteral(ASource, LIndex);
      end
      else if (ASource[LIndex] = '/') and
        (LIndex < Length(ASource)) and
        (ASource[LIndex + 1] = '/') then
      begin
        LKind := stkComment;
        LEnd := LIndex + 2;
        while (LEnd <= Length(ASource)) and not IsLineBreak(ASource[LEnd]) do
          Inc(LEnd);
      end
      else if ASource[LIndex] = '{' then
      begin
        LEnd := ReadBraceBlock(ASource, LIndex);
        if (LIndex < Length(ASource)) and (ASource[LIndex + 1] = '$') then
          LKind := stkDirective
        else
          LKind := stkComment;
      end
      else if (ASource[LIndex] = '(') and
        (LIndex < Length(ASource)) and
        (ASource[LIndex + 1] = '*') then
      begin
        LKind := stkComment;
        LEnd := ReadParenComment(ASource, LIndex);
      end
      else
        LEnd := LIndex + 1;
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
