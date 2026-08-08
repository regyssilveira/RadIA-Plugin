unit RadIA.Tests.ResultCompactionSettings;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAResultCompactionSettingsTests = class
  public
    [Test]
    procedure PersistsValidatedProfileAndContextLimit;
    [Test]
    procedure UsesSafeDefaultsForInvalidStoredValues;
  end;

implementation

uses
  RadIA.Core.ResultCompactionSettings,
  RadIA.Core.SettingsStorage;

procedure TRadIAResultCompactionSettingsTests.PersistsValidatedProfileAndContextLimit;
var
  LLoaded: TRadIAResultCompactionSettings;
  LStorage: IRadIASettingsStorage;
  LStore: TRadIAResultCompactionSettingsStore;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LStore := TRadIAResultCompactionSettingsStore.Create(
    LStorage,
    'test\compaction'
  );
  try
    LStore.Save(TRadIAResultCompactionSettings.Create('Balanced', 64000));
    LLoaded := LStore.Load;
    Assert.AreEqual('Balanced', LLoaded.ProfileName);
    Assert.AreEqual(64000, LLoaded.MaximumDecisionContextCharacters);
  finally
    LStore.Free;
  end;
end;

procedure TRadIAResultCompactionSettingsTests.UsesSafeDefaultsForInvalidStoredValues;
var
  LLoaded: TRadIAResultCompactionSettings;
  LStorage: IRadIASettingsStorage;
  LStore: TRadIAResultCompactionSettingsStore;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  Assert.IsTrue(LStorage.OpenKey('test\compaction', True));
  LStorage.WriteString('Profile', 'unknown');
  LStorage.WriteInteger('MaximumDecisionContextCharacters', 12);
  LStorage.CloseKey;
  LStore := TRadIAResultCompactionSettingsStore.Create(
    LStorage,
    'test\compaction'
  );
  try
    LLoaded := LStore.Load;
    Assert.AreEqual('Conservative', LLoaded.ProfileName);
    Assert.AreEqual(120000, LLoaded.MaximumDecisionContextCharacters);
  finally
    LStore.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAResultCompactionSettingsTests);

end.
