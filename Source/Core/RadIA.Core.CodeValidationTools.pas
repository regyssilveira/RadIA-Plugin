unit RadIA.Core.CodeValidationTools;

interface

uses
  RadIA.Core.Build,
  RadIA.Core.Interfaces,
  RadIA.Core.Patches,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

procedure RegisterRadIACodeValidationTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const AHttpClient: IRadIAHttpClient;
  const ABuild: IRadIABuildFacade
);

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.JSON,
  System.NetEncoding,
  System.Net.URLClient,
  System.StrUtils,
  System.SysUtils,
  RadIA.Core.CodeValidation,
  RadIA.Core.DelphiLintAdapter,
  RadIA.Core.SaveReview;

type
  TRadIACodeValidationRequest = record
  private
    FIncludeCompiler: Boolean;
    FBuildBeforeValidation: Boolean;
    FIncludeDelphiLint: Boolean;
    FIncludeSonar: Boolean;
    FMaxFindings: Integer;
    FScope: string;
    FSonarProjectKey: string;
    FSonarUrl: string;
  public
    constructor Create(
      const AScope: string;
      const AIncludeCompiler: Boolean;
      const AIncludeDelphiLint: Boolean;
      const AIncludeSonar: Boolean;
      const AMaxFindings: Integer;
      const ASonarUrl: string;
      const ASonarProjectKey: string
    );
    function WithBuildBeforeValidation(
      const AValue: Boolean
    ): TRadIACodeValidationRequest;
    property IncludeCompiler: Boolean read FIncludeCompiler;
    property BuildBeforeValidation: Boolean read FBuildBeforeValidation;
    property IncludeDelphiLint: Boolean read FIncludeDelphiLint;
    property IncludeSonar: Boolean read FIncludeSonar;
    property MaxFindings: Integer read FMaxFindings;
    property Scope: string read FScope;
    property SonarProjectKey: string read FSonarProjectKey;
    property SonarUrl: string read FSonarUrl;
  end;

  TRadIAValidateDelphiCodeTool = class(TInterfacedObject, IRadIATool)
  private
    FHttpClient: IRadIAHttpClient;
    FBuild: IRadIABuildFacade;
    FDelphiLint: IRadIADelphiLintAdapter;
    FMutation: IRadIAEditorMutationFacade;
    FWorkspace: IRadIAWorkspaceFacade;
    procedure AddCompilerFindings(
      const ARequest: TRadIACodeValidationRequest;
      const AFindings: TList<TRadIACodeValidationFinding>;
      const ASources: TJSONArray
    );
    procedure AddBuildStatus(
      const ARequest: TRadIACodeValidationRequest;
      const ASources: TJSONArray
    );
    procedure AddDelphiLintFindings(
      const ARequest: TRadIACodeValidationRequest;
      const AProject: TRadIAProjectSnapshot;
      const AFindings: TList<TRadIACodeValidationFinding>;
      const ASources: TJSONArray
    );
    procedure AddNativeFindings(
      const ARequest: TRadIACodeValidationRequest;
      const AFindings: TList<TRadIACodeValidationFinding>;
      const ASources: TJSONArray
    );
    procedure AddSonarFindings(
      const ARequest: TRadIACodeValidationRequest;
      const AProject: TRadIAProjectSnapshot;
      const AFindings: TList<TRadIACodeValidationFinding>;
      const ASources: TJSONArray
    );
    function LoadRequest(
      const AJson: string;
      out ARequest: TRadIACodeValidationRequest;
      out AError: string
    ): Boolean;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const AMutation: IRadIAEditorMutationFacade;
      const AHttpClient: IRadIAHttpClient;
      const ABuild: IRadIABuildFacade
    );
    function Execute(const ARequest: TRadIAToolRequest): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CInputSchema =
    '{"type":"object","properties":{"scope":{"type":"string",' +
    '"enum":["activeUnit","project"]},"buildBeforeValidation":' +
    '{"type":"boolean"},"includeCompiler":' +
    '{"type":"boolean"},"includeDelphiLint":{"type":"boolean"},' +
    '"includeSonar":{"type":"boolean"},"maxFindings":{"type":' +
    '"integer","minimum":1,"maximum":500},"sonarUrl":{"type":' +
    '"string"},"sonarProjectKey":{"type":"string"}},' +
    '"additionalProperties":false}';
  COutputSchema =
    '{"type":"object","required":["status","scope","findingCount",' +
    '"findings","sources"],"properties":{"status":{"type":"string"},' +
    '"scope":{"type":"string"},"findingCount":{"type":"integer"},' +
    '"findings":{"type":"array"},"sources":{"type":"array"}}}';
  CMaxFileCharacters = 2 * 1024 * 1024;

function SourceStatus(
  const AName: string;
  const AStatus: string;
  const AMessage: string;
  const AAction: string = ''
): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('source', AName);
  Result.AddPair('status', AStatus);
  Result.AddPair('message', AMessage);
  Result.AddPair('action', AAction);
end;

function TRadIACodeValidationRequest.WithBuildBeforeValidation(
  const AValue: Boolean
): TRadIACodeValidationRequest;
begin
  Result := Self;
  Result.FBuildBeforeValidation := AValue;
end;

procedure AppendFindings(
  const ATarget: TList<TRadIACodeValidationFinding>;
  const AItems: TArray<TRadIACodeValidationFinding>;
  const AMaxCount: Integer
);
var
  LItem: TRadIACodeValidationFinding;
begin
  for LItem in AItems do
  begin
    if ATarget.Count >= AMaxCount then
      Exit;
    ATarget.Add(LItem);
  end;
end;

procedure ResolveSonarConfiguration(
  const AProject: TRadIAProjectSnapshot;
  const ARequest: TRadIACodeValidationRequest;
  out AUrl: string;
  out AProjectKey: string
);
begin
  TRadIASonarConfiguration.Resolve(
    AProject.RootPath,
    ARequest.SonarUrl,
    ARequest.SonarProjectKey,
    AUrl,
    AProjectKey
  );
end;

constructor TRadIACodeValidationRequest.Create(
  const AScope: string;
  const AIncludeCompiler: Boolean;
  const AIncludeDelphiLint: Boolean;
  const AIncludeSonar: Boolean;
  const AMaxFindings: Integer;
  const ASonarUrl: string;
  const ASonarProjectKey: string
);
begin
  FScope := AScope;
  FIncludeCompiler := AIncludeCompiler;
  FIncludeDelphiLint := AIncludeDelphiLint;
  FIncludeSonar := AIncludeSonar;
  FMaxFindings := AMaxFindings;
  FSonarUrl := ASonarUrl;
  FSonarProjectKey := ASonarProjectKey;
end;

constructor TRadIAValidateDelphiCodeTool.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const AHttpClient: IRadIAHttpClient;
  const ABuild: IRadIABuildFacade
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(AMutation) then
    raise EArgumentNilException.Create('AMutation');
  if not Assigned(AHttpClient) then
    raise EArgumentNilException.Create('AHttpClient');
  if not Assigned(ABuild) then
    raise EArgumentNilException.Create('ABuild');
  FWorkspace := AWorkspace;
  FMutation := AMutation;
  FHttpClient := AHttpClient;
  FBuild := ABuild;
  FDelphiLint := CreateRadIADelphiLintAdapter;
end;

procedure TRadIAValidateDelphiCodeTool.AddBuildStatus(
  const ARequest: TRadIACodeValidationRequest;
  const ASources: TJSONArray
);
var
  LResult: TRadIABuildResult;
begin
  if not ARequest.BuildBeforeValidation then
  begin
    ASources.AddElement(SourceStatus(
      'build',
      'not-requested',
      'A fresh compiler check was not requested.'
    ));
    Exit;
  end;
  LResult := FBuild.Execute(TRadIABuildRequest.Create(bmCheck, 120000, True));
  if LResult.Success then
    ASources.AddElement(SourceStatus(
      'build',
      'passed',
      Format('Fresh compiler check completed in %d ms.', [LResult.DurationMs])
    ))
  else
    ASources.AddElement(SourceStatus(
      'build',
      'failed',
      Format('Fresh compiler check did not pass; %d message(s) were returned.', [
        Length(LResult.Messages)
      ]),
      'Open the compiler findings below and fix the reported errors.'
    ));
end;

procedure TRadIAValidateDelphiCodeTool.AddCompilerFindings(
  const ARequest: TRadIACodeValidationRequest;
  const AFindings: TList<TRadIACodeValidationFinding>;
  const ASources: TJSONArray
);
var
  LItems: TArray<TRadIACodeValidationFinding>;
begin
  if not ARequest.IncludeCompiler then
  begin
    ASources.AddElement(SourceStatus('compiler', 'not-requested',
      'Compiler messages were not requested.'));
    Exit;
  end;
  LItems := TRadIACodeValidationParser.FromCompilerMessages(
    FWorkspace.GetCompilerMessages(ARequest.MaxFindings)
  );
  AppendFindings(AFindings, LItems, ARequest.MaxFindings);
  ASources.AddElement(SourceStatus(
    'compiler',
    IfThen(Length(LItems) = 0, 'passed', 'findings'),
    Format('%d current compiler message(s) collected.', [Length(LItems)]),
    'Run BuildProject first when fresh compiler evidence is required.'
  ));
end;

procedure TRadIAValidateDelphiCodeTool.AddDelphiLintFindings(
  const ARequest: TRadIACodeValidationRequest;
  const AProject: TRadIAProjectSnapshot;
  const AFindings: TList<TRadIACodeValidationFinding>;
  const ASources: TJSONArray
);
var
  LError: string;
  LFiles: TArray<string>;
  LItems: TArray<TRadIACodeValidationFinding>;
  LProperties: string;
  LResult: TRadIADelphiLintResult;
  LSonarKey: string;
  LSonarToken: string;
  LSonarUrl: string;
begin
  if not ARequest.IncludeDelphiLint then
  begin
    ASources.AddElement(SourceStatus('delphilint', 'not-requested',
      'DelphiLint analysis was not requested.'));
    Exit;
  end;
  if SameText(ARequest.Scope, 'activeUnit') then
    LFiles := [FWorkspace.GetActiveUnit]
  else
    LFiles := FWorkspace.ListProjectUnits;
  ResolveSonarConfiguration(AProject, ARequest, LSonarUrl, LSonarKey);
  LSonarToken := '';
  if SameText(
    GetEnvironmentVariable('SONAR_HOST_URL').TrimRight(['/']),
    LSonarUrl
  ) then
    LSonarToken := GetEnvironmentVariable('SONAR_TOKEN');
  LProperties := TPath.Combine(AProject.RootPath, 'sonar-project.properties');
  if not TFile.Exists(LProperties) then
    LProperties := '';
  LResult := FDelphiLint.Analyze(TRadIADelphiLintRequest.Create(
    AProject.RootPath,
    LFiles,
    LSonarUrl,
    LSonarKey,
    LSonarToken,
    LProperties
  ), 30000);
  if not LResult.Succeeded then
  begin
    ASources.AddElement(SourceStatus(
      'delphilint',
      LResult.Status,
      LResult.Error,
      'Install DelphiLint from https://github.com/' +
      'integrated-application-development/delphilint/releases and configure Java.'
    ));
    Exit;
  end;
  if not TRadIACodeValidationParser.ParseDelphiLint(
    LResult.ResponseJson,
    LItems,
    LError
  ) then
  begin
    ASources.AddElement(SourceStatus(
      'delphilint',
      'invalid-response',
      LError,
      'Update DelphiLint or run /doctor --deep to inspect the adapter.'
    ));
    Exit;
  end;
  AppendFindings(AFindings, LItems, ARequest.MaxFindings);
  ASources.AddElement(SourceStatus(
    'delphilint',
    IfThen(Length(LItems) = 0, 'passed', 'findings'),
    Format('%d DelphiLint issue(s) collected.', [Length(LItems)])
  ));
end;

procedure TRadIAValidateDelphiCodeTool.AddNativeFindings(
  const ARequest: TRadIACodeValidationRequest;
  const AFindings: TList<TRadIACodeValidationFinding>;
  const ASources: TJSONArray
);
var
  LContent: TRadIAEditorContent;
  LFileName: string;
  LFinding: TRadIASaveReviewFinding;
  LFiles: TArray<string>;
begin
  if SameText(ARequest.Scope, 'activeUnit') then
    LFiles := [FWorkspace.GetActiveUnit]
  else
    LFiles := FWorkspace.ListProjectUnits;
  for LFileName in LFiles do
  begin
    if AFindings.Count >= ARequest.MaxFindings then
      Break;
    if SameText(ARequest.Scope, 'activeUnit') then
      LContent := FWorkspace.GetEditorContent(CMaxFileCharacters)
    else
      LContent := FMutation.ReadContent(LFileName, CMaxFileCharacters);
    if LContent.Truncated or LContent.Content.IsEmpty then
      Continue;
    for LFinding in TRadIASaveReviewAnalyzer.Analyze(
      LContent.Content,
      ARequest.MaxFindings - AFindings.Count
    ) do
      AFindings.Add(TRadIACodeValidationFinding.Create(
        cvsNative,
        cvsWarning,
        'radia-native-style',
        LFinding.Message,
        LContent.FileName,
        LFinding.Line,
        1
      ));
  end;
  ASources.AddElement(SourceStatus(
    'native',
    IfThen(AFindings.Count = 0, 'passed', 'findings'),
    'RadIA native deterministic rules were evaluated.'
  ));
end;

procedure TRadIAValidateDelphiCodeTool.AddSonarFindings(
  const ARequest: TRadIACodeValidationRequest;
  const AProject: TRadIAProjectSnapshot;
  const AFindings: TList<TRadIACodeValidationFinding>;
  const ASources: TJSONArray
);
var
  LError: string;
  LHeaders: TNetHeaders;
  LItems: TArray<TRadIACodeValidationFinding>;
  LJson: string;
  LToken: string;
  LTokenHost: string;
  LUrl: string;
  LSonarProjectKey: string;
  LSonarUrl: string;
begin
  if not ARequest.IncludeSonar then
  begin
    ASources.AddElement(SourceStatus('sonar', 'not-requested',
      'Sonar analysis was not requested.'));
    Exit;
  end;
  ResolveSonarConfiguration(
    AProject,
    ARequest,
    LSonarUrl,
    LSonarProjectKey
  );
  if LSonarUrl.IsEmpty or LSonarProjectKey.IsEmpty then
  begin
    ASources.AddElement(SourceStatus(
      'sonar',
      'not-configured',
      'Sonar URL or project key could not be discovered.',
      'Create sonar-project.properties, run a local scan, or provide ' +
      'sonarUrl and sonarProjectKey. Authentication uses SONAR_TOKEN.'
    ));
    Exit;
  end;
  SetLength(LHeaders, 0);
  LToken := GetEnvironmentVariable('SONAR_TOKEN');
  LTokenHost := GetEnvironmentVariable('SONAR_HOST_URL').TrimRight(['/']);
  if not LToken.IsEmpty and
    SameText(LTokenHost, LSonarUrl) then
  begin
    SetLength(LHeaders, 1);
    LHeaders[0] := TNetHeader.Create(
      'Authorization',
      'Basic ' + TNetEncoding.Base64.Encode(LToken + ':')
    );
  end;
  LUrl := LSonarUrl +
    '/api/issues/search?componentKeys=' +
    TNetEncoding.URL.Encode(LSonarProjectKey) + '&resolved=false&ps=500';
  try
    LJson := FHttpClient.Get(LUrl, LHeaders, 15000);
    if not TRadIACodeValidationParser.ParseSonar(LJson, LItems, LError) then
      raise EInvalidOpException.Create(LError);
    AppendFindings(AFindings, LItems, ARequest.MaxFindings);
    ASources.AddElement(SourceStatus(
      'sonar',
      IfThen(Length(LItems) = 0, 'passed', 'findings'),
      Format('%d current Sonar issue(s) collected for %s.', [
        Length(LItems),
        AProject.Name
      ])
    ));
  except
    on E: Exception do
      ASources.AddElement(SourceStatus(
        'sonar',
        'error',
        'Sonar could not be queried: ' + E.Message,
        'Verify the URL, project key, SONAR_TOKEN, and server availability.'
      ));
  end;
end;

function TRadIAValidateDelphiCodeTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LFinding: TRadIACodeValidationFinding;
  LFindings: TList<TRadIACodeValidationFinding>;
  LFindingsJson: TJSONArray;
  LJson: TJSONObject;
  LParsed: TRadIACodeValidationRequest;
  LProject: TRadIAProjectSnapshot;
  LSources: TJSONArray;
  LError: string;
begin
  if not LoadRequest(ARequest.ArgumentsJson, LParsed, LError) then
    Exit(TRadIAToolResult.Failed('invalid_request', LError));
  LProject := FWorkspace.GetActiveProject;
  if LProject.RootPath.IsEmpty then
    Exit(TRadIAToolResult.Failed(
      'project_required',
      'Open a Delphi project before running project code validation.'
    ));
  LFindings := TList<TRadIACodeValidationFinding>.Create;
  LJson := TJSONObject.Create;
  try
    LSources := TJSONArray.Create;
    AddNativeFindings(LParsed, LFindings, LSources);
    AddBuildStatus(LParsed, LSources);
    AddCompilerFindings(LParsed, LFindings, LSources);
    AddDelphiLintFindings(LParsed, LProject, LFindings, LSources);
    AddSonarFindings(LParsed, LProject, LFindings, LSources);
    LFindingsJson := TJSONArray.Create;
    for LFinding in LFindings do
      LFindingsJson.AddElement(LFinding.ToJson);
    LJson.AddPair('status', IfThen(LFindings.Count = 0, 'passed', 'findings'));
    LJson.AddPair('scope', LParsed.Scope);
    LJson.AddPair('findingCount', TJSONNumber.Create(LFindings.Count));
    LJson.AddPair('findings', LFindingsJson);
    LJson.AddPair('sources', LSources);
    Result := TRadIAToolResult.Succeeded(LJson.ToJSON);
  finally
    LJson.Free;
    LFindings.Free;
  end;
end;

function TRadIAValidateDelphiCodeTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'ValidateDelphiCode',
    '1.0.0',
    'Validates Delphi code with native, compiler, DelphiLint, and Sonar evidence.',
    CInputSchema,
    COutputSchema,
    trExecution
  ).WithExecutionOptions(30000, True);
end;

function TRadIAValidateDelphiCodeTool.LoadRequest(
  const AJson: string;
  out ARequest: TRadIACodeValidationRequest;
  out AError: string
): Boolean;
var
  LJson: TJSONObject;
  LMaxFindings: Integer;
  LScope: string;
begin
  Result := False;
  AError := '';
  LJson := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if not Assigned(LJson) then
  begin
    AError := 'Validation arguments must be a JSON object.';
    Exit;
  end;
  try
    LScope := LJson.GetValue<string>('scope', 'activeUnit');
    LMaxFindings := LJson.GetValue<Integer>('maxFindings', 200);
    if not MatchText(LScope, ['activeUnit', 'project']) or
      (LMaxFindings < 1) or (LMaxFindings > 500) then
    begin
      AError := 'Validation scope or maxFindings is invalid.';
      Exit;
    end;
    ARequest := TRadIACodeValidationRequest.Create(
      LScope,
      LJson.GetValue<Boolean>('includeCompiler', True),
      LJson.GetValue<Boolean>('includeDelphiLint', True),
      LJson.GetValue<Boolean>('includeSonar', True),
      LMaxFindings,
      LJson.GetValue<string>('sonarUrl', ''),
      LJson.GetValue<string>('sonarProjectKey', '')
    ).WithBuildBeforeValidation(
      LJson.GetValue<Boolean>('buildBeforeValidation', False)
    );
    Result := True;
  finally
    LJson.Free;
  end;
end;

procedure RegisterRadIACodeValidationTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const AMutation: IRadIAEditorMutationFacade;
  const AHttpClient: IRadIAHttpClient;
  const ABuild: IRadIABuildFacade
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(TRadIAValidateDelphiCodeTool.Create(
    AWorkspace,
    AMutation,
    AHttpClient,
    ABuild
  ));
end;

end.
