unit RadIA.Tests.BlockReviews;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIABlockReviews = class
  public
    [Test]
    procedure SeparatesIndependentChanges;
    [Test]
    procedure ComposesMixedBlockDecisions;
    [Test]
    procedure EditedDecisionUsesUserContent;
    [Test]
    procedure BlockIdentityIncludesRevisionAndContent;
    [Test]
    procedure PreservesWindowsLineBreaks;
  end;

implementation

uses
  RadIA.Core.BlockReviews;

procedure TTestRadIABlockReviews.BlockIdentityIncludesRevisionAndContent;
var
  LFirst: TArray<TRadIABlockReview>;
  LSecond: TArray<TRadIABlockReview>;
begin
  LFirst := TRadIABlockReviewEngine.Build(
    'Unit1.pas',
    'revision-1',
    'old',
    'new'
  );
  LSecond := TRadIABlockReviewEngine.Build(
    'Unit1.pas',
    'revision-2',
    'old',
    'new'
  );
  Assert.AreNotEqual(LFirst[0].Id, LSecond[0].Id);
end;

procedure TTestRadIABlockReviews.ComposesMixedBlockDecisions;
var
  LBlocks: TArray<TRadIABlockReview>;
begin
  LBlocks := TRadIABlockReviewEngine.Build(
    'Unit1.pas',
    'revision',
    'one'#10'old a'#10'middle'#10'old b'#10'last',
    'one'#10'new a'#10'middle'#10'new b'#10'last'
  );
  LBlocks[0] := LBlocks[0].WithDecision(brdAccepted);
  LBlocks[1] := LBlocks[1].WithDecision(brdRejected);
  Assert.AreEqual(
    'one'#10'new a'#10'middle'#10'old b'#10'last',
    TRadIABlockReviewEngine.Compose(
      'one'#10'old a'#10'middle'#10'old b'#10'last',
      LBlocks
    )
  );
end;

procedure TTestRadIABlockReviews.EditedDecisionUsesUserContent;
var
  LBlocks: TArray<TRadIABlockReview>;
begin
  LBlocks := TRadIABlockReviewEngine.Build(
    'Unit1.pas',
    'revision',
    'before'#10'old'#10'after',
    'before'#10'generated'#10'after'
  );
  LBlocks[0] := LBlocks[0].WithDecision(brdEdited, 'reviewed');
  Assert.AreEqual(
    'before'#10'reviewed'#10'after',
    TRadIABlockReviewEngine.Compose(
      'before'#10'old'#10'after',
      LBlocks
    )
  );
end;

procedure TTestRadIABlockReviews.PreservesWindowsLineBreaks;
var
  LBlocks: TArray<TRadIABlockReview>;
begin
  LBlocks := TRadIABlockReviewEngine.Build(
    'Unit1.pas',
    'revision',
    'before'#13#10'old'#13#10'after',
    'before'#13#10'new'#13#10'after'
  );
  LBlocks[0] := LBlocks[0].WithDecision(brdAccepted);
  Assert.AreEqual(
    'before'#13#10'new'#13#10'after',
    TRadIABlockReviewEngine.Compose(
      'before'#13#10'old'#13#10'after',
      LBlocks
    )
  );
end;

procedure TTestRadIABlockReviews.SeparatesIndependentChanges;
var
  LBlocks: TArray<TRadIABlockReview>;
begin
  LBlocks := TRadIABlockReviewEngine.Build(
    'Unit1.pas',
    'revision',
    'one'#10'old a'#10'middle'#10'old b'#10'last',
    'one'#10'new a'#10'middle'#10'new b'#10'last'
  );
  Assert.AreEqual<Integer>(2, Length(LBlocks));
  Assert.AreEqual('Unit1.pas', LBlocks[0].TargetFile);
  Assert.AreEqual('revision', LBlocks[0].BaseRevision);
  Assert.AreEqual(2, LBlocks[0].OriginalStartLine);
  Assert.AreEqual(2, LBlocks[0].ProposedStartLine);
  Assert.AreEqual(1, LBlocks[0].ProposedLineCount);
  Assert.AreEqual('old a', LBlocks[0].OriginalText);
  Assert.AreEqual('new b', LBlocks[1].ProposedText);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIABlockReviews);

end.
