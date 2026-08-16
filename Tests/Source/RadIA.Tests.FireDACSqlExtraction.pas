unit RadIA.Tests.FireDACSqlExtraction;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACSqlExtractionTests = class
  public
    [Test]
    procedure ExtractsMultilineSqlTextAndSqlAdd;
    [Test]
    procedure ExtractsDfmSqlWithoutReturningSqlText;
    [Test]
    procedure MarksUnresolvedExpressionsAsDynamic;
    [Test]
    procedure ResolvesLiteralConstantsAndIgnoresCommentsAndStrings;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.FireDAC.SqlExtraction;

procedure TRadIAFireDACSqlExtractionTests.ExtractsMultilineSqlTextAndSqlAdd;
var
  LExtraction: TRadIAFireDACSqlExtraction;
  LExtractor: TRadIAFireDACSqlExtractor;
  LJson: string;
begin
  LExtractor := TRadIAFireDACSqlExtractor.Create;
  try
    LExtraction := LExtractor.ExtractPascal(
      'Query.SQL.Text := ''select id'' +' + sLineBreak +
      '  '' from customer where id = :Id'';' + sLineBreak +
      'Query.SQL.Add(''order by name'');',
      'Data.pas'
    );
    try
      LJson := LExtraction.ToJson;
    finally
      LExtraction.Free;
    end;
  finally
    LExtractor.Free;
  end;
  Assert.Contains(LJson, '"kind":"sql-text"');
  Assert.Contains(LJson, '"kind":"sql-add"');
  Assert.Contains(LJson, '"name":"Id"');
  Assert.DoesNotContain(LJson, 'from customer');
end;

procedure TRadIAFireDACSqlExtractionTests.ExtractsDfmSqlWithoutReturningSqlText;
var
  LExtraction: TRadIAFireDACSqlExtraction;
  LExtractor: TRadIAFireDACSqlExtractor;
  LJson: string;
begin
  LExtractor := TRadIAFireDACSqlExtractor.Create;
  try
    LExtraction := LExtractor.ExtractDfm(
      'object CustomerQuery: TFDQuery' + sLineBreak +
      '  SQL.Strings = (' + sLineBreak +
      '    ''select id from customer'')' + sLineBreak +
      'end',
      'Data.dfm'
    );
    try
      LJson := LExtraction.ToJson;
    finally
      LExtraction.Free;
    end;
  finally
    LExtractor.Free;
  end;
  Assert.Contains(LJson, '"component":"CustomerQuery"');
  Assert.Contains(LJson, '"statementKind":"select"');
  Assert.DoesNotContain(LJson, 'select id from customer');
end;

procedure TRadIAFireDACSqlExtractionTests.MarksUnresolvedExpressionsAsDynamic;
var
  LExtraction: TRadIAFireDACSqlExtraction;
  LExtractor: TRadIAFireDACSqlExtractor;
  LJson: string;
begin
  LExtractor := TRadIAFireDACSqlExtractor.Create;
  try
    LExtraction := LExtractor.ExtractPascal(
      'Query.SQL.Text := BuildSql(UserInput);',
      'Data.pas'
    );
    try
      LJson := LExtraction.ToJson;
    finally
      LExtraction.Free;
    end;
  finally
    LExtractor.Free;
  end;
  Assert.Contains(LJson, '"dynamic":true');
  Assert.Contains(LJson, 'firedac.sql.dynamic-source');
  Assert.DoesNotContain(LJson, 'UserInput');
end;

procedure TRadIAFireDACSqlExtractionTests.ResolvesLiteralConstantsAndIgnoresCommentsAndStrings;
var
  LExtraction: TRadIAFireDACSqlExtraction;
  LExtractor: TRadIAFireDACSqlExtractor;
  LJson: string;
begin
  LExtractor := TRadIAFireDACSqlExtractor.Create;
  try
    LExtraction := LExtractor.ExtractPascal(
      'const CustomerSql = ''select id from customer where id = :Id'';' + sLineBreak +
      '// Fake.SQL.Text := ''delete from customer'';' + sLineBreak +
      'Text := ''Fake.SQL.Add(''''drop table customer'''');'';' + sLineBreak +
      'Query.SQL.Text := CustomerSql;',
      'Data.pas'
    );
    try
      LJson := LExtraction.ToJson;
    finally
      LExtraction.Free;
    end;
  finally
    LExtractor.Free;
  end;
  Assert.Contains(LJson, '"component":"Query"');
  Assert.Contains(LJson, '"name":"Id"');
  Assert.DoesNotContain(LJson, '"component":"Fake"');
  Assert.DoesNotContain(LJson, 'delete from customer');
  Assert.DoesNotContain(LJson, 'drop table customer');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACSqlExtractionTests);

end.
