unit RadIA.Core.FireDAC.Transactions;

interface

uses
  System.Generics.Collections,
  RadIA.Core.FireDAC.Model;

type
  TRadIAFireDACTransactionUsage = class
  private
    FCommitCount: Integer;
    FEarlyExitCount: Integer;
    FFirstLine: Integer;
    FName: string;
    FRollbackCount: Integer;
    FStartCount: Integer;
  public
    constructor Create(const AName: string; const AFirstLine: Integer);
    property CommitCount: Integer read FCommitCount write FCommitCount;
    property EarlyExitCount: Integer read FEarlyExitCount write FEarlyExitCount;
    property FirstLine: Integer read FFirstLine;
    property Name: string read FName;
    property RollbackCount: Integer read FRollbackCount write FRollbackCount;
    property StartCount: Integer read FStartCount write FStartCount;
  end;

  TRadIAFireDACTransactionAnalysis = class
  private
    FFindings: TList<TRadIAFireDACFinding>;
    FUsages: TObjectList<TRadIAFireDACTransactionUsage>;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddFinding(const AFinding: TRadIAFireDACFinding);
    function AddOrGetUsage(
      const AName: string;
      const ALine: Integer
    ): TRadIAFireDACTransactionUsage;
    function ToJson: string;
  end;

  TRadIAFireDACTransactionAnalyzer = class
  private
    procedure AddUsageFindings(
      const AUsage: TRadIAFireDACTransactionUsage;
      const AFileName: string;
      const AResult: TRadIAFireDACTransactionAnalysis
    );
    function SanitizePascal(const AContent: string): string;
  public
    function Analyze(
      const AContent: string;
      const AFileName: string
    ): TRadIAFireDACTransactionAnalysis;
  end;

implementation

uses
  System.JSON,
  System.RegularExpressions,
  System.SysUtils;

type
  TRadIAPascalMaskState = (pmsCode, pmsString, pmsBraceComment, pmsParenComment, pmsLineComment);

constructor TRadIAFireDACTransactionUsage.Create(
  const AName: string;
  const AFirstLine: Integer
);
begin
  inherited Create;
  FName := AName;
  FFirstLine := AFirstLine;
end;

constructor TRadIAFireDACTransactionAnalysis.Create;
begin
  inherited Create;
  FFindings := TList<TRadIAFireDACFinding>.Create;
  FUsages := TObjectList<TRadIAFireDACTransactionUsage>.Create(True);
end;

destructor TRadIAFireDACTransactionAnalysis.Destroy;
begin
  FUsages.Free;
  FFindings.Free;
  inherited;
end;

procedure TRadIAFireDACTransactionAnalysis.AddFinding(
  const AFinding: TRadIAFireDACFinding
);
begin
  if FFindings.Count < CRadIAFireDACMaximumFindings then
    FFindings.Add(AFinding);
end;

function TRadIAFireDACTransactionAnalysis.AddOrGetUsage(
  const AName: string;
  const ALine: Integer
): TRadIAFireDACTransactionUsage;
var
  LUsage: TRadIAFireDACTransactionUsage;
begin
  for LUsage in FUsages do
    if SameText(LUsage.Name, AName) then
      Exit(LUsage);
  Result := TRadIAFireDACTransactionUsage.Create(AName, ALine);
  FUsages.Add(Result);
end;

function TransactionFindingJson(const AFinding: TRadIAFireDACFinding): TJSONObject;
var
  LEvidence: TJSONArray;
begin
  Result := TJSONObject.Create;
  Result.AddPair('id', AFinding.Id);
  Result.AddPair('ruleId', AFinding.RuleId);
  Result.AddPair('severity', RadIAFireDACSeverityName(AFinding.Severity));
  Result.AddPair('confidence', RadIAFireDACConfidenceName(AFinding.Confidence));
  Result.AddPair('title', AFinding.Title);
  Result.AddPair('message', AFinding.Message);
  Result.AddPair('file', AFinding.Location.FileName);
  Result.AddPair('line', TJSONNumber.Create(AFinding.Location.Line));
  Result.AddPair('symbol', AFinding.Symbol);
  LEvidence := TJSONArray.Create;
  if not AFinding.Evidence.IsEmpty then
    LEvidence.Add(AFinding.Evidence);
  Result.AddPair('evidence', LEvidence);
  Result.AddPair('suggestedAction', AFinding.SuggestedAction);
  Result.AddPair('automaticFixAvailable', TJSONBool.Create(AFinding.AutomaticFixAvailable));
end;

function TRadIAFireDACTransactionAnalysis.ToJson: string;
var
  LArray: TJSONArray;
  LFinding: TRadIAFireDACFinding;
  LObject: TJSONObject;
  LRoot: TJSONObject;
  LUsage: TRadIAFireDACTransactionUsage;
begin
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    for LUsage in FUsages do
    begin
      LObject := TJSONObject.Create;
      LObject.AddPair('name', LUsage.Name);
      LObject.AddPair('firstLine', TJSONNumber.Create(LUsage.FirstLine));
      LObject.AddPair('startCount', TJSONNumber.Create(LUsage.StartCount));
      LObject.AddPair('commitCount', TJSONNumber.Create(LUsage.CommitCount));
      LObject.AddPair('rollbackCount', TJSONNumber.Create(LUsage.RollbackCount));
      LObject.AddPair('earlyExitCount', TJSONNumber.Create(LUsage.EarlyExitCount));
      LArray.AddElement(LObject);
    end;
    LRoot.AddPair('transactions', LArray);
    LArray := TJSONArray.Create;
    for LFinding in FFindings do
      LArray.AddElement(TransactionFindingJson(LFinding));
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACTransactionAnalyzer.SanitizePascal(const AContent: string): string;
var
  I: Integer;
  LChars: TArray<Char>;
  LState: TRadIAPascalMaskState;
begin
  LChars := AContent.ToCharArray;
  LState := pmsCode;
  I := Low(LChars);
  while I <= High(LChars) do
  begin
    case LState of
      pmsCode:
        if LChars[I] = '''' then
          LState := pmsString
        else if LChars[I] = '{' then
          LState := pmsBraceComment
        else if (LChars[I] = '(') and (I < High(LChars)) and (LChars[I + 1] = '*') then
          LState := pmsParenComment
        else if (LChars[I] = '/') and (I < High(LChars)) and (LChars[I + 1] = '/') then
          LState := pmsLineComment;
      pmsString:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if (AContent.Chars[I] = '''') and (I < High(LChars)) and (AContent.Chars[I + 1] = '''') then
          begin
            Inc(I);
            LChars[I] := ' ';
          end
          else if AContent.Chars[I] = '''' then
            LState := pmsCode;
        end;
      pmsBraceComment:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if AContent.Chars[I] = '}' then
            LState := pmsCode;
        end;
      pmsParenComment:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if (AContent.Chars[I] = '*') and (I < High(LChars)) and (AContent.Chars[I + 1] = ')') then
          begin
            Inc(I);
            LChars[I] := ' ';
            LState := pmsCode;
          end;
        end;
      pmsLineComment:
        begin
          if not CharInSet(LChars[I], [#10, #13]) then
            LChars[I] := ' ';
          if CharInSet(AContent.Chars[I], [#10, #13]) then
            LState := pmsCode;
        end;
    end;
    Inc(I);
  end;
  Result := string.Create(LChars);
end;

procedure TRadIAFireDACTransactionAnalyzer.AddUsageFindings(
  const AUsage: TRadIAFireDACTransactionUsage;
  const AFileName: string;
  const AResult: TRadIAFireDACTransactionAnalysis
);
var
  LLocation: TRadIAFireDACLocation;
begin
  LLocation := TRadIAFireDACLocation.Create(AFileName, AUsage.FirstLine);
  if (AUsage.StartCount > 0) and (AUsage.CommitCount = 0) then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.transaction.commit-missing',
      ffsHigh,
      ffcStrong,
      'Transaction has no visible commit',
      'A transaction starts without a visible commit in the analyzed source.',
      TRadIAFireDACFindingDetails.Create(
        LLocation,
        AUsage.Name,
        'StartTransaction is present and no matching Commit call was found.',
        'Verify all successful paths and add an explicit commit where required.',
        False
      )
    ));
  if (AUsage.StartCount > 0) and (AUsage.RollbackCount = 0) then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.transaction.rollback-missing',
      ffsHigh,
      ffcStrong,
      'Transaction has no visible rollback',
      'A transaction starts without a visible rollback in the analyzed source.',
      TRadIAFireDACFindingDetails.Create(
        LLocation,
        AUsage.Name,
        'StartTransaction is present and no matching Rollback call was found.',
        'Protect the transaction with exception-safe rollback handling.',
        False
      )
    ));
  if AUsage.EarlyExitCount > 0 then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.transaction.early-exit',
      ffsHigh,
      ffcPossible,
      'Early exit may bypass transaction completion',
      'An exit occurs after a transaction start in the analyzed source.',
      TRadIAFireDACFindingDetails.Create(
        LLocation,
        AUsage.Name,
        'Exit appears after StartTransaction; path-sensitive confirmation is required.',
        'Review the exit path and guarantee commit or rollback in a finally-safe flow.',
        False
      )
    ));
end;

function TRadIAFireDACTransactionAnalyzer.Analyze(
  const AContent: string;
  const AFileName: string
): TRadIAFireDACTransactionAnalysis;
var
  LActive: TList<TRadIAFireDACTransactionUsage>;
  LLine: string;
  LLineNumber: Integer;
  LMatch: TMatch;
  LSanitized: string;
  LUsage: TRadIAFireDACTransactionUsage;
begin
  LActive := TList<TRadIAFireDACTransactionUsage>.Create;
  try
    Result := TRadIAFireDACTransactionAnalysis.Create;
    try
      LSanitized := SanitizePascal(AContent);
      LLineNumber := 0;
      for LLine in LSanitized.Split([sLineBreak]) do
      begin
        Inc(LLineNumber);
        LMatch := TRegEx.Match(
          LLine,
          '(?i)\b([A-Za-z_][A-Za-z0-9_.]*)\.(StartTransaction|Commit|Rollback)\b'
        );
        while LMatch.Success do
        begin
          LUsage := Result.AddOrGetUsage(LMatch.Groups[1].Value, LLineNumber);
          if SameText(LMatch.Groups[2].Value, 'StartTransaction') then
          begin
            LUsage.StartCount := LUsage.StartCount + 1;
            if not LActive.Contains(LUsage) then
              LActive.Add(LUsage);
          end
          else if SameText(LMatch.Groups[2].Value, 'Commit') then
          begin
            LUsage.CommitCount := LUsage.CommitCount + 1;
            LActive.Remove(LUsage);
          end
          else
          begin
            LUsage.RollbackCount := LUsage.RollbackCount + 1;
            LActive.Remove(LUsage);
          end;
          LMatch := LMatch.NextMatch;
        end;
        if TRegEx.IsMatch(LLine, '(?i)\bExit\s*(?:\([^)]*\))?\s*;') then
          for LUsage in LActive do
            LUsage.EarlyExitCount := LUsage.EarlyExitCount + 1;
      end;
      for LUsage in Result.FUsages do
        AddUsageFindings(LUsage, AFileName, Result);
    except
      Result.Free;
      raise;
    end;
  finally
    LActive.Free;
  end;
end;

end.
