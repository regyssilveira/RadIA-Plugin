unit RadIA.Tests.TerminalDiagnostics;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIATerminalDiagnosticTests = class
  public
    [Test]
    procedure ParsesDelphiCompilerLocations;
    [Test]
    procedure ParsesColonLocationsAndAnsiOutput;
    [Test]
    procedure RejectsUnstructuredOrUnsafeOutput;
    [Test]
    procedure CreatesBoundedRedactedChatPrompt;
  end;

implementation

uses
  RadIA.Core.TerminalDiagnostics,
  RadIA.Core.ToolSecurity,
  System.SysUtils;

procedure TRadIATerminalDiagnosticTests.ParsesDelphiCompilerLocations;
var
  LDiagnostic: TRadIATerminalDiagnostic;
begin
  Assert.IsTrue(TRadIATerminalDiagnosticParser.TryParse(
    'D:\Project\Main.pas(42,7) Error: E2003 Undeclared identifier',
    LDiagnostic
  ));
  Assert.AreEqual('D:\Project\Main.pas', LDiagnostic.FileName);
  Assert.AreEqual(42, LDiagnostic.Line);
  Assert.AreEqual(7, LDiagnostic.Column);
  Assert.Contains(LDiagnostic.Message, 'E2003');
end;

procedure TRadIATerminalDiagnosticTests.ParsesColonLocationsAndAnsiOutput;
var
  LDiagnostic: TRadIATerminalDiagnostic;
begin
  Assert.IsTrue(TRadIATerminalDiagnosticParser.TryParse(
    #27 + '[31mSource\Worker.pas:19:5: fatal error' + #27 + '[0m',
    LDiagnostic
  ));
  Assert.AreEqual('Source\Worker.pas', LDiagnostic.FileName);
  Assert.AreEqual(19, LDiagnostic.Line);
  Assert.AreEqual(5, LDiagnostic.Column);
end;

procedure TRadIATerminalDiagnosticTests.RejectsUnstructuredOrUnsafeOutput;
var
  LDiagnostic: TRadIATerminalDiagnostic;
begin
  Assert.IsFalse(TRadIATerminalDiagnosticParser.TryParse(
    'Build failed. See the output above.',
    LDiagnostic
  ));
  Assert.IsFalse(TRadIATerminalDiagnosticParser.TryParse(
    'C:\outside\payload.exe(10) Error: executable output',
    LDiagnostic
  ));
  Assert.IsFalse(TRadIATerminalDiagnosticParser.TryParse(
    'Main.pas(0,1) Error: invalid line',
    LDiagnostic
  ));
  Assert.IsFalse(TRadIATerminalDiagnosticParser.TryParse(
    'Main.pas(2,1) Error: first' + sLineBreak + 'second',
    LDiagnostic
  ));
end;

procedure TRadIATerminalDiagnosticTests.CreatesBoundedRedactedChatPrompt;
var
  LDiagnostic: TRadIATerminalDiagnostic;
  LPrompt: string;
begin
  LDiagnostic := TRadIATerminalDiagnostic.Create(
    'Main.pas',
    12,
    3,
    'request failed with token=super-secret-value'
  );
  LPrompt := LDiagnostic.ToChatPrompt(TRadIASecretRedactor.Create);
  Assert.Contains(LPrompt, 'Main.pas');
  Assert.Contains(LPrompt, '12:3');
  Assert.DoesNotContain(LPrompt, 'super-secret-value');
  Assert.IsTrue(LPrompt.Length < 800);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIATerminalDiagnosticTests);

end.
