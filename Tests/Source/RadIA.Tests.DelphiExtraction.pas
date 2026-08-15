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
    [Test]
    procedure InfersInputAndOutputParameters;
    [Test]
    procedure PreservesObservableVarParameterMutation;
    [Test]
    procedure PreservesAssignedLocalInsideExtractedMethod;
    [Test]
    procedure RejectsFunctionResultMutation;
    [Test]
    procedure FindsImplementationContainingSelection;
    [Test]
    procedure RejectsSelectionOutsideRoutine;
  end;

implementation

uses
  RadIA.Core.DelphiExtraction;

procedure TRadIADelphiExtractionTests.FindsImplementationContainingSelection;
const
  CSelection = '  LTotal := AValue * 2;' + sLineBreak;
  CSource = 'unit Calculator;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TCalculator = class' + sLineBreak +
    '  public' + sLineBreak +
    '    procedure Calculate(const AValue: Integer);' + sLineBreak +
    '  end;' + sLineBreak + 'implementation' + sLineBreak +
    'procedure TCalculator.Calculate(const AValue: Integer);' + sLineBreak +
    'var' + sLineBreak + '  LTotal: Integer;' + sLineBreak +
    'begin' + sLineBreak + CSelection + 'end;' + sLineBreak + 'end.';
var
  LError: string;
  LRoutine: TRadIADelphiExtractRoutine;
  LSelection: TRadIADelphiExtractSelection;
begin
  LSelection := TRadIADelphiExtractSelection.Create(
    CSelection,
    Pos(CSelection, CSource) - 1
  );
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryFindEnclosingRoutine(
    CSource,
    LSelection,
    LRoutine,
    LError
  ), LError);
  Assert.AreEqual('Calculate', LRoutine.Name);
  Assert.AreEqual('TCalculator', LRoutine.ContainerName);
  Assert.Contains(LRoutine.Signature, 'TCalculator.Calculate');
  Assert.IsTrue(LRoutine.BodyStart < LSelection.StartOffset);
  Assert.IsTrue(LRoutine.BodyEnd > LSelection.StartOffset);
end;

procedure TRadIADelphiExtractionTests.RejectsSelectionOutsideRoutine;
const
  CSelection = 'type TOutside = Integer;';
  CSource = 'unit Outside;' + sLineBreak + 'interface' + sLineBreak +
    CSelection + sLineBreak + 'implementation' + sLineBreak + 'end.';
var
  LError: string;
  LRoutine: TRadIADelphiExtractRoutine;
  LSelection: TRadIADelphiExtractSelection;
begin
  LSelection := TRadIADelphiExtractSelection.Create(
    CSelection,
    Pos(CSelection, CSource) - 1
  );
  Assert.IsFalse(TRadIADelphiExtractionAnalyzer.TryFindEnclosingRoutine(
    CSource,
    LSelection,
    LRoutine,
    LError
  ));
  Assert.Contains(LError, 'No unambiguous Delphi routine');
end;

procedure TRadIADelphiExtractionTests.InfersInputAndOutputParameters;
const
  CSignature =
    'procedure TCalculator.Calculate(const APrice: Currency; ' +
    'AQuantity: Integer);';
  CSelection = '  LTotal := APrice * AQuantity;' + sLineBreak;
  CSource = CSignature + sLineBreak +
    'var' + sLineBreak +
    '  LTotal: Currency;' + sLineBreak +
    'begin' + sLineBreak +
    CSelection +
    '  Save(LTotal);' + sLineBreak +
    'end;';
var
  LError: string;
  LParameters: TArray<TRadIADelphiExtractParameter>;
  LSelection: TRadIADelphiExtractSelection;
begin
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryAnalyze(
    CSource,
    CSelection,
    5,
    10,
    LSelection,
    LError
  ), LError);
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryInferParameters(
    CSource,
    LSelection,
    CSignature,
    0,
    LParameters,
    LError
  ), LError);
  Assert.AreEqual(NativeInt(3), Length(LParameters));
  Assert.AreEqual('APrice', LParameters[0].Name);
  Assert.AreEqual('Currency', LParameters[0].TypeName);
  Assert.AreEqual(Integer(epkConst), Integer(LParameters[0].Kind));
  Assert.AreEqual('AQuantity', LParameters[1].Name);
  Assert.AreEqual(Integer(epkValue), Integer(LParameters[1].Kind));
  Assert.AreEqual('LTotal', LParameters[2].Name);
  Assert.AreEqual(Integer(epkOut), Integer(LParameters[2].Kind));
end;

procedure TRadIADelphiExtractionTests.
  PreservesObservableVarParameterMutation;
const
  CSignature = 'procedure Increment(var AValue: Integer);';
  CSelection = '  AValue := AValue + 1;' + sLineBreak;
  CSource = CSignature + sLineBreak + 'begin' + sLineBreak +
    CSelection + 'end;';
var
  LError: string;
  LParameters: TArray<TRadIADelphiExtractParameter>;
  LSelection: TRadIADelphiExtractSelection;
begin
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryAnalyze(
    CSource,
    CSelection,
    3,
    10,
    LSelection,
    LError
  ), LError);
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryInferParameters(
    CSource,
    LSelection,
    CSignature,
    0,
    LParameters,
    LError
  ), LError);
  Assert.AreEqual(NativeInt(1), Length(LParameters));
  Assert.AreEqual(Integer(epkVar), Integer(LParameters[0].Kind));
end;

procedure TRadIADelphiExtractionTests.
  PreservesAssignedLocalInsideExtractedMethod;
const
  CSignature = 'procedure Calculate;';
  CSelection = '  LTemporary := 42;' + sLineBreak;
  CSource = CSignature + sLineBreak + 'var' + sLineBreak +
    '  LTemporary: Integer;' + sLineBreak + 'begin' + sLineBreak +
    CSelection + 'end;';
var
  LError: string;
  LParameters: TArray<TRadIADelphiExtractParameter>;
  LSelection: TRadIADelphiExtractSelection;
begin
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryAnalyze(
    CSource, CSelection, 5, 10, LSelection, LError
  ), LError);
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryInferParameters(
    CSource, LSelection, CSignature, 0, LParameters, LError
  ), LError);
  Assert.AreEqual(NativeInt(1), Length(LParameters));
  Assert.AreEqual('LTemporary', LParameters[0].Name);
  Assert.AreEqual(Integer(epkOut), Integer(LParameters[0].Kind));
end;

procedure TRadIADelphiExtractionTests.RejectsFunctionResultMutation;
const
  CSignature = 'function Calculate: Integer;';
  CSelection = '  Result := 42;' + sLineBreak;
  CSource = CSignature + sLineBreak + 'begin' + sLineBreak +
    CSelection + 'end;';
var
  LError: string;
  LParameters: TArray<TRadIADelphiExtractParameter>;
  LSelection: TRadIADelphiExtractSelection;
begin
  Assert.IsTrue(TRadIADelphiExtractionAnalyzer.TryAnalyze(
    CSource, CSelection, 3, 10, LSelection, LError
  ), LError);
  Assert.IsFalse(TRadIADelphiExtractionAnalyzer.TryInferParameters(
    CSource, LSelection, CSignature, 0, LParameters, LError
  ));
  Assert.Contains(LError, 'function Result');
end;

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
