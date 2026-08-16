unit RadIA.Core.FireDAC.Scanner;

interface

uses
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
  public
    constructor Create(const ABoundary: IRadIAWorkspaceBoundary);
    function Scan(const ARootPath: string): TRadIAFireDACInventory;
  end;

implementation

uses
  System.Generics.Collections,
  System.Generics.Defaults,
  System.IOUtils,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils;

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
begin
  if SameText(AClassName, 'TFDManager') then
    Exit(fckManager);
  if SameText(AClassName, 'TFDConnection') then
    Exit(fckConnection);
  if SameText(AClassName, 'TFDTransaction') then
    Exit(fckTransaction);
  if SameText(AClassName, 'TFDQuery') then
    Exit(fckQuery);
  if SameText(AClassName, 'TFDCommand') then
    Exit(fckCommand);
  if SameText(AClassName, 'TFDTable') then
    Exit(fckTable);
  if SameText(AClassName, 'TFDStoredProc') then
    Exit(fckStoredProcedure);
  if SameText(AClassName, 'TFDMemTable') then
    Exit(fckMemoryTable);
  if SameText(AClassName, 'TFDLocalSQL') then
    Exit(fckLocalSql);
  if SameText(AClassName, 'TFDUpdateSQL') then
    Exit(fckUpdateSql);
  if SameText(AClassName, 'TFDScript') then
    Exit(fckScript);
  if SameText(AClassName, 'TFDBatchMove') then
    Exit(fckBatchMove);
  if SameText(AClassName, 'TFDGUIxWaitCursor') then
    Exit(fckWaitCursor);
  if SameText(AClassName, 'TDataSource') then
    Exit(fckDataSource);
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
    TRadIAFireDACLocation.Create(AFileName, ALine),
    'Move the credential to a protected runtime configuration.',
    False
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
  LClassName: string;
  LCurrentComponent: string;
  LLine: string;
  LLineNumber: Integer;
  LMatch: TMatch;
  LName: string;
  LOwners: TStack<string>;
  LOwnerName: string;
begin
  LCurrentComponent := '';
  LOwners := TStack<string>.Create;
  try
    LLineNumber := 0;
    for LLine in AContent.Split([sLineBreak]) do
    begin
      Inc(LLineNumber);
      LMatch := TRegEx.Match(
        LLine,
        '(?i)^\s*(?:object|inherited|inline)\s+([A-Za-z_][A-Za-z0-9_]*):\s*([A-Za-z_][A-Za-z0-9_.]*)'
      );
      if LMatch.Success then
      begin
        LName := LMatch.Groups[1].Value;
        LClassName := LMatch.Groups[2].Value;
        if LOwners.Count > 0 then
          LOwnerName := LOwners.Peek
        else
          LOwnerName := '';
        LOwners.Push(LName);
        LCurrentComponent := LName;
        if IsSupportedClass(LClassName) then
          AInventory.AddComponent(TRadIAFireDACComponent.Create(
            LName,
            LClassName,
            ComponentKind(LClassName),
            TRadIAFireDACLocation.Create(AFileName, LLineNumber),
            LOwnerName
          ));
        Continue;
      end;
      if SameText(LLine.Trim, 'end') then
      begin
        if LOwners.Count > 0 then
          LOwners.Pop;
        if LOwners.Count > 0 then
          LCurrentComponent := LOwners.Peek
        else
          LCurrentComponent := '';
        Continue;
      end;
      AnalyzeRelationshipLine(LLine, LCurrentComponent, AFileName, LLineNumber, AInventory);
      if IsCredentialLine(LLine) then
        AddCredentialFinding(AInventory, AFileName, LLineNumber);
    end;
  finally
    LOwners.Free;
  end;
end;

procedure TRadIAFireDACScanner.AnalyzePascal(
  const AContent: string;
  const AFileName: string;
  const AInventory: TRadIAFireDACInventory
);
var
  LClassName: string;
  LCodeLine: string;
  LCurrentOwner: string;
  LInBlockComment: Boolean;
  LLine: string;
  LLineNumber: Integer;
  LMatch: TMatch;
  LName: string;
begin
  LCurrentOwner := '';
  LInBlockComment := False;
  LLineNumber := 0;
  for LLine in AContent.Split([sLineBreak]) do
  begin
    Inc(LLineNumber);
    LCodeLine := LLine;
    if LInBlockComment then
    begin
      if LCodeLine.Contains('}') then
      begin
        LCodeLine := LCodeLine.Substring(LCodeLine.IndexOf('}') + 1);
        LInBlockComment := False;
      end
      else if LCodeLine.Contains('*)') then
      begin
        LCodeLine := LCodeLine.Substring(LCodeLine.IndexOf('*)') + 2);
        LInBlockComment := False;
      end
      else
        Continue;
    end;
    if LCodeLine.Trim.StartsWith('//') then
      Continue;
    if LCodeLine.Trim.StartsWith('{') and not LCodeLine.Contains('}') then
    begin
      LInBlockComment := True;
      Continue;
    end;
    if LCodeLine.Trim.StartsWith('(*') and not LCodeLine.Contains('*)') then
    begin
      LInBlockComment := True;
      Continue;
    end;
    LMatch := TRegEx.Match(
      LCodeLine,
      '(?i)^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*class(?:\s*\([^)]*\))?'
    );
    if LMatch.Success then
      LCurrentOwner := LMatch.Groups[1].Value;
    LMatch := TRegEx.Match(
      LCodeLine,
      '(?i)\b([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(' + CClassPattern + ')\b'
    );
    if not LMatch.Success then
      LMatch := TRegEx.Match(
        LCodeLine,
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
        TRadIAFireDACLocation.Create(AFileName, LLineNumber),
        LCurrentOwner
      ));
    end;
    LMatch := TRegEx.Match(
      LCodeLine,
      '(?i)\b([A-Za-z_][A-Za-z0-9_]*)\.(?:Connection|Transaction|UpdateObject|DataSet)\s*:='
    );
    if LMatch.Success then
      AnalyzeRelationshipLine(
        LCodeLine,
        LMatch.Groups[1].Value,
        AFileName,
        LLineNumber,
        AInventory
      );
    if IsCredentialLine(LCodeLine) then
      AddCredentialFinding(AInventory, AFileName, LLineNumber);
  end;
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
        TRadIAFireDACLocation.Create(ARelativeName, 0),
        'Review or reduce the file before running the inventory again.',
        False
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
        TRadIAFireDACLocation.Create(ARelativeName, 0),
        'Check file access and encoding before running the inventory again.',
        False
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

end.
