unit RadIA.Tests.OAuth;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces, RadIA.Core.OAuth,
  RadIA.Core.SettingsStorage, System.Net.URLClient, System.SysUtils;

type
  TMockOAuthHttpClient = class(TInterfacedObject, IRadIAHttpClient)
  private
    FResponse: string;
    FErrorStatusCode: Integer;
    FErrorContent: string;
  public
    constructor Create(const AResponse: string = '');
    function Get(const AUrl: string; const AHeaders: TNetHeaders; const ATimeoutMs: Integer = 0): string;
    function Post(
      const AUrl: string;
      const AHeaders: TNetHeaders;
      const ARequestBody: string;
      const ATimeoutMs: Integer = 0
    ): string;
    procedure PostStream(
      const AUrl: string;
      const AHeaders: TNetHeaders;
      const ARequestBody: string;
      const AOnWrite: TProc<TBytes>;
      const ATimeoutMs: Integer = 0
    );
    procedure Cancel;
    procedure SetErrorResponse(const AStatusCode: Integer; const AContent: string);

    property Response: string read FResponse write FResponse;
  end;

  TMockLoopbackServer = class(TInterfacedObject, IRadIALoopbackServer)
  private
    FRunning: Boolean;
    FPort: Word;
    FCallback: TLoopbackCallback;
  public
    procedure Start(const APort: Word; const ACallback: TLoopbackCallback);
    procedure Stop;
    function GetActivePort: Word;
    function IsRunning: Boolean;

    property Callback: TLoopbackCallback read FCallback;
  end;

  TTestableOAuthManager = class(TRadIAOAuthManager)
  private
    FLastOpenedUrl: string;
  protected
    procedure OpenBrowser(const AUrl: string); override;
  public
    property LastOpenedUrl: string read FLastOpenedUrl;
  end;

  [TestFixture]
  TTestRadIAOAuth = class
  private
    FConfig: IRadIAConfig;
    FStorage: IRadIASettingsStorage;
    FMockServer: TMockLoopbackServer;
    FMockHttpClient: TMockOAuthHttpClient;
    FManager: TTestableOAuthManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestPKCEGeneration;
    [Test]
    procedure TestStartLoginTriggersLoopbackStartAndOpensUrl;
    [Test]
    procedure TestHandleCallbackWithError;
    [Test]
    procedure TestHandleCallbackWithSuccess;
    [Test]
    procedure TestHandleCallbackWithExchangeError;
    [Test]
    procedure TestCancelLoginStopsServer;
    [Test]
    procedure TestRefreshAccessTokenSuccess;
  end;

implementation

uses
  RadIA.Core.Config;

{ TMockOAuthHttpClient }

constructor TMockOAuthHttpClient.Create(const AResponse: string);
begin
  inherited Create;
  FResponse := AResponse;
  FErrorStatusCode := 0;
end;

function TMockOAuthHttpClient.Get(const AUrl: string; const AHeaders: TNetHeaders; const ATimeoutMs: Integer): string;
begin
  Result := '';
end;

function TMockOAuthHttpClient.Post(
  const AUrl: string;
  const AHeaders: TNetHeaders;
  const ARequestBody: string;
  const ATimeoutMs: Integer
): string;
begin
  if FErrorStatusCode <> 0 then
    raise ERadIAHttpException.Create(FErrorContent, FErrorStatusCode, FErrorContent);
  Result := FResponse;
end;

procedure TMockOAuthHttpClient.PostStream(
  const AUrl: string;
  const AHeaders: TNetHeaders;
  const ARequestBody: string;
  const AOnWrite: TProc<TBytes>;
  const ATimeoutMs: Integer
);
begin
  if True then ;
end;

procedure TMockOAuthHttpClient.Cancel;
begin
  if True then ;
end;

procedure TMockOAuthHttpClient.SetErrorResponse(const AStatusCode: Integer; const AContent: string);
begin
  FErrorStatusCode := AStatusCode;
  FErrorContent := AContent;
end;

{ TMockLoopbackServer }

procedure TMockLoopbackServer.Start(const APort: Word; const ACallback: TLoopbackCallback);
begin
  FPort := APort;
  FCallback := ACallback;
  FRunning := True;
end;

procedure TMockLoopbackServer.Stop;
begin
  FRunning := False;
end;

function TMockLoopbackServer.GetActivePort: Word;
begin
  Result := FPort;
end;

function TMockLoopbackServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

{ TTestableOAuthManager }

procedure TTestableOAuthManager.OpenBrowser(const AUrl: string);
begin
  FLastOpenedUrl := AUrl;
end;

{ TTestRadIAOAuth }

procedure TTestRadIAOAuth.Setup;
begin
  TRadIAConfig.SetBaseRegistryPath('Software\TestRadIAOAuth');
  FStorage := TRadIAMemorySettingsStorage.Create;
  TRadIAConfig.SetStorage(FStorage);
  FConfig := TRadIAConfig.Create;
  FConfig.Load;

  FMockHttpClient := TMockOAuthHttpClient.Create;
  FMockServer := TMockLoopbackServer.Create;
  FManager := TTestableOAuthManager.Create(FConfig, FMockServer, FMockHttpClient);
end;

procedure TTestRadIAOAuth.TearDown;
begin
  FManager.Free;
  FConfig := nil;
  FStorage := nil;
  TRadIAConfig.SetStorage(nil);
  TRadIAConfig.SetBaseRegistryPath('');
end;

procedure TTestRadIAOAuth.TestPKCEGeneration;
var
  LVerifier: string;
  LChallenge: string;
begin
  LVerifier := TRadIAOAuthManager.GenerateVerifier;
  Assert.AreEqual<Integer>(
    64,
    Length(LVerifier),
    'Verifier must be 64 characters long.'
  );

  LChallenge := TRadIAOAuthManager.GenerateChallenge(LVerifier);
  Assert.IsNotEmpty(LChallenge, 'Challenge must not be empty.');
  Assert.IsFalse(LChallenge.Contains('='), 'Challenge must be Base64URL-encoded.');
end;

procedure TTestRadIAOAuth.TestStartLoginTriggersLoopbackStartAndOpensUrl;
begin
  Assert.IsFalse(FMockServer.IsRunning);

  FManager.StartLogin(
    'OpenAI',
    TRadIAOAuthParams.Create(
      'https://auth.openai.com/oauth/authorize',
      'https://auth.openai.com/oauth/token',
      'app_EMoamEEZ73f0CkXaXp7hrann',
      '',
      1455
    ),
    nil,
    nil
  );

  Assert.IsTrue(FMockServer.IsRunning);
  Assert.AreEqual(1455, FMockServer.GetActivePort);
  Assert.IsNotEmpty(FManager.LastOpenedUrl);
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('https://auth.openai.com/oauth/authorize'));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('client_id=app_EMoamEEZ73f0CkXaXp7hrann'));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('redirect_uri=http%3A%2F%2Flocalhost%3A1455%2Fauth%2Fcallback'));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('code_challenge='));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('code_challenge_method=S256'));
  Assert.IsTrue(FManager.LastOpenedUrl.Contains('state='));
end;

procedure TTestRadIAOAuth.TestHandleCallbackWithError;
var
  LErrorMsg: string;
  LSuccessCalled: Boolean;
begin
  LSuccessCalled := False;
  LErrorMsg := '';

  FManager.StartLogin(
    'OpenAI',
    TRadIAOAuthParams.Create(
      'https://auth.openai.com/oauth/authorize',
      'https://auth.openai.com/oauth/token',
      'app_EMoamEEZ73f0CkXaXp7hrann',
      '',
      1455
    ),
    procedure
    begin
      LSuccessCalled := True;
    end,
    procedure(AError: string)
    begin
      LErrorMsg := AError;
    end
  );

  Assert.IsTrue(FMockServer.IsRunning);
  Assert.IsTrue(Assigned(FMockServer.Callback));

  FMockServer.Callback('', 'access_denied');

  Assert.IsFalse(LSuccessCalled);
  Assert.AreEqual('access_denied', LErrorMsg);
  Assert.IsFalse(FMockServer.IsRunning);
end;

procedure TTestRadIAOAuth.TestCancelLoginStopsServer;
begin
  FManager.StartLogin(
    'OpenAI',
    TRadIAOAuthParams.Create(
      'https://auth.openai.com/oauth/authorize',
      'https://auth.openai.com/oauth/token',
      'app_EMoamEEZ73f0CkXaXp7hrann',
      '',
      1455
    ),
    nil,
    nil
  );

  Assert.IsTrue(FMockServer.IsRunning);

  FManager.CancelLogin;

  Assert.IsFalse(FMockServer.IsRunning);
end;

procedure TTestRadIAOAuth.TestHandleCallbackWithSuccess;
var
  LSuccessCalled: Boolean;
  LErrorMsg: string;
begin
  LSuccessCalled := False;
  LErrorMsg := '';

  FMockHttpClient.Response := '{"access_token":"test-access-token",' +
    '"refresh_token":"test-refresh-token","expires_in":3600}';

  FManager.StartLogin(
    'OpenAI',
    TRadIAOAuthParams.Create(
      'https://auth.openai.com/oauth/authorize',
      'https://auth.openai.com/oauth/token',
      'app_EMoamEEZ73f0CkXaXp7hrann',
      '',
      1455
    ),
    procedure
    begin
      LSuccessCalled := True;
    end,
    procedure(AError: string)
    begin
      LErrorMsg := AError;
    end
  );

  Assert.IsTrue(FMockServer.IsRunning);
  Assert.IsTrue(Assigned(FMockServer.Callback));

  FMockServer.Callback('auth-code-123', '');

  // Sleep breve para aguardar processamento do thread anonimo assincrono
  Sleep(100);

  Assert.IsTrue(LSuccessCalled, 'OnSuccess callback should have been called.');
  Assert.IsEmpty(LErrorMsg, 'OnError should not be called.');

  Assert.AreEqual('test-access-token', FConfig.GetOAuthAccessToken('OpenAI'));
  Assert.AreEqual('test-refresh-token', FConfig.GetOAuthRefreshToken('OpenAI'));
  Assert.IsFalse(FMockServer.IsRunning);
end;

procedure TTestRadIAOAuth.TestHandleCallbackWithExchangeError;
var
  LSuccessCalled: Boolean;
  LErrorMsg: string;
begin
  LSuccessCalled := False;
  LErrorMsg := '';

  FMockHttpClient.SetErrorResponse(400, 'Invalid code');

  FManager.StartLogin(
    'OpenAI',
    TRadIAOAuthParams.Create(
      'https://auth.openai.com/oauth/authorize',
      'https://auth.openai.com/oauth/token',
      'app_EMoamEEZ73f0CkXaXp7hrann',
      '',
      1455
    ),
    procedure
    begin
      LSuccessCalled := True;
    end,
    procedure(AError: string)
    begin
      LErrorMsg := AError;
    end
  );

  FMockServer.Callback('invalid-code-123', '');

  Sleep(100);

  Assert.IsFalse(LSuccessCalled);
  Assert.IsTrue(
    LErrorMsg.Contains('400') or LErrorMsg.Contains('failed'),
    'OnError should contain HTTP error status or fail message.'
  );
end;

procedure TTestRadIAOAuth.TestRefreshAccessTokenSuccess;
var
  LSuccess: Boolean;
begin
  FConfig.SetOAuthRefreshToken('OpenAI', 'old-refresh');
  FConfig.Save;

  FMockHttpClient.Response := '{"access_token":"new-access-token",' +
    '"refresh_token":"new-refresh-token","expires_in":1800}';

  LSuccess := FManager.RefreshAccessToken(
    'OpenAI',
    'https://auth.openai.com/oauth/token',
    'radia-delphi-plugin'
  );

  Assert.IsTrue(LSuccess, 'RefreshAccessToken should return True.');
  Assert.AreEqual('new-access-token', FConfig.GetOAuthAccessToken('OpenAI'));
  Assert.AreEqual('new-refresh-token', FConfig.GetOAuthRefreshToken('OpenAI'));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAOAuth);

end.
