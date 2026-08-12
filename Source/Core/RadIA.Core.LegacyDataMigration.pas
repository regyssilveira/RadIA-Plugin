unit RadIA.Core.LegacyDataMigration;

interface

type
  TRadIALegacyDataTechnology = (ldtBDE, ldtADO, ldtDbExpress);
  TRadIALegacyMigrationRisk = (lmrLow, lmrMedium, lmrHigh);

  TRadIALegacySourceFile = record
  private
    FFileName: string;
    FRevision: string;
    FContent: string;
  public
    constructor Create(
      const AFileName: string;
      const ARevision: string;
      const AContent: string
    );
    property FileName: string read FFileName;
    property Revision: string read FRevision;
    property Content: string read FContent;
  end;

  TRadIALegacyMigrationFinding = record
  private
    FTechnology: TRadIALegacyDataTechnology;
    FRisk: TRadIALegacyMigrationRisk;
    FFileName: string;
    FLine: Integer;
    FSymbol: string;
    FReplacement: string;
    FManualAction: string;
    function GetCanPrepare: Boolean;
  public
    constructor Create(
      const ATechnology: TRadIALegacyDataTechnology;
      const ARisk: TRadIALegacyMigrationRisk;
      const AFileName: string;
      const ALine: Integer;
      const ASymbol: string;
      const AReplacement: string;
      const AManualAction: string
    );
    property Technology: TRadIALegacyDataTechnology read FTechnology;
    property Risk: TRadIALegacyMigrationRisk read FRisk;
    property FileName: string read FFileName;
    property Line: Integer read FLine;
    property Symbol: string read FSymbol;
    property Replacement: string read FReplacement;
    property ManualAction: string read FManualAction;
    property CanPrepare: Boolean read GetCanPrepare;
  end;

  TRadIALegacyMigrationBatch = record
  private
    FId: string;
    FTechnology: TRadIALegacyDataTechnology;
    FFileName: string;
    FFindingCount: Integer;
    FCanPrepare: Boolean;
  public
    constructor Create(
      const AId: string;
      const ATechnology: TRadIALegacyDataTechnology;
      const AFileName: string;
      const AFindingCount: Integer;
      const ACanPrepare: Boolean
    );
    property Id: string read FId;
    property Technology: TRadIALegacyDataTechnology read FTechnology;
    property FileName: string read FFileName;
    property FindingCount: Integer read FFindingCount;
    property CanPrepare: Boolean read FCanPrepare;
  end;

  TRadIALegacyDataMigrationAnalyzer = class
  private
    class function ContainsSymbol(
      const ALine: string;
      const ASymbol: string
    ): Boolean; static;
    class procedure InspectLine(
      const AFileName: string;
      const ALine: string;
      const ALineNumber: Integer;
      const AFindings: TArray<TRadIALegacyMigrationFinding>;
      var ACount: Integer
    ); static;
  public
    class function Inventory(
      const AFiles: TArray<TRadIALegacySourceFile>
    ): TArray<TRadIALegacyMigrationFinding>; static;
    class function PlanBatches(
      const AFindings: TArray<TRadIALegacyMigrationFinding>
    ): TArray<TRadIALegacyMigrationBatch>; static;
    class function PrepareContent(
      const AContent: string;
      const AFindings: TArray<TRadIALegacyMigrationFinding>;
      const AFileName: string;
      const ATechnology: TRadIALegacyDataTechnology
    ): string; static;
    class function TechnologyName(
      const ATechnology: TRadIALegacyDataTechnology
    ): string; static;
    class function RiskName(
      const ARisk: TRadIALegacyMigrationRisk
    ): string; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.Math,
  System.RegularExpressions,
  System.SysUtils;

const
  CMaxFiles = 500;
  CMaxFileCharacters = 2 * 1024 * 1024;
  CMaxFindings = 2000;

type
  TRadIALegacyPattern = record
    Technology: TRadIALegacyDataTechnology;
    Risk: TRadIALegacyMigrationRisk;
    Symbol: string;
    Replacement: string;
    ManualAction: string;
  end;

const
  CPatterns: array[0..16] of TRadIALegacyPattern = (
    (Technology: ldtBDE; Risk: lmrLow; Symbol: 'DBTables';
      Replacement: 'FireDAC.Comp.Client'; ManualAction: 'Review the resulting uses clause.'),
    (Technology: ldtBDE; Risk: lmrHigh; Symbol: 'TDatabase';
      Replacement: 'TFDConnection'; ManualAction: 'Map aliases, driver and transaction parameters.'),
    (Technology: ldtBDE; Risk: lmrMedium; Symbol: 'TQuery';
      Replacement: 'TFDQuery'; ManualAction: 'Review SQL, parameters and update behavior.'),
    (Technology: ldtBDE; Risk: lmrMedium; Symbol: 'TTable';
      Replacement: 'TFDTable'; ManualAction: 'Review index and range semantics.'),
    (Technology: ldtBDE; Risk: lmrMedium; Symbol: 'TStoredProc';
      Replacement: 'TFDStoredProc'; ManualAction: 'Review parameter metadata.'),
    (Technology: ldtADO; Risk: lmrLow; Symbol: 'Data.Win.ADODB';
      Replacement: 'FireDAC.Comp.Client'; ManualAction: 'Review the resulting uses clause.'),
    (Technology: ldtADO; Risk: lmrLow; Symbol: 'ADODB';
      Replacement: 'FireDAC.Comp.Client'; ManualAction: 'Review the resulting uses clause.'),
    (Technology: ldtADO; Risk: lmrHigh; Symbol: 'TADOConnection';
      Replacement: 'TFDConnection';
      ManualAction: 'Map provider, connection string and transactions.'),
    (Technology: ldtADO; Risk: lmrMedium; Symbol: 'TADOQuery';
      Replacement: 'TFDQuery'; ManualAction: 'Review SQL, parameters and cursor behavior.'),
    (Technology: ldtADO; Risk: lmrMedium; Symbol: 'TADOTable';
      Replacement: 'TFDTable'; ManualAction: 'Review index and filtering semantics.'),
    (Technology: ldtADO; Risk: lmrMedium; Symbol: 'TADOStoredProc';
      Replacement: 'TFDStoredProc'; ManualAction: 'Review parameter metadata.'),
    (Technology: ldtDbExpress; Risk: lmrLow; Symbol: 'Data.SqlExpr';
      Replacement: 'FireDAC.Comp.Client'; ManualAction: 'Review the resulting uses clause.'),
    (Technology: ldtDbExpress; Risk: lmrLow; Symbol: 'SqlExpr';
      Replacement: 'FireDAC.Comp.Client'; ManualAction: 'Review the resulting uses clause.'),
    (Technology: ldtDbExpress; Risk: lmrHigh; Symbol: 'TSQLConnection';
      Replacement: 'TFDConnection'; ManualAction: 'Map driver, library and transaction parameters.'),
    (Technology: ldtDbExpress; Risk: lmrMedium; Symbol: 'TSQLQuery';
      Replacement: 'TFDQuery'; ManualAction: 'Review SQL and parameter binding.'),
    (Technology: ldtDbExpress; Risk: lmrMedium; Symbol: 'TSQLDataSet';
      Replacement: 'TFDQuery'; ManualAction: 'Review provider and update behavior.'),
    (Technology: ldtDbExpress; Risk: lmrMedium; Symbol: 'TSQLStoredProc';
      Replacement: 'TFDStoredProc'; ManualAction: 'Review parameter metadata.')
  );

constructor TRadIALegacySourceFile.Create(
  const AFileName: string;
  const ARevision: string;
  const AContent: string
);
begin
  FFileName := AFileName;
  FRevision := ARevision;
  FContent := AContent;
end;

constructor TRadIALegacyMigrationFinding.Create(
  const ATechnology: TRadIALegacyDataTechnology;
  const ARisk: TRadIALegacyMigrationRisk;
  const AFileName: string;
  const ALine: Integer;
  const ASymbol: string;
  const AReplacement: string;
  const AManualAction: string
);
begin
  FTechnology := ATechnology;
  FRisk := ARisk;
  FFileName := AFileName;
  FLine := ALine;
  FSymbol := ASymbol;
  FReplacement := AReplacement;
  FManualAction := AManualAction;
end;

function TRadIALegacyMigrationFinding.GetCanPrepare: Boolean;
begin
  Result := FRisk <> lmrHigh;
end;

constructor TRadIALegacyMigrationBatch.Create(
  const AId: string;
  const ATechnology: TRadIALegacyDataTechnology;
  const AFileName: string;
  const AFindingCount: Integer;
  const ACanPrepare: Boolean
);
begin
  FId := AId;
  FTechnology := ATechnology;
  FFileName := AFileName;
  FFindingCount := AFindingCount;
  FCanPrepare := ACanPrepare;
end;

class function TRadIALegacyDataMigrationAnalyzer.ContainsSymbol(
  const ALine: string;
  const ASymbol: string
): Boolean;
begin
  Result := TRegEx.IsMatch(
    ALine,
    '(?i)(?<![A-Za-z0-9_])' + TRegEx.Escape(ASymbol) + '(?![A-Za-z0-9_])'
  );
end;

class procedure TRadIALegacyDataMigrationAnalyzer.InspectLine(
  const AFileName: string;
  const ALine: string;
  const ALineNumber: Integer;
  const AFindings: TArray<TRadIALegacyMigrationFinding>;
  var ACount: Integer
);
var
  LPattern: TRadIALegacyPattern;
begin
  for LPattern in CPatterns do
  begin
    if ACount >= Length(AFindings) then
      Exit;
    if ContainsSymbol(ALine, LPattern.Symbol) then
    begin
      AFindings[ACount] := TRadIALegacyMigrationFinding.Create(
        LPattern.Technology,
        LPattern.Risk,
        AFileName,
        ALineNumber,
        LPattern.Symbol,
        LPattern.Replacement,
        LPattern.ManualAction
      );
      Inc(ACount);
    end;
  end;
end;

class function TRadIALegacyDataMigrationAnalyzer.Inventory(
  const AFiles: TArray<TRadIALegacySourceFile>
): TArray<TRadIALegacyMigrationFinding>;
var
  LCount: Integer;
  LFile: TRadIALegacySourceFile;
  LFileIndex: Integer;
  LLineIndex: Integer;
  LLines: TArray<string>;
begin
  SetLength(Result, CMaxFindings);
  LCount := 0;
  for LFileIndex := 0 to Min(High(AFiles), CMaxFiles - 1) do
  begin
    LFile := AFiles[LFileIndex];
    if Length(LFile.Content) > CMaxFileCharacters then
      Continue;
    LLines := LFile.Content.Replace(#13#10, #10).Replace(#13, #10).Split([#10]);
    for LLineIndex := 0 to High(LLines) do
      InspectLine(LFile.FileName, LLines[LLineIndex], LLineIndex + 1, Result, LCount);
    if LCount >= CMaxFindings then
      Break;
  end;
  SetLength(Result, LCount);
end;

class function TRadIALegacyDataMigrationAnalyzer.PlanBatches(
  const AFindings: TArray<TRadIALegacyMigrationFinding>
): TArray<TRadIALegacyMigrationBatch>;
var
  LCanPrepare: Boolean;
  LBatchCount: Integer;
  LFindingCount: Integer;
  LCount: Integer;
  LFinding: TRadIALegacyMigrationFinding;
  LKey: string;
  LKeys: TList<string>;
  LTechnology: TRadIALegacyDataTechnology;
begin
  LKeys := TList<string>.Create;
  try
    for LFinding in AFindings do
    begin
      LKey := IntToStr(Ord(LFinding.Technology)) + '|' + LFinding.FileName;
      if LKeys.IndexOf(LKey) < 0 then
        LKeys.Add(LKey);
    end;
    LBatchCount := 0;
    for LKey in LKeys do
      Inc(LBatchCount);
    SetLength(Result, LBatchCount);
    for LCount := 0 to LKeys.Count - 1 do
    begin
      LTechnology := TRadIALegacyDataTechnology(StrToInt(LKeys[LCount].Split(['|'])[0]));
      LKey := LKeys[LCount].Substring(LKeys[LCount].IndexOf('|') + 1);
      LCanPrepare := False;
      LFindingCount := 0;
      for LFinding in AFindings do
        if (LFinding.Technology = LTechnology) and SameText(LFinding.FileName, LKey) then
        begin
          LCanPrepare := LCanPrepare or LFinding.CanPrepare;
          Inc(LFindingCount);
        end;
      Result[LCount] := TRadIALegacyMigrationBatch.Create(
        Format('legacy-%d-%d', [Ord(LTechnology), LCount + 1]),
        LTechnology,
        LKey,
        LFindingCount,
        LCanPrepare
      );
    end;
  finally
    LKeys.Free;
  end;
end;

class function TRadIALegacyDataMigrationAnalyzer.PrepareContent(
  const AContent: string;
  const AFindings: TArray<TRadIALegacyMigrationFinding>;
  const AFileName: string;
  const ATechnology: TRadIALegacyDataTechnology
): string;
var
  LFinding: TRadIALegacyMigrationFinding;
begin
  Result := AContent;
  for LFinding in AFindings do
    if LFinding.CanPrepare and (LFinding.Technology = ATechnology) and
      SameText(LFinding.FileName, AFileName) then
      Result := TRegEx.Replace(
        Result,
        '(?i)(?<![A-Za-z0-9_])' + TRegEx.Escape(LFinding.Symbol) + '(?![A-Za-z0-9_])',
        LFinding.Replacement
      );
end;

class function TRadIALegacyDataMigrationAnalyzer.TechnologyName(
  const ATechnology: TRadIALegacyDataTechnology
): string;
begin
  case ATechnology of
    ldtBDE: Result := 'BDE';
    ldtADO: Result := 'ADO';
  else
    Result := 'dbExpress';
  end;
end;

class function TRadIALegacyDataMigrationAnalyzer.RiskName(
  const ARisk: TRadIALegacyMigrationRisk
): string;
begin
  case ARisk of
    lmrLow: Result := 'low';
    lmrMedium: Result := 'medium';
  else
    Result := 'high';
  end;
end;

end.
