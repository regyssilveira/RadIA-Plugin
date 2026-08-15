unit RadIA.Tests.Problems;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAProblemTests = class
  private
    function ExtractJson(
      const AToolName: string;
      const AJson: string
    ): string;
  public
    [Test]
    procedure NormalizesBuildMessagesWithNavigation;
    [Test]
    procedure KeepsOnlyFailedTestCases;
    [Test]
    procedure ResolvesDfmFileAndRecommendedAction;
    [Test]
    procedure ProducesStableProblemIdentifiers;
    [Test]
    procedure ConvertsCoverageAndMemoryEvidence;
    [Test]
    procedure RoutesUnifiedValidationToReview;
  end;

implementation

uses
  System.JSON,
  RadIA.Core.Problems;

procedure TRadIAProblemTests.ConvertsCoverageAndMemoryEvidence;
var
  LCoverage: string;
  LMemory: string;
begin
  LCoverage := ExtractJson(
    'GetCoverageSummary',
    '{"reportPath":"Output\\Coverage\\summary.xml",' +
      '"summary":{"coveredPercent":72}}'
  );
  Assert.Contains(LCoverage, '"category":"coverage"');
  Assert.Contains(LCoverage, '72%');

  LMemory := ExtractJson(
    'ParseFastMM5Log',
    '{"events":[{"kind":"leak","className":"TStringList",' +
      '"totalBytes":48,"frames":[{"fileName":"Main.pas",' +
      '"lineNumber":27}]}]}'
  );
  Assert.Contains(LMemory, '"category":"memory"');
  Assert.Contains(LMemory, '"fileName":"Main.pas"');
  Assert.Contains(LMemory, '"line":27');
end;

procedure TRadIAProblemTests.RoutesUnifiedValidationToReview;
var
  LJson: string;
begin
  LJson := ExtractJson(
    'ValidateDelphiCode',
    '{"findings":[{"source":"sonar","code":"rule-1",' +
    '"severity":"warning","message":"Review this routine.",' +
    '"fileName":"Main.pas","line":9,"column":2}]}'
  );
  Assert.Contains(LJson, '"category":"review"');
  Assert.Contains(LJson, '"recommendedCommand":"/review"');
end;

function TRadIAProblemTests.ExtractJson(
  const AToolName: string;
  const AJson: string
): string;
var
  LProblems: TJSONArray;
  LRoot: TJSONValue;
begin
  LRoot := TJSONObject.ParseJSONValue(AJson);
  try
    Assert.IsTrue(LRoot is TJSONObject);
    LProblems := TRadIAProblemExtractor.Extract(
      AToolName,
      TJSONObject(LRoot)
    );
    try
      Result := LProblems.ToJSON;
    finally
      LProblems.Free;
    end;
  finally
    LRoot.Free;
  end;
end;

procedure TRadIAProblemTests.KeepsOnlyFailedTestCases;
var
  LJson: string;
begin
  LJson := ExtractJson(
    'RunDUnitXTests',
    '{"testCases":[' +
      '{"fixture":"MathTests","name":"Adds","status":"passed"},' +
      '{"fixture":"MathTests","name":"Divides","status":"failed",' +
      '"message":"Expected 2 but got 3"}' +
    ']}'
  );
  Assert.DoesNotContain(LJson, 'Adds');
  Assert.Contains(LJson, 'Divides');
  Assert.Contains(LJson, '"category":"tests"');
  Assert.Contains(LJson, '"severity":"error"');
end;

procedure TRadIAProblemTests.NormalizesBuildMessagesWithNavigation;
var
  LJson: string;
begin
  LJson := ExtractJson(
    'BuildProject',
    '{"messages":[{"text":"[dcc32 Error] Unit1.pas(14): E2003",' +
      '"fileName":"Unit1.pas","line":14,"column":3}]}'
  );
  Assert.Contains(LJson, '"category":"build"');
  Assert.Contains(LJson, '"severity":"error"');
  Assert.Contains(LJson, '"fileName":"Unit1.pas"');
  Assert.Contains(LJson, '"line":14');
  Assert.Contains(LJson, '/journey fix-build');
end;

procedure TRadIAProblemTests.ProducesStableProblemIdentifiers;
var
  LFirst: string;
  LSecond: string;
begin
  LFirst := ExtractJson(
    'AnalyzeThreadingRisks',
    '{"risks":[{"code":"unsafe-vcl","line":9,' +
      '"message":"VCL access from a worker thread."}]}'
  );
  LSecond := ExtractJson(
    'AnalyzeThreadingRisks',
    '{"risks":[{"code":"unsafe-vcl","line":9,' +
      '"message":"VCL access from a worker thread."}]}'
  );
  Assert.AreEqual(LFirst, LSecond);
  Assert.Contains(LFirst, '"category":"threading"');
end;

procedure TRadIAProblemTests.ResolvesDfmFileAndRecommendedAction;
var
  LJson: string;
begin
  LJson := ExtractJson(
    'AuditDfmPasConsistency',
    '{"dfmFile":"MainForm.dfm","pasFile":"MainForm.pas",' +
      '"findings":[{"code":"missing-handler","severity":"high",' +
      '"fileKind":"dfm","line":20,"message":"Handler was not found."}]}'
  );
  Assert.Contains(LJson, '"category":"dfm-pas"');
  Assert.Contains(LJson, '"fileName":"MainForm.dfm"');
  Assert.Contains(LJson, '"severity":"warning"');
  Assert.Contains(LJson, '"recommendedCommand":"/review"');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAProblemTests);

end.
