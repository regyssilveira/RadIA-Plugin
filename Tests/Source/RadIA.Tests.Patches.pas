unit RadIA.Tests.Patches;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Patches,
  RadIA.Core.Workspace;

type
  TTestRadIAPatchWorkspace = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade,
    IRadIAEditorMutationFacade
  )
  private
    FContent: string;
    FFileName: string;
    FRejectWrites: Boolean;
    FRootPath: string;
    function Revision: string;
  public
    constructor Create(
      const ARootPath: string;
      const AFileName: string;
      const AContent: string
    );
    function ApplyContent(
      const AFileName: string;
      const AExpectedRevision: string;
      const ANewContent: string;
      out AAppliedRevision: string
    ): Boolean;
    function GetIDEState: TRadIAIDEState;
    function GetActiveProject: TRadIAProjectSnapshot;
    function GetActiveUnit: string;
    function ListOpenFiles: TArray<string>;
    function ListProjectUnits: TArray<string>;
    function GetEditorContent(
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
    function GetEditorSelection: TRadIAEditorSelection;
    function GetCursorPosition: TRadIAEditorPosition;
    function GetCompilerMessages(
      const AMaxCount: Integer
    ): TArray<TRadIACompilerMessage>;
    property Content: string read FContent write FContent;
    property RejectWrites: Boolean
      read FRejectWrites write FRejectWrites;
  end;

  [TestFixture]
  TTestRadIAPatches = class
  private
    FFileName: string;
    FRootPath: string;
    FService: IRadIAPatchService;
    FWorkspace: TTestRadIAPatchWorkspace;
    function BuildSpec(
      const AOriginalText: string;
      const AReplacementText: string
    ): TRadIAPatchSpec;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure PrepareCreatesReviewablePreview;
    [Test]
    procedure ApplyAndRevertPreserveRevisionPreconditions;
    [Test]
    procedure ApplyRejectsChangedBuffer;
    [Test]
    procedure ApplyFailurePreservesOriginalBuffer;
    [Test]
    procedure PrepareRejectsAmbiguousOriginal;
    [Test]
    procedure PrepareRejectsOutsideWorkspace;
    [Test]
    procedure PatchToolsDeclareCorrectRiskLevels;
    [Test]
    procedure PolicyDenialPreventsPatchApplication;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.PatchTools,
  RadIA.Core.Tools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.ToolSecurity,
  RadIA.Core.WorkspaceBoundary;

{ TTestRadIAPatchWorkspace }

function TTestRadIAPatchWorkspace.ApplyContent(
  const AFileName: string;
  const AExpectedRevision: string;
  const ANewContent: string;
  out AAppliedRevision: string
): Boolean;
begin
  Result := SameFileName(AFileName, FFileName) and
    SameText(AExpectedRevision, Revision) and
    not FRejectWrites;
  if Result then
    FContent := ANewContent;
  AAppliedRevision := Revision;
end;

procedure TTestRadIAPatches.ApplyFailurePreservesOriginalBuffer;
var
  LPrepareResult: TRadIAPatchResult;
  LResult: TRadIAPatchResult;
begin
  LPrepareResult := FService.Prepare(
    BuildSpec('OldValue', 'NewValue')
  );
  FWorkspace.RejectWrites := True;

  LResult := FService.Apply(LPrepareResult.Preview.Id);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('apply_failed', LResult.ErrorCode);
  Assert.Contains(FWorkspace.Content, 'OldValue');
  Assert.IsFalse(FWorkspace.Content.Contains('NewValue'));
end;

constructor TTestRadIAPatchWorkspace.Create(
  const ARootPath: string;
  const AFileName: string;
  const AContent: string
);
begin
  inherited Create;
  FRootPath := ARootPath;
  FFileName := AFileName;
  FContent := AContent;
end;

function TTestRadIAPatchWorkspace.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'PatchTests',
    TPath.Combine(FRootPath, 'PatchTests.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TTestRadIAPatchWorkspace.GetActiveUnit: string;
begin
  Result := 'UnitOne';
end;

function TTestRadIAPatchWorkspace.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  SetLength(Result, 0);
end;

function TTestRadIAPatchWorkspace.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := TRadIAEditorPosition.Create(1, 1);
end;

function TTestRadIAPatchWorkspace.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := TRadIAEditorContent.Create(
    'UnitOne',
    FFileName,
    FContent,
    Revision,
    Length(FContent),
    False
  );
end;

function TTestRadIAPatchWorkspace.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := TRadIAEditorSelection.Create('', 1, 1);
end;

function TTestRadIAPatchWorkspace.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create(
    'Test',
    'Win32',
    False,
    ['EditorRead', 'EditorWrite']
  );
end;

function TTestRadIAPatchWorkspace.ListOpenFiles: TArray<string>;
begin
  Result := [FFileName];
end;

function TTestRadIAPatchWorkspace.ListProjectUnits: TArray<string>;
begin
  Result := [FFileName];
end;

function TTestRadIAPatchWorkspace.Revision: string;
begin
  Result := THashSHA2.GetHashString(FContent);
end;

{ TTestRadIAPatches }

procedure TTestRadIAPatches.ApplyAndRevertPreserveRevisionPreconditions;
var
  LApplyResult: TRadIAPatchResult;
  LPrepareResult: TRadIAPatchResult;
  LRevertResult: TRadIAPatchResult;
begin
  LPrepareResult := FService.Prepare(
    BuildSpec('OldValue', 'NewValue')
  );
  LApplyResult := FService.Apply(LPrepareResult.Preview.Id);
  LRevertResult := FService.Revert(LPrepareResult.Preview.Id);

  Assert.IsTrue(LApplyResult.Success);
  Assert.Contains(LApplyResult.Preview.ProposedContent, 'NewValue');
  Assert.IsTrue(LRevertResult.Success);
  Assert.Contains(FWorkspace.Content, 'OldValue');
end;

procedure TTestRadIAPatches.ApplyRejectsChangedBuffer;
var
  LPrepareResult: TRadIAPatchResult;
  LResult: TRadIAPatchResult;
begin
  LPrepareResult := FService.Prepare(
    BuildSpec('OldValue', 'NewValue')
  );
  FWorkspace.Content := FWorkspace.Content + sLineBreak +
    '// User edit';

  LResult := FService.Apply(LPrepareResult.Preview.Id);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
  Assert.Contains(FWorkspace.Content, '// User edit');
end;

function TTestRadIAPatches.BuildSpec(
  const AOriginalText: string;
  const AReplacementText: string
): TRadIAPatchSpec;
begin
  Result := TRadIAPatchSpec.Create(
    FFileName,
    THashSHA2.GetHashString(FWorkspace.Content),
    AOriginalText,
    AReplacementText
  );
end;

procedure TTestRadIAPatches.PrepareCreatesReviewablePreview;
var
  LResult: TRadIAPatchResult;
begin
  LResult := FService.Prepare(
    BuildSpec('OldValue', 'NewValue')
  );

  Assert.IsTrue(LResult.Success);
  Assert.IsNotEmpty(LResult.Preview.Id);
  Assert.Contains(LResult.Preview.OriginalContent, 'OldValue');
  Assert.Contains(LResult.Preview.ProposedContent, 'NewValue');
  Assert.AreNotEqual(
    LResult.Preview.Spec.BaseRevision,
    LResult.Preview.ProposedRevision
  );
end;

procedure TTestRadIAPatches.PrepareRejectsAmbiguousOriginal;
var
  LResult: TRadIAPatchResult;
begin
  FWorkspace.Content := 'OldValue OldValue';
  LResult := FService.Prepare(
    BuildSpec('OldValue', 'NewValue')
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('ambiguous_original', LResult.ErrorCode);
end;

procedure TTestRadIAPatches.PrepareRejectsOutsideWorkspace;
var
  LResult: TRadIAPatchResult;
  LSpec: TRadIAPatchSpec;
begin
  LSpec := TRadIAPatchSpec.Create(
    TPath.Combine(TPath.GetTempPath, 'Outside.pas'),
    THashSHA2.GetHashString(FWorkspace.Content),
    'OldValue',
    'NewValue'
  );
  LResult := FService.Prepare(LSpec);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('outside_workspace', LResult.ErrorCode);
end;

procedure TTestRadIAPatches.PatchToolsDeclareCorrectRiskLevels;
var
  LRegistry: IRadIAToolRegistry;
  LTool: IRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAPatchTools(LRegistry, FService);

  Assert.AreEqual(3, LRegistry.Count);
  LTool := LRegistry.Resolve('PreparePatch');
  Assert.AreEqual(trReadOnly, LTool.Descriptor.Risk);
  LTool := LRegistry.Resolve('ApplyPatch');
  Assert.AreEqual(trReversibleWrite, LTool.Descriptor.Risk);
  LTool := LRegistry.Resolve('RevertPatch');
  Assert.AreEqual(trReversibleWrite, LTool.Descriptor.Risk);
end;

procedure TTestRadIAPatches.PolicyDenialPreventsPatchApplication;
var
  LAudit: IRadIAToolAuditSink;
  LExecutor: IRadIAToolExecutor;
  LPrepareResult: TRadIAPatchResult;
  LRegistry: IRadIAToolRegistry;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
begin
  LPrepareResult := FService.Prepare(
    BuildSpec('OldValue', 'NewValue')
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAPatchTools(LRegistry, FService);
  LAudit := TRadIAInMemoryToolAuditSink.Create;
  LExecutor := TRadIAToolPolicyExecutor.Create(
    LRegistry,
    TRadIAToolExecutor.Create(LRegistry),
    TRadIADenyConsentProvider.Create,
    LAudit,
    TRadIASecretRedactor.Create
  ) as IRadIAToolExecutor;
  LRequest := TRadIAToolRequest.Create(
    'ApplyPatch',
    '{"previewId":"' + LPrepareResult.Preview.Id + '"}',
    TGUID.NewGuid.ToString,
    'test',
    'session',
    FRootPath,
    FFileName
  );

  LResult := LExecutor.Execute(LRequest);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('consent_denied', LResult.ErrorCode);
  Assert.Contains(FWorkspace.Content, 'OldValue');
end;

procedure TTestRadIAPatches.Setup;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIAPatches-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  FFileName := TPath.Combine(FRootPath, 'UnitOne.pas');
  FWorkspace := TTestRadIAPatchWorkspace.Create(
    FRootPath,
    FFileName,
    'unit UnitOne;' + sLineBreak +
    'const Value = ''OldValue'';' + sLineBreak +
    'end.'
  );
  FService := TRadIAPatchService.Create(
    FWorkspace,
    FWorkspace,
    TRadIAWorkspaceBoundary.Create
  );
end;

procedure TTestRadIAPatches.TearDown;
begin
  FService := nil;
  FWorkspace := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAPatches);

end.
