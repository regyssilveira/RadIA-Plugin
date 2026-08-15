unit RadIA.Core.TestImpact;

interface

uses
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIATestImpactPlan = record
  private
    FChangedSymbols: TArray<string>;
    FChangedUnits: TArray<string>;
    FConfidence: string;
    FCoverageAvailable: Boolean;
    FCoverageMatchedUnits: TArray<string>;
    FFullSuite: Boolean;
    FReasons: TArray<string>;
    FSelectedFixtures: TArray<string>;
    FSelectedTestUnits: TArray<string>;
  public
    property ChangedSymbols: TArray<string> read FChangedSymbols;
    property ChangedUnits: TArray<string> read FChangedUnits;
    property Confidence: string read FConfidence;
    property CoverageAvailable: Boolean read FCoverageAvailable;
    property CoverageMatchedUnits: TArray<string> read FCoverageMatchedUnits;
    property FullSuite: Boolean read FFullSuite;
    property Reasons: TArray<string> read FReasons;
    property SelectedFixtures: TArray<string> read FSelectedFixtures;
    property SelectedTestUnits: TArray<string> read FSelectedTestUnits;
  end;

  TRadIATestImpactResult = record
  private
    FErrorCode: string;
    FErrorMessage: string;
    FPlan: TRadIATestImpactPlan;
    FSuccess: Boolean;
  public
    class function Failed(
      const AErrorCode: string;
      const AErrorMessage: string
    ): TRadIATestImpactResult; static;
    class function Succeeded(
      const APlan: TRadIATestImpactPlan
    ): TRadIATestImpactResult; static;
    property ErrorCode: string read FErrorCode;
    property ErrorMessage: string read FErrorMessage;
    property Plan: TRadIATestImpactPlan read FPlan;
    property Success: Boolean read FSuccess;
  end;

  IRadIATestImpactService = interface
    ['{17188149-9077-4771-A45B-D80331F974A6}']
    function Plan(
      const AChangedFiles: TArray<string>;
      const AChangedSymbols: TArray<string>;
      const ACoverageReport: string
    ): TRadIATestImpactResult;
  end;

  TRadIATestImpactService = class(
    TInterfacedObject,
    IRadIATestImpactService
  )
  private
    FBoundary: IRadIAWorkspaceBoundary;
    FWorkspace: IRadIAWorkspaceFacade;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary
    );
    function Plan(
      const AChangedFiles: TArray<string>;
      const AChangedSymbols: TArray<string>;
      const ACoverageReport: string
    ): TRadIATestImpactResult;
  end;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.StrUtils,
  System.SysUtils,
  RadIA.Semantic.Parser;

type
  TRadIAUnitImpactInfo = class
  private
    FDependencies: TArray<string>;
    FFileName: string;
    FFixtures: TArray<string>;
    FModuleName: string;
  public
    constructor Create(
      const AUnitName: string;
      const AFileName: string;
      const ADependencies: TArray<string>;
      const AFixtures: TArray<string>
    );
    property Dependencies: TArray<string> read FDependencies;
    property FileName: string read FFileName;
    property Fixtures: TArray<string> read FFixtures;
    property ModuleName: string read FModuleName;
  end;

const
  CDefaultCoverageReport = 'Output\Coverage\CodeCoverage_Summary.xml';
  CMaximumFiles = 2000;
  CMaximumFileCharacters = 2 * 1024 * 1024;
  CMaximumFilters = 100;

function NormalizeUnitName(const AValue: string): string;
begin
  Result := LowerCase(Trim(AValue));
end;

procedure AddUnique(
  const AList: TList<string>;
  const AValue: string
);
begin
  if not AValue.IsEmpty and not AList.Contains(AValue) then
    AList.Add(AValue);
end;

function IsIgnoredPath(const AFileName: string): Boolean;
var
  LPath: string;
begin
  LPath := LowerCase(StringReplace(AFileName, '/', '\', [rfReplaceAll]));
  Result := ContainsText(LPath, '\.git\') or
    ContainsText(LPath, '\output\') or
    ContainsText(LPath, '\redist\') or
    ContainsText(LPath, '\__history\') or
    ContainsText(LPath, '\node_modules\');
end;

function ExtractFixtures(const ASource: string): TArray<string>;
const
  CMarker = 'RegisterTestFixture(';
var
  LCharacter: Char;
  LFixture: string;
  LFixtures: TList<string>;
  LIndex: Integer;
  LPosition: Integer;
begin
  LFixtures := TList<string>.Create;
  try
    LPosition := 1;
    while True do
    begin
      LPosition := PosEx(CMarker, ASource, LPosition);
      if LPosition = 0 then
        Break;
      Inc(LPosition, Length(CMarker));
      while (LPosition <= Length(ASource)) and
        CharInSet(ASource[LPosition], [#9, #10, #13, ' ']) do
        Inc(LPosition);
      LFixture := '';
      LIndex := LPosition;
      while LIndex <= Length(ASource) do
      begin
        LCharacter := ASource[LIndex];
        if not CharInSet(
          LCharacter,
          ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']
        ) then
          Break;
        LFixture := LFixture + LCharacter;
        Inc(LIndex);
      end;
      AddUnique(LFixtures, LFixture);
      LPosition := LIndex;
    end;
    Result := LFixtures.ToArray;
  finally
    LFixtures.Free;
  end;
end;

function ParseUnitInfo(
  const AFileName: string;
  const ASource: string
): TRadIAUnitImpactInfo;
var
  LDependencies: TList<string>;
  LParseResult: TRadIASemanticParseResult;
  LSymbol: TRadIASemanticSymbol;
  LUnitName: string;
begin
  LDependencies := TList<string>.Create;
  try
    LUnitName := TPath.GetFileNameWithoutExtension(AFileName);
    LParseResult := TRadIASemanticParser.Parse(ASource, nil);
    for LSymbol in LParseResult.Symbols do
      case LSymbol.Kind of
        sskModule:
          LUnitName := LSymbol.Name;
        sskUnitReference:
          AddUnique(LDependencies, NormalizeUnitName(LSymbol.Name));
      end;
    Result := TRadIAUnitImpactInfo.Create(
      LUnitName,
      AFileName,
      LDependencies.ToArray,
      ExtractFixtures(ASource)
    );
  finally
    LDependencies.Free;
  end;
end;

function ReadUnitInfo(const AFileName: string): TRadIAUnitImpactInfo;
var
  LSource: string;
begin
  Result := nil;
  if TFile.GetSize(AFileName) > CMaximumFileCharacters then
    Exit;
  try
    LSource := TFile.ReadAllText(AFileName, TEncoding.UTF8);
    Result := ParseUnitInfo(AFileName, LSource);
  except
    Result.Free;
    Result := nil;
  end;
end;

function BuildUnitMap(
  const ARootPath: string;
  out AExceededLimit: Boolean
): TObjectDictionary<string, TRadIAUnitImpactInfo>;
var
  LFileName: string;
  LFiles: TArray<string>;
  LInfo: TRadIAUnitImpactInfo;
begin
  Result := TObjectDictionary<string, TRadIAUnitImpactInfo>.Create(
    [doOwnsValues]
  );
  AExceededLimit := False;
  LFiles := TDirectory.GetFiles(
    ARootPath,
    '*.pas',
    TSearchOption.soAllDirectories
  );
  if Length(LFiles) > CMaximumFiles then
  begin
    AExceededLimit := True;
    Exit;
  end;
  for LFileName in LFiles do
  begin
    if IsIgnoredPath(LFileName) then
      Continue;
    LInfo := ReadUnitInfo(LFileName);
    if Assigned(LInfo) then
      Result.AddOrSetValue(NormalizeUnitName(LInfo.ModuleName), LInfo);
  end;
end;

function DependsOnChanged(
  const AUnitName: string;
  const AUnits: TObjectDictionary<string, TRadIAUnitImpactInfo>;
  const AChanged: TDictionary<string, Boolean>;
  const AVisited: TDictionary<string, Boolean>
): Boolean;
var
  LDependency: string;
  LInfo: TRadIAUnitImpactInfo;
  LNormalized: string;
begin
  Result := False;
  LNormalized := NormalizeUnitName(AUnitName);
  if AChanged.ContainsKey(LNormalized) then
    Exit(True);
  if AVisited.ContainsKey(LNormalized) then
    Exit;
  AVisited.Add(LNormalized, True);
  if not AUnits.TryGetValue(LNormalized, LInfo) then
    Exit;
  for LDependency in LInfo.Dependencies do
    if DependsOnChanged(LDependency, AUnits, AChanged, AVisited) then
      Exit(True);
end;

function ResolveChangedUnits(
  const AChangedFiles: TArray<string>;
  const AUnits: TObjectDictionary<string, TRadIAUnitImpactInfo>;
  out AHasUnknownChange: Boolean
): TArray<string>;
var
  LChanged: TList<string>;
  LExtension: string;
  LFileName: string;
  LInfo: TRadIAUnitImpactInfo;
  LPair: TPair<string, TRadIAUnitImpactInfo>;
  LUnitName: string;
begin
  LChanged := TList<string>.Create;
  try
    AHasUnknownChange := False;
    for LFileName in AChangedFiles do
    begin
      LExtension := ExtractFileExt(LFileName);
      if not SameText(LExtension, '.pas') and
        not SameText(LExtension, '.dpr') and
        not SameText(LExtension, '.dfm') then
      begin
        AHasUnknownChange := True;
        Continue;
      end;
      LUnitName := TPath.GetFileNameWithoutExtension(LFileName);
      for LPair in AUnits do
        if SameFileName(LPair.Value.FileName, LFileName) then
        begin
          LInfo := LPair.Value;
          LUnitName := LInfo.ModuleName;
          Break;
        end;
      AddUnique(LChanged, NormalizeUnitName(LUnitName));
    end;
    Result := LChanged.ToArray;
  finally
    LChanged.Free;
  end;
end;

function ValidateChangedFiles(
  const ARootPath: string;
  const AChangedFiles: TArray<string>;
  const ABoundary: IRadIAWorkspaceBoundary;
  out AError: TRadIAPathValidation
): TArray<string>;
var
  LChangedFile: string;
  LIndex: Integer;
begin
  Result := nil;
  SetLength(Result, Length(AChangedFiles));
  for LIndex := Low(AChangedFiles) to High(AChangedFiles) do
  begin
    LChangedFile := Trim(AChangedFiles[LIndex]);
    if LChangedFile.IsEmpty then
    begin
      AError := TRadIAPathValidation.Rejected(
        'invalid_changed_file',
        'Changed workspace file names cannot be empty.'
      );
      Exit(nil);
    end;
    AError := ABoundary.ValidatePath(ARootPath, LChangedFile);
    if not AError.Allowed then
      Exit(nil);
    Result[LIndex] := AError.ResolvedPath;
  end;
  AError := TRadIAPathValidation.Accepted(ARootPath);
end;

function ResolveCoveragePath(
  const ARootPath: string;
  const ACoverageReport: string;
  const ABoundary: IRadIAWorkspaceBoundary
): string;
var
  LCandidate: string;
  LValidation: TRadIAPathValidation;
begin
  LCandidate := Trim(ACoverageReport);
  if LCandidate.IsEmpty then
    LCandidate := CDefaultCoverageReport;
  LValidation := ABoundary.ValidatePath(ARootPath, LCandidate);
  if LValidation.Allowed then
    Result := LValidation.ResolvedPath
  else
    Result := '';
end;

function MatchCoverageUnits(
  const ACoveragePath: string;
  const AChangedUnits: TArray<string>;
  out AAvailable: Boolean
): TArray<string>;
var
  LCoverage: string;
  LMatched: TList<string>;
  LUnitName: string;
begin
  AAvailable := not ACoveragePath.IsEmpty and TFile.Exists(ACoveragePath);
  if not AAvailable then
    Exit(nil);
  LMatched := TList<string>.Create;
  try
    LCoverage := TFile.ReadAllText(ACoveragePath, TEncoding.Default);
    for LUnitName in AChangedUnits do
      if ContainsText(
        LCoverage,
        'name="' + LUnitName + '.pas"'
      ) then
        AddUnique(LMatched, LUnitName);
    Result := LMatched.ToArray;
  finally
    LMatched.Free;
  end;
end;

function SelectFixtures(
  const AUnits: TObjectDictionary<string, TRadIAUnitImpactInfo>;
  const AChangedUnits: TArray<string>;
  out ATestUnits: TArray<string>;
  out AReasons: TArray<string>
): TArray<string>;
var
  LChanged: TDictionary<string, Boolean>;
  LFixture: string;
  LFixtures: TList<string>;
  LPair: TPair<string, TRadIAUnitImpactInfo>;
  LReasons: TList<string>;
  LTestUnits: TList<string>;
  LUnitName: string;
  LVisited: TDictionary<string, Boolean>;
begin
  LChanged := TDictionary<string, Boolean>.Create;
  LFixtures := TList<string>.Create;
  LReasons := TList<string>.Create;
  LTestUnits := TList<string>.Create;
  try
    for LUnitName in AChangedUnits do
      LChanged.AddOrSetValue(NormalizeUnitName(LUnitName), True);
    for LPair in AUnits do
    begin
      if Length(LPair.Value.Fixtures) = 0 then
        Continue;
      LVisited := TDictionary<string, Boolean>.Create;
      try
        if not DependsOnChanged(
          LPair.Key,
          AUnits,
          LChanged,
          LVisited
        ) then
          Continue;
      finally
        LVisited.Free;
      end;
      AddUnique(LTestUnits, LPair.Value.ModuleName);
      for LFixture in LPair.Value.Fixtures do
      begin
        AddUnique(LFixtures, LFixture);
        AddUnique(
          LReasons,
          LFixture + ' selected because ' + LPair.Value.ModuleName +
          ' depends on a changed unit.'
        );
      end;
    end;
    ATestUnits := LTestUnits.ToArray;
    AReasons := LReasons.ToArray;
    Result := LFixtures.ToArray;
  finally
    LTestUnits.Free;
    LReasons.Free;
    LFixtures.Free;
    LChanged.Free;
  end;
end;

constructor TRadIAUnitImpactInfo.Create(
  const AUnitName: string;
  const AFileName: string;
  const ADependencies: TArray<string>;
  const AFixtures: TArray<string>
);
begin
  inherited Create;
  FModuleName := AUnitName;
  FFileName := AFileName;
  FDependencies := Copy(ADependencies);
  FFixtures := Copy(AFixtures);
end;

class function TRadIATestImpactResult.Failed(
  const AErrorCode: string;
  const AErrorMessage: string
): TRadIATestImpactResult;
begin
  Result.FSuccess := False;
  Result.FErrorCode := AErrorCode;
  Result.FErrorMessage := AErrorMessage;
end;

class function TRadIATestImpactResult.Succeeded(
  const APlan: TRadIATestImpactPlan
): TRadIATestImpactResult;
begin
  Result.FSuccess := True;
  Result.FPlan := APlan;
end;

constructor TRadIATestImpactService.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
end;

function TRadIATestImpactService.Plan(
  const AChangedFiles: TArray<string>;
  const AChangedSymbols: TArray<string>;
  const ACoverageReport: string
): TRadIATestImpactResult;
var
  LChangedFiles: TArray<string>;
  LChangedUnits: TArray<string>;
  LConfidence: string;
  LCoverageAvailable: Boolean;
  LCoverageMatched: TArray<string>;
  LCoveragePath: string;
  LExceededLimit: Boolean;
  LFullSuite: Boolean;
  LHasUnknownChange: Boolean;
  LPlan: TRadIATestImpactPlan;
  LProject: TRadIAProjectSnapshot;
  LReasons: TArray<string>;
  LSelectedFixtures: TArray<string>;
  LSelectedTestUnits: TArray<string>;
  LUnits: TObjectDictionary<string, TRadIAUnitImpactInfo>;
  LValidation: TRadIAPathValidation;
begin
  if Length(AChangedFiles) = 0 then
    Exit(TRadIATestImpactResult.Failed(
      'changed_files_required',
      'At least one changed workspace file is required.'
    ));
  LProject := FWorkspace.GetActiveProject;
  if LProject.RootPath.IsEmpty or not TDirectory.Exists(LProject.RootPath) then
    Exit(TRadIATestImpactResult.Failed(
      'workspace_unavailable',
      'An active project root is required for impact analysis.'
    ));
  LChangedFiles := ValidateChangedFiles(
    LProject.RootPath,
    AChangedFiles,
    FBoundary,
    LValidation
  );
  if not LValidation.Allowed then
    Exit(TRadIATestImpactResult.Failed(
      LValidation.ErrorCode,
      LValidation.ErrorMessage
    ));
  if not Trim(ACoverageReport).IsEmpty then
  begin
    LValidation := FBoundary.ValidatePath(
      LProject.RootPath,
      ACoverageReport
    );
    if not LValidation.Allowed then
      Exit(TRadIATestImpactResult.Failed(
        LValidation.ErrorCode,
        LValidation.ErrorMessage
      ));
  end;
  try
    LUnits := BuildUnitMap(LProject.RootPath, LExceededLimit);
  except
    on E: Exception do
      Exit(TRadIATestImpactResult.Failed(
        'impact_scan_failed',
        'The workspace dependency graph could not be scanned: ' + E.Message
      ));
  end;
  try
    LChangedUnits := ResolveChangedUnits(
      LChangedFiles,
      LUnits,
      LHasUnknownChange
    );
    LSelectedFixtures := SelectFixtures(
      LUnits,
      LChangedUnits,
      LSelectedTestUnits,
      LReasons
    );
    LCoveragePath := ResolveCoveragePath(
      LProject.RootPath,
      ACoverageReport,
      FBoundary
    );
    LCoverageMatched := MatchCoverageUnits(
      LCoveragePath,
      LChangedUnits,
      LCoverageAvailable
    );
    LFullSuite := LExceededLimit or LHasUnknownChange or
      (Length(LChangedUnits) = 0) or
      (Length(LSelectedFixtures) = 0) or
      (Length(LSelectedFixtures) > CMaximumFilters) or
      (LCoverageAvailable and
      (Length(LCoverageMatched) < Length(LChangedUnits)));
    if LFullSuite then
    begin
      LSelectedFixtures := nil;
      LSelectedTestUnits := nil;
      LConfidence := 'fallback-full-suite';
      LReasons := LReasons + [
        'Impact evidence was incomplete or exceeded a safety limit; ' +
        'run the complete DUnitX suite.'
      ];
    end
    else if LCoverageAvailable then
      LConfidence := 'high'
    else
    begin
      LConfidence := 'medium';
      LReasons := LReasons + [
        'No coverage report was available; selection is based on the ' +
        'transitive unit dependency graph.'
      ];
    end;
    LPlan.FChangedUnits := Copy(LChangedUnits);
    LPlan.FChangedSymbols := Copy(AChangedSymbols);
    LPlan.FSelectedFixtures := Copy(LSelectedFixtures);
    LPlan.FSelectedTestUnits := Copy(LSelectedTestUnits);
    LPlan.FReasons := Copy(LReasons);
    LPlan.FCoverageMatchedUnits := Copy(LCoverageMatched);
    LPlan.FFullSuite := LFullSuite;
    LPlan.FCoverageAvailable := LCoverageAvailable;
    LPlan.FConfidence := LConfidence;
    Result := TRadIATestImpactResult.Succeeded(LPlan);
  finally
    LUnits.Free;
  end;
end;

end.
