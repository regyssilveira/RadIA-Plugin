unit RadIA.Tests.WebViewLifecycle;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAWebViewLifecycleTests = class
  public
    [Test]
    procedure TracksCreateNavigationAndReady;
    [Test]
    procedure BoundsRecoveryAttempts;
    [Test]
    procedure StopsRecoveryDuringShutdown;
    [Test]
    procedure ResetBudgetRequiresReadyState;
  end;

implementation

uses
  RadIA.Core.WebViewLifecycle;

procedure TRadIAWebViewLifecycleTests.TracksCreateNavigationAndReady;
var
  LLifecycle: TRadIAWebViewLifecycle;
  LSnapshot: TRadIAWebViewLifecycleSnapshot;
begin
  LLifecycle := TRadIAWebViewLifecycle.Create;
  try
    LLifecycle.BeginCreate;
    LLifecycle.BeginNavigation;
    LLifecycle.MarkReady;
    LSnapshot := LLifecycle.Snapshot;
    Assert.AreEqual(Ord(wlsReady), Ord(LSnapshot.State));
    Assert.AreEqual(1, LSnapshot.Generation);
    Assert.AreEqual(0, LSnapshot.RecoveryCount);
  finally
    LLifecycle.Free;
  end;
end;

procedure TRadIAWebViewLifecycleTests.BoundsRecoveryAttempts;
var
  LLifecycle: TRadIAWebViewLifecycle;
begin
  LLifecycle := TRadIAWebViewLifecycle.Create(2);
  try
    Assert.IsTrue(LLifecycle.RegisterFailure(False));
    Assert.IsTrue(LLifecycle.RegisterFailure(False));
    Assert.IsFalse(LLifecycle.RegisterFailure(False));
    Assert.AreEqual(2, LLifecycle.Snapshot.RecoveryAttempts);
    Assert.AreEqual(2, LLifecycle.Snapshot.RecoveryCount);
    Assert.AreEqual(Ord(wlsFailed), Ord(LLifecycle.Snapshot.State));
  finally
    LLifecycle.Free;
  end;
end;

procedure TRadIAWebViewLifecycleTests.StopsRecoveryDuringShutdown;
var
  LLifecycle: TRadIAWebViewLifecycle;
begin
  LLifecycle := TRadIAWebViewLifecycle.Create;
  try
    Assert.IsFalse(LLifecycle.RegisterFailure(True));
    LLifecycle.Stop;
    Assert.IsFalse(LLifecycle.RegisterFailure(False));
    Assert.AreEqual(Ord(wlsStopped), Ord(LLifecycle.Snapshot.State));
  finally
    LLifecycle.Free;
  end;
end;

procedure TRadIAWebViewLifecycleTests.ResetBudgetRequiresReadyState;
var
  LLifecycle: TRadIAWebViewLifecycle;
begin
  LLifecycle := TRadIAWebViewLifecycle.Create;
  try
    Assert.IsTrue(LLifecycle.RegisterFailure(False));
    LLifecycle.ResetRecoveryBudget;
    Assert.AreEqual(1, LLifecycle.Snapshot.RecoveryAttempts);
    LLifecycle.MarkReady;
    Assert.AreEqual(0, LLifecycle.Snapshot.RecoveryAttempts);
    Assert.AreEqual(1, LLifecycle.Snapshot.RecoveryCount);
  finally
    LLifecycle.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAWebViewLifecycleTests);

end.
