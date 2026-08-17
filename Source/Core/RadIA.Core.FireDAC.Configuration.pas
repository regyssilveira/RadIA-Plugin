unit RadIA.Core.FireDAC.Configuration;

interface

uses
  System.Generics.Collections,
  RadIA.Core.FireDAC.Model;

type
  TRadIAFireDACConfigurationKind = (fcfgConnection, fcfgDriverLink);

  TRadIAFireDACConfigurationEntry = class
  private
    FClassName: string;
    FConnectionDefinition: string;
    FDesignTimeConnected: Boolean;
    FDriverId: string;
    FFileName: string;
    FHasCredential: Boolean;
    FKind: TRadIAFireDACConfigurationKind;
    FLibraryFileName: string;
    FLine: Integer;
    FLoginPromptKnown: Boolean;
    FLoginPrompt: Boolean;
    FName: string;
    FOptionCount: Integer;
  public
    constructor Create(
      const AName: string;
      const AClassName: string;
      const AKind: TRadIAFireDACConfigurationKind;
      const AFileName: string;
      const ALine: Integer
    );
    property ComponentClassName: string read FClassName;
    property ConnectionDefinition: string read FConnectionDefinition write FConnectionDefinition;
    property DesignTimeConnected: Boolean read FDesignTimeConnected write FDesignTimeConnected;
    property DriverId: string read FDriverId write FDriverId;
    property FileName: string read FFileName;
    property HasCredential: Boolean read FHasCredential write FHasCredential;
    property Kind: TRadIAFireDACConfigurationKind read FKind;
    property LibraryFileName: string read FLibraryFileName write FLibraryFileName;
    property Line: Integer read FLine;
    property LoginPrompt: Boolean read FLoginPrompt write FLoginPrompt;
    property LoginPromptKnown: Boolean read FLoginPromptKnown write FLoginPromptKnown;
    property Name: string read FName;
    property OptionCount: Integer read FOptionCount write FOptionCount;
  end;

  TRadIAFireDACConfigurationAnalysis = class
  private
    FEntries: TObjectList<TRadIAFireDACConfigurationEntry>;
    FFindings: TList<TRadIAFireDACFinding>;
  public
    constructor Create;
    destructor Destroy; override;
    function AddOrGetEntry(
      const AName: string;
      const AClassName: string;
      const AKind: TRadIAFireDACConfigurationKind;
      const AFileName: string;
      const ALine: Integer
    ): TRadIAFireDACConfigurationEntry;
    procedure AddFinding(const AFinding: TRadIAFireDACFinding);
    function Entries: TArray<TRadIAFireDACConfigurationEntry>;
    function EntryCount: Int64;
    function Findings: TArray<TRadIAFireDACFinding>;
    function ToJson: string;
  end;

  TRadIAFireDACConfigurationAnalyzer = class
  private
    procedure AddCredentialFinding(
      const AEntry: TRadIAFireDACConfigurationEntry;
      const ALine: Integer;
      const AResult: TRadIAFireDACConfigurationAnalysis
    );
    procedure AddLibraryPathFinding(
      const AEntry: TRadIAFireDACConfigurationEntry;
      const ALine: Integer;
      const AResult: TRadIAFireDACConfigurationAnalysis
    );
    function AddDfmEntry(
      const AName: string;
      const AClassName: string;
      const AFileName: string;
      const ALineNumber: Integer;
      const AResult: TRadIAFireDACConfigurationAnalysis
    ): TRadIAFireDACConfigurationEntry;
    procedure AnalyzeDuplicates(const AResult: TRadIAFireDACConfigurationAnalysis);
    procedure AnalyzeEntry(
      const AEntry: TRadIAFireDACConfigurationEntry;
      const AResult: TRadIAFireDACConfigurationAnalysis
    );
    procedure AnalyzePascalLine(
      const ALine: string;
      const ALineNumber: Integer;
      const AFileName: string;
      const AResult: TRadIAFireDACConfigurationAnalysis
    );
    procedure ApplyConnectionLine(
      const ALine: string;
      const ALineNumber: Integer;
      const AEntry: TRadIAFireDACConfigurationEntry;
      const AResult: TRadIAFireDACConfigurationAnalysis
    );
    procedure ApplyDriverLine(
      const ALine: string;
      const ALineNumber: Integer;
      const AEntry: TRadIAFireDACConfigurationEntry;
      const AResult: TRadIAFireDACConfigurationAnalysis
    );
    function QuotedPropertyValue(const ALine, APropertyName: string): string;
  public
    function AnalyzeDfm(
      const AContent: string;
      const AFileName: string
    ): TRadIAFireDACConfigurationAnalysis;
    function AnalyzePascal(
      const AContent: string;
      const AFileName: string
    ): TRadIAFireDACConfigurationAnalysis;
  end;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.RegularExpressions,
  System.SysUtils;

constructor TRadIAFireDACConfigurationEntry.Create(
  const AName: string;
  const AClassName: string;
  const AKind: TRadIAFireDACConfigurationKind;
  const AFileName: string;
  const ALine: Integer
);
begin
  inherited Create;
  FName := AName;
  FClassName := AClassName;
  FKind := AKind;
  FFileName := AFileName;
  FLine := ALine;
end;

constructor TRadIAFireDACConfigurationAnalysis.Create;
begin
  inherited Create;
  FEntries := TObjectList<TRadIAFireDACConfigurationEntry>.Create(True);
  FFindings := TList<TRadIAFireDACFinding>.Create;
end;

destructor TRadIAFireDACConfigurationAnalysis.Destroy;
begin
  FFindings.Free;
  FEntries.Free;
  inherited;
end;

function TRadIAFireDACConfigurationAnalysis.AddOrGetEntry(
  const AName: string;
  const AClassName: string;
  const AKind: TRadIAFireDACConfigurationKind;
  const AFileName: string;
  const ALine: Integer
): TRadIAFireDACConfigurationEntry;
var
  LEntry: TRadIAFireDACConfigurationEntry;
begin
  for LEntry in FEntries do
    if SameText(LEntry.Name, AName) and SameText(LEntry.FileName, AFileName) then
      Exit(LEntry);
  Result := TRadIAFireDACConfigurationEntry.Create(
    AName,
    AClassName,
    AKind,
    AFileName,
    ALine
  );
  FEntries.Add(Result);
end;

procedure TRadIAFireDACConfigurationAnalysis.AddFinding(
  const AFinding: TRadIAFireDACFinding
);
begin
  if FFindings.Count < CRadIAFireDACMaximumFindings then
    FFindings.Add(AFinding);
end;

function TRadIAFireDACConfigurationAnalysis.EntryCount: Int64;
begin
  Result := FEntries.Count;
end;

function TRadIAFireDACConfigurationAnalysis.Findings: TArray<TRadIAFireDACFinding>;
begin
  Result := FFindings.ToArray;
end;

function TRadIAFireDACConfigurationAnalysis.Entries: TArray<TRadIAFireDACConfigurationEntry>;
begin
  Result := FEntries.ToArray;
end;

function ConfigurationKindName(const AKind: TRadIAFireDACConfigurationKind): string;
begin
  if AKind = fcfgConnection then
    Result := 'connection'
  else
    Result := 'driver-link';
end;

function ConfigurationEntryJson(const AEntry: TRadIAFireDACConfigurationEntry): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('name', AEntry.Name);
  Result.AddPair('className', AEntry.ComponentClassName);
  Result.AddPair('kind', ConfigurationKindName(AEntry.Kind));
  Result.AddPair('file', AEntry.FileName);
  Result.AddPair('line', TJSONNumber.Create(AEntry.Line));
  Result.AddPair('driverId', AEntry.DriverId);
  Result.AddPair('connectionDefinition', AEntry.ConnectionDefinition);
  Result.AddPair('designTimeConnected', TJSONBool.Create(AEntry.DesignTimeConnected));
  Result.AddPair('loginPromptKnown', TJSONBool.Create(AEntry.LoginPromptKnown));
  Result.AddPair('loginPrompt', TJSONBool.Create(AEntry.LoginPrompt));
  Result.AddPair('optionCount', TJSONNumber.Create(AEntry.OptionCount));
  Result.AddPair('libraryConfigured', TJSONBool.Create(not AEntry.LibraryFileName.IsEmpty));
  Result.AddPair('libraryFileName', AEntry.LibraryFileName);
  Result.AddPair('credentialPresent', TJSONBool.Create(AEntry.HasCredential));
end;

function TRadIAFireDACConfigurationAnalysis.ToJson: string;
var
  LArray: TJSONArray;
  LEntry: TRadIAFireDACConfigurationEntry;
  LFinding: TRadIAFireDACFinding;
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LArray := TJSONArray.Create;
    for LEntry in FEntries do
      LArray.AddElement(ConfigurationEntryJson(LEntry));
    LRoot.AddPair('entries', LArray);
    LArray := TJSONArray.Create;
    for LFinding in FFindings do
      LArray.AddElement(RadIAFireDACFindingToJson(LFinding));
    LRoot.AddPair('findings', LArray);
    LRoot.AddPair('credentialsCollected', TJSONBool.Create(False));
    LRoot.AddPair('sqlExecuted', TJSONBool.Create(False));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIAFireDACConfigurationAnalyzer.QuotedPropertyValue(
  const ALine: string;
  const APropertyName: string
): string;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(
    ALine,
    '(?i)^\s*' + TRegEx.Escape(APropertyName) + '\s*:?=\s*''([^'']*)'''
  );
  if LMatch.Success then
    Result := LMatch.Groups[1].Value
  else
    Result := '';
end;

procedure TRadIAFireDACConfigurationAnalyzer.AddCredentialFinding(
  const AEntry: TRadIAFireDACConfigurationEntry;
  const ALine: Integer;
  const AResult: TRadIAFireDACConfigurationAnalysis
);
begin
  AEntry.HasCredential := True;
  AResult.AddFinding(TRadIAFireDACFinding.Create(
    'firedac.configuration.embedded-credential',
    ffsCritical,
    ffcProven,
    'Embedded FireDAC credential',
    'A FireDAC configuration contains a credential. Its value was discarded.',
    TRadIAFireDACFindingDetails.Create(
      TRadIAFireDACLocation.Create(AEntry.FileName, ALine),
      AEntry.Name,
      'A credential-bearing property is present; its value was not retained.',
      'Move the credential to protected runtime configuration.',
      False
    )
  ));
end;

procedure TRadIAFireDACConfigurationAnalyzer.AddLibraryPathFinding(
  const AEntry: TRadIAFireDACConfigurationEntry;
  const ALine: Integer;
  const AResult: TRadIAFireDACConfigurationAnalysis
);
begin
  AResult.AddFinding(TRadIAFireDACFinding.Create(
    'firedac.configuration.absolute-library-path',
    ffsMedium,
    ffcProven,
    'Absolute driver library path',
    'A FireDAC driver library uses an absolute machine-specific path.',
    TRadIAFireDACFindingDetails.Create(
      TRadIAFireDACLocation.Create(AEntry.FileName, ALine),
      AEntry.Name,
      'An absolute path was detected; only its file name was retained.',
      'Use deployment-aware lookup or a project-relative configuration.',
      False
    )
  ));
end;

function IsCredentialSetting(const ALine: string): Boolean;
begin
  Result := TRegEx.IsMatch(
    ALine,
    '(?i)(?:Password|Pwd|User_Name|User\s*ID|AccessToken|AuthToken)[''"]?\]?\s*:?='
  );
end;

function ParameterValue(const ALine, AName: string): string;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(
    ALine,
    '(?i)''?' + TRegEx.Escape(AName) + '\s*=\s*([^''\r\n)]*)'
  );
  if LMatch.Success then
    Result := LMatch.Groups[1].Value.Trim
  else
    Result := '';
end;

procedure TRadIAFireDACConfigurationAnalyzer.ApplyConnectionLine(
  const ALine: string;
  const ALineNumber: Integer;
  const AEntry: TRadIAFireDACConfigurationEntry;
  const AResult: TRadIAFireDACConfigurationAnalysis
);
var
  LValue: string;
begin
  LValue := QuotedPropertyValue(ALine, 'DriverName');
  if not LValue.IsEmpty then
    AEntry.DriverId := LValue;
  LValue := ParameterValue(ALine, 'DriverID');
  if not LValue.IsEmpty then
    AEntry.DriverId := LValue;
  LValue := QuotedPropertyValue(ALine, 'ConnectionDefName');
  if not LValue.IsEmpty then
    AEntry.ConnectionDefinition := LValue;
  if TRegEx.IsMatch(ALine, '(?i)^\s*Connected\s*:?=\s*True\b') then
    AEntry.DesignTimeConnected := True;
  if TRegEx.IsMatch(ALine, '(?i)^\s*LoginPrompt\s*:?=\s*(True|False)\b') then
  begin
    AEntry.LoginPromptKnown := True;
    AEntry.LoginPrompt := TRegEx.IsMatch(ALine, '(?i)\bTrue\b');
  end;
  if TRegEx.IsMatch(
    ALine,
    '(?i)^\s*(?:ResourceOptions|FormatOptions|UpdateOptions|FetchOptions)\.'
  ) then
    AEntry.OptionCount := AEntry.OptionCount + 1;
  if IsCredentialSetting(ALine) then
    AddCredentialFinding(AEntry, ALineNumber, AResult);
end;

procedure TRadIAFireDACConfigurationAnalyzer.ApplyDriverLine(
  const ALine: string;
  const ALineNumber: Integer;
  const AEntry: TRadIAFireDACConfigurationEntry;
  const AResult: TRadIAFireDACConfigurationAnalysis
);
var
  LValue: string;
begin
  LValue := QuotedPropertyValue(ALine, 'VendorLib');
  if LValue.IsEmpty then
    LValue := QuotedPropertyValue(ALine, 'VendorLibWin64');
  if LValue.IsEmpty then
    Exit;
  AEntry.LibraryFileName := TPath.GetFileName(LValue);
  if TPath.IsPathRooted(LValue) then
    AddLibraryPathFinding(AEntry, ALineNumber, AResult);
end;

procedure TRadIAFireDACConfigurationAnalyzer.AnalyzeEntry(
  const AEntry: TRadIAFireDACConfigurationEntry;
  const AResult: TRadIAFireDACConfigurationAnalysis
);
begin
  if AEntry.DesignTimeConnected then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.configuration.design-time-connected',
      ffsHigh,
      ffcProven,
      'FireDAC connection is active at design time',
      'A FireDAC connection persists Connected=True in project source.',
      TRadIAFireDACFindingDetails.Create(
        TRadIAFireDACLocation.Create(AEntry.FileName, AEntry.Line),
        AEntry.Name,
        'The serialized or assigned Connected property is True.',
        'Keep the connection closed until controlled runtime initialization.',
        True
      )
    ));
  if (AEntry.Kind = fcfgConnection) and AEntry.DriverId.IsEmpty and
    AEntry.ConnectionDefinition.IsEmpty then
    AResult.AddFinding(TRadIAFireDACFinding.Create(
      'firedac.configuration.driver-unresolved',
      ffsLow,
      ffcPossible,
      'FireDAC driver cannot be resolved statically',
      'The connection has no visible DriverID, DriverName, or connection definition.',
      TRadIAFireDACFindingDetails.Create(
        TRadIAFireDACLocation.Create(AEntry.FileName, AEntry.Line),
        AEntry.Name,
        'No deterministic driver selection was found in the analyzed file.',
        'Verify runtime configuration and document the expected driver.',
        False
      )
    ));
end;

procedure TRadIAFireDACConfigurationAnalyzer.AnalyzeDuplicates(
  const AResult: TRadIAFireDACConfigurationAnalysis
);
var
  I: Integer;
  J: Integer;
  LEntry: TRadIAFireDACConfigurationEntry;
  LOther: TRadIAFireDACConfigurationEntry;
begin
  for I := 0 to AResult.FEntries.Count - 1 do
  begin
    LEntry := AResult.FEntries[I];
    if LEntry.ConnectionDefinition.IsEmpty then
      Continue;
    for J := I + 1 to AResult.FEntries.Count - 1 do
    begin
      LOther := AResult.FEntries[J];
      if not SameText(LEntry.ConnectionDefinition, LOther.ConnectionDefinition) then
        Continue;
      AResult.AddFinding(TRadIAFireDACFinding.Create(
        'firedac.configuration.duplicate-connection-definition',
        ffsLow,
        ffcProven,
        'Connection definition is used more than once',
        'Multiple FireDAC connections reference the same connection definition.',
        TRadIAFireDACFindingDetails.Create(
          TRadIAFireDACLocation.Create(LOther.FileName, LOther.Line),
          LOther.Name,
          'The same connection definition name is referenced by multiple components.',
          'Verify that sharing is intentional and options remain consistent.',
          False
        )
      ));
    end;
  end;
end;

function IsDriverLinkClass(const AClassName: string): Boolean;
begin
  Result := TRegEx.IsMatch(AClassName, '(?i)^TFDPhys.+DriverLink$');
end;

function TRadIAFireDACConfigurationAnalyzer.AddDfmEntry(
  const AName: string;
  const AClassName: string;
  const AFileName: string;
  const ALineNumber: Integer;
  const AResult: TRadIAFireDACConfigurationAnalysis
): TRadIAFireDACConfigurationEntry;
begin
  Result := nil;
  if SameText(AClassName, 'TFDConnection') then
    Result := AResult.AddOrGetEntry(
      AName,
      AClassName,
      fcfgConnection,
      AFileName,
      ALineNumber
    )
  else if IsDriverLinkClass(AClassName) then
    Result := AResult.AddOrGetEntry(
      AName,
      AClassName,
      fcfgDriverLink,
      AFileName,
      ALineNumber
    );
end;

function TRadIAFireDACConfigurationAnalyzer.AnalyzeDfm(
  const AContent: string;
  const AFileName: string
): TRadIAFireDACConfigurationAnalysis;
var
  LCurrent: TRadIAFireDACConfigurationEntry;
  LEntry: TRadIAFireDACConfigurationEntry;
  LLine: string;
  LLineNumber: Integer;
  LMatch: TMatch;
begin
  Result := TRadIAFireDACConfigurationAnalysis.Create;
  try
    LCurrent := nil;
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
        LCurrent := AddDfmEntry(
          LMatch.Groups[1].Value,
          LMatch.Groups[2].Value,
          AFileName,
          LLineNumber,
          Result
        );
        Continue;
      end;
      if not Assigned(LCurrent) then
        Continue;
      if LCurrent.Kind = fcfgConnection then
        ApplyConnectionLine(LLine, LLineNumber, LCurrent, Result)
      else
        ApplyDriverLine(LLine, LLineNumber, LCurrent, Result);
    end;
    for LEntry in Result.FEntries do
      AnalyzeEntry(LEntry, Result);
    AnalyzeDuplicates(Result);
  except
    Result.Free;
    raise;
  end;
end;

function PascalLiteralAssignment(
  const ALine: string;
  const APropertyName: string;
  out AName: string;
  out AValue: string
): Boolean;
var
  LMatch: TMatch;
begin
  LMatch := TRegEx.Match(
    ALine,
    '(?i)\b([A-Za-z_][A-Za-z0-9_.]*)\.' + TRegEx.Escape(APropertyName) +
    '\s*:=\s*''([^'']*)'''
  );
  Result := LMatch.Success;
  if Result then
  begin
    AName := LMatch.Groups[1].Value;
    AValue := LMatch.Groups[2].Value;
  end;
end;

procedure TRadIAFireDACConfigurationAnalyzer.AnalyzePascalLine(
  const ALine: string;
  const ALineNumber: Integer;
  const AFileName: string;
  const AResult: TRadIAFireDACConfigurationAnalysis
);
var
  LEntry: TRadIAFireDACConfigurationEntry;
  LMatch: TMatch;
  LName: string;
  LValue: string;
begin
  if ALine.Trim.StartsWith('//') then
    Exit;
  if PascalLiteralAssignment(ALine, 'DriverName', LName, LValue) then
  begin
    LEntry := AResult.AddOrGetEntry(
      LName, 'TFDConnection', fcfgConnection, AFileName, ALineNumber
    );
    LEntry.DriverId := LValue;
  end;
  if PascalLiteralAssignment(ALine, 'ConnectionDefName', LName, LValue) then
  begin
    LEntry := AResult.AddOrGetEntry(
      LName, 'TFDConnection', fcfgConnection, AFileName, ALineNumber
    );
    LEntry.ConnectionDefinition := LValue;
  end;
  LMatch := TRegEx.Match(
    ALine,
    '(?i)\b([A-Za-z_][A-Za-z0-9_.]*)\.Connected\s*:=\s*True\b'
  );
  if LMatch.Success then
  begin
    LName := LMatch.Groups[1].Value;
    LEntry := AResult.AddOrGetEntry(
      LName, 'TFDConnection', fcfgConnection, AFileName, ALineNumber
    );
    LEntry.DesignTimeConnected := True;
  end;
  if PascalLiteralAssignment(ALine, 'VendorLib', LName, LValue) then
  begin
    LEntry := AResult.AddOrGetEntry(
      LName, 'TFDPhysDriverLink', fcfgDriverLink, AFileName, ALineNumber
    );
    LEntry.LibraryFileName := TPath.GetFileName(LValue);
    if TPath.IsPathRooted(LValue) then
      AddLibraryPathFinding(LEntry, ALineNumber, AResult);
  end;
  if not IsCredentialSetting(ALine) then
    Exit;
  LMatch := TRegEx.Match(ALine, '(?i)\b([A-Za-z_][A-Za-z0-9_.]*)\.');
  if LMatch.Success then
    LName := LMatch.Groups[1].Value
  else
    LName := 'FireDACConfiguration';
  LEntry := AResult.AddOrGetEntry(
    LName, 'TFDConnection', fcfgConnection, AFileName, ALineNumber
  );
  AddCredentialFinding(LEntry, ALineNumber, AResult);
end;

function TRadIAFireDACConfigurationAnalyzer.AnalyzePascal(
  const AContent: string;
  const AFileName: string
): TRadIAFireDACConfigurationAnalysis;
var
  LEntry: TRadIAFireDACConfigurationEntry;
  LLine: string;
  LLineNumber: Integer;
begin
  Result := TRadIAFireDACConfigurationAnalysis.Create;
  try
    LLineNumber := 0;
    for LLine in AContent.Split([sLineBreak]) do
    begin
      Inc(LLineNumber);
      AnalyzePascalLine(LLine, LLineNumber, AFileName, Result);
    end;
    for LEntry in Result.FEntries do
      AnalyzeEntry(LEntry, Result);
    AnalyzeDuplicates(Result);
  except
    Result.Free;
    raise;
  end;
end;

end.
