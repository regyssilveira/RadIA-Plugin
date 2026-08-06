unit RadIA.Core.ProjectHealthTools;

interface

uses
  RadIA.Core.Build,
  RadIA.Core.DUnitX,
  RadIA.Core.Knowledge,
  RadIA.Core.Tools,
  RadIA.Core.Workspace;

procedure RegisterRadIAProjectHealthTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABuild: IRadIABuildFacade;
  const ATests: IRadIADUnitXRunner;
  const AKnowledge: IRadIAKnowledgeService
);

implementation

uses
  System.JSON,
  System.SysUtils;

type
  TRadIAProjectHealthTool = class(TInterfacedObject, IRadIATool)
  private
    FBuild: IRadIABuildFacade;
    FKnowledge: IRadIAKnowledgeService;
    FTests: IRadIADUnitXRunner;
    FWorkspace: IRadIAWorkspaceFacade;
    procedure AddRisk(
      const ARisks: TJSONArray;
      const ASeverity: string;
      const ACode: string;
      const AMessage: string;
      const ARecommendedCommand: string
    );
    function CalculateScore(const ARisks: TJSONArray): Integer;
    function HealthName(const ARisks: TJSONArray): string;
    function NextAction(const ARisks: TJSONArray): string;
    function BuildStatusName: string;
    function TestStatusName: string;
  public
    constructor Create(
      const AWorkspace: IRadIAWorkspaceFacade;
      const ABuild: IRadIABuildFacade;
      const ATests: IRadIADUnitXRunner;
      const AKnowledge: IRadIAKnowledgeService
    );
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

const
  CEmptyInputSchema =
    '{"type":"object","additionalProperties":false}';

constructor TRadIAProjectHealthTool.Create(
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABuild: IRadIABuildFacade;
  const ATests: IRadIADUnitXRunner;
  const AKnowledge: IRadIAKnowledgeService
);
begin
  inherited Create;
  if not Assigned(AWorkspace) then
    raise EArgumentNilException.Create('AWorkspace');
  if not Assigned(ABuild) then
    raise EArgumentNilException.Create('ABuild');
  if not Assigned(ATests) then
    raise EArgumentNilException.Create('ATests');
  if not Assigned(AKnowledge) then
    raise EArgumentNilException.Create('AKnowledge');
  FWorkspace := AWorkspace;
  FBuild := ABuild;
  FTests := ATests;
  FKnowledge := AKnowledge;
end;

procedure TRadIAProjectHealthTool.AddRisk(
  const ARisks: TJSONArray;
  const ASeverity: string;
  const ACode: string;
  const AMessage: string;
  const ARecommendedCommand: string
);
var
  LRisk: TJSONObject;
begin
  LRisk := TJSONObject.Create;
  LRisk.AddPair('severity', ASeverity);
  LRisk.AddPair('code', ACode);
  LRisk.AddPair('message', AMessage);
  LRisk.AddPair('recommendedCommand', ARecommendedCommand);
  ARisks.AddElement(LRisk);
end;

function TRadIAProjectHealthTool.CalculateScore(
  const ARisks: TJSONArray
): Integer;
var
  LIndex: Integer;
  LRisk: TJSONObject;
  LSeverity: string;
begin
  Result := 100;
  for LIndex := 0 to ARisks.Count - 1 do
  begin
    LRisk := ARisks[LIndex] as TJSONObject;
    LSeverity := LRisk.GetValue<string>('severity', '');
    if SameText(LSeverity, 'critical') then
      Dec(Result, 50)
    else if SameText(LSeverity, 'high') then
      Dec(Result, 25)
    else if SameText(LSeverity, 'medium') then
      Dec(Result, 10);
  end;
  if Result < 0 then
    Result := 0;
end;

function TRadIAProjectHealthTool.HealthName(
  const ARisks: TJSONArray
): string;
begin
  if ARisks.Count = 0 then
    Result := 'healthy'
  else
    Result := 'attention';
end;

function TRadIAProjectHealthTool.NextAction(
  const ARisks: TJSONArray
): string;
begin
  if ARisks.Count = 0 then
    Exit('/agent run Review project health');
  Result := (ARisks[0] as TJSONObject).GetValue<string>(
    'recommendedCommand',
    ''
  );
end;

function TRadIAProjectHealthTool.BuildStatusName: string;
begin
  case FBuild.GetStatus of
    bsIdle:
      Result := 'idle';
    bsRunning:
      Result := 'running';
    bsSucceeded:
      Result := 'succeeded';
    bsFailed:
      Result := 'failed';
    bsCancelled:
      Result := 'cancelled';
    bsTimedOut:
      Result := 'timedOut';
    bsUnsupported:
      Result := 'unsupported';
  else
    Result := 'unknown';
  end;
end;

function TRadIAProjectHealthTool.TestStatusName: string;
begin
  case FTests.GetStatus of
    drsIdle:
      Result := 'idle';
    drsRunning:
      Result := 'running';
    drsSucceeded:
      Result := 'succeeded';
    drsFailed:
      Result := 'failed';
    drsCancelled:
      Result := 'cancelled';
    drsTimedOut:
      Result := 'timedOut';
  else
    Result := 'unknown';
  end;
end;

function TRadIAProjectHealthTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
var
  LBuildStatus: string;
  LErrorCount: Integer;
  LHealth: string;
  LIDE: TRadIAIDEState;
  LKnowledge: TRadIAKnowledgeStatus;
  LMessage: TRadIACompilerMessage;
  LProject: TRadIAProjectSnapshot;
  LRoot: TJSONObject;
  LRisks: TJSONArray;
  LScore: Integer;
  LTestStatus: string;
begin
  LIDE := FWorkspace.GetIDEState;
  LProject := FWorkspace.GetActiveProject;
  LBuildStatus := BuildStatusName;
  LTestStatus := TestStatusName;
  LKnowledge := FKnowledge.GetStatus(LProject.FileName);
  LErrorCount := 0;
  for LMessage in FWorkspace.GetCompilerMessages(200) do
    if LMessage.Severity in [cmsError, cmsFatal] then
      Inc(LErrorCount);

  LRoot := TJSONObject.Create;
  try
    LRisks := TJSONArray.Create;
    LRoot.AddPair('risks', LRisks);
    if LIDE.ShuttingDown then
      AddRisk(
        LRisks,
        'critical',
        'ide_shutting_down',
        'The IDE is shutting down.',
        ''
      );
    if LProject.FileName.Trim.IsEmpty then
      AddRisk(
        LRisks,
        'critical',
        'no_active_project',
        'No active Delphi project was found.',
        '/journey create'
      );
    if LErrorCount > 0 then
      AddRisk(
        LRisks,
        'high',
        'compiler_errors',
        Format('%d compiler error messages require attention.', [LErrorCount]),
        '/journey fix-build'
      );
    if SameText(LBuildStatus, 'failed') or SameText(LBuildStatus, 'timedOut') then
      AddRisk(
        LRisks,
        'high',
        'build_unhealthy',
        'The latest build did not succeed.',
        '/journey fix-build'
      );
    if SameText(LTestStatus, 'failed') or SameText(LTestStatus, 'timedOut') then
      AddRisk(
        LRisks,
        'high',
        'tests_unhealthy',
        'The latest test run did not succeed.',
        '/journey tests'
      );
    if not LKnowledge.Loaded and not LProject.FileName.Trim.IsEmpty then
      AddRisk(
        LRisks,
        'medium',
        'knowledge_not_indexed',
        'Local project knowledge has not been indexed.',
        '/tool RebuildProjectKnowledge {}'
      );
    LHealth := HealthName(LRisks);
    LScore := CalculateScore(LRisks);
    LRoot.AddPair('health', LHealth);
    LRoot.AddPair('score', TJSONNumber.Create(LScore));
    LRoot.AddPair('nextAction', NextAction(LRisks));
    LRoot.AddPair('projectName', LProject.Name);
    LRoot.AddPair('projectFile', LProject.FileName);
    LRoot.AddPair('configuration', LProject.Configuration);
    LRoot.AddPair('platform', LProject.Platform);
    LRoot.AddPair('ideVersion', LIDE.VersionName);
    LRoot.AddPair('idePlatform', LIDE.Platform);
    LRoot.AddPair('buildStatus', LBuildStatus);
    LRoot.AddPair('testStatus', LTestStatus);
    LRoot.AddPair('compilerErrorCount', TJSONNumber.Create(LErrorCount));
    LRoot.AddPair('knowledgeLoaded', TJSONBool.Create(LKnowledge.Loaded));
    LRoot.AddPair('knowledgeFiles', TJSONNumber.Create(LKnowledge.FileCount));
    LRoot.AddPair('knowledgeChunks', TJSONNumber.Create(LKnowledge.ChunkCount));
    Result := TRadIAToolResult.Succeeded(LRoot.ToJSON);
  finally
    LRoot.Free;
  end;
end;

function TRadIAProjectHealthTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetProjectHealth',
    '1.1.0',
    'Scores project health and recommends prioritized Delphi journeys.',
    CEmptyInputSchema,
    '{"type":"object"}',
    trReadOnly
  );
end;

procedure RegisterRadIAProjectHealthTools(
  const ARegistry: IRadIAToolRegistry;
  const AWorkspace: IRadIAWorkspaceFacade;
  const ABuild: IRadIABuildFacade;
  const ATests: IRadIADUnitXRunner;
  const AKnowledge: IRadIAKnowledgeService
);
begin
  if not Assigned(ARegistry) then
    raise EArgumentNilException.Create('ARegistry');
  ARegistry.RegisterTool(
    TRadIAProjectHealthTool.Create(
      AWorkspace,
      ABuild,
      ATests,
      AKnowledge
    )
  );
end;

end.
