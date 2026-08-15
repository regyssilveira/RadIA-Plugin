unit RadIA.Tests.DelphiSignatures;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIADelphiSignatureTests = class
  public
    [Test]
    procedure ParsesGroupedParametersAndDirectives;
    [Test]
    procedure PreservesNestedGenericAndAnonymousMethodTypes;
    [Test]
    procedure RejectsInvalidSignatures;
    [Test]
    procedure ParsesParameterlessProcedureDirectives;
  end;

implementation

uses
  RadIA.Core.DelphiSignatures;

procedure TRadIADelphiSignatureTests.ParsesGroupedParametersAndDirectives;
var
  LError: string;
  LSignature: TRadIADelphiSignature;
begin
  Assert.IsTrue(TRadIADelphiSignatureParser.TryParse(
    'class function TWorker.Calculate(const A, B: Integer; ' +
    'out AText: string): Double; overload; static;',
    LSignature,
    LError
  ), LError);
  Assert.IsTrue(LSignature.IsClassRoutine);
  Assert.AreEqual(Integer(drkFunction), Integer(LSignature.Kind));
  Assert.AreEqual('TWorker.Calculate', LSignature.Name);
  Assert.AreEqual(NativeInt(3), Length(LSignature.Parameters));
  Assert.AreEqual('const', LSignature.Parameters[0].Modifier);
  Assert.AreEqual('B', LSignature.Parameters[1].Name);
  Assert.AreEqual('out', LSignature.Parameters[2].Modifier);
  Assert.AreEqual('Double', LSignature.ReturnType);
  Assert.AreEqual('overload; static', LSignature.Directives);
  Assert.AreEqual(1, LSignature.FindParameter('B'));
end;

procedure TRadIADelphiSignatureTests.ParsesParameterlessProcedureDirectives;
var
  LError: string;
  LSignature: TRadIADelphiSignature;
begin
  Assert.IsTrue(TRadIADelphiSignatureParser.TryParse(
    'procedure Execute; overload;',
    LSignature,
    LError
  ), LError);
  Assert.AreEqual('Execute', LSignature.Name);
  Assert.AreEqual('overload', LSignature.Directives);
  Assert.AreEqual(NativeInt(0), Length(LSignature.Parameters));
end;

procedure TRadIADelphiSignatureTests.PreservesNestedGenericAndAnonymousMethodTypes;
var
  LError: string;
  LSignature: TRadIADelphiSignature;
begin
  Assert.IsTrue(TRadIADelphiSignatureParser.TryParse(
    'procedure Execute(const AMap: TDictionary<string, TArray<Integer>>; ' +
    'const ACallback: reference to procedure(const AValue: Integer); ' +
    'const ATimeout: Integer = 5000);',
    LSignature,
    LError
  ), LError);
  Assert.AreEqual(NativeInt(3), Length(LSignature.Parameters));
  Assert.AreEqual(
    'TDictionary<string, TArray<Integer>>',
    LSignature.Parameters[0].TypeName
  );
  Assert.AreEqual(
    'reference to procedure(const AValue: Integer)',
    LSignature.Parameters[1].TypeName
  );
  Assert.AreEqual('5000', LSignature.Parameters[2].DefaultValue);
end;

procedure TRadIADelphiSignatureTests.RejectsInvalidSignatures;
var
  LError: string;
  LSignature: TRadIADelphiSignature;
begin
  Assert.IsFalse(TRadIADelphiSignatureParser.TryParse(
    'procedure Execute(AValue);',
    LSignature,
    LError
  ));
  Assert.IsFalse(TRadIADelphiSignatureParser.TryParse(
    'function Execute(const AValue: Integer);',
    LSignature,
    LError
  ));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADelphiSignatureTests);

end.
