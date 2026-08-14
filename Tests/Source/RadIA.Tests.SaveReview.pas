unit RadIA.Tests.SaveReview;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIASaveReviewTests = class
  public
    [Test]
    procedure DetectsBoundedActionableFindings;
    [Test]
    procedure AcceptsCleanSavedCode;
  end;

implementation

uses
  RadIA.Core.SaveReview,
  System.SysUtils;

procedure TRadIASaveReviewTests.AcceptsCleanSavedCode;
begin
  Assert.AreEqual(0, Length(TRadIASaveReviewAnalyzer.Analyze(
    'unit Clean;' + sLineBreak + 'interface' + sLineBreak + 'end.'
  )));
end;

procedure TRadIASaveReviewTests.DetectsBoundedActionableFindings;
var
  LFindings: TArray<TRadIASaveReviewFinding>;
begin
  LFindings := TRadIASaveReviewAnalyzer.Analyze(
    '// TODO review this' + sLineBreak +
    'value := 1; ' + sLineBreak +
    StringOfChar('x', 121),
    2
  );
  Assert.AreEqual(2, Length(LFindings));
  Assert.AreEqual(1, LFindings[0].Line);
  Assert.Contains(LFindings[0].Message, 'TODO');
  Assert.Contains(LFindings[1].Message, 'trailing whitespace');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASaveReviewTests);

end.
