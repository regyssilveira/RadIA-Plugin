unit RadIA.Tests.CliMcpSettings;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIACliMcpSettingsTests = class
  public
    [Test]
    procedure MissingClientUsesDefaults;
    [Test]
    procedure SavedClientPathsCanBeLoaded;
    [Test]
    procedure ClientsAreStoredIndependently;
    [Test]
    procedure InvalidClientIdIsRejected;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.CliMcpSettings,
  RadIA.Core.SettingsStorage;

const
  CBasePath = 'Software\RadIA\Tests\CliMcp';

procedure TRadIACliMcpSettingsTests.ClientsAreStoredIndependently;
var
  LSettings: TRadIACliMcpSettings;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LSettings := TRadIACliMcpSettings.Create(LStorage, CBasePath);
  try
    LSettings.Save(
      'codex',
      TRadIACliMcpClientSettings.Create('codex.exe', 'codex.toml', 'bridge.exe')
    );
    LSettings.Save(
      'gemini',
      TRadIACliMcpClientSettings.Create('gemini.cmd', 'gemini.json', 'bridge.exe')
    );
    Assert.Contains(
      LSettings.Load('codex', '', '').ToDiagnosticText,
      'codex.exe'
    );
    Assert.Contains(
      LSettings.Load('gemini', '', '').ToDiagnosticText,
      'gemini.cmd'
    );
  finally
    LSettings.Free;
  end;
end;

procedure TRadIACliMcpSettingsTests.InvalidClientIdIsRejected;
var
  LSettings: TRadIACliMcpSettings;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LSettings := TRadIACliMcpSettings.Create(LStorage, CBasePath);
  try
    Assert.WillRaise(
      procedure
      begin
        LSettings.Load('..\invalid', '', '');
      end,
      EArgumentException
    );
  finally
    LSettings.Free;
  end;
end;

procedure TRadIACliMcpSettingsTests.MissingClientUsesDefaults;
var
  LLoaded: TRadIACliMcpClientSettings;
  LSettings: TRadIACliMcpSettings;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LSettings := TRadIACliMcpSettings.Create(LStorage, CBasePath);
  try
    LLoaded := LSettings.Load(
      'codex',
      'default.toml',
      'default-bridge.exe'
    );
    Assert.AreEqual('', LLoaded.CliExecutablePath);
    Assert.AreEqual('default.toml', LLoaded.McpConfigPath);
    Assert.AreEqual('default-bridge.exe', LLoaded.McpBridgePath);
  finally
    LSettings.Free;
  end;
end;

procedure TRadIACliMcpSettingsTests.SavedClientPathsCanBeLoaded;
var
  LLoaded: TRadIACliMcpClientSettings;
  LSettings: TRadIACliMcpSettings;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LSettings := TRadIACliMcpSettings.Create(LStorage, CBasePath);
  try
    LSettings.Save(
      'claude',
      TRadIACliMcpClientSettings.Create(
        'C:\bin\claude.exe',
        'C:\config\claude.json',
        'C:\radia\bridge.exe'
      )
    );
    LLoaded := LSettings.Load('claude', '', '');
    Assert.AreEqual('C:\bin\claude.exe', LLoaded.CliExecutablePath);
    Assert.AreEqual('C:\config\claude.json', LLoaded.McpConfigPath);
    Assert.AreEqual('C:\radia\bridge.exe', LLoaded.McpBridgePath);
  finally
    LSettings.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIACliMcpSettingsTests);

end.
