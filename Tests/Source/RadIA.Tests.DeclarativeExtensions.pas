unit RadIA.Tests.DeclarativeExtensions;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.DeclarativeExtensions;

type
  [TestFixture]
  TRadIADeclarativeExtensionTests = class
  private
    FDirectory: string;
    FManager: TRadIADeclarativeExtensionManager;
    procedure WriteManifest(
      const AFileName: string;
      const AContent: string
    );
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure LoadsAndResolvesCommandWithoutRestart;
    [Test]
    procedure ReloadRemovesDeletedManifest;
    [Test]
    procedure RejectsReservedCommandAtomically;
    [Test]
    procedure RequiresExplicitMinimalPermission;
    [Test]
    procedure ReportsDisabledManifest;
    [Test]
    procedure RejectsOversizedManifestBeforeParsing;
    [Test]
    procedure InstallsUpdatesAndActivatesManifestAtomically;
    [Test]
    procedure InvalidUpdateRollsBackWorkingManifest;
    [Test]
    procedure EnablesDisablesAndRemovesWithoutRestart;
    [Test]
    procedure RemovesRejectedManifestByDiagnosticFile;
    [Test]
    procedure LoadsSchemaTwoTemplatesAndSkills;
    [Test]
    procedure RejectsDuplicateCommandsAcrossCapabilityKinds;
    [Test]
    procedure SchemaOneDoesNotEnableSkills;
    [Test]
    procedure LoadsSchemaThreeDeclarativeToolContract;
    [Test]
    procedure LoadsSchemaFourTeamJourneysAndPolicies;
    [Test]
    procedure LoadsAndExecutesSchemaFiveWorkflow;
    [Test]
    procedure RejectsWorkflowWithoutExplicitPermission;
    [Test]
    procedure BinderRejectsWorkflowTargetingDeclarativeCapability;
    [Test]
    procedure RejectsSchemaFourCredentialFields;
    [Test]
    procedure RejectsDeclarativeToolWithoutExplicitPermission;
    [Test]
    procedure RejectsDeclarativeToolOutsideExtensionNamespace;
    [Test]
    procedure BindsDeclarativeToolWithInheritedPolicyMetadata;
    [Test]
    procedure BinderRejectsUnknownOrChainedTargets;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.DeclarativeTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools;

type
  TRadIATestTargetTool = class(TInterfacedObject, IRadIATool)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIATestExecutionTool = class(TInterfacedObject, IRadIATool)
  public
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    function GetDescriptor: TRadIAToolDescriptor;
  end;

  TRadIATestWorkflowExecutor = class(
    TInterfacedObject,
    IRadIAToolExecutor
  )
  private
    FCallCount: Integer;
    FInner: IRadIAToolExecutor;
  public
    constructor Create(const AInner: IRadIAToolExecutor);
    function Execute(
      const ARequest: TRadIAToolRequest
    ): TRadIAToolResult;
    property CallCount: Integer read FCallCount;
  end;

const
  CValidManifest =
    '{"schemaVersion":1,"id":"TeamCommands","version":"1.0.0",' +
    '"enabled":true,"permissions":["chat.prompt"],"commands":[{' +
    '"name":"Team review","description":"Apply the team review policy.",' +
    '"command":"/team-review","prompt":"Review using the team policy: {code}"' +
    '}]}';

function TRadIATestTargetTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Result := TRadIAToolResult.Succeeded(
    '{"target":"' + ARequest.ToolName + '"}'
  );
end;

function TRadIATestTargetTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'GetProjectHealth',
    '1.0.0',
    'Returns project health.',
    '{"type":"object"}',
    '{"type":"object"}',
    trReadOnly
  ).WithExecutionOptions(5000, True);
end;

{ TRadIATestExecutionTool }

function TRadIATestExecutionTool.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Result := TRadIAToolResult.Succeeded(
    '{"target":"' + ARequest.ToolName + '"}'
  );
end;

function TRadIATestExecutionTool.GetDescriptor: TRadIAToolDescriptor;
begin
  Result := TRadIAToolDescriptor.Create(
    'BuildProject',
    '1.0.0',
    'Builds a project.',
    '{"type":"object"}',
    '{"type":"object"}',
    trExecution
  ).WithExecutionOptions(10000, False);
end;

{ TRadIATestWorkflowExecutor }

constructor TRadIATestWorkflowExecutor.Create(
  const AInner: IRadIAToolExecutor
);
begin
  inherited Create;
  FInner := AInner;
end;

function TRadIATestWorkflowExecutor.Execute(
  const ARequest: TRadIAToolRequest
): TRadIAToolResult;
begin
  Inc(FCallCount);
  Result := FInner.Execute(ARequest);
end;

procedure TRadIADeclarativeExtensionTests.
  BinderRejectsUnknownOrChainedTargets;
var
  LBinder: TRadIADeclarativeToolBinder;
  LDefinitions: TArray<TRadIADeclarativeTool>;
  LExecutor: IRadIAToolExecutor;
  LRegistry: IRadIAToolRegistry;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LRegistry.RegisterTool(TRadIATestTargetTool.Create);
  LExecutor := TRadIAToolExecutor.Create(LRegistry);
  LBinder := TRadIADeclarativeToolBinder.Create(
    LRegistry,
    LExecutor
  );
  try
    LDefinitions := [
      TRadIADeclarativeTool.Create(
        'TeamTools',
        'TeamToolsUnknown',
        'Unknown target.',
        'MissingTool'
      )
    ];
    Assert.WillRaise(
      procedure
      begin
        LBinder.Reload(LDefinitions, []);
      end,
      EArgumentException
    );
    LDefinitions := [
      TRadIADeclarativeTool.Create(
        'TeamTools',
        'TeamToolsFirst',
        'First alias.',
        'TeamToolsSecond'
      ),
      TRadIADeclarativeTool.Create(
        'TeamTools',
        'TeamToolsSecond',
        'Second alias.',
        'GetProjectHealth'
      )
    ];
    Assert.WillRaise(
      procedure
      begin
        LBinder.Reload(LDefinitions, []);
      end,
      EArgumentException
    );
  finally
    LBinder.Free;
  end;
end;

procedure TRadIADeclarativeExtensionTests.
  BindsDeclarativeToolWithInheritedPolicyMetadata;
var
  LAlias: IRadIATool;
  LBinder: TRadIADeclarativeToolBinder;
  LDefinitions: TArray<TRadIADeclarativeTool>;
  LExecutor: IRadIAToolExecutor;
  LRegistry: IRadIAToolRegistry;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LRegistry.RegisterTool(TRadIATestTargetTool.Create);
  LExecutor := TRadIAToolExecutor.Create(LRegistry);
  LBinder := TRadIADeclarativeToolBinder.Create(
    LRegistry,
    LExecutor
  );
  try
    LDefinitions := [
      TRadIADeclarativeTool.Create(
        'TeamTools',
        'TeamToolsProjectHealth',
        'Team project health.',
        'GetProjectHealth'
      )
    ];
    LBinder.Reload(LDefinitions, []);
    Assert.IsTrue(
      LRegistry.TryResolve('TeamToolsProjectHealth', LAlias)
    );
    Assert.AreEqual(trReadOnly, LAlias.Descriptor.Risk);
    Assert.AreEqual<Cardinal>(5000, LAlias.Descriptor.TimeoutMs);
    Assert.IsTrue(LAlias.Descriptor.Idempotent);
    LRequest := TRadIAToolRequest.Create(
      'TeamToolsProjectHealth',
      '{}',
      'test-correlation'
    );
    LResult := LAlias.Execute(LRequest);
    Assert.IsTrue(LResult.Success);
    Assert.Contains(LResult.ContentJson, 'GetProjectHealth');
    LBinder.Reload([], []);
    Assert.IsFalse(
      LRegistry.TryResolve('TeamToolsProjectHealth', LAlias)
    );
  finally
    LBinder.Free;
  end;
end;

procedure TRadIADeclarativeExtensionTests.
  EnablesDisablesAndRemovesWithoutRestart;
var
  LCommand: TRadIADeclarativeCommand;
  LExtensionId: string;
  LMessage: string;
  LSourceFileName: string;
begin
  LSourceFileName := TPath.Combine(FDirectory, 'source.json');
  TFile.WriteAllText(LSourceFileName, CValidManifest, TEncoding.UTF8);
  Assert.IsTrue(
    FManager.InstallOrUpdate(
      LSourceFileName,
      [],
      LExtensionId,
      LMessage
    ),
    LMessage
  );
  Assert.IsTrue(
    FManager.SetEnabled(LExtensionId, False, [], LMessage),
    LMessage
  );
  Assert.IsFalse(FManager.TryResolve('/team-review', LCommand));
  Assert.AreEqual('disabled', FManager.GetDiagnostics[0].Status);
  Assert.IsTrue(
    FManager.SetEnabled(LExtensionId, True, [], LMessage),
    LMessage
  );
  Assert.IsTrue(FManager.TryResolve('/team-review', LCommand));
  Assert.IsTrue(FManager.Remove(LExtensionId, [], LMessage), LMessage);
  Assert.IsFalse(FManager.TryResolve('/team-review', LCommand));
end;

procedure TRadIADeclarativeExtensionTests.
  InstallsUpdatesAndActivatesManifestAtomically;
var
  LCommand: TRadIADeclarativeCommand;
  LExtensionId: string;
  LMessage: string;
  LSourceFileName: string;
begin
  LSourceFileName := TPath.Combine(FDirectory, 'source.json');
  TFile.WriteAllText(LSourceFileName, CValidManifest, TEncoding.UTF8);
  Assert.IsTrue(
    FManager.InstallOrUpdate(
      LSourceFileName,
      [],
      LExtensionId,
      LMessage
    ),
    LMessage
  );
  Assert.AreEqual('TeamCommands', LExtensionId);
  Assert.IsTrue(FManager.TryResolve('/team-review', LCommand));
  TFile.WriteAllText(
    LSourceFileName,
    CValidManifest.Replace('1.0.0', '1.1.0').Replace(
      'team policy: {code}',
      'updated policy: {code}'
    ),
    TEncoding.UTF8
  );
  Assert.IsTrue(
    FManager.InstallOrUpdate(
      LSourceFileName,
      [],
      LExtensionId,
      LMessage
    ),
    LMessage
  );
  Assert.IsTrue(FManager.TryResolve('/team-review', LCommand));
  Assert.Contains(LCommand.Prompt, 'updated policy');
end;

procedure TRadIADeclarativeExtensionTests.
  InvalidUpdateRollsBackWorkingManifest;
var
  LCommand: TRadIADeclarativeCommand;
  LExtensionId: string;
  LMessage: string;
  LSourceFileName: string;
begin
  LSourceFileName := TPath.Combine(FDirectory, 'source.json');
  TFile.WriteAllText(LSourceFileName, CValidManifest, TEncoding.UTF8);
  Assert.IsTrue(
    FManager.InstallOrUpdate(
      LSourceFileName,
      [],
      LExtensionId,
      LMessage
    ),
    LMessage
  );
  TFile.WriteAllText(
    LSourceFileName,
    CValidManifest.Replace('/team-review', '/agent'),
    TEncoding.UTF8
  );
  Assert.IsFalse(
    FManager.InstallOrUpdate(
      LSourceFileName,
      ['/agent'],
      LExtensionId,
      LMessage
    )
  );
  Assert.Contains(LMessage, 'collides');
  FManager.Reload([]);
  Assert.IsTrue(FManager.TryResolve('/team-review', LCommand));
end;

procedure TRadIADeclarativeExtensionTests.LoadsSchemaTwoTemplatesAndSkills;
const
  CManifest =
    '{"schemaVersion":2,"id":"TeamWorkflow","version":"2.0.0",' +
    '"permissions":["chat.prompt"],"templates":[{"name":"Fix plan",' +
    '"description":"Create a reviewed fix plan.","command":"/team-plan",' +
    '"prompt":"Plan a fix for: {argument}"}],"skills":[{"name":"Team style",' +
    '"description":"Apply the team coding style.","command":"/team-style",' +
    '"instructions":"Follow the team style while reviewing: {code}"}]}';
var
  LCapability: TRadIADeclarativeCommand;
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
begin
  WriteManifest('workflow.radia.json', CManifest);
  FManager.Reload([]);
  Assert.IsTrue(FManager.TryResolve('/team-plan', LCapability));
  Assert.AreEqual('template', LCapability.Kind);
  Assert.Contains(LCapability.Prompt, '{argument}');
  Assert.IsTrue(FManager.TryResolve('/team-style', LCapability));
  Assert.AreEqual('skill', LCapability.Kind);
  Assert.Contains(LCapability.Prompt, '{code}');
  LDiagnostics := FManager.GetDiagnostics;
  Assert.AreEqual<Integer>(1, Length(LDiagnostics));
  Assert.AreEqual('loaded', LDiagnostics[0].Status);
  Assert.Contains(LDiagnostics[0].Message, '2 capability');
end;

procedure TRadIADeclarativeExtensionTests.
  LoadsSchemaThreeDeclarativeToolContract;
const
  CManifest =
    '{"schemaVersion":3,"id":"TeamTools","version":"3.0.0",' +
    '"permissions":["tool.alias"],"tools":[{' +
    '"name":"TeamToolsProjectHealth",' +
    '"description":"Expose project health under the team namespace.",' +
    '"targetTool":"GetProjectHealth"}]}';
var
  LTools: TArray<TRadIADeclarativeTool>;
begin
  WriteManifest('tools.radia.json', CManifest);
  FManager.Reload([]);
  LTools := FManager.GetTools;
  Assert.AreEqual<Integer>(1, Length(LTools));
  Assert.AreEqual('TeamTools', LTools[0].ExtensionId);
  Assert.AreEqual('TeamToolsProjectHealth', LTools[0].Name);
  Assert.AreEqual('GetProjectHealth', LTools[0].TargetTool);
  Assert.AreEqual('loaded', FManager.GetDiagnostics[0].Status);
end;

procedure TRadIADeclarativeExtensionTests.
  LoadsSchemaFourTeamJourneysAndPolicies;
const
  CManifest =
    '{"schemaVersion":4,"id":"TeamDelivery","version":"4.0.0",' +
    '"permissions":["chat.prompt"],"journeys":[{"name":"Team release",' +
    '"description":"Run the team release journey.","command":"/team-release",' +
    '"objective":"Inspect, validate, review, and prepare the team release."}],' +
    '"policies":[{"name":"Team architecture","description":"Review architecture.",' +
    '"command":"/team-architecture","instructions":"Apply the published architecture policy."}]}';
var
  LArgument: string;
  LCapability: TRadIADeclarativeCommand;
begin
  WriteManifest('team-delivery.radia.json', CManifest);
  FManager.Reload([]);

  Assert.IsTrue(
    FManager.TryResolveInput(
      '/team-release release only the billing package',
      LCapability,
      LArgument
    )
  );
  Assert.AreEqual('journey', LCapability.Kind);
  Assert.AreEqual('release only the billing package', LArgument);
  Assert.Contains(LCapability.Prompt, 'Inspect, validate');

  Assert.IsTrue(FManager.TryResolve('/team-architecture', LCapability));
  Assert.AreEqual('policy', LCapability.Kind);
  Assert.AreEqual('loaded', FManager.GetDiagnostics[0].Status);
  Assert.Contains(FManager.GetDiagnostics[0].Message, '2 capability');
end;

procedure TRadIADeclarativeExtensionTests.
  LoadsAndExecutesSchemaFiveWorkflow;
const
  CManifest =
    '{"schemaVersion":5,"id":"TeamFlow","version":"5.0.0",' +
    '"permissions":["tool.workflow"],"workflows":[{' +
    '"name":"TeamFlowInspect","description":"Inspect twice.",' +
    '"steps":[{"tool":"GetProjectHealth","arguments":{}},' +
    '{"tool":"BuildProject","arguments":{"mode":"check"}}]}]}';
var
  LBinder: TRadIADeclarativeToolBinder;
  LExecutor: IRadIAToolExecutor;
  LRegistry: IRadIAToolRegistry;
  LRequest: TRadIAToolRequest;
  LResult: TRadIAToolResult;
  LSpy: TRadIATestWorkflowExecutor;
  LTool: IRadIATool;
  LWorkflows: TArray<TRadIADeclarativeWorkflow>;
begin
  WriteManifest('team-flow.radia.json', CManifest);
  FManager.Reload([]);
  LWorkflows := FManager.GetWorkflows;
  Assert.AreEqual<Integer>(1, Length(LWorkflows));
  Assert.AreEqual<Integer>(2, Length(LWorkflows[0].Steps));
  Assert.AreEqual('GetProjectHealth', LWorkflows[0].Steps[0].TargetTool);

  LRegistry := TRadIAToolRegistry.Create;
  LRegistry.RegisterTool(TRadIATestTargetTool.Create);
  LRegistry.RegisterTool(TRadIATestExecutionTool.Create);
  LExecutor := TRadIAToolExecutor.Create(LRegistry);
  LSpy := TRadIATestWorkflowExecutor.Create(LExecutor);
  LExecutor := LSpy;
  LBinder := TRadIADeclarativeToolBinder.Create(LRegistry, LExecutor);
  try
    LBinder.Reload([], LWorkflows);
    Assert.IsTrue(LRegistry.TryResolve('TeamFlowInspect', LTool));
    Assert.AreEqual(trExecution, LTool.Descriptor.Risk);
    Assert.AreEqual<Cardinal>(15000, LTool.Descriptor.TimeoutMs);
    Assert.IsFalse(LTool.Descriptor.Idempotent);
    LRequest := TRadIAToolRequest.Create(
      'TeamFlowInspect',
      '{}',
      'workflow-test'
    );
    LResult := LTool.Execute(LRequest);
    Assert.IsTrue(LResult.Success);
    Assert.AreEqual(2, LSpy.CallCount);
    Assert.Contains(LResult.ContentJson, '"index":1');
    Assert.Contains(LResult.ContentJson, '"index":2');
  finally
    LBinder.Free;
  end;
end;

procedure TRadIADeclarativeExtensionTests.
  RejectsWorkflowWithoutExplicitPermission;
const
  CManifest =
    '{"schemaVersion":5,"id":"TeamFlow","version":"5.0.0",' +
    '"permissions":[],"workflows":[{' +
    '"name":"TeamFlowInspect","description":"Inspect safely.",' +
    '"steps":[{"tool":"GetProjectHealth","arguments":{}}]}]}';
begin
  WriteManifest('workflow-permission.radia.json', CManifest);
  FManager.Reload([]);

  Assert.AreEqual<Integer>(0, Length(FManager.GetWorkflows));
  Assert.AreEqual('rejected', FManager.GetDiagnostics[0].Status);
  Assert.Contains(FManager.GetDiagnostics[0].Message, 'tool.workflow');
end;

procedure TRadIADeclarativeExtensionTests.
  BinderRejectsWorkflowTargetingDeclarativeCapability;
var
  LBinder: TRadIADeclarativeToolBinder;
  LDefinitions: TArray<TRadIADeclarativeTool>;
  LExecutor: IRadIAToolExecutor;
  LRegistry: IRadIAToolRegistry;
  LSteps: TArray<TRadIADeclarativeWorkflowStep>;
  LWorkflows: TArray<TRadIADeclarativeWorkflow>;
begin
  LRegistry := TRadIAToolRegistry.Create;
  LRegistry.RegisterTool(TRadIATestTargetTool.Create);
  LExecutor := TRadIAToolExecutor.Create(LRegistry);
  LBinder := TRadIADeclarativeToolBinder.Create(LRegistry, LExecutor);
  try
    LDefinitions := [
      TRadIADeclarativeTool.Create(
        'TeamTools',
        'TeamToolsHealth',
        'Health alias.',
        'GetProjectHealth'
      )
    ];
    LSteps := [
      TRadIADeclarativeWorkflowStep.Create(
        'TeamToolsHealth',
        '{}'
      )
    ];
    LWorkflows := [
      TRadIADeclarativeWorkflow.Create(
        'TeamFlowInspect',
        'Invalid chained workflow.',
        LSteps
      )
    ];
    Assert.WillRaise(
      procedure
      begin
        LBinder.Reload(LDefinitions, LWorkflows);
      end,
      EArgumentException
    );
  finally
    LBinder.Free;
  end;
end;

procedure TRadIADeclarativeExtensionTests.
  RejectsSchemaFourCredentialFields;
const
  CManifest =
    '{"schemaVersion":4,"id":"UnsafeTeam","version":"4.0.0",' +
    '"permissions":["chat.prompt"],"policies":[{"name":"Unsafe policy",' +
    '"description":"Contains a forbidden field.","command":"/unsafe-policy",' +
    '"instructions":"Review code.","settings":{"apiKey":"must-not-load"}}]}';
begin
  WriteManifest('unsafe-team.radia.json', CManifest);
  FManager.Reload([]);

  Assert.AreEqual<Integer>(0, Length(FManager.GetCommands));
  Assert.AreEqual('rejected', FManager.GetDiagnostics[0].Status);
  Assert.Contains(FManager.GetDiagnostics[0].Message, 'credential fields');
end;

procedure TRadIADeclarativeExtensionTests.
  RejectsDeclarativeToolOutsideExtensionNamespace;
const
  CManifest =
    '{"schemaVersion":3,"id":"TeamTools","version":"3.0.0",' +
    '"permissions":["tool.alias"],"tools":[{' +
    '"name":"ForeignProjectHealth","description":"Invalid namespace.",' +
    '"targetTool":"GetProjectHealth"}]}';
begin
  WriteManifest('foreign-tool.radia.json', CManifest);
  FManager.Reload([]);
  Assert.AreEqual<Integer>(0, Length(FManager.GetTools));
  Assert.AreEqual('rejected', FManager.GetDiagnostics[0].Status);
  Assert.Contains(FManager.GetDiagnostics[0].Message, 'extension ID');
end;

procedure TRadIADeclarativeExtensionTests.
  RejectsDeclarativeToolWithoutExplicitPermission;
const
  CManifest =
    '{"schemaVersion":3,"id":"TeamTools","version":"3.0.0",' +
    '"permissions":["chat.prompt"],"tools":[{' +
    '"name":"TeamToolsProjectHealth","description":"Missing permission.",' +
    '"targetTool":"GetProjectHealth"}]}';
begin
  WriteManifest('tool-permission.radia.json', CManifest);
  FManager.Reload([]);
  Assert.AreEqual<Integer>(0, Length(FManager.GetTools));
  Assert.AreEqual('rejected', FManager.GetDiagnostics[0].Status);
  Assert.Contains(FManager.GetDiagnostics[0].Message, 'permission');
end;

procedure TRadIADeclarativeExtensionTests.
  RejectsDuplicateCommandsAcrossCapabilityKinds;
const
  CManifest =
    '{"schemaVersion":2,"id":"DuplicateKinds","version":"1.0.0",' +
    '"permissions":["chat.prompt"],"commands":[{"name":"Command",' +
    '"description":"Command entry.","command":"/same-entry",' +
    '"prompt":"Command prompt"}],"skills":[{"name":"Skill",' +
    '"description":"Skill entry.","command":"/same-entry",' +
    '"instructions":"Skill instructions"}]}';
begin
  WriteManifest('duplicate.radia.json', CManifest);
  FManager.Reload([]);
  Assert.AreEqual<Integer>(0, Length(FManager.GetCommands));
  Assert.AreEqual('rejected', FManager.GetDiagnostics[0].Status);
  Assert.Contains(FManager.GetDiagnostics[0].Message, 'duplicate');
end;

procedure TRadIADeclarativeExtensionTests.SchemaOneDoesNotEnableSkills;
const
  CManifest =
    '{"schemaVersion":1,"id":"LegacySkill","version":"1.0.0",' +
    '"permissions":["chat.prompt"],"skills":[{"name":"Legacy skill",' +
    '"description":"Must not load in schema one.","command":"/legacy-skill",' +
    '"instructions":"Instructions"}]}';
begin
  WriteManifest('legacy-skill.radia.json', CManifest);
  FManager.Reload([]);
  Assert.AreEqual<Integer>(0, Length(FManager.GetCommands));
  Assert.AreEqual('rejected', FManager.GetDiagnostics[0].Status);
  Assert.Contains(FManager.GetDiagnostics[0].Message, 'capabilities');
end;

{ TRadIADeclarativeExtensionTests }

procedure TRadIADeclarativeExtensionTests.LoadsAndResolvesCommandWithoutRestart;
var
  LCommand: TRadIADeclarativeCommand;
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
begin
  WriteManifest('team.radia.json', CValidManifest);
  FManager.Reload(['/agent', '/review']);
  Assert.IsTrue(FManager.TryResolve('/team-review', LCommand));
  Assert.AreEqual('TeamCommands', LCommand.ExtensionId);
  Assert.AreEqual('Team review', LCommand.Name);
  Assert.Contains(LCommand.Prompt, '{code}');
  LDiagnostics := FManager.GetDiagnostics;
  Assert.AreEqual<Integer>(1, Length(LDiagnostics));
  Assert.AreEqual('loaded', LDiagnostics[0].Status);
end;

procedure TRadIADeclarativeExtensionTests.ReloadRemovesDeletedManifest;
var
  LCommand: TRadIADeclarativeCommand;
  LFileName: string;
begin
  LFileName := TPath.Combine(FDirectory, 'team.radia.json');
  WriteManifest('team.radia.json', CValidManifest);
  FManager.Reload([]);
  Assert.IsTrue(FManager.TryResolve('/team-review', LCommand));
  TFile.Delete(LFileName);
  FManager.Reload([]);
  Assert.IsFalse(FManager.TryResolve('/team-review', LCommand));
  Assert.AreEqual<Integer>(0, Length(FManager.GetCommands));
end;

procedure TRadIADeclarativeExtensionTests.
  RemovesRejectedManifestByDiagnosticFile;
var
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
  LMessage: string;
begin
  WriteManifest('rejected.radia.json', '{invalid');
  FManager.Reload([]);
  LDiagnostics := FManager.GetDiagnostics;
  Assert.AreEqual<Integer>(1, Length(LDiagnostics));
  Assert.AreEqual('rejected', LDiagnostics[0].Status);
  Assert.IsTrue(
    FManager.RemoveManifest(
      LDiagnostics[0].FileName,
      [],
      LMessage
    ),
    LMessage
  );
  Assert.AreEqual<Integer>(0, Length(FManager.GetDiagnostics));
end;

procedure TRadIADeclarativeExtensionTests.ReportsDisabledManifest;
var
  LCommand: TRadIADeclarativeCommand;
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
begin
  WriteManifest(
    'disabled.radia.json',
    CValidManifest.Replace('"enabled":true', '"enabled":false')
  );
  FManager.Reload([]);
  Assert.IsFalse(FManager.TryResolve('/team-review', LCommand));
  LDiagnostics := FManager.GetDiagnostics;
  Assert.AreEqual('disabled', LDiagnostics[0].Status);
end;

procedure TRadIADeclarativeExtensionTests.
  RejectsOversizedManifestBeforeParsing;
var
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
begin
  WriteManifest(
    'oversized.radia.json',
    StringOfChar('x', 1048577)
  );
  FManager.Reload([]);
  Assert.AreEqual<Integer>(0, Length(FManager.GetCommands));
  LDiagnostics := FManager.GetDiagnostics;
  Assert.AreEqual('rejected', LDiagnostics[0].Status);
  Assert.Contains(LDiagnostics[0].Message, '1 MiB');
end;

procedure TRadIADeclarativeExtensionTests.RejectsReservedCommandAtomically;
var
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
begin
  WriteManifest(
    'collision.radia.json',
    CValidManifest.Replace('/team-review', '/agent')
  );
  FManager.Reload(['/agent']);
  Assert.AreEqual<Integer>(0, Length(FManager.GetCommands));
  LDiagnostics := FManager.GetDiagnostics;
  Assert.AreEqual('rejected', LDiagnostics[0].Status);
  Assert.Contains(LDiagnostics[0].Message, 'collides');
end;

procedure TRadIADeclarativeExtensionTests.RequiresExplicitMinimalPermission;
var
  LDiagnostics: TArray<TRadIADeclarativeExtensionDiagnostic>;
begin
  WriteManifest(
    'permission.radia.json',
    CValidManifest.Replace(
      '["chat.prompt"]',
      '["chat.prompt","workspace.write"]'
    )
  );
  FManager.Reload([]);
  Assert.AreEqual<Integer>(0, Length(FManager.GetCommands));
  LDiagnostics := FManager.GetDiagnostics;
  Assert.AreEqual('rejected', LDiagnostics[0].Status);
  Assert.Contains(LDiagnostics[0].Message, 'permission');
end;

procedure TRadIADeclarativeExtensionTests.Setup;
begin
  FDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-DeclarativeExtensions-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FDirectory);
  FManager := TRadIADeclarativeExtensionManager.Create(FDirectory);
end;

procedure TRadIADeclarativeExtensionTests.TearDown;
begin
  FManager.Free;
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TRadIADeclarativeExtensionTests.WriteManifest(
  const AFileName: string;
  const AContent: string
);
begin
  TFile.WriteAllText(
    TPath.Combine(FDirectory, AFileName),
    AContent,
    TEncoding.UTF8
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADeclarativeExtensionTests);

end.
