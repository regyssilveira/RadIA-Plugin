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
  end;

implementation

uses
  System.SyncObjs,
  System.SysUtils,
  Winapi.Windows,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliProcess;

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

initialization
  TDUnitX.RegisterTestFixture(TRadIACliProcessTests);

end.
