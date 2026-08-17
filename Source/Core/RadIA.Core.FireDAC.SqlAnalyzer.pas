unit RadIA.Core.FireDAC.SqlAnalyzer;

interface

uses
  System.Generics.Collections,
  RadIA.Core.FireDAC.Model;

const
  CRadIAFireDACMaximumSqlLength = 256 * 1024;
  CRadIAFireDACMaximumStatements = 128;
  CRadIAFireDACMaximumParameters = 512;

type
  TRadIAFireDACSqlStatementKind = (
    fskUnknown,
    fskSelect,
    fskInsert,
    fskUpdate,
    fskDelete,
    fskMerge,
    fskExecute,
    fskDdl
  );

  TRadIAFireDACSqlParameter = record
  private
    FName: string;
    FOffset: Integer;
    FPrefix: Char;
  public
    constructor Create(const AName: string; const APrefix: Char; const AOffset: Integer);
    property Name: string read FName;
    property Offset: Integer read FOffset;
    property Prefix: Char read FPrefix;
  end;

  TRadIAFireDACSqlAnalysis = class
  private
    FFindings: TList<TRadIAFireDACFinding>;
    FParameters: TList<TRadIAFireDACSqlParameter>;
    FStatementCount: Integer;
    FStatementKind: TRadIAFireDACSqlStatementKind;
    FTruncated: Boolean;
    function ContainsParameter(const AName: string): Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFinding(const AFinding: TRadIAFireDACFinding);
    procedure AddParameter(const AParameter: TRadIAFireDACSqlParameter);
    function Findings: TArray<TRadIAFireDACFinding>;
    function Parameters: TArray<TRadIAFireDACSqlParameter>;
    function ToJson: string;
    property StatementCount: Integer read FStatementCount write FStatementCount;
    property StatementKind: TRadIAFireDACSqlStatementKind read FStatementKind write FStatementKind;
    property Truncated: Boolean read FTruncated write FTruncated;
  end;

  TRadIAFireDACSqlAnalyzer = class
  private
    function ClassifyStatement(const AMaskedSql: string): TRadIAFireDACSqlStatementKind;
    function CountStatements(const AMaskedSql: string; out ATruncated: Boolean): Integer;
    procedure ExtractParameters(
      const AMaskedSql: string;
      const AAnalysis: TRadIAFireDACSqlAnalysis
    );
    function MaskUntrustedSegments(const ASql: string): string;
  public
    function Analyze(
      const ASql: string;
      const AFileName: string = '';
      const ALine: Integer = 0
    ): TRadIAFireDACSqlAnalysis;
  end;

function RadIAFireDACSqlStatementKindName(const AKind: TRadIAFireDACSqlStatementKind): string;

implementation

uses
  System.JSON,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils;

type
  TRadIAFireDACSqlMaskState = (
    smsCode,
    smsSingleQuote,
    smsDoubleQuote,
    smsLineComment,
    smsBlockComment
  );

procedure MaskSqlCharacter(
  const ACharacters: TArray<Char>;
  const AIndex: Integer
);
begin
  if not CharInSet(ACharacters[AIndex], [#10, #13]) then
    ACharacters[AIndex] := ' ';
end;

procedure EnterSqlMaskState(
  const ASql: string;
  const AIndex: Integer;
  var AState: TRadIAFireDACSqlMaskState
);
begin
  if ASql.Chars[AIndex] = '''' then
    AState := smsSingleQuote
  else if ASql.Chars[AIndex] = '"' then
    AState := smsDoubleQuote
  else if (AIndex < ASql.Length - 1) and
    (ASql.Chars[AIndex] = '-') and
    (ASql.Chars[AIndex + 1] = '-') then
    AState := smsLineComment
  else if (AIndex < ASql.Length - 1) and
    (ASql.Chars[AIndex] = '/') and
    (ASql.Chars[AIndex + 1] = '*') then
    AState := smsBlockComment;
end;

procedure MaskSqlSingleQuote(
  const ASql: string;
  const ACharacters: TArray<Char>;
  var AIndex: Integer;
  var AState: TRadIAFireDACSqlMaskState
);
begin
  MaskSqlCharacter(ACharacters, AIndex);
  if (ASql.Chars[AIndex] = '''') and
    (AIndex < High(ACharacters)) and
    (ASql.Chars[AIndex + 1] = '''') then
  begin
    Inc(AIndex);
    ACharacters[AIndex] := ' ';
  end
  else if ASql.Chars[AIndex] = '''' then
    AState := smsCode;
end;

procedure MaskSqlDoubleQuote(
  const ASql: string;
  const ACharacters: TArray<Char>;
  const AIndex: Integer;
  var AState: TRadIAFireDACSqlMaskState
);
begin
  MaskSqlCharacter(ACharacters, AIndex);
  if ASql.Chars[AIndex] = '"' then
    AState := smsCode;
end;

procedure MaskSqlLineComment(
  const ASql: string;
  const ACharacters: TArray<Char>;
  const AIndex: Integer;
  var AState: TRadIAFireDACSqlMaskState
);
begin
  MaskSqlCharacter(ACharacters, AIndex);
  if CharInSet(ASql.Chars[AIndex], [#10, #13]) then
    AState := smsCode;
end;

procedure MaskSqlBlockComment(
  const ASql: string;
  const ACharacters: TArray<Char>;
  var AIndex: Integer;
  var AState: TRadIAFireDACSqlMaskState
);
begin
  MaskSqlCharacter(ACharacters, AIndex);
  if (ASql.Chars[AIndex] = '*') and
    (AIndex < High(ACharacters)) and
    (ASql.Chars[AIndex + 1] = '/') then
  begin
    Inc(AIndex);
    ACharacters[AIndex] := ' ';
    AState := smsCode;
  end;
end;

function SqlStatementKindFromToken(
  const AToken: string
): TRadIAFireDACSqlStatementKind;
begin
  if AToken = 'select' then
    Exit(fskSelect);
  if AToken = 'insert' then
    Exit(fskInsert);
  if AToken = 'update' then
    Exit(fskUpdate);
  if AToken = 'delete' then
    Exit(fskDelete);
  if AToken = 'merge' then
    Exit(fskMerge);
  if MatchText(AToken, ['execute', 'exec']) then
    Exit(fskExecute);
  if MatchText(AToken, ['create', 'alter', 'drop', 'truncate']) then
    Exit(fskDdl);
  Result := fskUnknown;
end;

function TryReadTopLevelSqlToken(
  const ASql: string;
  const ADepth: Integer;
  var AIndex: Integer;
  out AToken: string
): Boolean;
var
  LStart: Integer;
begin
  Result := (ADepth = 0) and
    CharInSet(ASql[AIndex], ['A'..'Z', 'a'..'z', '_']);
  if not Result then
    Exit;
  LStart := AIndex;
  while (AIndex <= High(ASql)) and
    CharInSet(ASql[AIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
    Inc(AIndex);
  AToken := LowerCase(ASql.Substring(LStart - 1, AIndex - LStart));
end;

function RadIAFireDACSqlStatementKindName(const AKind: TRadIAFireDACSqlStatementKind): string;
const
  CNames: array[TRadIAFireDACSqlStatementKind] of string = (
    'unknown', 'select', 'insert', 'update', 'delete', 'merge', 'execute', 'ddl'
  );
begin
  Result := CNames[AKind];
end;

constructor TRadIAFireDACSqlParameter.Create(
  const AName: string;
  const APrefix: Char;
  const AOffset: Integer
);
begin
  FName := AName;
  FPrefix := APrefix;
  FOffset := AOffset;
end;

constructor TRadIAFireDACSqlAnalysis.Create;
begin
  inherited Create;
  FFindings := TList<TRadIAFireDACFinding>.Create;
  FParameters := TList<TRadIAFireDACSqlParameter>.Create;
end;

destructor TRadIAFireDACSqlAnalysis.Destroy;
begin
  FParameters.Free;
  FFindings.Free;
  inherited;
end;

function TRadIAFireDACSqlAnalysis.ContainsParameter(const AName: string): Boolean;
var
  LParameter: TRadIAFireDACSqlParameter;
begin
  Result := False;
  for LParameter in FParameters do
    if SameText(LParameter.Name, AName) then
      Exit(True);
end;

procedure TRadIAFireDACSqlAnalysis.AddFinding(const AFinding: TRadIAFireDACFinding);
begin
  if FFindings.Count >= CRadIAFireDACMaximumFindings then
  begin
    FTruncated := True;
    Exit;
  end;
  FFindings.Add(AFinding);
end;

procedure TRadIAFireDACSqlAnalysis.AddParameter(
  const AParameter: TRadIAFireDACSqlParameter
);
begin
  if ContainsParameter(AParameter.Name) then
    Exit;
  if FParameters.Count >= CRadIAFireDACMaximumParameters then
  begin
    FTruncated := True;
    Exit;
  end;
  FParameters.Add(AParameter);
end;

function TRadIAFireDACSqlAnalysis.Parameters: TArray<TRadIAFireDACSqlParameter>;
begin
  Result := FParameters.ToArray;
end;

function TRadIAFireDACSqlAnalysis.Findings: TArray<TRadIAFireDACFinding>;
begin
  Result := FFindings.ToArray;
end;

function TRadIAFireDACSqlAnalysis.ToJson: string;
var
  LArray: TJSONArray;
  LFinding: TRadIAFireDACFinding;
  LObject: TJSONObject;
  LParameter: TRadIAFireDACSqlParameter;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('statementKind', RadIAFireDACSqlStatementKindName(FStatementKind));
    LRoot.AddPair('statementCount', TJSONNumber.Create(FStatementCount));
    LRoot.AddPair('mutable', TJSONBool.Create(FStatementKind in [
      fskInsert, fskUpdate, fskDelete, fskMerge, fskExecute, fskDdl
    ]));
    LRoot.AddPair('truncated', TJSONBool.Create(FTruncated));
    LArray := TJSONArray.Create;
    for LParameter in FParameters do
    begin
      LObject := TJSONObject.Create;
      LObject.AddPair('name', LParameter.Name);
      LObject.AddPair('prefix', string(LParameter.Prefix));
      LObject.AddPair('offset', TJSONNumber.Create(LParameter.Offset));
      LArray.AddElement(LObject);
    end;
    LRoot.AddPair('parameters', LArray);
    LArray := TJSONArray.Create;
    for LFinding in FFindings do
    begin
      LArray.AddElement(RadIAFireDACFindingToJson(LFinding));
    end;
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACSqlAnalyzer.MaskUntrustedSegments(const ASql: string): string;
var
  LIndex: Integer;
  LChars: TArray<Char>;
  LState: TRadIAFireDACSqlMaskState;
begin
  LChars := ASql.ToCharArray;
  LState := smsCode;
  LIndex := Low(LChars);
  while LIndex <= High(LChars) do
  begin
    case LState of
      smsCode:
        EnterSqlMaskState(ASql, LIndex, LState);
      smsSingleQuote:
        MaskSqlSingleQuote(ASql, LChars, LIndex, LState);
      smsDoubleQuote:
        MaskSqlDoubleQuote(ASql, LChars, LIndex, LState);
      smsLineComment:
        MaskSqlLineComment(ASql, LChars, LIndex, LState);
      smsBlockComment:
        MaskSqlBlockComment(ASql, LChars, LIndex, LState);
    end;
    Inc(LIndex);
  end;
  Result := string.Create(LChars);
end;

function TRadIAFireDACSqlAnalyzer.ClassifyStatement(
  const AMaskedSql: string
): TRadIAFireDACSqlStatementKind;
var
  LDepth: Integer;
  LIndex: Integer;
  LToken: string;
begin
  Result := fskUnknown;
  LDepth := 0;
  LIndex := Low(AMaskedSql);
  while LIndex <= High(AMaskedSql) do
  begin
    if AMaskedSql[LIndex] = '(' then
      Inc(LDepth)
    else if (AMaskedSql[LIndex] = ')') and (LDepth > 0) then
      Dec(LDepth)
    else if TryReadTopLevelSqlToken(
      AMaskedSql,
      LDepth,
      LIndex,
      LToken
    ) then
    begin
      Result := SqlStatementKindFromToken(LToken);
      if Result <> fskUnknown then
        Exit;
      Continue;
    end;
    Inc(LIndex);
  end;
end;

function TRadIAFireDACSqlAnalyzer.CountStatements(
  const AMaskedSql: string;
  out ATruncated: Boolean
): Integer;
var
  I: Integer;
  LHasContent: Boolean;
begin
  Result := 0;
  ATruncated := False;
  LHasContent := False;
  for I := Low(AMaskedSql) to High(AMaskedSql) do
    if AMaskedSql[I] = ';' then
    begin
      if LHasContent then
        Inc(Result);
      LHasContent := False;
      if Result >= CRadIAFireDACMaximumStatements then
      begin
        ATruncated := True;
        Exit;
      end;
    end
    else if not CharInSet(AMaskedSql[I], [#9, #10, #13, ' ']) then
      LHasContent := True;
  if LHasContent then
    Inc(Result);
end;

procedure TRadIAFireDACSqlAnalyzer.ExtractParameters(
  const AMaskedSql: string;
  const AAnalysis: TRadIAFireDACSqlAnalysis
);
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AMaskedSql, '(?<!:)([:@])([A-Za-z_][A-Za-z0-9_$]*)');
  while LMatch.Success do
  begin
    AAnalysis.AddParameter(TRadIAFireDACSqlParameter.Create(
      LMatch.Groups[2].Value,
      LMatch.Groups[1].Value[1],
      LMatch.Index
    ));
    LMatch := LMatch.NextMatch;
  end;
end;

function TRadIAFireDACSqlAnalyzer.Analyze(
  const ASql: string;
  const AFileName: string;
  const ALine: Integer
): TRadIAFireDACSqlAnalysis;
var
  LMaskedSql: string;
  LSql: string;
  LStatementLimitReached: Boolean;
begin
  Result := TRadIAFireDACSqlAnalysis.Create;
  try
    LSql := ASql;
    if LSql.Length > CRadIAFireDACMaximumSqlLength then
    begin
      LSql := LSql.Substring(0, CRadIAFireDACMaximumSqlLength);
      Result.Truncated := True;
    end;
    LMaskedSql := MaskUntrustedSegments(LSql);
    Result.StatementKind := ClassifyStatement(LMaskedSql);
    Result.StatementCount := CountStatements(LMaskedSql, LStatementLimitReached);
    Result.Truncated := Result.Truncated or LStatementLimitReached;
    ExtractParameters(LMaskedSql, Result);
    if Result.StatementCount > 1 then
      Result.AddFinding(TRadIAFireDACFinding.Create(
        'firedac.sql.multiple-statements',
        ffsHigh,
        ffcProven,
        'Multiple SQL statements',
        'The SQL text contains more than one executable statement.',
        TRadIAFireDACFindingDetails.Create(
          TRadIAFireDACLocation.Create(AFileName, ALine),
          '',
          'More than one top-level statement delimiter was found.',
          'Split the statements and review each execution boundary.',
          False
        )
      ));
  except
    Result.Free;
    raise;
  end;
end;

end.
