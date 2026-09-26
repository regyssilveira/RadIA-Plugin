unit RadIA.Tests.ConsentSettings;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAConsentSettingsTests = class
  public
    [Test]
    procedure DefaultsToCategoryLevel;
    [Test]
    procedure PersistsEveryGrantLevel;
  end;

implementation

uses
  RadIA.Core.ConsentSettings,
  RadIA.Core.SettingsStorage;

procedure TRadIAConsentSettingsTests.DefaultsToCategoryLevel;
var
  LStore: TRadIAConsentSettingsStore;
begin
  LStore := TRadIAConsentSettingsStore.Create(
    TRadIAMemorySettingsStorage.Create,
    'test\consent'
  );
  try
    Assert.AreEqual(cglCategory, LStore.LoadGrantLevel);
  finally
    LStore.Free;
  end;
end;

procedure TRadIAConsentSettingsTests.PersistsEveryGrantLevel;
var
  LLevel: TRadIAConsentGrantLevel;
  LStore: TRadIAConsentSettingsStore;
begin
  LStore := TRadIAConsentSettingsStore.Create(
    TRadIAMemorySettingsStorage.Create,
    'test\consent'
  );
  try
    for LLevel := Low(TRadIAConsentGrantLevel) to
      High(TRadIAConsentGrantLevel) do
    begin
      LStore.SaveGrantLevel(LLevel);
      Assert.AreEqual(LLevel, LStore.LoadGrantLevel);
    end;
  finally
    LStore.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAConsentSettingsTests);

end.
