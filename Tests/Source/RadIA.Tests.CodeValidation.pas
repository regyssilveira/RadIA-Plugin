unit RadIA.Tests.CodeValidation;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIACodeValidationTests = class
  public
    [Test]
    procedure ParsesDelphiLintIssues;
    [Test]
    procedure ParsesSonarIssuesAndComponentPaths;
    [Test]
    procedure NormalizesCompilerMessages;
    [Test]
    procedure RejectsInvalidExternalResponses;
    [Test]
    procedure DiscoversSonarConfiguration;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.CodeValidation,
  RadIA.Core.Workspace;

procedure TRadIACodeValidationTests.NormalizesCompilerMessages;
var
  LFindings: TArray<TRadIACodeValidationFinding>;
begin
  LFindings := TRadIACodeValidationParser.FromCompilerMessages([
    TRadIACompilerMessage.Create(
      cmsError,
      'E2003 Undeclared identifier',
      'Main.pas',
      14,
      3
    )
  ]);
  Assert.AreEqual(1, Length(LFindings));
  Assert.AreEqual('compiler', RadIAValidationSourceName(LFindings[0].Source));
  Assert.AreEqual('error', RadIAValidationSeverityName(LFindings[0].Severity));
  Assert.AreEqual(14, LFindings[0].Line);
end;

procedure TRadIACodeValidationTests.DiscoversSonarConfiguration;
var
  LKey: string;
  LRootPath: string;
  LUrl: string;
begin
  LRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIASonarConfiguration-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(TPath.Combine(LRootPath, '.scannerwork'));
  try
    TFile.WriteAllText(
      TPath.Combine(LRootPath, 'sonar-project.properties'),
      '# project' + sLineBreak + 'sonar.projectKey = sample-key',
      TEncoding.UTF8
    );
    TFile.WriteAllText(
      TPath.Combine(LRootPath, '.scannerwork\report-task.txt'),
      'serverUrl=http://localhost:9000',
      TEncoding.UTF8
    );
    TRadIASonarConfiguration.Resolve(
      LRootPath,
      'https://sonar.example.test/',
      '',
      LUrl,
      LKey
    );
    Assert.AreEqual('https://sonar.example.test', LUrl);
    Assert.AreEqual('sample-key', LKey);
  finally
    TDirectory.Delete(LRootPath, True);
  end;
end;

procedure TRadIACodeValidationTests.ParsesDelphiLintIssues;
var
  LError: string;
  LFindings: TArray<TRadIACodeValidationFinding>;
begin
  Assert.IsTrue(TRadIACodeValidationParser.ParseDelphiLint(
    '{"issues":[{"ruleKey":"DelphiLint:LongRoutine",' +
    '"message":"Routine is too long","file":"Main.pas",' +
    '"textRange":{"startLine":12,"startOffset":4}}]}',
    LFindings,
    LError
  ), LError);
  Assert.AreEqual(1, Length(LFindings));
  Assert.AreEqual('DelphiLint:LongRoutine', LFindings[0].Rule);
  Assert.AreEqual(12, LFindings[0].Line);
  Assert.AreEqual(5, LFindings[0].Column);
end;

procedure TRadIACodeValidationTests.ParsesSonarIssuesAndComponentPaths;
var
  LError: string;
  LFindings: TArray<TRadIACodeValidationFinding>;
begin
  Assert.IsTrue(TRadIACodeValidationParser.ParseSonar(
    '{"issues":[{"rule":"community-delphi:EmptyRoutine",' +
    '"severity":"CRITICAL","component":"radia:Main.pas",' +
    '"line":22,"message":"Remove this empty routine.",' +
    '"textRange":{"startOffset":2}}],"components":[' +
    '{"key":"radia:Main.pas","path":"Source/Main.pas"}]}',
    LFindings,
    LError
  ), LError);
  Assert.AreEqual(1, Length(LFindings));
  Assert.AreEqual('Source/Main.pas', LFindings[0].FileName);
  Assert.AreEqual('error', RadIAValidationSeverityName(LFindings[0].Severity));
  Assert.AreEqual(3, LFindings[0].Column);
end;

procedure TRadIACodeValidationTests.RejectsInvalidExternalResponses;
var
  LError: string;
  LFindings: TArray<TRadIACodeValidationFinding>;
begin
  Assert.IsFalse(TRadIACodeValidationParser.ParseDelphiLint(
    '{}',
    LFindings,
    LError
  ));
  Assert.Contains(LError, 'issues');
  Assert.IsFalse(TRadIACodeValidationParser.ParseSonar(
    '[]',
    LFindings,
    LError
  ));
  Assert.Contains(LError, 'object');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIACodeValidationTests);

end.
