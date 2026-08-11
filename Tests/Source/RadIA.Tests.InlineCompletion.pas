unit RadIA.Tests.InlineCompletion;

interface

uses
  DUnitX.TestFramework,
  RadIA.Core.InlineCompletion;

type
  TRadIAInlineCompletionProviderStub = class(
    TInterfacedObject,
    IRadIAInlineCompletionProvider
  )
  private
    FCallCount: Integer;
    FResponse: string;
  public
    function Complete(
      const AContext: TRadIAInlineCompletionContext;
      const ACancellation: IRadIAInlineCompletionCancellationToken
    ): string;
    property CallCount: Integer read FCallCount;
    property Response: string read FResponse write FResponse;
  end;

  TRadIAInlineCompletionViewStub = class(
    TInterfacedObject,
    IRadIAInlineCompletionView
  )
  private
    FApplyAllowed: Boolean;
    FAppliedText: string;
    FClearCount: Integer;
    FAlternativeCount: Integer;
    FSelectedAlternative: Integer;
    FShownText: string;
  public
    function Apply(
      const AContext: TRadIAInlineCompletionContext;
      const AText: string;
      out AUpdatedContext: TRadIAInlineCompletionContext
    ): Boolean;
    procedure Clear;
    procedure Show(
      const AContext: TRadIAInlineCompletionContext;
      const ASuggestion: string
    );
    procedure ShowAlternatives(
      const AContext: TRadIAInlineCompletionContext;
      const AAlternatives: TArray<string>;
      const ASelectedIndex: Integer
    );
    property AlternativeCount: Integer read FAlternativeCount;
    property AppliedText: string read FAppliedText;
    property ApplyAllowed: Boolean read FApplyAllowed write FApplyAllowed;
    property ClearCount: Integer read FClearCount;
    property SelectedAlternative: Integer read FSelectedAlternative;
    property ShownText: string read FShownText;
  end;

  [TestFixture]
  TRadIAInlineCompletionTests = class
  private
    FController: IRadIAInlineCompletionController;
    FProvider: TRadIAInlineCompletionProviderStub;
    FView: TRadIAInlineCompletionViewStub;
    function Context(const ARevision: string):
      TRadIAInlineCompletionContext;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure ShowsSanitizedSuggestion;
    [Test]
    procedure ReusesSuggestionCache;
    [Test]
    procedure AcceptsAllSuggestion;
    [Test]
    procedure AcceptsNextWordAndKeepsRemainder;
    [Test]
    procedure RejectClearsSuggestion;
    [Test]
    procedure AlternativeRequestsCompletionAgain;
    [Test]
    procedure NavigatesCollectedAlternatives;
    [Test]
    procedure InvalidContextDoesNotCallProvider;
    [Test]
    procedure LimitsContextAroundCursor;
    [Test]
    procedure BuildsExplicitFimPrompt;
    [Test]
    procedure PreservesCursorThroughContextLimit;
    [Test]
    procedure PreviewsLocalSuggestionWithoutProvider;
    [Test]
    procedure PreviewsAndSelectsLocalAlternativesWithoutProvider;
    [Test]
    procedure RefusesAcceptanceWhenViewRevisionChanged;
    [Test]
    procedure PolicyAllowsContextOutsideExclusions;
    [Test]
    procedure PolicyExcludesLanguage;
    [Test]
    procedure PolicyExcludesFileAndProjectFragments;
    [Test]
    procedure UpdatesOptionsAtRuntime;
    [Test]
    procedure ShortcutProfileRoundTripsDefaults;
    [Test]
    procedure ShortcutProfileRejectsDuplicateKeys;
    [Test]
    procedure ShortcutProfileRejectsMissingActions;
    [Test]
    procedure BuildsMultilineGhostLayoutWithoutChangingSuggestion;
    [Test]
    procedure ResolvesGhostLinesByRelativeOffset;
    [Test]
    procedure AcceptsMultilineSuggestionExactly;
    [Test]
    procedure AcceptsNextWordAcrossLineBreak;
    [Test]
    procedure BuildsSemanticEditorContext;
    [Test]
    procedure LimitsSemanticImportsAndNearbySymbols;
    [Test]
    procedure HandlesUnitWithoutSymbols;
  end;

implementation

uses
  RadIA.Core.EditorContext,
  RadIA.Core.InlineShortcuts,
  System.SysUtils;

{ TRadIAInlineCompletionProviderStub }

function TRadIAInlineCompletionProviderStub.Complete(
  const AContext: TRadIAInlineCompletionContext;
  const ACancellation: IRadIAInlineCompletionCancellationToken
): string;
begin
  Inc(FCallCount);
  Result := FResponse;
end;

{ TRadIAInlineCompletionViewStub }

function TRadIAInlineCompletionViewStub.Apply(
  const AContext: TRadIAInlineCompletionContext;
  const AText: string;
  out AUpdatedContext: TRadIAInlineCompletionContext
): Boolean;
begin
  if not FApplyAllowed then
    Exit(False);
  FAppliedText := FAppliedText + AText;
  AUpdatedContext := AContext.WithCursor(
    AContext.CursorLine,
    AContext.CursorColumn + Length(AText)
  );
  Result := True;
end;

procedure TRadIAInlineCompletionViewStub.Clear;
begin
  Inc(FClearCount);
  FShownText := '';
end;

procedure TRadIAInlineCompletionViewStub.Show(
  const AContext: TRadIAInlineCompletionContext;
  const ASuggestion: string
);
begin
  FShownText := ASuggestion;
end;

procedure TRadIAInlineCompletionViewStub.ShowAlternatives(
  const AContext: TRadIAInlineCompletionContext;
  const AAlternatives: TArray<string>;
  const ASelectedIndex: Integer
);
begin
  FAlternativeCount := Length(AAlternatives);
  FSelectedAlternative := ASelectedIndex;
  if (ASelectedIndex >= 0) and
    (ASelectedIndex < Length(AAlternatives)) then
    FShownText := AAlternatives[ASelectedIndex]
  else
    FShownText := '';
end;

{ TRadIAInlineCompletionTests }

procedure TRadIAInlineCompletionTests.AcceptsAllSuggestion;
begin
  FController.Request(Context('2'));
  Assert.IsTrue(FController.AcceptAll);
  Assert.AreEqual('WriteLn(''Hello'');', FView.AppliedText);
end;

procedure TRadIAInlineCompletionTests.AcceptsMultilineSuggestionExactly;
const
  CSuggestion = 'if Ready then'#13#10'begin'#13#10'  Run;';
begin
  FProvider.Response := CSuggestion;
  FController.Request(Context('multiline-all'));
  Assert.IsTrue(FController.AcceptAll);
  Assert.AreEqual(CSuggestion, FView.AppliedText);
  Assert.AreEqual('', FView.ShownText);
end;

procedure TRadIAInlineCompletionTests.AcceptsNextWordAndKeepsRemainder;
begin
  FProvider.Response := 'FirstWord secondWord';
  FController.Request(Context('3'));
  Assert.IsTrue(FController.AcceptNextWord);
  Assert.AreEqual('FirstWord ', FView.AppliedText);
  Assert.AreEqual('secondWord', FView.ShownText);
end;

procedure TRadIAInlineCompletionTests.AcceptsNextWordAcrossLineBreak;
begin
  FProvider.Response := 'First'#13#10'Second value';
  FController.Request(Context('multiline-next-word'));
  Assert.IsTrue(FController.AcceptNextWord);
  Assert.AreEqual('First'#13, FView.AppliedText);
  Assert.AreEqual(#10'Second value', FView.ShownText);
  Assert.IsTrue(FController.AcceptNextWord);
  Assert.AreEqual(
    'First'#13#10'Second ',
    FView.AppliedText
  );
  Assert.AreEqual('value', FView.ShownText);
end;

procedure TRadIAInlineCompletionTests.AlternativeRequestsCompletionAgain;
begin
  FController.Request(Context('4'));
  FProvider.Response := 'Alternative';
  FController.RequestAlternative;
  Assert.AreEqual(2, FProvider.CallCount);
  Assert.AreEqual('Alternative', FView.ShownText);
  Assert.AreEqual(2, FView.AlternativeCount);
end;

procedure TRadIAInlineCompletionTests.NavigatesCollectedAlternatives;
begin
  FController.Request(Context('alternatives'));
  FProvider.Response := 'Alternative';
  FController.RequestAlternative;
  Assert.AreEqual(1, FView.SelectedAlternative);
  Assert.IsTrue(FController.SelectPreviousAlternative);
  Assert.AreEqual('WriteLn(''Hello'');', FView.ShownText);
  Assert.AreEqual(0, FView.SelectedAlternative);
  Assert.IsTrue(FController.SelectNextAlternative);
  Assert.AreEqual('Alternative', FView.ShownText);
  Assert.AreEqual(1, FView.SelectedAlternative);
end;

procedure TRadIAInlineCompletionTests.BuildsExplicitFimPrompt;
var
  LPrompt: string;
begin
  LPrompt := TRadIAServiceInlineCompletionProvider.BuildPrompt(
    Context('prompt-revision')
  );
  Assert.Contains(LPrompt, '<PREFIX>');
  Assert.Contains(LPrompt, '<CURSOR>');
  Assert.Contains(LPrompt, '<SUFFIX>');
  Assert.Contains(LPrompt, '<PROJECT_CONTEXT>');
  Assert.Contains(LPrompt, 'Revision: prompt-revision');
end;

procedure TRadIAInlineCompletionTests.
  BuildsMultilineGhostLayoutWithoutChangingSuggestion;
const
  CSuggestion = 'if Ready then'#13#10'begin'#13#10'  Run;'#13#10'end;';
var
  LLines: TArray<TRadIAInlineGhostLine>;
begin
  LLines := TRadIAInlineGhostLayout.Build(CSuggestion);
  Assert.AreEqual<Integer>(4, Length(LLines));
  Assert.AreEqual('if Ready then', LLines[0].Text);
  Assert.AreEqual('begin', LLines[1].Text);
  Assert.AreEqual('  Run;', LLines[2].Text);
  Assert.AreEqual('end;', LLines[3].Text);
  Assert.AreEqual(3, LLines[3].LineOffset);
  Assert.AreEqual(
    CSuggestion,
    string.Join(sLineBreak, [
      LLines[0].Text,
      LLines[1].Text,
      LLines[2].Text,
      LLines[3].Text
    ])
  );
end;

function TRadIAInlineCompletionTests.Context(
  const ARevision: string
): TRadIAInlineCompletionContext;
begin
  Result := TRadIAInlineCompletionContext.Create(
    'C:\Project\Sample.pas',
    'delphi',
    'procedure Demo;'#13#10'begin'#13#10'  ',
    #13#10'end;',
    'Demo',
    'unit Sample;',
    ARevision
  );
end;

procedure TRadIAInlineCompletionTests.InvalidContextDoesNotCallProvider;
var
  LContext: TRadIAInlineCompletionContext;
begin
  LContext := TRadIAInlineCompletionContext.Create(
    '',
    'delphi',
    '',
    '',
    '',
    '',
    ''
  );
  FController.Request(LContext);
  Assert.AreEqual(0, FProvider.CallCount);
end;

procedure TRadIAInlineCompletionTests.LimitsContextAroundCursor;
var
  LContext: TRadIAInlineCompletionContext;
  LLimited: TRadIAInlineCompletionContext;
begin
  LContext := TRadIAInlineCompletionContext.Create(
    'Sample.pas',
    'delphi',
    '0123456789ABCDEFGHIJ',
    'abcdefghijABCDEFGHIJ',
    'Demo',
    'project-context-that-must-be-limited',
    'limit'
  );
  LLimited := LContext.Limited(20);
  Assert.AreEqual('ABCDEFGHIJ', LLimited.Prefix);
  Assert.AreEqual('abcde', LLimited.Suffix);
  Assert.AreEqual(5, Length(LLimited.ProjectContext));
end;

procedure TRadIAInlineCompletionTests.PreservesCursorThroughContextLimit;
var
  LContext: TRadIAInlineCompletionContext;
begin
  LContext := Context('cursor').WithCursor(12, 7).Limited(256);
  Assert.AreEqual(12, LContext.CursorLine);
  Assert.AreEqual(7, LContext.CursorColumn);
end;

procedure TRadIAInlineCompletionTests.PreviewsLocalSuggestionWithoutProvider;
const
  CLocalSuggestion = 'LocalPreview'#13#10'SecondLine';
begin
  FController.Preview(Context('local-preview'), CLocalSuggestion);
  Assert.AreEqual(0, FProvider.CallCount);
  Assert.AreEqual(CLocalSuggestion, FView.ShownText);
  Assert.IsTrue(FController.AcceptAll);
  Assert.AreEqual(CLocalSuggestion, FView.AppliedText);
end;

procedure TRadIAInlineCompletionTests.
  PreviewsAndSelectsLocalAlternativesWithoutProvider;
begin
  FController.PreviewAlternatives(
    Context('local-alternatives'),
    ['First', 'Second', 'Third'],
    1
  );
  Assert.AreEqual(0, FProvider.CallCount);
  Assert.AreEqual(3, FView.AlternativeCount);
  Assert.AreEqual(1, FView.SelectedAlternative);
  Assert.AreEqual('Second', FView.ShownText);
  Assert.IsTrue(FController.AcceptAll);
  Assert.AreEqual('Second', FView.AppliedText);
end;

procedure TRadIAInlineCompletionTests.PolicyAllowsContextOutsideExclusions;
begin
  Assert.IsTrue(
    TRadIAInlineCompletionPolicy.IsAllowed(
      Context('allowed'),
      'sql, markdown',
      'generated;vendor',
      'legacy-project'
    )
  );
end;

procedure TRadIAInlineCompletionTests.PolicyExcludesFileAndProjectFragments;
begin
  Assert.IsFalse(
    TRadIAInlineCompletionPolicy.IsAllowed(
      Context('file'),
      '',
      'sample.pas',
      ''
    )
  );
  Assert.IsFalse(
    TRadIAInlineCompletionPolicy.IsAllowed(
      Context('project'),
      '',
      '',
      'unit sample'
    )
  );
end;

procedure TRadIAInlineCompletionTests.PolicyExcludesLanguage;
begin
  Assert.IsFalse(
    TRadIAInlineCompletionPolicy.IsAllowed(
      Context('language'),
      'markdown; DELPHI',
      '',
      ''
    )
  );
end;

procedure TRadIAInlineCompletionTests.RefusesAcceptanceWhenViewRevisionChanged;
begin
  FController.Request(Context('stale'));
  FView.ApplyAllowed := False;
  Assert.IsFalse(FController.AcceptAll);
  Assert.AreEqual('', FView.AppliedText);
end;

procedure TRadIAInlineCompletionTests.
  ResolvesGhostLinesByRelativeOffset;
var
  LLine: TRadIAInlineGhostLine;
  LLines: TArray<TRadIAInlineGhostLine>;
begin
  LLines := TRadIAInlineGhostLayout.Build(
    'first'#10'second'#10'third'
  );
  Assert.IsTrue(
    TRadIAInlineGhostLayout.TryGetLine(LLines, 1, LLine)
  );
  Assert.AreEqual('second', LLine.Text);
  Assert.IsFalse(
    TRadIAInlineGhostLayout.TryGetLine(LLines, -1, LLine)
  );
  Assert.IsFalse(
    TRadIAInlineGhostLayout.TryGetLine(LLines, 3, LLine)
  );
end;

procedure TRadIAInlineCompletionTests.RejectClearsSuggestion;
begin
  FController.Request(Context('5'));
  FController.Reject;
  Assert.IsFalse(FController.AcceptAll);
  Assert.AreEqual('', FView.ShownText);
  Assert.IsTrue(FView.ClearCount > 0);
end;

procedure TRadIAInlineCompletionTests.ReusesSuggestionCache;
begin
  FController.Request(Context('6'));
  FController.Request(Context('7'));
  Assert.AreEqual(1, FProvider.CallCount);
end;

procedure TRadIAInlineCompletionTests.Setup;
var
  LDispatcher: TRadIAInlineCompletionDispatcher;
  LOptions: TRadIAInlineCompletionOptions;
  LProvider: IRadIAInlineCompletionProvider;
  LRunner: TRadIAInlineCompletionRunner;
  LView: IRadIAInlineCompletionView;
begin
  FProvider := TRadIAInlineCompletionProviderStub.Create;
  FProvider.Response := '```pascal'#10'WriteLn(''Hello'');'#10'end;'#10'```';
  FView := TRadIAInlineCompletionViewStub.Create;
  FView.ApplyAllowed := True;
  LProvider := FProvider;
  LView := FView;
  LOptions := TRadIAInlineCompletionOptions.Create(0, 4096, 512);
  LRunner :=
    procedure(const AAction: TProc)
    begin
      AAction();
    end;
  LDispatcher :=
    procedure(const AAction: TProc)
    begin
      AAction();
    end;
  FController := TRadIAInlineCompletionController.Create(
    LProvider,
    LView,
    LOptions,
    LRunner,
    LDispatcher
  );
end;

procedure TRadIAInlineCompletionTests.ShowsSanitizedSuggestion;
begin
  FController.Request(Context('1'));
  Assert.AreEqual('WriteLn(''Hello'');', FView.ShownText);
end;

procedure TRadIAInlineCompletionTests.ShortcutProfileRejectsDuplicateKeys;
var
  LError: string;
  LProfile: TRadIAInlineShortcutProfile;
begin
  Assert.IsFalse(
    TRadIAInlineShortcutProfile.TryParse(
      'request=Ctrl+Alt+Space; accept=Ctrl+Alt+Space; ' +
      'nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+]; ' +
      'reject=Ctrl+Alt+Backspace',
      LProfile,
      LError
    )
  );
  Assert.Contains(LError, 'unique');
end;

procedure TRadIAInlineCompletionTests.ShortcutProfileRejectsMissingActions;
var
  LError: string;
  LProfile: TRadIAInlineShortcutProfile;
begin
  Assert.IsFalse(
    TRadIAInlineShortcutProfile.TryParse(
      'request=Ctrl+Alt+Space',
      LProfile,
      LError
    )
  );
  Assert.Contains(LError, 'Missing');
end;

procedure TRadIAInlineCompletionTests.ShortcutProfileRoundTripsDefaults;
var
  LError: string;
  LProfile: TRadIAInlineShortcutProfile;
begin
  Assert.IsTrue(
    TRadIAInlineShortcutProfile.TryParse(
      TRadIAInlineShortcutProfile.DefaultText,
      LProfile,
      LError
    ),
    LError
  );
  Assert.AreEqual(
    TRadIAInlineShortcutProfile.DefaultText,
    LProfile.ToText
  );
end;

procedure TRadIAInlineCompletionTests.UpdatesOptionsAtRuntime;
begin
  FController.Configure(
    TRadIAInlineCompletionOptions.Create(0, 4096, 4)
  );
  FProvider.Response := 'LongSuggestion';
  FController.Request(Context('runtime-options'));
  Assert.AreEqual('Long', FView.ShownText);
end;

procedure TRadIAInlineCompletionTests.BuildsSemanticEditorContext;
var
  LContext: TRadIAEditorSemanticContext;
  LSource: string;
begin
  LSource := 'unit Demo.Unit1;' + sLineBreak + sLineBreak +
    'interface' + sLineBreak + sLineBreak +
    'uses' + sLineBreak +
    '  System.SysUtils, Vcl.Forms;' + sLineBreak + sLineBreak +
    'implementation' + sLineBreak + sLineBreak +
    'procedure TDemoForm.Calculate;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak + sLineBreak +
    'end.';
  LContext := TRadIAEditorContextAnalyzer.Analyze(LSource, 12);
  Assert.AreEqual('Demo.Unit1', LContext.UnitName);
  Assert.AreEqual('TDemoForm.Calculate', LContext.CurrentSymbol);
  Assert.AreEqual(2, Integer(Length(LContext.Imports)));
  Assert.Contains(LContext.ToPromptContext, 'System.SysUtils');
  Assert.Contains(LContext.ToPromptContext, 'Calculate');
end;

procedure TRadIAInlineCompletionTests.HandlesUnitWithoutSymbols;
var
  LContext: TRadIAEditorSemanticContext;
begin
  LContext := TRadIAEditorContextAnalyzer.Analyze(
    'unit EmptyUnit;' + sLineBreak + 'interface' + sLineBreak + 'end.',
    2
  );
  Assert.AreEqual('EmptyUnit', LContext.UnitName);
  Assert.AreEqual('', LContext.CurrentSymbol);
  Assert.AreEqual(0, Integer(Length(LContext.NearbySymbols)));
end;

procedure TRadIAInlineCompletionTests.LimitsSemanticImportsAndNearbySymbols;
var
  LContext: TRadIAEditorSemanticContext;
  LSource: string;
begin
  LSource := 'unit LimitedUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'uses UnitA, UnitB, UnitC;' + sLineBreak +
    'procedure First;' + sLineBreak +
    'procedure Second;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure First; begin end;' + sLineBreak +
    'procedure Second; begin end;' + sLineBreak +
    'end.';
  LContext := TRadIAEditorContextAnalyzer.Analyze(LSource, 8, 2, 1);
  Assert.AreEqual(2, Integer(Length(LContext.Imports)));
  Assert.AreEqual(1, Integer(Length(LContext.NearbySymbols)));
end;

procedure TRadIAInlineCompletionTests.TearDown;
begin
  FController := nil;
  FProvider := nil;
  FView := nil;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAInlineCompletionTests);

end.
