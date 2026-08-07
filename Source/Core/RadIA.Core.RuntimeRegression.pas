unit RadIA.Core.RuntimeRegression;

interface

uses
  RadIA.Core.ToolSecurity,
  RadIA.Core.Workspace,
  RadIA.Core.WorkspaceBoundary;

type
  IRadIARuntimeRegressionCoordinator = interface
    ['{AB40521E-19B4-4AF1-B431-A927D2C4D884}']
    function Apply(const APreviewId: string): string;
    function Get(const ARegressionId: string): string;
    function List: string;
    function Prepare(
      const ARegressionId: string;
      const AScenarioJson: string
    ): string;
    function Revert(const AApplicationId: string): string;
  end;

  TRadIARuntimeRegressionCoordinator = class(
    TInterfacedObject,
    IRadIARuntimeRegressionCoordinator
  )
  private
    FApplications: TObject;
    FBoundary: IRadIAWorkspaceBoundary;
    FPreviews: TObject;
    FRedactor: IRadIASecretRedactor;
    FWorkspace: IRadIAWorkspaceFacade;
    function ActiveRoot: string;
    function ArtifactPath(
      const ARootPath: string;
      const ARegressionId: string
    ): string;
    function BuildArtifact(
      const ARegressionId: string;
      const AScenarioJson: string;
      const AFingerprint: string
    ): string;
    function ValidateRegressionId(
      const ARegressionId: string
    ): string;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABoundary: IRadIAWorkspaceBoundary;
      const ARedactor: IRadIASecretRedactor
    );
    destructor Destroy; override;
    function Apply(const APreviewId: string): string;
    function Get(const ARegressionId: string): string;
    function List: string;
    function Prepare(
      const ARegressionId: string;
      const AScenarioJson: string
    ): string;
    function Revert(const AApplicationId: string): string;
  end;

implementation

uses
  System.Character,
  System.DateUtils,
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  Winapi.Windows;

const
  CArtifactSchemaVersion = 1;
  CMaxArtifactBytes = 1024 * 1024;

type
  TRadIARuntimeRegressionPreview = class
  private
    FArtifactJson: string;
    FFingerprint: string;
    FPath: string;
    FPreviewId: string;
    FPreviousExists: Boolean;
    FPreviousContent: string;
    FRegressionId: string;
    FRootPath: string;
  end;

  TRadIARuntimeRegressionApplication = class
  private
    FApplicationId: string;
    FAppliedContent: string;
    FPath: string;
    FPreviousExists: Boolean;
    FPreviousContent: string;
    FRootPath: string;
  end;

  TRadIARuntimeRegressionPreviewDictionary =
    TObjectDictionary<string, TRadIARuntimeRegressionPreview>;
  TRadIARuntimeRegressionApplicationDictionary =
    TObjectDictionary<string, TRadIARuntimeRegressionApplication>;

function NewRuntimeRegressionId: string;
begin
  Result := LowerCase(
    TGUID.NewGuid.ToString.Replace('{', '').Replace('}', '').Replace('-', '')
  );
end;

function JsonFingerprint(const AJson: string): string;
begin
  Result := LowerCase(
    THashSHA2.GetHashString(
      AJson,
      THashSHA2.TSHA2Version.SHA256
    )
  );
end;

function CanonicalJsonObject(const AJson: string): string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if not Assigned(LRoot) then
    raise EArgumentException.Create(
      'Runtime regression scenario must be a JSON object.'
    );
  try
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function ValidateArtifactContent(
  const AContent: string;
  const AExpectedId: string
): Boolean;
var
  LFingerprint: string;
  LRoot: TJSONObject;
  LScenario: TJSONValue;
begin
  Result := False;
  LRoot := TJSONObject.ParseJSONValue(AContent) as TJSONObject;
  if not Assigned(LRoot) then
    Exit;
  try
    LScenario := LRoot.GetValue('scenario');
    LFingerprint := LRoot.GetValue<string>('fingerprint', '');
    Result :=
      (LRoot.GetValue<Integer>('schemaVersion', 0) =
        CArtifactSchemaVersion) and
      SameText(LRoot.GetValue<string>('id', ''), AExpectedId) and
      (LScenario is TJSONObject) and
      SameText(
        LFingerprint,
        JsonFingerprint(LScenario.ToJSON)
      );
  finally
    LRoot.Free;
  end;
end;

procedure WriteAtomicText(
  const AFileName: string;
  const AContent: string
);
var
  LDirectory: string;
  LTemporaryFile: string;
begin
  LDirectory := ExtractFileDir(AFileName);
  TDirectory.CreateDirectory(LDirectory);
  LTemporaryFile := AFileName + '.tmp-' + NewRuntimeRegressionId;
  TFile.WriteAllText(LTemporaryFile, AContent, TEncoding.UTF8);
  try
    if not MoveFileEx(
      PChar(LTemporaryFile),
      PChar(AFileName),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH
    ) then
      RaiseLastOSError;
  finally
    if TFile.Exists(LTemporaryFile) then
      TFile.Delete(LTemporaryFile);
  end;
end;

function BuildPreviewJson(
  const APreview: TRadIARuntimeRegressionPreview
): string;
var
  LRoot: TJSONObject;
begin
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('previewId', APreview.FPreviewId);
    LRoot.AddPair('regressionId', APreview.FRegressionId);
    LRoot.AddPair('relativePath', TPath.GetFileName(APreview.FPath));
    LRoot.AddPair('fingerprint', APreview.FFingerprint);
    LRoot.AddPair(
      'overwritesExisting',
      TJSONBool.Create(APreview.FPreviousExists)
    );
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

{ TRadIARuntimeRegressionCoordinator }

function TRadIARuntimeRegressionCoordinator.ActiveRoot: string;
var
  LProject: TRadIAProjectSnapshot;
begin
  LProject := FWorkspace.GetActiveProject;
  if Trim(LProject.RootPath) = '' then
    raise EInvalidOp.Create(
      'An active project with an existing root directory is required.'
    );
  Result := ExcludeTrailingPathDelimiter(
    TPath.GetFullPath(LProject.RootPath)
  );
  if (Result = '') or not TDirectory.Exists(Result) then
    raise EInvalidOp.Create(
      'An active project with an existing root directory is required.'
    );
end;

function TRadIARuntimeRegressionCoordinator.Apply(
  const APreviewId: string
): string;
var
  LApplication: TRadIARuntimeRegressionApplication;
  LApplicationId: string;
  LPreview: TRadIARuntimeRegressionPreview;
  LRoot: TJSONObject;
begin
  LApplication := nil;
  TMonitor.Enter(FPreviews);
  try
    if not TRadIARuntimeRegressionPreviewDictionary(FPreviews).TryGetValue(
      APreviewId,
      LPreview
    ) then
      raise EArgumentException.Create(
        'Runtime regression preview id is unknown or expired.'
      );
    if not SameText(ActiveRoot, LPreview.FRootPath) then
      raise EInvalidOp.Create(
        'Active project changed after the runtime regression preview.'
      );
    if not SameText(
      ArtifactPath(LPreview.FRootPath, LPreview.FRegressionId),
      LPreview.FPath
    ) then
      raise EInvalidOp.Create(
        'Runtime regression path changed after preview.'
      );
    if TFile.Exists(LPreview.FPath) <> LPreview.FPreviousExists then
      raise EInvalidOp.Create(
        'Runtime regression artifact changed after preview.'
      );
    if LPreview.FPreviousExists and
      (
        TFile.ReadAllText(LPreview.FPath, TEncoding.UTF8) <>
        LPreview.FPreviousContent
      ) then
      raise EInvalidOp.Create(
        'Runtime regression artifact changed after preview.'
      );
    WriteAtomicText(LPreview.FPath, LPreview.FArtifactJson);
    LApplication := TRadIARuntimeRegressionApplication.Create;
    LApplicationId := NewRuntimeRegressionId;
    LApplication.FApplicationId := LApplicationId;
    LApplication.FAppliedContent := LPreview.FArtifactJson;
    LApplication.FPath := LPreview.FPath;
    LApplication.FPreviousExists := LPreview.FPreviousExists;
    LApplication.FPreviousContent := LPreview.FPreviousContent;
    LApplication.FRootPath := LPreview.FRootPath;
    TMonitor.Enter(FApplications);
    try
      TRadIARuntimeRegressionApplicationDictionary(FApplications).Add(
        LApplication.FApplicationId,
        LApplication
      );
      LApplication := nil;
    finally
      TMonitor.Exit(FApplications);
    end;
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair(
        'applicationId',
        LApplicationId
      );
      LRoot.AddPair('regressionId', LPreview.FRegressionId);
      LRoot.AddPair('fingerprint', LPreview.FFingerprint);
      Result := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
    TRadIARuntimeRegressionPreviewDictionary(FPreviews).Remove(APreviewId);
  finally
    TMonitor.Exit(FPreviews);
    LApplication.Free;
  end;
end;

function TRadIARuntimeRegressionCoordinator.ArtifactPath(
  const ARootPath: string;
  const ARegressionId: string
): string;
var
  LCandidate: string;
  LValidation: TRadIAPathValidation;
begin
  LCandidate := TPath.Combine(
    TPath.Combine(ARootPath, '.radia\runtime-scenarios'),
    ARegressionId + '.json'
  );
  LValidation := FBoundary.ValidatePath(ARootPath, LCandidate);
  if not LValidation.Allowed then
    raise EInvalidOp.Create(LValidation.ErrorMessage);
  Result := LValidation.ResolvedPath;
end;

function TRadIARuntimeRegressionCoordinator.BuildArtifact(
  const ARegressionId: string;
  const AScenarioJson: string;
  const AFingerprint: string
): string;
var
  LRoot: TJSONObject;
  LScenario: TJSONValue;
begin
  LScenario := TJSONObject.ParseJSONValue(AScenarioJson);
  if not (LScenario is TJSONObject) then
  begin
    LScenario.Free;
    raise EArgumentException.Create(
      'Runtime regression scenario must be a JSON object.'
    );
  end;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair(
      'schemaVersion',
      TJSONNumber.Create(CArtifactSchemaVersion)
    );
    LRoot.AddPair('id', ARegressionId);
    LRoot.AddPair(
      'savedAtUtc',
      DateToISO8601(TTimeZone.Local.ToUniversalTime(Now), True)
    );
    LRoot.AddPair('fingerprint', AFingerprint);
    LRoot.AddPair('scenario', LScenario);
    LScenario := nil;
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
    LScenario.Free;
  end;
end;

constructor TRadIARuntimeRegressionCoordinator.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABoundary: IRadIAWorkspaceBoundary;
  const ARedactor: IRadIASecretRedactor
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABoundary) then
    raise EArgumentNilException.Create('ABoundary');
  if not Assigned(ARedactor) then
    raise EArgumentNilException.Create('ARedactor');
  FWorkspace := AWorkspace;
  FBoundary := ABoundary;
  FRedactor := ARedactor;
  FPreviews := TRadIARuntimeRegressionPreviewDictionary.Create(
    [doOwnsValues]
  );
  FApplications := TRadIARuntimeRegressionApplicationDictionary.Create(
    [doOwnsValues]
  );
end;

destructor TRadIARuntimeRegressionCoordinator.Destroy;
begin
  FApplications.Free;
  FPreviews.Free;
  inherited;
end;

function TRadIARuntimeRegressionCoordinator.Get(
  const ARegressionId: string
): string;
var
  LFileName: string;
  LRegressionId: string;
begin
  LRegressionId := ValidateRegressionId(ARegressionId);
  LFileName := ArtifactPath(
    ActiveRoot,
    LRegressionId
  );
  if not TFile.Exists(LFileName) then
    raise EArgumentException.Create(
      'Runtime regression id was not found.'
    );
  if TFile.GetSize(LFileName) > CMaxArtifactBytes then
    raise EInvalidOp.Create(
      'Runtime regression artifact exceeds the size limit.'
    );
  Result := TFile.ReadAllText(LFileName, TEncoding.UTF8);
  if not ValidateArtifactContent(Result, LRegressionId) then
    raise EInvalidOp.Create(
      'Runtime regression artifact failed schema or integrity validation.'
    );
end;

function TRadIARuntimeRegressionCoordinator.List: string;
var
  LArray: TJSONArray;
  LDirectory: string;
  LFileName: string;
  LItem: TJSONObject;
  LRoot: TJSONObject;
  LRootPath: string;
begin
  LRootPath := ActiveRoot;
  LDirectory := ExtractFileDir(
    ArtifactPath(LRootPath, 'runtime-regression-probe')
  );
  LArray := TJSONArray.Create;
  LRoot := TJSONObject.Create;
  try
    LRoot.AddPair('regressions', LArray);
    if TDirectory.Exists(LDirectory) then
      for LFileName in TDirectory.GetFiles(LDirectory, '*.json') do
      begin
        LItem := TJSONObject.Create;
        LItem.AddPair(
          'id',
          TPath.GetFileNameWithoutExtension(LFileName)
        );
        LItem.AddPair(
          'relativePath',
          '.radia/runtime-scenarios/' + TPath.GetFileName(LFileName)
        );
        LArray.AddElement(LItem);
      end;
    LRoot.AddPair('count', TJSONNumber.Create(LArray.Count));
    Result := LRoot.ToJSON;
  finally
    LRoot.Free;
  end;
end;

function TRadIARuntimeRegressionCoordinator.Prepare(
  const ARegressionId: string;
  const AScenarioJson: string
): string;
var
  LCanonicalScenario: string;
  LFingerprint: string;
  LPreview: TRadIARuntimeRegressionPreview;
  LRootPath: string;
begin
  LCanonicalScenario := CanonicalJsonObject(AScenarioJson);
  if Length(LCanonicalScenario) > CMaxArtifactBytes then
    raise EArgumentOutOfRangeException.Create(
      'Runtime regression scenario exceeds the size limit.'
    );
  if not SameText(
    FRedactor.Redact(LCanonicalScenario),
    LCanonicalScenario
  ) then
    raise EArgumentException.Create(
      'Runtime regression scenario contains sensitive data.'
    );
  LRootPath := ActiveRoot;
  LFingerprint := JsonFingerprint(LCanonicalScenario);
  LPreview := TRadIARuntimeRegressionPreview.Create;
  try
    LPreview.FPreviewId := NewRuntimeRegressionId;
    LPreview.FRegressionId := ValidateRegressionId(ARegressionId);
    LPreview.FRootPath := LRootPath;
    LPreview.FPath := ArtifactPath(
      LRootPath,
      LPreview.FRegressionId
    );
    LPreview.FFingerprint := LFingerprint;
    LPreview.FArtifactJson := BuildArtifact(
      LPreview.FRegressionId,
      LCanonicalScenario,
      LFingerprint
    );
    if TFile.Exists(LPreview.FPath) then
    begin
      if TFile.GetSize(LPreview.FPath) > CMaxArtifactBytes then
        raise EInvalidOp.Create(
          'Existing runtime regression artifact exceeds the size limit.'
        );
      LPreview.FPreviousExists := True;
      LPreview.FPreviousContent := TFile.ReadAllText(
        LPreview.FPath,
        TEncoding.UTF8
      );
    end;
    Result := BuildPreviewJson(LPreview);
    TMonitor.Enter(FPreviews);
    try
      TRadIARuntimeRegressionPreviewDictionary(FPreviews).Add(
        LPreview.FPreviewId,
        LPreview
      );
      LPreview := nil;
    finally
      TMonitor.Exit(FPreviews);
    end;
  finally
    LPreview.Free;
  end;
end;

function TRadIARuntimeRegressionCoordinator.Revert(
  const AApplicationId: string
): string;
var
  LApplication: TRadIARuntimeRegressionApplication;
  LRoot: TJSONObject;
begin
  TMonitor.Enter(FApplications);
  try
    if not TRadIARuntimeRegressionApplicationDictionary(
      FApplications
    ).TryGetValue(AApplicationId, LApplication) then
      raise EArgumentException.Create(
        'Runtime regression application id is unknown or expired.'
      );
    if not SameText(ActiveRoot, LApplication.FRootPath) then
      raise EInvalidOp.Create(
        'Active project changed after saving the runtime regression.'
      );
    if not SameText(
      FBoundary.ValidatePath(
        LApplication.FRootPath,
        LApplication.FPath
      ).ResolvedPath,
      LApplication.FPath
    ) then
      raise EInvalidOp.Create(
        'Runtime regression path is no longer authorized.'
      );
    if not TFile.Exists(LApplication.FPath) or
      (
        TFile.ReadAllText(LApplication.FPath, TEncoding.UTF8) <>
        LApplication.FAppliedContent
      ) then
      raise EInvalidOp.Create(
        'Runtime regression artifact changed after it was saved.'
      );
    if not LApplication.FPreviousExists then
    begin
      if TFile.Exists(LApplication.FPath) then
        TFile.Delete(LApplication.FPath);
    end
    else
      WriteAtomicText(
        LApplication.FPath,
        LApplication.FPreviousContent
      );
    LRoot := TJSONObject.Create;
    try
      LRoot.AddPair('applicationId', AApplicationId);
      LRoot.AddPair('reverted', TJSONBool.Create(True));
      Result := LRoot.ToJSON;
    finally
      LRoot.Free;
    end;
    TRadIARuntimeRegressionApplicationDictionary(FApplications).Remove(
      AApplicationId
    );
  finally
    TMonitor.Exit(FApplications);
  end;
end;

function TRadIARuntimeRegressionCoordinator.ValidateRegressionId(
  const ARegressionId: string
): string;
var
  LCharacter: Char;
begin
  Result := LowerCase(Trim(ARegressionId));
  if (Length(Result) < 3) or (Length(Result) > 64) then
    raise EArgumentException.Create(
      'Runtime regression id must contain 3 to 64 characters.'
    );
  for LCharacter in Result do
    if not LCharacter.IsLetterOrDigit and (LCharacter <> '-') then
      raise EArgumentException.Create(
        'Runtime regression id accepts letters, digits, and hyphens only.'
      );
end;

end.
