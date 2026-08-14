unit RadIA.Tests.DextFormModernization;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIADextFormModernizationTests = class
  public
    [Test]
    procedure PreparesValidatedReversibleStage;
    [Test]
    procedure RejectsUnvalidatedMigration;
    [Test]
    procedure RevertsFailedGate;
  end;

implementation

uses
  RadIA.Core.DextFormModernization,
  RadIA.Core.DfmPasAudit,
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Tools,
  System.DateUtils,
  System.JSON,
  System.SysUtils;

type
  TRadIADextFormPatchStub = class(TInterfacedObject, IRadIAMultiFilePatchService)
  private
    FPrepared: Boolean;
    FReverted: Boolean;
  public
    function Apply(const APreviewId: string): TRadIAMultiFilePatchResult;
    procedure Clear;
    function Prepare(
      const ASpecs: TArray<TRadIAMultiFilePatchSpec>
    ): TRadIAMultiFilePatchResult;
    function Revert(const APreviewId: string): TRadIAMultiFilePatchResult;
    property Prepared: Boolean read FPrepared;
    property Reverted: Boolean read FReverted;
  end;

  TRadIADextFormAuditStub = class(TInterfacedObject, IRadIADfmPasAuditor)
  public
    function Audit(const AInput: TRadIADfmPasAuditInput): TRadIADfmPasAuditResult;
  end;

function BuildArguments(const AState: string): TJSONObject;
var
  LBatches: TJSONArray;
  LFiles: TJSONArray;
  LReport: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('parityEvidence', 'Existing UI scenario passed.');
  LReport := TJSONObject.Create;
  LBatches := TJSONArray.Create;
  LBatches.AddElement(TJSONObject.Create.AddPair('state', AState));
  LReport.AddPair('batches', LBatches);
  Result.AddPair('migrationReport', LReport);
  LFiles := TJSONArray.Create;
  LFiles.AddElement(TJSONObject.Create
    .AddPair('targetFile', 'MainForm.dfm')
    .AddPair('baseRevision', 'dfm-revision')
    .AddPair('proposedContent', 'object MainForm: TMainForm end'));
  LFiles.AddElement(TJSONObject.Create
    .AddPair('targetFile', 'MainForm.pas')
    .AddPair('baseRevision', 'pas-revision')
    .AddPair('proposedContent', 'unit MainForm; interface uses Dext.Web; type TMainForm = class end; end.'));
  LFiles.AddElement(TJSONObject.Create
    .AddPair('targetFile', 'RadIA.UI.MainForm.Presenter.pas')
    .AddPair('baseRevision', 'presenter-revision')
    .AddPair('proposedContent', 'unit RadIA.UI.MainForm.Presenter; interface end.'));
  Result.AddPair('files', LFiles);
end;

function TRadIADextFormPatchStub.Apply(
  const APreviewId: string
): TRadIAMultiFilePatchResult;
begin
  Result := TRadIAMultiFilePatchResult.Failed('', '');
end;

procedure TRadIADextFormPatchStub.Clear;
begin
  FPrepared := False;
  FReverted := False;
end;

function TRadIADextFormPatchStub.Prepare(
  const ASpecs: TArray<TRadIAMultiFilePatchSpec>
): TRadIAMultiFilePatchResult;
var
  LEntries: TArray<TRadIAMultiFilePatchEntry>;
  LIndex: Integer;
begin
  FPrepared := True;
  SetLength(LEntries, Length(ASpecs));
  for LIndex := Low(ASpecs) to High(ASpecs) do
    LEntries[LIndex] := TRadIAMultiFilePatchEntry.Create(ASpecs[LIndex], '', 'new-revision');
  Result := TRadIAMultiFilePatchResult.Succeeded(
    TRadIAMultiFilePatchPreview.Create('modernization-preview', LEntries, IncMinute(Now, 10))
  );
end;

function TRadIADextFormPatchStub.Revert(
  const APreviewId: string
): TRadIAMultiFilePatchResult;
var
  LPreview: TRadIAMultiFilePatchPreview;
begin
  FReverted := True;
  LPreview := TRadIAMultiFilePatchPreview.Create('modernization-preview', [], IncMinute(Now, 10));
  LPreview.State := mpsReverted;
  Result := TRadIAMultiFilePatchResult.Succeeded(LPreview);
end;

function TRadIADextFormAuditStub.Audit(
  const AInput: TRadIADfmPasAuditInput
): TRadIADfmPasAuditResult;
begin
  Result := TRadIADfmPasAuditResult.Create([]);
end;

procedure TRadIADextFormModernizationTests.PreparesValidatedReversibleStage;
var
  LArguments: TJSONObject;
  LPatches: TRadIADextFormPatchStub;
  LResult: TRadIAToolResult;
  LService: IRadIADextFormModernizationService;
begin
  LPatches := TRadIADextFormPatchStub.Create;
  LService := TRadIADextFormModernizationService.Create(LPatches, TRadIADextFormAuditStub.Create);
  LArguments := BuildArguments('validated');
  try
    LResult := LService.Prepare(LArguments);
    Assert.IsTrue(LResult.Success);
    Assert.IsTrue(LPatches.Prepared);
    Assert.Contains(LResult.ContentJson, 'modernization-preview');
  finally
    LArguments.Free;
  end;
end;

procedure TRadIADextFormModernizationTests.RejectsUnvalidatedMigration;
var
  LArguments: TJSONObject;
  LResult: TRadIAToolResult;
  LService: IRadIADextFormModernizationService;
begin
  LService := TRadIADextFormModernizationService.Create(
    TRadIADextFormPatchStub.Create,
    TRadIADextFormAuditStub.Create
  );
  LArguments := BuildArguments('planned');
  try
    LResult := LService.Prepare(LArguments);
    Assert.IsFalse(LResult.Success);
    Assert.AreEqual('migration_not_ready', LResult.ErrorCode);
  finally
    LArguments.Free;
  end;
end;

procedure TRadIADextFormModernizationTests.RevertsFailedGate;
var
  LArguments: TJSONObject;
  LPatches: TRadIADextFormPatchStub;
  LResult: TRadIAToolResult;
  LService: IRadIADextFormModernizationService;
begin
  LPatches := TRadIADextFormPatchStub.Create;
  LService := TRadIADextFormModernizationService.Create(LPatches, TRadIADextFormAuditStub.Create);
  LArguments := TJSONObject.Create;
  try
    LArguments.AddPair('previewId', 'modernization-preview');
    LArguments.AddPair('buildPassed', TJSONBool.Create(False));
    LArguments.AddPair('testsPassed', TJSONBool.Create(True));
    LArguments.AddPair('buildEvidence', 'Compiler error captured.');
    LArguments.AddPair('testEvidence', 'Tests passed before build gate.');
    LResult := LService.RecordGate(LArguments);
    Assert.IsTrue(LResult.Success);
    Assert.IsTrue(LPatches.Reverted);
  finally
    LArguments.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADextFormModernizationTests);

end.
