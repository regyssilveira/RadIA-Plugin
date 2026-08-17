unit RadIA.Tests.ResultCompactor;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAResultCompactor = class
  public
    [Test]
    procedure CompactsRepeatedDUnitXOutput;
    [Test]
    procedure PreservesBuildErrorsWhileReducingRoutineMessages;
    [Test]
    procedure CompactsKnowledgeContentWithProvenance;
    [Test]
    procedure InvalidJsonFallsBackWithoutException;
    [Test]
    procedure IncompleteAnsiSequenceDoesNotLeakControlCode;
    [Test]
    procedure OneMiBDiffMeetsPerformanceBudget;
    [Test]
    procedure LeavesUnsupportedToolResultUntouched;
    [Test]
    procedure TruncatesLargeDiffWithHeadAndTail;
    [Test]
    procedure PreservesCriticalTestFailureInsideLargeOutput;
    [Test]
    procedure PreservesDiffHeadersInsideLargeDiff;
    [Test]
    procedure CompactsLargeWorkspaceListWithProvenance;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.ResultCompactor;

procedure TTestRadIAResultCompactor.CompactsRepeatedDUnitXOutput;
var
  LCompaction: TRadIAResultCompaction;
  LResultJson: string;
begin
  LResultJson := '{"status":"succeeded","output":"' +
    'Running a deliberately verbose test fixture\r\n' +
    'Running a deliberately verbose test fixture\r\n' +
    'Running a deliberately verbose test fixture\r\nDone"}';
  LCompaction := TRadIAResultCompactor.Compact(
    'RunDUnitXTests',
    LResultJson
  );
  Assert.IsTrue(LCompaction.Compacted);
  Assert.Contains(LCompaction.CompactedJson, 'repeated 2 times');
  Assert.IsTrue(
    LCompaction.CompactedCharacters < LCompaction.OriginalCharacters
  );
end;

procedure TTestRadIAResultCompactor.PreservesBuildErrorsWhileReducingRoutineMessages;
var
  LCompaction: TRadIAResultCompaction;
  LIndex: Integer;
  LMessage: TJSONObject;
  LMessages: TJSONArray;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('status', 'failed');
    LMessages := TJSONArray.Create;
    for LIndex := 1 to 100 do
    begin
      LMessage := TJSONObject.Create;
      LMessage.AddPair('text', Format('Hint H%d: sanitized message', [LIndex]));
      LMessages.AddElement(LMessage);
    end;
    LMessage := TJSONObject.Create;
    LMessage.AddPair('text', 'Error E2003: Required critical evidence');
    LMessages.AddElement(LMessage);
    LRoot.AddPair('messages', LMessages);
    LCompaction := TRadIAResultCompactor.Compact('BuildProject', LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
  Assert.IsTrue(LCompaction.Compacted);
  Assert.Contains(LCompaction.CompactedJson, 'Error E2003');
  Assert.Contains(LCompaction.CompactedJson, 'omittedRoutineMessages');
end;

procedure TTestRadIAResultCompactor.CompactsKnowledgeContentWithProvenance;
var
  LCompaction: TRadIAResultCompaction;
  LContent: string;
begin
  LContent := 'HEAD' + StringOfChar('k', 10000) + 'TAIL';
  LCompaction := TRadIAResultCompactor.Compact(
    'SearchKnowledge',
    '{"results":[{"fileName":"Sample.pas","content":"' +
      LContent + '"}]}'
  );
  Assert.IsTrue(LCompaction.Compacted);
  Assert.Contains(LCompaction.CompactedJson, 'Sample.pas');
  Assert.Contains(LCompaction.CompactedJson, 'HEAD');
  Assert.Contains(LCompaction.CompactedJson, 'TAIL');
  Assert.Contains(LCompaction.CompactedJson, 'originalContentCharacters');
end;

procedure TTestRadIAResultCompactor.InvalidJsonFallsBackWithoutException;
var
  LCompaction: TRadIAResultCompaction;
begin
  LCompaction := TRadIAResultCompactor.Compact(
    'RunDUnitXTests',
    '{invalid-json'
  );
  Assert.IsFalse(LCompaction.Compacted);
  Assert.AreEqual('{invalid-json', LCompaction.CompactedJson);
end;

procedure TTestRadIAResultCompactor.IncompleteAnsiSequenceDoesNotLeakControlCode;
var
  LCompaction: TRadIAResultCompaction;
  LResultJson: string;
begin
  LResultJson := '{"output":"PASS\u001b[31"}';
  LCompaction := TRadIAResultCompactor.Compact(
    'RunDUnitXTests',
    LResultJson
  );
  Assert.IsTrue(LCompaction.Compacted);
  Assert.DoesNotContain(LCompaction.CompactedJson, '\u001b');
  Assert.Contains(LCompaction.CompactedJson, 'PASS');
end;

procedure TTestRadIAResultCompactor.OneMiBDiffMeetsPerformanceBudget;
var
  LBestDuration: Int64;
  LCompaction: TRadIAResultCompaction;
  LDiff: string;
  LIteration: Integer;
begin
  LDiff := 'diff --git a/Sample.pas b/Sample.pas ' +
    StringOfChar('x', 1024 * 1024);
  { Warm the JSON parser, regular expressions, and allocator before measuring.
    The gate targets steady-state compaction, not one-time RTL initialization. }
  LCompaction := TRadIAResultCompactor.Compact(
    'GetGitDiff',
    '{"diff":"' + LDiff + '"}'
  );
  Assert.IsTrue(LCompaction.Compacted);
  LBestDuration := High(Int64);
  for LIteration := 1 to 3 do
  begin
    LCompaction := TRadIAResultCompactor.Compact(
      'GetGitDiff',
      '{"diff":"' + LDiff + '"}'
    );
    Assert.IsTrue(LCompaction.Compacted);
    if LCompaction.DurationMicroseconds < LBestDuration then
      LBestDuration := LCompaction.DurationMicroseconds;
  end;
  Assert.IsTrue(
    LBestDuration < 100000,
    Format(
      'Best of three one MiB compactions took %d microseconds.',
      [LBestDuration]
    )
  );
end;

procedure TTestRadIAResultCompactor.LeavesUnsupportedToolResultUntouched;
var
  LCompaction: TRadIAResultCompaction;
  LResultJson: string;
begin
  LResultJson := '{"content":"full source must remain unchanged"}';
  LCompaction := TRadIAResultCompactor.Compact(
    'GetEditorContent',
    LResultJson
  );
  Assert.IsFalse(LCompaction.Compacted);
  Assert.AreEqual(LResultJson, LCompaction.CompactedJson);
end;

procedure TTestRadIAResultCompactor.TruncatesLargeDiffWithHeadAndTail;
var
  LCompaction: TRadIAResultCompaction;
  LDiff: string;
  LResultJson: string;
begin
  LDiff := 'HEAD_MARKER' + StringOfChar('x', 30000) + 'TAIL_MARKER';
  LResultJson := '{"diff":"' + LDiff + '"}';
  LCompaction := TRadIAResultCompactor.Compact('GetGitDiff', LResultJson);
  Assert.IsTrue(LCompaction.Compacted);
  Assert.Contains(LCompaction.CompactedJson, 'HEAD_MARKER');
  Assert.Contains(LCompaction.CompactedJson, 'TAIL_MARKER');
  Assert.Contains(LCompaction.CompactedJson, 'RadIA omitted');
end;

procedure TTestRadIAResultCompactor.PreservesCriticalTestFailureInsideLargeOutput;
var
  LCompaction: TRadIAResultCompaction;
  LOutput: string;
  LRoot: TJSONObject;
begin
  LOutput := 'HEAD' + StringOfChar('a', 12000) + sLineBreak +
    'FAILED: Required regression evidence' + sLineBreak +
    StringOfChar('b', 12000) + 'TAIL';
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('output', LOutput);
    LCompaction := TRadIAResultCompactor.Compact(
      'RunDUnitXTests',
      LRoot.ToJSON
    );
  finally
    LRoot.Free;
  end;
  Assert.IsTrue(LCompaction.Compacted);
  Assert.Contains(LCompaction.CompactedJson, 'FAILED: Required regression evidence');
end;

procedure TTestRadIAResultCompactor.PreservesDiffHeadersInsideLargeDiff;
var
  LCompaction: TRadIAResultCompaction;
  LDiff: string;
  LRoot: TJSONObject;
begin
  LDiff := 'HEAD' + StringOfChar('a', 12000) + sLineBreak +
    'diff --git a/Middle.pas b/Middle.pas' + sLineBreak +
    '@@ -10,1 +10,1 @@' + sLineBreak + StringOfChar('b', 12000) + 'TAIL';
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('diff', LDiff);
    LCompaction := TRadIAResultCompactor.Compact('GetGitDiff', LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
  Assert.IsTrue(LCompaction.Compacted);
  Assert.Contains(LCompaction.CompactedJson, 'diff --git a/Middle.pas');
  Assert.Contains(LCompaction.CompactedJson, '@@ -10,1 +10,1 @@');
end;

procedure TTestRadIAResultCompactor.CompactsLargeWorkspaceListWithProvenance;
var
  LCompaction: TRadIAResultCompaction;
  LIndex: Integer;
  LItems: TJSONArray;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LItems := TJSONArray.Create;
    for LIndex := 1 to 100 do
      LItems.Add(Format('Unit%.3d.pas', [LIndex]));
    LRoot.AddPair('items', LItems);
    LCompaction := TRadIAResultCompactor.Compact('ListOpenFiles', LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
  Assert.IsTrue(LCompaction.Compacted);
  Assert.Contains(LCompaction.CompactedJson, 'Unit001.pas');
  Assert.Contains(LCompaction.CompactedJson, 'Unit100.pas');
  Assert.Contains(LCompaction.CompactedJson, '"omittedItems":50');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAResultCompactor);

end.
