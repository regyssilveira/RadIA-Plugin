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
      LObject := TJSONObject.Create;
      LObject.AddPair('id', LFinding.Id);
      LObject.AddPair('ruleId', LFinding.RuleId);
      LObject.AddPair('severity', RadIAFireDACSeverityName(LFinding.Severity));
      LObject.AddPair('confidence', RadIAFireDACConfidenceName(LFinding.Confidence));
      LObject.AddPair('title', LFinding.Title);
      LObject.AddPair('message', LFinding.Message);
      LObject.AddPair('file', LFinding.Location.FileName);
      LObject.AddPair('line', TJSONNumber.Create(LFinding.Location.Line));
      LObject.AddPair('suggestedAction', LFinding.SuggestedAction);
      LObject.AddPair('automaticFixAvailable', TJSONBool.Create(LFinding.AutomaticFixAvailable));
      LArray.AddElement(LObject);
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
  I: Integer;
  LChars: TArray<Char>;
  LState: TRadIAFireDACSqlMaskState;
begin
  LChars := ASql.ToCharArray;
  LState := smsCode;
  I := Low(LChars);
  while I <= High(LChars) do
  begin
    case LState of
      smsCode:
        if LChars[I] = '''' then
          LState := smsSingleQuote
        else if LChars[I] = '"' then
          LState := smsDoubleQuote
        else if (LChars[I] = '-') and (I < High(LChars)) and (LChars[I + 1] = '-') then
          LState := smsLineComment
        else if (LChars[I] = '/') and (I < High(LChars)) and (LChars[I + 1] = '*') then
          LState := smsBlockComment;
      smsSingleQuote:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if (ASql.Chars[I] = '''') and (I < High(LChars)) and (ASql.Chars[I + 1] = '''') then
          begin
            Inc(I);
            LChars[I] := ' ';
          end
          else if ASql.Chars[I] = '''' then
            LState := smsCode;
        end;
      smsDoubleQuote:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if ASql.Chars[I] = '"' then
            LState := smsCode;
        end;
      smsLineComment:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if CharInSet(ASql.Chars[I], [#10, #13]) then
            LState := smsCode;
        end;
      smsBlockComment:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if (ASql.Chars[I] = '*') and (I < High(LChars)) and (ASql.Chars[I + 1] = '/') then
          begin
            Inc(I);
            LChars[I] := ' ';
            LState := smsCode;
          end;
        end;
    end;
    Inc(I);
  end;
  Result := string.Create(LChars);
end;

function TRadIAFireDACSqlAnalyzer.ClassifyStatement(
  const AMaskedSql: string
): TRadIAFireDACSqlStatementKind;
var
  LDepth: Integer;
  LIndex: Integer;
  LStart: Integer;
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
    else if (LDepth = 0) and CharInSet(AMaskedSql[LIndex], ['A'..'Z', 'a'..'z', '_']) then
    begin
      LStart := LIndex;
      while (LIndex <= High(AMaskedSql)) and
        CharInSet(AMaskedSql[LIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
        Inc(LIndex);
      LToken := LowerCase(AMaskedSql.Substring(LStart - 1, LIndex - LStart));
      if LToken = 'select' then
        Exit(fskSelect);
      if LToken = 'insert' then
        Exit(fskInsert);
      if LToken = 'update' then
        Exit(fskUpdate);
      if LToken = 'delete' then
        Exit(fskDelete);
      if LToken = 'merge' then
        Exit(fskMerge);
      if MatchText(LToken, ['execute', 'exec']) then
        Exit(fskExecute);
      if MatchText(LToken, ['create', 'alter', 'drop', 'truncate']) then
        Exit(fskDdl);
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
        TRadIAFireDACLocation.Create(AFileName, ALine),
        'Split the statements and review each execution boundary.',
        False
      ));
  except
    Result.Free;
    raise;
  end;
end;

end.
