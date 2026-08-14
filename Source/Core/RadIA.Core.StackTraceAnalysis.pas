unit RadIA.Core.StackTraceAnalysis;

interface

uses
  RadIA.Core.SemanticQueries,
  RadIA.Core.Workspace;

type
  TRadIAStackTraceFrame = record
  private
    FConfidence: string;
    FFileName: string;
    FLine: Integer;
    FMethodName: string;
    FRawText: string;
    FResolved: Boolean;
  public
    constructor Create(
      const ARawText: string;
      const AFileName: string;
      const AMethodName: string;
      const ALine: Integer;
      const AResolved: Boolean;
      const AConfidence: string
    );
    property Confidence: string read FConfidence;
    property FileName: string read FFileName;
    property Line: Integer read FLine;
    property MethodName: string read FMethodName;
    property RawText: string read FRawText;
    property Resolved: Boolean read FResolved;
  end;

  TRadIAStackTraceAnalysis = record
  private
    FDetectedFormat: string;
    FFrames: TArray<TRadIAStackTraceFrame>;
  public
    constructor Create(
      const ADetectedFormat: string;
      const AFrames: TArray<TRadIAStackTraceFrame>
    );
    property DetectedFormat: string read FDetectedFormat;
    property Frames: TArray<TRadIAStackTraceFrame> read FFrames;
  end;

  IRadIAStackTraceAnalysisService = interface
    ['{4CE3C00D-FD86-4EE7-BA30-E0A81E98EB5E}']
    function Analyze(
      const AText: string;
      const AMaxFrames: Integer
    ): TRadIAStackTraceAnalysis;
  end;

  TRadIAStackTraceAnalysisService = class(
    TInterfacedObject,
    IRadIAStackTraceAnalysisService
  )
  private
    FQueries: IRadIASemanticQueryService;
    FWorkspace: IRadIAWorkspaceFacade;
    function DetectFormat(const AText: string): string;
    function FindProjectUnit(
      const AReportedFile: string;
      const AProjectUnits: TArray<string>
    ): string;
    function ResolveByMethod(const AMethodName: string): string;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AQueries: IRadIASemanticQueryService
    );
    function Analyze(
      const AText: string;
      const AMaxFrames: Integer
    ): TRadIAStackTraceAnalysis;
  end;

implementation

uses
  System.Classes,
  System.Generics.Collections,
  System.IOUtils,
  System.Math,
  System.RegularExpressions,
  System.SysUtils;

const
  CMaximumStackTraceCharacters = 524288;
  CMaximumStackTraceFrames = 500;

constructor TRadIAStackTraceFrame.Create(
  const ARawText: string;
  const AFileName: string;
  const AMethodName: string;
  const ALine: Integer;
  const AResolved: Boolean;
  const AConfidence: string
);
begin
  FRawText := ARawText;
  FFileName := AFileName;
  FMethodName := AMethodName;
  FLine := ALine;
  FResolved := AResolved;
  FConfidence := AConfidence;
end;

constructor TRadIAStackTraceAnalysis.Create(
  const ADetectedFormat: string;
  const AFrames: TArray<TRadIAStackTraceFrame>
);
begin
  FDetectedFormat := ADetectedFormat;
  FFrames := Copy(AFrames);
end;

constructor TRadIAStackTraceAnalysisService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AQueries: IRadIASemanticQueryService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(AQueries) then
    raise EArgumentNilException.Create('AQueries');
  FWorkspace := AWorkspace;
  FQueries := AQueries;
end;

function TRadIAStackTraceAnalysisService.Analyze(
  const AText: string;
  const AMaxFrames: Integer
): TRadIAStackTraceAnalysis;
var
  LConfidence: string;
  LFileName: string;
  LFrames: TList<TRadIAStackTraceFrame>;
  LLimit: Integer;
  LLine: string;
  LLineNumber: Integer;
  LLines: TStringList;
  LMatch: TMatch;
  LMethodName: string;
  LProjectUnits: TArray<string>;
  LResolvedFile: string;
begin
  if Length(AText) > CMaximumStackTraceCharacters then
    raise EArgumentOutOfRangeException.Create('Stack trace exceeds 512 KiB.');
  LLimit := EnsureRange(AMaxFrames, 1, CMaximumStackTraceFrames);
  LProjectUnits := FWorkspace.ListProjectUnits;
  LFrames := TList<TRadIAStackTraceFrame>.Create;
  LLines := TStringList.Create;
  try
    LLines.Text := AText;
    for LLine in LLines do
    begin
      LMatch := TRegEx.Match(
        LLine,
        '([A-Za-z0-9_.-]+\.pas)\s*(?:\(|:|\.)\s*(\d+)\)?(?:\s+([^\s+]+))?',
        [roIgnoreCase]
      );
      if not LMatch.Success then
        Continue;
      LFileName := LMatch.Groups[1].Value;
      LLineNumber := StrToIntDef(LMatch.Groups[2].Value, 0);
      LMethodName := Trim(LMatch.Groups[3].Value);
      LResolvedFile := FindProjectUnit(LFileName, LProjectUnits);
      if (LResolvedFile = '') and (LMethodName <> '') then
        LResolvedFile := ResolveByMethod(LMethodName);
      if LResolvedFile = '' then
        LConfidence := 'low'
      else if (LLineNumber > 0) and (LMethodName <> '') then
        LConfidence := 'high'
      else
        LConfidence := 'medium';
      LFrames.Add(TRadIAStackTraceFrame.Create(
        Trim(LLine),
        LResolvedFile,
        LMethodName,
        LLineNumber,
        LResolvedFile <> '',
        LConfidence
      ));
      if LFrames.Count >= LLimit then
        Break;
    end;
    Result := TRadIAStackTraceAnalysis.Create(DetectFormat(AText), LFrames.ToArray);
  finally
    LLines.Free;
    LFrames.Free;
  end;
end;

function TRadIAStackTraceAnalysisService.DetectFormat(const AText: string): string;
begin
  if AText.Contains('madExcept') or TRegEx.IsMatch(AText, '\[[0-9A-F]{8}\]', [roIgnoreCase]) then
    Exit('madexcept');
  if AText.Contains('EurekaLog') or AText.Contains('Exception Thread') then
    Exit('eurekalog');
  Result := 'delphi';
end;

function TRadIAStackTraceAnalysisService.FindProjectUnit(
  const AReportedFile: string;
  const AProjectUnits: TArray<string>
): string;
var
  LUnit: string;
begin
  Result := '';
  for LUnit in AProjectUnits do
    if SameText(TPath.GetFileName(LUnit), TPath.GetFileName(AReportedFile)) then
      Exit(LUnit);
end;

function TRadIAStackTraceAnalysisService.ResolveByMethod(
  const AMethodName: string
): string;
var
  LError: string;
  LName: string;
  LPosition: Integer;
  LSymbols: TArray<TRadIASemanticLocation>;
begin
  Result := '';
  LName := AMethodName;
  LPosition := LName.LastIndexOf('.');
  if LPosition >= 0 then
    LName := LName.Substring(LPosition + 1);
  if FQueries.FindSymbols(LName, LSymbols, LError) and (Length(LSymbols) = 1) then
    Result := LSymbols[0].FileName;
end;

end.
