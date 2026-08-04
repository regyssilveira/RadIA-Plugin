unit RadIA.Tests.DebugTimeline;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIADebugTimelineTests = class
  public
    [Test]
    procedure RetainsBoundedOrderedEvents;
    [Test]
    procedure ToolReturnsEventsAfterSequence;
  end;

implementation

uses
  RadIA.Core.DebugTimeline,
  RadIA.Core.DebugTimelineTools,
  RadIA.Core.ToolRegistry,
  RadIA.Core.Tools;

procedure TRadIADebugTimelineTests.RetainsBoundedOrderedEvents;
var
  LEvents: TArray<TRadIADebugEvent>;
  LIndex: Integer;
  LTimeline: IRadIADebugTimeline;
begin
  LTimeline := TRadIADebugTimeline.Create(10);
  for LIndex := 1 to 12 do
    LTimeline.RecordEvent(
      dekProcessStateChanged,
      LIndex,
      'running',
      ''
    );
  LEvents := LTimeline.ListEvents(0, 100);
  Assert.AreEqual<Integer>(10, Length(LEvents));
  Assert.AreEqual(Int64(3), LEvents[0].Sequence);
  Assert.AreEqual(Int64(12), LTimeline.GetLastSequence);
end;

procedure TRadIADebugTimelineTests.ToolReturnsEventsAfterSequence;
var
  LRegistry: IRadIAToolRegistry;
  LResult: TRadIAToolResult;
  LTimeline: IRadIADebugTimeline;
  LTool: IRadIATool;
begin
  LTimeline := TRadIADebugTimeline.Create;
  LTimeline.RecordEvent(
    dekProcessCreated,
    42,
    'running',
    'Sample.exe'
  );
  LTimeline.RecordEvent(
    dekProcessStateChanged,
    42,
    'stopped',
    ''
  );
  LRegistry := TRadIAToolRegistry.Create;
  RegisterRadIADebugTimelineTools(LRegistry, LTimeline);
  LTool := LRegistry.Resolve('GetDebugTimeline');
  LResult := LTool.Execute(
    TRadIAToolRequest.Create(
      'GetDebugTimeline',
      '{"sinceSequence":1,"maxCount":10}',
      'timeline-test'
    )
  );
  Assert.IsTrue(LResult.Success);
  Assert.Contains(LResult.ContentJson, '"lastSequence":2');
  Assert.Contains(LResult.ContentJson, '"sequence":2');
  Assert.Contains(LResult.ContentJson, '"state":"stopped"');
  Assert.AreEqual(0, Pos('"sequence":1', LResult.ContentJson));
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIADebugTimelineTests);

end.
