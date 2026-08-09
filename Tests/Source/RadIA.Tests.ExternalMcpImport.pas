unit RadIA.Tests.ExternalMcpImport;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAExternalMcpImportTests = class
  public
    [Test]
    procedure ImportsStandardConfigurationWithoutExecutingIt;
    [Test]
    procedure RejectsInvalidServerWithoutPartialImport;
  end;

implementation

uses
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpImport;

procedure TRadIAExternalMcpImportTests.ImportsStandardConfigurationWithoutExecutingIt;
var
  LError: string;
  LServers: TArray<TRadIAExternalMcpServerConfig>;
begin
  Assert.IsTrue(
    TRadIAExternalMcpConfigImporter.ImportJson(
      '{"mcpServers":{"local-files":{' +
      '"command":"C:\\Tools\\server.exe",' +
      '"args":["--root","C:\\Work"],' +
      '"cwd":"C:\\Work","timeoutMs":45000}}}',
      LServers,
      LError
    ),
    LError
  );
  Assert.AreEqual<Integer>(1, Length(LServers));
  Assert.AreEqual('local-files', LServers[0].Id);
  Assert.AreEqual('C:\Tools\server.exe', LServers[0].Command);
  Assert.AreEqual<Integer>(2, Length(LServers[0].Arguments));
  Assert.AreEqual<Cardinal>(45000, LServers[0].TimeoutMs);
  Assert.IsTrue(LServers[0].Enabled);
end;

procedure TRadIAExternalMcpImportTests.RejectsInvalidServerWithoutPartialImport;
var
  LError: string;
  LServers: TArray<TRadIAExternalMcpServerConfig>;
begin
  Assert.IsFalse(
    TRadIAExternalMcpConfigImporter.ImportJson(
      '{"mcpServers":{"valid":{"command":"server.exe"},' +
      '"invalid id":{"command":"server.exe"}}}',
      LServers,
      LError
    )
  );
  Assert.Contains(LError, 'Invalid imported server');
  Assert.AreEqual<Integer>(0, Length(LServers));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAExternalMcpImportTests);

end.
