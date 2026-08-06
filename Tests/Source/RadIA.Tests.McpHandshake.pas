unit RadIA.Tests.McpHandshake;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAMcpHandshakeTests = class
  public
    [Test]
    procedure InputContainsInitializationPingAndToolsList;
    [Test]
    procedure CompleteResponsesAreAccepted;
    [Test]
    procedure MissingResponseIsRejected;
    [Test]
    procedure ErrorResponseIsRejected;
    [Test]
    procedure InvalidJsonIsRejected;
    [Test]
    procedure NonObjectJsonIsRejected;
  end;

implementation

uses
  RadIA.Core.McpHandshake;

function CompleteOutput: string;
begin
  Result :=
    '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18",' +
    '"capabilities":{"tools":{}},"serverInfo":{"name":"Rad IA","version":"2.0.0"}}}' +
    sLineBreak +
    '{"jsonrpc":"2.0","id":2,"result":{}}' + sLineBreak +
    '{"jsonrpc":"2.0","id":3,"result":{"tools":[{"name":"ReadFile"},' +
    '{"name":"BuildProject"}]}}' + sLineBreak;
end;

procedure TRadIAMcpHandshakeTests.CompleteResponsesAreAccepted;
var
  LResult: TRadIAMcpHandshakeResult;
begin
  LResult := TRadIAMcpHandshake.ParseOutput(CompleteOutput);
  Assert.IsTrue(LResult.Succeeded);
  Assert.AreEqual('2025-06-18', LResult.ProtocolVersion);
  Assert.AreEqual(2, LResult.ToolCount);
  Assert.Contains(LResult.Message, 'Handshake succeeded');
end;

procedure TRadIAMcpHandshakeTests.ErrorResponseIsRejected;
var
  LResult: TRadIAMcpHandshakeResult;
begin
  LResult := TRadIAMcpHandshake.ParseOutput(
    '{"jsonrpc":"2.0","id":1,"error":{"code":-32603,"message":"failed"}}'
  );
  Assert.IsFalse(LResult.Succeeded);
  Assert.Contains(LResult.Message, 'returned an error');
end;

procedure TRadIAMcpHandshakeTests.InputContainsInitializationPingAndToolsList;
var
  LInput: string;
begin
  LInput := TRadIAMcpHandshake.BuildInput;
  Assert.Contains(LInput, '"method":"initialize"');
  Assert.Contains(LInput, '"method":"notifications/initialized"');
  Assert.Contains(LInput, '"method":"ping"');
  Assert.Contains(LInput, '"method":"tools/list"');
  Assert.Contains(LInput, '"protocolVersion":"2025-06-18"');
end;

procedure TRadIAMcpHandshakeTests.InvalidJsonIsRejected;
var
  LResult: TRadIAMcpHandshakeResult;
begin
  LResult := TRadIAMcpHandshake.ParseOutput('not-json');
  Assert.IsFalse(LResult.Succeeded);
  Assert.Contains(LResult.Message, 'Invalid JSON');
end;

procedure TRadIAMcpHandshakeTests.MissingResponseIsRejected;
var
  LResult: TRadIAMcpHandshakeResult;
begin
  LResult := TRadIAMcpHandshake.ParseOutput(
    '{"jsonrpc":"2.0","id":1,"result":{"protocolVersion":"2025-06-18"}}'
  );
  Assert.IsFalse(LResult.Succeeded);
  Assert.Contains(LResult.Message, 'incomplete');
end;

procedure TRadIAMcpHandshakeTests.NonObjectJsonIsRejected;
var
  LResult: TRadIAMcpHandshakeResult;
begin
  LResult := TRadIAMcpHandshake.ParseOutput('[]');
  Assert.IsFalse(LResult.Succeeded);
  Assert.Contains(LResult.Message, 'Invalid JSON');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAMcpHandshakeTests);

end.
