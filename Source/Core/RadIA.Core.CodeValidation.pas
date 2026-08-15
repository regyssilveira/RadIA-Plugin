unit RadIA.Core.CodeValidation;

interface

uses
  System.JSON,
  RadIA.Core.Workspace;

type
  TRadIACodeValidationSource = (
    cvsNative,
    cvsCompiler,
    cvsDelphiLint,
    cvsSonar
  );

  TRadIACodeValidationSeverity = (
    cvsInformation,
    cvsWarning,
    cvsError,
    cvsCritical
  );

  TRadIACodeValidationFinding = record
  private
    FColumn: Integer;
    FFileName: string;
    FLine: Integer;
    FMessage: string;
    FRule: string;
    FSeverity: TRadIACodeValidationSeverity;
    FSource: TRadIACodeValidationSource;
  public
    constructor Create(
      const ASource: TRadIACodeValidationSource;
      const ASeverity: TRadIACodeValidationSeverity;
      const ARule: string;
      const AMessage: string;
      const AFileName: string;
      const ALine: Integer;
      const AColumn: Integer
    );
    function ToJson: TJSONObject;
    property Column: Integer read FColumn;
    property FileName: string read FFileName;
    property Line: Integer read FLine;
    property Rule: string read FRule;
    property Severity: TRadIACodeValidationSeverity read FSeverity;
    property Source: TRadIACodeValidationSource read FSource;
  end;

  TRadIACodeValidationParser = class
  public
    class function ParseDelphiLint(
      const AJson: string;
      out AFindings: TArray<TRadIACodeValidationFinding>;
      out AError: string
    ): Boolean; static;
    class function ParseSonar(
      const AJson: string;
      out AFindings: TArray<TRadIACodeValidationFinding>;
      out AError: string
    ): Boolean; static;
    class function FromCompilerMessages(
      const AMessages: TArray<TRadIACompilerMessage>
    ): TArray<TRadIACodeValidationFinding>; static;
  end;

  TRadIASonarConfiguration = class
  public
    class procedure Resolve(
      const ARootPath: string;
      const AExplicitUrl: string;
      const AExplicitProjectKey: string;
      out AUrl: string;
      out AProjectKey: string
    ); static;
  end;

function RadIAValidationSourceName(
  const ASource: TRadIACodeValidationSource
): string;

function RadIAValidationSeverityName(
  const ASeverity: TRadIACodeValidationSeverity
): string;

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.Math,
  System.SysUtils;

function JsonInteger(
  const AObject: TJSONObject;
  const AName: string;
  const ADefault: Integer = 0
): Integer;
var
  LValue: TJSONValue;
begin
  Result := ADefault;
  LValue := AObject.GetValue(AName);
  if Assigned(LValue) then
    Result := StrToIntDef(LValue.Value, ADefault);
end;

function JsonText(
  const AObject: TJSONObject;
  const AName: string
): string;
var
  LValue: TJSONValue;
begin
  Result := '';
  LValue := AObject.GetValue(AName);
  if Assigned(LValue) and not (LValue is TJSONNull) then
    Result := LValue.Value;
end;

function DelphiLintSeverity(const ARule: string): TRadIACodeValidationSeverity;
begin
  if ARule.ToLower.Contains('security') then
    Exit(cvsError);
  Result := cvsWarning;
end;

function SonarSeverity(const AValue: string): TRadIACodeValidationSeverity;
begin
  if SameText(AValue, 'BLOCKER') then
    Exit(cvsCritical);
  if SameText(AValue, 'CRITICAL') then
    Exit(cvsError);
  if SameText(AValue, 'MAJOR') or SameText(AValue, 'HIGH') then
    Exit(cvsWarning);
  Result := cvsInformation;
end;

function CompilerSeverity(
  const AValue: TRadIACompilerMessageSeverity
): TRadIACodeValidationSeverity;
begin
  case AValue of
    cmsFatal: Result := cvsCritical;
    cmsError: Result := cvsError;
    cmsWarning: Result := cvsWarning;
  else
    Result := cvsInformation;
  end;
end;

function ReadPropertyValue(
  const AFileName: string;
  const AName: string
): string;
var
  LLine: string;
  LRawLine: string;
  LSeparator: Integer;
begin
  Result := '';
  if not TFile.Exists(AFileName) then
    Exit;
  for LRawLine in TFile.ReadAllLines(AFileName, TEncoding.UTF8) do
  begin
    LLine := LRawLine.Trim;
    if LLine.IsEmpty or LLine.StartsWith('#') then
      Continue;
    LSeparator := LLine.IndexOf('=');
    if (LSeparator > 0) and
      SameText(LLine.Substring(0, LSeparator).Trim, AName) then
      Exit(LLine.Substring(LSeparator + 1).Trim);
  end;
end;

class procedure TRadIASonarConfiguration.Resolve(
  const ARootPath: string;
  const AExplicitUrl: string;
  const AExplicitProjectKey: string;
  out AUrl: string;
  out AProjectKey: string
);
var
  LProperties: string;
  LReport: string;
begin
  AUrl := AExplicitUrl.TrimRight(['/']);
  AProjectKey := AExplicitProjectKey;
  LProperties := TPath.Combine(ARootPath, 'sonar-project.properties');
  LReport := TPath.Combine(
    TPath.Combine(ARootPath, '.scannerwork'),
    'report-task.txt'
  );
  if AProjectKey.IsEmpty then
    AProjectKey := ReadPropertyValue(LProperties, 'sonar.projectKey');
  if AProjectKey.IsEmpty then
    AProjectKey := ReadPropertyValue(LReport, 'projectKey');
  if AUrl.IsEmpty then
    AUrl := GetEnvironmentVariable('SONAR_HOST_URL').TrimRight(['/']);
  if AUrl.IsEmpty then
    AUrl := ReadPropertyValue(LProperties, 'sonar.host.url').TrimRight(['/']);
  if AUrl.IsEmpty then
    AUrl := ReadPropertyValue(LReport, 'serverUrl').TrimRight(['/']);
end;

function RadIAValidationSourceName(
  const ASource: TRadIACodeValidationSource
): string;
begin
  case ASource of
    cvsCompiler: Result := 'compiler';
    cvsDelphiLint: Result := 'delphilint';
    cvsSonar: Result := 'sonar';
  else
    Result := 'native';
  end;
end;

function RadIAValidationSeverityName(
  const ASeverity: TRadIACodeValidationSeverity
): string;
begin
  case ASeverity of
    cvsWarning: Result := 'warning';
    cvsError: Result := 'error';
    cvsCritical: Result := 'critical';
  else
    Result := 'information';
  end;
end;

constructor TRadIACodeValidationFinding.Create(
  const ASource: TRadIACodeValidationSource;
  const ASeverity: TRadIACodeValidationSeverity;
  const ARule: string;
  const AMessage: string;
  const AFileName: string;
  const ALine: Integer;
  const AColumn: Integer
);
begin
  FSource := ASource;
  FSeverity := ASeverity;
  FRule := ARule;
  FMessage := AMessage;
  FFileName := AFileName;
  FLine := Max(0, ALine);
  FColumn := Max(0, AColumn);
end;

function TRadIACodeValidationFinding.ToJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('source', RadIAValidationSourceName(FSource));
  Result.AddPair('severity', RadIAValidationSeverityName(FSeverity));
  Result.AddPair('code', FRule);
  Result.AddPair('rule', FRule);
  Result.AddPair('message', FMessage);
  Result.AddPair('fileName', FFileName);
  Result.AddPair('line', TJSONNumber.Create(FLine));
  Result.AddPair('column', TJSONNumber.Create(FColumn));
end;

class function TRadIACodeValidationParser.FromCompilerMessages(
  const AMessages: TArray<TRadIACompilerMessage>
): TArray<TRadIACodeValidationFinding>;
var
  LFindings: TList<TRadIACodeValidationFinding>;
  LMessage: TRadIACompilerMessage;
begin
  LFindings := TList<TRadIACodeValidationFinding>.Create;
  try
    for LMessage in AMessages do
      LFindings.Add(TRadIACodeValidationFinding.Create(
        cvsCompiler,
        CompilerSeverity(LMessage.Severity),
        'compiler-message',
        LMessage.Text,
        LMessage.FileName,
        LMessage.Line,
        LMessage.Column
      ));
    Result := LFindings.ToArray;
  finally
    LFindings.Free;
  end;
end;

class function TRadIACodeValidationParser.ParseDelphiLint(
  const AJson: string;
  out AFindings: TArray<TRadIACodeValidationFinding>;
  out AError: string
): Boolean;
var
  LFindings: TList<TRadIACodeValidationFinding>;
  LIssue: TJSONValue;
  LIssues: TJSONArray;
  LObject: TJSONObject;
  LRange: TJSONObject;
  LRoot: TJSONValue;
  LRule: string;
begin
  Result := False;
  AFindings := nil;
  AError := '';
  LRoot := TJSONObject.ParseJSONValue(AJson);
  if not (LRoot is TJSONObject) then
  begin
    LRoot.Free;
    AError := 'DelphiLint response must be a JSON object.';
    Exit;
  end;
  LFindings := TList<TRadIACodeValidationFinding>.Create;
  try
    LIssues := TJSONObject(LRoot).GetValue('issues') as TJSONArray;
    if not Assigned(LIssues) then
    begin
      AError := 'DelphiLint response does not contain an issues array.';
      Exit;
    end;
    for LIssue in LIssues do
    begin
      if not (LIssue is TJSONObject) then
        Continue;
      LObject := TJSONObject(LIssue);
      LRange := LObject.GetValue('textRange') as TJSONObject;
      LRule := JsonText(LObject, 'ruleKey');
      LFindings.Add(TRadIACodeValidationFinding.Create(
        cvsDelphiLint,
        DelphiLintSeverity(LRule),
        LRule,
        JsonText(LObject, 'message'),
        JsonText(LObject, 'file'),
        IfThen(Assigned(LRange), JsonInteger(LRange, 'startLine'), 0),
        IfThen(Assigned(LRange), JsonInteger(LRange, 'startOffset') + 1, 0)
      ));
    end;
    AFindings := LFindings.ToArray;
    Result := True;
  finally
    LFindings.Free;
    LRoot.Free;
  end;
end;

class function TRadIACodeValidationParser.ParseSonar(
  const AJson: string;
  out AFindings: TArray<TRadIACodeValidationFinding>;
  out AError: string
): Boolean;
var
  LComponents: TDictionary<string, string>;
  LFindings: TList<TRadIACodeValidationFinding>;
  LIssue: TJSONValue;
  LIssues: TJSONArray;
  LItem: TJSONValue;
  LItems: TJSONArray;
  LObject: TJSONObject;
  LRange: TJSONObject;
  LRoot: TJSONValue;
  LFileName: string;
begin
  Result := False;
  AFindings := nil;
  AError := '';
  LRoot := TJSONObject.ParseJSONValue(AJson);
  if not (LRoot is TJSONObject) then
  begin
    LRoot.Free;
    AError := 'Sonar response must be a JSON object.';
    Exit;
  end;
  LComponents := TDictionary<string, string>.Create;
  LFindings := TList<TRadIACodeValidationFinding>.Create;
  try
    LItems := TJSONObject(LRoot).GetValue('components') as TJSONArray;
    if Assigned(LItems) then
      for LItem in LItems do
        if LItem is TJSONObject then
          LComponents.AddOrSetValue(
            JsonText(TJSONObject(LItem), 'key'),
            JsonText(TJSONObject(LItem), 'path')
          );
    LIssues := TJSONObject(LRoot).GetValue('issues') as TJSONArray;
    if not Assigned(LIssues) then
    begin
      AError := 'Sonar response does not contain an issues array.';
      Exit;
    end;
    for LIssue in LIssues do
    begin
      if not (LIssue is TJSONObject) then
        Continue;
      LObject := TJSONObject(LIssue);
      LFileName := JsonText(LObject, 'component');
      LComponents.TryGetValue(LFileName, LFileName);
      LRange := LObject.GetValue('textRange') as TJSONObject;
      LFindings.Add(TRadIACodeValidationFinding.Create(
        cvsSonar,
        SonarSeverity(JsonText(LObject, 'severity')),
        JsonText(LObject, 'rule'),
        JsonText(LObject, 'message'),
        LFileName,
        JsonInteger(LObject, 'line'),
        IfThen(Assigned(LRange), JsonInteger(LRange, 'startOffset') + 1, 0)
      ));
    end;
    AFindings := LFindings.ToArray;
    Result := True;
  finally
    LFindings.Free;
    LComponents.Free;
    LRoot.Free;
  end;
end;

end.
