unit RadIA.Tests.FireDACSqlAnalyzer;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACSqlAnalyzerTests = class
  private
    function AnalyzeJson(const ASql: string): string;
  public
    [Test]
    procedure ClassifiesSelectWithCteAndParameters;
    [Test]
    procedure ClassifiesOuterMutationAfterCte;
    [Test]
    procedure IgnoresParametersAndSemicolonsInsideStringsAndComments;
    [Test]
    procedure DoesNotTreatPostgreSqlCastAsParameter;
    [Test]
    procedure ClassifiesMutableAndDdlStatements;
    [Test]
    procedure ReportsMultipleStatementsWithoutExecutingSql;
    [Test]
    procedure DeduplicatesCaseInsensitiveParameters;
    [Test]
    procedure TruncatesOversizedSql;
  end;

implementation

uses
  System.RegularExpressions,
  System.SysUtils,
  RadIA.Core.FireDAC.SqlAnalyzer;

function TRadIAFireDACSqlAnalyzerTests.AnalyzeJson(const ASql: string): string;
var
  LAnalysis: TRadIAFireDACSqlAnalysis;
  LAnalyzer: TRadIAFireDACSqlAnalyzer;
begin
  LAnalyzer := TRadIAFireDACSqlAnalyzer.Create;
  try
    LAnalysis := LAnalyzer.Analyze(ASql, 'Data.pas', 42);
    try
      Result := LAnalysis.ToJson;
    finally
      LAnalysis.Free;
    end;
  finally
    LAnalyzer.Free;
  end;
end;

procedure TRadIAFireDACSqlAnalyzerTests.ClassifiesSelectWithCteAndParameters;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'with active as (select id from customer where state = :State) ' +
    'select id from active where id = @CustomerId'
  );
  Assert.Contains(LJson, '"statementKind":"select"');
  Assert.Contains(LJson, '"name":"State","prefix":":"');
  Assert.Contains(LJson, '"name":"CustomerId","prefix":"@"');
  Assert.Contains(LJson, '"statementCount":1');
end;

procedure TRadIAFireDACSqlAnalyzerTests.ClassifiesOuterMutationAfterCte;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'with inactive as (select id from customer where active = 0) ' +
    'update customer set archived = 1 where id in (select id from inactive)'
  );
  Assert.Contains(LJson, '"statementKind":"update"');
  Assert.Contains(LJson, '"mutable":true');
end;

procedure TRadIAFireDACSqlAnalyzerTests.IgnoresParametersAndSemicolonsInsideStringsAndComments;
var
  LJson: string;
begin
  LJson := AnalyzeJson(
    'select '':not_a_parameter;'' as sample -- @ignored;' + sLineBreak +
    'from customer /* :also_ignored; */ where id = :Id'
  );
  Assert.Contains(LJson, '"name":"Id"');
  Assert.DoesNotContain(LJson, 'not_a_parameter');
  Assert.DoesNotContain(LJson, 'also_ignored');
  Assert.Contains(LJson, '"statementCount":1');
end;

procedure TRadIAFireDACSqlAnalyzerTests.DoesNotTreatPostgreSqlCastAsParameter;
var
  LJson: string;
begin
  LJson := AnalyzeJson('select created_at::date from audit where tenant_id = :TenantId');
  Assert.Contains(LJson, '"name":"TenantId"');
  Assert.DoesNotContain(LJson, '"name":"date"');
end;

procedure TRadIAFireDACSqlAnalyzerTests.ClassifiesMutableAndDdlStatements;
begin
  Assert.Contains(AnalyzeJson('update customer set active = 0'), '"statementKind":"update"');
  Assert.Contains(AnalyzeJson('create table sample (id integer)'), '"statementKind":"ddl"');
end;

procedure TRadIAFireDACSqlAnalyzerTests.ReportsMultipleStatementsWithoutExecutingSql;
var
  LJson: string;
begin
  LJson := AnalyzeJson('select id from customer; delete from audit where id = :Id;');
  Assert.Contains(LJson, 'firedac.sql.multiple-statements');
  Assert.Contains(LJson, '"statementCount":2');
  Assert.Contains(LJson, '"sqlExecuted":false');
  Assert.DoesNotContain(LJson, 'delete from audit');
end;

procedure TRadIAFireDACSqlAnalyzerTests.DeduplicatesCaseInsensitiveParameters;
var
  LJson: string;
begin
  LJson := AnalyzeJson('select * from customer where id = :Id or parent_id = :ID');
  Assert.AreEqual(1, TRegEx.Matches(LJson, '"name":').Count);
end;

procedure TRadIAFireDACSqlAnalyzerTests.TruncatesOversizedSql;
var
  LJson: string;
begin
  LJson := AnalyzeJson('select 1 ' + StringOfChar(' ', CRadIAFireDACMaximumSqlLength + 1));
  Assert.Contains(LJson, '"truncated":true');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACSqlAnalyzerTests);

end.
