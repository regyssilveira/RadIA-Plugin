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
    procedure HistoryFindsPreviousMatchingCommands;
    [Test]
    procedure CorruptedHistoryIsIgnored;
    [Test]
    procedure AnsiParserPreservesStyleAcrossChunks;
    [Test]
    procedure AnsiParserHandlesSplitEscapeSequence;
    [Test]
    procedure AnsiParserResetsStyleAndIgnoresCursorCommand;
    [Test]
    procedure ScreenOverwritesProgressWithCarriageReturn;
    [Test]
    procedure ScreenAppliesCursorMovementAndEraseLine;
    [Test]
    procedure ScreenPreservesStyleAcrossFragmentedCsi;
    [Test]
    procedure ScreenSuppressesOscWindowTitles;
    [Test]
    procedure ScreenResizesAndRejectsInvalidWidth;
    [Test]
    procedure TerminalFrameCreatesAndDestroysWithoutResourceFailure;
    [Test]
    procedure HiddenDockHostDoesNotFocusTerminalDuringEmbedding;
    [Test]
    procedure TerminalTabsCreateAndCloseIndependentSessions;
    [Test]
    procedure TerminalControlsExposeAccessibleLabels;
    [Test]
    procedure TerminalShortcutIsConfigurableAndBackwardCompatible;
  end;

implementation

uses
  System.DateUtils,
  System.IOUtils,
  System.SysUtils,
  Vcl.Menus,
  Vcl.Forms,
  RadIA.Core.AgentExecutors,
  RadIA.Core.InlineShortcuts,
  RadIA.Core.Terminal,
  RadIA.Core.TerminalScreen,
  RadIA.UI.TerminalFrame;

function SegmentsText(
  const ASegments: TArray<TRadIATerminalTextSegment>
): string;
var
  LSegment: TRadIATerminalTextSegment;
begin
  Result := '';
  for LSegment in ASegments do
    Result := Result + LSegment.Text;
end;

procedure TRadIATerminalTests.AnsiParserHandlesSplitEscapeSequence;
var
  LParser: TRadIATerminalAnsiParser;
  LSegments: TArray<TRadIATerminalTextSegment>;
begin
  LParser := TRadIATerminalAnsiParser.Create;
  try
    LSegments := LParser.Feed(#27'[9');
    Assert.AreEqual<Integer>(0, Length(LSegments));
    LSegments := LParser.Feed('2mgreen');
    Assert.AreEqual<Integer>(1, Length(LSegments));
    Assert.AreEqual('green', LSegments[0].Text);
    Assert.AreEqual(
      tcBrightGreen,
      LSegments[0].Style.Foreground
    );
  finally
    LParser.Free;
  end;
end;

procedure TRadIATerminalTests.AnsiParserPreservesStyleAcrossChunks;
var
  LParser: TRadIATerminalAnsiParser;
  LSegments: TArray<TRadIATerminalTextSegment>;
begin
  LParser := TRadIATerminalAnsiParser.Create;
  try
    LSegments := LParser.Feed(#27'[1;31merror');
    Assert.AreEqual<Integer>(1, Length(LSegments));
    Assert.AreEqual(tcRed, LSegments[0].Style.Foreground);
    Assert.IsTrue(LSegments[0].Style.Bold);
    LSegments := LParser.Feed(' continued');
    Assert.AreEqual(' continued', LSegments[0].Text);
    Assert.AreEqual(tcRed, LSegments[0].Style.Foreground);
  finally
    LParser.Free;
  end;
end;

procedure TRadIATerminalTests.AnsiParserResetsStyleAndIgnoresCursorCommand;
var
  LParser: TRadIATerminalAnsiParser;
  LSegments: TArray<TRadIATerminalTextSegment>;
begin
  LParser := TRadIATerminalAnsiParser.Create;
  try
    LSegments := LParser.Feed(
      #27'[34mblue'#27'[0m default'#27'[2Kdone'
    );
    Assert.AreEqual<Integer>(2, Length(LSegments));
    Assert.AreEqual(tcBlue, LSegments[0].Style.Foreground);
    Assert.AreEqual(' defaultdone', LSegments[1].Text);
    Assert.AreEqual(tcDefault, LSegments[1].Style.Foreground);
  finally
    LParser.Free;
  end;
end;

procedure TRadIATerminalTests.CatalogProvidesShellProfilesAndSnippets;
begin
  Assert.AreEqual<Integer>(
    2,
    Length(TRadIATerminalCatalog.Profiles)
  );
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
    Assert.AreEqual<Integer>(0, Length(LHistory.Entries));
  finally
    LHistory.Free;
  end;
end;

procedure TRadIATerminalTests.EmptyCommandIsRejected;
var
  LInvocation: TRadIACliInvocation;
  LProfile: TRadIATerminalProfile;
  LTestMethod: TTestLocalMethod;
begin
  LInvocation := Default(TRadIACliInvocation);
  LProfile := TRadIATerminalCatalog.Profiles[0];
  LTestMethod :=
    procedure
    begin
      LInvocation := LProfile.BuildInvocation('', FDirectory);
    end;
  Assert.WillRaise(LTestMethod, EArgumentException);
  Assert.AreEqual('', LInvocation.ExecutablePath);
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
    Assert.AreEqual<Integer>(2, Length(LHistory.Entries));
    Assert.AreEqual('second', LHistory.Entries[0].Command);
  finally
    LHistory.Free;
  end;
end;

procedure TRadIATerminalTests.HistoryFindsPreviousMatchingCommands;
var
  LCommand: string;
  LHistory: TRadIATerminalHistory;
  LNextIndex: Integer;
begin
  LHistory := TRadIATerminalHistory.Create(FFileName);
  try
    LHistory.Add(
      TRadIATerminalHistoryEntry.Create(Now, 'cmd', 'git status', 0)
    );
    LHistory.Add(
      TRadIATerminalHistoryEntry.Create(Now, 'cmd', 'build project', 0)
    );
    LHistory.Add(
      TRadIATerminalHistoryEntry.Create(Now, 'cmd', 'git diff', 0)
    );

    Assert.IsTrue(
      LHistory.FindPrevious('GIT', -1, LCommand, LNextIndex)
    );
    Assert.AreEqual('git diff', LCommand);
    Assert.IsTrue(
      LHistory.FindPrevious('git', LNextIndex, LCommand, LNextIndex)
    );
    Assert.AreEqual('git status', LCommand);
    Assert.IsFalse(
      LHistory.FindPrevious('missing', -1, LCommand, LNextIndex)
    );
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
    Assert.AreEqual<Integer>(1, Length(LReloaded.Entries));
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

procedure TRadIATerminalTests.ScreenAppliesCursorMovementAndEraseLine;
var
  LScreen: TRadIATerminalScreen;
begin
  LScreen := TRadIATerminalScreen.Create(40);
  try
    LScreen.Feed('first' + sLineBreak + 'second');
    LScreen.Feed(#27'[1A'#13#27'[2Kreplacement');
    Assert.AreEqual(
      'replacement' + sLineBreak + 'second',
      SegmentsText(LScreen.RenderSegments)
    );
  finally
    LScreen.Free;
  end;
end;

procedure TRadIATerminalTests.ScreenOverwritesProgressWithCarriageReturn;
var
  LScreen: TRadIATerminalScreen;
begin
  LScreen := TRadIATerminalScreen.Create(40);
  try
    LScreen.Feed('progress 10%'#13'progress 90%'#27'[K');
    Assert.AreEqual(
      'progress 90%',
      SegmentsText(LScreen.RenderSegments)
    );
    Assert.AreEqual<Integer>(12, LScreen.CursorColumn);
  finally
    LScreen.Free;
  end;
end;

procedure TRadIATerminalTests.ScreenPreservesStyleAcrossFragmentedCsi;
var
  LScreen: TRadIATerminalScreen;
  LSegments: TArray<TRadIATerminalTextSegment>;
begin
  LScreen := TRadIATerminalScreen.Create(40);
  try
    LScreen.Feed(#27'[1;3');
    LScreen.Feed('1mred'#27'[0m plain');
    LSegments := LScreen.RenderSegments;
    Assert.AreEqual<Integer>(2, Length(LSegments));
    Assert.AreEqual('red', LSegments[0].Text);
    Assert.AreEqual(tcRed, LSegments[0].Style.Foreground);
    Assert.IsTrue(LSegments[0].Style.Bold);
    Assert.AreEqual(' plain', LSegments[1].Text);
    Assert.AreEqual(tcDefault, LSegments[1].Style.Foreground);
  finally
    LScreen.Free;
  end;
end;

procedure TRadIATerminalTests.ScreenResizesAndRejectsInvalidWidth;
var
  LScreen: TRadIATerminalScreen;
  LTestMethod: TTestLocalMethod;
begin
  LScreen := TRadIATerminalScreen.Create(40);
  try
    LScreen.Feed('content');
    LScreen.Resize(80);
    Assert.AreEqual<Integer>(80, LScreen.Columns);
    Assert.AreEqual('content', SegmentsText(LScreen.RenderSegments));
    LTestMethod :=
      procedure
      begin
        LScreen.Resize(10);
      end;
    Assert.WillRaise(LTestMethod, EArgumentOutOfRangeException);
  finally
    LScreen.Free;
  end;
end;

procedure TRadIATerminalTests.ScreenSuppressesOscWindowTitles;
var
  LScreen: TRadIATerminalScreen;
begin
  LScreen := TRadIATerminalScreen.Create(40);
  try
    LScreen.Feed('before'#27']0;hidden title');
    LScreen.Feed(#7'after');
    Assert.AreEqual(
      'beforeafter',
      SegmentsText(LScreen.RenderSegments)
    );
    LScreen.Clear;
    LScreen.Feed(#27']2;hidden'#27'\visible');
    Assert.AreEqual(
      'visible',
      SegmentsText(LScreen.RenderSegments)
    );
  finally
    LScreen.Free;
  end;
end;

procedure TRadIATerminalTests.TearDown;
begin
  if TDirectory.Exists(FDirectory) then
    TDirectory.Delete(FDirectory, True);
end;

procedure TRadIATerminalTests.
  HiddenDockHostDoesNotFocusTerminalDuringEmbedding;
var
  LFrame: TRadIATerminalTabsFrame;
  LHost: TForm;
begin
  LHost := TForm.CreateNew(nil);
  try
    LFrame := TRadIATerminalTabsFrame.Create(LHost);
    try
      LFrame.Parent := LHost;
      LFrame.HandleNeeded;
      LFrame.EnsureVisibleContent;
      Assert.IsFalse(LHost.Showing);
      Assert.AreEqual<Integer>(1, LFrame.TestSessionCount);
    finally
      LFrame.Free;
    end;
  finally
    LHost.Free;
  end;
end;

procedure TRadIATerminalTests.
  TerminalFrameCreatesAndDestroysWithoutResourceFailure;
var
  LFrame: TRadIATerminalFrame;
  LHost: TForm;
begin
  LHost := TForm.CreateNew(nil);
  try
    LHost.Show;
    LFrame := TRadIATerminalFrame.Create(LHost);
    try
      LFrame.Parent := LHost;
      Assert.IsTrue(LFrame.HandleAllocated);
    finally
      LFrame.Free;
    end;
  finally
    LHost.Free;
  end;
end;

procedure TRadIATerminalTests.
  TerminalTabsCreateAndCloseIndependentSessions;
var
  LFrame: TRadIATerminalTabsFrame;
  LFirstSession: TObject;
  LHost: TForm;
begin
  LHost := TForm.CreateNew(nil);
  try
    LHost.Show;
    LFrame := TRadIATerminalTabsFrame.Create(LHost);
    try
      LFrame.Parent := LHost;
      Assert.AreEqual<Integer>(1, LFrame.TestSessionCount);
      LFirstSession := LFrame.TestActiveSession;
      Assert.IsNotNull(LFirstSession);
      LFrame.TestAddSession;
      Assert.AreEqual<Integer>(2, LFrame.TestSessionCount);
      Assert.IsFalse(LFirstSession = LFrame.TestActiveSession);
      LFrame.TestCloseSession;
      Assert.AreEqual<Integer>(1, LFrame.TestSessionCount);
      LFrame.TestCloseSession;
      Assert.AreEqual<Integer>(1, LFrame.TestSessionCount);
    finally
      LFrame.Free;
    end;
  finally
    LHost.Free;
  end;
end;

procedure TRadIATerminalTests.TerminalControlsExposeAccessibleLabels;
var
  LFrame: TRadIATerminalTabsFrame;
  LHost: TForm;
begin
  LHost := TForm.CreateNew(nil);
  try
    LHost.Show;
    LFrame := TRadIATerminalTabsFrame.Create(LHost);
    try
      LFrame.Parent := LHost;
      Assert.IsTrue(LFrame.TestAccessibilityReady);
    finally
      LFrame.Free;
    end;
  finally
    LHost.Free;
  end;
end;

procedure TRadIATerminalTests.
  TerminalShortcutIsConfigurableAndBackwardCompatible;
var
  LError: string;
  LProfile: TRadIAInlineShortcutProfile;
begin
  Assert.IsTrue(
    TRadIAInlineShortcutProfile.TryParse(
      'request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right; ' +
      'nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+]; ' +
      'reject=Ctrl+Alt+Backspace',
      LProfile,
      LError
    ),
    LError
  );
  Assert.AreEqual<Integer>(
    Integer(TextToShortCut('Ctrl+Alt+T')),
    Integer(LProfile.ShortcutFor(isaTerminal))
  );
  Assert.IsTrue(
    TRadIAInlineShortcutProfile.TryParse(
      'request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right; ' +
      'nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+]; ' +
      'reject=Ctrl+Alt+Backspace; terminal=Ctrl+Shift+T',
      LProfile,
      LError
    ),
    LError
  );
  Assert.AreEqual<Integer>(
    Integer(TextToShortCut('Ctrl+Shift+T')),
    Integer(LProfile.ShortcutFor(isaTerminal))
  );
  Assert.IsFalse(
    TRadIAInlineShortcutProfile.TryParse(
      'request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right; ' +
      'nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+]; ' +
      'reject=Ctrl+Alt+Backspace; terminal=Ctrl+Alt+Space',
      LProfile,
      LError
    )
  );
  Assert.Contains(LError, 'must be unique');
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIATerminalTests);

end.
