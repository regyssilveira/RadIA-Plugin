unit RadIA.Tests.ProjectHealthTools;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Build,
  RadIA.Core.DUnitX,
  RadIA.Core.Knowledge,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIAProjectHealthTestWorkspace = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade
  )
  private
    FHasProject: Boolean;
    FHasCompilerError: Boolean;
    FShuttingDown: Boolean;
  public
    constructor Create(
      const AHasProject: Boolean;
      const AHasCompilerError: Boolean;
      const AShuttingDown: Boolean
    );
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

  TRadIAProjectHealthTestBuild = class(
    TInterfacedObject,
    IRadIABuildFacade
  )
  private
    FStatus: TRadIABuildStatus;
  public
    constructor Create(const AStatus: TRadIABuildStatus);
    function Execute(
      const ARequest: TRadIABuildRequest
    ): TRadIABuildResult;
    function Cancel: Boolean;
    function GetStatus: TRadIABuildStatus;
  end;

  TRadIAProjectHealthTestRunner = class(
    TInterfacedObject,
    IRadIADUnitXRunner
  )
  private
    FStatus: TRadIADUnitXRunStatus;
  public
    constructor Create(const AStatus: TRadIADUnitXRunStatus);
    function Execute(
      const ARequest: TRadIADUnitXRunRequest
    ): TRadIADUnitXRunResult;
    function Cancel: Boolean;
    function GetStatus: TRadIADUnitXRunStatus;
  end;

  TRadIAProjectHealthTestKnowledge = class(
    TInterfacedObject,
    IRadIAKnowledgeService
  )
  private
    FLoaded: Boolean;
  public
    constructor Create(const ALoaded: Boolean);
    function GetCurrentProjectId: string;
    function GetStatus(
      const AProjectId: string
    ): TRadIAKnowledgeStatus;
    function GetDocument(
      const AProjectId: string;
      const AFileName: string;
      out ADocument: TRadIAIndexedKnowledgeDocument
    ): Boolean;
    function RefreshProject: TRadIAKnowledgeRefreshResult;
    function Search(
      const AProjectId: string;
      const AQuery: string;
      const AMaxResults: Integer
    ): TArray<TRadIAKnowledgeSearchHit>;
    procedure ClearProject(const AProjectId: string);
    procedure Clear;
  end;

  [TestFixture]
  TTestRadIAProjectHealthTools = class
  private
    function ExecuteHealth(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABuild: IRadIABuildFacade;
      const ATests: IRadIADUnitXRunner;
      const AKnowledge: IRadIAKnowledgeService
    ): TRadIAToolResult;
  public
    [Test]
    procedure HealthyProjectHasNoRisks;
    [Test]
    procedure CriticalSignalsArePrioritized;
  end;

implementation

uses
  RadIA.Core.ProjectHealthTools,
  RadIA.Core.ToolRegistry;

const
  CProjectFile = 'C:\Projects\Demo\Demo.dproj';

constructor TRadIAProjectHealthTestWorkspace.Create(
  const AHasProject: Boolean;
  const AHasCompilerError: Boolean;
  const AShuttingDown: Boolean
);
begin
  inherited Create;
  FHasProject := AHasProject;
  FHasCompilerError := AHasCompilerError;
  FShuttingDown := AShuttingDown;
end;

function TRadIAProjectHealthTestWorkspace.GetIDEState:
  TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create(
    'Delphi 13',
    'Win64',
    FShuttingDown,
    ['workspace']
  );
end;

function TRadIAProjectHealthTestWorkspace.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  if FHasProject then
    Result := TRadIAProjectSnapshot.Create(
      'Demo',
      CProjectFile,
      'C:\Projects\Demo',
      'Debug',
      'Win32'
    )
  else
    Result := Default(TRadIAProjectSnapshot);
end;

function TRadIAProjectHealthTestWorkspace.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIAProjectHealthTestWorkspace.ListOpenFiles:
  TArray<string>;
begin
  Result := [];
end;

function TRadIAProjectHealthTestWorkspace.ListProjectUnits:
  TArray<string>;
begin
  Result := [];
end;

function TRadIAProjectHealthTestWorkspace.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIAProjectHealthTestWorkspace.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIAProjectHealthTestWorkspace.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIAProjectHealthTestWorkspace.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  if FHasCompilerError then
    Result := [
      TRadIACompilerMessage.Create(
        cmsError,
        'Undeclared identifier',
        'Unit1.pas',
        10,
        5
      )
    ]
  else
    Result := [];
end;

constructor TRadIAProjectHealthTestBuild.Create(
  const AStatus: TRadIABuildStatus
);
begin
  inherited Create;
  FStatus := AStatus;
end;

function TRadIAProjectHealthTestBuild.Execute(
  const ARequest: TRadIABuildRequest
): TRadIABuildResult;
begin
  Result := Default(TRadIABuildResult);
end;

function TRadIAProjectHealthTestBuild.Cancel: Boolean;
begin
  Result := False;
end;

function TRadIAProjectHealthTestBuild.GetStatus:
  TRadIABuildStatus;
begin
  Result := FStatus;
end;

constructor TRadIAProjectHealthTestRunner.Create(
  const AStatus: TRadIADUnitXRunStatus
);
begin
  inherited Create;
  FStatus := AStatus;
end;

function TRadIAProjectHealthTestRunner.Execute(
  const ARequest: TRadIADUnitXRunRequest
): TRadIADUnitXRunResult;
begin
  Result := Default(TRadIADUnitXRunResult);
end;

function TRadIAProjectHealthTestRunner.Cancel: Boolean;
begin
  Result := False;
end;

function TRadIAProjectHealthTestRunner.GetStatus:
  TRadIADUnitXRunStatus;
begin
  Result := FStatus;
end;

constructor TRadIAProjectHealthTestKnowledge.Create(
  const ALoaded: Boolean
);
begin
  inherited Create;
  FLoaded := ALoaded;
end;

procedure TRadIAProjectHealthTestKnowledge.Clear;
begin
  // Intentionally empty because this fake stores no index.
end;

procedure TRadIAProjectHealthTestKnowledge.ClearProject(
  const AProjectId: string
);
begin
  // Intentionally empty because this fake stores no project.
end;

function TRadIAProjectHealthTestKnowledge.GetCurrentProjectId: string;
begin
  Result := CProjectFile;
end;

function TRadIAProjectHealthTestKnowledge.GetDocument(
  const AProjectId: string;
  const AFileName: string;
  out ADocument: TRadIAIndexedKnowledgeDocument
): Boolean;
begin
  ADocument := Default(TRadIAIndexedKnowledgeDocument);
  Result := False;
end;

function TRadIAProjectHealthTestKnowledge.GetStatus(
  const AProjectId: string
): TRadIAKnowledgeStatus;
begin
  Result := TRadIAKnowledgeStatus.Create(
    AProjectId,
    FLoaded,
    12,
    24
  );
end;

function TRadIAProjectHealthTestKnowledge.RefreshProject:
  TRadIAKnowledgeRefreshResult;
begin
  Result := Default(TRadIAKnowledgeRefreshResult);
end;

function TRadIAProjectHealthTestKnowledge.Search(
  const AProjectId: string;
  const AQuery: string;
  const AMaxResults: Integer
): TArray<TRadIAKnowledgeSearchHit>;
begin
  Result := [];
end;

function TTestRadIAProjectHealthTools.ExecuteHealth(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABuild: IRadIABuildFacade;
  const ATests: IRadIADUnitXRunner;
  const AKnowledge: IRadIAKnowledgeService
): TRadIAToolResult;
var
  LRegistry: IRadIAToolRegistry;
  LTool: IRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIAProjectHealthTools(
    LRegistry,
    AWorkspace,
    ABuild,
    ATests,
    AKnowledge
  );
  LTool := LRegistry.Resolve('GetProjectHealth');
  Result := LTool.Execute(
    TRadIAToolRequest.Create('GetProjectHealth', '{}', 'health-test')
  );
end;

procedure TTestRadIAProjectHealthTools.HealthyProjectHasNoRisks;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteHealth(
    TRadIAProjectHealthTestWorkspace.Create(True, False, False),
    TRadIAProjectHealthTestBuild.Create(bsSucceeded),
    TRadIAProjectHealthTestRunner.Create(drsSucceeded),
    TRadIAProjectHealthTestKnowledge.Create(True)
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"health":"healthy"');
  Assert.Contains(LResult.ContentJson, '"risks":[]');
end;

procedure TTestRadIAProjectHealthTools.CriticalSignalsArePrioritized;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteHealth(
    TRadIAProjectHealthTestWorkspace.Create(False, True, True),
    TRadIAProjectHealthTestBuild.Create(bsFailed),
    TRadIAProjectHealthTestRunner.Create(drsFailed),
    TRadIAProjectHealthTestKnowledge.Create(False)
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"health":"attention"');
  Assert.Contains(LResult.ContentJson, '"code":"ide_shutting_down"');
  Assert.Contains(LResult.ContentJson, '"code":"no_active_project"');
  Assert.Contains(LResult.ContentJson, '"code":"compiler_errors"');
  Assert.Contains(LResult.ContentJson, '"code":"build_unhealthy"');
  Assert.Contains(LResult.ContentJson, '"code":"tests_unhealthy"');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAProjectHealthTools);

end.
