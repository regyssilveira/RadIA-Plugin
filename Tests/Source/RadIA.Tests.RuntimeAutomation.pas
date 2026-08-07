unit RadIA.Tests.RuntimeAutomation;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.RuntimeAutomation;

type
  [TestFixture]
  TTestRadIARuntimeAutomation = class
  private
    function CreateSession: TRadIARuntimeSessionIdentity;
    function CreateSelector: TRadIARuntimeSelector;
  public
    [Test]
    procedure AcceptsCompleteSessionIdentity;
    [Test]
    procedure RejectsIncompleteSessionIdentity;
    [Test]
    procedure AcceptsStableSelectors;
    [Test]
    procedure RejectsUnstableSelector;
    [Test]
    procedure AcceptsBoundedScenario;
    [Test]
    procedure RejectsScenarioBeyondLimits;
    [Test]
    procedure RejectsActionWithoutStableSelector;
  end;

implementation

uses
  System.SysUtils;

function TTestRadIARuntimeAutomation.CreateSelector:
  TRadIARuntimeSelector;
begin
  Result := TRadIARuntimeSelector.Create(
    '',
    'TButton',
    'btnCancel',
    'Cancel',
    'MainForm/TargetForm'
  );
end;

function TTestRadIARuntimeAutomation.CreateSession:
  TRadIARuntimeSessionIdentity;
begin
  Result := TRadIARuntimeSessionIdentity.Create(
    'session-1',
    1234,
    Now,
    'C:\Workspace\RuntimeLab.exe',
    'C:\Workspace\RuntimeLab.dproj',
    'build-1'
  );
end;

procedure TTestRadIARuntimeAutomation.AcceptsBoundedScenario;
var
  LActions: TArray<TRadIARuntimeScenarioAction>;
  LScenario: TRadIARuntimeScenario;
begin
  SetLength(LActions, 1);
  LActions[0] := TRadIARuntimeScenarioAction.Create(
    rakInvoke,
    CreateSelector,
    '',
    1000
  );
  LScenario := TRadIARuntimeScenario.Create(
    'Cancel target form',
    CreateSession,
    TRadIARuntimeScenarioLimits.Create(5, 5000, 1),
    LActions
  );

  Assert.IsTrue(LScenario.IsExecutable);
end;

procedure TTestRadIARuntimeAutomation.AcceptsCompleteSessionIdentity;
begin
  Assert.IsTrue(CreateSession.IsComplete);
end;

procedure TTestRadIARuntimeAutomation.AcceptsStableSelectors;
begin
  Assert.IsTrue(CreateSelector.HasStableIdentity);
  Assert.IsTrue(
    TRadIARuntimeSelector.Create(
      'cancel-action',
      '',
      '',
      '',
      ''
    ).HasStableIdentity
  );
end;

procedure TTestRadIARuntimeAutomation.RejectsActionWithoutStableSelector;
var
  LActions: TArray<TRadIARuntimeScenarioAction>;
  LScenario: TRadIARuntimeScenario;
begin
  SetLength(LActions, 1);
  LActions[0] := TRadIARuntimeScenarioAction.Create(
    rakInvoke,
    TRadIARuntimeSelector.Create('', 'TButton', '', 'Cancel', ''),
    '',
    1000
  );
  LScenario := TRadIARuntimeScenario.Create(
    'Unsafe selector',
    CreateSession,
    TRadIARuntimeScenarioLimits.Create(5, 5000, 1),
    LActions
  );

  Assert.IsFalse(LScenario.IsExecutable);
end;

procedure TTestRadIARuntimeAutomation.RejectsIncompleteSessionIdentity;
var
  LSession: TRadIARuntimeSessionIdentity;
begin
  LSession := TRadIARuntimeSessionIdentity.Create(
    '',
    0,
    0,
    '',
    '',
    ''
  );

  Assert.IsFalse(LSession.IsComplete);
end;

procedure TTestRadIARuntimeAutomation.RejectsScenarioBeyondLimits;
var
  LActions: TArray<TRadIARuntimeScenarioAction>;
  LScenario: TRadIARuntimeScenario;
begin
  SetLength(LActions, 2);
  LActions[0] := TRadIARuntimeScenarioAction.Create(
    rakInvoke,
    CreateSelector,
    '',
    1000
  );
  LActions[1] := LActions[0];
  LScenario := TRadIARuntimeScenario.Create(
    'Too many actions',
    CreateSession,
    TRadIARuntimeScenarioLimits.Create(1, 5000, 1),
    LActions
  );

  Assert.IsFalse(LScenario.IsExecutable);
end;

procedure TTestRadIARuntimeAutomation.RejectsUnstableSelector;
var
  LSelector: TRadIARuntimeSelector;
begin
  LSelector := TRadIARuntimeSelector.Create(
    '',
    'TButton',
    '',
    'Cancel',
    ''
  );

  Assert.IsFalse(LSelector.HasStableIdentity);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimeAutomation);

end.
