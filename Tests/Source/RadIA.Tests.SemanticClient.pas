unit RadIA.Tests.SemanticClient;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIASemanticClientTests = class
  public
    [Test]
    procedure ProbeAcceptsPackagedEngine;
    [Test]
    procedure ProbeReportsMissingEngine;
    [Test]
    procedure DefaultPathUsesPackageDirectory;
    [Test]
    procedure SupervisorKeepsEngineAliveAcrossRequests;
    [Test]
    procedure SupervisorRestartsAfterTransportFailure;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.ExternalMcp,
  RadIA.Core.ExternalMcpTransport,
  RadIA.Semantic.Client;

type
  TRadIAFailOnceSemanticTransport = class(
    TInterfacedObject,
    IRadIAExternalMcpTransport
  )
  private
    FLastError: string;
    FResponse: string;
    FRunning: Boolean;
    FStartCount: Integer;
  public
    function GetLastError: string;
    function GetRunning: Boolean;
    function Receive(
      const ATimeoutMs: Cardinal;
      out AMessage: string
    ): Boolean;
    function Send(const AMessage: string): Boolean;
    function Start(
      const AConfig: TRadIAExternalMcpServerConfig;
      out AError: string
    ): Boolean;
    procedure Stop;
  end;

function TRadIAFailOnceSemanticTransport.GetLastError: string;
begin
  Result := FLastError;
end;

function TRadIAFailOnceSemanticTransport.GetRunning: Boolean;
begin
  Result := FRunning;
end;

function TRadIAFailOnceSemanticTransport.Receive(
  const ATimeoutMs: Cardinal;
  out AMessage: string
): Boolean;
begin
  AMessage := FResponse;
  FResponse := '';
  Result := AMessage <> '';
end;

function TRadIAFailOnceSemanticTransport.Send(
  const AMessage: string
): Boolean;
begin
  if AMessage.Contains('"method":"initialize"') then
  begin
    FResponse :=
      '{"id":0,"result":{"name":"RadIA Semantic Engine",' +
      '"protocolVersion":"1.0"}}';
    Exit(True);
  end;
  if FStartCount = 1 then
  begin
    FLastError := 'Simulated process failure.';
    FRunning := False;
    Exit(False);
  end;
  FResponse := '{"id":1,"result":{"tokens":[]}}';
  Result := True;
end;

function TRadIAFailOnceSemanticTransport.Start(
  const AConfig: TRadIAExternalMcpServerConfig;
  out AError: string
): Boolean;
begin
  Inc(FStartCount);
  FLastError := '';
  FRunning := True;
  AError := '';
  Result := True;
end;

procedure TRadIAFailOnceSemanticTransport.Stop;
begin
  FRunning := False;
end;

procedure TRadIASemanticClientTests.ProbeAcceptsPackagedEngine;
var
  LPath: string;
  LResult: TRadIASemanticEngineProbe;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LResult := TRadIASemanticEngineClient.Probe(LPath);
  Assert.IsTrue(LResult.Ready, LResult.ErrorMessage);
  Assert.AreEqual('RadIA Semantic Engine', LResult.Name);
  Assert.AreEqual('1.0', LResult.ProtocolVersion);
end;

procedure TRadIASemanticClientTests.ProbeReportsMissingEngine;
var
  LResult: TRadIASemanticEngineProbe;
begin
  LResult := TRadIASemanticEngineClient.Probe(
    TPath.Combine(TPath.GetTempPath, 'missing-semantic-engine.exe')
  );
  Assert.IsFalse(LResult.Ready);
  Assert.IsTrue(LResult.ErrorMessage.Contains('was not found'));
end;

procedure TRadIASemanticClientTests.SupervisorKeepsEngineAliveAcrossRequests;
var
  LError: string;
  LPath: string;
  LResponse: string;
  LSupervisor: TRadIASemanticEngineSupervisor;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LSupervisor := TRadIASemanticEngineSupervisor.Create(LPath);
  try
    Assert.IsTrue(
      LSupervisor.Request(
        'tokenize',
        '{"source":"unit Sample;"}',
        LResponse,
        LError
      ),
      LError
    );
    Assert.Contains(LResponse, '"tokens"');
    Assert.IsTrue(
      LSupervisor.Request(
        'preprocess',
        '{"source":"{$IFDEF DEBUG}On{$ENDIF}","defines":["DEBUG"]}',
        LResponse,
        LError
      ),
      LError
    );
    Assert.Contains(LResponse, '"activity":"active"');
    Assert.IsTrue(
      LSupervisor.Request(
        'parse',
        '{"source":"unit ProtocolSample; interface implementation end."}',
        LResponse,
        LError
      ),
      LError
    );
    Assert.Contains(LResponse, '"name":"ProtocolSample"');
    Assert.AreEqual(0, LSupervisor.RestartCount);
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.SupervisorRestartsAfterTransportFailure;
var
  LError: string;
  LPath: string;
  LResponse: string;
  LSupervisor: TRadIASemanticEngineSupervisor;
  LTransport: IRadIAExternalMcpTransport;
begin
  LPath := TPath.Combine(
    ExtractFilePath(ParamStr(0)),
    'RadIA.Semantic.Engine.exe'
  );
  LTransport := TRadIAFailOnceSemanticTransport.Create;
  LSupervisor := TRadIASemanticEngineSupervisor.Create(
    LPath,
    5000,
    LTransport
  );
  try
    Assert.IsTrue(
      LSupervisor.Request('tokenize', '{"source":""}', LResponse, LError),
      LError
    );
    Assert.Contains(LResponse, '"tokens"');
    Assert.AreEqual(1, LSupervisor.RestartCount);
  finally
    LSupervisor.Free;
  end;
end;

procedure TRadIASemanticClientTests.DefaultPathUsesPackageDirectory;
begin
  Assert.IsTrue(
    TRadIASemanticEngineClient.DefaultExecutablePath.EndsWith(
      'RadIA.Semantic.Engine.exe'
    )
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIASemanticClientTests);

end.
