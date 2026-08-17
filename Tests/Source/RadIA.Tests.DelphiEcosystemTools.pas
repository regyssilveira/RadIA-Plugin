unit RadIA.Tests.DelphiEcosystemTools;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIADelphiEcosystemTools = class
  private
    FRootPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure InventoriesFireDACWithoutReturningCredentialValues;
    [Test]
    procedure PreservesFireDACUsageCompatibilityWithStructuredProjectInventory;
    [Test]
    procedure AuditsFireDACTransactionsWithoutExecutingSql;
    [Test]
    procedure InspectsFireDACConfigurationWithoutReturningCredentials;
    [Test]
    procedure AnalyzesFireDACThreadSafetyWithoutExecutingSql;
    [Test]
    procedure GetsSanitizedFireDACProjectReport;
    [Test]
    procedure DiagnosesFireDACEnvironmentWithoutExternalActions;
    [Test]
    procedure ReportsMissingDependencyPaths;
    [Test]
    procedure FindsLocalizationCandidates;
    [Test]
    procedure PreparesLocalizationExtractionWithoutApplyingIt;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.DelphiEcosystemTools,
  RadIA.Core.Patches,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAEcosystemPatchStub = class(TInterfacedObject, IRadIAPatchService)
  private
    FPrepared: Boolean;
  public
    function Apply(const APreviewId: string): TRadIAPatchResult;
    procedure Clear;
    function Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
    function Revert(const APreviewId: string): TRadIAPatchResult;
  end;

  TRadIAEcosystemWorkspaceStub = class(TInterfacedObject, IRadIAWorkspaceFacade)
  private
    FRootPath: string;
  public
    constructor Create(const ARootPath: string);
    function GetActiveProject: TRadIAProjectSnapshot;
    function GetActiveUnit: string;
    function GetCompilerMessages(const AMaxCount: Integer): TArray<TRadIACompilerMessage>;
    function GetCursorPosition: TRadIAEditorPosition;
    function GetEditorContent(const AMaxCharacters: Integer): TRadIAEditorContent;
    function GetEditorSelection: TRadIAEditorSelection;
    function GetIDEState: TRadIAIDEState;
    function ListOpenFiles: TArray<string>;
    function ListProjectUnits: TArray<string>;
  end;

function TRadIAEcosystemPatchStub.Apply(const APreviewId: string): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('not_supported', 'Not supported by this test stub.');
end;

procedure TRadIAEcosystemPatchStub.Clear;
begin
  FPrepared := False;
end;

function TRadIAEcosystemPatchStub.Prepare(const ASpec: TRadIAPatchSpec): TRadIAPatchResult;
begin
  FPrepared := True;
  Result := TRadIAPatchResult.Succeeded(TRadIAPatchPreview.Create(
    'localization-preview',
    ASpec,
    ASpec.OriginalText,
    ASpec.ReplacementText,
    'proposed-revision',
    Now + 1
  ));
end;

function TRadIAEcosystemPatchStub.Revert(const APreviewId: string): TRadIAPatchResult;
begin
  Result := TRadIAPatchResult.Failed('not_supported', 'Not supported by this test stub.');
end;

constructor TRadIAEcosystemWorkspaceStub.Create(const ARootPath: string);
begin
  inherited Create;
  FRootPath := ARootPath;
end;

function TRadIAEcosystemWorkspaceStub.GetActiveProject: TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'Fixture',
    TPath.Combine(FRootPath, 'Fixture.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TRadIAEcosystemWorkspaceStub.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIAEcosystemWorkspaceStub.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TRadIAEcosystemWorkspaceStub.GetCursorPosition: TRadIAEditorPosition;
begin
  Result := TRadIAEditorPosition.Create(1, 1);
end;

function TRadIAEcosystemWorkspaceStub.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
var
  LContent: string;
  LFileName: string;
begin
  LFileName := TPath.Combine(FRootPath, 'Main.pas');
  if not TFile.Exists(LFileName) then
    Exit(Default(TRadIAEditorContent));
  LContent := TFile.ReadAllText(LFileName);
  Result := TRadIAEditorContent.Create(
    'Main',
    LFileName,
    LContent,
    'fixture-revision',
    LContent.Length,
    False
  );
end;

function TRadIAEcosystemWorkspaceStub.GetEditorSelection: TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIAEcosystemWorkspaceStub.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Delphi 13', 'Win32', False, []);
end;

function TRadIAEcosystemWorkspaceStub.ListOpenFiles: TArray<string>;
begin
  Result := [];
end;

function TRadIAEcosystemWorkspaceStub.ListProjectUnits: TArray<string>;
begin
  Result := [];
end;

procedure TTestRadIADelphiEcosystemTools.Setup;
begin
  FRootPath := TPath.Combine(TPath.GetTempPath, 'radia-ecosystem-' + TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(FRootPath);
end;

procedure TTestRadIADelphiEcosystemTools.TearDown;
begin
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

function ExecuteTool(const ARootPath, AToolName: string): TRadIAToolResult;
var
  LRegistry: IRadIAToolRegistry;
  LTool: IRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIADelphiEcosystemTools(
    LRegistry,
    TRadIAEcosystemWorkspaceStub.Create(ARootPath),
    TRadIAEcosystemPatchStub.Create,
    TRadIAWorkspaceBoundary.Create
  );
  LTool := LRegistry.Resolve(AToolName);
  Result := LTool.Execute(TRadIAToolRequest.Create(AToolName, '{}', 'ecosystem-test'));
end;

procedure TTestRadIADelphiEcosystemTools.InventoriesFireDACWithoutReturningCredentialValues;
var
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Data.dfm'),
    'object Connection: TFDConnection' + sLineBreak +
    '  Params.Strings = (' + sLineBreak +
    '    ''User_Name=admin''' + sLineBreak +
    '    ''Password=do-not-return'')' + sLineBreak +
    'object Query: TFDQuery'
  );
  LResult := ExecuteTool(FRootPath, 'InspectFireDACUsage');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"connectionCount":1');
  Assert.Contains(LResult.ContentJson, '"credentialsCollected":false');
  Assert.IsFalse(LResult.ContentJson.Contains('do-not-return'));
end;

procedure TTestRadIADelphiEcosystemTools.PreservesFireDACUsageCompatibilityWithStructuredProjectInventory;
var
  LProjectResult: TRadIAToolResult;
  LUsageResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Data.pas'),
    'type TDataModule = class' + sLineBreak +
    '  Connection: TFDConnection;' + sLineBreak +
    '  Query: TFDQuery;' + sLineBreak +
    'end;'
  );
  LUsageResult := ExecuteTool(FRootPath, 'InspectFireDACUsage');
  LProjectResult := ExecuteTool(FRootPath, 'InspectFireDACProject');
  Assert.IsTrue(LUsageResult.Success);
  Assert.IsTrue(LProjectResult.Success);
  Assert.Contains(LUsageResult.ContentJson, '"connectionCount":1');
  Assert.Contains(LProjectResult.ContentJson, '"connectionCount":1');
  Assert.Contains(LUsageResult.ContentJson, '"components"');
  Assert.Contains(LProjectResult.ContentJson, '"components"');
end;

procedure TTestRadIADelphiEcosystemTools.AuditsFireDACTransactionsWithoutExecutingSql;
var
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Data.pas'),
    'procedure Save;' + sLineBreak +
    'begin' + sLineBreak +
    '  MainTransaction.StartTransaction;' + sLineBreak +
    'end;'
  );
  LResult := ExecuteTool(FRootPath, 'AuditFireDACTransactions');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'firedac.transaction.commit-missing');
  Assert.Contains(LResult.ContentJson, '"sqlExecuted":false');
end;

procedure TTestRadIADelphiEcosystemTools.InspectsFireDACConfigurationWithoutReturningCredentials;
var
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Data.dfm'),
    'object MainConnection: TFDConnection' + sLineBreak +
    '  Params.Strings = (' + sLineBreak +
    '    ''DriverID=SQLite''' + sLineBreak +
    '    ''Password=never-return'')' + sLineBreak +
    'end'
  );
  LResult := ExecuteTool(FRootPath, 'InspectFireDACConfiguration');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"driverId":"SQLite"');
  Assert.Contains(LResult.ContentJson, '"credentialsCollected":false');
  Assert.DoesNotContain(LResult.ContentJson, 'never-return');
end;

procedure TTestRadIADelphiEcosystemTools.AnalyzesFireDACThreadSafetyWithoutExecutingSql;
var
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Worker.pas'),
    'type TDataModule = class' + sLineBreak +
    '  MainConnection: TFDConnection;' + sLineBreak +
    'end;' + sLineBreak +
    'TTask.Run(procedure begin MainConnection.Open; end);'
  );
  LResult := ExecuteTool(FRootPath, 'AnalyzeFireDACThreadSafety');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'firedac.thread.shared-component');
  Assert.Contains(LResult.ContentJson, '"sqlExecuted":false');
end;

procedure TTestRadIADelphiEcosystemTools.GetsSanitizedFireDACProjectReport;
var
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Data.pas'),
    'Query.SQL.Text := ''select id from customer where id = :Id'';'
  );
  LResult := ExecuteTool(FRootPath, 'GetFireDACProjectReport');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"name":"Id"');
  Assert.DoesNotContain(LResult.ContentJson, 'select id from customer');
end;

procedure TTestRadIADelphiEcosystemTools.DiagnosesFireDACEnvironmentWithoutExternalActions;
var
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Data.dfm'),
    'object Connection: TFDConnection' + sLineBreak +
    '  Params.Strings = (''DriverID=SQLite'')' + sLineBreak +
    'end'
  );
  LResult := ExecuteTool(FRootPath, 'DiagnoseFireDACEnvironment');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"configuredDriverIds":["SQLite"]');
  Assert.Contains(LResult.ContentJson, '"driverInstallationAttempted":false');
end;

procedure TTestRadIADelphiEcosystemTools.ReportsMissingDependencyPaths;
var
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Fixture.dproj'),
    '<Project><DCC_UnitSearchPath>missing-library</DCC_UnitSearchPath></Project>'
  );
  LResult := ExecuteTool(FRootPath, 'DiagnoseDelphiDependencies');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"missingPathCount":1');
  Assert.Contains(LResult.ContentJson, 'missing-library');
end;

procedure TTestRadIADelphiEcosystemTools.FindsLocalizationCandidates;
var
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Main.pas'),
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  ShowMessage(''Hello'');' + sLineBreak +
    'end;'
  );
  LResult := ExecuteTool(FRootPath, 'AuditDelphiLocalization');
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"candidateCount":1');
  Assert.Contains(LResult.ContentJson, '"line":3');
end;

procedure TTestRadIADelphiEcosystemTools.PreparesLocalizationExtractionWithoutApplyingIt;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
begin
  TFile.WriteAllText(
    TPath.Combine(FRootPath, 'Main.pas'),
    'unit Main;' + sLineBreak + 'interface' + sLineBreak + 'implementation' + sLineBreak +
    'procedure Run; begin ShowMessage(''Hello''); end;' + sLineBreak + 'end.'
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIADelphiEcosystemTools(
    LRegistry,
    TRadIAEcosystemWorkspaceStub.Create(FRootPath),
    TRadIAEcosystemPatchStub.Create,
    TRadIAWorkspaceBoundary.Create
  );
  LResult := LRegistry.Resolve('PrepareLocalizationExtraction').Execute(
    TRadIAToolRequest.Create(
      'PrepareLocalizationExtraction',
      '{"literal":"Hello","resourceName":"SHello"}',
      'localization-test'
    )
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"previewId":"localization-preview"');
  Assert.Contains(LResult.ContentJson, '"mutationApplied":false');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIADelphiEcosystemTools);

end.
