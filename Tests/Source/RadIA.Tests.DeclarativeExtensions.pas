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
