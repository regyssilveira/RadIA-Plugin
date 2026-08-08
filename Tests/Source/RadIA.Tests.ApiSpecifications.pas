unit RadIA.Tests.ApiSpecifications;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAApiSpecifications = class
  public
    [Test]
    procedure ParsesNeutralEndpointSpecification;
    [Test]
    procedure RejectsDuplicateRoutes;
    [Test]
    procedure RejectsInvalidEndpointName;
    [Test]
    procedure RejectsUnsupportedMethod;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.ApiSpecifications;

const
  CValidSpecification =
    '{"schemaVersion":1,"port":8090,"enableSwagger":true,' +
    '"endpoints":[{"name":"ReadTelemetry","group":"Telemetry",' +
    '"method":"GET","path":"/telemetry/{id}","statusCode":200}]}';

procedure TTestRadIAApiSpecifications.ParsesNeutralEndpointSpecification;
var
  LSpecification: TRadIAApiSpecification;
begin
  LSpecification := TRadIAApiSpecificationParser.Parse(
    'TelemetryApi',
    asMinimal,
    CValidSpecification
  );
  Assert.AreEqual(8090, LSpecification.Port);
  Assert.AreEqual(1, Length(LSpecification.Endpoints));
  Assert.AreEqual('Telemetry', LSpecification.Endpoints[0].Group);
  Assert.AreEqual('/telemetry/{id}', LSpecification.Endpoints[0].Path);
end;

procedure TTestRadIAApiSpecifications.RejectsDuplicateRoutes;
begin
  Assert.WillRaise(
    procedure
    begin
      TRadIAApiSpecificationParser.Parse(
        'DuplicateApi',
        asControllers,
        '{"schemaVersion":1,"endpoints":[' +
        '{"name":"First","method":"GET","path":"/status"},' +
        '{"name":"Second","method":"get","path":"/status"}]}'
      );
    end,
    EArgumentException
  );
end;

procedure TTestRadIAApiSpecifications.RejectsInvalidEndpointName;
begin
  Assert.WillRaise(
    procedure
    begin
      TRadIAApiSpecificationParser.Parse(
        'InvalidApi',
        asMinimal,
        '{"schemaVersion":1,"endpoints":[' +
        '{"name":"invalid-name","method":"GET","path":"/status"}]}'
      );
    end,
    EArgumentException
  );
end;

procedure TTestRadIAApiSpecifications.RejectsUnsupportedMethod;
begin
  Assert.WillRaise(
    procedure
    begin
      TRadIAApiSpecificationParser.Parse(
        'InvalidApi',
        asMinimal,
        '{"schemaVersion":1,"endpoints":[' +
        '{"name":"TraceStatus","method":"TRACE","path":"/status"}]}'
      );
    end,
    EArgumentException
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAApiSpecifications);

end.
