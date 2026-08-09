unit RadIA.Tests.BlockReviewSessions;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.BlockReviewSessions,
  RadIA.Core.Tools,
  RadIA.Tests.MultiFilePatches;

type
  [TestFixture]
  TTestRadIABlockReviewSessions = class
  private
    FFirstFile: string;
    FRootPath: string;
    FRegistry: IRadIAToolRegistry;
    FSecondFile: string;
    FService: IRadIABlockReviewSession;
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
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.BlockReviewTools,
  RadIA.Core.BlockReviews,
  RadIA.Core.MultiFilePatches,
  RadIA.Core.MultiFilePatchTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.WorkspaceBoundary;

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
  FService := TRadIABlockReviewSession.Create(LPatchService);
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAMultiFilePatchTools(FRegistry, LPatchService, FService);
  RegisterRadIABlockReviewTools(FRegistry, FService);
end;

procedure TTestRadIABlockReviewSessions.TearDown;
begin
  FService := nil;
  FRegistry := nil;
  FWorkspace := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIABlockReviewSessions);

end.
