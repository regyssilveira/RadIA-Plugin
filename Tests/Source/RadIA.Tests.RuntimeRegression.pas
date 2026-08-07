unit RadIA.Tests.RuntimeRegression;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeDebugSession,
  RadIA.Core.RuntimeRegression,
  RadIA.Core.RuntimeScenario,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

type
  TMockRadIARuntimeRegressionWorkspace = class(
    TInterfacedObject,
    IRadIAWorkspaceFacade
  )
  private
    FRootPath: string;
  public
    constructor Create(const ARootPath: string);
    function GetActiveProject: TRadIAProjectSnapshot;
    function GetActiveUnit: string;
    function GetCompilerMessages(
      const AMaxCount: Integer
    ): TArray<TRadIACompilerMessage>;
    function GetCursorPosition: TRadIAEditorPosition;
    function GetEditorContent(
      const AMaxCharacters: Integer
    ): TRadIAEditorContent;
    function GetEditorSelection: TRadIAEditorSelection;
    function GetIDEState: TRadIAIDEState;
    function ListOpenFiles: TArray<string>;
    function ListProjectUnits: TArray<string>;
  end;

  TMockRadIARuntimeRegressionAction = class(
    TInterfacedObject,
    IRadIARuntimeActionFacade
  )
  public
    function ExecuteAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
    function ValidateAction(
      const ASession: TRadIARuntimeSessionIdentity;
      const AAction: TRadIARuntimeScenarioAction
    ): TRadIARuntimeActionResult;
  end;

  [TestFixture]
  TTestRadIARuntimeRegression = class
  private
    FDebugCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FDirectory: string;
    FRegistry: IRadIAToolRegistry;
    FRegression: IRadIARuntimeRegressionCoordinator;
    FScenario: IRadIARuntimeScenarioCoordinator;
    function ExecuteTool(
      const AName: string;
      const AArguments: string
    ): TRadIAToolResult;
    function JsonValue(
      const AJson: string;
      const AName: string
    ): string;
    function ScenarioJson: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure SavesListsPreparesAndRevertsRegression;
    [Test]
    procedure RejectsSessionOpaqueTargetsAndSensitiveValues;
    [Test]
    procedure RejectsTamperedArtifact;
    [Test]
    procedure RefusesArtifactChangedAfterPreview;
  end;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.JSON,
  System.SysUtils,
  RadIA.Core.RuntimeRegressionTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.ToolSecurity,
  RadIA.Core.WorkspaceBoundary;

{ TMockRadIARuntimeRegressionWorkspace }

constructor TMockRadIARuntimeRegressionWorkspace.Create(
  const ARootPath: string
);
begin
  inherited Create;
  FRootPath := ARootPath;
end;

function TMockRadIARuntimeRegressionWorkspace.GetActiveProject:
  TRadIAProjectSnapshot;
begin
  Result := TRadIAProjectSnapshot.Create(
    'RuntimeRegression',
    TPath.Combine(FRootPath, 'RuntimeRegression.dproj'),
    FRootPath,
    'Debug',
    'Win32'
  );
end;

function TMockRadIARuntimeRegressionWorkspace.GetActiveUnit: string;
begin
  Result := '';
end;

function TMockRadIARuntimeRegressionWorkspace.GetCompilerMessages(
  const AMaxCount: Integer
): TArray<TRadIACompilerMessage>;
begin
  Result := [];
end;

function TMockRadIARuntimeRegressionWorkspace.GetCursorPosition:
  TRadIAEditorPosition;
begin
  Result := Default(TRadIAEditorPosition);
end;

function TMockRadIARuntimeRegressionWorkspace.GetEditorContent(
  const AMaxCharacters: Integer
): TRadIAEditorContent;
begin
  Result := Default(TRadIAEditorContent);
end;

function TMockRadIARuntimeRegressionWorkspace.GetEditorSelection:
  TRadIAEditorSelection;
begin
  Result := Default(TRadIAEditorSelection);
end;

function TMockRadIARuntimeRegressionWorkspace.GetIDEState:
  TRadIAIDEState;
begin
  Result := Default(TRadIAIDEState);
end;

function TMockRadIARuntimeRegressionWorkspace.ListOpenFiles:
  TArray<string>;
begin
  Result := [];
end;

function TMockRadIARuntimeRegressionWorkspace.ListProjectUnits:
  TArray<string>;
begin
  Result := [];
end;

{ TMockRadIARuntimeRegressionAction }

function TMockRadIARuntimeRegressionAction.ExecuteAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Result := TRadIARuntimeActionResult.Succeeded;
end;

function TMockRadIARuntimeRegressionAction.ValidateAction(
  const ASession: TRadIARuntimeSessionIdentity;
  const AAction: TRadIARuntimeScenarioAction
): TRadIARuntimeActionResult;
begin
  Result := TRadIARuntimeActionResult.Succeeded;
end;

{ TTestRadIARuntimeRegression }

function TTestRadIARuntimeRegression.ExecuteTool(
  const AName: string;
  const AArguments: string
): TRadIAToolResult;
begin
  Result := FRegistry.Resolve(AName).Execute(
    TRadIAToolRequest.Create(
      AName,
      AArguments,
      'runtime-regression-test'
    )
  );
end;

function TTestRadIARuntimeRegression.JsonValue(
  const AJson: string;
  const AName: string
): string;
var
  LJson: TJSONObject;
begin
  LJson := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  try
    Assert.IsNotNull(LJson);
    Result := LJson.GetValue<string>(AName, '');
  finally
    LJson.Free;
  end;
end;

procedure TTestRadIARuntimeRegression.
  RefusesArtifactChangedAfterPreview;
var
  LFileName: string;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'PrepareRuntimeRegression',
    '{"regressionId":"stale-preview","scenario":' +
    ScenarioJson + '}'
  );
  Assert.IsTrue(LResult.Success);
  LPreviewId := JsonValue(LResult.ContentJson, 'previewId');
  LFileName := TPath.Combine(
    FDirectory,
    '.radia\runtime-scenarios\stale-preview.json'
  );
  TDirectory.CreateDirectory(ExtractFileDir(LFileName));
  TFile.WriteAllText(LFileName, '{"externalChange":true}');
  LResult := ExecuteTool(
    'SaveRuntimeRegression',
    '{"previewId":"' + LPreviewId + '"}'
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual(
    'runtime_regression_unavailable',
    LResult.ErrorCode
  );
  Assert.AreEqual(
    '{"externalChange":true}',
    TFile.ReadAllText(LFileName)
  );
end;

procedure TTestRadIARuntimeRegression.
  RejectsSessionOpaqueTargetsAndSensitiveValues;
var
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'PrepareRuntimeRegression',
    '{"regressionId":"opaque-target","scenario":{' +
    '"name":"Opaque target","limits":{"maxActions":1,' +
    '"maxDurationMs":5000,"maxRepetitions":1},"actions":[' +
    '{"kind":"invoke","targetId":"' + StringOfChar('a', 64) +
    '","timeoutMs":1000}]}}'
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual(
    'runtime_regression_not_replayable',
    LResult.ErrorCode
  );

  LResult := ExecuteTool(
    'PrepareRuntimeRegression',
    '{"regressionId":"sensitive-target","scenario":' +
    ScenarioJson.Replace(
      '"actions":',
      '"password":"secret-value","actions":'
    ) + '}'
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual('invalid_runtime_regression', LResult.ErrorCode);
end;

procedure TTestRadIARuntimeRegression.RejectsTamperedArtifact;
var
  LApplicationId: string;
  LFileName: string;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'PrepareRuntimeRegression',
    '{"regressionId":"tamper-check","scenario":' +
    ScenarioJson + '}'
  );
  Assert.IsTrue(LResult.Success);
  LPreviewId := JsonValue(LResult.ContentJson, 'previewId');
  LResult := ExecuteTool(
    'SaveRuntimeRegression',
    '{"previewId":"' + LPreviewId + '"}'
  );
  Assert.IsTrue(LResult.Success);
  LApplicationId := JsonValue(LResult.ContentJson, 'applicationId');
  LFileName := TPath.Combine(
    FDirectory,
    '.radia\runtime-scenarios\tamper-check.json'
  );
  TFile.WriteAllText(
    LFileName,
    TFile.ReadAllText(LFileName).Replace(
      '"name":"Cancel access violation"',
      '"name":"Changed without fingerprint"'
    )
  );
  LResult := ExecuteTool(
    'PrepareSavedRuntimeScenario',
    '{"regressionId":"tamper-check"}'
  );
  Assert.IsFalse(LResult.Success);
  Assert.AreEqual(
    'runtime_regression_unavailable',
    LResult.ErrorCode
  );
  Assert.IsFalse(
    ExecuteTool(
      'RevertRuntimeRegression',
      '{"applicationId":"' + LApplicationId + '"}'
    ).Success
  );
end;

function TTestRadIARuntimeRegression.ScenarioJson: string;
begin
  Result :=
    '{"name":"Cancel access violation","limits":{' +
    '"maxActions":1,"maxDurationMs":5000,"maxRepetitions":10},' +
    '"actions":[{"kind":"cancel","selector":{' +
    '"className":"TButton","text":"Cancel",' +
    '"parentPath":"TTargetForm[0]"},' +
    '"timeoutMs":1000}]}';
end;

procedure TTestRadIARuntimeRegression.
  SavesListsPreparesAndRevertsRegression;
var
  LApplicationId: string;
  LFileName: string;
  LPreviewId: string;
  LResult: TRadIAToolResult;
begin
  LResult := ExecuteTool(
    'PrepareRuntimeRegression',
    '{"regressionId":"cancel-av","scenario":' +
    ScenarioJson + '}'
  );
  Assert.IsTrue(LResult.Success);
  LPreviewId := JsonValue(LResult.ContentJson, 'previewId');
  Assert.AreEqual(32, Length(LPreviewId));

  LResult := ExecuteTool(
    'SaveRuntimeRegression',
    '{"previewId":"' + LPreviewId + '"}'
  );
  Assert.IsTrue(LResult.Success);
  LApplicationId := JsonValue(LResult.ContentJson, 'applicationId');
  LFileName := TPath.Combine(
    FDirectory,
    '.radia\runtime-scenarios\cancel-av.json'
  );
  Assert.IsTrue(TFile.Exists(LFileName));
  Assert.Contains(
    ExecuteTool('ListRuntimeRegressions', '{}').ContentJson,
    '"id":"cancel-av"'
  );

  LResult := ExecuteTool(
    'PrepareSavedRuntimeScenario',
    '{"regressionId":"cancel-av"}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"repetitions":10');

  LResult := ExecuteTool(
    'RevertRuntimeRegression',
    '{"applicationId":"' + LApplicationId + '"}'
  );
  Assert.IsTrue(LResult.Success);
  Assert.IsFalse(TFile.Exists(LFileName));
end;

procedure TTestRadIARuntimeRegression.Setup;
var
  LActionFacade: IRadIARuntimeActionFacade;
  LSessionId: string;
  LWorkspace: IRadIAWorkspaceFacade;
begin
  FDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-RuntimeRegression-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FDirectory);
  LWorkspace := TMockRadIARuntimeRegressionWorkspace.Create(FDirectory);
  FRegression := TRadIARuntimeRegressionCoordinator.Create(
    LWorkspace,
    TRadIAWorkspaceBoundary.Create,
    TRadIASecretRedactor.Create
  );
  FDebugCoordinator := TRadIARuntimeDebugSessionCoordinator.Create;
  LSessionId := FDebugCoordinator.BeginSession(
    TPath.Combine(FDirectory, 'RuntimeRegression.dproj')
  );
  Assert.IsTrue(
    FDebugCoordinator.AttachProcess(
      LSessionId,
      100,
      IncSecond(Now, -1),
      TPath.Combine(FDirectory, 'RuntimeRegression.exe'),
      'runtime-regression-build'
    )
  );
  LActionFacade := TMockRadIARuntimeRegressionAction.Create;
  FScenario := TRadIARuntimeScenarioCoordinator.Create(LActionFacade);
  FRegistry := TRadIAToolRegistry.Create;
  RegisterRadIARuntimeRegressionTools(
    FRegistry,
    FRegression,
    FDebugCoordinator,
    FScenario
  );
end;

procedure TTestRadIARuntimeRegression.TearDown;
begin
  FRegistry := nil;
  FScenario := nil;
  FDebugCoordinator := nil;
  FRegression := nil;
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimeRegression);

end.
