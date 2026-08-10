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
    procedure BuildsCapabilityAudit;
    [Test]
    procedure ExportsVerifiedUnsignedPackage;
    [Test]
    procedure ExportsAndTestsResourcePackage;
    [Test]
    procedure TestsManifestInIsolatedSandbox;
    [Test]
    procedure RejectsInvalidDrafts;
    [Test]
    procedure GeneratedManifestsPassManagerValidation;
    [Test]
    procedure ParsesSigningCertificateCatalog;
    [Test]
    procedure BuildsSafeSigningInvocation;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.AgentExecutors,
  RadIA.Core.DeclarativeExtensionPackages,
  RadIA.Core.DeclarativeExtensions,
  RadIA.Core.ExtensionStudio,
  RadIA.Core.ExtensionSigning;

procedure TRadIAExtensionStudioTests.BuildsSafeSigningInvocation;
var
  LInvocation: TRadIACliInvocation;
  LManifestPath: string;
  LPackagerPath: string;
begin
  LManifestPath := TPath.GetTempFileName;
  LPackagerPath := TPath.GetTempFileName;
  try
    LInvocation := TRadIAExtensionSigningService.BuildSigningInvocation(
      TRadIAExtensionSigningRequest.Create(
        LManifestPath,
        TPath.Combine(TPath.GetTempPath, 'signed.radiaext'),
        LPackagerPath,
        'publisher-id',
        'Publisher Name',
        'AABBCC'
      )
    );
    Assert.AreEqual('powershell.exe', LInvocation.ExecutablePath);
    Assert.AreEqual('AABBCC', LInvocation.Arguments[11]);
    Assert.AreEqual('publisher-id', LInvocation.Arguments[13]);
    Assert.AreEqual('Publisher Name', LInvocation.Arguments[15]);
  finally
    TFile.Delete(LManifestPath);
    TFile.Delete(LPackagerPath);
  end;
end;

procedure TRadIAExtensionStudioTests.ParsesSigningCertificateCatalog;
var
  LCertificates: TArray<TRadIAExtensionSigningCertificate>;
begin
  LCertificates := TRadIAExtensionSigningService.ParseCertificates(
    '[{"displayName":"Rad IA Publisher",' +
    '"expiresAt":"2028-01-02 03:04:05","thumbprint":"aabbcc"}]'
  );
  Assert.AreEqual<Integer>(1, Length(LCertificates));
  Assert.AreEqual('Rad IA Publisher', LCertificates[0].DisplayName);
  Assert.AreEqual('2028-01-02 03:04:05', LCertificates[0].ExpiresAt);
  Assert.AreEqual('AABBCC', LCertificates[0].Thumbprint);
end;

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

procedure TRadIAExtensionStudioTests.BuildsCapabilityAudit;
var
  LAudit: string;
begin
  LAudit := TRadIAExtensionStudioBuilder.BuildAudit(
    TRadIAExtensionStudioDraft.Create(
      eskWorkflow,
      'TeamFlow',
      '1.0.0',
      'TeamFlowInspect',
      'Inspect IDE state.',
      '',
      '[{"tool":"GetIDEState","arguments":{}}]'
    )
  );
  Assert.Contains(LAudit, 'Permission: tool.workflow');
  Assert.Contains(LAudit, 'Arbitrary process execution: no');
  Assert.Contains(LAudit, 'central consent and audit apply');
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

procedure TRadIAExtensionStudioTests.ExportsVerifiedUnsignedPackage;
var
  LDraft: TRadIAExtensionStudioDraft;
  LHash: string;
  LManifest: string;
  LPackage: TRadIADeclarativeExtensionPackage;
  LPackageFileName: string;
begin
  LDraft := TRadIAExtensionStudioDraft.Create(
    eskCommand,
    'StudioPackage',
    '1.2.3',
    'Package command',
    'Create a verified package.',
    '/package-command',
    'Review {argument}'
  );
  LManifest := TRadIAExtensionStudioBuilder.BuildManifest(LDraft);
  LPackageFileName := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-Studio-' + TGUID.NewGuid.ToString + '.radiaext'
  );
  try
    LHash := TRadIAExtensionStudioPackager.ExportUnsigned(
      LManifest,
      LPackageFileName
    );
    Assert.AreEqual<Integer>(64, Length(LHash));
    LPackage := TRadIADeclarativeExtensionPackageReader.Read(
      LPackageFileName
    );
    Assert.AreEqual('StudioPackage', LPackage.ExtensionId);
    Assert.AreEqual('1.2.3', LPackage.Version);
    Assert.IsFalse(LPackage.IsSigned);
  finally
    if TFile.Exists(LPackageFileName) then
      TFile.Delete(LPackageFileName);
  end;
end;

procedure TRadIAExtensionStudioTests.ExportsAndTestsResourcePackage;
var
  LManifest: string;
  LPackage: TRadIADeclarativeExtensionPackage;
  LPackageFileName: string;
  LResourceDirectory: string;
  LResourceFileName: string;
  LResult: string;
  LRoot: string;
begin
  LRoot := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-StudioResources-' + TGUID.NewGuid.ToString
  );
  LResourceDirectory := TPath.Combine(LRoot, 'resources');
  LResourceFileName := TPath.Combine(
    LResourceDirectory,
    'knowledge\team\rules.md'
  );
  TDirectory.CreateDirectory(ExtractFilePath(LResourceFileName));
  TFile.WriteAllText(
    LResourceFileName,
    '# Team rules',
    TEncoding.UTF8
  );
  LPackageFileName := TPath.Combine(LRoot, 'studio.radiaext');
  try
    LManifest := TRadIAExtensionStudioBuilder.BuildManifest(
      TRadIAExtensionStudioDraft.Create(
        eskSkill,
        'StudioKnowledge',
        '1.0.0',
        'Team knowledge',
        'Load shared team knowledge.',
        '/team-knowledge',
        ''
      ).WithContentFile('knowledge/team/rules.md')
    );
    Assert.Contains(LManifest, '"schemaVersion": 6');
    Assert.Contains(LManifest, '"contentFile": "knowledge/team/rules.md"');
    TRadIAExtensionStudioPackager.ExportUnsigned(
      LManifest,
      LPackageFileName,
      LResourceDirectory
    );
    LPackage := TRadIADeclarativeExtensionPackageReader.Read(
      LPackageFileName
    );
    Assert.AreEqual<Integer>(3, LPackage.SchemaVersion);
    Assert.AreEqual<Integer>(1, Length(LPackage.Resources));
    LResult := TRadIAExtensionStudioSandbox.TestManifest(
      LManifest,
      [],
      LResourceDirectory
    );
    Assert.Contains(LResult, 'Sandbox result: activated');
  finally
    if TDirectory.Exists(LRoot) then
      TDirectory.Delete(LRoot, True);
  end;
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

procedure TRadIAExtensionStudioTests.TestsManifestInIsolatedSandbox;
var
  LManifest: string;
  LResult: string;
begin
  LManifest := TRadIAExtensionStudioBuilder.BuildManifest(
    TRadIAExtensionStudioDraft.Create(
      eskCommand,
      'SandboxCommand',
      '1.0.0',
      'Sandbox command',
      'Validate isolated activation.',
      '/sandbox-command',
      'Inspect {argument}'
    )
  );
  LResult := TRadIAExtensionStudioSandbox.TestManifest(LManifest, []);
  Assert.Contains(LResult, 'Sandbox result: activated');
  Assert.Contains(LResult, 'Commands and journeys: 1');
  Assert.Contains(LResult, 'Persistent changes: none');
  LResult := TRadIAExtensionStudioSandbox.TestManifest(
    LManifest,
    ['/sandbox-command']
  );
  Assert.Contains(LResult, 'Sandbox result: rejected');
  Assert.Contains(LResult, 'collides with an existing slash command');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAExtensionStudioTests);

end.
