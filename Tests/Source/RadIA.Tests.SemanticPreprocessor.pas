unit RadIA.Tests.SemanticPreprocessor;

interface

implementation

uses
  System.SysUtils,
  DUnitX.TestFramework,
  RadIA.Semantic.Preprocessor;

type
  [TestFixture]
  TRadIASemanticPreprocessorTests = class
  private
    function ActivityForText(
      const AResult: TRadIASemanticPreprocessResult;
      const AText: string
    ): TRadIASemanticActivity;
  public
    [Test]
    procedure SelectsKnownNestedBranches;
    [Test]
    procedure AppliesActiveDefineAndUndefDirectives;
    [Test]
    procedure PreservesUnknownConditionsAndReportsThem;
    [Test]
    procedure ReportsUnbalancedConditionalBlocks;
  end;

function TRadIASemanticPreprocessorTests.ActivityForText(
  const AResult: TRadIASemanticPreprocessResult;
  const AText: string
): TRadIASemanticActivity;
var
  LToken: TRadIASemanticProcessedToken;
begin
  for LToken in AResult.Tokens do
    if SameText(LToken.Token.Text, AText) then
      Exit(LToken.Activity);
  Assert.Fail('Token not found: ' + AText);
  Result := saUnknown;
end;

procedure TRadIASemanticPreprocessorTests.AppliesActiveDefineAndUndefDirectives;
var
  LResult: TRadIASemanticPreprocessResult;
  LSource: string;
begin
  LSource :=
    '{$DEFINE FEATURE}' + sLineBreak +
    '{$IFDEF FEATURE}Enabled{$ENDIF}' + sLineBreak +
    '{$UNDEF FEATURE}' + sLineBreak +
    '{$IFDEF FEATURE}Wrong{$ELSE}Disabled{$ENDIF}';
  LResult := TRadIASemanticPreprocessor.Process(LSource, nil);
  Assert.AreEqual(saActive, ActivityForText(LResult, 'Enabled'));
  Assert.AreEqual(saInactive, ActivityForText(LResult, 'Wrong'));
  Assert.AreEqual(saActive, ActivityForText(LResult, 'Disabled'));
end;

procedure TRadIASemanticPreprocessorTests.PreservesUnknownConditionsAndReportsThem;
var
  LResult: TRadIASemanticPreprocessResult;
begin
  LResult := TRadIASemanticPreprocessor.Process(
    '{$IF SizeOf(Pointer) = 8}Wide{$ELSE}Narrow{$ENDIF}',
    nil
  );
  Assert.AreEqual(saUnknown, ActivityForText(LResult, 'Wide'));
  Assert.AreEqual(saUnknown, ActivityForText(LResult, 'Narrow'));
  Assert.AreEqual(1, Length(LResult.Diagnostics));
  Assert.Contains(LResult.Diagnostics[0], 'unresolved');
end;

procedure TRadIASemanticPreprocessorTests.ReportsUnbalancedConditionalBlocks;
var
  LResult: TRadIASemanticPreprocessResult;
begin
  LResult := TRadIASemanticPreprocessor.Process(
    '{$IFDEF DEBUG}Open',
    ['DEBUG']
  );
  Assert.AreEqual(1, Length(LResult.Diagnostics));
  Assert.Contains(LResult.Diagnostics[0], 'not closed');

  LResult := TRadIASemanticPreprocessor.Process('{$ENDIF}', nil);
  Assert.AreEqual(1, Length(LResult.Diagnostics));
  Assert.Contains(LResult.Diagnostics[0], 'no matching IF');
end;

procedure TRadIASemanticPreprocessorTests.SelectsKnownNestedBranches;
var
  LResult: TRadIASemanticPreprocessResult;
  LSource: string;
begin
  LSource :=
    '{$IFDEF DEBUG}DebugCode' +
    '{$IFNDEF WIN64}Win32Code{$ELSE}Win64Code{$ENDIF}' +
    '{$ELSE}ReleaseCode{$ENDIF}';
  LResult := TRadIASemanticPreprocessor.Process(
    LSource,
    ['DEBUG', 'WIN64']
  );
  Assert.AreEqual(saActive, ActivityForText(LResult, 'DebugCode'));
  Assert.AreEqual(saInactive, ActivityForText(LResult, 'Win32Code'));
  Assert.AreEqual(saActive, ActivityForText(LResult, 'Win64Code'));
  Assert.AreEqual(saInactive, ActivityForText(LResult, 'ReleaseCode'));
  Assert.AreEqual(0, Length(LResult.Diagnostics));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticPreprocessorTests);

end.
