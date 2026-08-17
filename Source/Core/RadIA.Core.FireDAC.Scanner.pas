unit RadIA.Core.FireDAC.Scanner;

interface

uses
  System.Generics.Collections,
  System.JSON,
  RadIA.Core.FireDAC.Model,
  RadIA.Core.WorkspaceBoundary;

type
  TRadIAFireDACScanner = class
  private
    FBoundary: IRadIAWorkspaceBoundary;
    procedure AddCredentialFinding(
      const AInventory: TRadIAFireDACInventory;
      const AFileName: string;
      const ALine: Integer
    );
    procedure AddConfigurationReportFile(
      const ARootPath: string;
      const AFileName: string;
      const AInventory: TRadIAFireDACInventory;
      const AConfigurations: TJSONArray;
      const AFindings: TJSONArray
    );
    procedure AddProjectReportFile(
      const ARootPath: string;
      const AFileName: string;
      const AInventory: TRadIAFireDACInventory;
      const ASqlAnalyses: TJSONArray;
      const AFindings: TJSONArray
    );
    procedure AnalyzeDfm(
      const AContent: string;
      const AFileName: string;
      const AInventory: TRadIAFireDACInventory
    );
    procedure AnalyzePascal(
      const AContent: string;
      const AFileName: string;
      const AInventory: TRadIAFireDACInventory
    );
    procedure AnalyzePascalCodeLine(
      const ALine: string;
      const AFileName: string;
      const ALineNumber: Integer;
      const AInventory: TRadIAFireDACInventory;
      var ACurrentOwner: string
    );
    procedure AnalyzeProject(
      const AContent: string;
      const AInventory: TRadIAFireDACInventory
    );
    procedure AnalyzeRelationshipLine(
      const ALine: string;
      const ASourceName: string;
      const AFileName: string;
      const ALineNumber: Integer;
      const AInventory: TRadIAFireDACInventory
    );
    function CollectFiles(
      const ARootPath: string;
      const AInventory: TRadIAFireDACInventory
    ): TArray<string>;
    function ComponentKind(const AClassName: string): TRadIAFireDACComponentKind;
    function IsCredentialLine(const ALine: string): Boolean;
    function IsPotentiallyMutableSql(const AContent: string): Boolean;
    function IsSupportedClass(const AClassName: string): Boolean;
    function ReadSupportedFile(
      const AFileName: string;
      const ARelativeName: string;
      const AInventory: TRadIAFireDACInventory;
      out AContent: string
    ): Boolean;
    function RelativeName(const ARootPath: string; const AFileName: string): string;
    function TryCloseDfmComponent(
      const ALine: string;
      const AOwners: TStack<string>;
      var ACurrentComponent: string
    ): Boolean;
    function TryOpenDfmComponent(
      const ALine: string;
      const AFileName: string;
      const ALineNumber: Integer;
      const AInventory: TRadIAFireDACInventory;
      const AOwners: TStack<string>;
      var ACurrentComponent: string
    ): Boolean;
  public
    constructor Create(const ABoundary: IRadIAWorkspaceBoundary);
    function AnalyzeThreadSafety(const ARootPath: string): string;
    function AuditTransactions(const ARootPath: string): string;
    function DiagnoseEnvironment(const ARootPath: string): string;
    function GetProjectReport(const ARootPath: string): string;
    function InspectConfiguration(const ARootPath: string): string;
    function Scan(const ARootPath: string): TRadIAFireDACInventory;
  end;

implementation

uses
  System.Generics.Defaults,
  System.IOUtils,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.FireDAC.Configuration,
  RadIA.Core.FireDAC.Environment,
  RadIA.Core.FireDAC.PascalMask,
  RadIA.Core.FireDAC.SqlExtraction,
  RadIA.Core.FireDAC.SqlAnalyzer,
  RadIA.Core.FireDAC.ThreadSafety,
  RadIA.Core.FireDAC.Transactions;

const
  CClassPattern =
    'TFD(?:Manager|Connection|Transaction|Query|Command|Table|StoredProc|MemTable|' +
    'LocalSQL|UpdateSQL|Script|BatchMove|Phys[A-Za-z0-9_]*DriverLink|' +
    'GUIxWaitCursor|Moni[A-Za-z0-9_]*ClientLink)|TDataSource';

constructor TRadIAFireDACScanner.Create(const ABoundary: IRadIAWorkspaceBoundary);
begin
  inherited Create;
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  FBoundary := ABoundary;
end;

function TRadIAFireDACScanner.DiagnoseEnvironment(const ARootPath: string): string;
var
  LAnalysis: TRadIAFireDACConfigurationAnalysis;
  LAnalyzer: TRadIAFireDACConfigurationAnalyzer;
  LContent: string;
  LEnvironment: TRadIAFireDACEnvironmentAnalysis;
  LExtension: string;
  LFileName: string;
  LFiles: TArray<string>;
  LFinding: TRadIAFireDACFinding;
  LInventory: TRadIAFireDACInventory;
  LRelativeName: string;
begin
  if ARootPath.Trim.IsEmpty or not TDirectory.Exists(ARootPath) then
    raise EDirectoryNotFoundException.Create('A valid project root is required.');
  LInventory := TRadIAFireDACInventory.Create;
  try
    LAnalyzer := TRadIAFireDACConfigurationAnalyzer.Create;
    try
      LEnvironment := TRadIAFireDACEnvironmentAnalysis.Create;
      try
        LFiles := CollectFiles(ARootPath, LInventory);
        for LFileName in LFiles do
        begin
          LExtension := TPath.GetExtension(LFileName).ToLower;
          if not MatchText(LExtension, ['.pas', '.dfm']) then
            Continue;
          LRelativeName := RelativeName(ARootPath, LFileName);
          if not ReadSupportedFile(LFileName, LRelativeName, LInventory, LContent) then
            Continue;
          if SameText(LExtension, '.pas') then
            LAnalysis := LAnalyzer.AnalyzePascal(LContent, LRelativeName)
          else
            LAnalysis := LAnalyzer.AnalyzeDfm(LContent, LRelativeName);
          try
            LEnvironment.AnalyzeEntries(LAnalysis.Entries);
            for LFinding in LAnalysis.Findings do
              LEnvironment.AddFinding(LFinding);
          finally
            LAnalysis.Free;
          end;
        end;
        Result := LEnvironment.ToJson;
      finally
        LEnvironment.Free;
      end;
    finally
      LAnalyzer.Free;
    end;
  finally
    LInventory.Free;
  end;
end;

procedure TRadIAFireDACScanner.AddProjectReportFile(
  const ARootPath: string;
  const AFileName: string;
  const AInventory: TRadIAFireDACInventory;
  const ASqlAnalyses: TJSONArray;
  const AFindings: TJSONArray
);
var
  LAnalysis: TRadIAFireDACSqlAnalysis;
  LAnalyzer: TRadIAFireDACSqlAnalyzer;
  LContent: string;
  LExtraction: TRadIAFireDACSqlExtraction;
  LExtractor: TRadIAFireDACSqlExtractor;
  LFinding: TRadIAFireDACFinding;
  LRelativeName: string;
  LSource: TRadIAFireDACSqlSource;
begin
  LRelativeName := RelativeName(ARootPath, AFileName);
  if not ReadSupportedFile(AFileName, LRelativeName, AInventory, LContent) then
    Exit;
  LExtractor := TRadIAFireDACSqlExtractor.Create;
  LAnalyzer := TRadIAFireDACSqlAnalyzer.Create;
  try
    if SameText(TPath.GetExtension(AFileName), '.pas') then
      LExtraction := LExtractor.ExtractPascal(LContent, LRelativeName)
    else if SameText(TPath.GetExtension(AFileName), '.dfm') then
      LExtraction := LExtractor.ExtractDfm(LContent, LRelativeName)
    else
      Exit;
    try
      for LFinding in LExtraction.Findings do
        AFindings.AddElement(RadIAFireDACFindingToJson(LFinding));
      for LSource in LExtraction.Sources do
      begin
        if LSource.Dynamic then
          Continue;
        LAnalysis := LAnalyzer.Analyze(
          LSource.Sql,
          LSource.Location.FileName,
          LSource.Location.Line
        );
        try
          for LFinding in LAnalysis.Findings do
            AFindings.AddElement(RadIAFireDACFindingToJson(LFinding));
        finally
          LAnalysis.Free;
        end;
      end;
      if Length(LExtraction.Sources) > 0 then
        ASqlAnalyses.AddElement(TJSONObject.ParseJSONValue(LExtraction.ToJson));
    finally
      LExtraction.Free;
    end;
  finally
    LAnalyzer.Free;
    LExtractor.Free;
  end;
end;

function TRadIAFireDACScanner.GetProjectReport(const ARootPath: string): string;
var
  LFileName: string;
  LFiles: TArray<string>;
  LFinding: TRadIAFireDACFinding;
  LFindings: TJSONArray;
  LInventory: TRadIAFireDACInventory;
  LObject: TJSONObject;
  LRoot: TJSONObject;
  LSqlAnalyses: TJSONArray;
begin
  LInventory := Scan(ARootPath);
  LRoot := TJSONObject.Create;
  try
    LFiles := CollectFiles(ARootPath, LInventory);
    LObject := TJSONObject.ParseJSONValue(LInventory.ToJson) as TJSONObject;
    LRoot.AddPair('inventory', LObject);
    LSqlAnalyses := TJSONArray.Create;
    LFindings := TJSONArray.Create;
    for LFinding in LInventory.Findings do
      LFindings.AddElement(RadIAFireDACFindingToJson(LFinding));
    for LFileName in LFiles do
      AddProjectReportFile(
        ARootPath,
        LFileName,
        LInventory,
        LSqlAnalyses,
        LFindings
      );
    LRoot.AddPair('sqlAnalyses', LSqlAnalyses);
    LRoot.AddPair('findings', LFindings);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
    LInventory.Free;
  end;
end;

function TRadIAFireDACScanner.RelativeName(
  const ARootPath: string;
  const AFileName: string
): string;
begin
  Result := AFileName;
  if AFileName.StartsWith(IncludeTrailingPathDelimiter(ARootPath), True) then
    Result := AFileName.Substring(IncludeTrailingPathDelimiter(ARootPath).Length);
end;

function TRadIAFireDACScanner.ComponentKind(
  const AClassName: string
): TRadIAFireDACComponentKind;
const
  CClassNames: array[0..13] of string = (
    'TFDManager', 'TFDConnection', 'TFDTransaction', 'TFDQuery',
    'TFDCommand', 'TFDTable', 'TFDStoredProc', 'TFDMemTable',
    'TFDLocalSQL', 'TFDUpdateSQL', 'TFDScript', 'TFDBatchMove',
    'TFDGUIxWaitCursor', 'TDataSource'
  );
  CKinds: array[0..13] of TRadIAFireDACComponentKind = (
    fckManager, fckConnection, fckTransaction, fckQuery,
    fckCommand, fckTable, fckStoredProcedure, fckMemoryTable,
    fckLocalSql, fckUpdateSql, fckScript, fckBatchMove,
    fckWaitCursor, fckDataSource
  );
var
  LIndex: Integer;
begin
  for LIndex := Low(CClassNames) to High(CClassNames) do
    if SameText(AClassName, CClassNames[LIndex]) then
      Exit(CKinds[LIndex]);
  if TRegEx.IsMatch(AClassName, '(?i)^TFDPhys.+DriverLink$') then
    Exit(fckDriverLink);
  if TRegEx.IsMatch(AClassName, '(?i)^TFDMoni.+ClientLink$') then
    Exit(fckMonitorLink);
  Result := fckUnknown;
end;

function TRadIAFireDACScanner.IsSupportedClass(const AClassName: string): Boolean;
begin
  Result := TRegEx.IsMatch(AClassName, '(?i)^(' + CClassPattern + ')$');
end;

function TRadIAFireDACScanner.IsCredentialLine(const ALine: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    ALine,
    '(?i)(?:Password|Pwd|User_Name|User\s*ID|AccessToken|AuthToken)\s*='
  );
end;

function TRadIAFireDACScanner.IsPotentiallyMutableSql(const AContent: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    AContent,
    '(?i)\b(?:insert|update|delete|merge|alter|drop|create)\b'
  );
end;

procedure TRadIAFireDACScanner.AddCredentialFinding(
  const AInventory: TRadIAFireDACInventory;
  const AFileName: string;
  const ALine: Integer
);
begin
  AInventory.AddFinding(TRadIAFireDACFinding.Create(
    'firedac.configuration.embedded-credential',
    ffsCritical,
    ffcProven,
    'Embedded connection credential',
    'A FireDAC connection setting contains a credential. Its value was not collected.',
    TRadIAFireDACFindingDetails.Create(
      TRadIAFireDACLocation.Create(AFileName, ALine),
      '',
      'A credential-bearing FireDAC setting is present; its value was discarded.',
      'Move the credential to a protected runtime configuration.',
      False
    )
  ));
end;

procedure TRadIAFireDACScanner.AnalyzeRelationshipLine(
  const ALine: string;
  const ASourceName: string;
  const AFileName: string;
  const ALineNumber: Integer;
  const AInventory: TRadIAFireDACInventory
);
const
  CPropertyNames: array[0..3] of string = (
    'Connection', 'Transaction', 'UpdateObject', 'DataSet'
  );
var
  LMatch: TMatch;
  LPropertyName: string;
begin
  if ASourceName.IsEmpty then
    Exit;
  for LPropertyName in CPropertyNames do
  begin
    LMatch := TRegEx.Match(
      ALine,
      '(?i)(?:\.' + LPropertyName + '|^\s*' + LPropertyName + ')\s*:?=\s*([A-Za-z_][A-Za-z0-9_.]*)'
    );
    if LMatch.Success then
      AInventory.AddRelationship(TRadIAFireDACRelationship.Create(
        ASourceName,
        LMatch.Groups[1].Value,
        LowerCase(LPropertyName),
        TRadIAFireDACLocation.Create(AFileName, ALineNumber)
      ));
  end;
end;

procedure TRadIAFireDACScanner.AnalyzeDfm(
  const AContent: string;
  const AFileName: string;
  const AInventory: TRadIAFireDACInventory
);
var
  LCurrentComponent: string;
  LLine: string;
  LLineNumber: Integer;
  LOwners: TStack<string>;
begin
  LCurrentComponent := '';
  LOwners := TStack<string>.Create;
  try
    LLineNumber := 0;
    for LLine in AContent.Split([sLineBreak]) do
    begin
      Inc(LLineNumber);
      if TryOpenDfmComponent(
        LLine,
        AFileName,
        LLineNumber,
        AInventory,
        LOwners,
        LCurrentComponent
      ) then
        Continue;
      if TryCloseDfmComponent(LLine, LOwners, LCurrentComponent) then
        Continue;
      AnalyzeRelationshipLine(LLine, LCurrentComponent, AFileName, LLineNumber, AInventory);
      if IsCredentialLine(LLine) then
        AddCredentialFinding(AInventory, AFileName, LLineNumber);
    end;
  finally
    LOwners.Free;
  end;
end;

function TRadIAFireDACScanner.TryOpenDfmComponent(
  const ALine: string;
  const AFileName: string;
  const ALineNumber: Integer;
  const AInventory: TRadIAFireDACInventory;
  const AOwners: TStack<string>;
  var ACurrentComponent: string
): Boolean;
var
  LClassName: string;
  LMatch: TMatch;
  LName: string;
  LOwnerName: string;
begin
  LMatch := TRegEx.Match(
    ALine,
    '(?i)^\s*(?:object|inherited|inline)\s+([A-Za-z_][A-Za-z0-9_]*):\s*([A-Za-z_][A-Za-z0-9_.]*)'
  );
  Result := LMatch.Success;
  if not Result then
    Exit;
  LName := LMatch.Groups[1].Value;
  LClassName := LMatch.Groups[2].Value;
  if AOwners.Count > 0 then
    LOwnerName := AOwners.Peek
  else
    LOwnerName := '';
  AOwners.Push(LName);
  ACurrentComponent := LName;
  if IsSupportedClass(LClassName) then
    AInventory.AddComponent(TRadIAFireDACComponent.Create(
      LName,
      LClassName,
      ComponentKind(LClassName),
      TRadIAFireDACLocation.Create(AFileName, ALineNumber),
      LOwnerName
    ));
end;

function TRadIAFireDACScanner.TryCloseDfmComponent(
  const ALine: string;
  const AOwners: TStack<string>;
  var ACurrentComponent: string
): Boolean;
begin
  Result := SameText(ALine.Trim, 'end');
  if not Result then
    Exit;
  if AOwners.Count > 0 then
    AOwners.Pop;
  if AOwners.Count > 0 then
    ACurrentComponent := AOwners.Peek
  else
    ACurrentComponent := '';
end;

procedure TRadIAFireDACScanner.AnalyzePascal(
  const AContent: string;
  const AFileName: string;
  const AInventory: TRadIAFireDACInventory
);
var
  LCurrentOwner: string;
  LLine: string;
  LLineNumber: Integer;
  LMaskedContent: string;
begin
  LCurrentOwner := '';
  LLineNumber := 0;
  LMaskedContent := RadIAMaskPascalNonCode(AContent);
  for LLine in LMaskedContent.Split([sLineBreak]) do
  begin
    Inc(LLineNumber);
    AnalyzePascalCodeLine(
      LLine,
      AFileName,
      LLineNumber,
      AInventory,
      LCurrentOwner
    );
  end;
end;

procedure TRadIAFireDACScanner.AnalyzePascalCodeLine(
  const ALine: string;
  const AFileName: string;
  const ALineNumber: Integer;
  const AInventory: TRadIAFireDACInventory;
  var ACurrentOwner: string
);
var
  LClassName: string;
  LMatch: TMatch;
  LName: string;
begin
  LMatch := TRegEx.Match(
    ALine,
    '(?i)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*class(?:\s*\([^)]*\))?'
  );
  if LMatch.Success then
    ACurrentOwner := LMatch.Groups[1].Value;
  LMatch := TRegEx.Match(
    ALine,
    '(?i)\b([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(' + CClassPattern + ')\b'
  );
  if not LMatch.Success then
    LMatch := TRegEx.Match(
      ALine,
      '(?i)\b([A-Za-z_][A-Za-z0-9_]*)\s*:=\s*(' + CClassPattern + ')\.Create\b'
    );
  if LMatch.Success then
  begin
    LName := LMatch.Groups[1].Value;
    LClassName := LMatch.Groups[2].Value;
    AInventory.AddComponent(TRadIAFireDACComponent.Create(
      LName,
      LClassName,
      ComponentKind(LClassName),
      TRadIAFireDACLocation.Create(AFileName, ALineNumber),
      ACurrentOwner
    ));
  end;
  LMatch := TRegEx.Match(
    ALine,
    '(?i)\b([A-Za-z_][A-Za-z0-9_]*)\.(?:Connection|Transaction|UpdateObject|DataSet)\s*:='
  );
  if LMatch.Success then
    AnalyzeRelationshipLine(
      ALine,
      LMatch.Groups[1].Value,
      AFileName,
      ALineNumber,
      AInventory
    );
  if IsCredentialLine(ALine) then
    AddCredentialFinding(AInventory, AFileName, ALineNumber);
end;

procedure TRadIAFireDACScanner.AnalyzeProject(
  const AContent: string;
  const AInventory: TRadIAFireDACInventory
);
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(AContent, '(?i)\bFireDAC(?:\.[A-Za-z0-9_]+)+\b');
  while LMatch.Success do
  begin
    AInventory.AddProjectReference(LMatch.Value);
    LMatch := LMatch.NextMatch;
  end;
end;

function TRadIAFireDACScanner.ReadSupportedFile(
  const AFileName: string;
  const ARelativeName: string;
  const AInventory: TRadIAFireDACInventory;
  out AContent: string
): Boolean;
begin
  Result := False;
  AContent := '';
  try
    if TFile.GetSize(AFileName) > CRadIAFireDACMaximumFileBytes then
    begin
      AInventory.Truncated := True;
      AInventory.AddFinding(TRadIAFireDACFinding.Create(
        'firedac.scan.file-too-large',
        ffsInfo,
        ffcProven,
        'FireDAC source file was not scanned',
        'A supported source file exceeds the bounded scanner size.',
        TRadIAFireDACFindingDetails.Create(
          TRadIAFireDACLocation.Create(ARelativeName, 0),
          '',
          'The file size exceeds the configured scanner byte limit.',
          'Review or reduce the file before running the inventory again.',
          False
        )
      ));
      Exit;
    end;
    AContent := TFile.ReadAllText(AFileName);
    Result := True;
  except
    on E: Exception do
      AInventory.AddFinding(TRadIAFireDACFinding.Create(
        'firedac.scan.file-unreadable',
        ffsLow,
        ffcProven,
        'FireDAC source file could not be read',
        'A supported source file could not be read safely.',
        TRadIAFireDACFindingDetails.Create(
          TRadIAFireDACLocation.Create(ARelativeName, 0),
          '',
          'The bounded file reader rejected or could not decode the file.',
          'Check file access and encoding before running the inventory again.',
          False
        )
      ));
  end;
end;

function TRadIAFireDACScanner.CollectFiles(
  const ARootPath: string;
  const AInventory: TRadIAFireDACInventory
): TArray<string>;
var
  LAllFiles: TArray<string>;
  LExtension: string;
  LFileName: string;
  LFiles: TList<string>;
  LValidation: TRadIAPathValidation;
begin
  LFiles := TList<string>.Create;
  try
    LAllFiles := TDirectory.GetFiles(ARootPath, '*', TSearchOption.soAllDirectories);
    TArray.Sort<string>(LAllFiles, TComparer<string>.Default);
    for LFileName in LAllFiles do
    begin
      LExtension := TPath.GetExtension(LFileName).ToLower;
      if not MatchText(LExtension, ['.pas', '.dfm', '.dproj']) then
        Continue;
      LValidation := FBoundary.ValidatePath(ARootPath, LFileName);
      if not LValidation.Allowed then
        Continue;
      if LFiles.Count >= CRadIAFireDACMaximumFiles then
      begin
        AInventory.Truncated := True;
        Break;
      end;
      LFiles.Add(LValidation.ResolvedPath);
    end;
    Result := LFiles.ToArray;
  finally
    LFiles.Free;
  end;
end;

function TRadIAFireDACScanner.Scan(const ARootPath: string): TRadIAFireDACInventory;
var
  LContent: string;
  LExtension: string;
  LFileName: string;
  LFiles: TArray<string>;
  LRelativeName: string;
begin
  if ARootPath.Trim.IsEmpty or not TDirectory.Exists(ARootPath) then
    raise EDirectoryNotFoundException.Create('A valid project root is required.');
  Result := TRadIAFireDACInventory.Create;
  try
    LFiles := CollectFiles(ARootPath, Result);
    Result.ScannedFileCount := Length(LFiles);
    for LFileName in LFiles do
    begin
      LRelativeName := RelativeName(ARootPath, LFileName);
      if not ReadSupportedFile(LFileName, LRelativeName, Result, LContent) then
        Continue;
      Result.ParameterReferenceCount := Result.ParameterReferenceCount +
        TRegEx.Matches(LContent, '(?i)\b(?:Params|ParamByName)\b').Count;
      if IsPotentiallyMutableSql(LContent) then
        Result.PotentiallyMutableSqlFileCount := Result.PotentiallyMutableSqlFileCount + 1;
      LExtension := TPath.GetExtension(LFileName).ToLower;
      if SameText(LExtension, '.pas') then
        AnalyzePascal(LContent, LRelativeName, Result)
      else if SameText(LExtension, '.dfm') then
        AnalyzeDfm(LContent, LRelativeName, Result)
      else if SameText(LExtension, '.dproj') then
        AnalyzeProject(LContent, Result);
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TRadIAFireDACScanner.AuditTransactions(const ARootPath: string): string;
var
  LAnalysis: TRadIAFireDACTransactionAnalysis;
  LAnalyzer: TRadIAFireDACTransactionAnalyzer;
  LContent: string;
  LFileName: string;
  LFiles: TArray<string>;
  LFinding: TRadIAFireDACFinding;
  LFindings: TJSONArray;
  LInventory: TRadIAFireDACInventory;
  LObject: TJSONObject;
  LRelativeName: string;
  LRoot: TJSONObject;
  LAudits: TJSONArray;
begin
  if ARootPath.Trim.IsEmpty or not TDirectory.Exists(ARootPath) then
    raise EDirectoryNotFoundException.Create('A valid project root is required.');
  LInventory := TRadIAFireDACInventory.Create;
  LAnalyzer := TRadIAFireDACTransactionAnalyzer.Create;
  LRoot := TJSONObject.Create;
  try
    LFiles := CollectFiles(ARootPath, LInventory);
    LAudits := TJSONArray.Create;
    LFindings := TJSONArray.Create;
    for LFileName in LFiles do
    begin
      if not SameText(TPath.GetExtension(LFileName), '.pas') then
        Continue;
      LRelativeName := RelativeName(ARootPath, LFileName);
      if not ReadSupportedFile(LFileName, LRelativeName, LInventory, LContent) then
        Continue;
      LAnalysis := LAnalyzer.Analyze(LContent, LRelativeName);
      try
        for LFinding in LAnalysis.Findings do
          LFindings.AddElement(RadIAFireDACFindingToJson(LFinding));
        if LAnalysis.UsageCount = 0 then
          Continue;
        LObject := TJSONObject.ParseJSONValue(LAnalysis.ToJson) as TJSONObject;
        if Assigned(LObject) then
        begin
          LObject.AddPair('file', LRelativeName);
          LAudits.AddElement(LObject);
        end;
      finally
        LAnalysis.Free;
      end;
    end;
    LRoot.AddPair('scannedFileCount', TJSONNumber.Create(Length(LFiles)));
    LRoot.AddPair('truncated', TJSONBool.Create(LInventory.Truncated));
    LRoot.AddPair('audits', LAudits);
    LRoot.AddPair('findings', LFindings);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
    LAnalyzer.Free;
    LInventory.Free;
  end;
end;

function TRadIAFireDACScanner.AnalyzeThreadSafety(const ARootPath: string): string;
var
  LAnalyses: TJSONArray;
  LAnalysis: TRadIAFireDACThreadSafetyAnalysis;
  LAnalyzer: TRadIAFireDACThreadSafetyAnalyzer;
  LContent: string;
  LFileName: string;
  LFiles: TArray<string>;
  LFinding: TRadIAFireDACFinding;
  LFindings: TJSONArray;
  LInventory: TRadIAFireDACInventory;
  LObject: TJSONObject;
  LRelativeName: string;
  LRoot: TJSONObject;
begin
  if ARootPath.Trim.IsEmpty or not TDirectory.Exists(ARootPath) then
    raise EDirectoryNotFoundException.Create('A valid project root is required.');
  LInventory := TRadIAFireDACInventory.Create;
  LAnalyzer := TRadIAFireDACThreadSafetyAnalyzer.Create;
  LRoot := TJSONObject.Create;
  try
    LFiles := CollectFiles(ARootPath, LInventory);
    LAnalyses := TJSONArray.Create;
    LFindings := TJSONArray.Create;
    for LFileName in LFiles do
    begin
      if not SameText(TPath.GetExtension(LFileName), '.pas') then
        Continue;
      LRelativeName := RelativeName(ARootPath, LFileName);
      if not ReadSupportedFile(LFileName, LRelativeName, LInventory, LContent) then
        Continue;
      LAnalysis := LAnalyzer.Analyze(LContent, LRelativeName);
      try
        for LFinding in LAnalysis.Findings do
          LFindings.AddElement(RadIAFireDACFindingToJson(LFinding));
        if LAnalysis.Truncated then
          LInventory.Truncated := True;
        if LAnalysis.ContextCount = 0 then
          Continue;
        LObject := TJSONObject.ParseJSONValue(LAnalysis.ToJson) as TJSONObject;
        if Assigned(LObject) then
        begin
          LObject.AddPair('file', LRelativeName);
          LAnalyses.AddElement(LObject);
        end;
      finally
        LAnalysis.Free;
      end;
    end;
    LRoot.AddPair('scannedFileCount', TJSONNumber.Create(Length(LFiles)));
    LRoot.AddPair('truncated', TJSONBool.Create(LInventory.Truncated));
    LRoot.AddPair('analyses', LAnalyses);
    LRoot.AddPair('findings', LFindings);
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
    LAnalyzer.Free;
    LInventory.Free;
  end;
end;

procedure TRadIAFireDACScanner.AddConfigurationReportFile(
  const ARootPath: string;
  const AFileName: string;
  const AInventory: TRadIAFireDACInventory;
  const AConfigurations: TJSONArray;
  const AFindings: TJSONArray
);
var
  LAnalysis: TRadIAFireDACConfigurationAnalysis;
  LAnalyzer: TRadIAFireDACConfigurationAnalyzer;
  LContent: string;
  LExtension: string;
  LFinding: TRadIAFireDACFinding;
  LObject: TJSONObject;
  LRelativeName: string;
begin
  LExtension := TPath.GetExtension(AFileName).ToLower;
  if not MatchText(LExtension, ['.pas', '.dfm']) then
    Exit;
  LRelativeName := RelativeName(ARootPath, AFileName);
  if not ReadSupportedFile(AFileName, LRelativeName, AInventory, LContent) then
    Exit;
  LAnalyzer := TRadIAFireDACConfigurationAnalyzer.Create;
  try
    if SameText(LExtension, '.pas') then
      LAnalysis := LAnalyzer.AnalyzePascal(LContent, LRelativeName)
    else
      LAnalysis := LAnalyzer.AnalyzeDfm(LContent, LRelativeName);
    try
      for LFinding in LAnalysis.Findings do
        AFindings.AddElement(RadIAFireDACFindingToJson(LFinding));
      if LAnalysis.EntryCount = 0 then
        Exit;
      LObject := TJSONObject.ParseJSONValue(LAnalysis.ToJson) as TJSONObject;
      if Assigned(LObject) then
        AConfigurations.AddElement(LObject);
    finally
      LAnalysis.Free;
    end;
  finally
    LAnalyzer.Free;
  end;
end;

function TRadIAFireDACScanner.InspectConfiguration(const ARootPath: string): string;
var
  LConfigurations: TJSONArray;
  LFileName: string;
  LFiles: TArray<string>;
  LFindings: TJSONArray;
  LInventory: TRadIAFireDACInventory;
  LRoot: TJSONObject;
begin
  if ARootPath.Trim.IsEmpty or not TDirectory.Exists(ARootPath) then
    raise EDirectoryNotFoundException.Create('A valid project root is required.');
  LInventory := TRadIAFireDACInventory.Create;
  LRoot := TJSONObject.Create;
  try
    LFiles := CollectFiles(ARootPath, LInventory);
    LConfigurations := TJSONArray.Create;
    LFindings := TJSONArray.Create;
    for LFileName in LFiles do
      AddConfigurationReportFile(
        ARootPath,
        LFileName,
        LInventory,
        LConfigurations,
        LFindings
      );
    LRoot.AddPair('scannedFileCount', TJSONNumber.Create(Length(LFiles)));
    LRoot.AddPair('truncated', TJSONBool.Create(LInventory.Truncated));
    LRoot.AddPair('configurations', LConfigurations);
    LRoot.AddPair('findings', LFindings);
    LRoot.AddPair('credentialsCollected', TJSONBool.Create(False));
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
    LInventory.Free;
  end;
end;

end.
