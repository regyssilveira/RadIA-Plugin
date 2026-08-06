unit RadIA.Tests.OnboardingForm;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAOnboardingFormTests = class
  public
    [Test]
    procedure CreatesWindowBeforeDynamicControlsAreAssigned;
  end;

implementation

uses
  RadIA.UI.OnboardingForm;

procedure TRadIAOnboardingFormTests.
  CreatesWindowBeforeDynamicControlsAreAssigned;
var
  LForm: TRadIAOnboardingForm;
begin
  LForm := TRadIAOnboardingForm.Create(nil);
  try
    Assert.IsTrue(LForm.Handle <> 0);
    Assert.AreEqual(0, LForm.StepIndex);
  finally
    LForm.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAOnboardingFormTests);

end.
