unit RadIA.Tests.BlockReviewSessions;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.BlockReviews,
  RadIA.Core.BlockReviewSessions,
  RadIA.Core.Tools,
  RadIA.Tests.MultiFilePatches;

type
  TRadIABlockReviewVisualStub = class(
    TInterfacedObject,
    IRadIABlockReviewVisualFacade
  )
  private
    FBlocks: TArray<TRadIABlockReview>;
    FClearCount: Integer;
    FShowCount: Integer;
  public
    procedure ShowBlocks(const ABlocks: TArray<TRadIABlockReview>);
    procedure ClearBlocks;
    property Blocks: TArray<TRadIABlockReview> read FBlocks;
    property ClearCount: Integer read FClearCount;
    property ShowCount: Integer read FShowCount;
  end;

  [TestFixture]
  TTestRadIABlockReviewSessions = class
  private
    FFirstFile: string;
    FRootPath: string;
    FRegistry: IRadIAToolRegistry;
    FSecondFile: string;
    FService: IRadIABlockReviewSession;
    FVisual: TRadIABlockReviewVisualStub;
    FWorkspace: TRadIAMultiFileWorkspaceStub;
    function RevisionOf(const AFileName: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure PublishesAndOrdersMultiFileBlocks;
    [Test]
    procedure RequiresEveryDecisionBeforeApply;
    [Test]
    procedure AppliesMixedDecisionsAsOneTransaction;
    [Test]
    procedure RejectsAllWithoutWriting;
    [Test]
    procedure RejectsStaleFileWithoutPartialWrites;
    [Test]
    procedure PrepareToolPublishesReviewSession;
    [Test]
    procedure RegistersBlockReviewToolsWithSafeRisks;
    [Test]
    procedure RefreshesAndClearsVisualProjection;
    [Test]
    procedure RequestsChangesWithCommentWithoutWriting;
    [Test]
    procedure ToolRecordsAndListsChangeRequestComment;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.BlockReviewTools,
  RadIA.Core.MultiFilePatches,
  RadIA.Core.MultiFilePatchTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.WorkspaceBoundary;

procedure TRadIABlockReviewVisualStub.ClearBlocks;
begin
  Inc(FClearCount);
  FBlocks := nil;
end;

procedure TRadIABlockReviewVisualStub.ShowBlocks(
  const ABlocks: TArray<TRadIABlockReview>
);
begin
  Inc(FShowCount);
  FBlocks := Copy(ABlocks);
end;

function TTestRadIABlockReviewSessions.RevisionOf(
  const AFileName: string
): string;
begin
  Result := FWorkspace.ReadContent(AFileName, -1).Revision;
end;

procedure TTestRadIABlockReviewSessions.AppliesMixedDecisionsAsOneTransaction;
var
  LBlocks: TArray<TRadIABlockReview>;
  LResult: TRadIABlockReviewSessionResult;
begin
  Assert.IsTrue(FService.PublishFile(
    FFirstFile,
    RevisionOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile),
    'one'#10'new a'#10'middle'#10'new b'#10'last'
  ).Success);
  Assert.IsTrue(FService.PublishFile(
    FSecondFile,
    RevisionOf(FSecondFile),
    FWorkspace.ContentOf(FSecondFile),
    'second changed'
  ).Success);
  LBlocks := FService.ListBlocks;
  Assert.IsTrue(FService.Decide(LBlocks[0].Id, brdAccepted).Success);
  Assert.IsTrue(FService.Decide(LBlocks[1].Id, brdRejected).Success);
  Assert.IsTrue(FService.Decide(LBlocks[2].Id, brdAccepted).Success);
  LResult := FService.Apply;
  Assert.IsTrue(LResult.Success);
  Assert.IsNotEmpty(LResult.TransactionId);
  Assert.AreEqual(
    'one'#10'new a'#10'middle'#10'old b'#10'last',
    FWorkspace.ContentOf(FFirstFile)
  );
  Assert.AreEqual('second changed', FWorkspace.ContentOf(FSecondFile));
  Assert.AreEqual(0, FService.GetStatus.FileCount);
end;

procedure TTestRadIABlockReviewSessions.PublishesAndOrdersMultiFileBlocks;
var
  LBlocks: TArray<TRadIABlockReview>;
  LStatus: TRadIABlockReviewSessionStatus;
begin
  Assert.IsTrue(FService.PublishFile(
    FSecondFile,
    RevisionOf(FSecondFile),
    FWorkspace.ContentOf(FSecondFile),
    'second changed'
  ).Success);
  Assert.IsTrue(FService.PublishFile(
    FFirstFile,
    RevisionOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile),
    'one'#10'new a'#10'middle'#10'new b'#10'last'
  ).Success);
  LBlocks := FService.ListBlocks;
  LStatus := FService.GetStatus;
  Assert.AreEqual<Integer>(3, Length(LBlocks));
  Assert.AreEqual(FFirstFile, LBlocks[0].TargetFile);
  Assert.AreEqual(2, LStatus.FileCount);
  Assert.AreEqual(3, LStatus.BlockCount);
  Assert.AreEqual(3, LStatus.PendingCount);
end;

procedure TTestRadIABlockReviewSessions.PrepareToolPublishesReviewSession;
var
  LArguments: string;
  LResult: TRadIAToolResult;
begin
  LArguments := Format(
    '{"files":[{"targetFile":"%s","baseRevision":"%s",' +
    '"proposedContent":"second changed"}]}',
    [
      StringReplace(FSecondFile, '\', '\\', [rfReplaceAll]),
      RevisionOf(FSecondFile)
    ]
  );
  LResult := FRegistry.Resolve('PrepareMultiFilePatch').Execute(
    TRadIAToolRequest.Create(
      'PrepareMultiFilePatch',
      LArguments,
      'correlation',
      'test',
      'session',
      'project',
      'workspace'
    )
  );
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(1, FService.GetStatus.FileCount);
  Assert.AreEqual(1, FService.GetStatus.BlockCount);
end;

procedure TTestRadIABlockReviewSessions.RejectsAllWithoutWriting;
var
  LBlock: TRadIABlockReview;
  LOriginal: string;
begin
  LOriginal := FWorkspace.ContentOf(FFirstFile);
  Assert.IsTrue(FService.PublishFile(
    FFirstFile,
    RevisionOf(FFirstFile),
    LOriginal,
    LOriginal.Replace('old a', 'new a')
  ).Success);
  for LBlock in FService.ListBlocks do
    Assert.IsTrue(FService.Decide(LBlock.Id, brdRejected).Success);
  Assert.IsTrue(FService.Apply.Success);
  Assert.AreEqual(LOriginal, FWorkspace.ContentOf(FFirstFile));
end;

procedure TTestRadIABlockReviewSessions.RefreshesAndClearsVisualProjection;
var
  LBlock: TRadIABlockReview;
begin
  Assert.IsTrue(FService.PublishFile(
    FFirstFile,
    RevisionOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile).Replace('old a', 'new a')
  ).Success);
  Assert.AreEqual(1, FVisual.ShowCount);
  Assert.AreEqual<Integer>(1, Length(FVisual.Blocks));
  LBlock := FService.ListBlocks[0];
  Assert.IsTrue(FService.Decide(LBlock.Id, brdAccepted).Success);
  Assert.AreEqual(2, FVisual.ShowCount);
  Assert.AreEqual<Integer>(Ord(brdAccepted), Ord(FVisual.Blocks[0].Decision));
  Assert.IsTrue(FService.Apply.Success);
  Assert.AreEqual(1, FVisual.ClearCount);
  Assert.AreEqual<Integer>(0, Length(FVisual.Blocks));
end;

procedure TTestRadIABlockReviewSessions.RequestsChangesWithCommentWithoutWriting;
var
  LBlock: TRadIABlockReview;
  LOriginal: string;
  LResult: TRadIABlockReviewSessionResult;
begin
  LOriginal := FWorkspace.ContentOf(FFirstFile);
  Assert.IsTrue(FService.PublishFile(
    FFirstFile,
    RevisionOf(FFirstFile),
    LOriginal,
    LOriginal.Replace('old a', 'new a')
  ).Success);
  LBlock := FService.ListBlocks[0];
  LResult := FService.Decide(
    LBlock.Id,
    brdChangesRequested,
    '',
    'Keep the public behavior and add a boundary test.'
  );
  Assert.IsTrue(LResult.Success);
  LBlock := FService.ListBlocks[0];
  Assert.AreEqual<Integer>(
    Ord(brdChangesRequested),
    Ord(LBlock.Decision)
  );
  Assert.AreEqual(
    'Keep the public behavior and add a boundary test.',
    LBlock.Comment
  );
  Assert.AreEqual(1, FService.GetStatus.PendingCount);
  Assert.AreEqual(LOriginal, FWorkspace.ContentOf(FFirstFile));
  LResult := FService.Apply;
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('pending_decisions', LResult.ErrorCode);
end;

procedure TTestRadIABlockReviewSessions.ToolRecordsAndListsChangeRequestComment;
var
  LArguments: string;
  LBlock: TRadIABlockReview;
  LResult: TRadIAToolResult;
begin
  Assert.IsTrue(FService.PublishFile(
    FFirstFile,
    RevisionOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile).Replace('old a', 'new a')
  ).Success);
  LBlock := FService.ListBlocks[0];
  LArguments := Format(
    '{"blockId":"%s","decision":"request-changes",' +
    '"comment":"Add a regression test."}',
    [LBlock.Id]
  );
  LResult := FRegistry.Resolve('DecideBlockReview').Execute(
    TRadIAToolRequest.Create('DecideBlockReview', LArguments, 'test')
  );
  Assert.IsTrue(LResult.Success);
  LResult := FRegistry.Resolve('ListBlockReviews').Execute(
    TRadIAToolRequest.Create('ListBlockReviews', '{}', 'test')
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'changes-requested');
  Assert.Contains(LResult.ContentJson, 'Add a regression test.');

  LResult := FRegistry.Resolve('DecideBlockReview').Execute(
    TRadIAToolRequest.Create(
      'DecideBlockReview',
      Format(
        '{"blockId":"%s","decision":"request-changes"}',
        [LBlock.Id]
      ),
      'test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('comment_required', LResult.ErrorCode);
end;

procedure TTestRadIABlockReviewSessions.RegistersBlockReviewToolsWithSafeRisks;
begin
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('ListBlockReviews').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('DecideBlockReview').Descriptor.Risk
  );
  Assert.AreEqual(
    trReversibleWrite,
    FRegistry.Resolve('ApplyBlockReviews').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('ClearBlockReviews').Descriptor.Risk
  );
end;

procedure TTestRadIABlockReviewSessions.RejectsStaleFileWithoutPartialWrites;
var
  LBlock: TRadIABlockReview;
  LResult: TRadIABlockReviewSessionResult;
  LSecondOriginal: string;
begin
  LSecondOriginal := FWorkspace.ContentOf(FSecondFile);
  Assert.IsTrue(FService.PublishFile(
    FFirstFile,
    RevisionOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile).Replace('old a', 'new a')
  ).Success);
  Assert.IsTrue(FService.PublishFile(
    FSecondFile,
    RevisionOf(FSecondFile),
    LSecondOriginal,
    'second changed'
  ).Success);
  for LBlock in FService.ListBlocks do
    Assert.IsTrue(FService.Decide(LBlock.Id, brdAccepted).Success);
  FWorkspace.AddFile(FFirstFile, 'external change');
  LResult := FService.Apply;
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
  Assert.AreEqual(LSecondOriginal, FWorkspace.ContentOf(FSecondFile));
end;

procedure TTestRadIABlockReviewSessions.RequiresEveryDecisionBeforeApply;
var
  LResult: TRadIABlockReviewSessionResult;
begin
  Assert.IsTrue(FService.PublishFile(
    FFirstFile,
    RevisionOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile),
    FWorkspace.ContentOf(FFirstFile).Replace('old a', 'new a')
  ).Success);
  LResult := FService.Apply;
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('pending_decisions', LResult.ErrorCode);
end;

procedure TTestRadIABlockReviewSessions.Setup;
var
  LBoundary: IRadIAWorkspaceBoundary;
  LPatchService: IRadIAMultiFilePatchService;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIABlockReviewSession-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  FFirstFile := TPath.Combine(FRootPath, 'First.pas');
  FSecondFile := TPath.Combine(FRootPath, 'Second.pas');
  FWorkspace := TRadIAMultiFileWorkspaceStub.Create(FRootPath);
  FWorkspace.AddFile(
    FFirstFile,
    'one'#10'old a'#10'middle'#10'old b'#10'last'
  );
  FWorkspace.AddFile(FSecondFile, 'second original');
  LBoundary := TRadIAWorkspaceBoundary.Create;
  LPatchService := TRadIAMultiFilePatchService.Create(
    FWorkspace,
    FWorkspace,
    LBoundary
  );
  FVisual := TRadIABlockReviewVisualStub.Create;
  FService := TRadIABlockReviewSession.Create(LPatchService, FVisual);
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAMultiFilePatchTools(FRegistry, LPatchService, FService);
  RegisterRadIABlockReviewTools(FRegistry, FService);
end;

procedure TTestRadIABlockReviewSessions.TearDown;
begin
  FService := nil;
  FVisual := nil;
  FRegistry := nil;
  FWorkspace := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIABlockReviewSessions);

end.
