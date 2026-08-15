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
    [Test]
    procedure ParsesParameterlessFunctionWithoutParentheses;
    [Test]
    procedure BuildsExplicitDeterministicSignatureDelta;
    [Test]
    procedure RendersQualifiedImplementationSignature;
    [Test]
    procedure RejectsDuplicateAndUnknownMappings;
  end;

implementation

uses
  RadIA.Core.DelphiSignatures;

procedure TRadIADelphiSignatureTests.
  ParsesParameterlessFunctionWithoutParentheses;
var
  LError: string;
  LSignature: TRadIADelphiSignature;
begin
  Assert.IsTrue(TRadIADelphiSignatureParser.TryParse(
    'function Calculate: Integer;',
    LSignature,
    LError
  ), LError);
  Assert.AreEqual('Calculate', LSignature.Name);
  Assert.AreEqual('Integer', LSignature.ReturnType);
  Assert.AreEqual(NativeInt(0), Length(LSignature.Parameters));
end;

procedure TRadIADelphiSignatureTests.BuildsExplicitDeterministicSignatureDelta;
var
  LDelta: TRadIADelphiSignatureDelta;
  LError: string;
  LMappings: TArray<TRadIADelphiParameterMapping>;
  LNewSignature: TRadIADelphiSignature;
  LOldSignature: TRadIADelphiSignature;
begin
  Assert.IsTrue(TRadIADelphiSignatureParser.TryParse(
    'function Calculate(const AValue: Integer; const AScale: Double): Double;',
    LOldSignature,
    LError
  ), LError);
  Assert.IsTrue(TRadIADelphiSignatureParser.TryParse(
    'function Calculate(const AMultiplier: Double; ' +
    'const AInput: Int64; const ARound: Boolean = False): Extended;',
    LNewSignature,
    LError
  ), LError);
  LMappings := [
    TRadIADelphiParameterMapping.Create('AScale', 'AMultiplier'),
    TRadIADelphiParameterMapping.Create('AValue', 'AInput')
  ];
  Assert.IsTrue(TRadIADelphiSignatureDelta.TryBuild(
    LOldSignature,
    LNewSignature,
    LMappings,
    LDelta,
    LError
  ), LError);
  Assert.AreEqual(1, LDelta.NewToOld[0]);
  Assert.AreEqual(0, LDelta.NewToOld[1]);
  Assert.AreEqual(-1, LDelta.NewToOld[2]);
  Assert.IsTrue(LDelta.ReturnTypeChanged);
  Assert.IsTrue(pckRenamed in LDelta.Changes[0].Kinds);
  Assert.IsTrue(pckReordered in LDelta.Changes[0].Kinds);
  Assert.IsTrue(pckAdded in LDelta.Changes[2].Kinds);
  Assert.AreEqual('AScale', LDelta.Changes[0].OldName);
  Assert.AreEqual('AMultiplier', LDelta.Changes[0].NewName);
  Assert.AreEqual(1, LDelta.Changes[0].OldIndex);
  Assert.AreEqual(0, LDelta.Changes[0].NewIndex);
end;

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

procedure TRadIADelphiSignatureTests.RejectsDuplicateAndUnknownMappings;
var
  LDelta: TRadIADelphiSignatureDelta;
  LError: string;
  LNewSignature: TRadIADelphiSignature;
  LOldSignature: TRadIADelphiSignature;
begin
  TRadIADelphiSignatureParser.TryParse(
    'procedure Execute(const AFirst: Integer; const ASecond: Integer);',
    LOldSignature,
    LError
  );
  TRadIADelphiSignatureParser.TryParse(
    'procedure Execute(const AOne: Integer; const ATwo: Integer);',
    LNewSignature,
    LError
  );
  Assert.IsFalse(TRadIADelphiSignatureDelta.TryBuild(
    LOldSignature,
    LNewSignature,
    [TRadIADelphiParameterMapping.Create('AMissing', 'AOne')],
    LDelta,
    LError
  ));
  Assert.IsFalse(TRadIADelphiSignatureDelta.TryBuild(
    LOldSignature,
    LNewSignature,
    [
      TRadIADelphiParameterMapping.Create('AFirst', 'AOne'),
      TRadIADelphiParameterMapping.Create('AFirst', 'ATwo')
    ],
    LDelta,
    LError
  ));
end;

procedure TRadIADelphiSignatureTests.RendersQualifiedImplementationSignature;
var
  LError: string;
  LSignature: TRadIADelphiSignature;
begin
  Assert.IsTrue(TRadIADelphiSignatureParser.TryParse(
    'class function Calculate(const AValue: Integer): Double;',
    LSignature,
    LError
  ), LError);
  Assert.AreEqual(
    'class function TWorker.Calculate(const AValue: Integer): Double;',
    LSignature.RenderCore('TWorker.Calculate')
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADelphiSignatureTests);

end.
