unit RadIA.Tests.MemoryDiagnostics;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAMemoryDiagnostics = class
  public
    [Test]
    procedure AcceptsBoundedLimits;
    [Test]
    procedure RejectsUnboundedLimits;
    [Test]
    procedure RequiresCompleteBackendStatus;
    [Test]
    procedure MapsPublicEnumNames;
  end;

implementation

uses
  RadIA.Core.MemoryDiagnostics;

procedure TTestRadIAMemoryDiagnostics.AcceptsBoundedLimits;
var
  LLimits: TRadIAMemoryDiagnosticsLimits;
begin
  LLimits := TRadIAMemoryDiagnosticsLimits.Create(120000, 52428800, 10);
  Assert.IsTrue(LLimits.IsValid);
end;

procedure TTestRadIAMemoryDiagnostics.RejectsUnboundedLimits;
var
  LLimits: TRadIAMemoryDiagnosticsLimits;
begin
  LLimits := TRadIAMemoryDiagnosticsLimits.Create(0, 0, 0);
  Assert.IsFalse(LLimits.IsValid);
end;

procedure TTestRadIAMemoryDiagnostics.RequiresCompleteBackendStatus;
var
  LReadyStatus: TRadIAMemoryBackendStatus;
begin
  LReadyStatus := TRadIAMemoryBackendStatus.Create(
    mbkFastMM5,
    mbsReady,
    '5.07',
    'D:\Delphi\FastMM5',
    'D:\Delphi\FastMM5\FastMM_FullDebugMode.dll',
    'Win32',
    'FastMM5 is ready.'
  );
  Assert.IsTrue(LReadyStatus.IsReady);
end;

procedure TTestRadIAMemoryDiagnostics.MapsPublicEnumNames;
begin
  Assert.AreEqual('leak', RadIAMemoryEventKindToString(mekLeak));
  Assert.AreEqual(
    'regressed',
    RadIAMemoryComparisonOutcomeToString(mcoRegressed)
  );
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAMemoryDiagnostics);

end.
