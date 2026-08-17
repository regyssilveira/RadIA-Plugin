unit RadIA.Core.LegacyDataMigrationTools;

interface

uses
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Patches,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

procedure RegisterRadIALegacyDataMigrationTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);

implementation

uses
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.LegacyDataMigration;

type
  TRadIALegacyMigrationToolKind = (
    lmtInventory,
    lmtPlanBatches,
    lmtPrepareBatch,
    lmtApplyBatch,
    lmtRecordGate,
    lmtReport,
    lmtPlanDext
  );

  IRadIALegacyMigrationSession = interface
    ['{5B46B669-D5DA-45C3-BD98-E5E19CC8A21B}']
    function Inventory: string;
    function PlanBatches: string;
    function PrepareBatch(const ABatchId: string): TRadIAToolResult;
    function ApplyBatch(const ABatchId: string): TRadIAToolResult;
    function RecordGate(
      const ABatchId: string;
      const AFireDACPassed: Boolean;
      const ABuildPassed: Boolean;
      const ATestsPassed: Boolean;
      const AFireDACEvidence: string;
      const ABuildEvidence: string;
      const ATestEvidence: string
    ): TRadIAToolResult;
    function Report: string;
    function PlanDext: string;
  end;

  TRadIALegacyMigrationSession = class(
    TInterfacedObject,
    IRadIALegacyMigrationSession
  )
  private
    FFiles: TArray<TRadIALegacySourceFile>;
    FFindings: TArray<TRadIALegacyMigrationFinding>;
    FBatches: TArray<TRadIALegacyMigrationBatch>;
    FPreviewIds: TDictionary<string, string>;
    FStates: TDictionary<string, string>;
    FBuildEvidence: TDictionary<string, string>;
    FFireDACEvidence: TDictionary<string, string>;
    FTestEvidence: TDictionary<string, string>;
    FWorkspace: IRadIAWorkspaceFacade;
    FMutation: IRadIAEditorMutationFacade;
    FPatches: IRadIAMultiFilePatchService;
    function AddFile(
      const AFileName: string;
      const AFiles: TList<TRadIALegacySourceFile>
    ): Boolean;
    function BatchById(
      const ABatchId: string;
      out ABatch: TRadIALegacyMigrationBatch
    ): Boolean;
    function FileByName(
      const AFileName: string;
      out AFile: TRadIALegacySourceFile
    ): Boolean;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AMutation: IRadIAEditorMutationFacade;
      const APatches: IRadIAMultiFilePatchService
    );
    destructor Destroy; override;
    function Inventory: string;
    function PlanBatches: string;
    function PrepareBatch(const ABatchId: string): TRadIAToolResult;
    function ApplyBatch(const ABatchId: string): TRadIAToolResult;
    function RecordGate(
      const ABatchId: string;
      const AFireDACPassed: Boolean;
      const ABuildPassed: Boolean;
      const ATestsPassed: Boolean;
      const AFireDACEvidence: string;
      const ABuildEvidence: string;
      const ATestEvidence: string
    ): TRadIAToolResult;
    function Report: string;
    function PlanDext: string;
  end;

  TRadIALegacyMigrationTool = class(TInterfacedObject, IRadIATool)
  private
    FKind: TRadIALegacyMigrationToolKind;
    FSession: IRadIALegacyMigrationSession;
    function GetDescriptor: TRadIAToolDescriptor;
  public
    constructor Create(
      const AKind: TRadIALegacyMigrationToolKind;
      const ASession: IRadIALegacyMigrationSession
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
  end;

const
  CMaxFileCharacters = 2 * 1024 * 1024;
  CEmptyInputSchema = '{"type":"object","additionalProperties":false}';
  CBatchInputSchema =
    '{"type":"object","required":["batchId"],"properties":{' +
    '"batchId":{"type":"string"}},"additionalProperties":false}';
  CGateInputSchema =
    '{"type":"object","required":["batchId","fireDACPassed","buildPassed",' +
    '"testsPassed","fireDACEvidence","buildEvidence","testEvidence"],"properties":{' +
    '"batchId":{"type":"string"},"fireDACPassed":{"type":"boolean"},' +
    '"buildPassed":{"type":"boolean"},"testsPassed":{"type":"boolean"},' +
    '"fireDACEvidence":{"type":"string","minLength":1,"maxLength":256},' +
    '"buildEvidence":{"type":"string","minLength":1,"maxLength":256},' +
    '"testEvidence":{"type":"string","minLength":1,"maxLength":256}},' +
    '"additionalProperties":false}';
  COutputSchema = '{"type":"object"}';

procedure RegisterRadIALegacyDataMigrationTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);
var
  LKind: TRadIALegacyMigrationToolKind;
  LSession: IRadIALegacyMigrationSession;
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  LSession := TRadIALegacyMigrationSession.Create(AWorkspace, AMutation, APatches);
  for LKind := Low(TRadIALegacyMigrationToolKind) to High(TRadIALegacyMigrationToolKind) do
    ARegistry.RegisterTool(TRadIALegacyMigrationTool.Create(LKind, LSession));
end;

constructor TRadIALegacyMigrationSession.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const APatches: IRadIAMultiFilePatchService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  FWorkspace := AWorkspace;
  FMutation := AMutation;
  FPatches := APatches;
  FPreviewIds := TDictionary<string, string>.Create;
  FStates := TDictionary<string, string>.Create;
  FBuildEvidence := TDictionary<string, string>.Create;
  FFireDACEvidence := TDictionary<string, string>.Create;
  FTestEvidence := TDictionary<string, string>.Create;
end;

destructor TRadIALegacyMigrationSession.Destroy;
begin
  FFireDACEvidence.Free;
  FTestEvidence.Free;
  FBuildEvidence.Free;
  FStates.Free;
  FPreviewIds.Free;
  inherited;
end;

function TRadIALegacyMigrationSession.AddFile(
  const AFileName: string;
  const AFiles: TList<TRadIALegacySourceFile>
): Boolean;
var
  LContent: TRadIAEditorContent;
  LExisting: TRadIALegacySourceFile;
begin
  Result := False;
  if Trim(AFileName) = '' then
    Exit;
  for LExisting in AFiles do
    if SameText(LExisting.FileName, AFileName) then
      Exit;
  LContent := FMutation.ReadContent(AFileName, CMaxFileCharacters);
  if LContent.Truncated or (LContent.FileName = '') then
    Exit;
  AFiles.Add(TRadIALegacySourceFile.Create(
    LContent.FileName,
    LContent.Revision,
    LContent.Content
  ));
  Result := True;
end;

function TRadIALegacyMigrationSession.Inventory: string;
var
  LArray: TJSONArray;
  LFileName: string;
  LFiles: TList<TRadIALegacySourceFile>;
  LFinding: TRadIALegacyMigrationFinding;
  LItem: TJSONObject;
  LJson: TJSONObject;
  LProject: TRadIAProjectSnapshot;
  LUnitName: string;
begin
  LFiles := TList<TRadIALegacySourceFile>.Create;
  try
    LProject := FWorkspace.GetActiveProject;
    AddFile(LProject.FileName, LFiles);
    for LUnitName in FWorkspace.ListProjectUnits do
    begin
      AddFile(LUnitName, LFiles);
      LFileName := ChangeFileExt(LUnitName, '.dfm');
      if TFile.Exists(LFileName) then
        AddFile(LFileName, LFiles)
      else
      begin
        LFileName := ChangeFileExt(LUnitName, '.fmx');
        if TFile.Exists(LFileName) then
          AddFile(LFileName, LFiles);
      end;
    end;
    FFiles := LFiles.ToArray;
  finally
    LFiles.Free;
  end;
  FFindings := TRadIALegacyDataMigrationAnalyzer.Inventory(FFiles);
  FBatches := nil;
  FPreviewIds.Clear;
  FStates.Clear;
  FBuildEvidence.Clear;
  FFireDACEvidence.Clear;
  FTestEvidence.Clear;
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('project', LProject.Name);
    LJson.AddPair('filesScanned', TJSONNumber.Create(Length(FFiles)));
    LJson.AddPair('findingCount', TJSONNumber.Create(Length(FFindings)));
    LArray := TJSONArray.Create;
    LJson.AddPair('findings', LArray);
    for LFinding in FFindings do
    begin
      LItem := TJSONObject.Create;
      LItem.AddPair('technology',
        TRadIALegacyDataMigrationAnalyzer.TechnologyName(LFinding.Technology));
      LItem.AddPair('risk', TRadIALegacyDataMigrationAnalyzer.RiskName(LFinding.Risk));
      LItem.AddPair('file', LFinding.FileName);
      LItem.AddPair('line', TJSONNumber.Create(LFinding.Line));
      LItem.AddPair('symbol', LFinding.Symbol);
      LItem.AddPair('replacement', LFinding.Replacement);
      LItem.AddPair('manualAction', LFinding.ManualAction);
      LItem.AddPair('canPrepare', TJSONBool.Create(LFinding.CanPrepare));
      LArray.AddElement(LItem);
    end;
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function TRadIALegacyMigrationSession.ApplyBatch(
  const ABatchId: string
): TRadIAToolResult;
var
  LPreviewId: string;
  LResult: TRadIAMultiFilePatchResult;
  LState: string;
begin
  if not FPreviewIds.TryGetValue(ABatchId, LPreviewId) then
    Exit(TRadIAToolResult.Failed('batch_not_prepared', 'Prepare the migration batch first.'));
  if not FStates.TryGetValue(ABatchId, LState) or not SameText(LState, 'prepared') then
    Exit(TRadIAToolResult.Failed('invalid_batch_state', 'Only a prepared batch can be applied.'));
  LResult := FPatches.Apply(LPreviewId);
  if not LResult.Success then
    Exit(TRadIAToolResult.Failed(LResult.ErrorCode, LResult.ErrorMessage));
  FStates.AddOrSetValue(ABatchId, 'applied');
  Result := TRadIAToolResult.Succeeded(
    Format('{"batchId":"%s","previewId":"%s","state":"applied"}',
      [ABatchId, LPreviewId])
  );
end;

function TRadIALegacyMigrationSession.PlanBatches: string;
var
  LArray: TJSONArray;
  LBatch: TRadIALegacyMigrationBatch;
  LItem: TJSONObject;
  LJson: TJSONObject;
begin
  FBatches := TRadIALegacyDataMigrationAnalyzer.PlanBatches(FFindings);
  FStates.Clear;
  LJson := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LJson.AddPair('batches', LArray);
    for LBatch in FBatches do
    begin
      FStates.AddOrSetValue(LBatch.Id, 'planned');
      LItem := TJSONObject.Create;
      LItem.AddPair('batchId', LBatch.Id);
      LItem.AddPair('technology',
        TRadIALegacyDataMigrationAnalyzer.TechnologyName(LBatch.Technology));
      LItem.AddPair('file', LBatch.FileName);
      LItem.AddPair('findingCount', TJSONNumber.Create(LBatch.FindingCount));
      LItem.AddPair('canPrepare', TJSONBool.Create(LBatch.CanPrepare));
      LArray.AddElement(LItem);
    end;
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function TRadIALegacyMigrationSession.BatchById(
  const ABatchId: string;
  out ABatch: TRadIALegacyMigrationBatch
): Boolean;
var
  LBatch: TRadIALegacyMigrationBatch;
begin
  for LBatch in FBatches do
    if SameText(LBatch.Id, ABatchId) then
    begin
      ABatch := LBatch;
      Exit(True);
    end;
  ABatch := Default(TRadIALegacyMigrationBatch);
  Result := False;
end;

function TRadIALegacyMigrationSession.FileByName(
  const AFileName: string;
  out AFile: TRadIALegacySourceFile
): Boolean;
var
  LFile: TRadIALegacySourceFile;
begin
  for LFile in FFiles do
    if SameText(LFile.FileName, AFileName) then
    begin
      AFile := LFile;
      Exit(True);
    end;
  AFile := Default(TRadIALegacySourceFile);
  Result := False;
end;

function TRadIALegacyMigrationSession.PrepareBatch(
  const ABatchId: string
): TRadIAToolResult;
var
  LBatch: TRadIALegacyMigrationBatch;
  LFile: TRadIALegacySourceFile;
  LProposed: string;
  LResult: TRadIAMultiFilePatchResult;
begin
  if not BatchById(ABatchId, LBatch) then
    Exit(TRadIAToolResult.Failed('batch_not_found', 'Migration batch was not found.'));
  if not LBatch.CanPrepare then
    Exit(TRadIAToolResult.Failed('manual_batch',
      'This batch only contains high-risk changes and requires manual migration.'));
  if not FileByName(LBatch.FileName, LFile) then
    Exit(TRadIAToolResult.Failed('file_not_found', 'Migration source file was not found.'));
  LProposed := TRadIALegacyDataMigrationAnalyzer.PrepareContent(
    LFile.Content,
    FFindings,
    LFile.FileName,
    LBatch.Technology
  );
  LResult := FPatches.Prepare([
    TRadIAMultiFilePatchSpec.Create(LFile.FileName, LFile.Revision, LProposed)
  ]);
  if not LResult.Success then
    Exit(TRadIAToolResult.Failed(LResult.ErrorCode, LResult.ErrorMessage));
  FPreviewIds.AddOrSetValue(ABatchId, LResult.Preview.Id);
  FStates.AddOrSetValue(ABatchId, 'prepared');
  Result := TRadIAToolResult.Succeeded(
    Format('{"batchId":"%s","previewId":"%s","state":"prepared"}',
      [ABatchId, LResult.Preview.Id])
  );
end;

function TRadIALegacyMigrationSession.RecordGate(
  const ABatchId: string;
  const AFireDACPassed: Boolean;
  const ABuildPassed: Boolean;
  const ATestsPassed: Boolean;
  const AFireDACEvidence: string;
  const ABuildEvidence: string;
  const ATestEvidence: string
): TRadIAToolResult;
var
  LPreviewId: string;
  LResult: TRadIAMultiFilePatchResult;
  LState: string;
begin
  if not FPreviewIds.TryGetValue(ABatchId, LPreviewId) then
    Exit(TRadIAToolResult.Failed('batch_not_prepared', 'Prepare the batch first.'));
  if not FStates.TryGetValue(ABatchId, LState) or not SameText(LState, 'applied') then
    Exit(TRadIAToolResult.Failed('batch_not_applied', 'Apply the batch before recording gates.'));
  if Trim(AFireDACEvidence) = '' then
    Exit(TRadIAToolResult.Failed('missing_firedac_evidence', 'FireDAC evidence is required.'));
  if Trim(ABuildEvidence) = '' then
    Exit(TRadIAToolResult.Failed('missing_build_evidence', 'Build evidence is required.'));
  if Trim(ATestEvidence) = '' then
    Exit(TRadIAToolResult.Failed('missing_test_evidence', 'Test evidence is required.'));
  if (Length(AFireDACEvidence) > 256) or
    (Length(ABuildEvidence) > 256) or
    (Length(ATestEvidence) > 256) then
    Exit(TRadIAToolResult.Failed('evidence_too_large', 'Gate evidence must not exceed 256 characters.'));
  FFireDACEvidence.AddOrSetValue(ABatchId, THashSHA2.GetHashString(AFireDACEvidence));
  FBuildEvidence.AddOrSetValue(ABatchId, THashSHA2.GetHashString(ABuildEvidence));
  FTestEvidence.AddOrSetValue(ABatchId, THashSHA2.GetHashString(ATestEvidence));
  if AFireDACPassed and ABuildPassed and ATestsPassed then
    LState := 'validated'
  else
  begin
    LResult := FPatches.Revert(LPreviewId);
    if not LResult.Success then
      Exit(TRadIAToolResult.Failed(LResult.ErrorCode, LResult.ErrorMessage));
    LState := 'reverted';
  end;
  FStates.AddOrSetValue(ABatchId, LState);
  Result := TRadIAToolResult.Succeeded(
    Format('{"batchId":"%s","state":"%s","fireDACPassed":%s,' +
      '"buildPassed":%s,"testsPassed":%s}',
      [ABatchId, LState, LowerCase(BoolToStr(AFireDACPassed, True)),
      LowerCase(BoolToStr(ABuildPassed, True)),
      LowerCase(BoolToStr(ATestsPassed, True))])
  );
end;

function TRadIALegacyMigrationSession.Report: string;
var
  LArray: TJSONArray;
  LBatch: TRadIALegacyMigrationBatch;
  LFinding: TRadIALegacyMigrationFinding;
  LItem: TJSONObject;
  LJson: TJSONObject;
  LState: string;
  LEvidence: string;
begin
  LJson := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    LJson.AddPair('batches', LArray);
    for LBatch in FBatches do
    begin
      if not FStates.TryGetValue(LBatch.Id, LState) then
        LState := 'planned';
      LItem := TJSONObject.Create;
      LItem.AddPair('batchId', LBatch.Id);
      LItem.AddPair('file', LBatch.FileName);
      LItem.AddPair('state', LState);
      if not FFireDACEvidence.TryGetValue(LBatch.Id, LEvidence) then
        LEvidence := '';
      LItem.AddPair('fireDACEvidenceFingerprint', LEvidence);
      if not FBuildEvidence.TryGetValue(LBatch.Id, LEvidence) then
        LEvidence := '';
      LItem.AddPair('buildEvidence', LEvidence);
      if not FTestEvidence.TryGetValue(LBatch.Id, LEvidence) then
        LEvidence := '';
      LItem.AddPair('testEvidence', LEvidence);
      LArray.AddElement(LItem);
    end;
    LArray := TJSONArray.Create;
    LJson.AddPair('manualActions', LArray);
    for LFinding in FFindings do
      if not LFinding.CanPrepare then
        LArray.Add(Format('%s:%d - %s',
          [LFinding.FileName, LFinding.Line, LFinding.ManualAction]));
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function TRadIALegacyMigrationSession.PlanDext: string;
begin
  Result := '{"automaticRewrite":false,"stages":[' +
    '"Validate every FireDAC migration batch",' +
    '"Extract data access interfaces from forms",' +
    '"Introduce a DEXT boundary only after behavioral parity",' +
    '"Decompose forms by data, action and navigation responsibilities"],' +
    '"precondition":"All migration batches must be validated or documented as manual"}';
end;

constructor TRadIALegacyMigrationTool.Create(
  const AKind: TRadIALegacyMigrationToolKind;
  const ASession: IRadIALegacyMigrationSession
);
begin
  inherited Create;
  FKind := AKind;
  FSession := ASession;
end;

function TRadIALegacyMigrationTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LJson: TJSONObject;
begin
  try
    case FKind of
      lmtInventory:
        Exit(TRadIAToolResult.Succeeded(FSession.Inventory));
      lmtPlanBatches:
        Exit(TRadIAToolResult.Succeeded(FSession.PlanBatches));
      lmtReport:
        Exit(TRadIAToolResult.Succeeded(FSession.Report));
      lmtPlanDext:
        Exit(TRadIAToolResult.Succeeded(FSession.PlanDext));
    end;
    LJson := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
    try
      if not Assigned(LJson) then
        Exit(TRadIAToolResult.Failed('invalid_arguments', 'Arguments must be a JSON object.'));
      if FKind = lmtPrepareBatch then
        Exit(FSession.PrepareBatch(LJson.GetValue<string>('batchId', '')));
      if FKind = lmtApplyBatch then
        Exit(FSession.ApplyBatch(LJson.GetValue<string>('batchId', '')));
      Result := FSession.RecordGate(
        LJson.GetValue<string>('batchId', ''),
        LJson.GetValue<Boolean>('fireDACPassed', False),
        LJson.GetValue<Boolean>('buildPassed', False),
        LJson.GetValue<Boolean>('testsPassed', False),
        LJson.GetValue<string>('fireDACEvidence', ''),
        LJson.GetValue<string>('buildEvidence', ''),
        LJson.GetValue<string>('testEvidence', '')
      );
    finally
      LJson.Free;
    end;
  except
    on E: Exception do
      Result := TRadIAToolResult.Failed('legacy_migration_failed', E.Message);
  end;
end;

function TRadIALegacyMigrationTool.GetDescriptor: TRadIAToolDescriptor;
var
  LDescription: string;
  LInputSchema: string;
  LName: string;
  LRisk: TRadIAToolRisk;
begin
  case FKind of
    lmtInventory:
      begin
        LName := 'InventoryLegacyDataAccess';
        LDescription := 'Inventories BDE, ADO and dbExpress references in the active project.';
      end;
    lmtPlanBatches:
      begin
        LName := 'PlanLegacyMigrationBatches';
        LDescription := 'Groups legacy data findings into bounded technology and file batches.';
      end;
    lmtPrepareBatch:
      begin
        LName := 'PrepareLegacyMigrationBatch';
        LDescription := 'Prepares a reversible preview for deterministic changes in one batch.';
      end;
    lmtApplyBatch:
      begin
        LName := 'ApplyLegacyMigrationBatch';
        LDescription := 'Applies one prepared migration batch before FireDAC, build and test gates.';
      end;
    lmtRecordGate:
      begin
        LName := 'RecordLegacyMigrationGate';
        LDescription := 'Records build and test evidence, reverting a failed applied batch.';
      end;
    lmtReport:
      begin
        LName := 'GetLegacyMigrationReport';
        LDescription := 'Reports batch compatibility, gate evidence and required manual actions.';
      end;
  else
    LName := 'PlanDextAndFormModernization';
    LDescription := 'Plans DEXT adoption and form decomposition after data migration.';
  end;
  if FKind in [lmtPrepareBatch, lmtApplyBatch] then
    LInputSchema := CBatchInputSchema
  else if FKind = lmtRecordGate then
    LInputSchema := CGateInputSchema
  else
    LInputSchema := CEmptyInputSchema;
  if FKind in [lmtApplyBatch, lmtRecordGate] then
    LRisk := trReversibleWrite
  else
    LRisk := trReadOnly;
  Result := TRadIAToolDescriptor.Create(
    LName,
    '1.0.0',
    LDescription,
    LInputSchema,
    COutputSchema,
    LRisk
  );
end;

end.
