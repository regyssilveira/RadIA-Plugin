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
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  RadIA.Semantic.Client;

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
