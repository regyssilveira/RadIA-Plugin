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
    [Test]
    procedure JourneysExposeAuditablePhasesAndEvidence;
    [Test]
    procedure ResolvesOptionalUserContext;
    [Test]
    procedure RejectsOversizedUserContext;
    [Test]
    procedure DextJourneyRequestsMissingInputsInOrder;
    [Test]
    procedure JourneysExposeUsageAndExamples;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.Journeys;

procedure TTestRadIAJourneys.CatalogContainsFiveEndToEndJourneys;
var
  LCount: Integer;
  LDefinition: TRadIAJourneyDefinition;
begin
  LCount := Length(TRadIAJourneyCatalog.All);
  Assert.AreEqual(9, LCount);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey create', LDefinition)
  );
  Assert.AreEqual('Create Delphi Project', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/JOURNEY DEBUG', LDefinition)
  );
  Assert.AreEqual('Debug Failure', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey modernize', LDefinition)
  );
  Assert.AreEqual('Modernize Delphi Project', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey migrate', LDefinition)
  );
  Assert.AreEqual('Migrate Legacy Delphi Code', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey dext-minimal', LDefinition)
  );
  Assert.AreEqual('Create DEXT Minimal API', LDefinition.Name);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey dext-controllers', LDefinition)
  );
  Assert.AreEqual('Create DEXT Controllers API', LDefinition.Name);
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
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey migrate', LDefinition)
  );
  Assert.Contains(LDefinition.Objective, 'central transaction flow');
  Assert.Contains(LDefinition.Phases[3].Evidence, 'rollback decision');
end;

procedure TTestRadIAJourneys.JourneysExposeAuditablePhasesAndEvidence;
var
  LDefinition: TRadIAJourneyDefinition;
  LObjective: string;
begin
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey debug', LDefinition)
  );
  Assert.AreEqual(NativeInt(4), Length(LDefinition.Phases));
  Assert.AreEqual('Reproduce', LDefinition.Phases[0].Name);
  Assert.Contains(LDefinition.Phases[1].Evidence, 'failure evidence');
  Assert.AreEqual(NativeInt(5), Length(LDefinition.SuccessCriteria));

  LObjective := LDefinition.BuildAgentObjective(
    'Access violation after saving an invoice'
  );
  Assert.Contains(LObjective, 'Required journey phases:');
  Assert.Contains(LObjective, 'Evidence:');
  Assert.Contains(LObjective, 'Completion criteria:');
  Assert.Contains(
    LObjective,
    'User-provided context: Access violation after saving an invoice'
  );
end;

procedure TTestRadIAJourneys.ResolvesOptionalUserContext;
var
  LContext: string;
  LDefinition: TRadIAJourneyDefinition;
begin
  Assert.IsTrue(
    TRadIAJourneyCatalog.Resolve(
      '/journey create VCL inventory app with SQLite',
      LDefinition,
      LContext
    )
  );
  Assert.AreEqual('/journey create', LDefinition.Command);
  Assert.AreEqual('VCL inventory app with SQLite', LContext);
  Assert.IsTrue(
    TRadIAJourneyCatalog.Resolve(
      '/JOURNEY FIX-BUILD',
      LDefinition,
      LContext
    )
  );
  Assert.AreEqual('', LContext);
end;

procedure TTestRadIAJourneys.RejectsOversizedUserContext;
var
  LContext: string;
  LDefinition: TRadIAJourneyDefinition;
  LRaised: Boolean;
begin
  LRaised := False;
  try
    TRadIAJourneyCatalog.Resolve(
      '/journey tests ' + StringOfChar('x', 4001),
      LDefinition,
      LContext
    );
  except
    on E: EArgumentException do
    begin
      LRaised := True;
      Assert.Contains(E.Message, '4000');
    end;
  end;
  Assert.IsTrue(LRaised);
end;

procedure TTestRadIAJourneys.DextJourneyRequestsMissingInputsInOrder;
var
  LDefinition: TRadIAJourneyDefinition;
  LField: string;
  LQuestion: string;
begin
  Assert.IsTrue(
    TRadIAJourneyCatalog.Find('/journey dext-minimal', LDefinition)
  );
  Assert.IsTrue(
    LDefinition.NextRequiredInput('products get post', LField, LQuestion)
  );
  Assert.AreEqual('project', LField);
  Assert.Contains(LQuestion, 'project');
  Assert.IsTrue(
    LDefinition.NextRequiredInput(
      'project=Catalog destination=D:\Projects platform=Win32 port=8080 ' +
      'health=/health',
      LField,
      LQuestion
    )
  );
  Assert.AreEqual('endpoints', LField);
  Assert.IsFalse(
    LDefinition.NextRequiredInput(
      'project=Catalog destination=D:\Projects platform=Win32 port=8080 ' +
      'health=/health endpoints="GET /products group=Products status=200 purpose=List"',
      LField,
      LQuestion
    )
  );
end;

procedure TTestRadIAJourneys.JourneysExposeUsageAndExamples;
var
  LDefinition: TRadIAJourneyDefinition;
begin
  for LDefinition in TRadIAJourneyCatalog.All do
  begin
    Assert.Contains(LDefinition.Usage, LDefinition.Command);
    Assert.Contains(LDefinition.Example, LDefinition.Command);
    Assert.Contains(LDefinition.InputHelpText, 'Usage:');
    Assert.Contains(LDefinition.InputHelpText, 'Example:');
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAJourneys);

end.
