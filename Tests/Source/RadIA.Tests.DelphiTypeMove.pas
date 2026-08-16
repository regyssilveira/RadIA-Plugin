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
    [Test]
    procedure FindsOnlyOwnedMethodImplementations;
    [Test]
    procedure RejectsAmbiguousNestedRoutineImplementation;
    [Test]
    procedure RemovesDeclarationAndImplementationsAtomically;
    [Test]
    procedure DetectsIndirectInterfaceCycles;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.DelphiTypeMove;

procedure TRadIADelphiTypeMoveTests.DetectsIndirectInterfaceCycles;
var
  LCycle: string;
  LUnits: TArray<TRadIADelphiUnitSource>;
begin
  LUnits := [
    TRadIADelphiUnitSource.Create(
      'UnitA',
      'unit UnitA; interface uses UnitB; implementation end.'
    ),
    TRadIADelphiUnitSource.Create(
      'UnitB',
      'unit UnitB; interface uses UnitC; implementation end.'
    ),
    TRadIADelphiUnitSource.Create(
      'UnitC',
      'unit UnitC; interface uses UnitA; implementation end.'
    )
  ];
  Assert.IsFalse(TRadIADelphiUnitDependencyGraph.TryValidateAcyclic(
    LUnits,
    LCycle
  ));
  Assert.Contains(LCycle, 'unita');
  LUnits[2] := TRadIADelphiUnitSource.Create(
    'UnitC',
    'unit UnitC; interface implementation end.'
  );
  Assert.IsTrue(TRadIADelphiUnitDependencyGraph.TryValidateAcyclic(
    LUnits,
    LCycle
  ), LCycle);
end;

procedure TRadIADelphiTypeMoveTests.FindsOnlyOwnedMethodImplementations;
const
  CSource = 'unit SourceUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type TWorker = class' + sLineBreak +
    '  procedure Execute; function Ready: Boolean;' + sLineBreak +
    'end;' + sLineBreak + 'implementation' + sLineBreak +
    'procedure TWorker.Execute;' + sLineBreak + 'begin' + sLineBreak +
    '  if Ready then' + sLineBreak + '  begin' + sLineBreak +
    '    Work;' + sLineBreak + '  end;' + sLineBreak + 'end;' + sLineBreak +
    'function TWorker.Ready: Boolean;' + sLineBreak + 'begin' + sLineBreak +
    '  Result := True;' + sLineBreak + 'end;' + sLineBreak +
    'procedure TOther.Execute;' + sLineBreak + 'begin' + sLineBreak +
    'end;' + sLineBreak + 'end.';
var
  LBlocks: TArray<TRadIADelphiMoveBlock>;
  LError: string;
begin
  Assert.IsTrue(TRadIADelphiTypeMoveAnalyzer.TryFindImplementations(
    CSource,
    'TWorker',
    LBlocks,
    LError
  ), LError);
  Assert.AreEqual(NativeInt(2), Length(LBlocks));
  Assert.Contains(LBlocks[0].Content, 'procedure TWorker.Execute');
  Assert.Contains(LBlocks[1].Content, 'function TWorker.Ready');
  Assert.IsFalse(LBlocks[0].Content.Contains('TOther'));
end;

procedure TRadIADelphiTypeMoveTests.
  RejectsAmbiguousNestedRoutineImplementation;
const
  CSource = 'unit SourceUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type TWorker = class procedure Execute; end;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure TWorker.Execute;' +
    sLineBreak + 'procedure LocalWork;' + sLineBreak + 'begin' +
    sLineBreak + 'end;' + sLineBreak + 'begin' + sLineBreak +
    '  LocalWork;' + sLineBreak + 'end;' + sLineBreak + 'end.';
var
  LBlocks: TArray<TRadIADelphiMoveBlock>;
  LError: string;
begin
  Assert.IsFalse(TRadIADelphiTypeMoveAnalyzer.TryFindImplementations(
    CSource,
    'TWorker',
    LBlocks,
    LError
  ));
  Assert.Contains(LError, 'nested routine');
end;

procedure TRadIADelphiTypeMoveTests.
  RemovesDeclarationAndImplementationsAtomically;
const
  CSource = 'unit SourceUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TWorker = class' + sLineBreak +
    '    procedure Execute;' + sLineBreak + '  end;' + sLineBreak +
    '  TRemaining = class end;' + sLineBreak + 'implementation' +
    sLineBreak + 'procedure TWorker.Execute;' + sLineBreak + 'begin' +
    sLineBreak + 'end;' + sLineBreak + 'end.';
var
  LBlocks: TArray<TRadIADelphiMoveBlock>;
  LContent: string;
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
  Assert.IsTrue(TRadIADelphiTypeMoveAnalyzer.TryFindImplementations(
    CSource,
    'TWorker',
    LBlocks,
    LError
  ), LError);
  Assert.IsTrue(TRadIADelphiTypeMoveEditor.TryRemoveMoveBlocks(
    CSource,
    LType,
    LBlocks,
    LContent,
    LError
  ), LError);
  Assert.IsFalse(LContent.Contains('TWorker'));
  Assert.Contains(LContent, 'TRemaining');
  Assert.Contains(LContent, 'implementation');
end;

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
