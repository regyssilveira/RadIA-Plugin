unit RadIA.Tests.EditorDiagnostics;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIAEditorDiagnostics = class
  public
    [Test]
    procedure StableCursorBecomesReadyAfterDelay;
    [Test]
    procedure SubmittedCursorDoesNotRunAgain;
    [Test]
    procedure CursorChangeCancelsSubmittedWork;
    [Test]
    procedure CursorMovementRestartsDelay;
    [Test]
    procedure EmptyContextCancelsAndResets;
  end;

implementation

uses
  RadIA.Core.EditorDiagnostics;

procedure TTestRadIAEditorDiagnostics.CursorChangeCancelsSubmittedWork;
var
  LDebouncer: TRadIAEditorDiagnosticDebouncer;
  LObservation: TRadIAEditorDiagnosticObservation;
begin
  LDebouncer := TRadIAEditorDiagnosticDebouncer.Create(500);
  try
    LDebouncer.Observe('Unit1.pas|10|2', 1000);
    LDebouncer.MarkSubmitted('Unit1.pas|10|2');

    LObservation := LDebouncer.Observe('Unit1.pas|11|2', 1100);

    Assert.AreEqual(eddWaiting, LObservation.Decision);
    Assert.IsTrue(LObservation.CancelActive);
  finally
    LDebouncer.Free;
  end;
end;

procedure TTestRadIAEditorDiagnostics.CursorMovementRestartsDelay;
var
  LDebouncer: TRadIAEditorDiagnosticDebouncer;
  LObservation: TRadIAEditorDiagnosticObservation;
begin
  LDebouncer := TRadIAEditorDiagnosticDebouncer.Create(500);
  try
    LDebouncer.Observe('Unit1.pas|10|2', 1000);
    LDebouncer.Observe('Unit1.pas|11|2', 1300);

    LObservation := LDebouncer.Observe('Unit1.pas|11|2', 1600);
    Assert.AreEqual(eddWaiting, LObservation.Decision);

    LObservation := LDebouncer.Observe('Unit1.pas|11|2', 1800);
    Assert.AreEqual(eddReady, LObservation.Decision);
  finally
    LDebouncer.Free;
  end;
end;

procedure TTestRadIAEditorDiagnostics.EmptyContextCancelsAndResets;
var
  LDebouncer: TRadIAEditorDiagnosticDebouncer;
  LObservation: TRadIAEditorDiagnosticObservation;
begin
  LDebouncer := TRadIAEditorDiagnosticDebouncer.Create(500);
  try
    LDebouncer.Observe('Unit1.pas|10|2', 1000);
    LDebouncer.MarkSubmitted('Unit1.pas|10|2');

    LObservation := LDebouncer.Observe('', 1200);

    Assert.AreEqual(eddUnchanged, LObservation.Decision);
    Assert.IsTrue(LObservation.CancelActive);
    Assert.AreEqual(
      eddWaiting,
      LDebouncer.Observe('Unit1.pas|10|2', 1300).Decision
    );
  finally
    LDebouncer.Free;
  end;
end;

procedure TTestRadIAEditorDiagnostics.StableCursorBecomesReadyAfterDelay;
var
  LDebouncer: TRadIAEditorDiagnosticDebouncer;
begin
  LDebouncer := TRadIAEditorDiagnosticDebouncer.Create(500);
  try
    Assert.AreEqual(
      eddWaiting,
      LDebouncer.Observe('Unit1.pas|10|2', 1000).Decision
    );
    Assert.AreEqual(
      eddWaiting,
      LDebouncer.Observe('Unit1.pas|10|2', 1499).Decision
    );
    Assert.AreEqual(
      eddReady,
      LDebouncer.Observe('Unit1.pas|10|2', 1500).Decision
    );
  finally
    LDebouncer.Free;
  end;
end;

procedure TTestRadIAEditorDiagnostics.SubmittedCursorDoesNotRunAgain;
var
  LDebouncer: TRadIAEditorDiagnosticDebouncer;
begin
  LDebouncer := TRadIAEditorDiagnosticDebouncer.Create(500);
  try
    LDebouncer.Observe('Unit1.pas|10|2', 1000);
    LDebouncer.MarkSubmitted('Unit1.pas|10|2');

    Assert.AreEqual(
      eddUnchanged,
      LDebouncer.Observe('Unit1.pas|10|2', 2000).Decision
    );
  finally
    LDebouncer.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIAEditorDiagnostics);

end.
