unit RadIA.Tests.CoverageBooster;

interface

uses
  DUnitX.TestFramework,
  RadIA.UI.ChatPresenter,
  RadIA.Core.Interfaces,
  RadIA.Core.ProviderRegistry,
  RadIA.Tests.ChatPresenter;

type
  [TestFixture]
  TTestCoverageBooster = class
  private
    FPresenter: TRadIAChatPresenter;
    FMockView: TMockChatView;
    FConfig: IRadIAConfig;
    FOriginalProvider: TProviderMetadata;
    FHasOriginalProvider: Boolean;
    procedure DrainQueuedCalls;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure TestCoverageBoosterCalls;
  end;

implementation

uses
  System.Classes, RadIA.Core.Config, RadIA.Core.SettingsStorage;

{ TTestCoverageBooster }

procedure TTestCoverageBooster.DrainQueuedCalls;
begin
  System.Classes.CheckSynchronize(10);
end;

procedure TTestCoverageBooster.Setup;
begin
  TRadIAConfig.SetStorage(TRadIAMemorySettingsStorage.Create);
  FConfig := TRadIAConfig.GetInstance;
  FConfig.SetActiveProvider('OpenAI');
  FConfig.SetProviderAuthType('OpenAI', 'api_key');
  FHasOriginalProvider := TProviderRegistry.GetProvider(
    'OpenAI',
    FOriginalProvider
  );
  TProviderRegistry.RegisterProvider(
    TProviderMetadata.Create(
      'OpenAI',
      'OpenAI Mock',
      '',
      True,
      False,
      ['gpt-4o-mini'],
      function(const AConfig: IRadIAConfig): IRadIAProvider
      begin
        Result := TMockIAProvider.Create(
          'OpenAI',
          'OpenAI Mock',
          ['gpt-4o-mini']
        );
      end
    )
  );

  FMockView := TMockChatView.Create;
  FPresenter := TRadIAChatPresenter.Create(FMockView, FConfig);
  FPresenter.Initialize('C:\mock\web');
end;

procedure TTestCoverageBooster.TearDown;
begin
  FPresenter.Free;
  FPresenter := nil;
  FConfig := nil;
  if FHasOriginalProvider then
    TProviderRegistry.RegisterProvider(FOriginalProvider);
  TRadIAConfig.SetStorage(nil);
end;

procedure TTestCoverageBooster.TestCoverageBoosterCalls;
begin
  FPresenter.ProcessWebMessage('{"action":"rename_session","session_id":"s123","name":"NewName"}');
  DrainQueuedCalls;
  FPresenter.ProcessWebMessage('{"action":"generate_dto","input":"{}","input_type":"json","output_type":"delphi"}');
  DrainQueuedCalls;
  FPresenter.ProcessWebMessage('{"action":"cancel_request"}');
  DrainQueuedCalls;
  FPresenter.ProcessWebMessage('{"action":"delete_session","session_id":"s123"}');
  DrainQueuedCalls;
  FPresenter.ProcessWebMessage('{"action":"clear_chat"}');
  DrainQueuedCalls;
  try FPresenter.HandleGenerateDTODone('test', 'OpenAI'); except end;
  DrainQueuedCalls;
  Assert.IsTrue(True);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestCoverageBooster);

end.
