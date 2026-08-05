unit RadIA.Tests.Coverage;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TRadIACoverageWorkspaceStub = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade
  )
  private
    FRootPath: string;
  public
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
    property RootPath: string read FRootPath write FRootPath;
  end;

  [TestFixture]
  TRadIACoverageTests = class
  private
    FRegistry: IRadIAToolRegistry;
    FRootPath: string;
    FWorkspace: TRadIACoverageWorkspaceStub;
    function Execute(const AArguments: string): TRadIAToolResult;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ParserReadsAuthoritativeStats;
    [Test]
    procedure ToolReadsDefaultWorkspaceReport;
    [Test]
    procedure ToolRejectsReportOutsideWorkspace;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.Coverage,
  RadIA.Core.CoverageTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.WorkspaceBoundary;

const
  CCoverageXml =
    '<?xml version="1.0" encoding="Windows-1252"?>' +
    '<report><stats><packages value="12"/><classes value="42"/>' +
    '<methods value="180"/><srcfiles value="16"/>' +
    '<srclines value="1000"/><totallines value="980"/>' +
    '<coveredlines value="815"/><coveredpercent value="81"/>' +
    '</stats></report>';

{ TRadIACoverageWorkspaceStub }

function TRadIACoverageWorkspaceStub.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'CoverageTests',
    TPath.Combine(FRootPath, 'CoverageTests.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TRadIACoverageWorkspaceStub.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIACoverageWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIACoverageWorkspaceStub.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := TRadIAEditorPosition.Create(1, 1);
end;

function TRadIACoverageWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := TRadIAEditorContent.Create('', '', '', '', 0, False);
end;

function TRadIACoverageWorkspaceStub.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := TRadIAEditorSelection.Create('', 1, 1);
end;

function TRadIACoverageWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Test', 'Win32', False, []);
end;

function TRadIACoverageWorkspaceStub.ListOpenFiles: TArray<string>;
begin
  Result := [];
end;

function TRadIACoverageWorkspaceStub.ListProjectUnits: TArray<string>;
begin
  Result := [];
end;

{ TRadIACoverageTests }

function TRadIACoverageTests.Execute(
  const AArguments: string
): TRadIAToolResult;
var
  LTool: IRadIATool;
begin
  LTool := FRegistry.Resolve('GetCoverageSummary');
  Result := LTool.Execute(
    TRadIAToolRequest.Create(
      'GetCoverageSummary',
      AArguments,
      'coverage-test'
    )
  );
end;

procedure TRadIACoverageTests.ParserReadsAuthoritativeStats;
var
  LParser: TRadIACoverageSummaryParser;
  LSummary: TRadIACoverageSummary;
begin
  LParser := TRadIACoverageSummaryParser.Create;
  try
    LSummary := LParser.Parse(CCoverageXml);
    Assert.AreEqual(16, LSummary.SourceFiles);
    Assert.AreEqual(1000, LSummary.SourceLines);
    Assert.AreEqual(815, LSummary.CoveredLines);
    Assert.AreEqual(81, LSummary.CoveredPercent);
    Assert.Contains(LSummary.ToJson, '"coveredPercent":81');
  finally
    LParser.Free;
  end;
end;

procedure TRadIACoverageTests.Setup;
var
  LBoundary: IRadIAWorkspaceBoundary;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-Coverage-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(
    TPath.Combine(FRootPath, 'Output\Coverage')
  );
  FRegistry := TRadIAToolRegistry.Create;
  FWorkspace := TRadIACoverageWorkspaceStub.Create;
  FWorkspace.RootPath := FRootPath;
  LWorkspace := FWorkspace;
  LBoundary := TRadIAWorkspaceBoundary.Create;
  RegisterRadIACoverageTools(FRegistry, LWorkspace, LBoundary);
end;

procedure TRadIACoverageTests.TearDown;
begin
  FRegistry := nil;
  FWorkspace := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

procedure TRadIACoverageTests.ToolReadsDefaultWorkspaceReport;
var
  LReportPath: string;
  LResult: TRadIAToolResult;
begin
  LReportPath := TPath.Combine(
    FRootPath,
    'Output\Coverage\CodeCoverage_Summary.xml'
  );
  TFile.WriteAllText(LReportPath, CCoverageXml, TEncoding.Default);
  LResult := Execute('{}');
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"coveredLines":815');
  Assert.Contains(LResult.ContentJson, '"coveredPercent":81');
  Assert.AreEqual(
    trReadOnly,
    FRegistry.Resolve('GetCoverageSummary').Descriptor.Risk
  );
end;

procedure TRadIACoverageTests.ToolRejectsReportOutsideWorkspace;
var
  LResult: TRadIAToolResult;
begin
  LResult := Execute('{"reportPath":"..\\outside.xml"}');
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('outside_workspace', LResult.ErrorCode);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIACoverageTests);

end.
