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
    [Test]
    procedure EditsDestinationSectionsIdempotently;
    [Test]
    procedure InsertsMissingUsesClauseAndRejectsInvalidInputs;
  end;

implementation

uses
  RadIA.Core.DelphiTypeMove;

procedure TRadIADelphiTypeMoveTests.EditsDestinationSectionsIdempotently;
const
  CSource = 'unit Destination;' + sLineBreak + 'interface' + sLineBreak +
    'uses' + sLineBreak + '  System.SysUtils;' + sLineBreak +
    'implementation' + sLineBreak + 'uses' + sLineBreak +
    '  System.Classes;' + sLineBreak + 'initialization' + sLineBreak +
    '  RegisterTypes;' + sLineBreak + 'end.';
var
  LContent: string;
  LError: string;
  LSecond: string;
begin
  Assert.IsTrue(TRadIADelphiTypeMoveEditor.TryEnsureUsesUnit(
    CSource, 'Source.Unit', True, LContent, LError
  ), LError);
  Assert.Contains(LContent, 'System.SysUtils,' + sLineBreak + '  Source.Unit;');
  Assert.IsTrue(TRadIADelphiTypeMoveEditor.TryEnsureUsesUnit(
    LContent, 'Source.Unit', True, LSecond, LError
  ), LError);
  Assert.AreEqual(LContent, LSecond);
  Assert.IsTrue(TRadIADelphiTypeMoveEditor.TryInsertDeclaration(
    LContent,
    'TWorker = class' + sLineBreak + 'end;',
    LSecond,
    LError
  ), LError);
  Assert.IsTrue(
    Pos('  TWorker = class', LSecond) < Pos('implementation', LSecond)
  );
  Assert.IsTrue(TRadIADelphiTypeMoveEditor.TryInsertImplementations(
    LSecond,
    ['procedure TWorker.Execute;' + sLineBreak +
      'begin' + sLineBreak + 'end;'],
    LContent,
    LError
  ), LError);
  Assert.IsTrue(
    Pos('procedure TWorker.Execute', LContent) < Pos('initialization', LContent)
  );
end;

procedure TRadIADelphiTypeMoveTests.
  InsertsMissingUsesClauseAndRejectsInvalidInputs;
const
  CSource = 'unit Destination;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.';
var
  LContent: string;
  LError: string;
begin
  Assert.IsTrue(TRadIADelphiTypeMoveEditor.TryEnsureUsesUnit(
    CSource, 'SourceUnit', False, LContent, LError
  ), LError);
  Assert.Contains(
    LContent,
    'implementation' + sLineBreak + 'uses' + sLineBreak +
    '  SourceUnit;'
  );
  Assert.IsFalse(TRadIADelphiTypeMoveEditor.TryEnsureUsesUnit(
    CSource, 'Invalid-Unit', True, LContent, LError
  ));
  Assert.Contains(LError, 'unit name is invalid');
  Assert.IsFalse(TRadIADelphiTypeMoveEditor.TryInsertDeclaration(
    CSource, '', LContent, LError
  ));
  Assert.Contains(LError, 'declaration is empty');
end;

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
