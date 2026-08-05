unit RadIA.Tests.CliProcess;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIACliProcessTests = class
  public
    [Test]
    procedure CapturesStandardOutput;
    [Test]
    procedure CapturesErrorAndExitCode;
    [Test]
    procedure TimeoutTerminatesProcessTree;
    [Test]
    procedure CancellationTerminatesProcessTree;
    [Test]
    procedure WritesStandardInputAndClosesPipe;
    [Test]
    procedure WritesContinuousInteractiveInput;
    [Test]
    procedure PipeSessionReportsTerminalCapabilities;
    [Test]
    procedure PseudoTerminalStartupCompletes;
    [Test]
    [Category('ExternalProcess')]
    procedure PseudoTerminalStreamsInputAndResizes;
    [Test]
    procedure PseudoTerminalRejectsInvalidDimensions;
    [Test]
    procedure PseudoTerminalAvailabilityMatchesRuntimeExports;
  end;

implementation

uses
  System.SyncObjs,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliProcess,
  RadIA.Core.PseudoTerminal;

function NewCommandInvocation(
  const ACommand: string
): TRadIACliInvocation;
begin
  Result := TRadIACliInvocation.Create(
    GetEnvironmentVariable('ComSpec'),
    ['/D', '/S', '/C', ACommand],
    GetCurrentDir,
    'text'
  );
end;

procedure TRadIACliProcessTests.CancellationTerminatesProcessTree;
var
  LCompleted: TEvent;
  LResult: TRadIACliProcessResult;
  LSession: IRadIACliProcessSession;
begin
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    LSession := TRadIACliProcessRunner.Start(
      NewCommandInvocation('ping 127.0.0.1 -n 20 > nul'),
      30000,
      nil,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LResult := AResult;
        LCompleted.SetEvent;
      end
    );
    Sleep(100);
    LSession.Cancel;
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(5000));
    Assert.IsTrue(LResult.Cancelled);
    Assert.IsFalse(LSession.IsRunning);
  finally
    LCompleted.Free;
  end;
end;

procedure TRadIACliProcessTests.CapturesErrorAndExitCode;
var
  LCompleted: TEvent;
  LResult: TRadIACliProcessResult;
begin
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    TRadIACliProcessRunner.Start(
      NewCommandInvocation('echo failure 1>&2 & exit /b 7'),
      5000,
      nil,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LResult := AResult;
        LCompleted.SetEvent;
      end
    );
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(5000));
    Assert.AreEqual<Cardinal>(7, LResult.ExitCode);
    Assert.Contains(LResult.StdErr, 'failure');
    Assert.IsFalse(LResult.Succeeded);
  finally
    LCompleted.Free;
  end;
end;

procedure TRadIACliProcessTests.CapturesStandardOutput;
var
  LCompleted: TEvent;
  LResult: TRadIACliProcessResult;
  LStreamed: string;
begin
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    TRadIACliProcessRunner.Start(
      NewCommandInvocation('echo radia-process-ok'),
      5000,
      procedure(AChunk: string)
      begin
        LStreamed := LStreamed + AChunk;
      end,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LResult := AResult;
        LCompleted.SetEvent;
      end
    );
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(5000));
    Assert.IsTrue(LResult.Succeeded);
    Assert.Contains(LResult.StdOut, 'radia-process-ok');
    Assert.Contains(LStreamed, 'radia-process-ok');
  finally
    LCompleted.Free;
  end;
end;

procedure TRadIACliProcessTests.PipeSessionReportsTerminalCapabilities;
var
  LCompleted: TEvent;
  LSession: IRadIACliProcessSession;
begin
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    LSession := TRadIACliProcessRunner.Start(
      NewCommandInvocation('echo pipe-session'),
      5000,
      nil,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LCompleted.SetEvent;
      end
    );
    Assert.IsFalse(LSession.IsPseudoTerminal);
    Assert.IsFalse(LSession.Resize(100, 30));
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(5000));
  finally
    LCompleted.Free;
  end;
end;

procedure TRadIACliProcessTests.TimeoutTerminatesProcessTree;
var
  LCompleted: TEvent;
  LResult: TRadIACliProcessResult;
begin
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    TRadIACliProcessRunner.Start(
      NewCommandInvocation('ping 127.0.0.1 -n 20 > nul'),
      100,
      nil,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LResult := AResult;
        LCompleted.SetEvent;
      end
    );
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(5000));
    Assert.IsTrue(LResult.TimedOut);
    Assert.IsFalse(LResult.Succeeded);
  finally
    LCompleted.Free;
  end;
end;

procedure TRadIACliProcessTests.WritesStandardInputAndClosesPipe;
var
  LCompleted: TEvent;
  LResult: TRadIACliProcessResult;
begin
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    TRadIACliProcessRunner.StartWithInput(
      NewCommandInvocation('findstr radia-input'),
      'radia-input' + sLineBreak,
      5000,
      nil,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LResult := AResult;
        LCompleted.SetEvent;
      end
    );
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(5000));
    Assert.IsTrue(LResult.Succeeded);
    Assert.Contains(LResult.StdOut, 'radia-input');
  finally
    LCompleted.Free;
  end;
end;

procedure TRadIACliProcessTests.WritesContinuousInteractiveInput;
var
  LCompleted: TEvent;
  LDeadline: UInt64;
  LResult: TRadIACliProcessResult;
  LSession: IRadIACliProcessSession;
  LWritten: Boolean;
begin
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    LSession := TRadIACliProcessRunner.StartInteractive(
      TRadIACliInvocation.Create(
        'powershell.exe',
        [
          '-NoLogo',
          '-NoProfile',
          '-Command',
          '$value = Read-Host; Write-Output "received-$value"'
        ],
        GetCurrentDir,
        'text'
      ),
      5000,
      nil,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LResult := AResult;
        LCompleted.SetEvent;
      end
    );
    LDeadline := GetTickCount64 + 2000;
    repeat
      LWritten := LSession.WriteInput('radia-live-input' + sLineBreak);
      if not LWritten then
        Sleep(10);
    until LWritten or (GetTickCount64 >= LDeadline);
    Assert.IsTrue(LWritten, 'Interactive stdin did not become ready.');
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(5000));
    Assert.IsTrue(LResult.Succeeded);
    Assert.Contains(LResult.StdOut, 'received-radia-live-input');
  finally
    LCompleted.Free;
  end;
end;

procedure TRadIACliProcessTests.PseudoTerminalRejectsInvalidDimensions;
var
  LTestMethod: TTestLocalMethod;
begin
  LTestMethod :=
    procedure
    begin
      TRadIAPseudoTerminalRunner.Start(
        NewCommandInvocation('echo invalid'),
        0,
        24,
        5000,
        nil,
        nil
      );
    end;
  Assert.WillRaise(LTestMethod, EArgumentOutOfRangeException);
end;

procedure TRadIACliProcessTests.PseudoTerminalStartupCompletes;
var
  LCompleted: TEvent;
  LResult: TRadIACliProcessResult;
begin
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    TRadIAPseudoTerminalRunner.Start(
      NewCommandInvocation('exit'),
      80,
      24,
      5000,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LResult := AResult;
        LCompleted.SetEvent;
      end
    );
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(7000));
    Assert.IsTrue(
      LResult.Succeeded or
      LResult.StdOut.Contains('pseudo-terminal')
    );
  finally
    LCompleted.Free;
  end;
end;

procedure TRadIACliProcessTests.
  PseudoTerminalAvailabilityMatchesRuntimeExports;
begin
  Assert.IsTrue(
    TRadIAPseudoTerminalRunner.IsSupported,
    'The supported Windows runtime must expose ConPTY.'
  );
end;

procedure TRadIACliProcessTests.PseudoTerminalStreamsInputAndResizes;
var
  LCompleted: TEvent;
  LDeadline: UInt64;
  LInputWritten: Boolean;
  LResized: Boolean;
  LResult: TRadIACliProcessResult;
  LSession: IRadIACliProcessSession;
begin
  Assert.IsTrue(
    TRadIAPseudoTerminalRunner.IsSupported,
    'Windows ConPTY is required by the supported runtime.'
  );
  LCompleted := TEvent.Create(nil, True, False, '');
  try
    LSession := TRadIAPseudoTerminalRunner.Start(
      TRadIACliInvocation.Create(
        GetEnvironmentVariable('ComSpec'),
        ['/D', '/Q'],
        GetCurrentDir,
        'text'
      ),
      80,
      24,
      5000,
      nil,
      procedure(AResult: TRadIACliProcessResult)
      begin
        LResult := AResult;
        LCompleted.SetEvent;
      end
    );
    Assert.IsTrue(LSession.IsPseudoTerminal);
    LDeadline := GetTickCount64 + 2000;
    repeat
      LResized := LSession.Resize(100, 30);
      if not LResized then
        Sleep(10);
    until LResized or (GetTickCount64 >= LDeadline);
    if not LResized then
    begin
      LCompleted.WaitFor(1000);
      Assert.Fail(
        'ConPTY resize did not become ready. Output: ' +
          LResult.StdOut
      );
    end;
    LInputWritten := LSession.WriteInput(
      'echo radia-conpty-input' + #13 + 'exit' + #13
    );
    Assert.IsTrue(LInputWritten, 'ConPTY input was not accepted.');
    Assert.AreEqual(wrSignaled, LCompleted.WaitFor(5000));
    Assert.IsTrue(
      LResult.Succeeded,
      Format(
        'ConPTY exited with %d. Output: %s',
        [LResult.ExitCode, LResult.StdOut]
      )
    );
    Assert.Contains(
      LResult.StdOut,
      'radia-conpty-input'
    );
  finally
    LCompleted.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIACliProcessTests);

end.
