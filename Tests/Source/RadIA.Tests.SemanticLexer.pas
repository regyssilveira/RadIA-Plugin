unit RadIA.Tests.SemanticLexer;

interface

implementation

uses
  System.SysUtils,
  DUnitX.TestFramework,
  RadIA.Semantic.Lexer;

type
  [TestFixture]
  TRadIASemanticLexerTests = class
  public
    [Test]
    procedure PreservesEverySourceCharacterAndOffset;
    [Test]
    procedure ClassifiesModernPascalSurface;
    [Test]
    procedure KeepsUnterminatedBlocksWithoutCrashing;
  end;

function Reconstruct(const ATokens: TArray<TRadIASemanticToken>): string;
var
  LToken: TRadIASemanticToken;
begin
  Result := '';
  for LToken in ATokens do
    Result := Result + LToken.Text;
end;

procedure TRadIASemanticLexerTests.ClassifiesModernPascalSurface;
var
  LSource: string;
  LToken: TRadIASemanticToken;
  LTokens: TArray<TRadIASemanticToken>;
  LTypes: string;
begin
  LSource :=
    '{$IFDEF DEBUG}' + sLineBreak +
    '[Test] procedure Run<T>(const AValue: T); // comment' + sLineBreak +
    'S := ''it''''s valid''; (* block *) {$ENDIF}';
  LTokens := TRadIASemanticLexer.Tokenize(LSource);
  LTypes := '';
  for LToken in LTokens do
    LTypes := LTypes + ';' +
      TRadIASemanticLexer.TokenKindName(LToken.Kind);

  Assert.Contains(LTypes, 'directive');
  Assert.Contains(LTypes, 'identifier');
  Assert.Contains(LTypes, 'comment');
  Assert.Contains(LTypes, 'string');
  Assert.AreEqual(LSource, Reconstruct(LTokens));
end;

procedure TRadIASemanticLexerTests.KeepsUnterminatedBlocksWithoutCrashing;
var
  LSource: string;
begin
  LSource := 'begin S := ''unfinished' + sLineBreak + '{comment';
  Assert.AreEqual(
    LSource,
    Reconstruct(TRadIASemanticLexer.Tokenize(LSource))
  );
end;

procedure TRadIASemanticLexerTests.PreservesEverySourceCharacterAndOffset;
var
  LExpectedOffset: Integer;
  LSource: string;
  LToken: TRadIASemanticToken;
  LTokens: TArray<TRadIASemanticToken>;
begin
  LSource :=
    'unit Sample;' + #13#10 +
    'interface' + #10 +
    'type TFoo<T> = class' + #13#10 +
    'end;';
  LTokens := TRadIASemanticLexer.Tokenize(LSource);
  LExpectedOffset := 0;
  for LToken in LTokens do
  begin
    Assert.AreEqual(LExpectedOffset, LToken.StartOffset);
    Assert.AreEqual(Length(LToken.Text), LToken.Length);
    Inc(LExpectedOffset, LToken.Length);
  end;
  Assert.AreEqual(Length(LSource), LExpectedOffset);
  Assert.AreEqual(LSource, Reconstruct(LTokens));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticLexerTests);

end.
