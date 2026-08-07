unit RadIA.Tests.RuntimeDebugSession;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.RuntimeDebugSession;

type
  [TestFixture]
  TTestRadIARuntimeDebugSession = class
  private
    FCoordinator: IRadIARuntimeDebugSessionCoordinator;
    FSessionId: string;
    procedure AttachProcess;
    function CreateWait(
      const AKinds: TRadIARuntimeDebugEventKinds;
      const ATimeoutMs: Cardinal
    ): IRadIARuntimeDebugWait;
  public
    [Setup]
    procedure Setup;
    [Test]
    procedure CreatesCompleteCorrelatedIdentity;
    [Test]
    procedure RejectsStaleSessionAttachment;
    [Test]
    procedure MatchesStructuredExceptionEvent;
    [Test]
    procedure ReturnsLastRecordedEvent;
    [Test]
    procedure TimesOutWithoutBusyWait;
    [Test]
    procedure CancelsWaitingOperation;
    [Test]
    procedure InvalidatesWaitWhenSessionChanges;
  end;

implementation

uses
  System.Classes,
  System.Diagnostics,
  System.SyncObjs,
  System.SysUtils;

type
  TRadIARuntimeWaitThread = class(TThread)
  private
    FCompleted: TEvent;
    FResult: TRadIARuntimeDebugWaitResult;
    FWait: IRadIARuntimeDebugWait;
  protected
    procedure Execute; override;
  public
    constructor Create(const AWait: IRadIARuntimeDebugWait);
    destructor Destroy; override;
    function AwaitCompletion: Boolean;
    property WaitResult: TRadIARuntimeDebugWaitResult read FResult;
  end;

{ TRadIARuntimeWaitThread }

function TRadIARuntimeWaitThread.AwaitCompletion: Boolean;
begin
  Result := FCompleted.WaitFor(3000) = wrSignaled;
end;

constructor TRadIARuntimeWaitThread.Create(
  const AWait: IRadIARuntimeDebugWait
);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FWait := AWait;
  FCompleted := TEvent.Create(nil, True, False, '');
end;

destructor TRadIARuntimeWaitThread.Destroy;
begin
  FCompleted.Free;
  inherited Destroy;
end;

procedure TRadIARuntimeWaitThread.Execute;
begin
  FResult := FWait.Wait;
  FCompleted.SetEvent;
end;

{ TTestRadIARuntimeDebugSession }

procedure TTestRadIARuntimeDebugSession.AttachProcess;
begin
  Assert.IsTrue(
    FCoordinator.AttachProcess(
      FSessionId,
      1234,
      Now,
      'C:\Workspace\RuntimeLab.exe',
      'size:timestamp'
    )
  );
end;

procedure TTestRadIARuntimeDebugSession.CancelsWaitingOperation;
var
  LThread: TRadIARuntimeWaitThread;
  LWait: IRadIARuntimeDebugWait;
begin
  AttachProcess;
  LWait := CreateWait([rdekException], 3000);
  LThread := TRadIARuntimeWaitThread.Create(LWait);
  try
    LThread.Start;
    LWait.Cancel;
    Assert.IsTrue(LThread.AwaitCompletion);
    Assert.AreEqual(
      Ord(rdwrCancelled),
      Ord(LThread.WaitResult.Reason)
    );
  finally
    LWait.Cancel;
    LThread.WaitFor;
    LThread.Free;
  end;
end;

function TTestRadIARuntimeDebugSession.CreateWait(
  const AKinds: TRadIARuntimeDebugEventKinds;
  const ATimeoutMs: Cardinal
): IRadIARuntimeDebugWait;
begin
  Result := FCoordinator.CreateWait(
    TRadIARuntimeDebugWaitFilter.Create(
      FSessionId,
      1234,
      FCoordinator.GetLastSequence,
      AKinds,
      ATimeoutMs
    )
  );
end;

procedure TTestRadIARuntimeDebugSession.CreatesCompleteCorrelatedIdentity;
begin
  AttachProcess;

  Assert.IsTrue(FCoordinator.GetCurrentSession.IsComplete);
  Assert.AreEqual(LongWord(1234), FCoordinator.GetCurrentSession.ProcessId);
  Assert.AreEqual(
    'C:\Workspace\RuntimeLab.dproj',
    FCoordinator.GetCurrentSession.ProjectPath
  );
end;

procedure TTestRadIARuntimeDebugSession.InvalidatesWaitWhenSessionChanges;
var
  LThread: TRadIARuntimeWaitThread;
  LWait: IRadIARuntimeDebugWait;
begin
  AttachProcess;
  LWait := CreateWait([rdekException], 3000);
  LThread := TRadIARuntimeWaitThread.Create(LWait);
  try
    LThread.Start;
    FCoordinator.BeginSession('C:\Workspace\Other.dproj');
    Assert.IsTrue(LThread.AwaitCompletion);
    Assert.AreEqual(
      Ord(rdwrSessionChanged),
      Ord(LThread.WaitResult.Reason)
    );
  finally
    LWait.Cancel;
    LThread.WaitFor;
    LThread.Free;
  end;
end;

procedure TTestRadIARuntimeDebugSession.MatchesStructuredExceptionEvent;
var
  LResult: TRadIARuntimeDebugWaitResult;
  LWait: IRadIARuntimeDebugWait;
begin
  AttachProcess;
  LWait := CreateWait([rdekException], 1000);
  Assert.IsTrue(
    FCoordinator.RecordEvent(
      FSessionId,
      rdekException,
      'exception',
      'Access violation'
    )
  );

  LResult := LWait.Wait;

  Assert.AreEqual(Ord(rdwrMatched), Ord(LResult.Reason));
  Assert.AreEqual(Ord(rdekException), Ord(LResult.Event.Kind));
  Assert.AreEqual(LongWord(1234), LResult.Event.ProcessId);
  Assert.AreEqual('Access violation', LResult.Event.Details);
end;

procedure TTestRadIARuntimeDebugSession.RejectsStaleSessionAttachment;
begin
  Assert.IsFalse(
    FCoordinator.AttachProcess(
      'stale-session',
      1234,
      Now,
      'C:\Workspace\RuntimeLab.exe',
      'size:timestamp'
    )
  );
  Assert.IsFalse(FCoordinator.GetCurrentSession.IsComplete);
end;

procedure TTestRadIARuntimeDebugSession.ReturnsLastRecordedEvent;
var
  LEvent: TRadIARuntimeDebugEvent;
begin
  Assert.IsFalse(FCoordinator.TryGetLastEvent(LEvent));
  AttachProcess;
  Assert.IsTrue(
    FCoordinator.RecordEvent(
      FSessionId,
      rdekRunning,
      'running',
      'Application resumed'
    )
  );
  Assert.IsTrue(FCoordinator.TryGetLastEvent(LEvent));
  Assert.AreEqual(Int64(1), LEvent.Sequence);
  Assert.AreEqual(rdekRunning, LEvent.Kind);
  Assert.AreEqual('Application resumed', LEvent.Details);
end;

procedure TTestRadIARuntimeDebugSession.Setup;
begin
  FCoordinator := TRadIARuntimeDebugSessionCoordinator.Create;
  FSessionId := FCoordinator.BeginSession(
    'C:\Workspace\RuntimeLab.dproj'
  );
end;

procedure TTestRadIARuntimeDebugSession.TimesOutWithoutBusyWait;
var
  LResult: TRadIARuntimeDebugWaitResult;
  LStopwatch: TStopwatch;
begin
  AttachProcess;
  LStopwatch := TStopwatch.StartNew;

  LResult := CreateWait([rdekException], 100).Wait;

  Assert.AreEqual(Ord(rdwrTimeout), Ord(LResult.Reason));
  Assert.IsTrue(LStopwatch.ElapsedMilliseconds >= 80);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimeDebugSession);

end.
