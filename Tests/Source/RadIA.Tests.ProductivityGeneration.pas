unit RadIA.Tests.ProductivityGeneration;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAProductivityGenerationTests = class
  private
    FArtifacts: IInterface;
    FFacade: TObject;
    FGeneration: IInterface;
    FRootPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ApiPreviewIsDeterministicAndDoesNotWrite;
    [Test]
    procedure ApiArtifactAppliesAndReverts;
    [Test]
    procedure ExistingTargetIsNeverOverwritten;
    [Test]
    procedure MockPreviewBuildsIsolatedPascalUnit;
    [Test]
    procedure MockApplyOptionallyRegistersAndReverts;
    [Test]
    procedure ChangedArtifactCannotBeReverted;
    [Test]
    procedure ToolsSeparateReadOnlyPreviewFromMutation;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.GeneratedArtifacts,
  RadIA.Core.ProductivityGeneration,
  RadIA.Core.ProductivityGenerationTools,
  RadIA.Core.SemanticQueries,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary,
  RadIA.Tests.ProjectFiles;

type
  TRadIAProductivityQueryStub = class(
    TInterfacedObject,
    IRadIASemanticQueryService
  )
  public
    function BuildContext(
      const ASymbolName: string;
      const AMaxCharacters: Integer;
      out AContext: string;
      out AError: string
    ): Boolean;
    function FindResolvedMembers(
      const AContainerName: string;
      out AMembers: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function FindReferences(
      const ASymbolId: string;
      const AIncludeCandidates: Boolean;
      const AMaxItems: Integer;
      out AReferences: TArray<TRadIASemanticReferenceLocation>;
      out AError: string
    ): Boolean;
    function FindSymbols(
      const AName: string;
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function HasResolvedMember(
      const AContainerName: string;
      const AMemberName: string
    ): Boolean;
    function ListPublicApiSymbols(
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
  end;

function TRadIAProductivityQueryStub.BuildContext(
  const ASymbolName: string;
  const AMaxCharacters: Integer;
  out AContext: string;
  out AError: string
): Boolean;
begin
  AContext := '';
  AError := '';
  Result := False;
end;

function TRadIAProductivityQueryStub.FindResolvedMembers(
  const AContainerName: string;
  out AMembers: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  AMembers := [
    TRadIASemanticLocation.Create(
      'Execute',
      'method',
      AContainerName,
      'Sample.Contracts.pas',
      'procedure Execute(const AValue: Integer);',
      'public',
      120
    ),
    TRadIASemanticLocation.Create(
      'Ready',
      'method',
      AContainerName,
      'Sample.Contracts.pas',
      'function Ready: Boolean;',
      'public',
      180
    )
  ];
  AError := '';
  Result := SameText(AContainerName, 'IWorker');
end;

function TRadIAProductivityQueryStub.FindReferences(
  const ASymbolId: string;
  const AIncludeCandidates: Boolean;
  const AMaxItems: Integer;
  out AReferences: TArray<TRadIASemanticReferenceLocation>;
  out AError: string
): Boolean;
begin
  AReferences := nil;
  AError := '';
  Result := False;
end;

function TRadIAProductivityQueryStub.FindSymbols(
  const AName: string;
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  ASymbols := [TRadIASemanticLocation.Create(
    'IWorker',
    'interface',
    '',
    'Sample.Contracts.pas',
    'IWorker = interface',
    'public',
    40
  )];
  AError := '';
  Result := SameText(AName, 'IWorker');
end;

function TRadIAProductivityQueryStub.HasResolvedMember(
  const AContainerName: string;
  const AMemberName: string
): Boolean;
begin
  Result := False;
end;

function TRadIAProductivityQueryStub.ListPublicApiSymbols(
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  ASymbols := [
    TRadIASemanticLocation.Create(
      'Sample.Contracts',
      'module',
      '',
      'Sample.Contracts.pas',
      'unit Sample.Contracts;',
      'unspecified',
      0
    ),
    TRadIASemanticLocation.Create(
      'IWorker',
      'interface',
      '',
      'Sample.Contracts.pas',
      'IWorker = interface',
      'public',
      40
    ),
    TRadIASemanticLocation.Create(
      'Execute',
      'method',
      'IWorker',
      'Sample.Contracts.pas',
      'procedure Execute(const AValue: Integer);',
      'public',
      120
    )
  ];
  AError := '';
  Result := True;
end;

procedure TRadIAProductivityGenerationTests.ApiArtifactAppliesAndReverts;
var
  LArtifacts: IRadIAGeneratedArtifactService;
  LFileName: string;
  LGeneration: IRadIAProductivityGenerationService;
  LResult: TRadIAGeneratedArtifactResult;
begin
  LArtifacts := FArtifacts as IRadIAGeneratedArtifactService;
  LGeneration := FGeneration as IRadIAProductivityGenerationService;
  LResult := LGeneration.PrepareApiDocumentation('API.md');
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  LFileName := LResult.Preview.FileName;
  LResult := LArtifacts.Apply(LResult.Preview.Id);
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.IsTrue(TFile.Exists(LFileName));
  LResult := LArtifacts.Revert(LResult.Preview.Id);
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.IsFalse(TFile.Exists(LFileName));
end;

procedure TRadIAProductivityGenerationTests.
  ApiPreviewIsDeterministicAndDoesNotWrite;
var
  LGeneration: IRadIAProductivityGenerationService;
  LResult: TRadIAGeneratedArtifactResult;
begin
  LGeneration := FGeneration as IRadIAProductivityGenerationService;
  LResult := LGeneration.PrepareApiDocumentation('API.md');
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.IsFalse(TFile.Exists(LResult.Preview.FileName));
  Assert.Contains(LResult.Preview.Content, '# ProjectFileTest API');
  Assert.Contains(LResult.Preview.Content, '### IWorker');
  Assert.Contains(LResult.Preview.Content, 'IWorker.Execute');
  Assert.Contains(LResult.Preview.Content, 'procedure Execute');
end;

procedure TRadIAProductivityGenerationTests.ChangedArtifactCannotBeReverted;
var
  LArtifacts: IRadIAGeneratedArtifactService;
  LResult: TRadIAGeneratedArtifactResult;
begin
  LArtifacts := FArtifacts as IRadIAGeneratedArtifactService;
  LResult := (FGeneration as IRadIAProductivityGenerationService).
    PrepareApiDocumentation('API.md');
  LResult := LArtifacts.Apply(LResult.Preview.Id);
  TFile.WriteAllText(LResult.Preview.FileName, 'user change', TEncoding.UTF8);
  LResult := LArtifacts.Revert(LResult.Preview.Id);
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
  Assert.IsTrue(TFile.Exists(TPath.Combine(FRootPath, 'API.md')));
end;

procedure TRadIAProductivityGenerationTests.ExistingTargetIsNeverOverwritten;
var
  LFileName: string;
  LResult: TRadIAGeneratedArtifactResult;
begin
  LFileName := TPath.Combine(FRootPath, 'API.md');
  TFile.WriteAllText(LFileName, 'existing', TEncoding.UTF8);
  LResult := (FGeneration as IRadIAProductivityGenerationService).
    PrepareApiDocumentation('API.md');
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('target_exists', LResult.ErrorCode);
  Assert.AreEqual('existing', TFile.ReadAllText(LFileName, TEncoding.UTF8));
end;

procedure TRadIAProductivityGenerationTests.
  MockPreviewBuildsIsolatedPascalUnit;
var
  LResult: TRadIAGeneratedArtifactResult;
begin
  LResult := (FGeneration as IRadIAProductivityGenerationService).
    PrepareMockUnit(
      'IWorker',
      'Sample.Tests.WorkerMock',
      'Tests',
      False
    );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.IsFalse(TFile.Exists(LResult.Preview.FileName));
  Assert.Contains(LResult.Preview.Content, 'TRadIAMockWorker');
  Assert.Contains(LResult.Preview.Content, 'procedure TRadIAMockWorker.Execute');
  Assert.Contains(LResult.Preview.Content, 'function TRadIAMockWorker.Ready');
  Assert.IsFalse(LResult.Preview.RegisterInProject);
end;

procedure TRadIAProductivityGenerationTests.
  MockApplyOptionallyRegistersAndReverts;
var
  LArtifacts: IRadIAGeneratedArtifactService;
  LFacade: TRadIAProjectFileFacadeStub;
  LResult: TRadIAGeneratedArtifactResult;
begin
  LArtifacts := FArtifacts as IRadIAGeneratedArtifactService;
  LFacade := TRadIAProjectFileFacadeStub(FFacade);
  LResult := (FGeneration as IRadIAProductivityGenerationService).
    PrepareMockUnit(
      'IWorker',
      'Sample.Tests.WorkerMock',
      'Tests',
      True
    );
  LResult := LArtifacts.Apply(LResult.Preview.Id);
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.IsTrue(LFacade.FileInProject(LResult.Preview.FileName));
  LResult := LArtifacts.Revert(LResult.Preview.Id);
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.IsFalse(LFacade.FileInProject(LResult.Preview.FileName));
  Assert.IsFalse(TFile.Exists(LResult.Preview.FileName));
end;

procedure TRadIAProductivityGenerationTests.Setup;
var
  LArtifactService: IRadIAGeneratedArtifactService;
  LFacade: TRadIAProjectFileFacadeStub;
  LGenerationService: IRadIAProductivityGenerationService;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-Productivity-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  LWorkspace := TRadIAProjectFileWorkspaceStub.Create(FRootPath);
  LFacade := TRadIAProjectFileFacadeStub.Create;
  FFacade := LFacade;
  LArtifactService := TRadIAGeneratedArtifactService.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create,
    LFacade
  );
  LGenerationService := TRadIAProductivityGenerationService.Create(
    LWorkspace,
    TRadIAProductivityQueryStub.Create,
    LArtifactService
  );
  FArtifacts := LArtifactService;
  FGeneration := LGenerationService;
end;

procedure TRadIAProductivityGenerationTests.TearDown;
begin
  FGeneration := nil;
  FArtifacts := nil;
  FFacade := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

procedure TRadIAProductivityGenerationTests.
  ToolsSeparateReadOnlyPreviewFromMutation;
var
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAProductivityGenerationTools(
    LRegistry,
    FGeneration as IRadIAProductivityGenerationService,
    FArtifacts as IRadIAGeneratedArtifactService
  );
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('PrepareApiDocumentation').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('PrepareMockUnit').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    LRegistry.Resolve('ApplyGeneratedArtifact').Descriptor.Risk
  );
  Assert.AreEqual(
    trReversibleWrite,
    LRegistry.Resolve('RevertGeneratedArtifact').Descriptor.Risk
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAProductivityGenerationTests);

end.
