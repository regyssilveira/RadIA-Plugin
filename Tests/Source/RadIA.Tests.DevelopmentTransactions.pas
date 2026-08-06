unit RadIA.Tests.DevelopmentTransactions;

interface

uses
  System.Generics.Collections,
  DUnitX.TestFramework,
  RadIA.Core.DevelopmentTransactions;

type
  TRadIADevelopmentOperationAdapterStub = class(
    TInterfacedObject,
    IRadIADevelopmentOperationAdapter
  )
  private
    FApplied: TDictionary<string, Boolean>;
    FFailApplyId: string;
    FFailRevertId: string;
    function KeyOf(
      const AOperation: TRadIADevelopmentOperation
    ): string;
  public
    constructor Create;
    destructor Destroy; override;
    function Apply(
      const AOperation: TRadIADevelopmentOperation;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
    function Revert(
      const AOperation: TRadIADevelopmentOperation;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
    function IsApplied(
      const AOperation: TRadIADevelopmentOperation
    ): Boolean;
    property FailApplyId: string read FFailApplyId write FFailApplyId;
    property FailRevertId: string read FFailRevertId write FFailRevertId;
  end;

  [TestFixture]
  TRadIADevelopmentTransactionTests = class
  private
    FAdapter: TRadIADevelopmentOperationAdapterStub;
    FOperations: TArray<TRadIADevelopmentOperation>;
    FService: IRadIADevelopmentTransactionService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure AppliesAndRevertsCodeProjectAndDesignerOperations;
    [Test]
    procedure ApplyFailureCompensatesEarlierOperations;
    [Test]
    procedure RevertFailureRestoresAlreadyRevertedOperations;
    [Test]
    procedure RejectsDuplicateOperation;
    [Test]
    procedure ToolsDeclareCompositeRiskLevels;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.DevelopmentTransactionTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools;

{ TRadIADevelopmentOperationAdapterStub }

function TRadIADevelopmentOperationAdapterStub.Apply(
  const AOperation: TRadIADevelopmentOperation;
  out AErrorCode: string;
  out AErrorMessage: string
): Boolean;
begin
  Result := not SameText(AOperation.PreviewId, FFailApplyId);
  if Result then
  begin
    FApplied.AddOrSetValue(KeyOf(AOperation), True);
    AErrorCode := '';
    AErrorMessage := '';
  end
  else
  begin
    AErrorCode := 'apply_rejected';
    AErrorMessage := 'The fake operation rejected apply.';
  end;
end;

constructor TRadIADevelopmentOperationAdapterStub.Create;
begin
  inherited Create;
  FApplied := TDictionary<string, Boolean>.Create;
end;

destructor TRadIADevelopmentOperationAdapterStub.Destroy;
begin
  FApplied.Free;
  inherited Destroy;
end;

function TRadIADevelopmentOperationAdapterStub.IsApplied(
  const AOperation: TRadIADevelopmentOperation
): Boolean;
begin
  Result := FApplied.ContainsKey(KeyOf(AOperation));
end;

function TRadIADevelopmentOperationAdapterStub.KeyOf(
  const AOperation: TRadIADevelopmentOperation
): string;
begin
  Result := RadIADevelopmentOperationKindName(AOperation.Kind) +
    ':' + LowerCase(AOperation.PreviewId);
end;

function TRadIADevelopmentOperationAdapterStub.Revert(
  const AOperation: TRadIADevelopmentOperation;
  out AErrorCode: string;
  out AErrorMessage: string
): Boolean;
begin
  Result := not SameText(AOperation.PreviewId, FFailRevertId);
  if Result then
  begin
    FApplied.Remove(KeyOf(AOperation));
    AErrorCode := '';
    AErrorMessage := '';
  end
  else
  begin
    AErrorCode := 'revert_rejected';
    AErrorMessage := 'The fake operation rejected revert.';
  end;
end;

{ TRadIADevelopmentTransactionTests }

procedure TRadIADevelopmentTransactionTests.AppliesAndRevertsCodeProjectAndDesignerOperations;
var
  LOperation: TRadIADevelopmentOperation;
  LPreview: TRadIADevelopmentTransactionResult;
begin
  LPreview := FService.Prepare(FOperations);
  Assert.IsTrue(FService.Apply(LPreview.Preview.Id).Success);
  for LOperation in FOperations do
    Assert.IsTrue(FAdapter.IsApplied(LOperation));

  Assert.IsTrue(FService.Revert(LPreview.Preview.Id).Success);

  for LOperation in FOperations do
    Assert.IsFalse(FAdapter.IsApplied(LOperation));
end;

procedure TRadIADevelopmentTransactionTests.ApplyFailureCompensatesEarlierOperations;
var
  LPreview: TRadIADevelopmentTransactionResult;
  LResult: TRadIADevelopmentTransactionResult;
begin
  FAdapter.FailApplyId := 'designer-component';
  LPreview := FService.Prepare(FOperations);

  LResult := FService.Apply(LPreview.Preview.Id);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('apply_rejected', LResult.ErrorCode);
  Assert.IsFalse(FAdapter.IsApplied(FOperations[0]));
  Assert.IsFalse(FAdapter.IsApplied(FOperations[1]));
end;

procedure TRadIADevelopmentTransactionTests.RejectsDuplicateOperation;
var
  LResult: TRadIADevelopmentTransactionResult;
begin
  LResult := FService.Prepare([
    FOperations[0],
    FOperations[0]
  ]);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_operation', LResult.ErrorCode);
end;

procedure TRadIADevelopmentTransactionTests.RevertFailureRestoresAlreadyRevertedOperations;
var
  LPreview: TRadIADevelopmentTransactionResult;
  LResult: TRadIADevelopmentTransactionResult;
begin
  LPreview := FService.Prepare(FOperations);
  Assert.IsTrue(FService.Apply(LPreview.Preview.Id).Success);
  FAdapter.FailRevertId := 'project-file';

  LResult := FService.Revert(LPreview.Preview.Id);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('revert_rejected', LResult.ErrorCode);
  Assert.IsTrue(FAdapter.IsApplied(FOperations[0]));
  Assert.IsTrue(FAdapter.IsApplied(FOperations[1]));
  Assert.IsTrue(FAdapter.IsApplied(FOperations[2]));
end;

procedure TRadIADevelopmentTransactionTests.Setup;
begin
  FAdapter := TRadIADevelopmentOperationAdapterStub.Create;
  FService := TRadIADevelopmentTransactionService.Create(FAdapter);
  FOperations := [
    TRadIADevelopmentOperation.Create(
      dokMultiFilePatch,
      'code-patch'
    ),
    TRadIADevelopmentOperation.Create(
      dokProjectFile,
      'project-file'
    ),
    TRadIADevelopmentOperation.Create(
      dokDesignerComponent,
      'designer-component'
    )
  ];
end;

procedure TRadIADevelopmentTransactionTests.TearDown;
begin
  FService := nil;
  FAdapter := nil;
end;

procedure TRadIADevelopmentTransactionTests.ToolsDeclareCompositeRiskLevels;
var
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIADevelopmentTransactionTools(LRegistry, FService);
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('PrepareDevelopmentTransaction').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    LRegistry.Resolve('ApplyDevelopmentTransaction').Descriptor.Risk
  );
  Assert.AreEqual(
    trReversibleWrite,
    LRegistry.Resolve('RevertDevelopmentTransaction').Descriptor.Risk
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADevelopmentTransactionTests);

end.
