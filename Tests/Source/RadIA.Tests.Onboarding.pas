unit RadIA.Tests.Onboarding;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAOnboardingTests = class
  public
    [Test]
    procedure CatalogCoversCompleteFirstRunJourney;
    [Test]
    procedure NewInstallationShowsOnboardingAutomatically;
    [Test]
    procedure ClosingOnboardingSuppressesRepeatedAutomaticDisplay;
    [Test]
    procedure CompletedOnboardingPersistsFinalStep;
    [Test]
    procedure InvalidStoredValuesAreClamped;
  end;

implementation

uses
  RadIA.Core.Onboarding,
  RadIA.Core.SettingsStorage;

const
  CSettingsPath = 'Software\RadIA\Tests\Onboarding';

procedure TRadIAOnboardingTests.CatalogCoversCompleteFirstRunJourney;
var
  LSteps: TArray<TRadIAOnboardingStep>;
begin
  LSteps := TRadIAOnboardingCatalog.Steps;
  Assert.AreEqual<Integer>(6, Length(LSteps));
  Assert.AreEqual(Ord(oaOpenChat), Ord(LSteps[0].Action));
  Assert.AreEqual(Ord(oaOpenProviderSettings), Ord(LSteps[1].Action));
  Assert.AreEqual(Ord(oaOpenSecuritySettings), Ord(LSteps[2].Action));
  Assert.AreEqual(Ord(oaOpenCliMcpSettings), Ord(LSteps[3].Action));
  Assert.AreEqual(Ord(oaOpenTerminal), Ord(LSteps[4].Action));
  Assert.AreEqual(Ord(oaCreateProject), Ord(LSteps[5].Action));
end;

procedure TRadIAOnboardingTests.ClosingOnboardingSuppressesRepeatedAutomaticDisplay;
var
  LState: TRadIAOnboardingState;
  LStorage: IRadIASettingsStorage;
  LStore: TRadIAOnboardingStore;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LStore := TRadIAOnboardingStore.Create(LStorage, CSettingsPath);
  try
    LStore.MarkShown(3);
    Assert.IsFalse(LStore.ShouldShowAutomatically);
    LState := LStore.Load;
    Assert.AreEqual(TRadIAOnboardingStore.CurrentFlowVersion, LState.FlowVersion);
    Assert.AreEqual(3, LState.LastStep);
    Assert.IsFalse(LState.Completed);
  finally
    LStore.Free;
  end;
end;

procedure TRadIAOnboardingTests.CompletedOnboardingPersistsFinalStep;
var
  LState: TRadIAOnboardingState;
  LStorage: IRadIASettingsStorage;
  LStore: TRadIAOnboardingStore;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LStore := TRadIAOnboardingStore.Create(LStorage, CSettingsPath);
  try
    LStore.MarkCompleted;
    LState := LStore.Load;
    Assert.AreEqual(5, LState.LastStep);
    Assert.IsTrue(LState.Completed);
    Assert.IsFalse(LStore.ShouldShowAutomatically);
  finally
    LStore.Free;
  end;
end;

procedure TRadIAOnboardingTests.InvalidStoredValuesAreClamped;
var
  LState: TRadIAOnboardingState;
  LStorage: IRadIASettingsStorage;
  LStore: TRadIAOnboardingStore;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  Assert.IsTrue(LStorage.OpenKey(CSettingsPath, True));
  try
    LStorage.WriteInteger('FlowVersion', -4);
    LStorage.WriteInteger('LastStep', -9);
  finally
    LStorage.CloseKey;
  end;
  LStore := TRadIAOnboardingStore.Create(LStorage, CSettingsPath);
  try
    LState := LStore.Load;
    Assert.AreEqual(0, LState.FlowVersion);
    Assert.AreEqual(0, LState.LastStep);
    Assert.IsTrue(LStore.ShouldShowAutomatically);
  finally
    LStore.Free;
  end;
end;

procedure TRadIAOnboardingTests.NewInstallationShowsOnboardingAutomatically;
var
  LState: TRadIAOnboardingState;
  LStorage: IRadIASettingsStorage;
  LStore: TRadIAOnboardingStore;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LStore := TRadIAOnboardingStore.Create(LStorage, CSettingsPath);
  try
    LState := LStore.Load;
    Assert.AreEqual(0, LState.FlowVersion);
    Assert.AreEqual(0, LState.LastStep);
    Assert.IsFalse(LState.Completed);
    Assert.IsTrue(LStore.ShouldShowAutomatically);
  finally
    LStore.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAOnboardingTests);

end.
