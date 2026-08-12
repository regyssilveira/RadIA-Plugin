unit RadIA.Tests.LegacyDataMigration;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIALegacyDataMigrationTests = class
  public
    [Test]
    procedure InventoriesBdeAdoAndDbExpressSources;
    [Test]
    procedure ClassifiesConnectionAsManualHighRisk;
    [Test]
    procedure CreatesSmallBatchesPerTechnologyAndFile;
    [Test]
    procedure PreparesOnlyDeterministicReplacements;
    [Test]
    procedure PreparesOnlyTheRequestedTechnology;
    [Test]
    procedure DoesNotMatchIdentifierFragments;
  end;

implementation

uses
  RadIA.Core.LegacyDataMigration;

function Source(
  const AFileName: string;
  const AContent: string
): TRadIALegacySourceFile;
begin
  Result := TRadIALegacySourceFile.Create(AFileName, 'revision', AContent);
end;

procedure TRadIALegacyDataMigrationTests.InventoriesBdeAdoAndDbExpressSources;
var
  LFiles: TArray<TRadIALegacySourceFile>;
  LFindings: TArray<TRadIALegacyMigrationFinding>;
begin
  LFiles := [
    Source('BdeUnit.pas', 'uses DBTables; var Query: TQuery;'),
    Source('AdoForm.dfm', 'object Connection: TADOConnection'),
    Source('SqlData.dfm', 'object DataSet: TSQLDataSet')
  ];
  LFindings := TRadIALegacyDataMigrationAnalyzer.Inventory(LFiles);
  Assert.AreEqual<Integer>(4, Length(LFindings));
  Assert.AreEqual('BDE',
    TRadIALegacyDataMigrationAnalyzer.TechnologyName(LFindings[0].Technology));
  Assert.AreEqual('ADO',
    TRadIALegacyDataMigrationAnalyzer.TechnologyName(LFindings[2].Technology));
  Assert.AreEqual('dbExpress',
    TRadIALegacyDataMigrationAnalyzer.TechnologyName(LFindings[3].Technology));
end;

procedure TRadIALegacyDataMigrationTests.ClassifiesConnectionAsManualHighRisk;
var
  LFindings: TArray<TRadIALegacyMigrationFinding>;
begin
  LFindings := TRadIALegacyDataMigrationAnalyzer.Inventory([
    Source('Data.dfm', 'object Connection: TADOConnection')
  ]);
  Assert.AreEqual<Integer>(1, Length(LFindings));
  Assert.AreEqual('high',
    TRadIALegacyDataMigrationAnalyzer.RiskName(LFindings[0].Risk));
  Assert.IsFalse(LFindings[0].CanPrepare);
  Assert.AreEqual('TFDConnection', LFindings[0].Replacement);
end;

procedure TRadIALegacyDataMigrationTests.CreatesSmallBatchesPerTechnologyAndFile;
var
  LBatches: TArray<TRadIALegacyMigrationBatch>;
  LFindings: TArray<TRadIALegacyMigrationFinding>;
begin
  LFindings := TRadIALegacyDataMigrationAnalyzer.Inventory([
    Source('One.pas', 'uses ADODB; var Query: TADOQuery;'),
    Source('Two.dfm', 'object Query: TADOQuery'),
    Source('Three.pas', 'uses DBTables; var Query: TQuery;')
  ]);
  LBatches := TRadIALegacyDataMigrationAnalyzer.PlanBatches(LFindings);
  Assert.AreEqual<Integer>(3, Length(LBatches));
  Assert.AreEqual<Integer>(2, LBatches[0].FindingCount);
  Assert.IsTrue(LBatches[0].CanPrepare);
end;

procedure TRadIALegacyDataMigrationTests.PreparesOnlyDeterministicReplacements;
var
  LContent: string;
  LFindings: TArray<TRadIALegacyMigrationFinding>;
begin
  LContent := 'uses ADODB; var Connection: TADOConnection; Query: TADOQuery;';
  LFindings := TRadIALegacyDataMigrationAnalyzer.Inventory([
    Source('Data.pas', LContent)
  ]);
  LContent := TRadIALegacyDataMigrationAnalyzer.PrepareContent(
    LContent,
    LFindings,
    'Data.pas',
    ldtADO
  );
  Assert.Contains(LContent, 'FireDAC.Comp.Client');
  Assert.Contains(LContent, 'TFDQuery');
  Assert.Contains(LContent, 'TADOConnection');
  Assert.DoesNotContain(LContent, 'TADOQuery');
end;

procedure TRadIALegacyDataMigrationTests.PreparesOnlyTheRequestedTechnology;
var
  LContent: string;
  LFindings: TArray<TRadIALegacyMigrationFinding>;
begin
  LContent := 'uses ADODB, DBTables; var AdoQuery: TADOQuery; BdeQuery: TQuery;';
  LFindings := TRadIALegacyDataMigrationAnalyzer.Inventory([
    Source('Mixed.pas', LContent)
  ]);
  LContent := TRadIALegacyDataMigrationAnalyzer.PrepareContent(
    LContent,
    LFindings,
    'Mixed.pas',
    ldtADO
  );
  Assert.Contains(LContent, 'TFDQuery');
  Assert.Contains(LContent, 'DBTables');
  Assert.Contains(LContent, 'TQuery');
end;

procedure TRadIALegacyDataMigrationTests.DoesNotMatchIdentifierFragments;
var
  LFindings: TArray<TRadIALegacyMigrationFinding>;
begin
  LFindings := TRadIALegacyDataMigrationAnalyzer.Inventory([
    Source('Safe.pas', 'type TADOQueryFactory = class;')
  ]);
  Assert.AreEqual<Integer>(0, Length(LFindings));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIALegacyDataMigrationTests);

end.
