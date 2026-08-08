unit RadIA.Tests.AgentExecutors;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TRadIAAgentExecutorTests = class
  public
    [Test]
    procedure MissingSettingsUseNativeExecutor;
    [Test]
    procedure CliSelectionCanBeSavedAndLoaded;
    [Test]
    procedure UnknownCliSelectionIsRejected;
    [Test]
    procedure CorruptedSettingsFallBackToNative;
    [Test]
    procedure CodexInvocationUsesExecJson;
    [Test]
    procedure ClaudeInvocationUsesPrintStreamJson;
    [Test]
    procedure GeminiInvocationUsesPromptStreamJson;
    [Test]
    procedure CopilotInvocationUsesProgrammaticJson;
    [Test]
    procedure CommandLineQuotesPromptWithoutShellExpansion;
    [Test]
    procedure EmptyPromptIsRejected;
    [Test]
    procedure StructuredOutputsReturnLastAssistantText;
    [Test]
    procedure PlainOutputIsPreserved;
    [Test]
    procedure NativeExecutorEnablesProviderModelSelection;
    [Test]
    procedure SupportedCliExecutorsManageTheirOwnModels;
    [Test]
    procedure CapabilityCatalogCoversEveryCli;
    [Test]
    procedure CapabilityCatalogDeclaresStableResumeWithoutFim;
    [Test]
    procedure ScopeIdentityRequiresEveryBoundary;
    [Test]
    procedure ScopeIdentityRejectsCrossProjectJourney;
  end;

implementation

uses
  System.SysUtils,
  RadIA.Core.AgentExecutorContracts,
  RadIA.Core.AgentExecutors,
  RadIA.Core.CliManager,
  RadIA.Core.SettingsStorage;

const
  CSettingsPath = 'Software\RadIA\Tests\AgentExecutor';

function BuildInvocation(
  const AClientId: string;
  const APrompt: string = 'Explain this unit'
): TRadIACliInvocation;
var
  LDefinition: TRadIACliDefinition;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById(AClientId, LDefinition));
  Result := TRadIACliInvocationBuilder.Build(
    LDefinition,
    'C:\Tools\' + AClientId + '.exe',
    APrompt,
    'C:\Project'
  );
end;

procedure TRadIAAgentExecutorTests.CapabilityCatalogCoversEveryCli;
var
  LContract: TRadIAExecutorContract;
  LDefinition: TRadIACliDefinition;
begin
  Assert.AreEqual<Integer>(
    4,
    Length(TRadIAExecutorContractCatalog.All)
  );
  for LDefinition in TRadIACliCatalog.All do
  begin
    Assert.IsTrue(
      TRadIAExecutorContractCatalog.FindByKind(
        LDefinition.Kind,
        LContract
      )
    );
    Assert.AreEqual(LDefinition.Id, LContract.ClientId);
  end;
end;

procedure TRadIAAgentExecutorTests.CapabilityCatalogDeclaresStableResumeWithoutFim;
var
  LContract: TRadIAExecutorContract;
begin
  for LContract in TRadIAExecutorContractCatalog.All do
  begin
    Assert.IsTrue(LContract.Supports(ecStructuredOutput));
    Assert.IsTrue(LContract.Supports(ecStableResume));
    Assert.IsTrue(LContract.Supports(ecSessionIdInOutput));
    Assert.IsTrue(LContract.Supports(ecModelSelection));
    Assert.IsTrue(LContract.Supports(ecMcp));
    Assert.IsFalse(LContract.Supports(ecFim));
    Assert.AreNotEqual(Ord(rsUnsupported), Ord(LContract.ResumeSyntax));
    Assert.AreNotEqual(
      Ord(sisUnavailable),
      Ord(LContract.SessionIdSource)
    );
  end;
end;

procedure TRadIAAgentExecutorTests.ClaudeInvocationUsesPrintStreamJson;
var
  LInvocation: TRadIACliInvocation;
begin
  LInvocation := BuildInvocation('claude');
  Assert.AreEqual('-p', LInvocation.Arguments[0]);
  Assert.AreEqual('--output-format', LInvocation.Arguments[2]);
  Assert.AreEqual('stream-json', LInvocation.Arguments[3]);
end;

procedure TRadIAAgentExecutorTests.CliSelectionCanBeSavedAndLoaded;
var
  LLoaded: TRadIAAgentExecutorSettings;
  LSettings: TRadIAAgentExecutorSettingsStore;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LSettings := TRadIAAgentExecutorSettingsStore.Create(
    LStorage,
    CSettingsPath
  );
  try
    LSettings.Save(TRadIAAgentExecutorSettings.Create(aekCli, 'claude'));
    LLoaded := LSettings.Load;
    Assert.AreEqual(Ord(aekCli), Ord(LLoaded.Kind));
    Assert.AreEqual('claude', LLoaded.CliClientId);
  finally
    LSettings.Free;
  end;
end;

procedure TRadIAAgentExecutorTests.CodexInvocationUsesExecJson;
var
  LInvocation: TRadIACliInvocation;
begin
  LInvocation := BuildInvocation('codex');
  Assert.AreEqual('exec', LInvocation.Arguments[0]);
  Assert.AreEqual('--json', LInvocation.Arguments[1]);
  Assert.AreEqual('Explain this unit', LInvocation.Arguments[2]);
end;

procedure TRadIAAgentExecutorTests.CommandLineQuotesPromptWithoutShellExpansion;
var
  LCommandLine: string;
begin
  LCommandLine := BuildInvocation(
    'codex',
    'Explain "value" and $(unsafe)'
  ).ToCommandLine;
  Assert.Contains(LCommandLine, '"Explain \"value\" and $(unsafe)"');
  Assert.Contains(LCommandLine, 'codex.exe');
end;

procedure TRadIAAgentExecutorTests.CopilotInvocationUsesProgrammaticJson;
var
  LInvocation: TRadIACliInvocation;
begin
  LInvocation := BuildInvocation('copilot');
  Assert.AreEqual('-p', LInvocation.Arguments[0]);
  Assert.AreEqual('--output-format=json', LInvocation.Arguments[2]);
  Assert.AreEqual('--no-color', LInvocation.Arguments[3]);
end;

procedure TRadIAAgentExecutorTests.CorruptedSettingsFallBackToNative;
var
  LLoaded: TRadIAAgentExecutorSettings;
  LSettings: TRadIAAgentExecutorSettingsStore;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  Assert.IsTrue(LStorage.OpenKey(CSettingsPath, True));
  try
    LStorage.WriteInteger('Kind', Ord(aekCli));
    LStorage.WriteString('CliClientId', 'unknown');
  finally
    LStorage.CloseKey;
  end;
  LSettings := TRadIAAgentExecutorSettingsStore.Create(
    LStorage,
    CSettingsPath
  );
  try
    LLoaded := LSettings.Load;
    Assert.AreEqual(Ord(aekNative), Ord(LLoaded.Kind));
    Assert.AreEqual('codex', LLoaded.CliClientId);
  finally
    LSettings.Free;
  end;
end;

procedure TRadIAAgentExecutorTests.EmptyPromptIsRejected;
var
  LDefinition: TRadIACliDefinition;
  LRaised: Boolean;
begin
  Assert.IsTrue(TRadIACliCatalog.FindById('codex', LDefinition));
  LRaised := False;
  try
    TRadIACliInvocationBuilder.Build(
      LDefinition,
      'codex.exe',
      '',
      'C:\Project'
    );
  except
    on EArgumentException do
      LRaised := True;
  end;
  Assert.IsTrue(LRaised, 'An empty prompt must be rejected.');
end;

procedure TRadIAAgentExecutorTests.GeminiInvocationUsesPromptStreamJson;
var
  LInvocation: TRadIACliInvocation;
begin
  LInvocation := BuildInvocation('gemini');
  Assert.AreEqual('-p', LInvocation.Arguments[0]);
  Assert.AreEqual('--output-format', LInvocation.Arguments[2]);
  Assert.AreEqual('stream-json', LInvocation.Arguments[3]);
end;

procedure TRadIAAgentExecutorTests.MissingSettingsUseNativeExecutor;
var
  LLoaded: TRadIAAgentExecutorSettings;
  LSettings: TRadIAAgentExecutorSettingsStore;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LSettings := TRadIAAgentExecutorSettingsStore.Create(
    LStorage,
    CSettingsPath
  );
  try
    LLoaded := LSettings.Load;
    Assert.AreEqual(Ord(aekNative), Ord(LLoaded.Kind));
    Assert.AreEqual('codex', LLoaded.CliClientId);
  finally
    LSettings.Free;
  end;
end;

procedure TRadIAAgentExecutorTests.NativeExecutorEnablesProviderModelSelection;
var
  LState: TRadIAModelSelectionState;
begin
  LState := TRadIAModelSelectionState.FromExecutor(
    TRadIAAgentExecutorSettings.Create(aekNative, 'codex')
  );
  Assert.IsTrue(LState.Enabled);
  Assert.IsEmpty(LState.DisplayText);
end;

procedure TRadIAAgentExecutorTests.PlainOutputIsPreserved;
begin
  Assert.AreEqual(
    'Plain CLI response',
    TRadIACliOutputParser.ExtractFinalText('  Plain CLI response  ')
  );
end;

procedure TRadIAAgentExecutorTests.StructuredOutputsReturnLastAssistantText;
var
  LOutput: string;
begin
  LOutput :=
    '{"type":"item.completed","item":{"type":"agent_message",' +
    '"text":"Codex answer"}}' + sLineBreak +
    '{"type":"result","result":"Final answer"}';
  Assert.AreEqual(
    'Final answer',
    TRadIACliOutputParser.ExtractFinalText(LOutput)
  );
  Assert.AreEqual(
    'Gemini answer',
    TRadIACliOutputParser.ExtractFinalText(
      '{"response":"Gemini answer","stats":{"tokens":12}}'
    )
  );
end;

procedure TRadIAAgentExecutorTests.ScopeIdentityRejectsCrossProjectJourney;
var
  LFirst: TRadIAAgentScopeIdentity;
  LOtherProject: TRadIAAgentScopeIdentity;
  LSameJourney: TRadIAAgentScopeIdentity;
begin
  LFirst := TRadIAAgentScopeIdentity.Create(
    'journey-1',
    'conversation-1',
    'session-1',
    'project-a',
    'request-1'
  );
  LSameJourney := TRadIAAgentScopeIdentity.Create(
    'JOURNEY-1',
    'conversation-1',
    'session-1',
    'PROJECT-A',
    'request-2'
  );
  LOtherProject := TRadIAAgentScopeIdentity.Create(
    'journey-1',
    'conversation-2',
    'session-2',
    'project-b',
    'request-3'
  );
  Assert.IsTrue(LFirst.BelongsToJourney(LSameJourney));
  Assert.IsFalse(LFirst.BelongsToJourney(LOtherProject));
end;

procedure TRadIAAgentExecutorTests.ScopeIdentityRequiresEveryBoundary;
var
  LComplete: TRadIAAgentScopeIdentity;
  LIncomplete: TRadIAAgentScopeIdentity;
begin
  LComplete := TRadIAAgentScopeIdentity.Create(
    'journey-1',
    'conversation-1',
    'session-1',
    'project-1',
    'request-1'
  );
  LIncomplete := TRadIAAgentScopeIdentity.Create(
    'journey-1',
    'conversation-1',
    'session-1',
    'project-1',
    ''
  );
  Assert.IsTrue(LComplete.IsComplete);
  Assert.IsFalse(LIncomplete.IsComplete);
end;

procedure TRadIAAgentExecutorTests.SupportedCliExecutorsManageTheirOwnModels;
const
  CClientIds: array[0..3] of string = (
    'codex',
    'claude',
    'gemini',
    'copilot'
  );
var
  LClientId: string;
  LDefinition: TRadIACliDefinition;
  LState: TRadIAModelSelectionState;
begin
  for LClientId in CClientIds do
  begin
    Assert.IsTrue(TRadIACliCatalog.FindById(LClientId, LDefinition));
    LState := TRadIAModelSelectionState.FromExecutor(
      TRadIAAgentExecutorSettings.Create(aekCli, LClientId)
    );
    Assert.IsFalse(LState.Enabled);
    Assert.AreEqual(
      'Model managed by ' + LDefinition.DisplayName,
      LState.DisplayText
    );
  end;
end;

procedure TRadIAAgentExecutorTests.UnknownCliSelectionIsRejected;
var
  LRaised: Boolean;
  LSettings: TRadIAAgentExecutorSettingsStore;
  LStorage: IRadIASettingsStorage;
begin
  LStorage := TRadIAMemorySettingsStorage.Create;
  LSettings := TRadIAAgentExecutorSettingsStore.Create(
    LStorage,
    CSettingsPath
  );
  try
    LRaised := False;
    try
      LSettings.Save(
        TRadIAAgentExecutorSettings.Create(aekCli, 'unknown')
      );
    except
      on EArgumentException do
        LRaised := True;
    end;
    Assert.IsTrue(LRaised, 'An unknown CLI selection must be rejected.');
  finally
    LSettings.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRadIAAgentExecutorTests);

end.
