unit RadIA.Core.LocalDatabase;

interface

uses
  System.JSON;

type
  IRadIALocalDatabaseService = interface
    ['{72B1E25F-CE0C-4B87-A57C-177B97CEB9B4}']
    function Inspect(
      const AFileName: string;
      out AResult: TJSONObject;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
    function PreviewQuery(
      const AFileName: string;
      const ASql: string;
      const AMaxRows: Integer;
      out AResult: TJSONObject;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
  end;

  TRadIALocalDatabaseService = class(
    TInterfacedObject,
    IRadIALocalDatabaseService
  )
  public
    function Inspect(
      const AFileName: string;
      out AResult: TJSONObject;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
    function PreviewQuery(
      const AFileName: string;
      const ASql: string;
      const AMaxRows: Integer;
      out AResult: TJSONObject;
      out AErrorCode: string;
      out AErrorMessage: string
    ): Boolean;
    class function ValidateReadOnlySql(
      const ASql: string;
      out ANormalizedSql: string;
      out AError: string
    ): Boolean; static;
    {$IFDEF TESTS}
    class procedure CreateTestFixture(const AFileName: string); static;
    {$ENDIF}
  end;

implementation

uses
  System.AnsiStrings,
  System.Generics.Collections,
  System.IOUtils,
  System.Math,
  System.RegularExpressions,
  System.SysUtils,
  Winapi.Windows;

const
  CMaximumColumns = 128;
  CMaximumObjects = 256;
  CMaximumRows = 500;
  CMaximumSqlLength = 32768;
  CMaximumTextLength = 4096;
  SQLITE_BLOB = 4;
  SQLITE_DONE = 101;
  SQLITE_FLOAT = 2;
  SQLITE_INTEGER = 1;
  SQLITE_NULL = 5;
  SQLITE_OK = 0;
  SQLITE_OPEN_READONLY = $00000001;
  SQLITE_ROW = 100;
  {$IFDEF TESTS}
  SQLITE_OPEN_CREATE = $00000004;
  SQLITE_OPEN_READWRITE = $00000002;
  {$ENDIF}

type
  TRadIASqliteOpen = function(
    const AFileName: PAnsiChar;
    out ADatabase: Pointer;
    const AFlags: Integer;
    const AVfs: PAnsiChar
  ): Integer; cdecl;
  TRadIASqliteClose = function(const ADatabase: Pointer): Integer; cdecl;
  TRadIASqliteError = function(const ADatabase: Pointer): PAnsiChar; cdecl;
  TRadIASqlitePrepare = function(
    const ADatabase: Pointer;
    const ASql: PAnsiChar;
    const ALength: Integer;
    out AStatement: Pointer;
    out ATail: PAnsiChar
  ): Integer; cdecl;
  TRadIASqliteStep = function(const AStatement: Pointer): Integer; cdecl;
  TRadIASqliteFinalize = function(const AStatement: Pointer): Integer; cdecl;
  TRadIASqliteColumnCount = function(const AStatement: Pointer): Integer; cdecl;
  TRadIASqliteColumnName = function(
    const AStatement: Pointer;
    const AIndex: Integer
  ): PAnsiChar; cdecl;
  TRadIASqliteColumnType = function(
    const AStatement: Pointer;
    const AIndex: Integer
  ): Integer; cdecl;
  TRadIASqliteColumnText = function(
    const AStatement: Pointer;
    const AIndex: Integer
  ): PAnsiChar; cdecl;
  TRadIASqliteColumnBytes = function(
    const AStatement: Pointer;
    const AIndex: Integer
  ): Integer; cdecl;
  TRadIASqliteColumnInt64 = function(
    const AStatement: Pointer;
    const AIndex: Integer
  ): Int64; cdecl;
  TRadIASqliteColumnDouble = function(
    const AStatement: Pointer;
    const AIndex: Integer
  ): Double; cdecl;
  TRadIASqliteStatementReadOnly = function(
    const AStatement: Pointer
  ): Integer; cdecl;
  TRadIASqliteExec = function(
    const ADatabase: Pointer;
    const ASql: PAnsiChar;
    const ACallback: Pointer;
    const AContext: Pointer;
    out AError: PAnsiChar
  ): Integer; cdecl;
  TRadIASqliteFree = procedure(const AValue: Pointer); cdecl;

  TRadIASqliteApi = class
  private
    FLibrary: HMODULE;
    FOpen: TRadIASqliteOpen;
    FClose: TRadIASqliteClose;
    FError: TRadIASqliteError;
    FPrepare: TRadIASqlitePrepare;
    FStep: TRadIASqliteStep;
    FFinalize: TRadIASqliteFinalize;
    FColumnCount: TRadIASqliteColumnCount;
    FColumnName: TRadIASqliteColumnName;
    FColumnType: TRadIASqliteColumnType;
    FColumnText: TRadIASqliteColumnText;
    FColumnBytes: TRadIASqliteColumnBytes;
    FColumnInt64: TRadIASqliteColumnInt64;
    FColumnDouble: TRadIASqliteColumnDouble;
    FStatementReadOnly: TRadIASqliteStatementReadOnly;
    FExec: TRadIASqliteExec;
    FFree: TRadIASqliteFree;
    function LibraryPath: string;
    function LoadProcedure(const AName: AnsiString): Pointer;
  public
    constructor Create;
    destructor Destroy; override;
    function Close(const ADatabase: Pointer): Integer;
    function ColumnBytes(const AStatement: Pointer; const AIndex: Integer): Integer;
    function ColumnCount(const AStatement: Pointer): Integer;
    function ColumnDouble(const AStatement: Pointer; const AIndex: Integer): Double;
    function ColumnInt64(const AStatement: Pointer; const AIndex: Integer): Int64;
    function ColumnName(const AStatement: Pointer; const AIndex: Integer): string;
    function ColumnText(const AStatement: Pointer; const AIndex: Integer): string;
    function ColumnType(const AStatement: Pointer; const AIndex: Integer): Integer;
    function ErrorMessage(const ADatabase: Pointer): string;
    function Execute(const ADatabase: Pointer; const ASql: string; out AError: string): Boolean;
    function Finalize(const AStatement: Pointer): Integer;
    function Open(const AFileName: string; const AFlags: Integer; out ADatabase: Pointer): Integer;
    function Prepare(
      const ADatabase: Pointer;
      const ASql: string;
      out AStatement: Pointer;
      out ATail: string
    ): Integer;
    function StatementReadOnly(const AStatement: Pointer): Boolean;
    function Step(const AStatement: Pointer): Integer;
  end;

function Utf8Value(const AValue: PAnsiChar; const ALength: Integer): string;
var
  LBytes: UTF8String;
begin
  if not Assigned(AValue) or (ALength <= 0) then
    Exit('');
  SetString(LBytes, AValue, ALength);
  Result := UTF8ToString(LBytes);
end;

{ TRadIASqliteApi }

constructor TRadIASqliteApi.Create;
var
  LPath: string;
begin
  inherited Create;
  LPath := LibraryPath;
  if LPath.IsEmpty then
    raise EFileNotFoundException.Create(
      'The trusted Embarcadero sqlite3.dll was not found.'
    );
  FLibrary := LoadLibrary(PChar(LPath));
  if FLibrary = 0 then
    RaiseLastOSError;
  FOpen := TRadIASqliteOpen(LoadProcedure('sqlite3_open_v2'));
  FClose := TRadIASqliteClose(LoadProcedure('sqlite3_close_v2'));
  FError := TRadIASqliteError(LoadProcedure('sqlite3_errmsg'));
  FPrepare := TRadIASqlitePrepare(LoadProcedure('sqlite3_prepare_v2'));
  FStep := TRadIASqliteStep(LoadProcedure('sqlite3_step'));
  FFinalize := TRadIASqliteFinalize(LoadProcedure('sqlite3_finalize'));
  FColumnCount := TRadIASqliteColumnCount(
    LoadProcedure('sqlite3_column_count')
  );
  FColumnName := TRadIASqliteColumnName(
    LoadProcedure('sqlite3_column_name')
  );
  FColumnType := TRadIASqliteColumnType(
    LoadProcedure('sqlite3_column_type')
  );
  FColumnText := TRadIASqliteColumnText(
    LoadProcedure('sqlite3_column_text')
  );
  FColumnBytes := TRadIASqliteColumnBytes(
    LoadProcedure('sqlite3_column_bytes')
  );
  FColumnInt64 := TRadIASqliteColumnInt64(
    LoadProcedure('sqlite3_column_int64')
  );
  FColumnDouble := TRadIASqliteColumnDouble(
    LoadProcedure('sqlite3_column_double')
  );
  FStatementReadOnly := TRadIASqliteStatementReadOnly(
    LoadProcedure('sqlite3_stmt_readonly')
  );
  FExec := TRadIASqliteExec(LoadProcedure('sqlite3_exec'));
  FFree := TRadIASqliteFree(LoadProcedure('sqlite3_free'));
end;

destructor TRadIASqliteApi.Destroy;
begin
  if FLibrary <> 0 then
    FreeLibrary(FLibrary);
  inherited Destroy;
end;

function TRadIASqliteApi.LibraryPath: string;
var
  LCandidates: TList<string>;
  LArchitecturePath: string;
  LCandidate: string;
  LExecutableDirectory: string;
  LPathEntry: string;
  LStudioRoot: string;
begin
  Result := '';
  LCandidates := TList<string>.Create;
  try
    LExecutableDirectory := TPath.GetDirectoryName(ParamStr(0));
    LCandidates.Add(TPath.Combine(LExecutableDirectory, 'sqlite3.dll'));
    if not GetEnvironmentVariable('BDSBIN').IsEmpty then
    begin
      LPathEntry := GetEnvironmentVariable('BDSBIN');
      {$IFDEF WIN64}
      if SameText(TPath.GetFileName(LPathEntry), 'bin') then
        LPathEntry := TPath.Combine(TPath.GetDirectoryName(LPathEntry), 'bin64');
      {$ELSE}
      if SameText(TPath.GetFileName(LPathEntry), 'bin64') then
        LPathEntry := TPath.Combine(TPath.GetDirectoryName(LPathEntry), 'bin');
      {$ENDIF}
      LCandidates.Add(TPath.Combine(LPathEntry, 'sqlite3.dll'));
    end;
    for LPathEntry in GetEnvironmentVariable('PATH').Split([';']) do
      if LPathEntry.Contains('\Embarcadero\Studio\') then
      begin
        LArchitecturePath := LPathEntry;
        {$IFDEF WIN64}
        if SameText(TPath.GetFileName(LArchitecturePath), 'bin') then
          LArchitecturePath := TPath.Combine(
            TPath.GetDirectoryName(LArchitecturePath),
            'bin64'
          );
        {$ELSE}
        if SameText(TPath.GetFileName(LArchitecturePath), 'bin64') then
          LArchitecturePath := TPath.Combine(
            TPath.GetDirectoryName(LArchitecturePath),
            'bin'
          );
        {$ENDIF}
        LCandidates.Add(TPath.Combine(LArchitecturePath, 'sqlite3.dll'));
      end;
    LStudioRoot := GetEnvironmentVariable('BDS');
    if not LStudioRoot.IsEmpty then
    begin
      {$IFDEF WIN64}
      LCandidates.Add(TPath.Combine(LStudioRoot, 'bin64\sqlite3.dll'));
      {$ELSE}
      LCandidates.Add(TPath.Combine(LStudioRoot, 'bin\sqlite3.dll'));
      {$ENDIF}
    end;
    for LCandidate in LCandidates do
      if TFile.Exists(LCandidate) then
        Exit(TPath.GetFullPath(LCandidate));
  finally
    LCandidates.Free;
  end;
end;

function TRadIASqliteApi.LoadProcedure(const AName: AnsiString): Pointer;
begin
  Result := GetProcAddress(FLibrary, PAnsiChar(AName));
  if not Assigned(Result) then
    raise ENotSupportedException.CreateFmt(
      'The trusted SQLite runtime does not export %s.',
      [string(AName)]
    );
end;

function TRadIASqliteApi.Open(
  const AFileName: string;
  const AFlags: Integer;
  out ADatabase: Pointer
): Integer;
var
  LFileName: UTF8String;
begin
  LFileName := UTF8Encode(AFileName);
  Result := FOpen(PAnsiChar(LFileName), ADatabase, AFlags, nil);
end;

function TRadIASqliteApi.Close(const ADatabase: Pointer): Integer;
begin
  Result := FClose(ADatabase);
end;

function TRadIASqliteApi.ErrorMessage(const ADatabase: Pointer): string;
var
  LMessage: PAnsiChar;
begin
  LMessage := FError(ADatabase);
  if Assigned(LMessage) then
    Result := Utf8Value(LMessage, System.AnsiStrings.StrLen(LMessage))
  else
    Result := '';
end;

function TRadIASqliteApi.Execute(
  const ADatabase: Pointer;
  const ASql: string;
  out AError: string
): Boolean;
var
  LError: PAnsiChar;
  LSql: UTF8String;
begin
  LError := nil;
  LSql := UTF8Encode(ASql);
  Result := FExec(ADatabase, PAnsiChar(LSql), nil, nil, LError) = SQLITE_OK;
  if not Result and Assigned(LError) then
  begin
    AError := Utf8Value(LError, System.AnsiStrings.StrLen(LError));
    FFree(LError);
  end
  else
    AError := '';
end;

function TRadIASqliteApi.Prepare(
  const ADatabase: Pointer;
  const ASql: string;
  out AStatement: Pointer;
  out ATail: string
): Integer;
var
  LSql: UTF8String;
  LTail: PAnsiChar;
begin
  LSql := UTF8Encode(ASql);
  LTail := nil;
  Result := FPrepare(
    ADatabase,
    PAnsiChar(LSql),
    Length(LSql),
    AStatement,
    LTail
  );
  if Assigned(LTail) then
    ATail := Utf8Value(LTail, System.AnsiStrings.StrLen(LTail))
  else
    ATail := '';
end;

function TRadIASqliteApi.Step(const AStatement: Pointer): Integer;
begin
  Result := FStep(AStatement);
end;

function TRadIASqliteApi.Finalize(const AStatement: Pointer): Integer;
begin
  Result := FFinalize(AStatement);
end;

function TRadIASqliteApi.StatementReadOnly(
  const AStatement: Pointer
): Boolean;
begin
  Result := FStatementReadOnly(AStatement) <> 0;
end;

function TRadIASqliteApi.ColumnCount(const AStatement: Pointer): Integer;
begin
  Result := FColumnCount(AStatement);
end;

function TRadIASqliteApi.ColumnName(
  const AStatement: Pointer;
  const AIndex: Integer
): string;
var
  LValue: PAnsiChar;
begin
  LValue := FColumnName(AStatement, AIndex);
  Result := Utf8Value(LValue, System.AnsiStrings.StrLen(LValue));
end;

function TRadIASqliteApi.ColumnType(
  const AStatement: Pointer;
  const AIndex: Integer
): Integer;
begin
  Result := FColumnType(AStatement, AIndex);
end;

function TRadIASqliteApi.ColumnBytes(
  const AStatement: Pointer;
  const AIndex: Integer
): Integer;
begin
  Result := FColumnBytes(AStatement, AIndex);
end;

function TRadIASqliteApi.ColumnText(
  const AStatement: Pointer;
  const AIndex: Integer
): string;
begin
  Result := Utf8Value(
    FColumnText(AStatement, AIndex),
    FColumnBytes(AStatement, AIndex)
  );
end;

function TRadIASqliteApi.ColumnInt64(
  const AStatement: Pointer;
  const AIndex: Integer
): Int64;
begin
  Result := FColumnInt64(AStatement, AIndex);
end;

function TRadIASqliteApi.ColumnDouble(
  const AStatement: Pointer;
  const AIndex: Integer
): Double;
begin
  Result := FColumnDouble(AStatement, AIndex);
end;

function IsSensitiveColumn(const AName: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    AName,
    '(?i)(password|passwd|secret|token|api[_-]?key|credential|authorization)'
  );
end;

function CsvField(const AValue: string): string;
begin
  Result := '"' + AValue.Replace('"', '""') + '"';
end;

function BuildCsv(
  const AColumns: TJSONArray;
  const ARows: TJSONArray
): string;
var
  LBuilder: TStringBuilder;
  LColumnIndex: Integer;
  LRow: TJSONArray;
  LRowIndex: Integer;
  LValue: TJSONValue;
begin
  LBuilder := TStringBuilder.Create;
  try
    for LColumnIndex := 0 to AColumns.Count - 1 do
    begin
      if LColumnIndex > 0 then
        LBuilder.Append(',');
      LBuilder.Append(CsvField(AColumns[LColumnIndex].Value));
    end;
    LBuilder.AppendLine;
    for LRowIndex := 0 to ARows.Count - 1 do
    begin
      LRow := ARows[LRowIndex] as TJSONArray;
      for LColumnIndex := 0 to LRow.Count - 1 do
      begin
        if LColumnIndex > 0 then
          LBuilder.Append(',');
        LValue := LRow[LColumnIndex];
        if LValue is TJSONNull then
          LBuilder.Append('')
        else
          LBuilder.Append(CsvField(LValue.Value));
      end;
      LBuilder.AppendLine;
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function DetectSqlQuote(const ACharacter: Char): Char;
begin
  if CharInSet(ACharacter, ['''', '"', '`', '[']) then
    Result := ACharacter
  else
    Result := #0;
end;

procedure MaskSqlQuotedCharacter(
  var AText: string;
  var AIndex: Integer;
  var AQuote: Char;
  const ACharacter: Char
);
var
  LClosingQuote: Char;
begin
  AText[AIndex] := ' ';
  LClosingQuote := AQuote;
  if AQuote = '[' then
    LClosingQuote := ']';
  if ACharacter <> LClosingQuote then
    Exit;
  if (AQuote <> '[') and (AIndex < High(AText)) and
    (AText[AIndex + 1] = ACharacter) then
  begin
    Inc(AIndex);
    AText[AIndex] := ' ';
    Exit;
  end;
  AQuote := #0;
end;

function MaskQuotedSql(const ASql: string): string;
var
  LCharacter: Char;
  LIndex: Integer;
  LQuote: Char;
begin
  Result := ASql;
  LQuote := #0;
  LIndex := Low(Result);
  while LIndex <= High(Result) do
  begin
    LCharacter := Result[LIndex];
    if LQuote <> #0 then
      MaskSqlQuotedCharacter(Result, LIndex, LQuote, LCharacter)
    else
    begin
      LQuote := DetectSqlQuote(LCharacter);
      if LQuote <> #0 then
      begin
        Result[LIndex] := ' ';
      end;
    end;
    Inc(LIndex);
  end;
end;

class function TRadIALocalDatabaseService.ValidateReadOnlySql(
  const ASql: string;
  out ANormalizedSql: string;
  out AError: string
): Boolean;
var
  LMasked: string;
  LUpper: string;
begin
  ANormalizedSql := ASql.Trim;
  AError := '';
  if ANormalizedSql.IsEmpty or (ANormalizedSql.Length > CMaximumSqlLength) then
  begin
    AError := 'SQL must contain between 1 and 32768 characters.';
    Exit(False);
  end;
  if ANormalizedSql.Contains('--') or ANormalizedSql.Contains('/*') or
    ANormalizedSql.Contains('*/') then
  begin
    AError := 'SQL comments are not allowed in a reviewed local preview.';
    Exit(False);
  end;
  if ANormalizedSql.EndsWith(';') then
    ANormalizedSql := ANormalizedSql.Substring(0, ANormalizedSql.Length - 1).Trim;
  LMasked := MaskQuotedSql(ANormalizedSql);
  if LMasked.Contains(';') then
  begin
    AError := 'Only one SQL statement can be previewed.';
    Exit(False);
  end;
  LUpper := LMasked.TrimLeft.ToUpper;
  if not (LUpper.StartsWith('SELECT ') or LUpper.StartsWith('SELECT' + #13) or
    LUpper.StartsWith('SELECT' + #10) or LUpper.StartsWith('WITH ') or
    LUpper.StartsWith('WITH' + #13) or LUpper.StartsWith('WITH' + #10) or
    LUpper.StartsWith('PRAGMA ')) then
  begin
    AError := 'Only SELECT, read-only WITH, or metadata PRAGMA statements are allowed.';
    Exit(False);
  end;
  if TRegEx.IsMatch(
    LUpper,
    '\b(INSERT|UPDATE|DELETE|REPLACE|CREATE|ALTER|DROP|ATTACH|DETACH|' +
    'VACUUM|REINDEX|ANALYZE|BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)\b'
  ) then
  begin
    AError := 'The SQL contains a mutating or database-control operation.';
    Exit(False);
  end;
  if LUpper.StartsWith('PRAGMA ') and not TRegEx.IsMatch(
    LUpper,
    '^PRAGMA\s+(TABLE_(X?INFO)|INDEX_(LIST|INFO|XINFO)|FOREIGN_KEY_LIST)\s*\('
  ) then
  begin
    AError := 'Only schema metadata PRAGMA functions are allowed.';
    Exit(False);
  end;
  Result := True;
end;

function OpenReadOnlyDatabase(
  const AApi: TRadIASqliteApi;
  const AFileName: string;
  out ADatabase: Pointer;
  out AError: string
): Boolean;
begin
  ADatabase := nil;
  Result := AApi.Open(AFileName, SQLITE_OPEN_READONLY, ADatabase) = SQLITE_OK;
  if not Result then
  begin
    if Assigned(ADatabase) then
      AError := AApi.ErrorMessage(ADatabase)
    else
      AError := 'SQLite could not open the database in read-only mode.';
    Exit;
  end;
  Result := AApi.Execute(
    ADatabase,
    'PRAGMA query_only=ON; PRAGMA trusted_schema=OFF;',
    AError
  );
end;

function AddColumnValue(
  const AApi: TRadIASqliteApi;
  const AStatement: Pointer;
  const AColumnIndex: Integer;
  const ASensitive: Boolean
): TJSONValue;
var
  LBytes: Integer;
  LText: string;
begin
  if ASensitive then
    Exit(TJSONString.Create('[redacted]'));
  case AApi.ColumnType(AStatement, AColumnIndex) of
    SQLITE_INTEGER:
      Result := TJSONNumber.Create(AApi.ColumnInt64(AStatement, AColumnIndex));
    SQLITE_FLOAT:
      Result := TJSONNumber.Create(AApi.ColumnDouble(AStatement, AColumnIndex));
    SQLITE_NULL:
      Result := TJSONNull.Create;
    SQLITE_BLOB:
      Result := TJSONString.Create(
        Format('[binary %d bytes]', [AApi.ColumnBytes(AStatement, AColumnIndex)])
      );
  else
    begin
      LText := AApi.ColumnText(AStatement, AColumnIndex);
      LBytes := LText.Length;
      if LBytes > CMaximumTextLength then
        LText := LText.Substring(0, CMaximumTextLength) + #$2026;
      Result := TJSONString.Create(LText);
    end;
  end;
end;

function ValidatePreparedQuery(
  const AApi: TRadIASqliteApi;
  const AStatement: Pointer;
  const ATail: string;
  out AError: string
): Boolean;
begin
  Result := False;
  if not ATail.Trim.IsEmpty then
    AError := 'SQLite detected trailing SQL after the reviewed statement.'
  else if not AApi.StatementReadOnly(AStatement) then
    AError := 'SQLite classified the prepared statement as mutable.'
  else if AApi.ColumnCount(AStatement) > CMaximumColumns then
    AError := 'The query exposes more than 128 columns.'
  else
    Result := True;
end;

procedure PopulateQueryColumns(
  const AApi: TRadIASqliteApi;
  const AStatement: Pointer;
  const AColumns: TJSONArray;
  const ARedacted: TJSONArray;
  out ASensitive: TArray<Boolean>
);
var
  LColumnIndex: Integer;
  LColumnName: string;
begin
  SetLength(ASensitive, AApi.ColumnCount(AStatement));
  for LColumnIndex := 0 to High(ASensitive) do
  begin
    LColumnName := AApi.ColumnName(AStatement, LColumnIndex);
    ASensitive[LColumnIndex] := IsSensitiveColumn(LColumnName);
    AColumns.Add(LColumnName);
    if ASensitive[LColumnIndex] then
      ARedacted.Add(LColumnName);
  end;
end;

function ReadBoundedRows(
  const AApi: TRadIASqliteApi;
  const AStatement: Pointer;
  const AMaxRows: Integer;
  const ASensitive: TArray<Boolean>;
  const ARows: TJSONArray;
  out ATruncated: Boolean;
  out AError: string
): Boolean;
var
  LColumnIndex: Integer;
  LRow: TJSONArray;
  LStepResult: Integer;
begin
  ATruncated := False;
  repeat
    LStepResult := AApi.Step(AStatement);
    if (LStepResult = SQLITE_ROW) and (ARows.Count >= AMaxRows) then
    begin
      ATruncated := True;
      Break;
    end;
    if LStepResult = SQLITE_ROW then
    begin
      LRow := TJSONArray.Create;
      for LColumnIndex := 0 to High(ASensitive) do
        LRow.AddElement(
          AddColumnValue(AApi, AStatement, LColumnIndex, ASensitive[LColumnIndex])
        );
      ARows.AddElement(LRow);
    end;
  until LStepResult <> SQLITE_ROW;
  Result := (LStepResult = SQLITE_DONE) or ATruncated;
  if not Result then
    AError := 'SQLite could not complete the reviewed read-only query.';
end;

function ExecuteBoundedQuery(
  const AApi: TRadIASqliteApi;
  const ADatabase: Pointer;
  const ASql: string;
  const AMaxRows: Integer;
  out AResult: TJSONObject;
  out AError: string
): Boolean;
var
  LColumns: TJSONArray;
  LRedacted: TJSONArray;
  LRows: TJSONArray;
  LSensitive: TArray<Boolean>;
  LStatement: Pointer;
  LTail: string;
  LTruncated: Boolean;
begin
  Result := False;
  AResult := nil;
  LStatement := nil;
  if AApi.Prepare(ADatabase, ASql, LStatement, LTail) <> SQLITE_OK then
  begin
    AError := AApi.ErrorMessage(ADatabase);
    Exit;
  end;
  try
    if not ValidatePreparedQuery(AApi, LStatement, LTail, AError) then
      Exit;
    LColumns := TJSONArray.Create;
    LRows := TJSONArray.Create;
    LRedacted := TJSONArray.Create;
    try
      PopulateQueryColumns(AApi, LStatement, LColumns, LRedacted, LSensitive);
      if not ReadBoundedRows(
        AApi,
        LStatement,
        AMaxRows,
        LSensitive,
        LRows,
        LTruncated,
        AError
      ) then
        Exit;
      AResult := TJSONObject.Create;
      AResult.AddPair('status', 'ready');
      AResult.AddPair('readOnly', TJSONBool.Create(True));
      AResult.AddPair('columns', LColumns);
      AResult.AddPair('rows', LRows);
      AResult.AddPair('rowCount', TJSONNumber.Create(LRows.Count));
      AResult.AddPair('maxRows', TJSONNumber.Create(AMaxRows));
      AResult.AddPair('truncated', TJSONBool.Create(LTruncated));
      AResult.AddPair('redactedColumns', LRedacted);
      AResult.AddPair('exportCsv', BuildCsv(LColumns, LRows));
      AResult.AddPair('exportSanitized', TJSONBool.Create(True));
      LColumns := nil;
      LRows := nil;
      LRedacted := nil;
      Result := True;
    finally
      LColumns.Free;
      LRows.Free;
      LRedacted.Free;
    end;
  finally
    AApi.Finalize(LStatement);
  end;
end;

function TRadIALocalDatabaseService.PreviewQuery(
  const AFileName: string;
  const ASql: string;
  const AMaxRows: Integer;
  out AResult: TJSONObject;
  out AErrorCode: string;
  out AErrorMessage: string
): Boolean;
var
  LApi: TRadIASqliteApi;
  LDatabase: Pointer;
  LMaxRows: Integer;
  LSql: string;
begin
  AResult := nil;
  AErrorCode := '';
  AErrorMessage := '';
  if not ValidateReadOnlySql(ASql, LSql, AErrorMessage) then
  begin
    AErrorCode := 'unsafe_sql';
    Exit(False);
  end;
  LApi := TRadIASqliteApi.Create;
  try
    if not OpenReadOnlyDatabase(LApi, AFileName, LDatabase, AErrorMessage) then
    begin
      AErrorCode := 'database_open_failed';
      Exit(False);
    end;
    try
      LMaxRows := EnsureRange(AMaxRows, 1, CMaximumRows);
      Result := ExecuteBoundedQuery(
        LApi,
        LDatabase,
        LSql,
        LMaxRows,
        AResult,
        AErrorMessage
      );
      if not Result then
        AErrorCode := 'query_rejected';
    finally
      LApi.Close(LDatabase);
    end;
  finally
    LApi.Free;
  end;
end;

function QuoteSqlIdentifier(const AValue: string): string;
begin
  Result := '"' + AValue.Replace('"', '""') + '"';
end;

function ReadTableColumns(
  const AApi: TRadIASqliteApi;
  const ADatabase: Pointer;
  const ATableName: string;
  out AColumns: TJSONArray;
  out AError: string
): Boolean;
var
  LColumn: TJSONObject;
  LStatement: Pointer;
  LStepResult: Integer;
  LTail: string;
begin
  AColumns := TJSONArray.Create;
  LStatement := nil;
  Result := AApi.Prepare(
    ADatabase,
    'PRAGMA table_info(' + QuoteSqlIdentifier(ATableName) + ')',
    LStatement,
    LTail
  ) = SQLITE_OK;
  if not Result then
  begin
    AError := AApi.ErrorMessage(ADatabase);
    Exit;
  end;
  try
    repeat
      LStepResult := AApi.Step(LStatement);
      if LStepResult = SQLITE_ROW then
      begin
        if AColumns.Count >= CMaximumColumns then
          Break;
        LColumn := TJSONObject.Create;
        LColumn.AddPair('name', AApi.ColumnText(LStatement, 1));
        LColumn.AddPair('dataType', AApi.ColumnText(LStatement, 2));
        LColumn.AddPair(
          'notNull',
          TJSONBool.Create(AApi.ColumnInt64(LStatement, 3) <> 0)
        );
        LColumn.AddPair(
          'primaryKey',
          TJSONBool.Create(AApi.ColumnInt64(LStatement, 5) <> 0)
        );
        LColumn.AddPair(
          'sensitive',
          TJSONBool.Create(IsSensitiveColumn(AApi.ColumnText(LStatement, 1)))
        );
        AColumns.AddElement(LColumn);
      end;
    until LStepResult <> SQLITE_ROW;
    Result := (LStepResult = SQLITE_DONE) or
      (AColumns.Count = CMaximumColumns);
    if not Result then
      AError := AApi.ErrorMessage(ADatabase);
  finally
    AApi.Finalize(LStatement);
  end;
end;

function InspectDatabase(
  const AApi: TRadIASqliteApi;
  const ADatabase: Pointer;
  out AResult: TJSONObject;
  out AError: string
): Boolean;
var
  LColumns: TJSONArray;
  LObject: TJSONObject;
  LObjects: TJSONArray;
  LStatement: Pointer;
  LStepResult: Integer;
  LTail: string;
begin
  AResult := nil;
  LStatement := nil;
  Result := AApi.Prepare(
    ADatabase,
    'SELECT name, type FROM sqlite_master ' +
    'WHERE type IN (''table'', ''view'') ' +
    'AND name NOT LIKE ''sqlite_%'' ORDER BY type, name',
    LStatement,
    LTail
  ) = SQLITE_OK;
  if not Result then
  begin
    AError := AApi.ErrorMessage(ADatabase);
    Exit;
  end;
  LObjects := TJSONArray.Create;
  try
    repeat
      LStepResult := AApi.Step(LStatement);
      if LStepResult = SQLITE_ROW then
      begin
        if LObjects.Count >= CMaximumObjects then
          Break;
        LObject := TJSONObject.Create;
        LObject.AddPair('name', AApi.ColumnText(LStatement, 0));
        LObject.AddPair('objectType', AApi.ColumnText(LStatement, 1));
        if not ReadTableColumns(
          AApi,
          ADatabase,
          AApi.ColumnText(LStatement, 0),
          LColumns,
          AError
        ) then
        begin
          LObject.Free;
          Exit(False);
        end;
        LObject.AddPair('columns', LColumns);
        LObjects.AddElement(LObject);
      end;
    until LStepResult <> SQLITE_ROW;
    Result := (LStepResult = SQLITE_DONE) or
      (LObjects.Count = CMaximumObjects);
    if not Result then
    begin
      AError := AApi.ErrorMessage(ADatabase);
      Exit;
    end;
    AResult := TJSONObject.Create;
    AResult.AddPair('status', 'ready');
    AResult.AddPair('engine', 'sqlite');
    AResult.AddPair('readOnly', TJSONBool.Create(True));
    AResult.AddPair('objectCount', TJSONNumber.Create(LObjects.Count));
    AResult.AddPair('objects', LObjects);
    LObjects := nil;
  finally
    AApi.Finalize(LStatement);
    LObjects.Free;
  end;
end;

function TRadIALocalDatabaseService.Inspect(
  const AFileName: string;
  out AResult: TJSONObject;
  out AErrorCode: string;
  out AErrorMessage: string
): Boolean;
var
  LApi: TRadIASqliteApi;
  LDatabase: Pointer;
begin
  AResult := nil;
  AErrorCode := '';
  AErrorMessage := '';
  LApi := TRadIASqliteApi.Create;
  try
    if not OpenReadOnlyDatabase(LApi, AFileName, LDatabase, AErrorMessage) then
    begin
      AErrorCode := 'database_open_failed';
      Exit(False);
    end;
    try
      Result := InspectDatabase(
        LApi,
        LDatabase,
        AResult,
        AErrorMessage
      );
      if not Result then
        AErrorCode := 'schema_read_failed';
    finally
      LApi.Close(LDatabase);
    end;
  finally
    LApi.Free;
  end;
end;

{$IFDEF TESTS}
class procedure TRadIALocalDatabaseService.CreateTestFixture(
  const AFileName: string
);
var
  LApi: TRadIASqliteApi;
  LDatabase: Pointer;
  LError: string;
begin
  if TFile.Exists(AFileName) then
    TFile.Delete(AFileName);
  LApi := TRadIASqliteApi.Create;
  try
    if LApi.Open(
      AFileName,
      SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE,
      LDatabase
    ) <> SQLITE_OK then
      raise EInOutError.Create('Unable to create the SQLite test fixture.');
    try
      if not LApi.Execute(
        LDatabase,
        'CREATE TABLE customers (' +
        'id INTEGER PRIMARY KEY, name TEXT NOT NULL, api_token TEXT, note BLOB);' +
        'INSERT INTO customers(name, api_token, note) VALUES ' +
        '(''Ana'', ''secret-one'', X''0102''),' +
        '(''Joao'', ''secret-two'', NULL),' +
        '(''Miyuki'', ''secret-three'', NULL);' +
        'CREATE VIEW customer_names AS SELECT id, name FROM customers;',
        LError
      ) then
        raise EInOutError.Create(LError);
    finally
      LApi.Close(LDatabase);
    end;
  finally
    LApi.Free;
  end;
end;
{$ENDIF}

end.
