unit RadIA.Tests.MultiFilePatches;

interface

uses
  System.Generics.Collections,
  DUnitX.TestFramework,
  RadIA.Core.MultiFilePatches,
  RadIA.Core.Patches,
  RadIA.Core.Workspace;

type
  TRadIAMultiFileWorkspaceStub = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade,
    IRadIAEditorMutationFacade
  )
  private
    FContents: TDictionary<string, string>;
    FFailFileName: string;
    FRootPath: string;
  public
    constructor Create(const ARootPath: string);
    destructor Destroy; override;
    procedure AddFile(
      const AFileName: string;
      const AContent: string
    );
    function ApplyContent(
      const AFileName: string;
      const AExpectedRevision: string;
      const ANewContent: string;
      out AAppliedRevision: string
    ): Boolean;
    function ReadContent(
      const AFileName: string;
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
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
    function ContentOf(const AFileName: string): string;
    property FailFileName: string
      read FFailFileName write FFailFileName;
  end;

  [TestFixture]
  TRadIAMultiFilePatchTests = class
  private
    FFirstFile: string;
    FRootPath: string;
    FSecondFile: string;
    FService: IRadIAMultiFilePatchService;
    FWorkspace: TRadIAMultiFileWorkspaceStub;
    function BuildSpecs: TArray<TRadIAMultiFilePatchSpec>;
    function RevisionOf(const AContent: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure PrepareApplyAndRevertTwoBuffers;
    [Test]
    procedure ChangedBufferPreventsEveryWrite;
    [Test]
    procedure MidCommitFailureCompensatesFirstBuffer;
    [Test]
    procedure DuplicateTargetIsRejected;
    [Test]
    procedure ToolsDeclareReviewAndReversibleRisks;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.MultiFilePatchTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.WorkspaceBoundary;

{ TRadIAMultiFileWorkspaceStub }

procedure TRadIAMultiFileWorkspaceStub.AddFile(
  const AFileName: string;
  const AContent: string
);
begin
  FContents.AddOrSetValue(AFileName.ToLower, AContent);
end;

function TRadIAMultiFileWorkspaceStub.ApplyContent(
  const AFileName: string;
  const AExpectedRevision: string;
  const ANewContent: string;
  out AAppliedRevision: string
): Boolean;
var
  LContent: string;
begin
  Result := FContents.TryGetValue(AFileName.ToLower, LContent);
  if not Result then
  begin
    AAppliedRevision := '';
    Exit;
  end;
  AAppliedRevision := THashSHA2.GetHashString(LContent);
  Result := SameText(AAppliedRevision, AExpectedRevision) and
    not SameFileName(AFileName, FFailFileName);
  if Result then
  begin
    FContents[AFileName.ToLower] := ANewContent;
    AAppliedRevision := THashSHA2.GetHashString(ANewContent);
  end;
end;

function TRadIAMultiFileWorkspaceStub.ContentOf(
  const AFileName: string
): string;
begin
  Result := FContents[AFileName.ToLower];
end;

constructor TRadIAMultiFileWorkspaceStub.Create(
  const ARootPath: string
);
begin
  inherited Create;
  FRootPath := ARootPath;
  FContents := TDictionary<string, string>.Create;
end;

destructor TRadIAMultiFileWorkspaceStub.Destroy;
begin
  FContents.Free;
  inherited Destroy;
end;

function TRadIAMultiFileWorkspaceStub.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'MultiFileTest',
    TPath.Combine(FRootPath, 'MultiFileTest.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TRadIAMultiFileWorkspaceStub.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIAMultiFileWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIAMultiFileWorkspaceStub.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIAMultiFileWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIAMultiFileWorkspaceStub.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIAMultiFileWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create(
    'Delphi',
    'Win32',
    False,
    []
  );
end;

function TRadIAMultiFileWorkspaceStub.ListOpenFiles:
  TArray<string>;
begin
  Result := FContents.Keys.ToArray;
end;

function TRadIAMultiFileWorkspaceStub.ListProjectUnits:
  TArray<string>;
begin
  Result := ListOpenFiles;
end;

function TRadIAMultiFileWorkspaceStub.ReadContent(
  const AFileName: string;
  const AMaxCharacters: Integer
): TRadIAEditorContent;
var
  LContent: string;
begin
  if not FContents.TryGetValue(AFileName.ToLower, LContent) then
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

{ TRadIAMultiFilePatchTests }

function TRadIAMultiFilePatchTests.BuildSpecs:
  TArray<TRadIAMultiFilePatchSpec>;
begin
  Result := [
    TRadIAMultiFilePatchSpec.Create(
      FFirstFile,
      RevisionOf('first-original'),
      'first-proposed'
    ),
    TRadIAMultiFilePatchSpec.Create(
      FSecondFile,
      RevisionOf('second-original'),
      'second-proposed'
    )
  ];
end;

procedure TRadIAMultiFilePatchTests.ChangedBufferPreventsEveryWrite;
var
  LPreview: TRadIAMultiFilePatchResult;
  LResult: TRadIAMultiFilePatchResult;
begin
  LPreview := FService.Prepare(BuildSpecs);
  FWorkspace.AddFile(FSecondFile, 'externally-changed');

  LResult := FService.Apply(LPreview.Preview.Id);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
  Assert.AreEqual(
    'first-original',
    FWorkspace.ContentOf(FFirstFile)
  );
end;

procedure TRadIAMultiFilePatchTests.DuplicateTargetIsRejected;
var
  LBaseSpecs: TArray<TRadIAMultiFilePatchSpec>;
  LSpecs: TArray<TRadIAMultiFilePatchSpec>;
  LResult: TRadIAMultiFilePatchResult;
begin
  LBaseSpecs := BuildSpecs;
  LSpecs := [LBaseSpecs[0], LBaseSpecs[0]];

  LResult := FService.Prepare(LSpecs);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_patch', LResult.ErrorCode);
end;

procedure TRadIAMultiFilePatchTests.MidCommitFailureCompensatesFirstBuffer;
var
  LPreview: TRadIAMultiFilePatchResult;
  LResult: TRadIAMultiFilePatchResult;
begin
  LPreview := FService.Prepare(BuildSpecs);
  FWorkspace.FailFileName := FSecondFile;

  LResult := FService.Apply(LPreview.Preview.Id);

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('apply_failed', LResult.ErrorCode);
  Assert.AreEqual(
    'first-original',
    FWorkspace.ContentOf(FFirstFile)
  );
  Assert.AreEqual(
    'second-original',
    FWorkspace.ContentOf(FSecondFile)
  );
end;

procedure TRadIAMultiFilePatchTests.PrepareApplyAndRevertTwoBuffers;
var
  LPreview: TRadIAMultiFilePatchResult;
begin
  LPreview := FService.Prepare(BuildSpecs);
  Assert.IsTrue(LPreview.Success);
  Assert.AreEqual(2, Integer(Length(LPreview.Preview.Entries)));

  Assert.IsTrue(FService.Apply(LPreview.Preview.Id).Success);
  Assert.AreEqual(
    'first-proposed',
    FWorkspace.ContentOf(FFirstFile)
  );
  Assert.AreEqual(
    'second-proposed',
    FWorkspace.ContentOf(FSecondFile)
  );

  Assert.IsTrue(FService.Revert(LPreview.Preview.Id).Success);
  Assert.AreEqual(
    'first-original',
    FWorkspace.ContentOf(FFirstFile)
  );
  Assert.AreEqual(
    'second-original',
    FWorkspace.ContentOf(FSecondFile)
  );
end;

function TRadIAMultiFilePatchTests.RevisionOf(
  const AContent: string
): string;
begin
  Result := THashSHA2.GetHashString(AContent);
end;

procedure TRadIAMultiFilePatchTests.Setup;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIAMultiFilePatch-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  FFirstFile := TPath.Combine(FRootPath, 'FirstUnit.pas');
  FSecondFile := TPath.Combine(FRootPath, 'SecondUnit.pas');
  FWorkspace := TRadIAMultiFileWorkspaceStub.Create(FRootPath);
  FWorkspace.AddFile(FFirstFile, 'first-original');
  FWorkspace.AddFile(FSecondFile, 'second-original');
  FService := TRadIAMultiFilePatchService.Create(
    FWorkspace,
    FWorkspace,
    TRadIAWorkspaceBoundary.Create
  );
end;

procedure TRadIAMultiFilePatchTests.TearDown;
begin
  FService := nil;
  FWorkspace := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

procedure TRadIAMultiFilePatchTests.ToolsDeclareReviewAndReversibleRisks;
var
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAMultiFilePatchTools(LRegistry, FService);
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('PrepareMultiFilePatch').Descriptor.Risk
  );
  Assert.AreEqual(
    trReversibleWrite,
    LRegistry.Resolve('ApplyMultiFilePatch').Descriptor.Risk
  );
  Assert.AreEqual(
    trReversibleWrite,
    LRegistry.Resolve('RevertMultiFilePatch').Descriptor.Risk
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAMultiFilePatchTests);

end.
