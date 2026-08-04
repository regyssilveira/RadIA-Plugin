unit RadIA.Tests.JSONProviders;

interface

uses
  DUnitX.TestFramework, RadIA.Core.Interfaces;

type
  [TestFixture]
  TTestRadIAJSONProviders = class
  private
    FConfig: IRadIAConfig;
    FTestJsonFile: string;
    procedure CreateMockJsonProvider;
    procedure DeleteMockJsonProvider;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestJSONProvider_RegistrationAndMetadata;
    [Test]
    procedure TestJSONProvider_InstanceCreation;
  end;

implementation

uses
  System.SysUtils, System.IOUtils, System.JSON, RadIA.Core.ProviderRegistry, RadIA.Core.Config,
      RadIA.Core.SettingsStorage;

{ TTestRadIAJSONProviders }

procedure TTestRadIAJSONProviders.Setup;
begin
  TRadIAConfig.SetBaseRegistryPath('Software\TestRadIAJSONProviders');
  TRadIAConfig.SetStorage(TRadIAMemorySettingsStorage.Create);
  FConfig := TRadIAConfig.Create;
  CreateMockJsonProvider;
end;

procedure TTestRadIAJSONProviders.TearDown;
begin
  DeleteMockJsonProvider;
  FConfig := nil;
  TRadIAConfig.SetStorage(nil);
  TRadIAConfig.SetBaseRegistryPath('');
end;

procedure TTestRadIAJSONProviders.CreateMockJsonProvider;
var
  LFolder: string;
  LJsonObj: TJSONObject;
  LModels: TJSONArray;
begin
  LFolder := TPath.Combine(IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) + 'RadIA', 'providers');
  if not TDirectory.Exists(LFolder) then
    TDirectory.CreateDirectory(LFolder);

  FTestJsonFile := TPath.Combine(LFolder, 'test_dynamic_provider.json');

  LJsonObj := TJSONObject.Create;
  try
    LJsonObj.AddPair('id', 'TestDynamic');
    LJsonObj.AddPair('displayName', 'Test Dynamic AI');
    LJsonObj.AddPair('baseUrl', 'https://api.testdynamic.ai/v1');
    LJsonObj.AddPair('apiKey', 'mock-api-key-12345');
    LJsonObj.AddPair('hasApiKey', TJSONBool.Create(True));
    LJsonObj.AddPair('hasCustomUrl', TJSONBool.Create(True));

    LModels := TJSONArray.Create;
    LModels.Add('dynamic-model-v1');
    LModels.Add('dynamic-model-v2');
    LJsonObj.AddPair('defaultModels', LModels);

    TFile.WriteAllText(FTestJsonFile, LJsonObj.ToJSON, TEncoding.UTF8);
  finally
    LJsonObj.Free;
  end;
end;

procedure TTestRadIAJSONProviders.DeleteMockJsonProvider;
begin
  if TFile.Exists(FTestJsonFile) then
    TFile.Delete(FTestJsonFile);
end;

procedure TTestRadIAJSONProviders.TestJSONProvider_RegistrationAndMetadata;
var
  LMeta: TProviderMetadata;
begin
  TProviderRegistry.LoadJsonProviders;

  Assert.IsTrue(TProviderRegistry.HasProvider('TestDynamic'), 'Registry should contain TestDynamic provider');

  if TProviderRegistry.GetProvider('TestDynamic', LMeta) then
  begin
    Assert.AreEqual('TestDynamic', LMeta.Id, 'ID does not match');
    Assert.AreEqual('Test Dynamic AI', LMeta.DisplayName, 'DisplayName does not match');
    Assert.AreEqual('https://api.testdynamic.ai/v1', LMeta.DefaultBaseUrl, 'DefaultBaseUrl does not match');
    Assert.IsTrue(LMeta.HasApiKey, 'HasApiKey should be True');
    Assert.IsTrue(LMeta.HasCustomUrl, 'HasCustomUrl should be True');
    Assert.IsTrue(LMeta.IsDynamic, 'IsDynamic should be True');
    Assert.AreEqual<Integer>(
      2,
      Length(LMeta.DefaultModels),
      'DefaultModels count does not match'
    );
    Assert.AreEqual('dynamic-model-v1', LMeta.DefaultModels[0], 'First model does not match');
  end
  else
    Assert.Fail('Could not retrieve TestDynamic provider metadata');
end;

procedure TTestRadIAJSONProviders.TestJSONProvider_InstanceCreation;
var
  LProvider: IRadIAProvider;
begin
  TProviderRegistry.LoadJsonProviders;

  LProvider := TProviderRegistry.CreateProvider('TestDynamic', FConfig);
  Assert.IsNotNull(LProvider, 'Provider instance should not be null');
  Assert.AreEqual('Test Dynamic AI', LProvider.GetName, 'GetName does not match');
  Assert.AreEqual('TestDynamic', LProvider.GetProviderId, 'GetProviderId does not match');
  Assert.AreEqual<Integer>(
    2,
    Length(LProvider.GetAvailableModels),
    'Models count does not match'
  );
  Assert.AreEqual('dynamic-model-v1', LProvider.GetAvailableModels[0], 'First model does not match');

  // Testar se a API Key do JSON foi propagada corretamente
  Assert.AreEqual('mock-api-key-12345', FConfig.GetApiKey('TestDynamic'), 'ApiKey not set in configuration');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAJSONProviders);

end.
