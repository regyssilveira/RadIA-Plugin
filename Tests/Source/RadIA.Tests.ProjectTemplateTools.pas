unit RadIA.Tests.ProjectTemplateTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Build,
  RadIA.Core.ProjectOpening,
  RadIA.Core.ProjectTemplateService,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIAProjectTemplateWorkspaceStub = class(
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

  TRadIAProjectBuildStub = class(
    TInterfacedObject,
    IRadIABuildFacade
  )
  private
    FSucceeds: Boolean;
  public
    constructor Create;
    function Execute(
      const ARequest: TRadIABuildRequest
    ): TRadIABuildResult;
    function Cancel: Boolean;
    function GetStatus: TRadIABuildStatus;
    property Succeeds: Boolean read FSucceeds write FSucceeds;
  end;

  TRadIAProjectOpeningStub = class(
    TInterfacedObject,
    IRadIAProjectOpeningFacade
  )
  private
    FLastProjectFileName: string;
    FRaiseOnOpen: Boolean;
  public
    function CloseProject(const AProjectFileName: string): Boolean;
    function OpenProject(const AProjectFileName: string): Boolean;
    property LastProjectFileName: string read FLastProjectFileName;
    property RaiseOnOpen: Boolean read FRaiseOnOpen write FRaiseOnOpen;
  end;

  [TestFixture]
  TRadIAProjectTemplateToolTests = class
  private
    FRootPath: string;
    FService: IRadIAProjectTemplateService;
    FRegistry: IRadIAToolRegistry;
    FOpeningStub: TRadIAProjectOpeningStub;
    FBuildStub: TRadIAProjectBuildStub;
    function Execute(
      const AToolName: string;
      const AArgumentsJson: string
    ): TRadIAToolResult;
    function PreviewArguments(
      const ADestinationPath: string
    ): string;
    function ReadString(
      const AJson: string;
      const AName: string
    ): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure PreviewDoesNotCreateDestination;
    [Test]
    procedure CommitCreatesReviewedProject;
    [Test]
    procedure RollbackRemovesCreatedProject;
    [Test]
    procedure RejectsDestinationOutsideWorkspace;
    [Test]
    procedure RegistersExpectedRiskLevels;
    [Test]
    procedure OpensCommittedProjectThroughFacade;
    [Test]
    procedure InitialBuildKeepsSuccessfulProject;
    [Test]
    procedure InitialBuildFailureRollsProjectBack;
    [Test]
    procedure OpeningExceptionRollsProjectBack;
    [Test]
    procedure AuthorizedRootAllowsPreviewWithoutActiveProject;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.ProjectTemplates,
  RadIA.Core.ProjectTemplateTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.WorkspaceBoundary;

{ TRadIAProjectTemplateWorkspaceStub }

{ TRadIAProjectOpeningStub }

procedure TRadIAProjectTemplateToolTests.
  AuthorizedRootAllowsPreviewWithoutActiveProject;
var
  LAuthorized: IRadIAAuthorizedProjectTemplateService;
  LDestination: string;
  LOpening: IRadIAProjectOpeningFacade;
  LResult: TRadIAProjectTemplateOperationResult;
  LService: IRadIAProjectTemplateService;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  LWorkspace := TRadIAProjectTemplateWorkspaceStub.Create('');
  LOpening := TRadIAProjectOpeningStub.Create;
  LService := TRadIAProjectTemplateService.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create,
    LOpening
  );
  LAuthorized := LService as IRadIAAuthorizedProjectTemplateService;
  LDestination := TPath.Combine(FRootPath, 'VisualProject');
  LResult := LAuthorized.PreviewAtAuthorizedRoot(
    TRadIAProjectTemplateRequest.Create(
      'VisualProject',
      ptkVcl,
      '37.0',
      ['Win32', 'Win64']
    ),
    FRootPath,
    LDestination
  );
  Assert.IsTrue(LResult.Success);
  Assert.IsFalse(TDirectory.Exists(LDestination));
  Assert.AreEqual(LDestination, LResult.DestinationPath);
end;

{ TRadIAProjectBuildStub }

function TRadIAProjectBuildStub.Cancel: Boolean;
begin
  Result := False;
end;

constructor TRadIAProjectBuildStub.Create;
begin
  inherited Create;
  FSucceeds := True;
end;

function TRadIAProjectBuildStub.Execute(
  const ARequest: TRadIABuildRequest
): TRadIABuildResult;
var
  LProject: TRadIAProjectSnapshot;
begin
  if not FSucceeds then
    Exit(TRadIABuildResult.Failed(
      bsFailed,
      'compiler_error',
      'Generated project did not compile.'
    ));
  LProject := TRadIAProjectSnapshot.Create(
    'CreatedApp',
    'CreatedApp.dproj',
    '',
    'Debug',
    'Win32'
  );
  Result := TRadIABuildResult.Completed(
    bsSucceeded,
    LProject,
    10,
    []
  );
end;

function TRadIAProjectBuildStub.GetStatus: TRadIABuildStatus;
begin
  Result := bsIdle;
end;

function TRadIAProjectOpeningStub.CloseProject(
  const AProjectFileName: string
): Boolean;
begin
  Result := SameText(FLastProjectFileName, AProjectFileName);
end;

procedure TRadIAProjectTemplateToolTests.InitialBuildFailureRollsProjectBack;
var
  LDestinationPath: string;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  LDestinationPath := TPath.Combine(FRootPath, 'FailedBuildApp');
  LResult := Execute(
    'PreviewProjectTemplate',
    PreviewArguments(LDestinationPath)
  );
  LPreviewId := ReadString(LResult.ContentJson, 'previewId');
  Assert.IsTrue(Execute(
    'CreateProjectFromTemplate',
    '{"previewId":"' + LPreviewId + '"}'
  ).Success);
  FBuildStub.Succeeds := False;

  LResult := Execute(
    'ValidateCreatedProject',
    '{"previewId":"' + LPreviewId + '"}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"buildSucceeded":false');
  Assert.Contains(LResult.ContentJson, '"rolledBack":true');
  Assert.IsFalse(TDirectory.Exists(LDestinationPath));
end;

procedure TRadIAProjectTemplateToolTests.InitialBuildKeepsSuccessfulProject;
var
  LDestinationPath: string;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  LDestinationPath := TPath.Combine(FRootPath, 'SuccessfulBuildApp');
  LResult := Execute(
    'PreviewProjectTemplate',
    PreviewArguments(LDestinationPath)
  );
  LPreviewId := ReadString(LResult.ContentJson, 'previewId');
  Assert.IsTrue(Execute(
    'CreateProjectFromTemplate',
    '{"previewId":"' + LPreviewId + '"}'
  ).Success);

  LResult := Execute(
    'ValidateCreatedProject',
    '{"previewId":"' + LPreviewId + '"}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"buildSucceeded":true');
  Assert.Contains(LResult.ContentJson, '"rolledBack":false');
  Assert.IsTrue(TDirectory.Exists(LDestinationPath));
end;

function TRadIAProjectOpeningStub.OpenProject(
  const AProjectFileName: string
): Boolean;
begin
  if FRaiseOnOpen then
    raise Exception.Create('Simulated IDE project-open failure.');
  FLastProjectFileName := AProjectFileName;
  Result := True;
end;

procedure TRadIAProjectTemplateToolTests.
  OpeningExceptionRollsProjectBack;
var
  LDestinationPath: string;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  LDestinationPath := TPath.Combine(FRootPath, 'OpenExceptionApp');
  LResult := Execute(
    'PreviewProjectTemplate',
    PreviewArguments(LDestinationPath)
  );
  LPreviewId := ReadString(LResult.ContentJson, 'previewId');
  Assert.IsTrue(Execute(
    'CreateProjectFromTemplate',
    '{"previewId":"' + LPreviewId + '"}'
  ).Success);
  FOpeningStub.RaiseOnOpen := True;

  LResult := Execute(
    'ValidateCreatedProject',
    '{"previewId":"' + LPreviewId + '"}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"buildSucceeded":false');
  Assert.Contains(LResult.ContentJson, '"rolledBack":true');
  Assert.Contains(
    LResult.ContentJson,
    '"errorCode":"project_open_exception"'
  );
  Assert.IsFalse(TDirectory.Exists(LDestinationPath));
end;

constructor TRadIAProjectTemplateWorkspaceStub.Create(
  const ARootPath: string
);
begin
  inherited Create;
  FRootPath := ARootPath;
end;

function TRadIAProjectTemplateWorkspaceStub.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'Workspace',
    TPath.Combine(FRootPath, 'Workspace.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TRadIAProjectTemplateWorkspaceStub.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIAProjectTemplateWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIAProjectTemplateWorkspaceStub.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := TRadIAEditorPosition.Create(1, 1);
end;

function TRadIAProjectTemplateWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIAProjectTemplateWorkspaceStub.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIAProjectTemplateWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create(
    'Delphi 13',
    'Win32',
    False,
    []
  );
end;

function TRadIAProjectTemplateWorkspaceStub.ListOpenFiles:
  TArray<string>;
begin
  Result := [];
end;

function TRadIAProjectTemplateWorkspaceStub.ListProjectUnits:
  TArray<string>;
begin
  Result := [];
end;

{ TRadIAProjectTemplateToolTests }

procedure TRadIAProjectTemplateToolTests.CommitCreatesReviewedProject;
var
  LDestinationPath: string;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  LDestinationPath := TPath.Combine(FRootPath, 'CreatedApp');
  LResult := Execute(
    'PreviewProjectTemplate',
    PreviewArguments(LDestinationPath)
  );
  Assert.IsTrue(LResult.Success);
  LPreviewId := ReadString(LResult.ContentJson, 'previewId');

  LResult := Execute(
    'CreateProjectFromTemplate',
    '{"previewId":"' + LPreviewId + '"}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.IsTrue(TFile.Exists(
    TPath.Combine(LDestinationPath, 'CreatedApp.dpr')
  ));
  Assert.Contains(LResult.ContentJson, '"committed":true');
end;

function TRadIAProjectTemplateToolTests.Execute(
  const AToolName: string;
  const AArgumentsJson: string
): TRadIAToolResult;
var
  LTool: IRadIATool;
begin
  LTool := FRegistry.Resolve(AToolName);
  Result := LTool.Execute(
    TRadIAToolRequest.Create(
      AToolName,
      AArgumentsJson,
      'project-template-test'
    )
  );
end;

function TRadIAProjectTemplateToolTests.PreviewArguments(
  const ADestinationPath: string
): string;
var
  LJson: TJSONObject;
  LPlatforms: TJSONArray;
begin
  LJson := TJSONObject.Create;
  try
    LJson.AddPair('projectName', 'CreatedApp');
    LJson.AddPair('template', 'console');
    LJson.AddPair('delphiVersion', '37.0');
    LPlatforms := TJSONArray.Create;
    LPlatforms.Add('Win32');
    LJson.AddPair('platforms', LPlatforms);
    LJson.AddPair('destinationPath', ADestinationPath);
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

procedure TRadIAProjectTemplateToolTests.PreviewDoesNotCreateDestination;
var
  LDestinationPath: string;
  LResult: TRadIAToolResult;
begin
  LDestinationPath := TPath.Combine(FRootPath, 'PreviewOnly');

  LResult := Execute(
    'PreviewProjectTemplate',
    PreviewArguments(LDestinationPath)
  );

  Assert.IsTrue(LResult.Success);
  Assert.IsFalse(TDirectory.Exists(LDestinationPath));
  Assert.Contains(LResult.ContentJson, '"template":"console"');
  Assert.IsFalse(LResult.ContentJson.Contains('Hello from'));
end;

procedure TRadIAProjectTemplateToolTests.OpensCommittedProjectThroughFacade;
var
  LDestinationPath: string;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  LDestinationPath := TPath.Combine(FRootPath, 'OpenedApp');
  LResult := Execute(
    'PreviewProjectTemplate',
    PreviewArguments(LDestinationPath)
  );
  LPreviewId := ReadString(LResult.ContentJson, 'previewId');
  Assert.IsTrue(Execute(
    'CreateProjectFromTemplate',
    '{"previewId":"' + LPreviewId + '"}'
  ).Success);

  LResult := Execute(
    'OpenCreatedProject',
    '{"previewId":"' + LPreviewId + '"}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.IsTrue(LResult.ContentJson.Contains('"opened":true'));
  Assert.AreEqual(
    TPath.Combine(LDestinationPath, 'CreatedApp.dproj'),
    FOpeningStub.LastProjectFileName
  );
end;

function TRadIAProjectTemplateToolTests.ReadString(
  const AJson: string;
  const AName: string
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  try
    Assert.IsNotNull(LJson);
    Result := LJson.GetValue<string>(AName, '');
  finally
    LJson.Free;
  end;
end;

procedure TRadIAProjectTemplateToolTests.RegistersExpectedRiskLevels;
begin
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('PreviewProjectTemplate').Descriptor.Risk
  );
  Assert.AreEqual(
    trStructuralWrite,
    FRegistry.Resolve('CreateProjectFromTemplate').Descriptor.Risk
  );
  Assert.AreEqual(
    trReversibleWrite,
    FRegistry.Resolve('RevertCreatedProject').Descriptor.Risk
  );
  Assert.AreEqual(
    trExecution,
    FRegistry.Resolve('OpenCreatedProject').Descriptor.Risk
  );
  Assert.AreEqual(
    trExecution,
    FRegistry.Resolve('ValidateCreatedProject').Descriptor.Risk
  );
end;

procedure TRadIAProjectTemplateToolTests.RejectsDestinationOutsideWorkspace;
var
  LDestinationPath: string;
  LResult: TRadIAToolResult;
begin
  LDestinationPath := TPath.Combine(
    TPath.GetDirectoryName(FRootPath),
    'OutsideWorkspace'
  );

  LResult := Execute(
    'PreviewProjectTemplate',
    PreviewArguments(LDestinationPath)
  );

  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('outside_workspace', LResult.ErrorCode);
end;

procedure TRadIAProjectTemplateToolTests.RollbackRemovesCreatedProject;
var
  LDestinationPath: string;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  LDestinationPath := TPath.Combine(FRootPath, 'RollbackApp');
  LResult := Execute(
    'PreviewProjectTemplate',
    PreviewArguments(LDestinationPath)
  );
  LPreviewId := ReadString(LResult.ContentJson, 'previewId');
  Assert.IsTrue(Execute(
    'CreateProjectFromTemplate',
    '{"previewId":"' + LPreviewId + '"}'
  ).Success);

  LResult := Execute(
    'RevertCreatedProject',
    '{"previewId":"' + LPreviewId + '"}'
  );

  Assert.IsTrue(LResult.Success);
  Assert.IsFalse(TDirectory.Exists(LDestinationPath));
  Assert.Contains(LResult.ContentJson, '"rolledBack":true');
end;

procedure TRadIAProjectTemplateToolTests.Setup;
var
  LWorkspace: IRadIAWorkspaceFacade;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIAProjectTemplateTools-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  LWorkspace := TRadIAProjectTemplateWorkspaceStub.Create(FRootPath);
  FOpeningStub := TRadIAProjectOpeningStub.Create;
  FBuildStub := TRadIAProjectBuildStub.Create;
  FService := TRadIAProjectTemplateService.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create,
    FOpeningStub
  );
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAProjectTemplateTools(
    FRegistry,
    FService,
    FBuildStub
  );
end;

procedure TRadIAProjectTemplateToolTests.TearDown;
begin
  FRegistry := nil;
  FService := nil;
  FOpeningStub := nil;
  FBuildStub := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAProjectTemplateToolTests);

end.
