unit RadIA.Tests.DelphiExtraction;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIADelphiExtractionTests = class
  public
    [Test]
    procedure LocatesCompleteSelectionAtCursor;
    [Test]
    procedure UsesCursorToDisambiguateRepeatedText;
    [Test]
    procedure RejectsUnbalancedAndEscapingControlFlow;
    [Test]
    procedure IgnoresStructuralWordsInsideStringsAndComments;
  end;

implementation

uses
  RadIA.Core.DelphiExtraction;

procedure TRadIADelphiExtractionTests.
  IgnoresStructuralWordsInsideStringsAndComments;
const
  CSelection = 'LText := ''begin exit end''; // break' + sLineBreak;
  CSource = 'begin' + sLineBreak + CSelection + 'end;';
var
  LError: string;
  LSelection: TRadIADelphiExtractSelection;
begin
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryAnalyze(
    CSource,
    CSelection,
    2,
    5,
    LSelection,
    LError
  ), LError);
end;

procedure TRadIADelphiExtractionTests.LocatesCompleteSelectionAtCursor;
const
  CSelection = '  LTotal := LPrice * LQuantity;' + sLineBreak;
  CSource = 'begin' + sLineBreak + CSelection + '  Save(LTotal);' +
    sLineBreak + 'end;';
var
  LError: string;
  LSelection: TRadIADelphiExtractSelection;
begin
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryAnalyze(
    CSource,
    CSelection,
    2,
    10,
    LSelection,
    LError
  ), LError);
  Assert.AreEqual(Length('begin' + sLineBreak), LSelection.StartOffset);
  Assert.AreEqual(CSelection, LSelection.Content);
  Assert.AreEqual(Length(CSelection), LSelection.Length);
end;

procedure TRadIADelphiExtractionTests.
  RejectsUnbalancedAndEscapingControlFlow;
var
  LError: string;
  LSelection: TRadIADelphiExtractSelection;
begin
  Assert.IsFalse(TRadIADelphiExtractionAnalyzer.TryAnalyze(
    'begin if LReady then begin Work; end; end;',
    'if LReady then begin Work;',
    1,
    15,
    LSelection,
    LError
  ));
  Assert.IsFalse(TRadIADelphiExtractionAnalyzer.TryAnalyze(
    'begin Work; Exit; end;',
    'Work; Exit;',
    1,
    12,
    LSelection,
    LError
  ));
end;

procedure TRadIADelphiExtractionTests.
  UsesCursorToDisambiguateRepeatedText;
const
  CSelection = '  Work;' + sLineBreak;
  CSource = 'begin' + sLineBreak + CSelection + CSelection + 'end;';
var
  LError: string;
  LSelection: TRadIADelphiExtractSelection;
begin
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryAnalyze(
    CSource,
    CSelection,
    3,
    5,
    LSelection,
    LError
  ), LError);
  Assert.AreEqual(
    Length('begin' + sLineBreak + CSelection),
    LSelection.StartOffset
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADelphiExtractionTests);

end.
