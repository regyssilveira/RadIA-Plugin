unit RadIA.Tests.Journeys;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAJourneys = class
  public
    [Test]
    procedure CatalogContainsFiveEndToEndJourneys;
    [Test]
    procedure JourneyObjectivesPreserveSafetyGates;
  end;

implementation

uses
  RadIA.Core.Journeys;

procedure TTestRadIAJourneys.CatalogContainsFiveEndToEndJourneys;
var
  LCount: Integer;
  LDefinition: TRadIAJourneyDefinition;
begin
  LCount := Length(TRadIAJourneyCatalog.All);
  Assert.AreEqual(5, LCount);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey create', LDefinition)
  );
  Assert.AreEqual('Create Delphi Project', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/JOURNEY DEBUG', LDefinition)
  );
  Assert.AreEqual('Debug Failure', LDefinition.Name);
end;

procedure TTestRadIAJourneys.JourneyObjectivesPreserveSafetyGates;
var
  LDefinition: TRadIAJourneyDefinition;
begin
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey fix-build', LDefinition)
  );
  Assert.Contains(LDefinition.Objective, 'Present a minimal repair plan');
  Assert.Contains(LDefinition.Objective, 'reviewable patches');
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey release', LDefinition)
  );
  Assert.Contains(LDefinition.Objective, 'Never push or publish');
  Assert.Contains(LDefinition.Objective, 'explicit user instruction');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAJourneys);

end.
