unit RadIA.Tests.DUnitX;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.DUnitX,
  RadIA.Core.Tools;

type
  TRadIADUnitXRunnerStub = class(
    TInterfacedObject,
    IRadIADUnitXRunner
  )
  private
    FCancelResult: Boolean;
    FExecuteCount: Integer;
    FLastRequest: TRadIADUnitXRunRequest;
    FResult: TRadIADUnitXRunResult;
    FStatus: TRadIADUnitXRunStatus;
  public
    function Execute(
      const ARequest: TRadIADUnitXRunRequest
    ): TRadIADUnitXRunResult;
    function Cancel: Boolean;
    function GetStatus: TRadIADUnitXRunStatus;
    property CancelResult: Boolean
      read FCancelResult write FCancelResult;
    property ExecuteCount: Integer read FExecuteCount;
    property LastRequest: TRadIADUnitXRunRequest read FLastRequest;
    property RunResult: TRadIADUnitXRunResult
      read FResult write FResult;
    property CurrentStatus: TRadIADUnitXRunStatus
      read FStatus write FStatus;
  end;

  [TestFixture]
  TRadIADUnitXReportParserTests = class
  public
    [Test]
    procedure ParsesSummaryCasesAndFailureDetails;
    [Test]
    procedure RejectsEmptyReport;
  end;

  [TestFixture]
  TRadIADUnitXToolTests = class
  private
    FRegistry: IRadIAToolRegistry;
    FRunner: TRadIADUnitXRunnerStub;
    function Execute(
      const AName: string;
      const AArguments: string
    ): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure RegistersRiskAndStatusContracts;
    [Test]
    procedure RunPassesValidatedRequestAndReturnsReport;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.DUnitXTools,
  RadIA.Core.ToolRegistry;

const
  CReport =
    '<?xml version="1.0" encoding="UTF-8"?>' +
    '<test-results name="SampleTests.exe" total="2" errors="0" ' +
    'failures="1" ignored="0">' +
    '<test-suite type="Fixture" name="TSampleTests">' +
    '<results>' +
    '<test-case name="Passes" result="Success" time="0.010" />' +
    '<test-case name="Fails" result="Failure" time="0.020">' +
    '<failure><message>Expected 1 but was 2</message>' +
    '<stack-trace>SampleTests.pas:42</stack-trace></failure>' +
    '</test-case></results></test-suite></test-results>';

{ TRadIADUnitXRunnerStub }

function TRadIADUnitXRunnerStub.Cancel: Boolean;
begin
  Result := FCancelResult;
end;

function TRadIADUnitXRunnerStub.Execute(
  const ARequest: TRadIADUnitXRunRequest
): TRadIADUnitXRunResult;
begin
  Inc(FExecuteCount);
  FLastRequest := ARequest;
  Result := FResult;
end;

function TRadIADUnitXRunnerStub.GetStatus: TRadIADUnitXRunStatus;
begin
  Result := FStatus;
end;

procedure TRadIADUnitXReportParserTests.ParsesSummaryCasesAndFailureDetails;
var
  LParser: TRadIADUnitXReportParser;
  LReport: TRadIADUnitXReport;
begin
  LParser := TRadIADUnitXReportParser.Create;
  try
    LReport := LParser.Parse(CReport);
    Assert.AreEqual('SampleTests.exe', LReport.Name);
    Assert.AreEqual(2, LReport.Total);
    Assert.AreEqual(1, LReport.Passed);
    Assert.AreEqual(1, LReport.Failed);
    Assert.AreEqual<Integer>(2, Length(LReport.TestCases));
    Assert.AreEqual(Int64(30), LReport.DurationMs);
    Assert.AreEqual('TSampleTests', LReport.TestCases[1].FixtureName);
    Assert.AreEqual(dtsFailed, LReport.TestCases[1].Status);
    Assert.AreEqual(
      'Expected 1 but was 2',
      LReport.TestCases[1].Message
    );
    Assert.IsTrue(LReport.ToJson.Contains('"allPassed":false'));
  finally
    LParser.Free;
  end;
end;

procedure TRadIADUnitXReportParserTests.RejectsEmptyReport;
var
  LParser: TRadIADUnitXReportParser;
begin
  LParser := TRadIADUnitXReportParser.Create;
  try
    Assert.WillRaise(
      procedure
      var
        LReport: TRadIADUnitXReport;
      begin
        LReport := LParser.Parse('');
        Assert.AreEqual(0, LReport.Total);
      end,
      EArgumentException
    );
  finally
    LParser.Free;
  end;
end;

{ TRadIADUnitXToolTests }

function TRadIADUnitXToolTests.Execute(
  const AName: string;
  const AArguments: string
): TRadIAToolResult;
var
  LTool: IRadIATool;
begin
  LTool := FRegistry.Resolve(AName);
  Result := LTool.Execute(
    TRadIAToolRequest.Create(AName, AArguments, 'test')
  );
end;

procedure TRadIADUnitXToolTests.RegistersRiskAndStatusContracts;
var
  LResult: TRadIAToolResult;
begin
  Assert.AreEqual(
    trExecution,
    FRegistry.Resolve('RunDUnitXTests').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('GetDUnitXStatus').Descriptor.Risk
  );
  FRunner.CurrentStatus := drsRunning;
  LResult := Execute('GetDUnitXStatus', '{}');
  Assert.IsTrue(LResult.Success);
  Assert.IsTrue(LResult.ContentJson.Contains('"status":"running"'));
end;

procedure TRadIADUnitXToolTests.RunPassesValidatedRequestAndReturnsReport;
var
  LParser: TRadIADUnitXReportParser;
  LReport: TRadIADUnitXReport;
  LResult: TRadIAToolResult;
begin
  LParser := TRadIADUnitXReportParser.Create;
  try
    LReport := LParser.Parse(CReport);
  finally
    LParser.Free;
  end;
  FRunner.RunResult := TRadIADUnitXRunResult.Completed(
    drsFailed,
    1,
    31,
    LReport,
    'test output'
  );
  LResult := Execute(
    'RunDUnitXTests',
    '{"executablePath":"bin\\Tests.exe","timeoutMs":5000,' +
    '"tests":["TSampleTests.Fails"]}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.AreEqual(1, FRunner.ExecuteCount);
  Assert.AreEqual('bin\Tests.exe', FRunner.LastRequest.ExecutablePath);
  Assert.AreEqual(Cardinal(5000), FRunner.LastRequest.TimeoutMs);
  Assert.AreEqual<Integer>(1, Length(FRunner.LastRequest.Tests));
  Assert.IsTrue(LResult.ContentJson.Contains('"status":"failed"'));
  Assert.IsTrue(LResult.ContentJson.Contains('"total":2'));
end;

procedure TRadIADUnitXToolTests.Setup;
begin
  FRegistry := TRadIAToolRegistry.Create;
  FRunner := TRadIADUnitXRunnerStub.Create;
  RegisterRadIADUnitXTools(FRegistry, FRunner);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADUnitXReportParserTests);
  TDUnitX.RegisterTestFixture(TRadIADUnitXToolTests);

end.
