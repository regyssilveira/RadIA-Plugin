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
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils;

const
  CValidManifest =
    '{"schemaVersion":1,"id":"TeamCommands","version":"1.0.0",' +
    '"enabled":true,"permissions":["chat.prompt"],"commands":[{' +
    '"name":"Team review","description":"Apply the team review policy.",' +
    '"command":"/team-review","prompt":"Review using the team policy: {code}"' +
    '}]}';

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
