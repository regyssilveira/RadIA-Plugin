unit RadIA.Tests.SkillReplicas;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIASkillReplicaTests = class
  public
    [Test]
    procedure CreatesUpdatesAndRemovesOwnedReplicas;
    [Test]
    procedure PreservesManuallyModifiedReplica;
    [Test]
    procedure RejectsUnownedConflict;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.SkillPortability,
  RadIA.Core.SkillReplicas;

function NewSkill(const AInstructions: string): TRadIACanonicalSkill;
begin
  Result := TRadIACanonicalSkill.Create(
    'ReplicaTest',
    'Project review',
    'Review the active project and report evidence.',
    AInstructions
  );
end;

function NewTestRoot: string;
begin
  Result := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-SkillReplicas-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(Result);
end;

procedure TRadIASkillReplicaTests.CreatesUpdatesAndRemovesOwnedReplicas;
var
  LFileName: string;
  LResult: TRadIASkillReplicaApplyResult;
  LRoot: string;
  LService: TRadIASkillReplicaService;
begin
  LRoot := NewTestRoot;
  LService := TRadIASkillReplicaService.Create(LRoot);
  try
    LResult := LService.Apply(NewSkill('First instructions.'), ['codex']);
    Assert.AreEqual(1, LResult.Created);
    LFileName := TPath.Combine(
      LRoot,
      '.agents\skills\replicatest-project-review\SKILL.md'
    );
    Assert.IsTrue(TFile.Exists(LFileName));
    LResult := LService.Apply(NewSkill('Updated instructions.'), ['codex']);
    Assert.AreEqual(1, LResult.Updated);
    Assert.Contains(TFile.ReadAllText(LFileName), 'Updated instructions.');
    Assert.Contains(LService.RemoveOwned('ReplicaTest'), 'Removed: 1');
    Assert.IsFalse(TFile.Exists(LFileName));
  finally
    LService.Free;
    TDirectory.Delete(LRoot, True);
  end;
end;

procedure TRadIASkillReplicaTests.PreservesManuallyModifiedReplica;
var
  LFileName: string;
  LRoot: string;
  LService: TRadIASkillReplicaService;
begin
  LRoot := NewTestRoot;
  LService := TRadIASkillReplicaService.Create(LRoot);
  try
    LService.Apply(NewSkill('Original instructions.'), ['claude']);
    LFileName := TPath.Combine(
      LRoot,
      '.claude\skills\replicatest-project-review\SKILL.md'
    );
    TFile.WriteAllText(LFileName, 'Manual content', TEncoding.UTF8);
    Assert.Contains(LService.RemoveOwned('ReplicaTest'), 'Preserved because modified: 1');
    Assert.AreEqual('Manual content', TFile.ReadAllText(LFileName, TEncoding.UTF8));
  finally
    LService.Free;
    TDirectory.Delete(LRoot, True);
  end;
end;

procedure TRadIASkillReplicaTests.RejectsUnownedConflict;
var
  LFileName: string;
  LPlan: TArray<TRadIASkillReplicaPlanItem>;
  LRoot: string;
  LService: TRadIASkillReplicaService;
begin
  LRoot := NewTestRoot;
  LFileName := TPath.Combine(
    LRoot,
    '.gemini\skills\replicatest-project-review\SKILL.md'
  );
  TDirectory.CreateDirectory(ExtractFilePath(LFileName));
  TFile.WriteAllText(LFileName, 'User content', TEncoding.UTF8);
  LService := TRadIASkillReplicaService.Create(LRoot);
  try
    LPlan := LService.BuildPlan(NewSkill('Instructions.'), ['gemini']);
    Assert.AreEqual(srsConflict, LPlan[0].State);
    Assert.AreEqual('User content', TFile.ReadAllText(LFileName, TEncoding.UTF8));
  finally
    LService.Free;
    TDirectory.Delete(LRoot, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASkillReplicaTests);

end.
