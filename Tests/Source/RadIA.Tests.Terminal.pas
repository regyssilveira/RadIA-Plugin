unit RadIA.Tests.Terminal;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIATerminalTests = class
  private
    FDirectory: string;
    FFileName: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure CatalogProvidesShellProfilesAndSnippets;
    [Test]
    procedure ProfileBuildsInvocationWithCommandAsOneArgument;
    [Test]
    procedure EmptyCommandIsRejected;
    [Test]
    procedure HistoryRoundTripPreservesEntries;
    [Test]
    procedure HistoryEnforcesLimit;
    [Test]
    procedure CorruptedHistoryIsIgnored;
  end;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.SysUtils,
  RadIA.Core.AgentExecutors,
  RadIA.Core.Terminal;

procedure TRadIATerminalTests.CatalogProvidesShellProfilesAndSnippets;
begin
  Assert.AreEqual(2, Length(TRadIATerminalCatalog.Profiles));
  Assert.IsTrue(Length(TRadIATerminalCatalog.Snippets) >= 4);
  Assert.AreEqual(
    'powershell',
    TRadIATerminalCatalog.Profiles[0].Id
  );
end;

procedure TRadIATerminalTests.CorruptedHistoryIsIgnored;
var
  LHistory: TRadIATerminalHistory;
begin
  TFile.WriteAllText(FFileName, '{invalid', TEncoding.UTF8);
  LHistory := TRadIATerminalHistory.Create(FFileName);
  try
    LHistory.Load;
    Assert.AreEqual(0, Length(LHistory.Entries));
  finally
    LHistory.Free;
  end;
end;

procedure TRadIATerminalTests.EmptyCommandIsRejected;
var
  LProfile: TRadIATerminalProfile;
begin
  LProfile := TRadIATerminalCatalog.Profiles[0];
  Assert.WillRaise(
    procedure
    begin
      LProfile.BuildInvocation('', FDirectory);
    end,
    EArgumentException
  );
end;

procedure TRadIATerminalTests.HistoryEnforcesLimit;
var
  LHistory: TRadIATerminalHistory;
begin
  LHistory := TRadIATerminalHistory.Create(FFileName, 2);
  try
    LHistory.Add(
      TRadIATerminalHistoryEntry.Create(Now, 'cmd', 'first', 0)
    );
    LHistory.Add(
      TRadIATerminalHistoryEntry.Create(Now, 'cmd', 'second', 0)
    );
    LHistory.Add(
      TRadIATerminalHistoryEntry.Create(Now, 'cmd', 'third', 0)
    );
    Assert.AreEqual(2, Length(LHistory.Entries));
    Assert.AreEqual('second', LHistory.Entries[0].Command);
  finally
    LHistory.Free;
  end;
end;

procedure TRadIATerminalTests.HistoryRoundTripPreservesEntries;
var
  LHistory: TRadIATerminalHistory;
  LReloaded: TRadIATerminalHistory;
begin
  LHistory := TRadIATerminalHistory.Create(FFileName);
  try
    LHistory.Add(
      TRadIATerminalHistoryEntry.Create(
        EncodeDateTime(2026, 8, 4, 12, 30, 0, 0),
        'powershell',
        'git status',
        7
      )
    );
    LHistory.Save;
  finally
    LHistory.Free;
  end;
  LReloaded := TRadIATerminalHistory.Create(FFileName);
  try
    LReloaded.Load;
    Assert.AreEqual(1, Length(LReloaded.Entries));
    Assert.AreEqual('git status', LReloaded.Entries[0].Command);
    Assert.AreEqual<Cardinal>(7, LReloaded.Entries[0].ExitCode);
  finally
    LReloaded.Free;
  end;
end;

procedure TRadIATerminalTests.ProfileBuildsInvocationWithCommandAsOneArgument;
var
  LInvocation: TRadIACliInvocation;
  LProfile: TRadIATerminalProfile;
begin
  LProfile := TRadIATerminalCatalog.Profiles[0];
  LInvocation := LProfile.BuildInvocation(
    'Write-Output "hello world"',
    FDirectory
  );
  Assert.AreEqual('powershell.exe', LInvocation.ExecutablePath);
  Assert.AreEqual(
    'Write-Output "hello world"',
    LInvocation.Arguments[High(LInvocation.Arguments)]
  );
  Assert.AreEqual(FDirectory, LInvocation.WorkingDirectory);
end;

procedure TRadIATerminalTests.Setup;
begin
  FDirectory := TPath.Combine(
    TPath.GetTempPath,
    'RadIA-Terminal-' + TGUID.NewGuid.ToString
  );
  TDirectory.CreateDirectory(FDirectory);
  FFileName := TPath.Combine(FDirectory, 'history.json');
end;

procedure TRadIATerminalTests.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIATerminalTests);

end.
