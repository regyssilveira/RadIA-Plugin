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
    [Test]
    procedure CollectsIncludesWithoutChangingSourceOffsets;
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

procedure TRadIASemanticPreprocessorTests.CollectsIncludesWithoutChangingSourceOffsets;
var
  LResult: TRadIASemanticPreprocessResult;
  LSource: string;
begin
  LSource :=
    '{$I ''shared.inc''}' + sLineBreak +
    '{$IFDEF DEBUG}{$INCLUDE debug.inc}{$ELSE}{$I release.inc}{$ENDIF}';
  LResult := TRadIASemanticPreprocessor.Process(LSource, ['DEBUG']);
  Assert.AreEqual(NativeInt(3), Length(LResult.Includes));
  Assert.AreEqual('shared.inc', LResult.Includes[0].Path);
  Assert.AreEqual(0, LResult.Includes[0].StartOffset);
  Assert.AreEqual(saActive, LResult.Includes[1].Activity);
  Assert.AreEqual(saInactive, LResult.Includes[2].Activity);
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
  Assert.AreEqual(NativeInt(1), Length(LResult.Diagnostics));
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
  Assert.AreEqual(NativeInt(1), Length(LResult.Diagnostics));
  Assert.Contains(LResult.Diagnostics[0], 'not closed');

  LResult := TRadIASemanticPreprocessor.Process('{$ENDIF}', nil);
  Assert.AreEqual(NativeInt(1), Length(LResult.Diagnostics));
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
  Assert.AreEqual(NativeInt(0), Length(LResult.Diagnostics));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticPreprocessorTests);

end.
