unit RadIA.Core.DextFormModernization;

interface

uses
  System.JSON,
  RadIA.Core.DfmPasAudit,
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Tools;

type
  IRadIADextFormModernizationService = interface
    ['{A3B29261-37F4-444D-B8DB-64DFA09B4D33}']
    function Prepare(const AArguments: TJSONObject): TRadIAToolResult;
    function RecordGate(const AArguments: TJSONObject): TRadIAToolResult;
  end;

  TRadIADextFormModernizationService = class(
    TInterfacedObject,
    IRadIADextFormModernizationService
  )
  private
    FAuditor: IRadIADfmPasAuditor;
    FPatches: IRadIAMultiFilePatchService;
    function BuildSpecs(
      const AFiles: TJSONArray;
      out ASpecs: TArray<TRadIAMultiFilePatchSpec>;
      out AError: string
    ): Boolean;
    function MigrationIsReady(const AReport: TJSONObject; out AError: string): Boolean;
    function ProposedStructureIsSafe(const AFiles: TJSONArray; out AError: string): Boolean;
    function ValidateDfmPair(const AFiles: TJSONArray; out AError: string): Boolean;
  public
    constructor Create(
      const APatches: IRadIAMultiFilePatchService;
      const AAuditor: IRadIADfmPasAuditor
    );
    function Prepare(const AArguments: TJSONObject): TRadIAToolResult;
    function RecordGate(const AArguments: TJSONObject): TRadIAToolResult;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils;

constructor TRadIADextFormModernizationService.Create(
  const APatches: IRadIAMultiFilePatchService;
  const AAuditor: IRadIADfmPasAuditor
);
begin
  inherited Create;
  if not Assigned(APatches) then
    raise EArgumentNilException.Create('APatches');
  if not Assigned(AAuditor) then
    raise EArgumentNilException.Create('AAuditor');
  FPatches := APatches;
  FAuditor := AAuditor;
end;

function TRadIADextFormModernizationService.MigrationIsReady(
  const AReport: TJSONObject;
  out AError: string
): Boolean;
var
  LBatches: TJSONArray;
  LIndex: Integer;
  LState: string;
begin
  AError := '';
  if not Assigned(AReport) then
  begin
    AError := 'A legacy migration report is required.';
    Exit(False);
  end;
  LBatches := AReport.GetValue<TJSONArray>('batches');
  if not Assigned(LBatches) then
  begin
    AError := 'The migration report must contain batches.';
    Exit(False);
  end;
  for LIndex := 0 to LBatches.Count - 1 do
  begin
    LState := TJSONObject(LBatches[LIndex]).GetValue<string>('state', 'planned');
    if not SameText(LState, 'validated') then
    begin
      AError := 'Every legacy migration batch must be validated before DEXT adoption.';
      Exit(False);
    end;
  end;
  Result := True;
end;

function TRadIADextFormModernizationService.ProposedStructureIsSafe(
  const AFiles: TJSONArray;
  out AError: string
): Boolean;
var
  LContent: string;
  LHasDextBoundary: Boolean;
  LHasExtractedResponsibility: Boolean;
  LIndex: Integer;
  LName: string;
begin
  if not Assigned(AFiles) then
  begin
    AError := 'Proposed files are required.';
    Exit(False);
  end;
  LHasDextBoundary := False;
  LHasExtractedResponsibility := False;
  for LIndex := 0 to AFiles.Count - 1 do
  begin
    LName := TJSONObject(AFiles[LIndex]).GetValue<string>('targetFile', '');
    LContent := TJSONObject(AFiles[LIndex]).GetValue<string>('proposedContent', '');
    LHasDextBoundary := LHasDextBoundary or LContent.Contains('Dext.Web') or
      LContent.Contains('IWebApplication');
    LHasExtractedResponsibility := LHasExtractedResponsibility or
      (not LName.EndsWith('.dfm', True) and
      (LName.Contains('.Presenter.') or LName.Contains('.Service.') or
      LName.Contains('.Controller.')));
  end;
  if not LHasDextBoundary then
  begin
    AError := 'The proposed files must introduce an explicit DEXT boundary.';
    Exit(False);
  end;
  if not LHasExtractedResponsibility then
  begin
    AError := 'At least one presenter, service, or controller responsibility must be extracted.';
    Exit(False);
  end;
  Result := True;
end;

function TRadIADextFormModernizationService.ValidateDfmPair(
  const AFiles: TJSONArray;
  out AError: string
): Boolean;
var
  LDfmContent: string;
  LDfmFile: string;
  LIndex: Integer;
  LPasContent: string;
  LPasFile: string;
  LResult: TRadIADfmPasAuditResult;
begin
  LDfmFile := '';
  LPasFile := '';
  for LIndex := 0 to AFiles.Count - 1 do
    with TJSONObject(AFiles[LIndex]) do
      if GetValue<string>('targetFile', '').EndsWith('.dfm', True) then
      begin
        LDfmFile := GetValue<string>('targetFile', '');
        LDfmContent := GetValue<string>('proposedContent', '');
      end;
  for LIndex := 0 to AFiles.Count - 1 do
    with TJSONObject(AFiles[LIndex]) do
      if GetValue<string>('targetFile', '').EndsWith('.pas', True) and
        SameText(
          TPath.GetFileNameWithoutExtension(GetValue<string>('targetFile', '')),
          TPath.GetFileNameWithoutExtension(LDfmFile)
        ) then
      begin
        LPasFile := GetValue<string>('targetFile', '');
        LPasContent := GetValue<string>('proposedContent', '');
      end;
  if LDfmFile.IsEmpty or LPasFile.IsEmpty then
  begin
    AError := 'A matching proposed DFM/Pascal form pair is required.';
    Exit(False);
  end;
  LResult := FAuditor.Audit(TRadIADfmPasAuditInput.Create(
    LDfmFile,
    LDfmContent,
    LPasFile,
    LPasContent
  ));
  if LResult.HasErrors then
  begin
    AError := 'The proposed form fails DFM/Pascal consistency audit.';
    Exit(False);
  end;
  Result := True;
end;

function TRadIADextFormModernizationService.BuildSpecs(
  const AFiles: TJSONArray;
  out ASpecs: TArray<TRadIAMultiFilePatchSpec>;
  out AError: string
): Boolean;
var
  LFile: TJSONObject;
  LIndex: Integer;
begin
  if not Assigned(AFiles) or (AFiles.Count < 3) then
  begin
    AError := 'At least the form pair and one extracted responsibility are required.';
    Exit(False);
  end;
  SetLength(ASpecs, AFiles.Count);
  for LIndex := 0 to AFiles.Count - 1 do
  begin
    LFile := TJSONObject(AFiles[LIndex]);
    ASpecs[LIndex] := TRadIAMultiFilePatchSpec.Create(
      LFile.GetValue<string>('targetFile', ''),
      LFile.GetValue<string>('baseRevision', ''),
      LFile.GetValue<string>('proposedContent', '')
    );
  end;
  Result := True;
end;

function TRadIADextFormModernizationService.Prepare(
  const AArguments: TJSONObject
): TRadIAToolResult;
var
  LError: string;
  LFiles: TJSONArray;
  LMigrationReport: TJSONObject;
  LResult: TRadIAMultiFilePatchResult;
  LSpecs: TArray<TRadIAMultiFilePatchSpec>;
begin
  if AArguments.GetValue<string>('parityEvidence', '').Trim.IsEmpty then
    Exit(TRadIAToolResult.Failed('missing_parity_evidence', 'Behavioral parity evidence is required.'));
  LMigrationReport := AArguments.GetValue<TJSONObject>('migrationReport');
  if not MigrationIsReady(LMigrationReport, LError) then
    Exit(TRadIAToolResult.Failed('migration_not_ready', LError));
  LFiles := AArguments.GetValue<TJSONArray>('files');
  if not ProposedStructureIsSafe(LFiles, LError) then
    Exit(TRadIAToolResult.Failed('unsafe_structure', LError));
  if not ValidateDfmPair(LFiles, LError) then
    Exit(TRadIAToolResult.Failed('dfm_pas_inconsistent', LError));
  if not BuildSpecs(LFiles, LSpecs, LError) then
    Exit(TRadIAToolResult.Failed('invalid_files', LError));
  LResult := FPatches.Prepare(LSpecs);
  if not LResult.Success then
    Exit(TRadIAToolResult.Failed(LResult.ErrorCode, LResult.ErrorMessage));
  Result := TRadIAToolResult.Succeeded(
    Format('{"previewId":"%s","state":"prepared","files":%d}',
      [LResult.Preview.Id, Length(LResult.Preview.Entries)])
  );
end;

function TRadIADextFormModernizationService.RecordGate(
  const AArguments: TJSONObject
): TRadIAToolResult;
var
  LPreviewId: string;
  LResult: TRadIAMultiFilePatchResult;
begin
  LPreviewId := AArguments.GetValue<string>('previewId', '');
  if LPreviewId.IsEmpty then
    Exit(TRadIAToolResult.Failed('missing_preview', 'Preview ID is required.'));
  if AArguments.GetValue<string>('buildEvidence', '').Trim.IsEmpty or
    AArguments.GetValue<string>('testEvidence', '').Trim.IsEmpty then
    Exit(TRadIAToolResult.Failed('missing_evidence', 'Build and test evidence are required.'));
  if AArguments.GetValue<Boolean>('buildPassed', False) and
    AArguments.GetValue<Boolean>('testsPassed', False) then
    Exit(TRadIAToolResult.Succeeded(
      Format('{"previewId":"%s","state":"validated"}', [LPreviewId])
    ));
  LResult := FPatches.Revert(LPreviewId);
  if not LResult.Success then
    Exit(TRadIAToolResult.Failed(LResult.ErrorCode, LResult.ErrorMessage));
  Result := TRadIAToolResult.Succeeded(
    Format('{"previewId":"%s","state":"reverted"}', [LPreviewId])
  );
end;

end.
