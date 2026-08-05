unit RadIA.Tests.RemoteKnowledgeSettings;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRemoteKnowledgeSettings = class
  public
    [Test]
    procedure DefaultsAreLocalAndFailClosed;
    [Test]
    procedure SavesAndLoadsProtectedConfiguration;
    [Test]
    procedure CreatesProviderOnlyWithValidConsent;
    [Test]
    procedure RejectsInvalidRemoteConfiguration;
  end;

implementation

uses
  RadIA.Core.Knowledge,
  RadIA.Core.RemoteKnowledgeSettings,
  RadIA.Core.SettingsStorage;

const
  CBasePath = 'Software\RadIA\Tests\RemoteKnowledge';

function CreateConfiguration(
  const AEnabled: Boolean;
  const AConsent: Boolean;
  const AEndpoint: string = 'https://example.test/v1/embeddings'
): TRadIARemoteKnowledgeConfiguration;
begin
  Result := TRadIARemoteKnowledgeConfiguration.Create(
    AEnabled,
    AConsent,
    AEndpoint,
    'embedding-model',
    'secret-key',
    TRadIARemoteKnowledgeLimits.Create(768, 15000, 8000)
  );
end;

procedure TTestRemoteKnowledgeSettings.CreatesProviderOnlyWithValidConsent;
var
  LProvider: IRadIAKnowledgeEmbeddingProvider;
  LSettings: TRadIARemoteKnowledgeSettings;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LSettings := TRadIARemoteKnowledgeSettings.Create(LStorage, CBasePath);
  try
    LSettings.Save(CreateConfiguration(True, True));

    Assert.IsTrue(LSettings.TryCreateProvider(LProvider));
    Assert.IsFalse(LProvider.IsLocal);
    Assert.AreEqual<Integer>(768, LProvider.GetDimensions);
  finally
    LSettings.Free;
  end;
end;

procedure TTestRemoteKnowledgeSettings.DefaultsAreLocalAndFailClosed;
var
  LConfiguration: TRadIARemoteKnowledgeConfiguration;
  LProvider: IRadIAKnowledgeEmbeddingProvider;
  LSettings: TRadIARemoteKnowledgeSettings;
begin
  LSettings := TRadIARemoteKnowledgeSettings.Create(
    TRadIAMemorySettingsStorage.Create,
    CBasePath
  );
  try
    LConfiguration := LSettings.GetConfiguration;

    Assert.IsFalse(LConfiguration.Enabled);
    Assert.IsFalse(LConfiguration.ConsentGranted);
    Assert.IsFalse(LSettings.TryCreateProvider(LProvider));
  finally
    LSettings.Free;
  end;
end;

procedure TTestRemoteKnowledgeSettings.RejectsInvalidRemoteConfiguration;
var
  LProvider: IRadIAKnowledgeEmbeddingProvider;
  LSettings: TRadIARemoteKnowledgeSettings;
begin
  LSettings := TRadIARemoteKnowledgeSettings.Create(
    TRadIAMemorySettingsStorage.Create,
    CBasePath
  );
  try
    LSettings.Save(
      CreateConfiguration(True, True, 'http://remote.example/embeddings')
    );

    Assert.IsFalse(LSettings.TryCreateProvider(LProvider));
    Assert.IsFalse(Assigned(LProvider));
  finally
    LSettings.Free;
  end;
end;

procedure TTestRemoteKnowledgeSettings.SavesAndLoadsProtectedConfiguration;
var
  LLoaded: TRadIARemoteKnowledgeConfiguration;
  LRawApiKey: string;
  LSettings: TRadIARemoteKnowledgeSettings;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LSettings := TRadIARemoteKnowledgeSettings.Create(LStorage, CBasePath);
  try
    LSettings.Save(CreateConfiguration(True, True));
    Assert.IsTrue(LStorage.OpenKey(CBasePath, False));
    try
      LRawApiKey := LStorage.ReadString('ApiKey', '');
    finally
      LStorage.CloseKey;
    end;
    Assert.IsNotEmpty(LRawApiKey);
    Assert.AreNotEqual('secret-key', LRawApiKey);

    LSettings.Load;
    LLoaded := LSettings.GetConfiguration;
    Assert.IsTrue(LLoaded.Enabled);
    Assert.IsTrue(LLoaded.ConsentGranted);
    Assert.AreEqual('secret-key', LLoaded.ApiKey);
    Assert.AreEqual('embedding-model', LLoaded.Model);
  finally
    LSettings.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRemoteKnowledgeSettings);

end.
