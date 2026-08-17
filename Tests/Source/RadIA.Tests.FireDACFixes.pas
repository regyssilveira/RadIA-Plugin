unit RadIA.Tests.FireDACFixes;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACFixTests = class
  public
    [Test]
    procedure RegistersPrepareAndMutationRisks;
    [Test]
    procedure ParameterFixBuildsOnlySupportedAccessorReplacement;
    [Test]
    procedure TransactionFixBuildsRollbackAtValidatedIndent;
    [Test]
    procedure RequiresProvenMatchingFinding;
    [Test]
    procedure ApplyAndRevertAcceptOnlyOwnedPreviewInOrder;
    [Test]
    procedure FailedMutationRestoresPreviousState;
    [Test]
    procedure GenericFixRoutesOnlySupportedRules;
  end;

implementation

uses
  System.DateUtils,
  System.SysUtils,
  RadIA.Core.FireDAC.Fixes,
  RadIA.Core.Patches,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools;

type
  TRadIAFireDACPatchStub = class(TInterfacedObject, IRadIAPatchService)
  private
    FApplyCount: Integer;
    FFailApply: Boolean;
    FFailRevert: Boolean;
    FLastSpec: TRadIAPatchSpec;
    FRevertCount: Integer;
  public
    function Apply(const APreviewId: string): TRadIAPatchResult;
    procedure Clear;
    function Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
    property ApplyCount: Integer read FApplyCount;
    property FailApply: Boolean read FFailApply write FFailApply;
    property FailRevert: Boolean read FFailRevert write FFailRevert;
    property LastSpec: TRadIAPatchSpec read FLastSpec;
    property RevertCount: Integer read FRevertCount;
  end;

function TRadIAFireDACPatchStub.Apply(
  const APreviewId: string
): TRadIAPatchResult;
begin
  Inc(FApplyCount);
  if FFailApply then
    Exit(TRadIAPatchResult.Failed('apply_failed', 'Expected test failure.'));
  Result := TRadIAPatchResult.Succeeded(TRadIAPatchPreview.Create(
    APreviewId,
    FLastSpec,
    FLastSpec.OriginalText,
    FLastSpec.ReplacementText,
    'proposed-revision',
    IncMinute(Now, 10)
  ));
end;

procedure TRadIAFireDACPatchStub.Clear;
begin
  FLastSpec := Default(TRadIAPatchSpec);
end;

function TRadIAFireDACPatchStub.Prepare(
  const ASpec: TRadIAPatchSpec
): TRadIAPatchResult;
begin
  FLastSpec := ASpec;
  Result := TRadIAPatchResult.Succeeded(TRadIAPatchPreview.Create(
    'firedac-preview',
    ASpec,
    ASpec.OriginalText,
    ASpec.ReplacementText,
    'proposed-revision',
    IncMinute(Now, 10)
  ));
end;

function TRadIAFireDACPatchStub.Revert(
  const APreviewId: string
): TRadIAPatchResult;
begin
  Inc(FRevertCount);
  if FFailRevert then
    Exit(TRadIAPatchResult.Failed('revert_failed', 'Expected test failure.'));
  Result := TRadIAPatchResult.Succeeded(TRadIAPatchPreview.Create(
    APreviewId,
    FLastSpec,
    FLastSpec.OriginalText,
    FLastSpec.ReplacementText,
    'proposed-revision',
    IncMinute(Now, 10)
  ));
end;

function CreateRegistry(
  const APatches: IRadIAPatchService
): IRadIAToolRegistry;
begin
  Result := TRadIAToolRegistry.Create;
  RegisterRadIAFireDACFixTools(Result, APatches);
end;

function ParameterArguments: string;
begin
  Result :=
    '{"findingId":"firedac.parameter.accessor-mismatch:unit:12:name",' +
    '"confidence":"proven","targetFile":"Source\\RadIA.Data.pas",' +
    '"baseRevision":"base","queryVariable":"CustomerQuery",' +
    '"parameterName":"CustomerId","fromAccessor":"AsString",' +
    '"toAccessor":"AsLargeInt"}';
end;

procedure TRadIAFireDACFixTests.RegistersPrepareAndMutationRisks;
var
  LPatches: IRadIAPatchService;
  LRegistry: IRadIAToolRegistry;
begin
  LPatches := TRadIAFireDACPatchStub.Create;
  LRegistry := CreateRegistry(LPatches);
  Assert.AreEqual(trReadOnly, LRegistry.Resolve('PrepareFireDACParameterFix').Descriptor.Risk);
  Assert.AreEqual(trReadOnly, LRegistry.Resolve('PrepareFireDACTransactionFix').Descriptor.Risk);
  Assert.AreEqual(trReadOnly, LRegistry.Resolve('PrepareFireDACFix').Descriptor.Risk);
  Assert.AreEqual(trReversibleWrite, LRegistry.Resolve('ApplyFireDACFix').Descriptor.Risk);
  Assert.AreEqual(trReversibleWrite, LRegistry.Resolve('RevertFireDACFix').Descriptor.Risk);
end;

procedure TRadIAFireDACFixTests.
  ParameterFixBuildsOnlySupportedAccessorReplacement;
var
  LPatchObject: TRadIAFireDACPatchStub;
  LPatches: IRadIAPatchService;
  LResult: TRadIAToolResult;
begin
  LPatchObject := TRadIAFireDACPatchStub.Create;
  LPatches := LPatchObject;
  LResult := CreateRegistry(LPatches).Resolve('PrepareFireDACParameterFix').Execute(
    TRadIAToolRequest.Create(
      'PrepareFireDACParameterFix',
      ParameterArguments,
      'firedac-fix-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.AreEqual(
    'CustomerQuery.ParamByName(''CustomerId'').AsString',
    LPatchObject.LastSpec.OriginalText
  );
  Assert.AreEqual(
    'CustomerQuery.ParamByName(''CustomerId'').AsLargeInt',
    LPatchObject.LastSpec.ReplacementText
  );
  Assert.Contains(LResult.ContentJson, '"mutationApplied":false');
  Assert.DoesNotContain(LResult.ContentJson, 'originalContent');
end;

procedure TRadIAFireDACFixTests.
  TransactionFixBuildsRollbackAtValidatedIndent;
var
  LPatchObject: TRadIAFireDACPatchStub;
  LPatches: IRadIAPatchService;
  LResult: TRadIAToolResult;
begin
  LPatchObject := TRadIAFireDACPatchStub.Create;
  LPatches := LPatchObject;
  LResult := CreateRegistry(LPatches).Resolve('PrepareFireDACTransactionFix').Execute(
    TRadIAToolRequest.Create(
      'PrepareFireDACTransactionFix',
      '{"findingId":"firedac.transaction.rollback-missing:unit:20",' +
      '"confidence":"proven","targetFile":"Source\\RadIA.Data.pas",' +
      '"baseRevision":"base","transactionVariable":"Transaction",' +
      '"indentLevel":2}',
      'firedac-fix-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.AreEqual('    except', LPatchObject.LastSpec.OriginalText);
  Assert.Contains(LPatchObject.LastSpec.ReplacementText, 'Transaction.Rollback;');
end;

procedure TRadIAFireDACFixTests.RequiresProvenMatchingFinding;
var
  LPatches: IRadIAPatchService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LPatches := TRadIAFireDACPatchStub.Create;
  LRegistry := CreateRegistry(LPatches);
  LResult := LRegistry.Resolve('PrepareFireDACParameterFix').Execute(
    TRadIAToolRequest.Create(
      'PrepareFireDACParameterFix',
      StringReplace(ParameterArguments, '"proven"', '"strong"', []),
      'firedac-fix-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('fix_not_proven', LResult.ErrorCode);
  LResult := LRegistry.Resolve('PrepareFireDACParameterFix').Execute(
    TRadIAToolRequest.Create(
      'PrepareFireDACParameterFix',
      StringReplace(ParameterArguments, 'firedac.parameter', 'firedac.transaction', []),
      'firedac-fix-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('finding_mismatch', LResult.ErrorCode);
end;

procedure TRadIAFireDACFixTests.
  ApplyAndRevertAcceptOnlyOwnedPreviewInOrder;
var
  LPatchObject: TRadIAFireDACPatchStub;
  LPatches: IRadIAPatchService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LPatchObject := TRadIAFireDACPatchStub.Create;
  LPatches := LPatchObject;
  LRegistry := CreateRegistry(LPatches);
  LResult := LRegistry.Resolve('ApplyFireDACFix').Execute(TRadIAToolRequest.Create(
    'ApplyFireDACFix',
    '{"previewId":"foreign-preview"}',
    'firedac-fix-test'
  ));
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('foreign_preview', LResult.ErrorCode);
  LRegistry.Resolve('PrepareFireDACParameterFix').Execute(TRadIAToolRequest.Create(
    'PrepareFireDACParameterFix',
    ParameterArguments,
    'firedac-fix-test'
  ));
  LResult := LRegistry.Resolve('RevertFireDACFix').Execute(TRadIAToolRequest.Create(
    'RevertFireDACFix',
    '{"previewId":"firedac-preview"}',
    'firedac-fix-test'
  ));
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_state', LResult.ErrorCode);
  LResult := LRegistry.Resolve('ApplyFireDACFix').Execute(TRadIAToolRequest.Create(
    'ApplyFireDACFix',
    '{"previewId":"firedac-preview"}',
    'firedac-fix-test'
  ));
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.AreEqual(1, LPatchObject.ApplyCount);
  LResult := LRegistry.Resolve('RevertFireDACFix').Execute(TRadIAToolRequest.Create(
    'RevertFireDACFix',
    '{"previewId":"firedac-preview"}',
    'firedac-fix-test'
  ));
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.AreEqual(1, LPatchObject.RevertCount);
end;

procedure TRadIAFireDACFixTests.GenericFixRoutesOnlySupportedRules;
var
  LPatches: IRadIAPatchService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LPatches := TRadIAFireDACPatchStub.Create;
  LRegistry := CreateRegistry(LPatches);
  LResult := LRegistry.Resolve('PrepareFireDACFix').Execute(TRadIAToolRequest.Create(
    'PrepareFireDACFix',
    '{"ruleId":"firedac.unknown"}',
    'firedac-fix-test'
  ));
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('unsupported_rule', LResult.ErrorCode);
end;

procedure TRadIAFireDACFixTests.FailedMutationRestoresPreviousState;
var
  LPatchObject: TRadIAFireDACPatchStub;
  LPatches: IRadIAPatchService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LPatchObject := TRadIAFireDACPatchStub.Create;
  LPatches := LPatchObject;
  LRegistry := CreateRegistry(LPatches);
  LRegistry.Resolve('PrepareFireDACParameterFix').Execute(TRadIAToolRequest.Create(
    'PrepareFireDACParameterFix',
    ParameterArguments,
    'firedac-fix-test'
  ));
  LPatchObject.FailApply := True;
  LResult := LRegistry.Resolve('ApplyFireDACFix').Execute(TRadIAToolRequest.Create(
    'ApplyFireDACFix',
    '{"previewId":"firedac-preview"}',
    'firedac-fix-test'
  ));
  Assert.IsFalse(LResult.Success);
  LPatchObject.FailApply := False;
  LResult := LRegistry.Resolve('ApplyFireDACFix').Execute(TRadIAToolRequest.Create(
    'ApplyFireDACFix',
    '{"previewId":"firedac-preview"}',
    'firedac-fix-test'
  ));
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  LPatchObject.FailRevert := True;
  LResult := LRegistry.Resolve('RevertFireDACFix').Execute(TRadIAToolRequest.Create(
    'RevertFireDACFix',
    '{"previewId":"firedac-preview"}',
    'firedac-fix-test'
  ));
  Assert.IsFalse(LResult.Success);
  LPatchObject.FailRevert := False;
  LResult := LRegistry.Resolve('RevertFireDACFix').Execute(TRadIAToolRequest.Create(
    'RevertFireDACFix',
    '{"previewId":"firedac-preview"}',
    'firedac-fix-test'
  ));
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACFixTests);

end.
