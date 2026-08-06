unit RadIA.Tests.Git;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Workspace;

type
  TRadIAGitWorkspaceStub = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade
  )
  private
    FRootPath: string;
  public
    constructor Create(const ARootPath: string);
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
  end;

  [TestFixture]
  [Category('ExternalProcess')]
  TRadIAGitFacadeTests = class
  private
    FRootPath: string;
    function RunGit(const AArguments: string): Cardinal;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure CreatesReviewedCommitInTemporaryRepository;
    [Test]
    procedure RejectsCommitWhenFileChangesAfterPreview;
    [Test]
    procedure ToolsDeclarePreviewAndCommitRisks;
    [Test]
    procedure RejectsPreviewWhenIndexAlreadyContainsChanges;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.Git,
  RadIA.Core.GitTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.WorkspaceBoundary,
  RadIA.OTA.Git;

constructor TRadIAGitWorkspaceStub.Create(const ARootPath: string);
begin
  inherited Create;
  FRootPath := ARootPath;
end;

function TRadIAGitWorkspaceStub.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'GitTests',
    TPath.Combine(FRootPath, 'GitTests.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TRadIAGitWorkspaceStub.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIAGitWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  SetLength(Result, 0);
end;

function TRadIAGitWorkspaceStub.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := TRadIAEditorPosition.Create(0, 0);
end;

function TRadIAGitWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIAGitWorkspaceStub.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := TRadIAEditorSelection.Create('', 0, 0);
end;

function TRadIAGitWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create(
    'test',
    'Win32',
    False,
    []
  );
end;

function TRadIAGitWorkspaceStub.ListOpenFiles: TArray<string>;
begin
  SetLength(Result, 0);
end;

function TRadIAGitWorkspaceStub.ListProjectUnits: TArray<string>;
begin
  SetLength(Result, 0);
end;

procedure TRadIAGitFacadeTests.CreatesReviewedCommitInTemporaryRepository;
var
  LGit: IRadIAGitFacade;
  LJson: TJSONObject;
  LPreviewId: string;
  LResult: TRadIAGitResult;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  LWorkspace := TRadIAGitWorkspaceStub.Create(FRootPath);
  LGit := TRadIAOTAGitFacade.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create
  );
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Unit1.pas'),
    'unit Unit1;' + sLineBreak + 'interface' + sLineBreak
  );
  LResult := LGit.PreviewCommit(
    ['Unit1.pas'],
    'feat: update sample unit'
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '+unit Unit1;');
  LJson := TJSONObject.ParseJSONValue(
    LResult.ContentJson
  ) as TJSONObject;
  try
    LPreviewId := LJson.GetValue<string>('previewId', '');
  finally
    LJson.Free;
  end;
  LResult := LGit.Commit(LPreviewId);
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"committed":true');
  LResult := LGit.GetStatus;
  Assert.IsTrue(LResult.Success);
  Assert.IsFalse(LResult.ContentJson.Contains('Unit1.pas'));
end;

procedure TRadIAGitFacadeTests.ToolsDeclarePreviewAndCommitRisks;
var
  LGit: IRadIAGitFacade;
  LRegistry: IRadIAToolRegistry;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  LWorkspace := TRadIAGitWorkspaceStub.Create(FRootPath);
  LGit := TRadIAOTAGitFacade.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAGitTools(LRegistry, LGit);
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('PreviewGitCommit').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    LRegistry.Resolve('CommitChanges').Descriptor.Risk
  );
end;

procedure TRadIAGitFacadeTests.RejectsCommitWhenFileChangesAfterPreview;
var
  LGit: IRadIAGitFacade;
  LJson: TJSONObject;
  LPreviewId: string;
  LResult: TRadIAGitResult;
  LUnitPath: string;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  LWorkspace := TRadIAGitWorkspaceStub.Create(FRootPath);
  LGit := TRadIAOTAGitFacade.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create
  );
  LUnitPath := TPath.Combine(FRootPath, 'Unit1.pas');
  TFile.WriteAllText(LUnitPath, 'unit Unit1;');
  LResult := LGit.PreviewCommit(
    ['Unit1.pas'],
    'fix: update sample unit'
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  LJson := TJSONObject.ParseJSONValue(
    LResult.ContentJson
  ) as TJSONObject;
  try
    LPreviewId := LJson.GetValue<string>('previewId', '');
  finally
    LJson.Free;
  end;
  TFile.AppendAllText(LUnitPath, sLineBreak + 'interface');
  LResult := LGit.Commit(LPreviewId);
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('precondition_failed', LResult.ErrorCode);
end;

procedure TRadIAGitFacadeTests.
  RejectsPreviewWhenIndexAlreadyContainsChanges;
var
  LGit: IRadIAGitFacade;
  LResult: TRadIAGitResult;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Staged.pas'),
    'unit Staged;'
  );
  Assert.AreEqual(Cardinal(0), RunGit('add -- Staged.pas'));
  LWorkspace := TRadIAGitWorkspaceStub.Create(FRootPath);
  LGit := TRadIAOTAGitFacade.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create
  );
  LResult := LGit.PreviewCommit(
    ['Staged.pas'],
    'test: staged change'
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('staged_changes_present', LResult.ErrorCode);
end;

function TRadIAGitFacadeTests.RunGit(
  const AArguments: string
): Cardinal;
var
  LCommandLine: string;
  LProcessInfo: TProcessInformation;
  LStartupInfo: TStartupInfo;
begin
  LCommandLine := '"git.exe" -C "' + FRootPath + '" ' + AArguments;
  ZeroMemory(@LStartupInfo, SizeOf(LStartupInfo));
  LStartupInfo.cb := SizeOf(LStartupInfo);
  ZeroMemory(@LProcessInfo, SizeOf(LProcessInfo));
  if not CreateProcess(
    nil,
    PChar(LCommandLine),
    nil,
    nil,
    False,
    CREATE_NO_WINDOW,
    nil,
    PChar(FRootPath),
    LStartupInfo,
    LProcessInfo
  ) then
    RaiseLastOSError;
  try
    WaitForSingleObject(LProcessInfo.hProcess, 30000);
    GetExitCodeProcess(LProcessInfo.hProcess, Result);
  finally
    CloseHandle(LProcessInfo.hThread);
    CloseHandle(LProcessInfo.hProcess);
  end;
end;

procedure TRadIAGitFacadeTests.Setup;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIAGitTests-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  Assert.AreEqual(Cardinal(0), RunGit('init --quiet'));
  Assert.AreEqual(
    Cardinal(0),
    RunGit('config user.email "radia-tests@example.invalid"')
  );
  Assert.AreEqual(
    Cardinal(0),
    RunGit('config user.name "RadIA Tests"')
  );
end;

procedure TRadIAGitFacadeTests.TearDown;
begin
  try
    if FRootPath.StartsWith(TPath.GetTempPath, True) and
      TDirectory.Exists(FRootPath) then
      TDirectory.Delete(FRootPath, True);
  except
    // Coverage may retain transient child-process handles until shutdown.
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAGitFacadeTests);

end.
