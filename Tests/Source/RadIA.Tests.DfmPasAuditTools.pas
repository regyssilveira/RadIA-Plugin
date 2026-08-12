unit RadIA.Tests.DfmPasAuditTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Designer,
  RadIA.Core.Patches,
  RadIA.Core.Tools,
  RadIA.Tests.MultiFilePatches;

type
  TRadIADfmPasDesignerStub = class(
    TInterfacedObject,
    IRadIAFormDesignerFacade
  )
  private
    FDfmFile: string;
    FPasFile: string;
  public
    constructor Create(
      const ADfmFile: string;
      const APasFile: string
    );
    function GetActiveForm: TRadIAFormSnapshot;
    function ListFormComponents(
      const AMaxCount: Integer
    ): TArray<TRadIAFormComponentSnapshot>;
  end;

  [TestFixture]
  TTestRadIADfmPasAuditTools = class
  private
    FDfmFile: string;
    FExecutor: IRadIAToolExecutor;
    FPasFile: string;
    FPatches: IRadIAPatchService;
    FRegistry: IRadIAToolRegistry;
    FRootPath: string;
    FWorkspace: TRadIAMultiFileWorkspaceStub;
    function Execute(
      const AName: string;
      const AArguments: string
    ): TRadIAToolResult;
    function PreviewIdOf(const AJson: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure AuditsActivePairWithLocations;
    [Test]
    procedure PreparesAppliesAndRevertsMissingHandler;
    [Test]
    procedure PreparesMissingComponentField;
    [Test]
    procedure ConcurrentChangeRejectsPreparedFix;
    [Test]
    procedure RegistersReadOnlyReviewTools;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.DfmPasAudit,
  RadIA.Core.DfmPasAuditTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

const
  CDfmContent =
    'object MainForm: TMainForm' + sLineBreak +
    '  object SaveButton: TButton' + sLineBreak +
    '    OnClick = SaveButtonClick' + sLineBreak +
    '  end' + sLineBreak +
    'end';
  CPasContent =
    'unit Main;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TMainForm = class(TForm)' + sLineBreak +
    '    SaveButton: TButton;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.';

{ TRadIADfmPasDesignerStub }

constructor TRadIADfmPasDesignerStub.Create(
  const ADfmFile: string;
  const APasFile: string
);
begin
  inherited Create;
  FDfmFile := ADfmFile;
  FPasFile := APasFile;
end;

function TRadIADfmPasDesignerStub.GetActiveForm: TRadIAFormSnapshot;
begin
  Result := TRadIAFormSnapshot.Create(
    True,
    'MainForm',
    'TMainForm',
    FPasFile,
    FDfmFile,
    2,
    0
  );
end;

function TRadIADfmPasDesignerStub.ListFormComponents(
  const AMaxCount: Integer
): TArray<TRadIAFormComponentSnapshot>;
begin
  Result := [];
end;

{ TTestRadIADfmPasAuditTools }

procedure TTestRadIADfmPasAuditTools.AuditsActivePairWithLocations;
var
  LResult: TRadIAToolResult;
begin
  LResult := Execute('AuditActiveDfmPasConsistency', '{}');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"missing_event_handler"');
  Assert.Contains(LResult.ContentJson, '"line":3');
  Assert.Contains(LResult.ContentJson, '"severity":"error"');
end;

procedure TTestRadIADfmPasAuditTools.ConcurrentChangeRejectsPreparedFix;
var
  LApply: TRadIAPatchResult;
  LPrepare: TRadIAToolResult;
  LPreviewId: string;
begin
  try
    LPrepare := Execute(
      'PrepareDfmPasAuditFix',
      '{"findingCode":"missing_event_handler",' +
        '"name":"SaveButtonClick"}'
    );
  except
    on E: Exception do
      raise Exception.Create('Prepare execution failed: ' + E.Message);
  end;
  Assert.IsTrue(LPrepare.Success);
  LPreviewId := PreviewIdOf(LPrepare.ContentJson);
  FWorkspace.AddFile(FPasFile, CPasContent + sLineBreak + '// changed');

  LApply := FPatches.Apply(LPreviewId);

  Assert.IsFalse(LApply.Success);
  Assert.AreEqual('precondition_failed', LApply.ErrorCode);
end;

function TTestRadIADfmPasAuditTools.Execute(
  const AName: string;
  const AArguments: string
): TRadIAToolResult;
begin
  Result := FExecutor.Execute(
    TRadIAToolRequest.Create(AName, AArguments, 'dfm-pas-test')
  );
end;

procedure TTestRadIADfmPasAuditTools.PreparesAppliesAndRevertsMissingHandler;
var
  LPrepare: TRadIAToolResult;
  LPreviewId: string;
begin
  LPrepare := Execute(
    'PrepareDfmPasAuditFix',
    '{"findingCode":"missing_event_handler",' +
      '"name":"SaveButtonClick"}'
  );
  Assert.IsTrue(LPrepare.Success);
  LPreviewId := PreviewIdOf(LPrepare.ContentJson);
  Assert.IsTrue(FPatches.Apply(LPreviewId).Success);
  Assert.Contains(
    FWorkspace.ContentOf(FPasFile),
    'procedure SaveButtonClick(Sender: TObject);'
  );
  Assert.Contains(
    FWorkspace.ContentOf(FPasFile),
    'procedure TMainForm.SaveButtonClick(Sender: TObject);'
  );
  Assert.IsTrue(FPatches.Revert(LPreviewId).Success);
  Assert.AreEqual(CPasContent, FWorkspace.ContentOf(FPasFile));
end;

procedure TTestRadIADfmPasAuditTools.PreparesMissingComponentField;
var
  LContent: string;
  LPrepare: TRadIAToolResult;
begin
  LContent := StringReplace(
    CPasContent,
    '    SaveButton: TButton;' + sLineBreak,
    '',
    []
  );
  FWorkspace.AddFile(FPasFile, LContent);
  LPrepare := Execute(
    'PrepareDfmPasAuditFix',
    '{"findingCode":"missing_component_field","name":"SaveButton"}'
  );
  Assert.IsTrue(LPrepare.Success);
  Assert.IsTrue(FPatches.Apply(PreviewIdOf(LPrepare.ContentJson)).Success);
  Assert.Contains(
    FWorkspace.ContentOf(FPasFile),
    'SaveButton: TButton;'
  );
end;

function TTestRadIADfmPasAuditTools.PreviewIdOf(
  const AJson: string
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  try
    Result := LJson.GetValue<string>('previewId');
  finally
    LJson.Free;
  end;
end;

procedure TTestRadIADfmPasAuditTools.RegistersReadOnlyReviewTools;
begin
  Assert.AreEqual(2, FRegistry.Count);
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('AuditActiveDfmPasConsistency').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('PrepareDfmPasAuditFix').Descriptor.Risk
  );
end;

procedure TTestRadIADfmPasAuditTools.Setup;
var
  LDesigner: IRadIAFormDesignerFacade;
  LMutation: IRadIAEditorMutationFacade;
  LWorkspaceFacade: IRadIAWorkspaceFacade;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIADfmPasAudit-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  FDfmFile := TPath.Combine(FRootPath, 'Main.dfm');
  FPasFile := TPath.Combine(FRootPath, 'Main.pas');
  FWorkspace := TRadIAMultiFileWorkspaceStub.Create(FRootPath);
  FWorkspace.AddFile(FDfmFile, CDfmContent);
  FWorkspace.AddFile(FPasFile, CPasContent);
  LWorkspaceFacade := FWorkspace;
  LMutation := FWorkspace;
  FPatches := TRadIAPatchService.Create(
    LWorkspaceFacade,
    LMutation,
    TRadIAWorkspaceBoundary.Create
  );
  FRegistry := TRadIAToolRegistry.Create;
  LDesigner := TRadIADfmPasDesignerStub.Create(FDfmFile, FPasFile);
  RegisterRadIADfmPasAuditTools(
    FRegistry,
    LDesigner,
    LMutation,
    TRadIADfmPasAuditor.Create,
    FPatches
  );
  FExecutor := TRadIAToolExecutor.Create(FRegistry);
end;

procedure TTestRadIADfmPasAuditTools.TearDown;
begin
  FExecutor := nil;
  FRegistry := nil;
  FPatches := nil;
  FWorkspace := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADfmPasAuditTools);

end.
