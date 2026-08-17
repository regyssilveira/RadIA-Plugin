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
    function Findings: TArray<TRadIAFireDACFinding>;
    function AddOrGetUsage(
      const AName: string;
      const ALine: Integer
    ): TRadIAFireDACTransactionUsage;
    function ToJson: string;
    function UsageCount: Int64;
  end;

  TRadIAFireDACTransactionAnalyzer = class
  private
    procedure AddUsageFindings(
      const AUsage: TRadIAFireDACTransactionUsage;
      const AFileName: string;
      const AResult: TRadIAFireDACTransactionAnalysis
    );
    procedure AnalyzeLine(
      const ALine: string;
      const ALineNumber: Integer;
      const AActive: TList<TRadIAFireDACTransactionUsage>;
      const AResult: TRadIAFireDACTransactionAnalysis
    );
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
  System.SysUtils,
  RadIA.Core.FireDAC.PascalMask;

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
      LArray.AddElement(RadIAFireDACFindingToJson(LFinding));
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACTransactionAnalysis.Findings: TArray<TRadIAFireDACFinding>;
begin
  Result := FFindings.ToArray;
end;

function TRadIAFireDACTransactionAnalysis.UsageCount: Int64;
begin
  Result := FUsages.Count;
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
  LSanitized: string;
  LUsage: TRadIAFireDACTransactionUsage;
begin
  LActive := TList<TRadIAFireDACTransactionUsage>.Create;
  try
    Result := TRadIAFireDACTransactionAnalysis.Create;
    try
      LSanitized := RadIAMaskPascalNonCode(AContent);
      LLineNumber := 0;
      for LLine in LSanitized.Split([sLineBreak]) do
      begin
        Inc(LLineNumber);
        AnalyzeLine(LLine, LLineNumber, LActive, Result);
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

procedure TRadIAFireDACTransactionAnalyzer.AnalyzeLine(
  const ALine: string;
  const ALineNumber: Integer;
  const AActive: TList<TRadIAFireDACTransactionUsage>;
  const AResult: TRadIAFireDACTransactionAnalysis
);
var
  LMatch: TMatch;
  LUsage: TRadIAFireDACTransactionUsage;
begin
  LMatch := TRegEx.Match(
    ALine,
    '(?i)\b([A-Za-z_][A-Za-z0-9_.]*)\.(StartTransaction|Commit|Rollback)\b'
  );
  while LMatch.Success do
  begin
    LUsage := AResult.AddOrGetUsage(LMatch.Groups[1].Value, ALineNumber);
    if SameText(LMatch.Groups[2].Value, 'StartTransaction') then
    begin
      LUsage.StartCount := LUsage.StartCount + 1;
      if not AActive.Contains(LUsage) then
        AActive.Add(LUsage);
    end
    else if SameText(LMatch.Groups[2].Value, 'Commit') then
    begin
      LUsage.CommitCount := LUsage.CommitCount + 1;
      AActive.Remove(LUsage);
    end
    else
    begin
      LUsage.RollbackCount := LUsage.RollbackCount + 1;
      AActive.Remove(LUsage);
    end;
    LMatch := LMatch.NextMatch;
  end;
  if TRegEx.IsMatch(ALine, '(?i)\bExit\s*(?:\([^)]*\))?\s*;') then
    for LUsage in AActive do
      LUsage.EarlyExitCount := LUsage.EarlyExitCount + 1;
end;

end.
