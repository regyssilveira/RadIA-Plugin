unit RadIA.Tests.RemoteKnowledgeEmbeddings;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIARemoteKnowledgeEmbeddingTests = class
  public
    [Test]
    procedure BuildsBoundedRequestAndParsesVector;
    [Test]
    procedure EmptyInputDoesNotCallTransport;
    [Test]
    procedure RejectsInsecureNonLoopbackEndpoint;
    [Test]
    procedure RejectsUnexpectedDimensions;
    [Test]
    procedure AcceptsLoopbackHttpForLocalCompatibility;
  end;

implementation

uses
  System.JSON,
  System.SysUtils,
  RadIA.Core.Knowledge,
  RadIA.Core.RemoteKnowledgeEmbeddings;

type
  TRadIARemoteEmbeddingTransportStub = class(
    TInterfacedObject,
    IRadIARemoteEmbeddingTransport
  )
  private
    FApiKey: string;
    FBody: string;
    FCallCount: Integer;
    FEndpoint: string;
    FResponse: string;
    FTimeoutMs: Cardinal;
  public
    function PostJson(
      const AEndpoint: string;
      const ABody: string;
      const AApiKey: string;
      const ATimeoutMs: Cardinal
    ): string;
    property ApiKey: string read FApiKey;
    property Body: string read FBody;
    property CallCount: Integer read FCallCount;
    property Endpoint: string read FEndpoint;
    property Response: string read FResponse write FResponse;
    property TimeoutMs: Cardinal read FTimeoutMs;
  end;

function TRadIARemoteEmbeddingTransportStub.PostJson(
  const AEndpoint: string;
  const ABody: string;
  const AApiKey: string;
  const ATimeoutMs: Cardinal
): string;
begin
  Inc(FCallCount);
  FEndpoint := AEndpoint;
  FBody := ABody;
  FApiKey := AApiKey;
  FTimeoutMs := ATimeoutMs;
  Result := FResponse;
end;

procedure TRadIARemoteKnowledgeEmbeddingTests.
  AcceptsLoopbackHttpForLocalCompatibility;
var
  LOptions: TRadIARemoteEmbeddingOptions;
begin
  LOptions := TRadIARemoteEmbeddingOptions.Create(
    'http://127.0.0.1:11434/v1/embeddings',
    'local-model',
    '',
    3,
    5000,
    1000
  );
  Assert.AreEqual(
    'http://127.0.0.1:11434/v1/embeddings',
    LOptions.Endpoint
  );
end;

procedure TRadIARemoteKnowledgeEmbeddingTests.
  BuildsBoundedRequestAndParsesVector;
var
  LJson: TJSONObject;
  LOptions: TRadIARemoteEmbeddingOptions;
  LProvider: IRadIAKnowledgeEmbeddingProvider;
  LStub: TRadIARemoteEmbeddingTransportStub;
  LTransport: IRadIARemoteEmbeddingTransport;
  LVector: TArray<Single>;
begin
  LStub := TRadIARemoteEmbeddingTransportStub.Create;
  LStub.Response :=
    '{"data":[{"embedding":[0.25,-0.5,0.75]}]}';
  LTransport := LStub;
  LOptions := TRadIARemoteEmbeddingOptions.Create(
    'https://embeddings.example.test/v1/embeddings',
    'embedding-model',
    'secret-key',
    3,
    7000,
    5
  );
  LProvider := TRadIAOpenAICompatibleEmbeddingProvider.Create(
    LOptions,
    LTransport
  );
  LVector := LProvider.Embed('123456789');
  Assert.AreEqual<Integer>(3, Length(LVector));
  Assert.AreEqual<Single>(0.25, LVector[0]);
  Assert.AreEqual<Single>(-0.5, LVector[1]);
  Assert.AreEqual<Single>(0.75, LVector[2]);
  Assert.AreEqual('secret-key', LStub.ApiKey);
  Assert.DoesNotContain(LStub.Body, 'secret-key');
  Assert.AreEqual(
    'https://embeddings.example.test/v1/embeddings',
    LStub.Endpoint
  );
  Assert.AreEqual<Cardinal>(7000, LStub.TimeoutMs);
  LJson := TJSONObject.ParseJSONValue(LStub.Body) as TJSONObject;
  try
    Assert.AreEqual('12345', LJson.GetValue<string>('input'));
    Assert.AreEqual(
      'embedding-model',
      LJson.GetValue<string>('model')
    );
  finally
    LJson.Free;
  end;
  Assert.IsFalse(LProvider.IsLocal);
end;

procedure TRadIARemoteKnowledgeEmbeddingTests.
  EmptyInputDoesNotCallTransport;
var
  LOptions: TRadIARemoteEmbeddingOptions;
  LProvider: IRadIAKnowledgeEmbeddingProvider;
  LStub: TRadIARemoteEmbeddingTransportStub;
begin
  LStub := TRadIARemoteEmbeddingTransportStub.Create;
  LOptions := TRadIARemoteEmbeddingOptions.Create(
    'https://embeddings.example.test/v1/embeddings',
    'embedding-model',
    '',
    3,
    5000,
    1000
  );
  LProvider := TRadIAOpenAICompatibleEmbeddingProvider.Create(
    LOptions,
    LStub
  );
  Assert.AreEqual<Integer>(0, Length(LProvider.Embed('  ')));
  Assert.AreEqual(0, LStub.CallCount);
end;

procedure TRadIARemoteKnowledgeEmbeddingTests.
  RejectsInsecureNonLoopbackEndpoint;
begin
  Assert.WillRaise(
    procedure
    begin
      TRadIARemoteEmbeddingOptions.Create(
        'http://embeddings.example.test/v1/embeddings',
        'embedding-model',
        '',
        3,
        5000,
        1000
      );
    end,
    EArgumentException
  );
end;

procedure TRadIARemoteKnowledgeEmbeddingTests.
  RejectsUnexpectedDimensions;
var
  LOptions: TRadIARemoteEmbeddingOptions;
  LProvider: IRadIAKnowledgeEmbeddingProvider;
  LStub: TRadIARemoteEmbeddingTransportStub;
begin
  LStub := TRadIARemoteEmbeddingTransportStub.Create;
  LStub.Response := '{"data":[{"embedding":[0.25,-0.5]}]}';
  LOptions := TRadIARemoteEmbeddingOptions.Create(
    'https://embeddings.example.test/v1/embeddings',
    'embedding-model',
    '',
    3,
    5000,
    1000
  );
  LProvider := TRadIAOpenAICompatibleEmbeddingProvider.Create(
    LOptions,
    LStub
  );
  Assert.WillRaise(
    procedure
    begin
      LProvider.Embed('text');
    end,
    EInvalidOpException
  );
end;

initialization
  TDUnitX.RegisterTestFixture(
    TRadIARemoteKnowledgeEmbeddingTests
  );

end.
