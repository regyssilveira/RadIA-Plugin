unit RadIA.Tests.FireDACScanner;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAFireDACScannerTests = class
  private
    FRootPath: string;
    function ScanJson: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure InventoriesPascalDfmAndDynamicComponents;
    [Test]
    procedure CorrelatesConnectionTransactionUpdateAndDataSource;
    [Test]
    procedure ReportsCredentialsWithoutReturningValues;
    [Test]
    procedure SkipsOversizedFilesAndDeclaresTruncation;
    [Test]
    procedure IgnoresSimilarNonFireDACClassesAndComments;
    [Test]
    procedure InventoriesDistinctFireDACProjectReferences;
    [Test]
    procedure AuditsTransactionsAcrossBoundedPascalFiles;
    [Test]
    procedure InspectsConfigurationWithoutReturningSecretsOrAbsolutePaths;
    [Test]
    procedure AnalyzesThreadSafetyAcrossBoundedPascalFiles;
    [Test]
    procedure BuildsProjectReportWithSanitizedSqlAnalysis;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.FireDAC.Model,
  RadIA.Core.FireDAC.Scanner,
  RadIA.Core.WorkspaceBoundary;

procedure TRadIAFireDACScannerTests.Setup;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-FireDAC-Scanner-' + TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '')
  );
  TDirectory.CreateDirectory(FRootPath);
end;

procedure TRadIAFireDACScannerTests.TearDown;
begin
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

function TRadIAFireDACScannerTests.ScanJson: string;
var
  LInventory: TRadIAFireDACInventory;
  LScanner: TRadIAFireDACScanner;
begin
  LScanner := TRadIAFireDACScanner.Create(TRadIAWorkspaceBoundary.Create);
  try
    LInventory := LScanner.Scan(FRootPath);
    try
      Result := LInventory.ToJson;
    finally
      LInventory.Free;
    end;
  finally
    LScanner.Free;
  end;
end;

procedure TRadIAFireDACScannerTests.InventoriesPascalDfmAndDynamicComponents;
var
  LJson: string;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'MainData.pas'),
    'type TMainData = class(TDataModule)' + sLineBreak +
    '  MainConnection: TFDConnection;' + sLineBreak +
    '  CustomerQuery: TFDQuery;' + sLineBreak +
    '  procedure Load; // ParamByName is used by the implementation' + sLineBreak +
    'end;' + sLineBreak +
    'LCommand := TFDCommand.Create(nil);'
  );
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'MainData.dfm'),
    'object MainData: TMainData' + sLineBreak +
    '  object MainTransaction: TFDTransaction' + sLineBreak +
    '  end' + sLineBreak +
    '  object FirebirdDriver: TFDPhysFBDriverLink' + sLineBreak +
    '  end' + sLineBreak +
    'end'
  );
  LJson := ScanJson;
  Assert.Contains(LJson, 'MainConnection');
  Assert.Contains(LJson, 'CustomerQuery');
  Assert.Contains(LJson, 'LCommand');
  Assert.Contains(LJson, 'MainTransaction');
  Assert.Contains(LJson, 'FirebirdDriver');
  Assert.Contains(LJson, '"kind":"driver-link"');
  Assert.Contains(LJson, '"connectionCount":1');
  Assert.Contains(LJson, '"queryCount":2');
  Assert.Contains(LJson, '"parameterReferenceCount":1');
end;

procedure TRadIAFireDACScannerTests.CorrelatesConnectionTransactionUpdateAndDataSource;
var
  LJson: string;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'MainData.dfm'),
    'object MainData: TMainData' + sLineBreak +
    '  object CustomerQuery: TFDQuery' + sLineBreak +
    '    Connection = MainConnection' + sLineBreak +
    '    Transaction = MainTransaction' + sLineBreak +
    '    UpdateObject = CustomerUpdate' + sLineBreak +
    '  end' + sLineBreak +
    '  object CustomerSource: TDataSource' + sLineBreak +
    '    DataSet = CustomerQuery' + sLineBreak +
    '  end' + sLineBreak +
    'end'
  );
  LJson := ScanJson;
  Assert.Contains(LJson, '"source":"CustomerQuery","target":"MainConnection"');
  Assert.Contains(LJson, '"source":"CustomerQuery","target":"MainTransaction"');
  Assert.Contains(LJson, '"source":"CustomerQuery","target":"CustomerUpdate"');
  Assert.Contains(LJson, '"source":"CustomerSource","target":"CustomerQuery"');
end;

procedure TRadIAFireDACScannerTests.ReportsCredentialsWithoutReturningValues;
var
  LJson: string;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'MainData.dfm'),
    'object MainConnection: TFDConnection' + sLineBreak +
    '  Params.Strings = (' + sLineBreak +
    '    ''User_Name=database-admin''' + sLineBreak +
    '    ''Password=super-secret-value'')' + sLineBreak +
    'end'
  );
  LJson := ScanJson;
  Assert.Contains(LJson, 'firedac.configuration.embedded-credential');
  Assert.Contains(LJson, '"credentialsCollected":false');
  Assert.DoesNotContain(LJson, 'database-admin');
  Assert.DoesNotContain(LJson, 'super-secret-value');
end;

procedure TRadIAFireDACScannerTests.SkipsOversizedFilesAndDeclaresTruncation;
var
  LJson: string;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'LargeData.pas'),
    StringOfChar('X', CRadIAFireDACMaximumFileBytes + 1)
  );
  LJson := ScanJson;
  Assert.Contains(LJson, 'firedac.scan.file-too-large');
  Assert.Contains(LJson, '"truncated":true');
end;

procedure TRadIAFireDACScannerTests.IgnoresSimilarNonFireDACClassesAndComments;
var
  LJson: string;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'FalsePositive.pas'),
    '// FakeQuery: TFDQuery;' + sLineBreak +
    'type TFDQueryFactory = class' + sLineBreak +
    '  QueryFactory: TFDQueryFactory;' + sLineBreak +
    'end;'
  );
  LJson := ScanJson;
  Assert.DoesNotContain(LJson, 'FakeQuery');
  Assert.DoesNotContain(LJson, 'QueryFactory');
end;

procedure TRadIAFireDACScannerTests.InventoriesDistinctFireDACProjectReferences;
var
  LJson: string;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Fixture.dproj'),
    '<Project><Unit>FireDAC.Comp.Client</Unit>' +
    '<Unit>FireDAC.Phys.FB</Unit><Unit>FireDAC.Comp.Client</Unit></Project>'
  );
  LJson := ScanJson;
  Assert.Contains(LJson, '"projectReferences":["FireDAC.Comp.Client","FireDAC.Phys.FB"]');
end;

procedure TRadIAFireDACScannerTests.AuditsTransactionsAcrossBoundedPascalFiles;
var
  LJson: string;
  LScanner: TRadIAFireDACScanner;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'UnsafeData.pas'),
    'procedure Save;' + sLineBreak +
    'begin' + sLineBreak +
    '  MainConnection.StartTransaction;' + sLineBreak +
    'end;'
  );
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Ignored.dfm'),
    'object MainData: TDataModule' + sLineBreak +
    '  Caption = ''MainConnection.StartTransaction;''' + sLineBreak +
    'end'
  );
  LScanner := TRadIAFireDACScanner.Create(TRadIAWorkspaceBoundary.Create);
  try
    LJson := LScanner.AuditTransactions(FRootPath);
  finally
    LScanner.Free;
  end;
  Assert.Contains(LJson, 'firedac.transaction.commit-missing');
  Assert.Contains(LJson, 'firedac.transaction.rollback-missing');
  Assert.Contains(LJson, '"file":"UnsafeData.pas"');
  Assert.Contains(LJson, '"findings"');
  Assert.DoesNotContain(LJson, 'Caption');
end;

procedure TRadIAFireDACScannerTests.InspectsConfigurationWithoutReturningSecretsOrAbsolutePaths;
var
  LJson: string;
  LScanner: TRadIAFireDACScanner;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'MainData.dfm'),
    'object Connection: TFDConnection' + sLineBreak +
    '  Params.Strings = (' + sLineBreak +
    '    ''DriverID=FB''' + sLineBreak +
    '    ''Password=hidden-password'')' + sLineBreak +
    'end' + sLineBreak +
    'object Driver: TFDPhysFBDriverLink' + sLineBreak +
    '  VendorLib = ''D:\Private\fbclient.dll''' + sLineBreak +
    'end'
  );
  LScanner := TRadIAFireDACScanner.Create(TRadIAWorkspaceBoundary.Create);
  try
    LJson := LScanner.InspectConfiguration(FRootPath);
  finally
    LScanner.Free;
  end;
  Assert.Contains(LJson, '"driverId":"FB"');
  Assert.Contains(LJson, '"libraryFileName":"fbclient.dll"');
  Assert.Contains(LJson, 'firedac.configuration.embedded-credential');
  Assert.Contains(LJson, '"credentialsCollected":false');
  Assert.DoesNotContain(LJson, 'hidden-password');
  Assert.DoesNotContain(LJson, 'D:\Private');
end;

procedure TRadIAFireDACScannerTests.AnalyzesThreadSafetyAcrossBoundedPascalFiles;
var
  LJson: string;
  LScanner: TRadIAFireDACScanner;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Worker.pas'),
    'type TDataModule = class' + sLineBreak +
    '  MainConnection: TFDConnection;' + sLineBreak +
    'end;' + sLineBreak +
    'TTask.Run(procedure begin MainConnection.Open; end);'
  );
  LScanner := TRadIAFireDACScanner.Create(TRadIAWorkspaceBoundary.Create);
  try
    LJson := LScanner.AnalyzeThreadSafety(FRootPath);
  finally
    LScanner.Free;
  end;
  Assert.Contains(LJson, 'firedac.thread.shared-component');
  Assert.Contains(LJson, '"file":"Worker.pas"');
  Assert.Contains(LJson, '"sqlExecuted":false');
  Assert.DoesNotContain(LJson, 'MainConnection.Open');
end;

procedure TRadIAFireDACScannerTests.BuildsProjectReportWithSanitizedSqlAnalysis;
var
  LJson: string;
  LScanner: TRadIAFireDACScanner;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Data.pas'),
    'type TDataModule = class' + sLineBreak +
    '  Query: TFDQuery;' + sLineBreak +
    'end;' + sLineBreak +
    'Query.SQL.Text := ''select id from customer where id = :Id; select 2;'';'
  );
  LScanner := TRadIAFireDACScanner.Create(TRadIAWorkspaceBoundary.Create);
  try
    LJson := LScanner.GetProjectReport(FRootPath);
  finally
    LScanner.Free;
  end;
  Assert.Contains(LJson, '"inventory"');
  Assert.Contains(LJson, '"sqlAnalyses"');
  Assert.Contains(LJson, '"name":"Id"');
  Assert.Contains(LJson, 'firedac.sql.multiple-statements');
  Assert.DoesNotContain(LJson, 'select id from customer');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAFireDACScannerTests);

end.
