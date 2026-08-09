unit RadIA.Tests.JourneyContext;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAJourneyContextTests = class
  public
    [Test]
    procedure ReusesJourneyForTheSameConversationAndProject;
    [Test]
    procedure CreatesNewJourneyWhenProjectChanges;
    [Test]
    procedure DetachRemovesOnlyTheSelectedConversation;
    [Test]
    procedure SwitchRejectsAJourneyFromAnotherProject;
    [Test]
    procedure SwitchActivatesAJourneyFromTheSameProject;
    [Test]
    procedure ExecutorUpdatePreservesJourneyIdentity;
    [Test]
    procedure ActivityStateIsSharedByEverySurface;
    [Test]
    procedure EditorContextIncludesOnlyTheMatchingProjectJourney;
  end;

implementation

uses
  RadIA.Core.JourneyContext;

procedure TRadIAJourneyContextTests.ReusesJourneyForTheSameConversationAndProject;
var
  LCoordinator: IRadIAJourneyContextCoordinator;
  LFirst: TRadIAJourneyContextSnapshot;
  LSecond: TRadIAJourneyContextSnapshot;
begin
  LCoordinator := TRadIAJourneyContextCoordinator.Create;
  LFirst := LCoordinator.Activate('chat-1', 'C:\project\app.dproj', 'native');
  LSecond := LCoordinator.Activate('chat-1', 'C:\project\app.dproj', 'native');

  Assert.AreEqual(LFirst.JourneyId, LSecond.JourneyId);
  Assert.IsTrue(LSecond.IsLinked);
end;

procedure TRadIAJourneyContextTests.CreatesNewJourneyWhenProjectChanges;
var
  LCoordinator: IRadIAJourneyContextCoordinator;
  LFirst: TRadIAJourneyContextSnapshot;
  LSecond: TRadIAJourneyContextSnapshot;
begin
  LCoordinator := TRadIAJourneyContextCoordinator.Create;
  LFirst := LCoordinator.Activate('chat-1', 'C:\project-a\app.dproj', 'native');
  LSecond := LCoordinator.Activate('chat-1', 'C:\project-b\app.dproj', 'native');

  Assert.AreNotEqual(LFirst.JourneyId, LSecond.JourneyId);
end;

procedure TRadIAJourneyContextTests.DetachRemovesOnlyTheSelectedConversation;
var
  LCoordinator: IRadIAJourneyContextCoordinator;
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  LCoordinator := TRadIAJourneyContextCoordinator.Create;
  LCoordinator.Activate('chat-1', 'C:\project\app.dproj', 'native');
  LCoordinator.Activate('chat-2', 'C:\project\app.dproj', 'native');

  Assert.IsTrue(LCoordinator.Detach('chat-1'));
  Assert.IsFalse(LCoordinator.TryGetForConversation('chat-1', LSnapshot));
  Assert.IsTrue(LCoordinator.TryGetForConversation('chat-2', LSnapshot));
end;

procedure TRadIAJourneyContextTests.SwitchRejectsAJourneyFromAnotherProject;
var
  LCoordinator: IRadIAJourneyContextCoordinator;
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  LCoordinator := TRadIAJourneyContextCoordinator.Create;
  LSnapshot := LCoordinator.Activate(
    'chat-1',
    'C:\project-a\app.dproj',
    'native'
  );

  Assert.IsFalse(LCoordinator.SwitchTo(
    LSnapshot.JourneyId,
    'C:\project-b\app.dproj'
  ));
end;

procedure TRadIAJourneyContextTests.SwitchActivatesAJourneyFromTheSameProject;
var
  LCoordinator: IRadIAJourneyContextCoordinator;
  LFirst: TRadIAJourneyContextSnapshot;
  LSecond: TRadIAJourneyContextSnapshot;
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  LCoordinator := TRadIAJourneyContextCoordinator.Create;
  LFirst := LCoordinator.Activate(
    'chat-1',
    'C:\project\app.dproj',
    'native'
  );
  LSecond := LCoordinator.Activate(
    'chat-2',
    'C:\project\app.dproj',
    'native'
  );

  Assert.AreNotEqual(LFirst.JourneyId, LSecond.JourneyId);
  Assert.IsTrue(LCoordinator.SwitchTo(
    LFirst.JourneyId,
    'C:\project\app.dproj'
  ));
  Assert.IsTrue(LCoordinator.TryGetActive(LSnapshot));
  Assert.AreEqual(LFirst.JourneyId, LSnapshot.JourneyId);
  Assert.IsTrue(LCoordinator.TryGetByJourney(LFirst.JourneyId, LSnapshot));
  Assert.AreEqual('chat-1', LSnapshot.ConversationId);
end;

procedure TRadIAJourneyContextTests.ExecutorUpdatePreservesJourneyIdentity;
var
  LCoordinator: IRadIAJourneyContextCoordinator;
  LFirst: TRadIAJourneyContextSnapshot;
  LUpdated: TRadIAJourneyContextSnapshot;
begin
  LCoordinator := TRadIAJourneyContextCoordinator.Create;
  LFirst := LCoordinator.Activate('chat-1', 'C:\project\app.dproj', 'native');

  LCoordinator.UpdateExecutor('codex');

  Assert.IsTrue(LCoordinator.TryGetActive(LUpdated));
  Assert.AreEqual(LFirst.JourneyId, LUpdated.JourneyId);
  Assert.AreEqual('codex', LUpdated.ExecutorId);
end;

procedure TRadIAJourneyContextTests.ActivityStateIsSharedByEverySurface;
var
  LCoordinator: IRadIAJourneyContextCoordinator;
  LSnapshot: TRadIAJourneyContextSnapshot;
begin
  LCoordinator := TRadIAJourneyContextCoordinator.Create;
  LCoordinator.Activate('chat-1', 'C:\project\app.dproj', 'native');

  LCoordinator.BeginActivity;
  Assert.IsTrue(LCoordinator.TryGetActive(LSnapshot));
  Assert.AreEqual(jasRunning, LSnapshot.State);

  LCoordinator.RequestCancellation;
  Assert.IsTrue(LCoordinator.TryGetActive(LSnapshot));
  Assert.AreEqual(jasCancellationRequested, LSnapshot.State);

  LCoordinator.CompleteActivity;
  Assert.IsTrue(LCoordinator.TryGetActive(LSnapshot));
  Assert.AreEqual(jasIdle, LSnapshot.State);
end;

procedure TRadIAJourneyContextTests.
  EditorContextIncludesOnlyTheMatchingProjectJourney;
var
  LCoordinator: IRadIAJourneyContextCoordinator;
  LContext: string;
begin
  LCoordinator := TRadIAJourneyContextCoordinator.Create;
  LCoordinator.Activate('chat-1', 'C:\project-a\app.dproj', 'native');

  LContext := TRadIAJourneyContextEnricher.EnrichProjectContext(
    'Project: App',
    'C:\project-a',
    LCoordinator
  );
  Assert.Contains(LContext, 'Journey: ');
  Assert.Contains(LContext, 'Conversation: chat-1');
  Assert.Contains(LContext, 'Activity: idle');

  LContext := TRadIAJourneyContextEnricher.EnrichProjectContext(
    'Project: Other',
    'C:\project-b',
    LCoordinator
  );
  Assert.AreEqual('Project: Other', LContext);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAJourneyContextTests);

end.
