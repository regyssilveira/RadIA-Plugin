unit RadIA.Tests.CliManager;

interface

uses
  DUnitX.TestFramework,
  System.Generics.Collections,
  RadIA.Core.CliManager;

type
  TRadIAFakeCliEnvironment = class(
    TInterfacedObject,
    IRadIACliEnvironment
  )
  private
    FFiles: TDictionary<string, Boolean>;
    FPathEntries: TArray<string>;
  public
    constructor Create(const APathEntries: TArray<string>);
    destructor Destroy; override;
    procedure AddFile(const AFileName: string);
    function FileExists(const AFileName: string): Boolean;
    function GetPathEntries: TArray<string>;
  end;

  [TestFixture]
  TRadIACliManagerTests = class
  public
    [Test]
    procedure CatalogContainsSupportedExecutors;
    [Test]
    procedure FindsConfiguredExecutableBeforePath;
    [Test]
    procedure FindsExecutableOnPath;
    [Test]
    procedure ReportsMissingExecutable;
    [Test]
    procedure NpmInstallPlansUseOfficialPackages;
    [Test]
    procedure CopilotInstallPlanUsesOfficialWingetPackage;
    [Test]
    procedure InstallPlanRejectsShellMetacharacters;
    [Test]
    procedure DetectAllReturnsOneResultPerDefinition;
    [Test]
    procedure DefaultEnvironmentCanDetectWithoutConfiguration;
    [Test]
    procedure FindByIdRejectsUnknownExecutor;
    [Test]
    procedure MissingConfiguredPathFallsBackToEnvironmentPath;
    [Test]
    procedure NormalizesCliVersionOutput;
    [Test]
    procedure ComparesCliSemanticVersions;
    [Test]
    procedure ResolverUsesPortableOverrideWithoutPackageManager;
    [Test]
    procedure ResolverUsesPathWhenOverrideIsMissing;
    [Test]
    procedure ExpectedCodexPathUsesGlobalNpmDirectory;
    [Test]
    procedure PrerequisitePlanUsesOfficialNodePackage;
    [Test]
    procedure ManualGuidanceIncludesEveryRecoveryPath;
    [Test]
    procedure PrerequisiteGuidanceReturnsToOriginalFlow;
    [Test]
    procedure FindsNewNpmExecutableOutsideInheritedPath;
    [Test]
    procedure ConvertsSetupFailuresIntoActionableGuidance;
    [Test]
    procedure DiagnosesOfficialChannelPrerequisites;
    [Test]
    procedure PersistsSanitizedSetupHistory;
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows;

{ TRadIAFakeCliEnvironment }

constructor TRadIAFakeCliEnvironment.Create(
  const APathEntries: TArray<string>
);
begin
  inherited Create;
  FFiles := TDictionary<string, Boolean>.Create;
  FPathEntries := APathEntries;
end;

destructor TRadIAFakeCliEnvironment.Destroy;
begin
  FFiles.Free;
  inherited;
end;

procedure TRadIAFakeCliEnvironment.AddFile(
  const AFileName: string
);
begin
  FFiles.AddOrSetValue(LowerCase(AFileName), True);
end;

function TRadIAFakeCliEnvironment.FileExists(
  const AFileName: string
): Boolean;
begin
  Result := FFiles.ContainsKey(LowerCase(AFileName));
end;

function TRadIAFakeCliEnvironment.GetPathEntries: TArray<string>;
begin
  Result := FPathEntries;
end;

{ TRadIACliManagerTests }

procedure TRadIACliManagerTests.CatalogContainsSupportedExecutors;
var
  LDefinition: TRadIACliDefinition;
begin
  Assert.AreEqual<Integer>(4, Length(TRadIACliCatalog.All));
  Assert.IsTrue(TRadIACliCatalog.FindById('codex', LDefinition));
  Assert.AreEqual('Codex CLI', LDefinition.DisplayName);
  Assert.AreEqual<Integer>(2, Length(LDefinition.AuthStatusArguments));
  Assert.AreEqual('login', LDefinition.AuthStatusArguments[0]);
  Assert.AreEqual('codex login', LDefinition.AuthLoginHint);
  Assert.Contains(LDefinition.ToDiagnosticText, '@openai/codex');
  Assert.IsTrue(TRadIACliCatalog.FindById('claude', LDefinition));
  Assert.AreEqual('auth', LDefinition.AuthStatusArguments[0]);
  Assert.IsTrue(TRadIACliCatalog.FindById('gemini', LDefinition));
  Assert.AreEqual<Integer>(0, Length(LDefinition.AuthStatusArguments));
  Assert.AreEqual('Start gemini and use /auth', LDefinition.AuthLoginHint);
  Assert.IsTrue(TRadIACliCatalog.FindById('copilot', LDefinition));
  Assert.AreEqual<Integer>(0, Length(LDefinition.AuthStatusArguments));
  Assert.AreEqual('copilot login', LDefinition.AuthLoginHint);
end;

procedure TRadIACliManagerTests.DetectAllReturnsOneResultPerDefinition;
var
  LDetector: TRadIACliDetector;
  LEnvironment: IRadIACliEnvironment;
begin
  LEnvironment := TRadIAFakeCliEnvironment.Create([]);
  LDetector := TRadIACliDetector.Create(LEnvironment);
  try
    Assert.AreEqual<Integer>(4, Length(LDetector.DetectAll));
  finally
    LDetector.Free;
  end;
end;

procedure TRadIACliManagerTests.DefaultEnvironmentCanDetectWithoutConfiguration;
var
  LDetector: TRadIACliDetector;
begin
  LDetector := TRadIACliDetector.Create;
  try
    Assert.AreEqual<Integer>(4, Length(LDetector.DetectAll));
  finally
    LDetector.Free;
  end;
end;

procedure TRadIACliManagerTests.FindByIdRejectsUnknownExecutor;
var
  LDefinition: TRadIACliDefinition;
begin
  Assert.IsFalse(
    TRadIACliCatalog.FindById('unknown', LDefinition)
  );
  Assert.AreEqual('', LDefinition.Id);
end;

procedure TRadIACliManagerTests.ExpectedCodexPathUsesGlobalNpmDirectory;
var
  LExpected: string;
begin
  LExpected := TPath.Combine(
    TPath.Combine(GetEnvironmentVariable('APPDATA'), 'npm'),
    'codex.cmd'
  );
  Assert.AreEqual(
    LExpected,
    TRadIACliResolver.ExpectedExecutablePath('codex')
  );
end;

procedure TRadIACliManagerTests.FindsConfiguredExecutableBeforePath;
var
  LDefinition: TRadIACliDefinition;
  LDetection: TRadIACliDetection;
  LDetector: TRadIACliDetector;
  LEnvironment: TRadIAFakeCliEnvironment;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('codex', LDefinition));
  LEnvironment := TRadIAFakeCliEnvironment.Create(['C:\Path']);
  LEnvironment.AddFile('C:\Configured\codex.exe');
  LEnvironment.AddFile('C:\Path\codex.exe');
  LDetector := TRadIACliDetector.Create(LEnvironment);
  try
    LDetection := LDetector.Detect(
      LDefinition,
      'C:\Configured\codex.exe'
    );
    Assert.IsTrue(LDetection.Installed);
    Assert.AreEqual('configured', LDetection.Source);
    Assert.AreEqual(
      'C:\Configured\codex.exe',
      LDetection.ExecutablePath
    );
    Assert.Contains(LDetection.ToDiagnosticText, 'configured');
  finally
    LDetector.Free;
  end;
end;

procedure TRadIACliManagerTests.FindsExecutableOnPath;
var
  LDefinition: TRadIACliDefinition;
  LDetection: TRadIACliDetection;
  LDetector: TRadIACliDetector;
  LEnvironment: TRadIAFakeCliEnvironment;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('gemini', LDefinition));
  LEnvironment := TRadIAFakeCliEnvironment.Create(['C:\Tools']);
  LEnvironment.AddFile(TPath.Combine('C:\Tools', 'gemini.cmd'));
  LDetector := TRadIACliDetector.Create(LEnvironment);
  try
    LDetection := LDetector.Detect(LDefinition);
    Assert.IsTrue(LDetection.Installed);
    Assert.AreEqual('path', LDetection.Source);
    Assert.AreEqual(
      TPath.Combine('C:\Tools', 'gemini.cmd'),
      LDetection.ExecutablePath
    );
  finally
    LDetector.Free;
  end;
end;

procedure TRadIACliManagerTests.DiagnosesOfficialChannelPrerequisites;
var
  LDefinition: TRadIACliDefinition;
  LDiagnostic: TRadIACliSetupDiagnostic;
begin
  for LDefinition in TRadIACliCatalog.All do
  begin
    LDiagnostic := TRadIACliSetupAdvisor.DiagnosePrerequisite(LDefinition);
    Assert.IsNotEmpty(LDiagnostic.PrerequisiteName);
    Assert.IsNotEmpty(LDiagnostic.DocumentationUrl);
    if LDiagnostic.Ready then
      Assert.IsNotEmpty(LDiagnostic.ExecutablePath)
    else
      Assert.IsNotEmpty(LDiagnostic.Action);
  end;
end;

procedure TRadIACliManagerTests.ConvertsSetupFailuresIntoActionableGuidance;
begin
  Assert.Contains(
    TRadIACliHealth.DescribeFailure('', '''npm'' is not recognized', 1),
    'Run Diagnose'
  );
  Assert.Contains(
    TRadIACliHealth.DescribeFailure('', 'network timed out', 1),
    'Check the network'
  );
  Assert.Contains(
    TRadIACliHealth.DescribeFailure('', 'unexpected failure', 7),
    'exit code 7'
  );
end;

procedure TRadIACliManagerTests.ManualGuidanceIncludesEveryRecoveryPath;
var
  LDefinition: TRadIACliDefinition;
  LGuidance: string;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('codex', LDefinition));
  LGuidance := TRadIACliSetupAdvisor.ManualGuidance(LDefinition);
  Assert.Contains(LGuidance, 'https://github.com/openai/codex');
  Assert.Contains(LGuidance, 'npm install --global @openai/codex@latest');
  Assert.Contains(LGuidance, 'codex.exe');
  Assert.Contains(LGuidance, 'portable');
end;

procedure TRadIACliManagerTests.PrerequisiteGuidanceReturnsToOriginalFlow;
var
  LDefinition: TRadIACliDefinition;
  LDiagnostic: TRadIACliSetupDiagnostic;
  LGuidance: string;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('codex', LDefinition));
  LDiagnostic := TRadIACliSetupDiagnostic.Create(
    False,
    'Node.js and npm',
    '',
    'Install Node.js LTS.',
    'https://nodejs.org/en/download'
  );
  LGuidance := TRadIACliSetupAdvisor.PrerequisiteManualGuidance(
    LDefinition,
    LDiagnostic
  );
  Assert.Contains(LGuidance, 'current LTS release');
  Assert.Contains(LGuidance, 'https://nodejs.org/en/download');
  Assert.Contains(LGuidance, 'Click Diagnose');
  Assert.Contains(LGuidance, 'portable CLI');
end;

procedure TRadIACliManagerTests.FindsNewNpmExecutableOutsideInheritedPath;
var
  LDefinition: TRadIACliDefinition;
  LDetection: TRadIACliDetection;
  LDetector: TRadIACliDetector;
  LEnvironment: IRadIACliEnvironment;
  LFake: TRadIAFakeCliEnvironment;
  LOriginalAppData: string;
begin
  LOriginalAppData := GetEnvironmentVariable('APPDATA');
  SetEnvironmentVariable(
    PChar('APPDATA'),
    PChar('C:\NewProfile\AppData\Roaming')
  );
  try
    LFake := TRadIAFakeCliEnvironment.Create([]);
    LEnvironment := LFake;
    LFake.AddFile('C:\NewProfile\AppData\Roaming\npm\codex.cmd');
    LDetector := TRadIACliDetector.Create(LEnvironment);
    try
      Assert.IsTrue(TRadIACliCatalog.FindById('codex', LDefinition));
      LDetection := LDetector.Detect(LDefinition);
      Assert.IsTrue(LDetection.Installed);
      Assert.AreEqual(
        'C:\NewProfile\AppData\Roaming\npm\codex.cmd',
        LDetection.ExecutablePath
      );
    finally
      LDetector.Free;
    end;
  finally
    SetEnvironmentVariable(PChar('APPDATA'), PChar(LOriginalAppData));
  end;
end;

procedure TRadIACliManagerTests.PrerequisitePlanUsesOfficialNodePackage;
var
  LDefinition: TRadIACliDefinition;
  LPlan: TRadIACliInstallPlan;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('claude', LDefinition));
  LPlan := TRadIACliInstaller.BuildPrerequisitePlan(LDefinition);
  Assert.AreEqual('cmd.exe', LPlan.ExecutablePath);
  Assert.Contains(LPlan.Preview, 'OpenJS.NodeJS.LTS');
  Assert.Contains(LPlan.Preview, '--accept-package-agreements');
end;

procedure TRadIACliManagerTests.PersistsSanitizedSetupHistory;
var
  LContent: string;
  LFileName: string;
  LOriginal: string;
begin
  LFileName := TPath.Combine(TPath.GetTempPath, TPath.GetRandomFileName);
  LOriginal := GetEnvironmentVariable('RADIA_CLI_MCP_HISTORY_PATH');
  SetEnvironmentVariable(PChar('RADIA_CLI_MCP_HISTORY_PATH'), PChar(LFileName));
  try
    TRadIACliSetupHistory.Append('codex', 'test-install', True, 'exitCode=0');
    LContent := TFile.ReadAllText(LFileName, TEncoding.UTF8);
    Assert.Contains(LContent, '"clientId":"codex"');
    Assert.Contains(LContent, '"operation":"test-install"');
    Assert.Contains(LContent, '"succeeded":true');
  finally
    if TFile.Exists(LFileName) then
      TFile.Delete(LFileName);
    SetEnvironmentVariable(
      PChar('RADIA_CLI_MCP_HISTORY_PATH'),
      PChar(LOriginal)
    );
  end;
end;

procedure TRadIACliManagerTests.ResolverUsesPortableOverrideWithoutPackageManager;
var
  LDetection: TRadIACliDetection;
  LEnvironment: TRadIAFakeCliEnvironment;
begin
  LEnvironment := TRadIAFakeCliEnvironment.Create([]);
  LEnvironment.AddFile('C:\Portable\codex.exe');
  LDetection := TRadIACliResolver.Resolve(
    'codex',
    'C:\Portable\codex.exe',
    LEnvironment
  );
  Assert.IsTrue(LDetection.Installed);
  Assert.AreEqual('configured', LDetection.Source);
  Assert.AreEqual('C:\Portable\codex.exe', LDetection.ExecutablePath);
end;

procedure TRadIACliManagerTests.ResolverUsesPathWhenOverrideIsMissing;
var
  LDetection: TRadIACliDetection;
  LEnvironment: TRadIAFakeCliEnvironment;
begin
  LEnvironment := TRadIAFakeCliEnvironment.Create(['C:\Alternative']);
  LEnvironment.AddFile('C:\Alternative\codex.exe');
  LDetection := TRadIACliResolver.Resolve(
    'codex',
    '',
    LEnvironment
  );
  Assert.IsTrue(LDetection.Installed);
  Assert.AreEqual('path', LDetection.Source);
  Assert.AreEqual('C:\Alternative\codex.exe', LDetection.ExecutablePath);
end;

procedure TRadIACliManagerTests.MissingConfiguredPathFallsBackToEnvironmentPath;
var
  LDefinition: TRadIACliDefinition;
  LDetection: TRadIACliDetection;
  LDetector: TRadIACliDetector;
  LEnvironment: TRadIAFakeCliEnvironment;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('copilot', LDefinition));
  LEnvironment := TRadIAFakeCliEnvironment.Create(['C:\Tools']);
  LEnvironment.AddFile(TPath.Combine('C:\Tools', 'copilot.exe'));
  LDetector := TRadIACliDetector.Create(LEnvironment);
  try
    LDetection := LDetector.Detect(
      LDefinition,
      'C:\Missing\copilot.exe'
    );
    Assert.IsTrue(LDetection.Installed);
    Assert.AreEqual('path', LDetection.Source);
  finally
    LDetector.Free;
  end;
end;

procedure TRadIACliManagerTests.ReportsMissingExecutable;
var
  LDefinition: TRadIACliDefinition;
  LDetection: TRadIACliDetection;
  LDetector: TRadIACliDetector;
  LEnvironment: IRadIACliEnvironment;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('claude', LDefinition));
  LEnvironment := TRadIAFakeCliEnvironment.Create(['C:\Empty']);
  LDetector := TRadIACliDetector.Create(LEnvironment);
  try
    LDetection := LDetector.Detect(LDefinition);
    Assert.IsFalse(LDetection.Installed);
    Assert.AreEqual('', LDetection.ExecutablePath);
  finally
    LDetector.Free;
  end;
end;

procedure TRadIACliManagerTests.CopilotInstallPlanUsesOfficialWingetPackage;
var
  LDefinition: TRadIACliDefinition;
  LPlan: TRadIACliInstallPlan;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('copilot', LDefinition));
  LPlan := TRadIACliInstaller.BuildPlan(LDefinition);
  Assert.AreEqual('cmd.exe', LPlan.ExecutablePath);
  Assert.AreEqual('/d', LPlan.Arguments[0]);
  Assert.Contains(LPlan.Preview, 'winget install');
  Assert.Contains(LPlan.Preview, 'GitHub.Copilot');
  Assert.Contains(LPlan.Preview, '--disable-interactivity');
end;

procedure TRadIACliManagerTests.NpmInstallPlansUseOfficialPackages;
var
  LDefinition: TRadIACliDefinition;
  LPlan: TRadIACliInstallPlan;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('codex', LDefinition));
  LPlan := TRadIACliInstaller.BuildPlan(LDefinition);
  Assert.Contains(LPlan.Preview, '@openai/codex@latest');
  Assert.IsTrue(TRadIACliCatalog.FindById('claude', LDefinition));
  LPlan := TRadIACliInstaller.BuildPlan(LDefinition);
  Assert.Contains(LPlan.Preview, '@anthropic-ai/claude-code@latest');
  Assert.IsTrue(TRadIACliCatalog.FindById('gemini', LDefinition));
  LPlan := TRadIACliInstaller.BuildPlan(LDefinition);
  Assert.Contains(LPlan.Preview, '@google/gemini-cli@latest');
end;

procedure TRadIACliManagerTests.NormalizesCliVersionOutput;
begin
  Assert.AreEqual(
    'codex-cli 1.2.3',
    TRadIACliHealth.NormalizeVersionOutput(
      'codex-cli 1.2.3' + sLineBreak + 'details',
      ''
    )
  );
  Assert.AreEqual(
    'claude 4.5.0',
    TRadIACliHealth.NormalizeVersionOutput('', 'claude 4.5.0')
  );
  Assert.AreEqual('', TRadIACliHealth.NormalizeVersionOutput('', ''));
end;

procedure TRadIACliManagerTests.ComparesCliSemanticVersions;
begin
  Assert.IsFalse(
    TRadIACliHealth.VersionMeetsMinimum(
      'codex-cli 0.130.0-alpha.5',
      '0.144.0'
    )
  );
  Assert.IsTrue(
    TRadIACliHealth.VersionMeetsMinimum('codex-cli 0.144.0', '0.144.0')
  );
  Assert.IsTrue(
    TRadIACliHealth.VersionMeetsMinimum('codex-cli 0.145.0-alpha.13', '0.144.0')
  );
  Assert.IsFalse(TRadIACliHealth.VersionMeetsMinimum('unknown', '0.144.0'));
end;

procedure TRadIACliManagerTests.InstallPlanRejectsShellMetacharacters;
var
  LDefinition: TRadIACliDefinition;
  LPlan: TRadIACliInstallPlan;
  LTestMethod: TTestLocalMethod;
begin
  LPlan := Default(TRadIACliInstallPlan);
  LDefinition := TRadIACliDefinition.Create(
    ckGemini,
    'unsafe',
    'Unsafe',
    ['unsafe.cmd'],
    cicNpm,
    '@vendor/package & whoami',
    'https://example.invalid'
  );
  LTestMethod :=
    procedure
    begin
      LPlan := TRadIACliInstaller.BuildPlan(LDefinition);
    end;
  Assert.WillRaise(LTestMethod, EArgumentException);
  Assert.AreEqual('', LPlan.ExecutablePath);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIACliManagerTests);

end.
