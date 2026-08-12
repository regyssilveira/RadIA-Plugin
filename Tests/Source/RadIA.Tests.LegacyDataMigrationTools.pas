unit RadIA.Tests.LegacyDataMigrationTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Tools,
  RadIA.Tests.MultiFilePatches;

type
  [TestFixture]
  TRadIALegacyDataMigrationToolTests = class
  private
    FPatchService: IRadIAMultiFilePatchService;
    FRegistry: IRadIAToolRegistry;
    FRootPath: string;
    FUnitFile: string;
    FWorkspace: TRadIAMultiFileWorkspaceStub;
    function Execute(const AName: string; const AArguments: string): TRadIAToolResult;
    function PreviewIdOf(const AJson: string): string;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure RegistersSixMigrationTools;
    [Test]
    procedure InventoriesPlansAndPreparesActiveProject;
    [Test]
    procedure FailedGateRevertsAppliedBatch;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.LegacyDataMigrationTools,
  RadIA.Core.Patches,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

function TRadIALegacyDataMigrationToolTests.Execute(
  const AName: string;
  const AArguments: string
): TRadIAToolResult;
begin
  Result := FRegistry.Resolve(AName).Execute(
    TRadIAToolRequest.Create(AName, AArguments, 'test')
  );
end;

function TRadIALegacyDataMigrationToolTests.PreviewIdOf(
  const AJson: string
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  try
    Result := LJson.GetValue<string>('previewId', '');
  finally
    LJson.Free;
  end;
end;

procedure TRadIALegacyDataMigrationToolTests.Setup;
var
  LBoundary: IRadIAWorkspaceBoundary;
  LMutation: IRadIAEditorMutationFacade;
  LWorkspaceFacade: IRadIAWorkspaceFacade;
begin
  FRootPath := TPath.Combine(TPath.GetTempPath,
    'RadIALegacyMigration-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FRootPath);
  FUnitFile := TPath.Combine(FRootPath, 'LegacyData.pas');
  FWorkspace := TRadIAMultiFileWorkspaceStub.Create(FRootPath);
  FWorkspace.AddFile(FUnitFile, 'uses ADODB; var Query: TADOQuery;');
  FWorkspace.AddFile(TPath.Combine(FRootPath, 'MultiFileTest.dproj'),
    '<Project><DCCReference Include="LegacyData.pas"/></Project>');
  LWorkspaceFacade := FWorkspace;
  LMutation := FWorkspace;
  LBoundary := TRadIAWorkspaceBoundary.Create;
  FPatchService := TRadIAMultiFilePatchService.Create(
    LWorkspaceFacade,
    LMutation,
    LBoundary
  );
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIALegacyDataMigrationTools(
    FRegistry,
    LWorkspaceFacade,
    LMutation,
    FPatchService
  );
end;

procedure TRadIALegacyDataMigrationToolTests.RegistersSixMigrationTools;
begin
  Assert.AreEqual<Integer>(6, FRegistry.Count);
  Assert.AreEqual(trReversibleWrite,
    FRegistry.Resolve('PrepareLegacyMigrationBatch').Descriptor.Risk);
  Assert.AreEqual(trReadOnly,
    FRegistry.Resolve('GetLegacyMigrationReport').Descriptor.Risk);
end;

procedure TRadIALegacyDataMigrationToolTests.InventoriesPlansAndPreparesActiveProject;
var
  LResult: TRadIAToolResult;
begin
  LResult := Execute('InventoryLegacyDataAccess', '{}');
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, 'TADOQuery');
  LResult := Execute('PlanLegacyMigrationBatches', '{}');
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, 'legacy-1-');
  LResult := Execute('PrepareLegacyMigrationBatch', '{"batchId":"legacy-1-2"}');
  if not LResult.Success then
    LResult := Execute('PrepareLegacyMigrationBatch', '{"batchId":"legacy-1-1"}');
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, 'previewId');
  Assert.Contains(FWorkspace.ContentOf(FUnitFile), 'TADOQuery');
end;

procedure TRadIALegacyDataMigrationToolTests.FailedGateRevertsAppliedBatch;
var
  LApply: TRadIAMultiFilePatchResult;
  LBatchId: string;
  LPrepare: TRadIAToolResult;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  Execute('InventoryLegacyDataAccess', '{}');
  Execute('PlanLegacyMigrationBatches', '{}');
  LBatchId := 'legacy-1-2';
  LPrepare := Execute('PrepareLegacyMigrationBatch',
    '{"batchId":"' + LBatchId + '"}');
  if not LPrepare.Success then
  begin
    LBatchId := 'legacy-1-1';
    LPrepare := Execute('PrepareLegacyMigrationBatch',
      '{"batchId":"' + LBatchId + '"}');
  end;
  Assert.IsTrue(LPrepare.Success, LPrepare.ErrorMessage);
  LPreviewId := PreviewIdOf(LPrepare.ContentJson);
  LApply := FPatchService.Apply(LPreviewId);
  Assert.IsTrue(LApply.Success, LApply.ErrorMessage);
  Assert.Contains(FWorkspace.ContentOf(FUnitFile), 'TFDQuery');
  LResult := Execute('RecordLegacyMigrationGate',
    '{"batchId":"' + LBatchId + '","buildPassed":false,' +
    '"testsPassed":true,"buildEvidence":"compiler error",' +
    '"testEvidence":"tests passed"}');
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, 'reverted');
  Assert.Contains(FWorkspace.ContentOf(FUnitFile), 'TADOQuery');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIALegacyDataMigrationToolTests);

end.
