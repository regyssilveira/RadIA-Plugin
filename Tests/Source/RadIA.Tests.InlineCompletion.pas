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
    property AppliedText: string read FAppliedText;
    property ApplyAllowed: Boolean read FApplyAllowed write FApplyAllowed;
    property ClearCount: Integer read FClearCount;
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
    procedure InvalidContextDoesNotCallProvider;
    [Test]
    procedure LimitsContextAroundCursor;
    [Test]
    procedure BuildsExplicitFimPrompt;
    [Test]
    procedure PreservesCursorThroughContextLimit;
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
  end;

implementation

uses
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

{ TRadIAInlineCompletionTests }

procedure TRadIAInlineCompletionTests.AcceptsAllSuggestion;
begin
  FController.Request(Context('2'));
  Assert.IsTrue(FController.AcceptAll);
  Assert.AreEqual('WriteLn(''Hello'');', FView.AppliedText);
end;

procedure TRadIAInlineCompletionTests.AcceptsNextWordAndKeepsRemainder;
begin
  FProvider.Response := 'FirstWord secondWord';
  FController.Request(Context('3'));
  Assert.IsTrue(FController.AcceptNextWord);
  Assert.AreEqual('FirstWord ', FView.AppliedText);
  Assert.AreEqual('secondWord', FView.ShownText);
end;

procedure TRadIAInlineCompletionTests.AlternativeRequestsCompletionAgain;
begin
  FController.Request(Context('4'));
  FProvider.Response := 'Alternative';
  FController.RequestAlternative;
  Assert.AreEqual(2, FProvider.CallCount);
  Assert.AreEqual('Alternative', FView.ShownText);
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

procedure TRadIAInlineCompletionTests.UpdatesOptionsAtRuntime;
begin
  FController.Configure(
    TRadIAInlineCompletionOptions.Create(0, 4096, 4)
  );
  FProvider.Response := 'LongSuggestion';
  FController.Request(Context('runtime-options'));
  Assert.AreEqual('Long', FView.ShownText);
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
