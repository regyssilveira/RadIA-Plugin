unit RadIA.Tests.FireDACEnvironment;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACEnvironmentTests = class
  public
    [Test]
    procedure ReportsStaticDriverCoverageWithoutExternalActions;
  end;

implementation

uses
  RadIA.Core.FireDAC.Configuration,
  RadIA.Core.FireDAC.Environment;

procedure TRadIAFireDACEnvironmentTests.ReportsStaticDriverCoverageWithoutExternalActions;
var
  LConfiguration: TRadIAFireDACConfigurationAnalysis;
  LEnvironment: TRadIAFireDACEnvironmentAnalysis;
  LJson: string;
begin
  LConfiguration := TRadIAFireDACConfigurationAnalysis.Create;
  try
    LConfiguration.AddOrGetEntry('Connection', 'TFDConnection', fcfgConnection, 'Data.dfm', 1).DriverId := 'FB';
    LEnvironment := TRadIAFireDACEnvironmentAnalysis.Create;
    try
      LEnvironment.AnalyzeEntries(LConfiguration.Entries);
      LJson := LEnvironment.ToJson;
    finally
      LEnvironment.Free;
    end;
  finally
    LConfiguration.Free;
  end;
  Assert.Contains(LJson, 'firedac.environment.driver-link-not-declared');
  Assert.Contains(LJson, '"connectionAttempted":false');
  Assert.Contains(LJson, '"driverInstallationAttempted":false');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACEnvironmentTests);

end.
