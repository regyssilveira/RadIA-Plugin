unit RadIA.Tests.VisualRuntimeSession;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.VisualRuntimeSession;

type
  TRadIAVisualSessionTestClock = class(
    TInterfacedObject,
    IRadIAVisualSessionClock
  )
  private
    FNowUtc: TDateTime;
  public
    constructor Create(const ANowUtc: TDateTime);
    procedure AdvanceMinutes(const AMinutes: Integer);
    function UtcNow: TDateTime;
  end;

  [TestFixture]
  TRadIAVisualRuntimeSessionTests = class
  private
    FClock: TRadIAVisualSessionTestClock;
    FSession: IRadIAVisualRuntimeSession;
    function BuildCapture(
      const AProcessId: LongWord;
      const APhase: TRadIAVisualCapturePhase;
      const ASize: Integer = 128
    ): TRadIAVisualCapture;
    function BuildIdentity(
      const ASessionId: string;
      const AProcessId: LongWord
    ): TRadIARuntimeSessionIdentity;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure RecordsOrderedEventsAndBoundedCaptures;
    [Test]
    procedure RejectsCaptureFromAnotherProcess;
    [Test]
    procedure RejectsOversizedCapture;
    [Test]
    procedure ExpiresCapturedPixelsAfterRetentionWindow;
    [Test]
    procedure NewSessionDiscardsPreviousVisualEvidence;
  end;

implementation

uses
  System.DateUtils,
  System.SysUtils;

{ TRadIAVisualSessionTestClock }

procedure TRadIAVisualSessionTestClock.AdvanceMinutes(
  const AMinutes: Integer
);
begin
  FNowUtc := IncMinute(FNowUtc, AMinutes);
end;

constructor TRadIAVisualSessionTestClock.Create(const ANowUtc: TDateTime);
begin
  inherited Create;
  FNowUtc := ANowUtc;
end;

function TRadIAVisualSessionTestClock.UtcNow: TDateTime;
begin
  Result := FNowUtc;
end;

{ TRadIAVisualRuntimeSessionTests }

function TRadIAVisualRuntimeSessionTests.BuildCapture(
  const AProcessId: LongWord;
  const APhase: TRadIAVisualCapturePhase;
  const ASize: Integer
): TRadIAVisualCapture;
var
  LBytes: TArray<Byte>;
begin
  SetLength(LBytes, ASize);
  Result := TRadIAVisualCapture.Create(
    TGUID.NewGuid.ToString,
    AProcessId,
    'window-1',
    APhase,
    TRadIAVisualCaptureContent.Create(
      'image/png',
      640,
      480,
      LBytes
    ),
    FClock.UtcNow
  );
end;

function TRadIAVisualRuntimeSessionTests.BuildIdentity(
  const ASessionId: string;
  const AProcessId: LongWord
): TRadIARuntimeSessionIdentity;
begin
  Result := TRadIARuntimeSessionIdentity.Create(
    ASessionId,
    AProcessId,
    FClock.UtcNow,
    'C:\Tests\RuntimeLab.exe',
    'C:\Tests\RuntimeLab.dproj',
    'build-1'
  );
end;

procedure TRadIAVisualRuntimeSessionTests.
  ExpiresCapturedPixelsAfterRetentionWindow;
var
  LSnapshot: TRadIAVisualSessionSnapshot;
begin
  FSession.BeginSession(BuildIdentity('session-1', 42));
  Assert.IsTrue(FSession.RecordCapture(
    'session-1',
    BuildCapture(42, vcpBefore)
  ));
  FClock.AdvanceMinutes(10);
  Assert.IsFalse(FSession.TryGetSnapshot(LSnapshot));
end;

procedure TRadIAVisualRuntimeSessionTests.
  NewSessionDiscardsPreviousVisualEvidence;
var
  LSnapshot: TRadIAVisualSessionSnapshot;
begin
  FSession.BeginSession(BuildIdentity('session-1', 42));
  FSession.RecordCapture('session-1', BuildCapture(42, vcpBefore));
  FSession.BeginSession(BuildIdentity('session-2', 77));
  Assert.IsTrue(FSession.TryGetSnapshot(LSnapshot));
  Assert.AreEqual('session-2', LSnapshot.Session.SessionId);
  Assert.AreEqual<Integer>(0, Length(LSnapshot.Captures));
  Assert.AreEqual<Integer>(1, Length(LSnapshot.Events));
end;

procedure TRadIAVisualRuntimeSessionTests.
  RecordsOrderedEventsAndBoundedCaptures;
var
  LSnapshot: TRadIAVisualSessionSnapshot;
begin
  FSession.BeginSession(BuildIdentity('session-1', 42));
  Assert.IsTrue(FSession.RecordCapture(
    'session-1',
    BuildCapture(42, vcpBefore)
  ));
  Assert.IsTrue(FSession.RecordEvent(
    'session-1',
    vsekActionStarted,
    1,
    'running',
    'Invoking the selected control.'
  ));
  Assert.IsTrue(FSession.RecordEvent(
    'session-1',
    vsekActionCompleted,
    1,
    'succeeded',
    'The control reported success.'
  ));
  Assert.IsTrue(FSession.RecordCapture(
    'session-1',
    BuildCapture(42, vcpAfter)
  ));
  Assert.IsTrue(FSession.Complete(
    'session-1',
    vssCompleted,
    'Runtime validation completed.'
  ));
  Assert.IsTrue(FSession.TryGetSnapshot(LSnapshot));
  Assert.AreEqual(vssCompleted, LSnapshot.State);
  Assert.AreEqual<Integer>(2, Length(LSnapshot.Captures));
  Assert.AreEqual<Integer>(6, Length(LSnapshot.Events));
  Assert.AreEqual<Int64>(1, LSnapshot.Events[0].Sequence);
  Assert.AreEqual<Int64>(6, LSnapshot.Events[5].Sequence);
  Assert.AreEqual(vcpBefore, LSnapshot.Captures[0].Phase);
  Assert.AreEqual(vcpAfter, LSnapshot.Captures[1].Phase);
end;

procedure TRadIAVisualRuntimeSessionTests.RejectsCaptureFromAnotherProcess;
begin
  FSession.BeginSession(BuildIdentity('session-1', 42));
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FSession.RecordCapture(
        'session-1',
        BuildCapture(77, vcpBefore)
      );
    end,
    EArgumentException,
    'Visual capture must belong to the active runtime process.'
  );
end;

procedure TRadIAVisualRuntimeSessionTests.RejectsOversizedCapture;
begin
  FSession.BeginSession(BuildIdentity('session-1', 42));
  Assert.WillRaiseWithMessage(
    procedure
    begin
      FSession.RecordCapture(
        'session-1',
        BuildCapture(42, vcpBefore, 2 * 1024 * 1024 + 1)
      );
    end,
    EArgumentOutOfRangeException,
    'Visual capture must contain at most 2 MiB.'
  );
end;

procedure TRadIAVisualRuntimeSessionTests.Setup;
begin
  FClock := TRadIAVisualSessionTestClock.Create(EncodeDate(2026, 8, 10));
  FSession := TRadIAVisualRuntimeSession.Create(FClock);
end;

procedure TRadIAVisualRuntimeSessionTests.TearDown;
begin
  FSession := nil;
  FClock := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAVisualRuntimeSessionTests);

end.
