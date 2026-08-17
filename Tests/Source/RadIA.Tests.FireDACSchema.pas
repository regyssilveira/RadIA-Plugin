unit RadIA.Tests.FireDACSchema;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACSchemaTests = class
  public
    [Test]
    procedure ReportsMissingTableColumnTypeAndNullability;
    [Test]
    procedure ClassifiesBlobAndSensitiveColumnsWithoutValues;
  end;

implementation

uses
  System.JSON,
  RadIA.Core.FireDAC.Model,
  RadIA.Core.FireDAC.Schema;

function CompareJson(
  const ASchemaJson: string;
  const AExpectations: TArray<TRadIAFireDACSchemaExpectation>
): string;
var
  LComparison: TRadIAFireDACSchemaComparison;
  LComparator: TRadIAFireDACSchemaComparator;
  LSchema: TJSONObject;
begin
  LSchema := TJSONObject.ParseJSONValue(ASchemaJson) as TJSONObject;
  LComparator := TRadIAFireDACSchemaComparator.Create;
  try
    LComparison := LComparator.Compare(LSchema, AExpectations);
    try
      Result := LComparison.ToJson;
    finally
      LComparison.Free;
    end;
  finally
    LComparator.Free;
    LSchema.Free;
  end;
end;

procedure TRadIAFireDACSchemaTests.ReportsMissingTableColumnTypeAndNullability;
var
  LExpectations: TArray<TRadIAFireDACSchemaExpectation>;
  LJson: string;
begin
  LExpectations := [
    TRadIAFireDACSchemaExpectation.Create(
      'customers', 'id', 'string', 'true', TRadIAFireDACLocation.Create('Dto.pas', 10)
    ),
    TRadIAFireDACSchemaExpectation.Create(
      'customers', 'missing', 'string', 'unknown', TRadIAFireDACLocation.Create('Dto.pas', 11)
    ),
    TRadIAFireDACSchemaExpectation.Create(
      'orders', 'id', 'integer', 'false', TRadIAFireDACLocation.Create('Dto.pas', 12)
    )
  ];
  LJson := CompareJson(
    '{"objects":[{"name":"customers","objectType":"table","columns":[' +
    '{"name":"id","dataType":"INTEGER","notNull":true,"sensitive":false}]}]}',
    LExpectations
  );
  Assert.Contains(LJson, 'firedac.schema.type-mismatch');
  Assert.Contains(LJson, 'firedac.schema.nullability-mismatch');
  Assert.Contains(LJson, 'firedac.schema.column-missing');
  Assert.Contains(LJson, 'firedac.schema.table-missing');
  Assert.Contains(LJson, '"schemaReadOnly":true');
end;

procedure TRadIAFireDACSchemaTests.ClassifiesBlobAndSensitiveColumnsWithoutValues;
var
  LExpectations: TArray<TRadIAFireDACSchemaExpectation>;
  LJson: string;
begin
  LExpectations := [TRadIAFireDACSchemaExpectation.Create(
    'accounts', 'api_token', 'bytes', 'unknown', TRadIAFireDACLocation.Create('Account.pas', 7)
  )];
  LJson := CompareJson(
    '{"objects":[{"name":"accounts","objectType":"table","columns":[' +
    '{"name":"api_token","dataType":"BLOB","notNull":false,"sensitive":true}]}]}',
    LExpectations
  );
  Assert.Contains(LJson, 'firedac.schema.blob-column');
  Assert.Contains(LJson, 'firedac.schema.sensitive-column');
  Assert.DoesNotContain(LJson, 'secret-value');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACSchemaTests);

end.
