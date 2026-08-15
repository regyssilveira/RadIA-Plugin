unit RadIA.Tests.TestImpact;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIATestImpactTests = class
  private
    FCoverageFile: string;
    FRootPath: string;
    FRunner: IInterface;
    FRunnerObject: TObject;
    FSourceFile: string;
    FWorkspace: IInterface;
    procedure WriteUnit(const AFileName: string; const AContent: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure SelectsTransitiveFixtureWithCoverageReason;
    [Test]
    procedure RunsSelectedFixtureThroughExistingRunner;
    [Test]
    procedure FallsBackToFullSuiteForUnknownChange;
    [Test]
    procedure FallsBackWhenCoverageDoesNotContainChangedUnit;
    [Test]
    procedure RejectsChangedFileOutsideWorkspace;
    [Test]
    procedure SelectsWithMediumConfidenceWithoutCoverage;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.DUnitX,
  RadIA.Core.TestImpact,
  RadIA.Core.TestImpactTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIATestImpactWorkspaceStub = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade
  )
  private
    FRootPath: string;
  public
    constructor Create(const ARootPath: string);
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
  end;

  TRadIATestImpactRunnerStub = class(
    TInterfacedObject,
    IRadIADUnitXRunner
  )
  private
    FLastRequest: TRadIADUnitXRunRequest;
  public
    function Cancel: Boolean;
    function Execute(
      const ARequest: TRadIADUnitXRunRequest
    ): TRadIADUnitXRunResult;
    function GetStatus: TRadIADUnitXRunStatus;
    property LastRequest: TRadIADUnitXRunRequest read FLastRequest;
  end;

constructor TRadIATestImpactWorkspaceStub.Create(const ARootPath: string);
begin
  inherited Create;
  FRootPath := ARootPath;
end;

function TRadIATestImpactWorkspaceStub.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'ImpactTest',
    TPath.Combine(FRootPath, 'ImpactTest.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TRadIATestImpactWorkspaceStub.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIATestImpactWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := nil;
end;

function TRadIATestImpactWorkspaceStub.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIATestImpactWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIATestImpactWorkspaceStub.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIATestImpactWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Delphi', 'Win32', False, []);
end;

function TRadIATestImpactWorkspaceStub.ListOpenFiles: TArray<string>;
begin
  Result := nil;
end;

function TRadIATestImpactWorkspaceStub.ListProjectUnits: TArray<string>;
begin
  Result := nil;
end;

function TRadIATestImpactRunnerStub.Cancel: Boolean;
begin
  Result := False;
end;

function TRadIATestImpactRunnerStub.Execute(
  const ARequest: TRadIADUnitXRunRequest
): TRadIADUnitXRunResult;
begin
  FLastRequest := ARequest;
  Result := TRadIADUnitXRunResult.Completed(
    drsSucceeded,
    0,
    12,
    Default(TRadIADUnitXReport),
    'selected tests completed'
  );
end;

function TRadIATestImpactRunnerStub.GetStatus: TRadIADUnitXRunStatus;
begin
  Result := drsIdle;
end;

procedure TRadIATestImpactTests.WriteUnit(
  const AFileName: string;
  const AContent: string
);
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, AFileName),
    AContent,
    TEncoding.UTF8
  );
end;

procedure TRadIATestImpactTests.Setup;
var
  LRunner: TRadIATestImpactRunnerStub;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIATestImpact-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FRootPath);
  FSourceFile := TPath.Combine(FRootPath, 'SourceUnit.pas');
  WriteUnit(
    'SourceUnit.pas',
    'unit SourceUnit; interface implementation end.'
  );
  WriteUnit(
    'MiddleUnit.pas',
    'unit MiddleUnit; interface uses SourceUnit; implementation end.'
  );
  WriteUnit(
    'Service.Tests.pas',
    'unit Service.Tests; interface uses DUnitX.TestFramework, MiddleUnit; ' +
    'implementation initialization ' +
    'TDUnitX.RegisterTestFixture(TServiceTests); end.'
  );
  WriteUnit(
    'Unrelated.Tests.pas',
    'unit Unrelated.Tests; interface uses DUnitX.TestFramework; ' +
    'implementation initialization ' +
    'TDUnitX.RegisterTestFixture(TUnrelatedTests); end.'
  );
  FCoverageFile := TPath.Combine(FRootPath, 'coverage.xml');
  TFile.WriteAllText(
    FCoverageFile,
    '<report><srcfile name="SourceUnit.pas"/></report>',
    TEncoding.UTF8
  );
  FWorkspace := TRadIATestImpactWorkspaceStub.Create(FRootPath);
  LRunner := TRadIATestImpactRunnerStub.Create;
  FRunner := LRunner;
  FRunnerObject := LRunner;
end;

procedure TRadIATestImpactTests.TearDown;
begin
  FRunnerObject := nil;
  FRunner := nil;
  FWorkspace := nil;
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

function BuildRegistry(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ARunner: IRadIADUnitXRunner
): IRadIAToolRegistry;
var
  LBoundary: IRadIAWorkspaceBoundary;
  LService: IRadIATestImpactService;
begin
  LBoundary := TRadIAWorkspaceBoundary.Create;
  LService := TRadIATestImpactService.Create(AWorkspace, LBoundary);
  Result := TRadIAToolRegistry.Create;
  RegisterRadIATestImpactTools(Result, LService, ARunner);
end;

procedure TRadIATestImpactTests.SelectsTransitiveFixtureWithCoverageReason;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := BuildRegistry(
    FWorkspace as IRadIAWorkspaceFacade,
    FRunner as IRadIADUnitXRunner
  );
  LResult := LRegistry.Resolve('PlanImpactedDUnitXTests').Execute(
    TRadIAToolRequest.Create(
      'PlanImpactedDUnitXTests',
      '{"changedFiles":["' + StringReplace(
        FSourceFile,
        '\',
        '\\',
        [rfReplaceAll]
      ) + '"],"changedSymbols":["TSource.Execute"],' +
      '"coverageReport":"coverage.xml"}',
      'impact-plan-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"runMode":"selected"');
  Assert.Contains(LResult.ContentJson, 'TServiceTests');
  Assert.Contains(LResult.ContentJson, 'TSource.Execute');
  Assert.DoesNotContain(LResult.ContentJson, 'TUnrelatedTests');
  Assert.Contains(LResult.ContentJson, '"confidence":"high"');
end;

procedure TRadIATestImpactTests.RunsSelectedFixtureThroughExistingRunner;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LRunner: TRadIATestImpactRunnerStub;
begin
  LRegistry := BuildRegistry(
    FWorkspace as IRadIAWorkspaceFacade,
    FRunner as IRadIADUnitXRunner
  );
  LResult := LRegistry.Resolve('RunImpactedDUnitXTests').Execute(
    TRadIAToolRequest.Create(
      'RunImpactedDUnitXTests',
      '{"changedFiles":["SourceUnit.pas"],' +
      '"coverageReport":"coverage.xml",' +
      '"executablePath":"ImpactTests.exe"}',
      'impact-run-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  LRunner := TRadIATestImpactRunnerStub(FRunnerObject);
  Assert.AreEqual<Integer>(1, Length(LRunner.LastRequest.Tests));
  Assert.AreEqual('TServiceTests', LRunner.LastRequest.Tests[0]);
  Assert.Contains(LResult.ContentJson, '"status":"succeeded"');
end;

procedure TRadIATestImpactTests.FallsBackToFullSuiteForUnknownChange;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := BuildRegistry(
    FWorkspace as IRadIAWorkspaceFacade,
    FRunner as IRadIADUnitXRunner
  );
  LResult := LRegistry.Resolve('PlanImpactedDUnitXTests').Execute(
    TRadIAToolRequest.Create(
      'PlanImpactedDUnitXTests',
      '{"changedFiles":["Shared.inc"]}',
      'impact-fallback-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"runMode":"full"');
  Assert.Contains(LResult.ContentJson, 'fallback-full-suite');
  Assert.Contains(LResult.ContentJson, 'complete DUnitX suite');
end;

procedure TRadIATestImpactTests.FallsBackWhenCoverageDoesNotContainChangedUnit;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    FCoverageFile,
    '<report><srcfile name="UnrelatedUnit.pas"/></report>',
    TEncoding.UTF8
  );
  LRegistry := BuildRegistry(
    FWorkspace as IRadIAWorkspaceFacade,
    FRunner as IRadIADUnitXRunner
  );
  LResult := LRegistry.Resolve('PlanImpactedDUnitXTests').Execute(
    TRadIAToolRequest.Create(
      'PlanImpactedDUnitXTests',
      '{"changedFiles":["SourceUnit.pas"],' +
      '"coverageReport":"coverage.xml"}',
      'impact-coverage-fallback-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"runMode":"full"');
  Assert.Contains(LResult.ContentJson, '"coverageAvailable":true');
end;

procedure TRadIATestImpactTests.RejectsChangedFileOutsideWorkspace;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := BuildRegistry(
    FWorkspace as IRadIAWorkspaceFacade,
    FRunner as IRadIADUnitXRunner
  );
  LResult := LRegistry.Resolve('PlanImpactedDUnitXTests').Execute(
    TRadIAToolRequest.Create(
      'PlanImpactedDUnitXTests',
      '{"changedFiles":["..\\OutsideUnit.pas"]}',
      'impact-boundary-test'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('outside_workspace', LResult.ErrorCode);
end;

procedure TRadIATestImpactTests.SelectsWithMediumConfidenceWithoutCoverage;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  LRegistry := BuildRegistry(
    FWorkspace as IRadIAWorkspaceFacade,
    FRunner as IRadIADUnitXRunner
  );
  LResult := LRegistry.Resolve('PlanImpactedDUnitXTests').Execute(
    TRadIAToolRequest.Create(
      'PlanImpactedDUnitXTests',
      '{"changedFiles":["SourceUnit.pas"]}',
      'impact-no-coverage-test'
    )
  );
  Assert.IsTrue(LResult.Success, LResult.ErrorMessage);
  Assert.Contains(LResult.ContentJson, '"runMode":"selected"');
  Assert.Contains(LResult.ContentJson, '"confidence":"medium"');
  Assert.Contains(LResult.ContentJson, 'transitive unit dependency graph');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIATestImpactTests);

end.
