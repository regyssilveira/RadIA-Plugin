unit RadIA.Tests.DelphiTypeMove;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIADelphiTypeMoveTests = class
  public
    [Test]
    procedure DelimitsClassAndNestedRecord;
    [Test]
    procedure DelimitsRecordHelper;
    [Test]
    procedure RejectsForwardConditionalAndStaleTypes;
  end;

implementation

uses
  RadIA.Core.DelphiTypeMove;

procedure TRadIADelphiTypeMoveTests.DelimitsClassAndNestedRecord;
const
  CType = 'TWorker = class' + sLineBreak +
    '  type TState = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    '  procedure Execute;' + sLineBreak +
    'end;';
  CSource = 'type' + sLineBreak + '  ' + CType + sLineBreak +
    '  TAfter = class end;';
var
  LError: string;
  LType: TRadIADelphiMovableType;
begin
  Assert.IsTrue(TRadIADelphiTypeMoveAnalyzer.TryAnalyze(
    CSource,
    'TWorker',
    Pos('TWorker', CSource) - 1,
    LType,
    LError
  ), LError);
  Assert.AreEqual(Integer(mtkClass), Integer(LType.Kind));
  Assert.AreEqual(CType, LType.Content);
end;

procedure TRadIADelphiTypeMoveTests.DelimitsRecordHelper;
const
  CType = 'TStringHelper = record helper for string' + sLineBreak +
    '  function Normalized: string;' + sLineBreak + 'end;';
  CSource = 'type' + sLineBreak + '  ' + CType;
var
  LError: string;
  LType: TRadIADelphiMovableType;
begin
  Assert.IsTrue(TRadIADelphiTypeMoveAnalyzer.TryAnalyze(
    CSource,
    'TStringHelper',
    Pos('TStringHelper', CSource) - 1,
    LType,
    LError
  ), LError);
  Assert.AreEqual(Integer(mtkRecordHelper), Integer(LType.Kind));
end;

procedure TRadIADelphiTypeMoveTests.
  RejectsForwardConditionalAndStaleTypes;
const
  CConditional = 'TWorker = class' + sLineBreak + '{$IFDEF DEBUG}' +
    sLineBreak + '  Value: Integer;' + sLineBreak + '{$ENDIF}' +
    sLineBreak + 'end;';
  CForward = 'TWorker = class;';
var
  LError: string;
  LType: TRadIADelphiMovableType;
begin
  Assert.IsFalse(TRadIADelphiTypeMoveAnalyzer.TryAnalyze(
    CForward, 'TWorker', 0, LType, LError
  ));
  Assert.Contains(LError, 'not structurally closed');
  Assert.IsFalse(TRadIADelphiTypeMoveAnalyzer.TryAnalyze(
    CConditional, 'TWorker', 0, LType, LError
  ));
  Assert.Contains(LError, 'conditional compiler directives');
  Assert.IsFalse(TRadIADelphiTypeMoveAnalyzer.TryAnalyze(
    'TWorker = class end;', 'TWorker', 1, LType, LError
  ));
  Assert.Contains(LError, 'changed');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADelphiTypeMoveTests);

end.
