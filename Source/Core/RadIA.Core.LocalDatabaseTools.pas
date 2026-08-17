unit RadIA.Core.LocalDatabaseTools;

interface

uses
  RadIA.Core.LocalDatabase,
  RadIA.Core.Tools,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

procedure RegisterRadIALocalDatabaseTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const AService: IRadIALocalDatabaseService
);

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.Math,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.FireDAC.Model,
  RadIA.Core.FireDAC.Schema;

const
  CMaximumDatabaseBytes = 512 * 1024 * 1024;

type
  TRadIALocalDatabaseToolKind = (ldtInspect, ldtPreviewQuery, ldtCompareFireDACSchema);

  TRadIALocalDatabaseTool = class(TInterfacedObject, IRadIATool)
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FKind: TRadIALocalDatabaseToolKind;
    FService: IRadIALocalDatabaseService;
    FWorkspace: IRadIAWorkspaceFacade;
    function CompareFireDACSchema(
      const AInput: TJSONObject;
      const ASchema: TJSONObject
    ): TRadIAToolResult;
    function ResolveDatabasePath(
      const ACandidate: string;
      out AFileName: string;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary;
      const AService: IRadIALocalDatabaseService;
      const AKind: TRadIALocalDatabaseToolKind
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

constructor TRadIALocalDatabaseTool.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const AService: IRadIALocalDatabaseService;
  const AKind: TRadIALocalDatabaseToolKind
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  if not Assigned(AService) then
    raise EArgumentNilException.Create('AService');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
  FService := AService;
  FKind := AKind;
end;

function TRadIALocalDatabaseTool.ResolveDatabasePath(
  const ACandidate: string;
  out AFileName: string;
  out AErrorCode: string;
  out AErrorMessage: string
): Boolean;
var
  LExtension: string;
  LProject: TRadIAProjectSnapshot;
  LValidation: TRadIAPathValidation;
begin
  Result := False;
  AFileName := '';
  AErrorCode := '';
  AErrorMessage := '';
  LProject := FWorkspace.GetActiveProject;
  if LProject.RootPath.Trim.IsEmpty then
  begin
    AErrorCode := 'workspace_required';
    AErrorMessage := 'Open a Delphi project before inspecting a local database.';
    Exit;
  end;
  LValidation := FBoundary.ValidatePath(LProject.RootPath, ACandidate);
  if not LValidation.Allowed then
  begin
    AErrorCode := LValidation.ErrorCode;
    AErrorMessage := LValidation.ErrorMessage;
    Exit;
  end;
  LExtension := TPath.GetExtension(LValidation.ResolvedPath).ToLower;
  if not MatchText(LExtension, ['.db', '.sqlite', '.sqlite3']) then
  begin
    AErrorCode := 'unsupported_database';
    AErrorMessage := 'Only local .db, .sqlite, or .sqlite3 files are supported.';
    Exit;
  end;
  if not TFile.Exists(LValidation.ResolvedPath) then
  begin
    AErrorCode := 'database_not_found';
    AErrorMessage := 'The local database file does not exist.';
    Exit;
  end;
  if TFile.GetSize(LValidation.ResolvedPath) > CMaximumDatabaseBytes then
  begin
    AErrorCode := 'database_too_large';
    AErrorMessage := 'The local database exceeds the 512 MB inspection limit.';
    Exit;
  end;
  AFileName := LValidation.ResolvedPath;
  Result := True;
end;

function TRadIALocalDatabaseTool.CompareFireDACSchema(
  const AInput: TJSONObject;
  const ASchema: TJSONObject
): TRadIAToolResult;
var
  LComparison: TRadIAFireDACSchemaComparison;
  LComparator: TRadIAFireDACSchemaComparator;
  LExpectation: TJSONObject;
  LExpectations: TJSONArray;
  LItems: TList<TRadIAFireDACSchemaExpectation>;
  LValue: TJSONValue;
begin
  LExpectations := AInput.GetValue<TJSONArray>('expectations');
  if not Assigned(LExpectations) or (LExpectations.Count = 0) then
    Exit(TRadIAToolResult.Failed('expectations_required', 'At least one schema expectation is required.'));
  if LExpectations.Count > CRadIAFireDACMaximumSchemaExpectations then
    Exit(TRadIAToolResult.Failed('too_many_expectations', 'The schema expectation limit was exceeded.'));
  LItems := TList<TRadIAFireDACSchemaExpectation>.Create;
  LComparator := TRadIAFireDACSchemaComparator.Create;
  try
    for LValue in LExpectations do
    begin
      if not (LValue is TJSONObject) then
        Exit(TRadIAToolResult.Failed('invalid_expectation', 'Each expectation must be an object.'));
      LExpectation := TJSONObject(LValue);
      if LExpectation.GetValue<string>('table', '').Trim.IsEmpty or
        LExpectation.GetValue<string>('column', '').Trim.IsEmpty then
        Exit(TRadIAToolResult.Failed('invalid_expectation', 'Each expectation requires table and column.'));
      LItems.Add(TRadIAFireDACSchemaExpectation.Create(
        LExpectation.GetValue<string>('table', ''),
        LExpectation.GetValue<string>('column', ''),
        LExpectation.GetValue<string>('dataType', ''),
        LExpectation.GetValue<string>('nullable', 'unknown'),
        TRadIAFireDACLocation.Create('', 0)
      ));
    end;
    LComparison := LComparator.Compare(ASchema, LItems.ToArray);
    try
      Result := TRadIAToolResult.Succeeded(LComparison.ToJson, LComparison.Truncated);
    finally
      LComparison.Free;
    end;
  finally
    LComparator.Free;
    LItems.Free;
  end;
end;

function TRadIALocalDatabaseTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LErrorCode: string;
  LErrorMessage: string;
  LFileName: string;
  LInput: TJSONObject;
  LMaxRows: Integer;
  LResult: TJSONObject;
  LSql: string;
begin
  LInput := TJSONObject.ParseJSONValue(ARequest.ArgumentsJson) as TJSONObject;
  if not Assigned(LInput) then
    Exit(TRadIAToolResult.Failed(
      'invalid_arguments',
      'Arguments must be a JSON object.'
    ));
  try
    if not ResolveDatabasePath(
      LInput.GetValue<string>('filePath', ''),
      LFileName,
      LErrorCode,
      LErrorMessage
    ) then
      Exit(TRadIAToolResult.Failed(LErrorCode, LErrorMessage));
    LResult := nil;
    try
      try
        case FKind of
          ldtInspect, ldtCompareFireDACSchema:
            if not FService.Inspect(
              LFileName,
              LResult,
              LErrorCode,
              LErrorMessage
            ) then
              Exit(TRadIAToolResult.Failed(LErrorCode, LErrorMessage));
          ldtPreviewQuery:
            begin
              LSql := LInput.GetValue<string>('sql', '');
              LMaxRows := EnsureRange(
                LInput.GetValue<Integer>('maxRows', 100),
                1,
                500
              );
              if not FService.PreviewQuery(
                LFileName,
                LSql,
                LMaxRows,
                LResult,
                LErrorCode,
                LErrorMessage
              ) then
                Exit(TRadIAToolResult.Failed(LErrorCode, LErrorMessage));
            end;
        end;
      except
        on E: Exception do
          Exit(TRadIAToolResult.Failed(
            'database_runtime_unavailable',
            E.Message
          ));
      end;
      if FKind = ldtCompareFireDACSchema then
        Exit(CompareFireDACSchema(LInput, LResult));
      LResult.AddPair('databaseFile', TPath.GetFileName(LFileName));
      Result := TRadIAToolResult.Succeeded(LResult.ToJSON);
    finally
      LResult.Free;
    end;
  finally
    LInput.Free;
  end;
end;

function TRadIALocalDatabaseTool.GetDescriptor: TRadIAToolDescriptor;
const
  CFileInputSchema =
    '{"type":"object","additionalProperties":false,' +
    '"required":["filePath"],"properties":{' +
    '"filePath":{"type":"string","minLength":1,"maxLength":1024}}}';
  CQueryInputSchema =
    '{"type":"object","additionalProperties":false,' +
    '"required":["filePath","sql"],"properties":{' +
    '"filePath":{"type":"string","minLength":1,"maxLength":1024},' +
    '"sql":{"type":"string","minLength":1,"maxLength":32768},' +
    '"maxRows":{"type":"integer","minimum":1,"maximum":500}}}';
  CCompareInputSchema =
    '{"type":"object","additionalProperties":false,' +
    '"required":["filePath","expectations"],"properties":{' +
    '"filePath":{"type":"string","minLength":1,"maxLength":1024},' +
    '"expectations":{"type":"array","minItems":1,"maxItems":2048,' +
    '"items":{"type":"object","additionalProperties":false,' +
    '"required":["table","column"],"properties":{' +
    '"table":{"type":"string","minLength":1,"maxLength":128},' +
    '"column":{"type":"string","minLength":1,"maxLength":128},' +
    '"dataType":{"type":"string","maxLength":64},' +
    '"nullable":{"type":"string","enum":["unknown","true","false"]}}}}}}';
begin
  case FKind of
    ldtInspect:
      Result := TRadIAToolDescriptor.Create(
        'InspectLocalSQLiteDatabase',
        '1.0.0',
        'Reads tables, views, and columns from a workspace-local SQLite database without executing user SQL.',
        CFileInputSchema,
        '{"type":"object"}',
        trReadOnly
      );
    ldtPreviewQuery:
      Result := TRadIAToolDescriptor.Create(
        'PreviewLocalSQLiteQuery',
        '1.0.0',
        'Runs one reviewed read-only SQLite query with bounded rows and sanitized grid and CSV output.',
        CQueryInputSchema,
        '{"type":"object"}',
        trSensitive
      ).WithConsentEveryTime;
    ldtCompareFireDACSchema:
      Result := TRadIAToolDescriptor.Create(
        'CompareFireDACCodeWithSchema',
        '1.0.0',
        'Compares typed FireDAC expectations with an authorized workspace-local SQLite schema.',
        CCompareInputSchema,
        '{"type":"object"}',
        trReadOnly
      );
  end;
end;

procedure RegisterRadIALocalDatabaseTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const AService: IRadIALocalDatabaseService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(
    TRadIALocalDatabaseTool.Create(
      AWorkspace,
      ABoundary,
      AService,
      ldtInspect
    )
  );
  ARegistry.RegisterTool(
    TRadIALocalDatabaseTool.Create(
      AWorkspace,
      ABoundary,
      AService,
      ldtPreviewQuery
    )
  );
  ARegistry.RegisterTool(
    TRadIALocalDatabaseTool.Create(
      AWorkspace,
      ABoundary,
      AService,
      ldtCompareFireDACSchema
    )
  );
end;

end.
