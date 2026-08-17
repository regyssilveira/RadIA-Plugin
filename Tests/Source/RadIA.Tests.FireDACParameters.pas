unit RadIA.Tests.FireDACParameters;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACParameterTests = class
  private
    function ValidateJson(
      const ASql: string;
      const ABindings: TArray<string>
    ): string;
  public
    [Test]
    procedure FindsMissingAndExtraBindingsCaseInsensitively;
    [Test]
    procedure ReportsStringSizeNullAndAssignmentTypeProblems;
    [Test]
    procedure AcceptsConsistentTypedBinding;
  end;

implementation

uses
  RadIA.Core.FireDAC.Model,
  RadIA.Core.FireDAC.Parameters,
  RadIA.Core.FireDAC.SqlAnalyzer;

function TRadIAFireDACParameterTests.ValidateJson(
  const ASql: string;
  const ABindings: TArray<string>
): string;
var
  LAnalysis: TRadIAFireDACSqlAnalysis;
  LAnalyzer: TRadIAFireDACSqlAnalyzer;
  LBinding: string;
  LBindingRecords: TArray<TRadIAFireDACParameterBinding>;
  LIndex: Integer;
  LValidation: TRadIAFireDACParameterValidation;
  LValidator: TRadIAFireDACParameterValidator;
begin
  SetLength(LBindingRecords, Length(ABindings));
  LIndex := 0;
  for LBinding in ABindings do
  begin
    LBindingRecords[LIndex] := TRadIAFireDACParameterBinding.Create(
      LBinding, '', fpdUnknown, 0, 'unknown', 'unknown', ''
    );
    Inc(LIndex);
  end;
  LAnalyzer := TRadIAFireDACSqlAnalyzer.Create;
  LValidator := TRadIAFireDACParameterValidator.Create;
  try
    LAnalysis := LAnalyzer.Analyze(ASql);
    try
      LValidation := LValidator.Validate(
        LAnalysis.Parameters,
        LBindingRecords,
        TRadIAFireDACLocation.Create('Data.pas', 10)
      );
      try
        Result := LValidation.ToJson;
      finally
        LValidation.Free;
      end;
    finally
      LAnalysis.Free;
    end;
  finally
    LValidator.Free;
    LAnalyzer.Free;
  end;
end;

procedure TRadIAFireDACParameterTests.FindsMissingAndExtraBindingsCaseInsensitively;
var
  LJson: string;
begin
  LJson := ValidateJson(
    'select * from customer where id = :Id and tenant = :Tenant',
    ['ID', 'Unused']
  );
  Assert.Contains(LJson, '"missingBindings":["Tenant"]');
  Assert.Contains(LJson, '"extraBindings":["Unused"]');
end;

procedure TRadIAFireDACParameterTests.ReportsStringSizeNullAndAssignmentTypeProblems;
var
  LAnalysis: TRadIAFireDACSqlAnalysis;
  LAnalyzer: TRadIAFireDACSqlAnalyzer;
  LBinding: TRadIAFireDACParameterBinding;
  LJson: string;
  LValidation: TRadIAFireDACParameterValidation;
  LValidator: TRadIAFireDACParameterValidator;
begin
  LBinding := TRadIAFireDACParameterBinding.Create(
    'Name', 'ftString', fpdInput, 0, 'false', 'null', 'AsInteger'
  );
  LAnalyzer := TRadIAFireDACSqlAnalyzer.Create;
  LValidator := TRadIAFireDACParameterValidator.Create;
  try
    LAnalysis := LAnalyzer.Analyze('select * from customer where name = :Name');
    try
      LValidation := LValidator.Validate(
        LAnalysis.Parameters,
        [LBinding],
        TRadIAFireDACLocation.Create('Data.pas', 10)
      );
      try
        LJson := LValidation.ToJson;
      finally
        LValidation.Free;
      end;
    finally
      LAnalysis.Free;
    end;
  finally
    LValidator.Free;
    LAnalyzer.Free;
  end;
  Assert.Contains(LJson, 'firedac.parameter.string-size-missing');
  Assert.Contains(LJson, 'firedac.parameter.null-not-allowed');
  Assert.Contains(LJson, 'firedac.parameter.assignment-type-mismatch');
  Assert.DoesNotContain(LJson, 'select * from customer');
end;

procedure TRadIAFireDACParameterTests.AcceptsConsistentTypedBinding;
var
  LAnalysis: TRadIAFireDACSqlAnalysis;
  LAnalyzer: TRadIAFireDACSqlAnalyzer;
  LBinding: TRadIAFireDACParameterBinding;
  LValidation: TRadIAFireDACParameterValidation;
  LValidator: TRadIAFireDACParameterValidator;
begin
  LBinding := TRadIAFireDACParameterBinding.Create(
    'Name', 'ftString', fpdInput, 80, 'true', 'value', 'AsString'
  );
  LAnalyzer := TRadIAFireDACSqlAnalyzer.Create;
  LValidator := TRadIAFireDACParameterValidator.Create;
  try
    LAnalysis := LAnalyzer.Analyze('select * from customer where name = :Name');
    try
      LValidation := LValidator.Validate(
        LAnalysis.Parameters,
        [LBinding],
        TRadIAFireDACLocation.Create('Data.pas', 10)
      );
      try
        Assert.Contains(LValidation.ToJson, '"valid":true');
      finally
        LValidation.Free;
      end;
    finally
      LAnalysis.Free;
    end;
  finally
    LValidator.Free;
    LAnalyzer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACParameterTests);

end.
