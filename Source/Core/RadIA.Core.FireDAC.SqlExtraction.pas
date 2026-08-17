unit RadIA.Core.FireDAC.SqlExtraction;

interface

uses
  System.Generics.Collections,
  RadIA.Core.FireDAC.Model;

const
  CRadIAFireDACMaximumExtractedSql = 512;

type
  TRadIAFireDACSqlSource = record
  private
    FComponentName: string;
    FDynamic: Boolean;
    FKind: string;
    FLocation: TRadIAFireDACLocation;
    FSql: string;
  public
    constructor Create(
      const AComponentName: string;
      const AKind: string;
      const ASql: string;
      const ALocation: TRadIAFireDACLocation;
      const ADynamic: Boolean
    );
    property ComponentName: string read FComponentName;
    property Dynamic: Boolean read FDynamic;
    property Kind: string read FKind;
    property Location: TRadIAFireDACLocation read FLocation;
    property Sql: string read FSql;
  end;

  TRadIAFireDACSqlExtraction = class
  private
    FFindings: TList<TRadIAFireDACFinding>;
    FSources: TList<TRadIAFireDACSqlSource>;
    FTruncated: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFinding(const AFinding: TRadIAFireDACFinding);
    procedure AddSource(const ASource: TRadIAFireDACSqlSource);
    function Findings: TArray<TRadIAFireDACFinding>;
    function Sources: TArray<TRadIAFireDACSqlSource>;
    function ToJson: string;
    property Truncated: Boolean read FTruncated write FTruncated;
  end;

  TRadIAFireDACSqlExtractor = class
  private
    function CollectConstants(
      const AContent: string;
      const AMaskedContent: string
    ): TDictionary<string, string>;
    function DecodeLiteralExpression(
      const AExpression: string;
      const AConstants: TDictionary<string, string>;
      out ASql: string
    ): Boolean;
    function LineAt(const AContent: string; const AIndex: Integer): Integer;
    procedure ExtractMatches(
      const AContent: string;
      const AMatchContent: string;
      const AFileName: string;
      const APattern: string;
      const AKind: string;
      const AConstants: TDictionary<string, string>;
      const AResult: TRadIAFireDACSqlExtraction
    );
  public
    function ExtractDfm(
      const AContent: string;
      const AFileName: string
    ): TRadIAFireDACSqlExtraction;
    function ExtractPascal(
      const AContent: string;
      const AFileName: string
    ): TRadIAFireDACSqlExtraction;
  end;

implementation

uses
  System.JSON,
  System.RegularExpressions,
  System.SysUtils,
  RadIA.Core.FireDAC.PascalMask,
  RadIA.Core.FireDAC.SqlAnalyzer;

constructor TRadIAFireDACSqlSource.Create(
  const AComponentName: string;
  const AKind: string;
  const ASql: string;
  const ALocation: TRadIAFireDACLocation;
  const ADynamic: Boolean
);
begin
  FComponentName := AComponentName;
  FKind := AKind;
  FSql := ASql;
  FLocation := ALocation;
  FDynamic := ADynamic;
end;

constructor TRadIAFireDACSqlExtraction.Create;
begin
  inherited Create;
  FSources := TList<TRadIAFireDACSqlSource>.Create;
  FFindings := TList<TRadIAFireDACFinding>.Create;
end;

destructor TRadIAFireDACSqlExtraction.Destroy;
begin
  FFindings.Free;
  FSources.Free;
  inherited;
end;

procedure TRadIAFireDACSqlExtraction.AddFinding(const AFinding: TRadIAFireDACFinding);
begin
  if FFindings.Count >= CRadIAFireDACMaximumFindings then
  begin
    FTruncated := True;
    Exit;
  end;
  FFindings.Add(AFinding);
end;

procedure TRadIAFireDACSqlExtraction.AddSource(const ASource: TRadIAFireDACSqlSource);
begin
  if FSources.Count >= CRadIAFireDACMaximumExtractedSql then
  begin
    FTruncated := True;
    Exit;
  end;
  FSources.Add(ASource);
end;

function TRadIAFireDACSqlExtraction.Sources: TArray<TRadIAFireDACSqlSource>;
begin
  Result := FSources.ToArray;
end;

function TRadIAFireDACSqlExtraction.Findings: TArray<TRadIAFireDACFinding>;
begin
  Result := FFindings.ToArray;
end;

function TRadIAFireDACSqlExtraction.ToJson: string;
var
  LAnalysis: TRadIAFireDACSqlAnalysis;
  LAnalyzer: TRadIAFireDACSqlAnalyzer;
  LArray: TJSONArray;
  LFinding: TRadIAFireDACFinding;
  LObject: TJSONObject;
  LRoot: TJSONObject;
  LSource: TRadIAFireDACSqlSource;
begin
  LRoot := TJSONObject.Create;
  LAnalyzer := TRadIAFireDACSqlAnalyzer.Create;
  try
    LRoot.AddPair('truncated', TJSONBool.Create(FTruncated));
    LArray := TJSONArray.Create;
    for LSource in FSources do
    begin
      LObject := TJSONObject.Create;
      LObject.AddPair('component', LSource.ComponentName);
      LObject.AddPair('kind', LSource.Kind);
      LObject.AddPair('file', LSource.Location.FileName);
      LObject.AddPair('line', TJSONNumber.Create(LSource.Location.Line));
      LObject.AddPair('dynamic', TJSONBool.Create(LSource.Dynamic));
      if not LSource.Dynamic then
      begin
        LAnalysis := LAnalyzer.Analyze(LSource.Sql, LSource.Location.FileName, LSource.Location.Line);
        try
          LObject.AddPair('analysis', TJSONObject.ParseJSONValue(LAnalysis.ToJson));
        finally
          LAnalysis.Free;
        end;
      end;
      LArray.AddElement(LObject);
    end;
    LRoot.AddPair('sources', LArray);
    LArray := TJSONArray.Create;
    for LFinding in FFindings do
      LArray.AddElement(RadIAFireDACFindingToJson(LFinding));
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LAnalyzer.Free;
    LRoot.Free;
  end;
end;

function TRadIAFireDACSqlExtractor.LineAt(const AContent: string; const AIndex: Integer): Integer;
var
  I: Integer;
begin
  Result := 1;
  for I := 0 to AIndex - 1 do
    if AContent.Chars[I] = #10 then
      Inc(Result);
end;

function TRadIAFireDACSqlExtractor.DecodeLiteralExpression(
  const AExpression: string;
  const AConstants: TDictionary<string, string>;
  out ASql: string
): Boolean;
var
  LMatch: TMatch;
  LRemaining: string;
begin
  ASql := '';
  if AConstants.TryGetValue(AExpression.Trim, ASql) then
    Exit(True);
  LMatch := TRegEx.Match(AExpression, '''((?:''''|[^''])*)''');
  while LMatch.Success do
  begin
    ASql := ASql + LMatch.Groups[1].Value.Replace('''''', '''');
    LMatch := LMatch.NextMatch;
  end;
  LRemaining := TRegEx.Replace(AExpression, '''(?:''''|[^''])*''', '');
  LRemaining := TRegEx.Replace(LRemaining, '(?i)\bsLineBreak\b|#13|#10|\+|\s', '');
  Result := not ASql.IsEmpty and LRemaining.IsEmpty;
end;

function TRadIAFireDACSqlExtractor.CollectConstants(
  const AContent: string;
  const AMaskedContent: string
): TDictionary<string, string>;
var
  LExpression: string;
  LMatch: TMatch;
  LName: string;
  LValue: string;
begin
  Result := TDictionary<string, string>.Create;
  LMatch := TRegEx.Match(
    AContent,
    '(?im)^\s*(?:const\s+)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*' +
    '((?:''(?:''''|[^''])*''|[^;])*)'
  );
  while LMatch.Success do
  begin
    if (LMatch.Groups[1].Index < AMaskedContent.Length) and
      (AMaskedContent.Chars[LMatch.Groups[1].Index] = ' ') then
    begin
      LMatch := LMatch.NextMatch;
      Continue;
    end;
    LName := LMatch.Groups[1].Value;
    LExpression := LMatch.Groups[2].Value;
    if DecodeLiteralExpression(LExpression, Result, LValue) and not Result.ContainsKey(LName) then
      Result.Add(LName, LValue);
    LMatch := LMatch.NextMatch;
  end;
end;

procedure TRadIAFireDACSqlExtractor.ExtractMatches(
  const AContent: string;
  const AMatchContent: string;
  const AFileName: string;
  const APattern: string;
  const AKind: string;
  const AConstants: TDictionary<string, string>;
  const AResult: TRadIAFireDACSqlExtraction
);
var
  LDynamic: Boolean;
  LMatch: TMatch;
  LSql: string;
begin
  LMatch := TRegEx.Match(AContent, APattern);
  while LMatch.Success do
  begin
    if (LMatch.Groups[1].Index < AMatchContent.Length) and
      (AMatchContent.Chars[LMatch.Groups[1].Index] = ' ') then
    begin
      LMatch := LMatch.NextMatch;
      Continue;
    end;
    LDynamic := not DecodeLiteralExpression(LMatch.Groups[2].Value, AConstants, LSql);
    AResult.AddSource(TRadIAFireDACSqlSource.Create(
      LMatch.Groups[1].Value,
      AKind,
      LSql,
      TRadIAFireDACLocation.Create(AFileName, LineAt(AContent, LMatch.Index)),
      LDynamic
    ));
    if LDynamic then
      AResult.AddFinding(TRadIAFireDACFinding.Create(
        'firedac.sql.dynamic-source',
        ffsInfo,
        ffcInformational,
        'SQL source requires runtime resolution',
        'The SQL expression contains values that cannot be resolved safely during static analysis.',
        TRadIAFireDACFindingDetails.Create(
          TRadIAFireDACLocation.Create(AFileName, LineAt(AContent, LMatch.Index)),
          LMatch.Groups[1].Value,
          AKind + ' contains a non-literal expression.',
          'Review the SQL construction or replace it with a safely resolvable constant.',
          False
        )
      ));
    LMatch := LMatch.NextMatch;
  end;
end;

function TRadIAFireDACSqlExtractor.ExtractPascal(
  const AContent: string;
  const AFileName: string
): TRadIAFireDACSqlExtraction;
var
  LConstants: TDictionary<string, string>;
  LMasked: string;
begin
  Result := TRadIAFireDACSqlExtraction.Create;
  LMasked := RadIAMaskPascalNonCode(AContent);
  LConstants := CollectConstants(AContent, LMasked);
  try
    try
      ExtractMatches(
        AContent, LMasked, AFileName,
        '(?is)\b([A-Za-z_][A-Za-z0-9_]*)\.SQL\.Text\s*:=\s*' +
        '((?:''(?:''''|[^''])*''|[^;])*)\s*;',
        'sql-text', LConstants, Result
      );
      ExtractMatches(
        AContent, LMasked, AFileName,
        '(?is)\b([A-Za-z_][A-Za-z0-9_]*)\.SQL\.Add\s*\(\s*(.*?)\s*\)\s*;',
        'sql-add', LConstants, Result
      );
    except
      Result.Free;
      raise;
    end;
  finally
    LConstants.Free;
  end;
end;

function TRadIAFireDACSqlExtractor.ExtractDfm(
  const AContent: string;
  const AFileName: string
): TRadIAFireDACSqlExtraction;
var
  LConstants: TDictionary<string, string>;
begin
  Result := TRadIAFireDACSqlExtraction.Create;
  LConstants := TDictionary<string, string>.Create;
  try
    try
      ExtractMatches(
        AContent, AContent, AFileName,
        '(?is)object\s+([A-Za-z_][A-Za-z0-9_]*)\s*:\s*TFD(?:Query|Command).*?' +
        '\bSQL\.Strings\s*=\s*\((.*?)\)',
        'dfm-sql-strings', LConstants, Result
      );
    except
      Result.Free;
      raise;
    end;
  finally
    LConstants.Free;
  end;
end;

end.
