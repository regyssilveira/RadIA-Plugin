unit RadIA.Tests.SemanticParser;

interface

implementation

uses
  System.SysUtils,
  DUnitX.TestFramework,
  RadIA.Semantic.Parser;

type
  [TestFixture]
  TRadIASemanticParserTests = class
  private
    function FindSymbol(
      const AResult: TRadIASemanticParseResult;
      const AName: string;
      const AKind: TRadIASemanticSymbolKind
    ): TRadIASemanticSymbol;
  public
    [Test]
    procedure ParsesModuleUsesTypesAndVisibility;
    [Test]
    procedure IgnoresInactiveDeclarations;
    [Test]
    procedure PreservesPartialUnitWhenTypeIsUnclosed;
    [Test]
    procedure ParsesEscapedMethodNames;
    [Test]
    procedure SkipsProceduralTypeDeclarations;
    [Test]
    procedure ParsesGenericForwardAndNestedTypes;
  end;

function TRadIASemanticParserTests.FindSymbol(
  const AResult: TRadIASemanticParseResult;
  const AName: string;
  const AKind: TRadIASemanticSymbolKind
): TRadIASemanticSymbol;
var
  LSymbol: TRadIASemanticSymbol;
begin
  for LSymbol in AResult.Symbols do
    if SameText(LSymbol.Name, AName) and (LSymbol.Kind = AKind) then
      Exit(LSymbol);
  Assert.Fail('Symbol not found: ' + AName);
  Result := Default(TRadIASemanticSymbol);
end;

procedure TRadIASemanticParserTests.IgnoresInactiveDeclarations;
var
  LResult: TRadIASemanticParseResult;
  LSymbol: TRadIASemanticSymbol;
begin
  LResult := TRadIASemanticParser.Parse(
    'unit Conditional; type {$IFDEF DEBUG}TDebug = class end;' +
    '{$ELSE}TRelease = record end;{$ENDIF} interface implementation end.',
    ['DEBUG']
  );
  LSymbol := FindSymbol(LResult, 'TDebug', sskClass);
  Assert.AreEqual('TDebug', LSymbol.Name);
  for LSymbol in LResult.Symbols do
    Assert.IsFalse(SameText(LSymbol.Name, 'TRelease'));
end;

procedure TRadIASemanticParserTests.ParsesModuleUsesTypesAndVisibility;
var
  LMethod: TRadIASemanticSymbol;
  LResult: TRadIASemanticParseResult;
  LSource: string;
begin
  LSource :=
    'unit Sample.Main; interface uses System.SysUtils, Vcl.Forms;' +
    'type TWorker = class(TInterfacedObject)' +
    ' strict private procedure Reset;' +
    ' public function Execute(const AValue: Integer): Boolean;' +
    ' end; TData = record public class function Empty: TData; static; end;' +
    ' IWorker = interface procedure Work; end;' +
    ' TWorkerHelper = class helper for TWorker procedure Help; end;' +
    'implementation end.';
  LResult := TRadIASemanticParser.Parse(LSource, nil);
  Assert.AreEqual('Sample.Main', FindSymbol(LResult, 'Sample.Main', sskModule).Name);
  FindSymbol(LResult, 'System.SysUtils', sskUnitReference);
  FindSymbol(LResult, 'Vcl.Forms', sskUnitReference);
  FindSymbol(LResult, 'TWorker', sskClass);
  FindSymbol(LResult, 'TData', sskRecord);
  FindSymbol(LResult, 'IWorker', sskInterface);
  FindSymbol(LResult, 'TWorkerHelper', sskHelper);
  LMethod := FindSymbol(LResult, 'Reset', sskMethod);
  Assert.AreEqual('TWorker', LMethod.ContainerName);
  Assert.AreEqual(svStrictPrivate, LMethod.Visibility);
  LMethod := FindSymbol(LResult, 'Execute', sskMethod);
  Assert.AreEqual(svPublic, LMethod.Visibility);
  Assert.Contains(LMethod.Signature, 'function Execute');
  Assert.AreEqual(0, Length(LResult.Diagnostics));
end;

procedure TRadIASemanticParserTests.PreservesPartialUnitWhenTypeIsUnclosed;
var
  LResult: TRadIASemanticParseResult;
begin
  LResult := TRadIASemanticParser.Parse(
    'unit Broken; interface type TOpen = class public procedure Run;',
    nil
  );
  FindSymbol(LResult, 'Broken', sskModule);
  FindSymbol(LResult, 'TOpen', sskClass);
  FindSymbol(LResult, 'Run', sskMethod);
  Assert.IsTrue(Length(LResult.Diagnostics) > 0);
  Assert.Contains(LResult.Diagnostics[0], 'not closed');
end;

procedure TRadIASemanticParserTests.ParsesEscapedMethodNames;
var
  LResult: TRadIASemanticParseResult;
begin
  LResult := TRadIASemanticParser.Parse(
    'unit Escaped; interface type TSample = class function &get: Integer; end;' +
    'implementation end.',
    nil
  );
  FindSymbol(LResult, 'get', sskMethod);
  Assert.AreEqual(0, Length(LResult.Diagnostics));
end;

procedure TRadIASemanticParserTests.SkipsProceduralTypeDeclarations;
var
  LResult: TRadIASemanticParseResult;
begin
  LResult := TRadIASemanticParser.Parse(
    'unit Callbacks; interface type TCallback = procedure(AValue: Integer);' +
    ' TObjectCallback = procedure of object; implementation end.',
    nil
  );
  FindSymbol(LResult, 'Callbacks', sskModule);
  Assert.AreEqual(0, Length(LResult.Diagnostics));
end;

procedure TRadIASemanticParserTests.ParsesGenericForwardAndNestedTypes;
var
  LNested: TRadIASemanticSymbol;
  LResult: TRadIASemanticParseResult;
begin
  LResult := TRadIASemanticParser.Parse(
    'unit Modern; interface type TForward = class;' +
    ' TGeneric<T: class> = class(TForward, IInterface)' +
    ' public type TNested = record end;' +
    ' class operator Implicit(AValue: Integer): TGeneric<T>;' +
    ' end; implementation end.',
    nil
  );
  FindSymbol(LResult, 'TForward', sskClass);
  Assert.Contains(
    FindSymbol(LResult, 'TGeneric', sskClass).Signature,
    'TForward, IInterface'
  );
  Assert.AreEqual(
    2,
    Length(FindSymbol(LResult, 'TGeneric', sskClass).AncestorNames)
  );
  Assert.AreEqual(
    'TForward',
    FindSymbol(LResult, 'TGeneric', sskClass).AncestorNames[0]
  );
  Assert.AreEqual(
    'IInterface',
    FindSymbol(LResult, 'TGeneric', sskClass).AncestorNames[1]
  );
  LNested := FindSymbol(LResult, 'TNested', sskRecord);
  Assert.AreEqual('TGeneric', LNested.ContainerName);
  FindSymbol(LResult, 'Implicit', sskMethod);
  Assert.AreEqual(0, Length(LResult.Diagnostics));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticParserTests);

end.
