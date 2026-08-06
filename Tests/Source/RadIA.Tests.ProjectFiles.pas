unit RadIA.Tests.ProjectFiles;

interface

uses
  System.Generics.Collections,
  DUnitX.TestFramework,
  RadIA.Core.ProjectFiles,
  RadIA.Core.Workspace;

type
  TRadIAProjectFileWorkspaceStub = class(
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

  TRadIAProjectFileFacadeStub = class(
    TInterfacedObject,
    IRadIAProjectFileFacade
  )
  private
    FFiles: TDictionary<string, Boolean>;
    FRejectAdd: Boolean;
    FObservedFileBeforeAdd: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function AddFile(
      const AFileName: string;
      const AIsUnitOrForm: Boolean
    ): Boolean;
    function RemoveFile(const AFileName: string): Boolean;
    function FileInProject(const AFileName: string): Boolean;
    procedure SeedFile(const AFileName: string);
    property RejectAdd: Boolean read FRejectAdd write FRejectAdd;
    property ObservedFileBeforeAdd: Boolean
      read FObservedFileBeforeAdd;
  end;

  [TestFixture]
  TRadIAProjectFileTests = class
  private
    FFacade: TRadIAProjectFileFacadeStub;
    FRootPath: string;
    FService: IRadIAProjectFileService;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure AddCreatesFileBeforeProjectRegistration;
    [Test]
    procedure AddFormCreatesPasAndDfmThenReverts;
    [Test]
    procedure RegistrationFailureCleansCreatedFiles;
    [Test]
    procedure RemoveUnregistersWithoutDeletingDiskFile;
    [Test]
    procedure ToolsDeclareSafeStructuralRisks;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.ProjectFileTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.WorkspaceBoundary;

{ TRadIAProjectFileWorkspaceStub }

constructor TRadIAProjectFileWorkspaceStub.Create(
  const ARootPath: string
);
begin
  inherited Create;
  FRootPath := ARootPath;
end;

function TRadIAProjectFileWorkspaceStub.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'ProjectFileTest',
    TPath.Combine(FRootPath, 'ProjectFileTest.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TRadIAProjectFileWorkspaceStub.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIAProjectFileWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIAProjectFileWorkspaceStub.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIAProjectFileWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIAProjectFileWorkspaceStub.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIAProjectFileWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create(
    'Delphi',
    'Win32',
    False,
    []
  );
end;

function TRadIAProjectFileWorkspaceStub.ListOpenFiles:
  TArray<string>;
begin
  Result := [];
end;

function TRadIAProjectFileWorkspaceStub.ListProjectUnits:
  TArray<string>;
begin
  Result := [];
end;

{ TRadIAProjectFileFacadeStub }

function TRadIAProjectFileFacadeStub.AddFile(
  const AFileName: string;
  const AIsUnitOrForm: Boolean
): Boolean;
begin
  FObservedFileBeforeAdd := TFile.Exists(AFileName);
  Result := FObservedFileBeforeAdd and
    AIsUnitOrForm and
    not FRejectAdd;
  if Result then
    FFiles.AddOrSetValue(AFileName.ToLower, True);
end;

constructor TRadIAProjectFileFacadeStub.Create;
begin
  inherited Create;
  FFiles := TDictionary<string, Boolean>.Create;
end;

destructor TRadIAProjectFileFacadeStub.Destroy;
begin
  FFiles.Free;
  inherited Destroy;
end;

function TRadIAProjectFileFacadeStub.FileInProject(
  const AFileName: string
): Boolean;
begin
  Result := FFiles.ContainsKey(AFileName.ToLower);
end;

function TRadIAProjectFileFacadeStub.RemoveFile(
  const AFileName: string
): Boolean;
begin
  Result := FFiles.ContainsKey(AFileName.ToLower);
  if Result then
    FFiles.Remove(AFileName.ToLower);
end;

procedure TRadIAProjectFileFacadeStub.SeedFile(
  const AFileName: string
);
begin
  FFiles.AddOrSetValue(AFileName.ToLower, True);
end;

{ TRadIAProjectFileTests }

procedure TRadIAProjectFileTests.AddCreatesFileBeforeProjectRegistration;
var
  LFileName: string;
  LPreview: TRadIAProjectFileResult;
begin
  LPreview := FService.PrepareAdd('Services.User', '.', pfkUnit);
  Assert.IsTrue(LPreview.Success);

  Assert.IsTrue(FService.Apply(LPreview.Preview.Id).Success);

  LFileName := TPath.Combine(FRootPath, 'Services.User.pas');
  Assert.IsTrue(TFile.Exists(LFileName));
  Assert.IsTrue(FFacade.FileInProject(LFileName));
  Assert.IsTrue(FFacade.ObservedFileBeforeAdd);
end;

procedure TRadIAProjectFileTests.AddFormCreatesPasAndDfmThenReverts;
var
  LDfmFileName: string;
  LPasFileName: string;
  LPreview: TRadIAProjectFileResult;
begin
  LPreview := FService.PrepareAdd('Customer', '.', pfkVclForm);
  Assert.IsTrue(FService.Apply(LPreview.Preview.Id).Success);
  LPasFileName := TPath.Combine(FRootPath, 'Customer.pas');
  LDfmFileName := TPath.Combine(FRootPath, 'Customer.dfm');
  Assert.IsTrue(TFile.Exists(LPasFileName));
  Assert.IsTrue(TFile.Exists(LDfmFileName));

  Assert.IsTrue(FService.Revert(LPreview.Preview.Id).Success);

  Assert.IsFalse(TFile.Exists(LPasFileName));
  Assert.IsFalse(TFile.Exists(LDfmFileName));
  Assert.IsFalse(FFacade.FileInProject(LPasFileName));
end;

procedure TRadIAProjectFileTests.RegistrationFailureCleansCreatedFiles;
var
  LFileName: string;
  LPreview: TRadIAProjectFileResult;
  LResult: TRadIAProjectFileResult;
begin
  FFacade.RejectAdd := True;
  LPreview := FService.PrepareAdd('RejectedUnit', '.', pfkUnit);

  LResult := FService.Apply(LPreview.Preview.Id);

  LFileName := TPath.Combine(FRootPath, 'RejectedUnit.pas');
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual(
    'project_registration_failed',
    LResult.ErrorCode
  );
  Assert.IsFalse(TFile.Exists(LFileName));
end;

procedure TRadIAProjectFileTests.RemoveUnregistersWithoutDeletingDiskFile;
var
  LFileName: string;
  LPreview: TRadIAProjectFileResult;
begin
  LFileName := TPath.Combine(FRootPath, 'ExistingUnit.pas');
  TFile.WriteAllText(LFileName, 'unit ExistingUnit; end.');
  FFacade.SeedFile(LFileName);
  LPreview := FService.PrepareRemove(LFileName);

  Assert.IsTrue(FService.Apply(LPreview.Preview.Id).Success);

  Assert.IsFalse(FFacade.FileInProject(LFileName));
  Assert.IsTrue(TFile.Exists(LFileName));
  Assert.IsTrue(FService.Revert(LPreview.Preview.Id).Success);
  Assert.IsTrue(FFacade.FileInProject(LFileName));
end;

procedure TRadIAProjectFileTests.Setup;
var
  LWorkspace: IRadIAWorkspaceFacade;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIAProjectFiles-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  FFacade := TRadIAProjectFileFacadeStub.Create;
  LWorkspace := TRadIAProjectFileWorkspaceStub.Create(FRootPath);
  FService := TRadIAProjectFileService.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create,
    FFacade
  );
end;

procedure TRadIAProjectFileTests.TearDown;
begin
  FService := nil;
  FFacade := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

procedure TRadIAProjectFileTests.ToolsDeclareSafeStructuralRisks;
var
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAProjectFileTools(LRegistry, FService);
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('PrepareAddProjectFile').Descriptor.Risk
  );
  Assert.AreEqual(
    trReadOnly,
    LRegistry.Resolve('PrepareRemoveProjectFile').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    LRegistry.Resolve('ApplyProjectFileChange').Descriptor.Risk
  );
  Assert.AreEqual(
    trReversibleWrite,
    LRegistry.Resolve('RevertProjectFileChange').Descriptor.Risk
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAProjectFileTests);

end.
