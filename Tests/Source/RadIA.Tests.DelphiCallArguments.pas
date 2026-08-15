unit RadIA.Tests.DelphiCallArguments;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIADelphiCallArgumentTests = class
  public
    [Test]
    procedure ReordersRenamesAndAddsPositionalArguments;
    [Test]
    procedure RewritesNamedArgumentsByIdentity;
    [Test]
    procedure RejectsRemovedSideEffectsAndMissingBindings;
    [Test]
    procedure LocatesNestedCallsAcrossStringsAndComments;
    [Test]
    procedure RejectsMethodReferencesAndUnclosedCalls;
  end;

implementation

uses
  RadIA.Core.DelphiCallArguments,
  RadIA.Core.DelphiSignatures;

procedure TRadIADelphiCallArgumentTests.
  LocatesNestedCallsAcrossStringsAndComments;
const
  CContent = 'begin Worker.Execute(Load(''(''), { ) } Other(2)); end;';
var
  LCallSite: TRadIADelphiCallSite;
  LError: string;
  LReferenceStart: Integer;
begin
  LReferenceStart := Pos('Execute', CContent) - 1;
  Assert.IsTrue(TRadIADelphiCallSite.TryLocate(
    CContent,
    LReferenceStart,
    Length('Execute'),
    LCallSite,
    LError
  ), LError);
  Assert.AreEqual('Load(''(''), { ) } Other(2)', LCallSite.ArgumentText);
  Assert.AreEqual(Pos('(', CContent), LCallSite.ArgumentStart);
  Assert.AreEqual(Length(LCallSite.ArgumentText), LCallSite.ArgumentLength);
end;

procedure TRadIADelphiCallArgumentTests.
  RejectsMethodReferencesAndUnclosedCalls;
var
  LCallSite: TRadIADelphiCallSite;
  LError: string;
begin
  Assert.IsFalse(TRadIADelphiCallSite.TryLocate(
    'LHandler := Execute;',
    Length('LHandler := '),
    Length('Execute'),
    LCallSite,
    LError
  ));
  Assert.IsFalse(TRadIADelphiCallSite.TryLocate(
    'Execute(LoadValue()',
    0,
    Length('Execute'),
    LCallSite,
    LError
  ));
end;

procedure BuildSignatures(
  out AOldSignature: TRadIADelphiSignature;
  out ANewSignature: TRadIADelphiSignature;
  out ADelta: TRadIADelphiSignatureDelta
);
var
  LError: string;
begin
  TRadIADelphiSignatureParser.TryParse(
    'procedure Execute(const AValue: Integer; const AScale: Double);',
    AOldSignature,
    LError
  );
  TRadIADelphiSignatureParser.TryParse(
    'procedure Execute(const AMultiplier: Double; const AInput: Integer; ' +
    'const ATrace: Boolean);',
    ANewSignature,
    LError
  );
  TRadIADelphiSignatureDelta.TryBuild(
    AOldSignature,
    ANewSignature,
    [
      TRadIADelphiParameterMapping.Create('AScale', 'AMultiplier'),
      TRadIADelphiParameterMapping.Create('AValue', 'AInput')
    ],
    ADelta,
    LError
  );
end;

procedure TRadIADelphiCallArgumentTests.
  RejectsRemovedSideEffectsAndMissingBindings;
var
  LDelta: TRadIADelphiSignatureDelta;
  LError: string;
  LNewSignature: TRadIADelphiSignature;
  LOldSignature: TRadIADelphiSignature;
  LRewrite: TRadIADelphiCallRewrite;
  LRequest: TRadIADelphiCallRewriteRequest;
begin
  TRadIADelphiSignatureParser.TryParse(
    'procedure Execute(const AValue: Integer);',
    LOldSignature,
    LError
  );
  TRadIADelphiSignatureParser.TryParse(
    'procedure Execute;',
    LNewSignature,
    LError
  );
  TRadIADelphiSignatureDelta.TryBuild(
    LOldSignature,
    LNewSignature,
    nil,
    LDelta,
    LError
  );
  LRequest := TRadIADelphiCallRewriteRequest.Create(
    'LoadValue()',
    LOldSignature,
    LNewSignature,
    LDelta,
    nil
  );
  Assert.IsFalse(TRadIADelphiCallRewrite.TryCreate(LRequest, LRewrite, LError));
  Assert.AreEqual(0, LRewrite.RemovedArgumentCount);
  BuildSignatures(LOldSignature, LNewSignature, LDelta);
  LRequest := TRadIADelphiCallRewriteRequest.Create(
    '10, 2.5',
    LOldSignature,
    LNewSignature,
    LDelta,
    nil
  );
  Assert.IsFalse(TRadIADelphiCallRewrite.TryCreate(LRequest, LRewrite, LError));
end;

procedure TRadIADelphiCallArgumentTests.
  ReordersRenamesAndAddsPositionalArguments;
var
  LDelta: TRadIADelphiSignatureDelta;
  LError: string;
  LNewSignature: TRadIADelphiSignature;
  LOldSignature: TRadIADelphiSignature;
  LRewrite: TRadIADelphiCallRewrite;
  LRequest: TRadIADelphiCallRewriteRequest;
begin
  BuildSignatures(LOldSignature, LNewSignature, LDelta);
  LRequest := TRadIADelphiCallRewriteRequest.Create(
    '10, 2.5',
    LOldSignature,
    LNewSignature,
    LDelta,
    [TRadIADelphiArgumentBinding.Create('ATrace', 'False')]
  );
  Assert.IsTrue(TRadIADelphiCallRewrite.TryCreate(LRequest, LRewrite, LError), LError);
  Assert.AreEqual('2.5, 10, False', LRewrite.ArgumentText);
  Assert.IsFalse(LRewrite.UsedNamedArguments);
end;

procedure TRadIADelphiCallArgumentTests.RewritesNamedArgumentsByIdentity;
var
  LDelta: TRadIADelphiSignatureDelta;
  LError: string;
  LNewSignature: TRadIADelphiSignature;
  LOldSignature: TRadIADelphiSignature;
  LRewrite: TRadIADelphiCallRewrite;
  LRequest: TRadIADelphiCallRewriteRequest;
begin
  BuildSignatures(LOldSignature, LNewSignature, LDelta);
  LRequest := TRadIADelphiCallRewriteRequest.Create(
    'AScale := 2.5, AValue := 10',
    LOldSignature,
    LNewSignature,
    LDelta,
    [TRadIADelphiArgumentBinding.Create('ATrace', 'False')]
  );
  Assert.IsTrue(TRadIADelphiCallRewrite.TryCreate(LRequest, LRewrite, LError), LError);
  Assert.AreEqual(
    'AMultiplier := 2.5, AInput := 10, ATrace := False',
    LRewrite.ArgumentText
  );
  Assert.IsTrue(LRewrite.UsedNamedArguments);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADelphiCallArgumentTests);

end.
