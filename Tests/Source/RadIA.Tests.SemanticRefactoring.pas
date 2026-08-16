unit RadIA.Tests.SemanticRefactoring;

interface

uses
  DUnitX.TestFramework;

type
  IRadIARenameWorkspaceInspect = interface
    ['{18E3D951-89C3-4FAB-A865-1D19B45603F0}']
    procedure AddFile(const AFileName: string; const AContent: string);
    function ContentOf(const AFileName: string): string;
    procedure SetActiveSelection(
      const AFileName: string;
      const AContent: string;
      const ALine: Integer;
      const AColumn: Integer
    );
  end;

  [TestFixture]
  TRadIASemanticRefactoringTests = class
  private
    FFormFile: string;
    FMainFile: string;
    FOtherFile: string;
    FPatchService: IInterface;
    FRootPath: string;
    FWorkspace: IInterface;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure PreparesAppliesAndRevertsPascalAndDfmRename;
    [Test]
    procedure RejectsInvalidAndAmbiguousRename;
    [Test]
    procedure ClosedUtf8FilePreservesPreambleAndPreconditions;
    [Test]
    procedure PreparesAppliesAndRevertsChangeSignature;
    [Test]
    procedure RejectsAmbiguousChangeSignatureCall;
    [Test]
    procedure PreparesAppliesAndRevertsExtractMethod;
    [Test]
    procedure PreparesAppliesAndRevertsMoveType;
    [Test]
    procedure RejectsAmbiguousAndCyclicMoveType;
    [Test]
    procedure RejectsStaleMoveTypePreview;
    [Test]
    procedure RenamesMemberAcrossClassHierarchy;
    [Test]
    procedure RejectsAmbiguousHierarchyMemberOverload;
  end;

implementation

uses
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Patches,
  RadIA.Core.SemanticQueries,
  RadIA.Core.SemanticChangeSignatureTools,
  RadIA.Core.SemanticExtractMethodTools,
  RadIA.Core.SemanticMoveTypeTools,
  RadIA.Core.SemanticRefactoringTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.TransactionalTextFiles,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIARenameWorkspaceStub = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade,
    IRadIAEditorMutationFacade,
    IRadIARenameWorkspaceInspect
  )
  private
    FActiveFile: string;
    FActiveSelection: TRadIAEditorSelection;
    FContents: TDictionary<string, string>;
    FRootPath: string;
  public
    constructor Create(const ARootPath: string);
    destructor Destroy; override;
    procedure AddFile(const AFileName: string; const AContent: string);
    procedure SetActiveSelection(
      const AFileName: string;
      const AContent: string;
      const ALine: Integer;
      const AColumn: Integer
    );
    function ApplyContent(
      const AFileName: string;
      const AExpectedRevision: string;
      const ANewContent: string;
      out AAppliedRevision: string
    ): Boolean;
    function ContentOf(const AFileName: string): string;
    function GetActiveProject: TRadIAProjectSnapshot;
    function GetActiveUnit: string;
    function GetCompilerMessages(
      const AMaxCount: Integer
    ): TArray<TRadIACompilerMessage>;
    function GetCursorPosition: TRadIAEditorPosition;
    function GetEditorContent(
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
    function GetEditorSelection: TRadIAEditorSelection;
    function GetIDEState: TRadIAIDEState;
    function ListOpenFiles: TArray<string>;
    function ListProjectUnits: TArray<string>;
    function ReadContent(
      const AFileName: string;
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
  end;

  TRadIARenameQueryStub = class(
    TInterfacedObject,
    IRadIASemanticQueryService,
    IRadIASemanticRoutineService,
    IRadIASemanticHierarchyService
  )
  private
    FAmbiguous: Boolean;
    FFormFile: string;
    FMainFile: string;
    FOtherFile: string;
    FWorkspace: IRadIARenameWorkspaceInspect;
    function ReferenceFor(
      const AFileName: string;
      const AUnitKey: string;
      const AOccurrence: Integer
    ): TRadIASemanticReferenceLocation;
  public
    constructor Create(
      const AWorkspace: IRadIARenameWorkspaceInspect;
      const AMainFile: string;
      const AOtherFile: string;
      const AFormFile: string;
      const AAmbiguous: Boolean
    );
    function BuildContext(
      const ASymbolName: string;
      const AMaxCharacters: Integer;
      out AContext: string;
      out AError: string
    ): Boolean;
    function FindReferences(
      const ASymbolId: string;
      const AIncludeCandidates: Boolean;
      const AMaxItems: Integer;
      out AReferences: TArray<TRadIASemanticReferenceLocation>;
      out AError: string
    ): Boolean;
    function FindResolvedMembers(
      const AContainerName: string;
      out AMembers: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function FindSymbols(
      const AName: string;
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
    function FindRoutineSymbols(
      const AName: string;
      const AUnitName: string;
      const AContainerName: string;
      const ASignature: string;
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
    function ListTypeSymbols(
      out ASymbols: TArray<TRadIASemanticLocation>;
      out AError: string
    ): Boolean;
  end;

constructor TRadIARenameWorkspaceStub.Create(const ARootPath: string);
begin
  inherited Create;
  FRootPath := ARootPath;
  FContents := TDictionary<string, string>.Create;
end;

destructor TRadIARenameWorkspaceStub.Destroy;
begin
  FContents.Free;
  inherited Destroy;
end;

procedure TRadIARenameWorkspaceStub.AddFile(
  const AFileName: string;
  const AContent: string
);
begin
  FContents.AddOrSetValue(LowerCase(AFileName), AContent);
end;

procedure TRadIARenameWorkspaceStub.SetActiveSelection(
  const AFileName: string;
  const AContent: string;
  const ALine: Integer;
  const AColumn: Integer
);
begin
  FActiveFile := AFileName;
  FActiveSelection := TRadIAEditorSelection.Create(
    AContent,
    ALine,
    AColumn
  );
end;

function TRadIARenameWorkspaceStub.ApplyContent(
  const AFileName: string;
  const AExpectedRevision: string;
  const ANewContent: string;
  out AAppliedRevision: string
): Boolean;
var
  LContent: string;
begin
  Result := FContents.TryGetValue(LowerCase(AFileName), LContent);
  if not Result then
    Exit;
  AAppliedRevision := THashSHA2.GetHashString(LContent);
  Result := SameText(AAppliedRevision, AExpectedRevision);
  if Result then
  begin
    FContents[LowerCase(AFileName)] := ANewContent;
    AAppliedRevision := THashSHA2.GetHashString(ANewContent);
  end;
end;

function TRadIARenameWorkspaceStub.ContentOf(
  const AFileName: string
): string;
begin
  Result := FContents[LowerCase(AFileName)];
end;

function TRadIARenameWorkspaceStub.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'RenameTest',
    TPath.Combine(FRootPath, 'RenameTest.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TRadIARenameWorkspaceStub.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIARenameWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := nil;
end;

function TRadIARenameWorkspaceStub.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIARenameWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  if FActiveFile.IsEmpty then
    Result := Default(TRadIAEditorContent)
  else
    Result := ReadContent(FActiveFile, AMaxCharacters);
end;

function TRadIARenameWorkspaceStub.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := FActiveSelection;
end;

function TRadIARenameWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Delphi', 'Win32', False, []);
end;

function TRadIARenameWorkspaceStub.ListOpenFiles: TArray<string>;
begin
  Result := nil;
end;

function TRadIARenameWorkspaceStub.ListProjectUnits: TArray<string>;
begin
  Result := FContents.Keys.ToArray;
end;

function TRadIARenameWorkspaceStub.ReadContent(
  const AFileName: string;
  const AMaxCharacters: Integer
): TRadIAEditorContent;
var
  LContent: string;
begin
  if not FContents.TryGetValue(LowerCase(AFileName), LContent) then
    Exit(Default(TRadIAEditorContent));
  Result := TRadIAEditorContent.Create(
    TPath.GetFileNameWithoutExtension(AFileName),
    AFileName,
    LContent,
    THashSHA2.GetHashString(LContent),
    Length(LContent),
    False
  );
end;

constructor TRadIARenameQueryStub.Create(
  const AWorkspace: IRadIARenameWorkspaceInspect;
  const AMainFile: string;
  const AOtherFile: string;
  const AFormFile: string;
  const AAmbiguous: Boolean
);
begin
  inherited Create;
  FWorkspace := AWorkspace;
  FMainFile := AMainFile;
  FOtherFile := AOtherFile;
  FFormFile := AFormFile;
  FAmbiguous := AAmbiguous;
end;

function TRadIARenameQueryStub.BuildContext(
  const ASymbolName: string;
  const AMaxCharacters: Integer;
  out AContext: string;
  out AError: string
): Boolean;
begin
  Result := False;
  AContext := '';
  AError := '';
end;

function TRadIARenameQueryStub.ReferenceFor(
  const AFileName: string;
  const AUnitKey: string;
  const AOccurrence: Integer
): TRadIASemanticReferenceLocation;
const
  CSymbol = 'SaveButtonClick';
var
  LContent: string;
  LOffset: Integer;
  LSearchFrom: Integer;
begin
  LContent := FWorkspace.ContentOf(AFileName);
  LSearchFrom := 1;
  LOffset := 0;
  while LSearchFrom <= AOccurrence do
  begin
    LOffset := PosEx(CSymbol, LContent, LOffset + 1);
    Inc(LSearchFrom);
  end;
  Result := TRadIASemanticReferenceLocation.Create(
    AUnitKey,
    AFileName,
    1,
    LOffset,
    'exact',
    'unique-symbol'
  ).WithOffsets(LOffset - 1, Length(CSymbol));
end;

function TRadIARenameQueryStub.FindReferences(
  const ASymbolId: string;
  const AIncludeCandidates: Boolean;
  const AMaxItems: Integer;
  out AReferences: TArray<TRadIASemanticReferenceLocation>;
  out AError: string
): Boolean;
begin
  if SameText(ASymbolId, 'sym-base-run') then
  begin
    AReferences := [
      TRadIASemanticReferenceLocation.Create(
        'Main',
        FMainFile,
        1,
        1,
        'exact',
        'hierarchy-declaration'
      ).WithOffsets(
        Pos('Run;', FWorkspace.ContentOf(FMainFile)) - 1,
        Length('Run')
      )
    ];
    AError := '';
    Exit(not AIncludeCandidates and (AMaxItems = 1000));
  end;
  if SameText(ASymbolId, 'sym-child-run') then
  begin
    AReferences := [
      TRadIASemanticReferenceLocation.Create(
        'Other',
        FOtherFile,
        1,
        1,
        'exact',
        'hierarchy-override'
      ).WithOffsets(
        Pos('Run;', FWorkspace.ContentOf(FOtherFile)) - 1,
        Length('Run')
      ),
      TRadIASemanticReferenceLocation.Create(
        'Other',
        FOtherFile,
        1,
        1,
        'exact',
        'hierarchy-call'
      ).WithOffsets(
        Pos('Run;', FWorkspace.ContentOf(FOtherFile),
          Pos('Run;', FWorkspace.ContentOf(FOtherFile)) + 1) - 1,
        Length('Run')
      )
    ];
    AError := '';
    Exit(not AIncludeCandidates and (AMaxItems = 1000));
  end;
  if SameText(ASymbolId, 'sym-worker') then
  begin
    AReferences := [
      TRadIASemanticReferenceLocation.Create(
        'Consumer',
        FFormFile,
        4,
        10,
        IfThen(FAmbiguous, 'candidate', 'exact'),
        IfThen(FAmbiguous, 'ambiguous-short-name', 'unique-symbol')
      ).WithOffsets(
        Pos('TWorker', FWorkspace.ContentOf(FFormFile)) - 1,
        Length('TWorker')
      )
    ];
    AError := '';
    Exit(not AIncludeCandidates and (AMaxItems = 1000));
  end;
  if SameText(ASymbolId, 'sym-execute') then
  begin
    AReferences := [
      TRadIASemanticReferenceLocation.Create(
        'Other',
        FOtherFile,
        1,
        1,
        IfThen(FAmbiguous, 'candidate', 'exact'),
        IfThen(FAmbiguous, 'ambiguous-short-name', 'unique-symbol')
      ).WithOffsets(
        Pos('Execute(10)', FWorkspace.ContentOf(FOtherFile)) - 1,
        Length('Execute')
      )
    ];
    AError := '';
    Exit(AIncludeCandidates and (AMaxItems = 1000));
  end;
  AReferences := [
    ReferenceFor(FMainFile, 'Main', 1),
    ReferenceFor(FMainFile, 'Main', 2),
    ReferenceFor(FOtherFile, 'Other', 1),
    ReferenceFor(FFormFile, 'Main', 1)
  ];
  AError := '';
  Result := SameText(ASymbolId, 'sym-save-button-click') and
    not AIncludeCandidates and (AMaxItems = 1000);
end;

procedure TRadIASemanticRefactoringTests.
  RejectsAmbiguousAndCyclicMoveType;
const
  CSource = 'unit Main;' + sLineBreak + 'interface' + sLineBreak +
    'type TWorker = class end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.';
  CConsumer = 'unit Consumer;' + sLineBreak + 'interface' + sLineBreak +
    'type TConsumer = class FWorker: TWorker; end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.';
var
  LConsumerFile: string;
  LInspect: IRadIARenameWorkspaceInspect;
  LPatches: IRadIAMultiFilePatchService;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;

  function ExecuteMove(const AAmbiguous: Boolean): TRadIAToolResult;
  begin
    LQueries := TRadIARenameQueryStub.Create(
      LInspect,
      FMainFile,
      FOtherFile,
      LConsumerFile,
      AAmbiguous
    );
    LRegistry := TRadIAToolRegistry.Create;
    RegisterRadIASemanticMoveTypeTools(
      LRegistry,
      FWorkspace as IRadIAWorkspaceFacade,
      LQueries,
      FWorkspace as IRadIAEditorMutationFacade,
      LPatches
    );
    Result := LRegistry.Resolve('PrepareMoveType').Execute(
      TRadIAToolRequest.Create(
        'PrepareMoveType',
        '{"symbol":"TWorker","destinationFile":"' +
        StringReplace(FOtherFile, '\', '\\', [rfReplaceAll]) + '"}',
        'unsafe-move-type-test'
      )
    );
  end;

begin
  LInspect := FWorkspace as IRadIARenameWorkspaceInspect;
  LPatches := FPatchService as IRadIAMultiFilePatchService;
  LConsumerFile := TPath.Combine(FRootPath, 'Consumer.pas');
  LInspect.AddFile(FMainFile, CSource);
  LInspect.AddFile(LConsumerFile, CConsumer);
  LInspect.AddFile(
    FOtherFile,
    'unit Other;' + sLineBreak + 'interface' + sLineBreak +
    'uses Consumer;' + sLineBreak + 'implementation' + sLineBreak + 'end.'
  );
  LResult := ExecuteMove(False);
  Assert.IsFalse(LResult.Success);
  Assert.Contains(LResult.ErrorMessage, 'cycle');
  LInspect.AddFile(
    FOtherFile,
    'unit Other;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.'
  );
  LResult := ExecuteMove(True);
  Assert.IsFalse(LResult.Success);
  Assert.Contains(LResult.ErrorMessage, 'candidate');
  LInspect.AddFile(
    FMainFile,
    'unit Main;' + sLineBreak + 'interface' + sLineBreak +
    'type TWorker = class FSecret: TSecret; end;' + sLineBreak +
    'implementation' + sLineBreak +
    'type TSecret = class end;' + sLineBreak + 'end.'
  );
  LResult := ExecuteMove(False);
  Assert.IsFalse(LResult.Success);
  Assert.Contains(LResult.ErrorMessage, 'TSecret');
end;

procedure TRadIASemanticRefactoringTests.
  RejectsAmbiguousChangeSignatureCall;
var
  LPatchService: IRadIAMultiFilePatchService;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LRoutines: IRadIASemanticRoutineService;
  LWorkspace: IRadIARenameWorkspaceInspect;
begin
  LWorkspace := FWorkspace as IRadIARenameWorkspaceInspect;
  LQueries := TRadIARenameQueryStub.Create(
    LWorkspace,
    FMainFile,
    FOtherFile,
    FFormFile,
    True
  );
  Assert.IsTrue(Supports(LQueries, IRadIASemanticRoutineService, LRoutines));
  LRegistry := TRadIAToolRegistry.Create;
  LPatchService := FPatchService as IRadIAMultiFilePatchService;
  RegisterRadIASemanticChangeSignatureTools(
    LRegistry,
    LQueries,
    LRoutines,
    FWorkspace as IRadIAEditorMutationFacade,
    LPatchService
  );
  LResult := LRegistry.Resolve('PrepareChangeSignature').Execute(
    TRadIAToolRequest.Create(
      'PrepareChangeSignature',
      '{"symbol":"Execute","unit":"Main","container":"TWorker",' +
      '"oldSignature":"procedure Execute(const AValue: Integer);",' +
      '"newSignature":"procedure Execute(const AInput: Integer);",' +
      '"mappings":[{"oldName":"AValue","newName":"AInput"}]}',
      'change-signature-ambiguous-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('change_signature_precondition', LResult.ErrorCode);
  Assert.Contains(LResult.ErrorMessage, 'ambiguous');
end;

function TRadIARenameQueryStub.FindRoutineSymbols(
  const AName: string;
  const AUnitName: string;
  const AContainerName: string;
  const ASignature: string;
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
const
  CDeclaration = 'procedure Execute(const AValue: Integer);';
  CImplementation = 'procedure TWorker.Execute(const AValue: Integer);';
var
  LContent: string;
begin
  LContent := FWorkspace.ContentOf(FMainFile);
  ASymbols := [
    TRadIASemanticLocation.Create(
      AName,
      'method',
      'TWorker',
      FMainFile,
      CDeclaration,
      Pos(CDeclaration, LContent) - 1
    ).WithIdentity('sym-execute', 'Main').WithDeclarationSection('interface'),
    TRadIASemanticLocation.Create(
      AName,
      'method',
      'TWorker',
      FMainFile,
      CImplementation,
      Pos(CImplementation, LContent) - 1
    ).WithIdentity('sym-execute', 'Main').WithDeclarationSection('implementation')
  ];
  AError := '';
  Result := SameText(AName, 'Execute') and
    (AUnitName.IsEmpty or SameText(AUnitName, 'Main')) and
    (AContainerName.IsEmpty or SameText(AContainerName, 'TWorker')) and
    SameText(ASignature, CDeclaration);
  if not Result then
    ASymbols := nil;
end;

function TRadIARenameQueryStub.FindResolvedMembers(
  const AContainerName: string;
  out AMembers: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  AMembers := nil;
  AError := '';
  Result := True;
end;

function TRadIARenameQueryStub.FindSymbols(
  const AName: string;
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  if SameText(AName, 'Run') then
  begin
    ASymbols := [
      TRadIASemanticLocation.Create(
        AName,
        'method',
        'TBaseWorker',
        FMainFile,
        'procedure Run; virtual;',
        Pos('Run;', FWorkspace.ContentOf(FMainFile)) - 1
      ).WithIdentity('sym-base-run', 'Main'),
      TRadIASemanticLocation.Create(
        AName,
        'method',
        'TChildWorker',
        FOtherFile,
        'procedure Run; override;',
        Pos('Run;', FWorkspace.ContentOf(FOtherFile)) - 1
      ).WithIdentity('sym-child-run', 'Other')
    ];
    if FAmbiguous then
      ASymbols := ASymbols + [
        TRadIASemanticLocation.Create(
          AName,
          'method',
          'TBaseWorker',
          FMainFile,
          'procedure Run(const AValue: Integer); virtual;',
          Pos('Run;', FWorkspace.ContentOf(FMainFile)) - 1
        ).WithIdentity('sym-base-run-overload', 'Main')
      ];
    AError := '';
    Exit(True);
  end;
  if SameText(AName, 'TWorker') then
  begin
    ASymbols := [
      TRadIASemanticLocation.Create(
        AName,
        'class',
        '',
        FMainFile,
        'TWorker = class',
        Pos('TWorker', FWorkspace.ContentOf(FMainFile)) - 1
      ).WithIdentity('sym-worker', 'Main').WithDeclarationSection('interface')
    ];
    AError := '';
    Exit(True);
  end;
  ASymbols := [
    TRadIASemanticLocation.Create(
      AName,
      'method',
      'TMainForm',
      FMainFile,
      'procedure SaveButtonClick(Sender: TObject);',
      0
    ).WithIdentity('sym-save-button-click', 'Main')
  ];
  if FAmbiguous then
    ASymbols := ASymbols + [
      TRadIASemanticLocation.Create(
        AName,
        'method',
        'TOtherForm',
        FOtherFile,
        'procedure SaveButtonClick(Sender: TObject);',
        0
      ).WithIdentity('sym-other-save-button-click', 'Other')
    ];
  AError := '';
  Result := True;
end;

procedure TRadIASemanticRefactoringTests.
  PreparesAppliesAndRevertsMoveType;
const
  CSource = 'unit Main;' + sLineBreak + 'interface' + sLineBreak +
    'uses System.SysUtils;' + sLineBreak + 'type' + sLineBreak +
    '  TWorker = class' + sLineBreak + '    procedure Execute;' +
    sLineBreak + '  end;' + sLineBreak + 'implementation' + sLineBreak +
    'procedure TWorker.Execute;' + sLineBreak + 'begin' + sLineBreak +
    'end;' + sLineBreak + 'end.';
  CDestination = 'unit Other;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.';
var
  LConsumerFile: string;
  LInspect: IRadIARenameWorkspaceInspect;
  LPatches: IRadIAMultiFilePatchService;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LRoot: TJSONObject;
  LPreviewId: string;
begin
  LInspect := FWorkspace as IRadIARenameWorkspaceInspect;
  LConsumerFile := TPath.Combine(FRootPath, 'Consumer.pas');
  LInspect.AddFile(FMainFile, CSource);
  LInspect.AddFile(FOtherFile, CDestination);
  LInspect.AddFile(
    LConsumerFile,
    'unit Consumer;' + sLineBreak + 'interface' + sLineBreak +
    'type TConsumer = class' + sLineBreak +
    '  FWorker: TWorker;' + sLineBreak + 'end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.'
  );
  LQueries := TRadIARenameQueryStub.Create(
    LInspect,
    FMainFile,
    FOtherFile,
    LConsumerFile,
    False
  );
  LPatches := FPatchService as IRadIAMultiFilePatchService;
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticMoveTypeTools(
    LRegistry,
    FWorkspace as IRadIAWorkspaceFacade,
    LQueries,
    FWorkspace as IRadIAEditorMutationFacade,
    LPatches
  );
  LResult := LRegistry.Resolve('PrepareMoveType').Execute(
    TRadIAToolRequest.Create(
      'PrepareMoveType',
      '{"symbol":"TWorker","destinationFile":"' +
      StringReplace(FOtherFile, '\', '\\', [rfReplaceAll]) + '"}',
      'move-type-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LInspect.ContentOf(FMainFile), 'TWorker');
  Assert.IsFalse(LInspect.ContentOf(FOtherFile).Contains('TWorker'));
  LRoot := TJSONObject.ParseJSONValue(LResult.ContentJson) as TJSONObject;
  try
    LPreviewId := LRoot.GetValue<string>('previewId');
  finally
    LRoot.Free;
  end;
  Assert.IsTrue(LPatches.Apply(LPreviewId).Success);
  Assert.IsFalse(LInspect.ContentOf(FMainFile).Contains('TWorker'));
  Assert.Contains(LInspect.ContentOf(FOtherFile), 'TWorker = class');
  Assert.Contains(LInspect.ContentOf(FOtherFile), 'TWorker.Execute');
  Assert.Contains(LInspect.ContentOf(FOtherFile), 'System.SysUtils');
  Assert.Contains(LInspect.ContentOf(LConsumerFile), 'uses');
  Assert.Contains(LInspect.ContentOf(LConsumerFile), 'Other');
  Assert.IsTrue(LPatches.Revert(LPreviewId).Success);
  Assert.AreEqual(CSource, LInspect.ContentOf(FMainFile));
  Assert.AreEqual(CDestination, LInspect.ContentOf(FOtherFile));
  Assert.IsFalse(LInspect.ContentOf(LConsumerFile).Contains('uses'));
end;

procedure TRadIASemanticRefactoringTests.RejectsStaleMoveTypePreview;
const
  CSource = 'unit Main;' + sLineBreak + 'interface' + sLineBreak +
    'type TWorker = class end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.';
  CDestination = 'unit Other;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.';
var
  LAppliedRevision: string;
  LConsumerFile: string;
  LInspect: IRadIARenameWorkspaceInspect;
  LMutation: IRadIAEditorMutationFacade;
  LPatches: IRadIAMultiFilePatchService;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LRoot: TJSONObject;
  LSnapshot: TRadIAEditorContent;
begin
  LInspect := FWorkspace as IRadIARenameWorkspaceInspect;
  LMutation := FWorkspace as IRadIAEditorMutationFacade;
  LConsumerFile := TPath.Combine(FRootPath, 'Consumer.pas');
  LInspect.AddFile(FMainFile, CSource);
  LInspect.AddFile(FOtherFile, CDestination);
  LInspect.AddFile(
    LConsumerFile,
    'unit Consumer; interface type TUse = class FValue: TWorker; end; ' +
    'implementation end.'
  );
  LQueries := TRadIARenameQueryStub.Create(
    LInspect,
    FMainFile,
    FOtherFile,
    LConsumerFile,
    False
  );
  LPatches := FPatchService as IRadIAMultiFilePatchService;
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticMoveTypeTools(
    LRegistry,
    FWorkspace as IRadIAWorkspaceFacade,
    LQueries,
    LMutation,
    LPatches
  );
  LResult := LRegistry.Resolve('PrepareMoveType').Execute(
    TRadIAToolRequest.Create(
      'PrepareMoveType',
      '{"symbol":"TWorker","destinationFile":"' +
      StringReplace(FOtherFile, '\', '\\', [rfReplaceAll]) + '"}',
      'stale-move-type-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  LSnapshot := LMutation.ReadContent(FOtherFile, 1024 * 1024);
  Assert.IsTrue(LMutation.ApplyContent(
    FOtherFile,
    LSnapshot.Revision,
    CDestination + sLineBreak + '// concurrent edit',
    LAppliedRevision
  ));
  LRoot := TJSONObject.ParseJSONValue(LResult.ContentJson) as TJSONObject;
  try
    Assert.IsFalse(LPatches.Apply(LRoot.GetValue<string>('previewId')).Success);
  finally
    LRoot.Free;
  end;
  Assert.AreEqual(CSource, LInspect.ContentOf(FMainFile));
  Assert.Contains(LInspect.ContentOf(FOtherFile), 'concurrent edit');
end;

function TRadIARenameQueryStub.HasResolvedMember(
  const AContainerName: string;
  const AMemberName: string
): Boolean;
begin
  Result := False;
end;

function TRadIARenameQueryStub.ListPublicApiSymbols(
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  ASymbols := nil;
  AError := '';
  Result := True;
end;

function TRadIARenameQueryStub.ListTypeSymbols(
  out ASymbols: TArray<TRadIASemanticLocation>;
  out AError: string
): Boolean;
begin
  ASymbols := [
    TRadIASemanticLocation.Create(
      'TBaseWorker',
      'class',
      '',
      FMainFile,
      'TBaseWorker = class',
      0
    ).WithIdentity('type-base-worker', 'Main'),
    TRadIASemanticLocation.Create(
      'TChildWorker',
      'class',
      '',
      FOtherFile,
      'TChildWorker = class(TBaseWorker)',
      0
    ).WithIdentity('type-child-worker', 'Other').WithAncestors(['TBaseWorker'])
  ];
  AError := '';
  Result := True;
end;

procedure TRadIASemanticRefactoringTests.Setup;
var
  LWorkspace: TRadIARenameWorkspaceStub;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIASemanticRename-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  FMainFile := TPath.Combine(FRootPath, 'Main.pas');
  FOtherFile := TPath.Combine(FRootPath, 'Other.pas');
  FFormFile := TPath.Combine(FRootPath, 'Main.dfm');
  LWorkspace := TRadIARenameWorkspaceStub.Create(FRootPath);
  LWorkspace.AddFile(
    FMainFile,
    'type TWorker = class' + sLineBreak +
    '  procedure Execute(const AValue: Integer);' + sLineBreak +
    'end;' + sLineBreak +
    'procedure TWorker.Execute(const AValue: Integer);' + sLineBreak +
    'begin end;' + sLineBreak +
    'procedure SaveButtonClick(Sender: TObject);' + sLineBreak +
    'begin SaveButtonClick(Sender); end;'
  );
  LWorkspace.AddFile(
    FOtherFile,
    'begin MainForm.SaveButtonClick(Sender); Worker.Execute(10); end;'
  );
  LWorkspace.AddFile(
    FFormFile,
    'object MainForm: TMainForm' + sLineBreak +
    '  OnClick = SaveButtonClick' + sLineBreak + 'end'
  );
  FWorkspace := LWorkspace;
  FPatchService := TRadIAMultiFilePatchService.Create(
    LWorkspace,
    LWorkspace,
    TRadIAWorkspaceBoundary.Create
  );
end;

procedure TRadIASemanticRefactoringTests.
  PreparesAppliesAndRevertsChangeSignature;
var
  LPatchService: IRadIAMultiFilePatchService;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LRoot: TJSONObject;
  LRoutines: IRadIASemanticRoutineService;
  LWorkspace: IRadIARenameWorkspaceInspect;
begin
  LWorkspace := FWorkspace as IRadIARenameWorkspaceInspect;
  LQueries := TRadIARenameQueryStub.Create(
    LWorkspace,
    FMainFile,
    FOtherFile,
    FFormFile,
    False
  );
  Assert.IsTrue(Supports(LQueries, IRadIASemanticRoutineService, LRoutines));
  LRegistry := TRadIAToolRegistry.Create;
  LPatchService := FPatchService as IRadIAMultiFilePatchService;
  RegisterRadIASemanticChangeSignatureTools(
    LRegistry,
    LQueries,
    LRoutines,
    FWorkspace as IRadIAEditorMutationFacade,
    LPatchService
  );
  LResult := LRegistry.Resolve('PrepareChangeSignature').Execute(
    TRadIAToolRequest.Create(
      'PrepareChangeSignature',
      '{"symbol":"Execute","unit":"Main","container":"TWorker",' +
      '"oldSignature":"procedure Execute(const AValue: Integer);",' +
      '"newSignature":"procedure Execute(const AInput: Integer; ' +
      'const ATrace: Boolean);","mappings":[{"oldName":"AValue",' +
      '"newName":"AInput"}],"bindings":[{"parameterName":"ATrace",' +
      '"expression":"False"}]}',
      'change-signature-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  LRoot := TJSONObject.ParseJSONValue(LResult.ContentJson) as TJSONObject;
  try
    Assert.IsTrue(
      LPatchService.Apply(LRoot.GetValue<string>('previewId')).Success
    );
    Assert.Contains(
      LWorkspace.ContentOf(FMainFile),
      'procedure Execute(const AInput: Integer; const ATrace: Boolean);'
    );
    Assert.Contains(
      LWorkspace.ContentOf(FMainFile),
      'procedure TWorker.Execute(const AInput: Integer; ' +
      'const ATrace: Boolean);'
    );
    Assert.Contains(LWorkspace.ContentOf(FOtherFile), 'Execute(10, False)');
    Assert.IsTrue(
      LPatchService.Revert(LRoot.GetValue<string>('previewId')).Success
    );
    Assert.Contains(LWorkspace.ContentOf(FOtherFile), 'Execute(10)');
  finally
    LRoot.Free;
  end;
end;

procedure TRadIASemanticRefactoringTests.
  PreparesAppliesAndRevertsExtractMethod;
const
  CSelection = '  LTotal := AValue * 2;' + sLineBreak;
  CSource = 'type TWorker = class' + sLineBreak +
    '  procedure Execute(const AValue: Integer);' + sLineBreak +
    'end;' + sLineBreak +
    'procedure TWorker.Execute(const AValue: Integer);' + sLineBreak +
    'var' + sLineBreak + '  LTotal: Integer;' + sLineBreak +
    'begin' + sLineBreak + CSelection +
    '  Save(LTotal);' + sLineBreak + 'end;';
var
  LInspect: IRadIARenameWorkspaceInspect;
  LPatches: IRadIAMultiFilePatchService;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LRoot: TJSONObject;
  LRoutines: IRadIASemanticRoutineService;
begin
  LInspect := FWorkspace as IRadIARenameWorkspaceInspect;
  LInspect.AddFile(FMainFile, CSource);
  LInspect.SetActiveSelection(FMainFile, CSelection, 8, 5);
  LQueries := TRadIARenameQueryStub.Create(
    LInspect,
    FMainFile,
    FOtherFile,
    FFormFile,
    False
  );
  Assert.IsTrue(Supports(LQueries, IRadIASemanticRoutineService, LRoutines));
  LPatches := FPatchService as IRadIAMultiFilePatchService;
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticExtractMethodTools(
    LRegistry,
    FWorkspace as IRadIAWorkspaceFacade,
    LQueries,
    LRoutines,
    LPatches
  );
  LResult := LRegistry.Resolve('PrepareExtractMethod').Execute(
    TRadIAToolRequest.Create(
      'PrepareExtractMethod',
      '{"methodName":"begin"}',
      'extract-method-invalid-name-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_identifier', LResult.ErrorCode);
  LResult := LRegistry.Resolve('PrepareExtractMethod').Execute(
    TRadIAToolRequest.Create(
      'PrepareExtractMethod',
      '{"methodName":"CalculateTotal"}',
      'extract-method-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  LRoot := TJSONObject.ParseJSONValue(LResult.ContentJson) as TJSONObject;
  try
    Assert.IsTrue(LPatches.Apply(
      LRoot.GetValue<string>('previewId')
    ).Success);
    Assert.Contains(
      LInspect.ContentOf(FMainFile),
      'procedure CalculateTotal(const AValue: Integer; out LTotal: Integer);'
    );
    Assert.Contains(
      LInspect.ContentOf(FMainFile),
      'procedure TWorker.CalculateTotal(const AValue: Integer; ' +
      'out LTotal: Integer);'
    );
    Assert.Contains(
      LInspect.ContentOf(FMainFile),
      '  CalculateTotal(AValue, LTotal);'
    );
    Assert.IsTrue(LPatches.Revert(
      LRoot.GetValue<string>('previewId')
    ).Success);
    Assert.AreEqual(CSource, LInspect.ContentOf(FMainFile));
  finally
    LRoot.Free;
  end;
end;

procedure TRadIASemanticRefactoringTests.TearDown;
begin
  FPatchService := nil;
  FWorkspace := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

procedure TRadIASemanticRefactoringTests.
  ClosedUtf8FilePreservesPreambleAndPreconditions;
var
  LAppliedRevision: string;
  LBytes: TBytes;
  LContent: string;
  LFileName: string;
  LOriginalRevision: string;
begin
  LFileName := TPath.Combine(FRootPath, 'ClosedUnit.pas');
  LContent := 'unit ClosedUnit;' + sLineBreak + 'interface';
  LBytes := TEncoding.UTF8.GetPreamble + TEncoding.UTF8.GetBytes(LContent);
  TFile.WriteAllBytes(LFileName, LBytes);
  Assert.IsTrue(TRadIATransactionalTextFile.Read(LFileName, LContent));
  LOriginalRevision := THashSHA2.GetHashString(LContent);
  Assert.IsTrue(TRadIATransactionalTextFile.Apply(
    LFileName,
    LOriginalRevision,
    LContent + sLineBreak + 'implementation',
    LAppliedRevision
  ));
  LBytes := TFile.ReadAllBytes(LFileName);
  Assert.AreEqual<Integer>($EF, LBytes[0]);
  Assert.AreEqual<Integer>($BB, LBytes[1]);
  Assert.AreEqual<Integer>($BF, LBytes[2]);
  Assert.IsFalse(TRadIATransactionalTextFile.Apply(
    LFileName,
    LOriginalRevision,
    'stale write',
    LAppliedRevision
  ));
  LFileName := TPath.Combine(FRootPath, 'BinaryForm.dfm');
  LBytes := [Ord('T'), Ord('P'), Ord('F'), Ord('0'), 1, 2, 3];
  TFile.WriteAllBytes(LFileName, LBytes);
  Assert.IsFalse(TRadIATransactionalTextFile.Read(LFileName, LContent));
end;

procedure TRadIASemanticRefactoringTests.
  PreparesAppliesAndRevertsPascalAndDfmRename;
var
  LJson: TJSONObject;
  LPatches: IRadIAMultiFilePatchService;
  LPreviewId: string;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LInspect: IRadIARenameWorkspaceInspect;
  LMutation: IRadIAEditorMutationFacade;
begin
  LPatches := FPatchService as IRadIAMultiFilePatchService;
  LInspect := FWorkspace as IRadIARenameWorkspaceInspect;
  LMutation := FWorkspace as IRadIAEditorMutationFacade;
  LQueries := TRadIARenameQueryStub.Create(
    LInspect,
    FMainFile,
    FOtherFile,
    FFormFile,
    False
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticRefactoringTools(
    LRegistry,
    LQueries,
    LMutation,
    LPatches
  );
  LResult := LRegistry.Resolve('PrepareRenameSymbol').Execute(
    TRadIAToolRequest.Create(
      'PrepareRenameSymbol',
      '{"symbol":"SaveButtonClick","newName":"HandleSaveClick"}',
      'rename-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"replacementCount":4');
  LJson := TJSONObject.ParseJSONValue(LResult.ContentJson) as TJSONObject;
  try
    LPreviewId := LJson.GetValue<string>('previewId');
  finally
    LJson.Free;
  end;
  Assert.IsTrue(LPatches.Apply(LPreviewId).Success);
  Assert.Contains(LInspect.ContentOf(FMainFile), 'HandleSaveClick');
  Assert.Contains(LInspect.ContentOf(FOtherFile), 'HandleSaveClick');
  Assert.Contains(LInspect.ContentOf(FFormFile), 'HandleSaveClick');
  Assert.IsTrue(LPatches.Revert(LPreviewId).Success);
  Assert.Contains(LInspect.ContentOf(FMainFile), 'SaveButtonClick');
  Assert.Contains(LInspect.ContentOf(FFormFile), 'SaveButtonClick');
end;

procedure TRadIASemanticRefactoringTests.
  RejectsInvalidAndAmbiguousRename;
var
  LPatches: IRadIAMultiFilePatchService;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LInspect: IRadIARenameWorkspaceInspect;
  LMutation: IRadIAEditorMutationFacade;
begin
  LPatches := FPatchService as IRadIAMultiFilePatchService;
  LInspect := FWorkspace as IRadIARenameWorkspaceInspect;
  LMutation := FWorkspace as IRadIAEditorMutationFacade;
  LQueries := TRadIARenameQueryStub.Create(
    LInspect,
    FMainFile,
    FOtherFile,
    FFormFile,
    True
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticRefactoringTools(
    LRegistry,
    LQueries,
    LMutation,
    LPatches
  );
  LResult := LRegistry.Resolve('PrepareRenameSymbol').Execute(
    TRadIAToolRequest.Create(
      'PrepareRenameSymbol',
      '{"symbol":"SaveButtonClick","newName":"1Invalid"}',
      'invalid-rename-test'
    )
  );
  Assert.AreEqual('invalid_identifier', LResult.ErrorCode);
  LResult := LRegistry.Resolve('PrepareRenameSymbol').Execute(
    TRadIAToolRequest.Create(
      'PrepareRenameSymbol',
      '{"symbol":"SaveButtonClick","newName":"HandleSaveClick"}',
      'ambiguous-rename-test'
    )
  );
  Assert.AreEqual('ambiguous_symbol', LResult.ErrorCode);
end;

procedure TRadIASemanticRefactoringTests.RenamesMemberAcrossClassHierarchy;
var
  LHierarchy: IRadIASemanticHierarchyService;
  LInspect: IRadIARenameWorkspaceInspect;
  LPatches: IRadIAMultiFilePatchService;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LRoot: TJSONObject;
  LPreviewId: string;
begin
  LInspect := FWorkspace as IRadIARenameWorkspaceInspect;
  LInspect.AddFile(
    FMainFile,
    'type TBaseWorker = class procedure Run; virtual; end;'
  );
  LInspect.AddFile(
    FOtherFile,
    'type TChildWorker = class(TBaseWorker) procedure Run; override; end; ' +
    'begin Worker.Run; end;'
  );
  LQueries := TRadIARenameQueryStub.Create(
    LInspect,
    FMainFile,
    FOtherFile,
    FFormFile,
    False
  );
  Assert.IsTrue(Supports(LQueries, IRadIASemanticHierarchyService, LHierarchy));
  LPatches := FPatchService as IRadIAMultiFilePatchService;
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticRefactoringTools(
    LRegistry,
    LQueries,
    FWorkspace as IRadIAEditorMutationFacade,
    LPatches,
    LHierarchy
  );
  LResult := LRegistry.Resolve('PrepareRenameSymbol').Execute(
    TRadIAToolRequest.Create(
      'PrepareRenameSymbol',
      '{"symbol":"Run","newName":"Execute","container":"TBaseWorker",' +
      '"unit":"Main","includeHierarchy":true}',
      'hierarchy-rename-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"hierarchySymbolCount":2');
  Assert.Contains(LResult.ContentJson, '"replacementCount":3');
  LRoot := TJSONObject.ParseJSONValue(LResult.ContentJson) as TJSONObject;
  try
    LPreviewId := LRoot.GetValue<string>('previewId');
  finally
    LRoot.Free;
  end;
  Assert.IsTrue(LPatches.Apply(LPreviewId).Success);
  Assert.Contains(LInspect.ContentOf(FMainFile), 'Execute; virtual');
  Assert.Contains(LInspect.ContentOf(FOtherFile), 'Execute; override');
  Assert.Contains(LInspect.ContentOf(FOtherFile), 'Worker.Execute');
  Assert.IsTrue(LPatches.Revert(LPreviewId).Success);
  Assert.Contains(LInspect.ContentOf(FMainFile), 'Run; virtual');
  Assert.Contains(LInspect.ContentOf(FOtherFile), 'Worker.Run');
end;

procedure TRadIASemanticRefactoringTests.
  RejectsAmbiguousHierarchyMemberOverload;
var
  LHierarchy: IRadIASemanticHierarchyService;
  LInspect: IRadIARenameWorkspaceInspect;
  LQueries: IRadIASemanticQueryService;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LInspect := FWorkspace as IRadIARenameWorkspaceInspect;
  LInspect.AddFile(
    FMainFile,
    'type TBaseWorker = class procedure Run; virtual; end;'
  );
  LInspect.AddFile(
    FOtherFile,
    'type TChildWorker = class(TBaseWorker) procedure Run; override; end;'
  );
  LQueries := TRadIARenameQueryStub.Create(
    LInspect,
    FMainFile,
    FOtherFile,
    FFormFile,
    True
  );
  Assert.IsTrue(Supports(LQueries, IRadIASemanticHierarchyService, LHierarchy));
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIASemanticRefactoringTools(
    LRegistry,
    LQueries,
    FWorkspace as IRadIAEditorMutationFacade,
    FPatchService as IRadIAMultiFilePatchService,
    LHierarchy
  );
  LResult := LRegistry.Resolve('PrepareRenameSymbol').Execute(
    TRadIAToolRequest.Create(
      'PrepareRenameSymbol',
      '{"symbol":"Run","newName":"Execute","container":"TBaseWorker",' +
      '"unit":"Main","includeHierarchy":true}',
      'ambiguous-hierarchy-rename-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('hierarchy_precondition_failed', LResult.ErrorCode);
  Assert.Contains(LResult.ErrorMessage, 'exact signature');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticRefactoringTests);

end.
