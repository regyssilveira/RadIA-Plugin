unit RadIA.Tests.ExternalMcpSettings;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAExternalMcpSettingsTests = class
  private
    FDirectory: string;
    FFileName: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure RoundTripProtectsAllConfigurationDetails;
    [Test]
    procedure CorruptedEnvelopeFailsWithoutPartialConfiguration;
    [Test]
    procedure InvalidSavePreservesPreviousSettings;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpSecurity,
  RadIA.Core.ExternalMcpSettings,
  RadIA.Core.Tools;

function ServerConfig: TRadIAExternalMcpServerConfig;
begin
  Result := TRadIAExternalMcpServerConfig.Create(
    'fixture',
    'Fixture Server',
    'C:\Tools\fixture.exe',
    ['--token', 'secret-value'],
    'C:\Workspace\Project',
    True,
    15000
  );
end;

function ToolGrant: TRadIAExternalMcpToolGrant;
begin
  Result := TRadIAExternalMcpToolGrant.Create(
    'mcp.fixture.read_file',
    trReadOnly,
    False,
    ['path'],
    False
  );
end;

procedure TRadIAExternalMcpSettingsTests.Setup;
begin
  FDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-ExternalMcpSettings-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FDirectory);
  FFileName := TPath.Combine(FDirectory, 'external-mcp.json');
end;

procedure TRadIAExternalMcpSettingsTests.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TRadIAExternalMcpSettingsTests.RoundTripProtectsAllConfigurationDetails;
var
  LError: string;
  LFileContent: string;
  LGrants: TArray<TRadIAExternalMcpToolGrant>;
  LServers: TArray<TRadIAExternalMcpServerConfig>;
  LStore: IRadIAExternalMcpSettingsStore;
begin
  LStore := TRadIAExternalMcpSettingsStore.Create(FFileName);
  Assert.IsTrue(LStore.Save([ServerConfig], [ToolGrant], LError), LError);
  LFileContent := TFile.ReadAllText(FFileName, TEncoding.UTF8);
  Assert.Contains(LFileContent, 'protectedPayload');
  Assert.DoesNotContain(LFileContent, 'fixture.exe');
  Assert.DoesNotContain(LFileContent, 'secret-value');
  Assert.DoesNotContain(LFileContent, 'read_file');
  Assert.IsTrue(LStore.Load(LServers, LGrants, LError), LError);
  Assert.AreEqual<Integer>(1, Length(LServers));
  Assert.AreEqual('C:\Tools\fixture.exe', LServers[0].Command);
  Assert.AreEqual('secret-value', LServers[0].Arguments[1]);
  Assert.AreEqual<Integer>(1, Length(LGrants));
  Assert.AreEqual('mcp.fixture.read_file', LGrants[0].NamespacedName);
  Assert.AreEqual('path', LGrants[0].PathArguments[0]);
end;

procedure TRadIAExternalMcpSettingsTests.CorruptedEnvelopeFailsWithoutPartialConfiguration;
var
  LError: string;
  LGrants: TArray<TRadIAExternalMcpToolGrant>;
  LServers: TArray<TRadIAExternalMcpServerConfig>;
  LStore: IRadIAExternalMcpSettingsStore;
begin
  TFile.WriteAllText(
    FFileName,
    '{"schemaVersion":1,"protectedPayload":"broken"}',
    TEncoding.UTF8
  );
  LStore := TRadIAExternalMcpSettingsStore.Create(FFileName);
  Assert.IsFalse(LStore.Load(LServers, LGrants, LError));
  Assert.AreEqual<Integer>(0, Length(LServers));
  Assert.AreEqual<Integer>(0, Length(LGrants));
  Assert.IsNotEmpty(LError);
end;

procedure TRadIAExternalMcpSettingsTests.InvalidSavePreservesPreviousSettings;
var
  LError: string;
  LOriginal: string;
  LStore: IRadIAExternalMcpSettingsStore;
begin
  LStore := TRadIAExternalMcpSettingsStore.Create(FFileName);
  Assert.IsTrue(LStore.Save([ServerConfig], [ToolGrant], LError), LError);
  LOriginal := TFile.ReadAllText(FFileName, TEncoding.UTF8);
  Assert.IsFalse(
    LStore.Save(
      [ServerConfig],
      [TRadIAExternalMcpToolGrant.Create(
        'mcp.unknown.read_file',
        trReadOnly,
        False,
        ['path'],
        False
      )],
      LError
    )
  );
  Assert.Contains(LError, 'unknown server');
  Assert.AreEqual(
    LOriginal,
    TFile.ReadAllText(FFileName, TEncoding.UTF8)
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAExternalMcpSettingsTests);

end.
