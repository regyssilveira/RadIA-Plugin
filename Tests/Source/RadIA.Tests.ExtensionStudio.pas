unit RadIA.Tests.ExtensionStudio;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAExtensionStudioTests = class
  public
    [Test]
    procedure BuildsCommandManifest;
    [Test]
    procedure BuildsAliasManifest;
    [Test]
    procedure BuildsWorkflowManifest;
    [Test]
    procedure RejectsInvalidDrafts;
    [Test]
    procedure GeneratedManifestsPassManagerValidation;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.DeclarativeExtensions,
  RadIA.Core.ExtensionStudio;

procedure TRadIAExtensionStudioTests.BuildsAliasManifest;
var
  LManifest: string;
begin
  LManifest := TRadIAExtensionStudioBuilder.BuildManifest(
    TRadIAExtensionStudioDraft.Create(
      eskAlias,
      'TeamTools',
      '1.0.0',
      'TeamToolsHealth',
      'Inspect project health.',
      'GetProjectHealth',
      ''
    )
  );
  Assert.Contains(LManifest, '"tool.alias"');
  Assert.Contains(LManifest, '"targetTool": "GetProjectHealth"');
end;

procedure TRadIAExtensionStudioTests.BuildsCommandManifest;
var
  LManifest: string;
begin
  LManifest := TRadIAExtensionStudioBuilder.BuildManifest(
    TRadIAExtensionStudioDraft.Create(
      eskCommand,
      'TeamReview',
      '1.0.0',
      'Team review',
      'Review selected code.',
      '/team-review',
      'Review {code}'
    )
  );
  Assert.Contains(LManifest, '"schemaVersion": 5');
  Assert.Contains(LManifest, '"chat.prompt"');
  Assert.Contains(LManifest, '"command": "/team-review"');
end;

procedure TRadIAExtensionStudioTests.BuildsWorkflowManifest;
var
  LManifest: string;
begin
  LManifest := TRadIAExtensionStudioBuilder.BuildManifest(
    TRadIAExtensionStudioDraft.Create(
      eskWorkflow,
      'TeamFlow',
      '1.0.0',
      'TeamFlowInspect',
      'Inspect the active IDE.',
      '',
      '[{"tool":"GetIDEState","arguments":{}}]'
    )
  );
  Assert.Contains(LManifest, '"tool.workflow"');
  Assert.Contains(LManifest, '"tool": "GetIDEState"');
end;

procedure TRadIAExtensionStudioTests.RejectsInvalidDrafts;
var
  LTestMethod: TTestLocalMethod;
begin
  LTestMethod :=
    procedure
    begin
      TRadIAExtensionStudioBuilder.BuildManifest(
        TRadIAExtensionStudioDraft.Create(
          eskCommand,
          'x',
          'next',
          '',
          '',
          'INVALID',
          ''
        )
      );
    end;
  Assert.WillRaise(LTestMethod, EArgumentException);
  LTestMethod :=
    procedure
    begin
      TRadIAExtensionStudioBuilder.BuildManifest(
        TRadIAExtensionStudioDraft.Create(
          eskWorkflow,
          'TeamFlow',
          '1.0.0',
          'TeamFlowInvalid',
          'Invalid workflow steps.',
          '',
          '{invalid}'
        )
      );
    end;
  Assert.WillRaise(LTestMethod, EArgumentException);
end;

procedure TRadIAExtensionStudioTests.GeneratedManifestsPassManagerValidation;
var
  LDraft: TRadIAExtensionStudioDraft;
  LDrafts: TArray<TRadIAExtensionStudioDraft>;
  LExtensionId: string;
  LFileName: string;
  LManager: TRadIADeclarativeExtensionManager;
  LMessage: string;
  LRoot: string;
begin
  LDrafts := [
    TRadIAExtensionStudioDraft.Create(
      eskCommand, 'StudioCommand', '1.0.0', 'Command', 'Command description.',
      '/studio-command', 'Run {argument}'
    ),
    TRadIAExtensionStudioDraft.Create(
      eskSkill, 'StudioSkill', '1.0.0', 'Skill', 'Skill description.',
      '/studio-skill', 'Review {code}'
    ),
    TRadIAExtensionStudioDraft.Create(
      eskAlias, 'StudioAlias', '1.0.0', 'StudioAliasState',
      'Alias description.', 'GetIDEState', ''
    ),
    TRadIAExtensionStudioDraft.Create(
      eskJourney, 'StudioJourney', '1.0.0', 'Journey',
      'Journey description.', '/studio-journey', 'Inspect and validate.'
    ),
    TRadIAExtensionStudioDraft.Create(
      eskWorkflow, 'StudioFlow', '1.0.0', 'StudioFlowState',
      'Workflow description.', '',
      '[{"tool":"GetIDEState","arguments":{}}]'
    )
  ];
  LRoot := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-ExtensionStudio-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(LRoot);
  LManager := TRadIADeclarativeExtensionManager.Create(LRoot);
  try
    for LDraft in LDrafts do
    begin
      LFileName := TPath.Combine(LRoot, LDraft.ExtensionId + '.source.json');
      TFile.WriteAllText(
        LFileName,
        TRadIAExtensionStudioBuilder.BuildManifest(LDraft),
        TEncoding.UTF8
      );
      Assert.IsTrue(
        LManager.InstallOrUpdate(
          LFileName,
          [],
          LExtensionId,
          LMessage
        ),
        LMessage
      );
      Assert.AreEqual(LDraft.ExtensionId, LExtensionId);
    end;
  finally
    LManager.Free;
    TDirectory.Delete(LRoot, True);
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAExtensionStudioTests);

end.
