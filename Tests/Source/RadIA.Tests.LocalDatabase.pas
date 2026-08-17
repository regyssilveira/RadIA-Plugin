unit RadIA.Tests.LocalDatabase;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIALocalDatabaseTests = class
  private
    FDatabaseFile: string;
    FRootPath: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure InspectsSchemaWithoutChangingDatabase;
    [Test]
    procedure PreviewsBoundedRowsAndSanitizesSecrets;
    [Test]
    procedure SupportsReadOnlyCommonTableExpression;
    [Test]
    procedure RejectsMutatingAndCompoundSql;
    [Test]
    procedure ToolsRejectDatabaseOutsideWorkspace;
    [Test]
    procedure ComparesFireDACExpectationsWithAuthorizedSchema;
    [Test]
    procedure GeneratesSanitizedFireDACSchemaReport;
  end;

implementation

uses
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.LocalDatabase,
  RadIA.Core.LocalDatabaseTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIALocalDatabaseTestWorkspace = class(
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
    function GetEditorContent(const AMaxCharacters: Integer): TRadIAEditorContent;
    function GetEditorSelection: TRadIAEditorSelection;
    function GetCursorPosition: TRadIAEditorPosition;
    function GetCompilerMessages(
      const AMaxCount: Integer
    ): TArray<TRadIACompilerMessage>;
  end;

constructor TRadIALocalDatabaseTestWorkspace.Create(const ARootPath: string);
begin
  inherited Create;
  FRootPath := ARootPath;
end;

function TRadIALocalDatabaseTestWorkspace.GetIDEState: TRadIAIDEState;
begin
  Result := TRadIAIDEState.Create('Test', 'Win32', False, []);
end;

function TRadIALocalDatabaseTestWorkspace.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'DatabaseFixture',
    TPath.Combine(FRootPath, 'DatabaseFixture.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TRadIALocalDatabaseTestWorkspace.GetActiveUnit: string;
begin
  Result := '';
end;

function TRadIALocalDatabaseTestWorkspace.ListOpenFiles: TArray<string>;
begin
  Result := nil;
end;

function TRadIALocalDatabaseTestWorkspace.ListProjectUnits: TArray<string>;
begin
  Result := nil;
end;

function TRadIALocalDatabaseTestWorkspace.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TRadIALocalDatabaseTestWorkspace.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TRadIALocalDatabaseTestWorkspace.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TRadIALocalDatabaseTestWorkspace.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := nil;
end;

procedure TRadIALocalDatabaseTests.Setup;
begin
  FRootPath := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-LocalDatabase-' + TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '')
  );
  TDirectory.CreateDirectory(FRootPath);
  FDatabaseFile := TPath.Combine(FRootPath, 'fixture.sqlite');
  TRadIALocalDatabaseService.CreateTestFixture(FDatabaseFile);
end;

procedure TRadIALocalDatabaseTests.TearDown;
begin
  if TDirectory.Exists(FRootPath) then
    TDirectory.Delete(FRootPath, True);
end;

procedure TRadIALocalDatabaseTests.InspectsSchemaWithoutChangingDatabase;
var
  LAfterHash: string;
  LBeforeHash: string;
  LErrorCode: string;
  LErrorMessage: string;
  LObjects: TJSONArray;
  LResult: TJSONObject;
  LService: IRadIALocalDatabaseService;
begin
  LBeforeHash := THashSHA2.GetHashStringFromFile(FDatabaseFile);
  LService := TRadIALocalDatabaseService.Create;
  LResult := nil;
  Assert.IsTrue(
    LService.Inspect(
      FDatabaseFile,
      LResult,
      LErrorCode,
      LErrorMessage
    ),
    LErrorCode + ': ' + LErrorMessage
  );
  try
    Assert.IsTrue(LResult.GetValue<Boolean>('readOnly'));
    LObjects := LResult.GetValue<TJSONArray>('objects');
    Assert.AreEqual(2, LObjects.Count);
    Assert.Contains(LObjects.ToJSON, 'customers');
    Assert.Contains(LObjects.ToJSON, 'customer_names');
    Assert.Contains(LObjects.ToJSON, 'api_token');
    Assert.Contains(LObjects.ToJSON, '"sensitive":true');
  finally
    LResult.Free;
  end;
  LAfterHash := THashSHA2.GetHashStringFromFile(FDatabaseFile);
  Assert.AreEqual(LBeforeHash, LAfterHash);
end;

procedure TRadIALocalDatabaseTests.PreviewsBoundedRowsAndSanitizesSecrets;
var
  LErrorCode: string;
  LErrorMessage: string;
  LResult: TJSONObject;
  LService: IRadIALocalDatabaseService;
begin
  LService := TRadIALocalDatabaseService.Create;
  LResult := nil;
  Assert.IsTrue(
    LService.PreviewQuery(
      FDatabaseFile,
      'SELECT id, name, api_token, note FROM customers ORDER BY id',
      2,
      LResult,
      LErrorCode,
      LErrorMessage
    ),
    LErrorCode + ': ' + LErrorMessage
  );
  try
    Assert.AreEqual(2, LResult.GetValue<Integer>('rowCount'));
    Assert.IsTrue(LResult.GetValue<Boolean>('truncated'));
    Assert.Contains(LResult.ToJSON, '[redacted]');
    Assert.Contains(LResult.ToJSON, '[binary 2 bytes]');
    Assert.DoesNotContain(LResult.ToJSON, 'secret-one');
    Assert.DoesNotContain(LResult.GetValue<string>('exportCsv'), 'secret-two');
    Assert.IsTrue(LResult.GetValue<Boolean>('exportSanitized'));
  finally
    LResult.Free;
  end;
end;

procedure TRadIALocalDatabaseTests.SupportsReadOnlyCommonTableExpression;
var
  LErrorCode: string;
  LErrorMessage: string;
  LResult: TJSONObject;
  LService: IRadIALocalDatabaseService;
begin
  LService := TRadIALocalDatabaseService.Create;
  LResult := nil;
  Assert.IsTrue(
    LService.PreviewQuery(
      FDatabaseFile,
      'WITH selected AS (SELECT name FROM customers) SELECT name FROM selected',
      10,
      LResult,
      LErrorCode,
      LErrorMessage
    ),
    LErrorCode + ': ' + LErrorMessage
  );
  try
    Assert.AreEqual(3, LResult.GetValue<Integer>('rowCount'));
  finally
    LResult.Free;
  end;
end;

procedure TRadIALocalDatabaseTests.RejectsMutatingAndCompoundSql;
const
  CUnsafeSql: array[0..7] of string = (
    'DELETE FROM customers',
    'WITH selected AS (SELECT 1) DELETE FROM customers',
    'SELECT * FROM customers; DROP TABLE customers',
    'ATTACH DATABASE ''other.db'' AS other',
    'PRAGMA journal_mode=WAL',
    'SELECT * FROM customers -- hidden',
    'CREATE TABLE unsafe(id INTEGER)',
    'UPDATE customers SET name = ''changed'''
  );
var
  LError: string;
  LNormalized: string;
  LSql: string;
begin
  for LSql in CUnsafeSql do
    Assert.IsFalse(
      TRadIALocalDatabaseService.ValidateReadOnlySql(
        LSql,
        LNormalized,
        LError
      ),
      LSql
    );
end;

procedure TRadIALocalDatabaseTests.ToolsRejectDatabaseOutsideWorkspace;
var
  LBoundary: IRadIAWorkspaceBoundary;
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LService: IRadIALocalDatabaseService;
  LTool: IRadIATool;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  LBoundary := TRadIAWorkspaceBoundary.Create;
  LRegistry := TRadIAToolRegistry.Create;
  LService := TRadIALocalDatabaseService.Create;
  LWorkspace := TRadIALocalDatabaseTestWorkspace.Create(FRootPath);
  RegisterRadIALocalDatabaseTools(
    LRegistry,
    LWorkspace,
    LBoundary,
    LService
  );
  LTool := LRegistry.Resolve('InspectLocalSQLiteDatabase');
  LResult := LTool.Execute(
    TRadIAToolRequest.Create(
      'InspectLocalSQLiteDatabase',
      '{"filePath":"..\\outside.sqlite"}',
      'database-boundary'
    )
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('outside_workspace', LResult.ErrorCode);
  Assert.AreEqual(4, LRegistry.Count);
end;

procedure TRadIALocalDatabaseTests.ComparesFireDACExpectationsWithAuthorizedSchema;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTool: IRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIALocalDatabaseTools(
    LRegistry,
    TRadIALocalDatabaseTestWorkspace.Create(FRootPath),
    TRadIAWorkspaceBoundary.Create,
    TRadIALocalDatabaseService.Create
  );
  LTool := LRegistry.Resolve('CompareFireDACCodeWithSchema');
  LResult := LTool.Execute(TRadIAToolRequest.Create(
    'CompareFireDACCodeWithSchema',
    '{"filePath":"fixture.sqlite","expectations":[' +
    '{"table":"customers","column":"id","dataType":"string","nullable":"true"},' +
    '{"table":"customers","column":"missing"}]}',
    'schema-comparison'
  ));
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, 'firedac.schema.type-mismatch');
  Assert.Contains(LResult.ContentJson, 'firedac.schema.column-missing');
  Assert.Contains(LResult.ContentJson, '"schemaReadOnly":true');
  Assert.DoesNotContain(LResult.ContentJson, 'secret-one');
end;

procedure TRadIALocalDatabaseTests.GeneratesSanitizedFireDACSchemaReport;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTool: IRadIATool;
begin
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIALocalDatabaseTools(
    LRegistry,
    TRadIALocalDatabaseTestWorkspace.Create(FRootPath),
    TRadIAWorkspaceBoundary.Create,
    TRadIALocalDatabaseService.Create
  );
  LTool := LRegistry.Resolve('GenerateFireDACSchemaReport');
  LResult := LTool.Execute(TRadIAToolRequest.Create(
    'GenerateFireDACSchemaReport',
    '{"filePath":"fixture.sqlite"}',
    'schema-report'
  ));
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"reportKind":"firedac-schema"');
  Assert.Contains(LResult.ContentJson, '"schemaOnly":true');
  Assert.Contains(LResult.ContentJson, '"readOnly":true');
  Assert.DoesNotContain(LResult.ContentJson, 'secret-one');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIALocalDatabaseTests);

end.
