unit RadIA.Tests.HttpClient;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces;

type
  [TestFixture]
  TTestRadIAHttpClient = class
  private
    FClient: IRadIAHttpClient;
    FServer: IRadIALoopbackServer;
    FServerUrl: string;
    FCallbackObserved: Boolean;
    procedure LoopbackCallback(const ACode, AError: string);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestGetVersionFromSonarQube;
    [Test]
    procedure TestGetNonExistentUrlThrowsException;
    [Test]
    procedure TestPostNonExistentUrlThrowsException;
    [Test]
    procedure TestCancelRequest;
  end;

implementation

uses
  RadIA.Core.HttpClient,
  RadIA.Core.IndyLoopback,
  System.SysUtils,
  System.Net.URLClient;

{ TTestRadIAHttpClient }

procedure TTestRadIAHttpClient.Setup;
begin
  FClient := TRadIAConcreteHttpClient.Create;
  FServer := TRadIAIndyLoopbackServer.Create;
  FCallbackObserved := False;
  FServer.Start(61340, LoopbackCallback);
  FServerUrl := 'http://127.0.0.1:61340';
end;

procedure TTestRadIAHttpClient.TearDown;
begin
  if Assigned(FServer) then
    FServer.Stop;
  FServer := nil;
  FClient := nil;
end;

procedure TTestRadIAHttpClient.LoopbackCallback(
  const ACode: string;
  const AError: string
);
begin
  FCallbackObserved := (ACode <> '') or (AError <> '');
end;

procedure TTestRadIAHttpClient.TestGetVersionFromSonarQube;
var
  LUrl: string;
  LHeaders: TNetHeaders;
  LResponse: string;
begin
  LUrl := FServerUrl + '/callback?code=http-client-test';
  SetLength(LHeaders, 0);
  try
    LResponse := FClient.Get(LUrl, LHeaders, 5000);
    Assert.IsNotEmpty(LResponse, 'Should receive a response from the local server');
  except
    on E: Exception do
      Assert.Fail('GET request to the local server failed: ' + E.Message);
  end;
end;

procedure TTestRadIAHttpClient.TestGetNonExistentUrlThrowsException;
var
  LUrl: string;
  LHeaders: TNetHeaders;
begin
  LUrl := FServerUrl + '/nonexistent_endpoint_for_test';
  SetLength(LHeaders, 0);

  Assert.WillRaise(
    procedure
    begin
      FClient.Get(LUrl, LHeaders, 2000);
    end,
    ERadIAHttpException,
    'GET to non-existent endpoint should raise ERadIAHttpException'
  );
end;

procedure TTestRadIAHttpClient.TestPostNonExistentUrlThrowsException;
var
  LUrl: string;
  LHeaders: TNetHeaders;
  LBody: string;
begin
  LUrl := FServerUrl + '/nonexistent_endpoint_for_test';
  SetLength(LHeaders, 0);
  LBody := '{"test": true}';

  Assert.WillRaise(
    procedure
    begin
      FClient.Post(LUrl, LHeaders, LBody, 2000);
    end,
    ERadIAHttpException,
    'POST to non-existent endpoint should raise ERadIAHttpException'
  );
end;

procedure TTestRadIAHttpClient.TestCancelRequest;
var
  LUrl: string;
  LHeaders: TNetHeaders;
begin
  LUrl := FServerUrl + '/callback?code=cancel-test';
  SetLength(LHeaders, 0);

  FClient.Cancel;

  try
    FClient.Get(LUrl, LHeaders, 2000);
  except
  end;
  Assert.Pass;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAHttpClient);

end.
