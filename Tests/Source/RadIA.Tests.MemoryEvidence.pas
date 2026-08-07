unit RadIA.Tests.MemoryEvidence;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.MemoryEvidence;

type
  [TestFixture]
  TRadIAMemoryEvidenceTests = class
  private
    FService: IRadIAMemoryEvidenceService;
    function Evidence(
      const AEvidenceId: string;
      const ABuildId: string;
      const AGroupsJson: string;
      const AScenarioFingerprint: string = 'scenario'
    ): string;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure ClassifiesFixedAcrossIndependentBuilds;
    [Test]
    procedure ClassifiesRegressedWhenNewGroupAppears;
    [Test]
    procedure RejectsSameBuildAsIncomparable;
    [Test]
    procedure RejectsMalformedGroupEvidence;
    [Test]
    procedure SelectsProjectFrameForReviewableFix;
  end;

implementation

uses
  RadIA.Core.Tools;

function TRadIAMemoryEvidenceTests.Evidence(
  const AEvidenceId: string;
  const ABuildId: string;
  const AGroupsJson: string;
  const AScenarioFingerprint: string
): string;
begin
  Result :=
    '{"schemaVersion":1,"evidenceId":"' + AEvidenceId + '",' +
    '"session":{"buildId":"' + ABuildId + '","scenarioFingerprint":"' +
    AScenarioFingerprint + '"},"groups":' + AGroupsJson + '}';
end;

procedure TRadIAMemoryEvidenceTests.ClassifiesFixedAcrossIndependentBuilds;
var
  LResult: TRadIAToolResult;
begin
  LResult := FService.Compare(
    Evidence(
      'baseline',
      'build-1',
      '[{"fingerprint":"' + StringOfChar('a', 64) +
      '","totalBytes":64}]'
    ),
    Evidence('verification', 'build-2', '[]')
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"outcome":"fixed"');
  Assert.Contains(LResult.ContentJson, '"baselineGroups":1');
  Assert.Contains(LResult.ContentJson, '"verificationGroups":0');
end;

procedure TRadIAMemoryEvidenceTests.ClassifiesRegressedWhenNewGroupAppears;
var
  LResult: TRadIAToolResult;
begin
  LResult := FService.Compare(
    Evidence(
      'baseline',
      'build-1',
      '[{"fingerprint":"' + StringOfChar('a', 64) +
      '","totalBytes":32}]'
    ),
    Evidence(
      'verification',
      'build-2',
      '[{"fingerprint":"' + StringOfChar('b', 64) +
      '","totalBytes":16}]'
    )
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"outcome":"regressed"');
end;

procedure TRadIAMemoryEvidenceTests.RejectsSameBuildAsIncomparable;
var
  LResult: TRadIAToolResult;
begin
  LResult := FService.Compare(
    Evidence('baseline', 'same-build', '[]'),
    Evidence('verification', 'same-build', '[]')
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"outcome":"incomparable"');
end;

procedure TRadIAMemoryEvidenceTests.RejectsMalformedGroupEvidence;
var
  LResult: TRadIAToolResult;
begin
  LResult := FService.Compare(
    Evidence('baseline', 'build-1', '[null]'),
    Evidence('verification', 'build-2', '[]')
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_baseline_evidence', LResult.ErrorCode);
end;

procedure TRadIAMemoryEvidenceTests.SelectsProjectFrameForReviewableFix;
var
  LFingerprint: string;
  LResult: TRadIAToolResult;
begin
  LFingerprint := StringOfChar('c', 64);
  LResult := FService.PrepareFix(
    Evidence(
      'baseline',
      'build-1',
      '[{"fingerprint":"' + LFingerprint + '","totalBytes":76,' +
      '"allocationNumber":419,"frames":[' +
      '{"fileName":"FastMM5.pas","lineNumber":8255},' +
      '{"fileName":"RadIA.TargetForm.pas","lineNumber":49,' +
      '"routineName":"TRadIATargetForm.CancelClick"}]}]'
    ),
    LFingerprint
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"allocationNumber":419');
  Assert.Contains(LResult.ContentJson, '"targetFile":"RadIA.TargetForm.pas"');
  Assert.Contains(LResult.ContentJson, '"lineNumber":49');
  Assert.Contains(LResult.ContentJson, '"nextTool":"PreparePatch"');
end;

procedure TRadIAMemoryEvidenceTests.Setup;
begin
  FService := TRadIAMemoryEvidenceService.Create;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAMemoryEvidenceTests);

end.
