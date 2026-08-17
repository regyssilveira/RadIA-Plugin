unit RadIA.Tests.FireDACTransactions;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACTransactionTests = class
  private
    function AnalyzeJson(const ASource: string): string;
  public
    [Test]
    procedure AcceptsCommitAndRollbackFlow;
    [Test]
    procedure ReportsMissingCommitAndRollback;
    [Test]
    procedure ReportsPossibleEarlyExit;
    [Test]
    procedure IgnoresCallsInsideStringsAndComments;
  end;

implementation

uses
  RadIA.Core.FireDAC.Transactions;

function TRadIAFireDACTransactionTests.AnalyzeJson(const ASource: string): string;
var
  LAnalysis: TRadIAFireDACTransactionAnalysis;
  LAnalyzer: TRadIAFireDACTransactionAnalyzer;
begin
  LAnalyzer := TRadIAFireDACTransactionAnalyzer.Create;
  try
    LAnalysis := LAnalyzer.Analyze(ASource, 'Data.pas');
    try
      Result := LAnalysis.ToJson;
    finally
      LAnalysis.Free;
    end;
  finally
    LAnalyzer.Free;
  end;
end;

procedure TRadIAFireDACTransactionTests.AcceptsCommitAndRollbackFlow;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'Connection.StartTransaction;' + sLineBreak +
    'try' + sLineBreak +
    '  Connection.Commit;' + sLineBreak +
    'except' + sLineBreak +
    '  Connection.Rollback;' + sLineBreak +
    '  raise;' + sLineBreak +
    'end;'
  );
  Assert.Contains(LJson, '"startCount":1');
  Assert.Contains(LJson, '"commitCount":1');
  Assert.Contains(LJson, '"rollbackCount":1');
  Assert.Contains(LJson, '"findings":[]');
end;

procedure TRadIAFireDACTransactionTests.ReportsMissingCommitAndRollback;
var
  LJson: string;
begin
  LJson := AnalyzeJson('MainTransaction.StartTransaction;');
  Assert.Contains(LJson, 'firedac.transaction.commit-missing');
  Assert.Contains(LJson, 'firedac.transaction.rollback-missing');
  Assert.Contains(LJson, '"symbol":"MainTransaction"');
end;

procedure TRadIAFireDACTransactionTests.ReportsPossibleEarlyExit;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'Connection.StartTransaction;' + sLineBreak +
    'if Cancelled then Exit;' + sLineBreak +
    'Connection.Commit;' + sLineBreak +
    'Connection.Rollback;'
  );
  Assert.Contains(LJson, 'firedac.transaction.early-exit');
  Assert.Contains(LJson, '"confidence":"possible"');
end;

procedure TRadIAFireDACTransactionTests.IgnoresCallsInsideStringsAndComments;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'Text := ''Connection.StartTransaction;'';' + sLineBreak +
    '// Connection.Commit;' + sLineBreak +
    '{ Connection.Rollback; }'
  );
  Assert.Contains(LJson, '"transactions":[]');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACTransactionTests);

end.
