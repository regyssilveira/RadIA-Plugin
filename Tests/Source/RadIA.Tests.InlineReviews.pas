unit RadIA.Tests.InlineReviews;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.InlineReviews,
  RadIA.Core.Patches,
  RadIA.Core.Tools,
  RadIA.Tests.Patches;

type
  TRadIAFakeInlineReviewVisual = class(
    TInterfacedObject,
    IRadIAInlineReviewVisualFacade
  )
  private
    FClearCount: Integer;
    FReviews: TArray<TRadIAInlineReview>;
  public
    procedure ShowReviews(
      const AFileName: string;
      const ARevision: string;
      const AReviews: TArray<TRadIAInlineReview>
    );
    procedure ClearReviews;
    property ClearCount: Integer read FClearCount;
    property Reviews: TArray<TRadIAInlineReview> read FReviews;
  end;

  [TestFixture]
  TTestRadIAInlineReviews = class
  private
    FFileName: string;
    FPatchService: IRadIAPatchService;
    FRegistry: IRadIAToolRegistry;
    FRootPath: string;
    FService: IRadIAInlineReviewService;
    FVisual: TRadIAFakeInlineReviewVisual;
    FWorkspace: TTestRadIAPatchWorkspace;
    function BuildReview(
      const AStartLine: Integer;
      const AEndLine: Integer
    ): TRadIAInlineReview;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure PublishesAndRendersCurrentReview;
    [Test]
    procedure HidesReviewAfterRevisionChanges;
    [Test]
    procedure RejectsInvalidLineRange;
    [Test]
    procedure PreparesSuggestionWithPatchService;
    [Test]
    procedure AppliesSuggestionAndRemovesReview;
    [Test]
    procedure RoutesLargeSuggestionToSmartDiff;
    [Test]
    procedure RejectsSuggestionWithoutChangingBuffer;
    [Test]
    procedure RemovesAndClearsReviews;
    [Test]
    procedure RegistersExpectedRiskLevels;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.InlineReviewTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.WorkspaceBoundary;

procedure TRadIAFakeInlineReviewVisual.ClearReviews;
begin
  Inc(FClearCount);
  SetLength(FReviews, 0);
end;

procedure TRadIAFakeInlineReviewVisual.ShowReviews(
  const AFileName: string;
  const ARevision: string;
  const AReviews: TArray<TRadIAInlineReview>
);
begin
  FReviews := Copy(AReviews);
end;

function TTestRadIAInlineReviews.BuildReview(
  const AStartLine: Integer;
  const AEndLine: Integer
): TRadIAInlineReview;
begin
  Result := TRadIAInlineReview.Create(
    '',
    FFileName,
    FWorkspace.GetEditorContent(-1).Revision,
    AStartLine,
    AEndLine,
    irsWarning
  );
  Result.SetContent(
    'Use a descriptive constant name.',
    'OldValue',
    'NewValue'
  );
end;

procedure TTestRadIAInlineReviews.HidesReviewAfterRevisionChanges;
begin
  Assert.IsTrue(FService.Publish(BuildReview(2, 2)).Success);
  FWorkspace.Content := FWorkspace.Content + sLineBreak + '// Edit';
  Assert.AreEqual<Integer>(0, Length(FService.ListCurrent));
  Assert.AreEqual<Integer>(0, Length(FVisual.Reviews));
end;

procedure TTestRadIAInlineReviews.AppliesSuggestionAndRemovesReview;
var
  LApply: TRadIAPatchResult;
  LPublish: TRadIAInlineReviewResult;
begin
  LPublish := FService.Publish(BuildReview(2, 2));
  LApply := FService.ApplyFix(LPublish.Review.Id);
  Assert.IsTrue(LApply.Success);
  Assert.Contains(FWorkspace.Content, 'NewValue');
  Assert.AreEqual<Integer>(0, Length(FService.ListCurrent));
end;

procedure TTestRadIAInlineReviews.PreparesSuggestionWithPatchService;
var
  LPatch: TRadIAPatchResult;
  LPublish: TRadIAInlineReviewResult;
begin
  LPublish := FService.Publish(BuildReview(2, 2));
  LPatch := FService.PrepareFix(LPublish.Review.Id);
  Assert.IsTrue(LPatch.Success);
  Assert.Contains(LPatch.Preview.ProposedContent, 'NewValue');
  Assert.Contains(LPatch.Preview.OriginalContent, 'OldValue');
end;

procedure TTestRadIAInlineReviews.PublishesAndRendersCurrentReview;
var
  LResult: TRadIAInlineReviewResult;
begin
  LResult := FService.Publish(BuildReview(2, 2));
  Assert.IsTrue(LResult.Success);
  Assert.IsNotEmpty(LResult.Review.Id);
  Assert.AreEqual<Integer>(1, Length(FService.ListCurrent));
  Assert.AreEqual<Integer>(1, Length(FVisual.Reviews));
end;

procedure TTestRadIAInlineReviews.RegistersExpectedRiskLevels;
begin
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('PublishInlineReview').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('ListInlineReviews').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('PrepareInlineReviewFix').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    FRegistry.Resolve('ApplyInlineReviewFix').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('RejectInlineReview').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('ClearInlineReviews').Descriptor.Risk
  );
end;

procedure TTestRadIAInlineReviews.RejectsInvalidLineRange;
var
  LResult: TRadIAInlineReviewResult;
begin
  LResult := FService.Publish(BuildReview(2, 10));
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_review', LResult.ErrorCode);
end;

procedure TTestRadIAInlineReviews.RejectsSuggestionWithoutChangingBuffer;
var
  LOriginalContent: string;
  LPublish: TRadIAInlineReviewResult;
begin
  LOriginalContent := FWorkspace.Content;
  LPublish := FService.Publish(BuildReview(2, 2));
  Assert.IsTrue(FService.Reject(LPublish.Review.Id));
  Assert.AreEqual(LOriginalContent, FWorkspace.Content);
  Assert.AreEqual<Integer>(0, Length(FService.ListCurrent));
end;

procedure TTestRadIAInlineReviews.RoutesLargeSuggestionToSmartDiff;
var
  LApply: TRadIAPatchResult;
  LPublish: TRadIAInlineReviewResult;
  LReview: TRadIAInlineReview;
begin
  LReview := BuildReview(2, 2);
  LReview.SetContent(
    'Review a large generated replacement.',
    'OldValue',
    StringOfChar('N', 4097)
  );
  Assert.IsTrue(LReview.RequiresSmartDiff);
  LPublish := FService.Publish(LReview);
  Assert.IsTrue(LPublish.Success);
  LApply := FService.ApplyFix(LPublish.Review.Id);
  Assert.IsFalse(LApply.Success);
  Assert.AreEqual('smart_diff_required', LApply.ErrorCode);
  Assert.Contains(FWorkspace.Content, 'OldValue');
  Assert.AreEqual<Integer>(1, Length(FService.ListCurrent));
end;

procedure TTestRadIAInlineReviews.RemovesAndClearsReviews;
var
  LFirst: TRadIAInlineReviewResult;
  LSecond: TRadIAInlineReviewResult;
begin
  LFirst := FService.Publish(BuildReview(1, 1));
  LSecond := FService.Publish(BuildReview(2, 2));
  Assert.IsTrue(FService.Remove(LFirst.Review.Id));
  Assert.AreEqual<Integer>(1, Length(FService.ListCurrent));
  FService.Clear;
  Assert.AreEqual<Integer>(0, Length(FService.ListCurrent));
  Assert.IsTrue(FVisual.ClearCount > 0);
  Assert.IsNotEmpty(LSecond.Review.Id);
end;

procedure TTestRadIAInlineReviews.Setup;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIAInlineReviews-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  FFileName := TPath.Combine(FRootPath, 'UnitOne.pas');
  FWorkspace := TTestRadIAPatchWorkspace.Create(
    FRootPath,
    FFileName,
    'unit UnitOne;' + sLineBreak +
    'const Value = ''OldValue'';' + sLineBreak +
    'end.'
  );
  FPatchService := TRadIAPatchService.Create(
    FWorkspace,
    FWorkspace,
    TRadIAWorkspaceBoundary.Create
  );
  FVisual := TRadIAFakeInlineReviewVisual.Create;
  FService := TRadIAInlineReviewService.Create(
    FWorkspace,
    TRadIAWorkspaceBoundary.Create,
    FPatchService,
    FVisual
  );
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAInlineReviewTools(FRegistry, FService);
end;

procedure TTestRadIAInlineReviews.TearDown;
begin
  FRegistry := nil;
  FService := nil;
  FVisual := nil;
  FPatchService := nil;
  FWorkspace := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAInlineReviews);

end.
