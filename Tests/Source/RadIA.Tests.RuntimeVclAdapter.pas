unit RadIA.Tests.RuntimeVclAdapter;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TTestRadIARuntimeVclAdapter = class
  public
    [Test]
    procedure AcceptsBoundedDefaults;
    [Test]
    procedure RejectsAdapterFromAnotherSession;
    [Test]
    procedure AcceptsAdapterBoundToRuntimeSession;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.RuntimeAutomation,
  RadIA.Core.RuntimeVclAdapter;

function CompleteSession: TRadIARuntimeSessionIdentity;
begin
  Result := TRadIARuntimeSessionIdentity.Create(
    'session-1', 42, Now, 'C:\Workspace\App.exe',
    'C:\Workspace\App.dproj', 'build-1'
  );
end;

procedure TTestRadIARuntimeVclAdapter.AcceptsAdapterBoundToRuntimeSession;
var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
begin
  LIdentity := TRadIARuntimeVclAdapterIdentity.Create(
    42, 'session-1', '\\.\pipe\RadIA.Runtime.42',
    '0123456789abcdef0123456789abcdef', 1
  );
  Assert.IsTrue(LIdentity.IsUsableFor(CompleteSession));
end;

procedure TTestRadIARuntimeVclAdapter.AcceptsBoundedDefaults;
begin
  Assert.IsTrue(TRadIARuntimeVclAdapterLimits.Defaults.IsValid);
end;

procedure TTestRadIARuntimeVclAdapter.RejectsAdapterFromAnotherSession;
var
  LIdentity: TRadIARuntimeVclAdapterIdentity;
begin
  LIdentity := TRadIARuntimeVclAdapterIdentity.Create(
    42, 'session-2', '\\.\pipe\RadIA.Runtime.42',
    '0123456789abcdef0123456789abcdef', 1
  );
  Assert.IsFalse(LIdentity.IsUsableFor(CompleteSession));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestRadIARuntimeVclAdapter);

end.
