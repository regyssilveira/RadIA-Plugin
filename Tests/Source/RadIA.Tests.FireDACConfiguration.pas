unit RadIA.Tests.FireDACConfiguration;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACConfigurationTests = class
  private
    function AnalyzeDfm(const AContent: string): string;
    function AnalyzePascal(const AContent: string): string;
  public
    [Test]
    procedure InventoriesConnectionDriverOptionsAndLibraryWithoutAbsolutePath;
    [Test]
    procedure RemovesCredentialValuesAndReportsDesignTimeConnection;
    [Test]
    procedure DetectsPascalAssignmentsWithoutReturningPathsOrSecrets;
    [Test]
    procedure ReportsDuplicateConnectionDefinitions;
  end;

implementation

uses
  RadIA.Core.FireDAC.Configuration;

function TRadIAFireDACConfigurationTests.AnalyzeDfm(const AContent: string): string;
var
  LAnalysis: TRadIAFireDACConfigurationAnalysis;
  LAnalyzer: TRadIAFireDACConfigurationAnalyzer;
begin
  LAnalyzer := TRadIAFireDACConfigurationAnalyzer.Create;
  try
    LAnalysis := LAnalyzer.AnalyzeDfm(AContent, 'Data.dfm');
    try
      Result := LAnalysis.ToJson;
    finally
      LAnalysis.Free;
    end;
  finally
    LAnalyzer.Free;
  end;
end;

function TRadIAFireDACConfigurationTests.AnalyzePascal(const AContent: string): string;
var
  LAnalysis: TRadIAFireDACConfigurationAnalysis;
  LAnalyzer: TRadIAFireDACConfigurationAnalyzer;
begin
  LAnalyzer := TRadIAFireDACConfigurationAnalyzer.Create;
  try
    LAnalysis := LAnalyzer.AnalyzePascal(AContent, 'Data.pas');
    try
      Result := LAnalysis.ToJson;
    finally
      LAnalysis.Free;
    end;
  finally
    LAnalyzer.Free;
  end;
end;

procedure TRadIAFireDACConfigurationTests.InventoriesConnectionDriverOptionsAndLibraryWithoutAbsolutePath;
var
  LJson: string;
begin
  LJson := AnalyzeDfm(
    'object MainConnection: TFDConnection' + sLineBreak +
    '  DriverName = ''FB''' + sLineBreak +
    '  ConnectionDefName = ''PrimaryDatabase''' + sLineBreak +
    '  LoginPrompt = False' + sLineBreak +
    '  ResourceOptions.CmdExecTimeout = 5000' + sLineBreak +
    'end' + sLineBreak +
    'object FirebirdDriver: TFDPhysFBDriverLink' + sLineBreak +
    '  VendorLib = ''C:\Program Files\Firebird\fbclient.dll''' + sLineBreak +
    'end'
  );
  Assert.Contains(LJson, '"driverId":"FB"');
  Assert.Contains(LJson, '"connectionDefinition":"PrimaryDatabase"');
  Assert.Contains(LJson, '"optionCount":1');
  Assert.Contains(LJson, '"libraryFileName":"fbclient.dll"');
  Assert.Contains(LJson, 'firedac.configuration.absolute-library-path');
  Assert.DoesNotContain(LJson, 'C:\Program Files');
end;

procedure TRadIAFireDACConfigurationTests.RemovesCredentialValuesAndReportsDesignTimeConnection;
var
  LJson: string;
begin
  LJson := AnalyzeDfm(
    'object MainConnection: TFDConnection' + sLineBreak +
    '  Connected = True' + sLineBreak +
    '  Params.Strings = (' + sLineBreak +
    '    ''DriverID=PG''' + sLineBreak +
    '    ''User_Name=database-owner''' + sLineBreak +
    '    ''Password=do-not-return'')' + sLineBreak +
    'end'
  );
  Assert.Contains(LJson, '"driverId":"PG"');
  Assert.Contains(LJson, 'firedac.configuration.embedded-credential');
  Assert.Contains(LJson, 'firedac.configuration.design-time-connected');
  Assert.Contains(LJson, '"credentialsCollected":false');
  Assert.DoesNotContain(LJson, 'database-owner');
  Assert.DoesNotContain(LJson, 'do-not-return');
end;

procedure TRadIAFireDACConfigurationTests.DetectsPascalAssignmentsWithoutReturningPathsOrSecrets;
var
  LJson: string;
begin
  LJson := AnalyzePascal(
    'Connection.DriverName := ''SQLite'';' + sLineBreak +
    'Connection.Connected := True;' + sLineBreak +
    'DriverLink.VendorLib := ''D:\Private\sqlite3.dll'';' + sLineBreak +
    'Connection.Params.Values[''Password''] := ''hidden-value'';'
  );
  Assert.Contains(LJson, '"driverId":"SQLite"');
  Assert.Contains(LJson, '"libraryFileName":"sqlite3.dll"');
  Assert.Contains(LJson, 'firedac.configuration.design-time-connected');
  Assert.Contains(LJson, 'firedac.configuration.embedded-credential');
  Assert.DoesNotContain(LJson, 'D:\Private');
  Assert.DoesNotContain(LJson, 'hidden-value');
end;

procedure TRadIAFireDACConfigurationTests.ReportsDuplicateConnectionDefinitions;
var
  LJson: string;
begin
  LJson := AnalyzeDfm(
    'object FirstConnection: TFDConnection' + sLineBreak +
    '  ConnectionDefName = ''SharedDefinition''' + sLineBreak +
    'end' + sLineBreak +
    'object SecondConnection: TFDConnection' + sLineBreak +
    '  ConnectionDefName = ''SharedDefinition''' + sLineBreak +
    'end'
  );
  Assert.Contains(LJson, 'firedac.configuration.duplicate-connection-definition');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACConfigurationTests);

end.
