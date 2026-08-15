unit RadIA.Tests.SemanticRefactoring;

interface

uses
  DUnitX.TestFramework;

type
  IRadIARenameWorkspaceInspect = interface
    ['{18E3D951-89C3-4FAB-A865-1D19B45603F0}']
    function ContentOf(const AFileName: string): string;
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
    FContents: TDictionary<string, string>;
    FRootPath: string;
  public
    constructor Create(const ARootPath: string);
    destructor Destroy; override;
    procedure AddFile(const AFileName: string; const AContent: string);
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
    IRadIASemanticQueryService
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
    function HasResolvedMember(
      const AContainerName: string;
      const AMemberName: string
    ): Boolean;
    function ListPublicApiSymbols(
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
  Result := Default(TRadIAEditorContent);
end;

function TRadIARenameWorkspaceStub.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
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
    'procedure SaveButtonClick(Sender: TObject);' + sLineBreak +
    'begin SaveButtonClick(Sender); end;'
  );
  LWorkspace.AddFile(
    FOtherFile,
    'begin MainForm.SaveButtonClick(Sender); end;'
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

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticRefactoringTests);

end.
