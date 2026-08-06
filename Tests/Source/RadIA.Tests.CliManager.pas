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
  end;

implementation

uses
  System.SysUtils,
  System.IOUtils;

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
  Assert.Contains(LDefinition.ToDiagnosticText, '@openai/codex');
  Assert.IsTrue(TRadIACliCatalog.FindById('claude', LDefinition));
  Assert.IsTrue(TRadIACliCatalog.FindById('gemini', LDefinition));
  Assert.IsTrue(TRadIACliCatalog.FindById('copilot', LDefinition));
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
