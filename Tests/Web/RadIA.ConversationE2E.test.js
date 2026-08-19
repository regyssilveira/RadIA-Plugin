const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const chatScript = fs.readFileSync('Source/UI/Web/chat.js', 'utf8');
const chatFrame = fs.readFileSync('Source/UI/RadIA.UI.ChatFrame.pas', 'utf8');
const presenter = fs.readFileSync(
  'Source/UI/RadIA.UI.ChatPresenter.pas',
  'utf8'
);
const naturalVclRunner = fs.readFileSync(
  'scripts/Test-RadIA.NaturalVclChatE2E.ps1',
  'utf8'
);

test('conversation smoke submits through the real composer path', () => {
  assert.match(chatScript, /globalThis\.beginConversationSmoke/u);
  assert.match(
    chatScript,
    /setPromptText\(conversationSmoke\.promptSubmitted\);[\s\S]*submitPrompt/u
  );
  assert.match(chatScript, /action: 'conversation_smoke_result'/u);
});

test('conversation smoke rejects plans, consent, step limits, and timeout', () => {
  assert.match(chatScript, /planVisible/u);
  assert.match(chatScript, /consentVisible/u);
  assert.match(chatScript, /stepLimitReached/u);
  assert.match(chatScript, /finishConversationSmoke\('failed', 'timeout'\)/u);
  assert.match(chatFrame, /LDuration <= 20000/u);
});

test('deterministic conversation service is restricted to the IDE smoke', () => {
  assert.match(chatFrame, /RADIA_IDE_SMOKE_CONVERSATION/u);
  assert.match(chatFrame, /TRadIAConversationSmokeService/u);
  assert.match(presenter, /RADIA_IDE_SMOKE_CONVERSATION/u);
  assert.match(chatFrame, /'promptContentStored'.*False/u);
  assert.match(chatFrame, /'responseContentStored'.*False/u);
});

test('cancellation smoke cancels and sends a recovery message', () => {
  assert.match(chatScript, /globalThis\.beginCancellationSmoke/u);
  assert.match(chatScript, /btnSendPrompt\.click\(\)/u);
  assert.match(chatScript, /cancellationSmoke\.phase = 'recovery'/u);
  assert.match(chatScript, /action: 'cancellation_smoke_result'/u);
  assert.match(chatFrame, /RADIA_IDE_SMOKE_CANCELLATION/u);
  assert.match(presenter, /RADIA_IDE_SMOKE_CANCELLATION/u);
});

test('chat logging omits raw prompt and response payloads', () => {
  assert.doesNotMatch(presenter, /ProcessWebMessage raw/u);
  assert.match(presenter, /ProcessWebMessage action/u);
  assert.match(presenter, /WebView console message received/u);
  assert.doesNotMatch(
    chatScript,
    /Received message from Delphi:', data\)/u
  );
});

test('provider recovery smoke requires actionable retry without raw errors', () => {
  assert.match(chatScript, /globalThis\.beginProviderRecoverySmoke/u);
  assert.match(chatScript, /action: 'provider_recovery_smoke_result'/u);
  assert.match(chatScript, /actionableErrorVisible/u);
  assert.match(chatScript, /rawExceptionVisible/u);
  assert.match(chatFrame, /RADIA_IDE_SMOKE_PROVIDER_RECOVERY/u);
  assert.match(presenter, /BuildProviderRecoveryMessage/u);
  assert.doesNotMatch(presenter, /error callback: %s/u);
});

test('agent budget smoke uses plan approval and one real read-only tool', () => {
  assert.match(chatScript, /globalThis\.beginAgentBudgetSmoke/u);
  assert.match(chatScript, /continueAgentBudgetSmoke/u);
  assert.match(chatScript, /button\.textContent === 'Approve plan'/u);
  assert.match(chatScript, /step\.toolName === 'GetIDEState'/u);
  assert.match(chatFrame, /RADIA_IDE_SMOKE_AGENT_BUDGET/u);
  assert.match(chatFrame, /agentStepBudgetSmoke/u);
});

test('natural VCL smoke accepts the real route and requires complete evidence', () => {
  assert.match(chatScript, /beginNaturalVclSmoke/u);
  assert.match(chatScript, /resumeNaturalVclSmoke/u);
  assert.match(chatScript, /accept_intent_recommendation/u);
  assert.match(chatScript, /PreviewProjectTemplate/u);
  assert.match(chatScript, /CreateProjectFromTemplate/u);
  assert.match(chatScript, /OpenCreatedProject/u);
  assert.match(chatScript, /BuildProject/u);
  assert.match(chatScript, /applicationStarted: succeeded\('StartDebugging'\)/u);
  assert.match(
    chatScript,
    /const required = \[[\s\S]*?'BuildProject'\s*\];/u
  );
  assert.match(chatFrame, /Project created, inspected, and built\./u);
  assert.match(chatScript, /completed-before-required-evidence/u);
  assert.match(chatScript, /failedTool: failedStep\.toolName/u);
  assert.match(chatScript, /agentMessage: state\.message/u);
  assert.match(chatScript, /state\.recoveryInput === 'destination'/u);
  assert.match(chatScript, /naturalVclSmoke\.recoveryPending/u);
  assert.match(chatScript, /recoveryRequestReady/u);
  assert.match(chatScript, /recoveryStateObserved/u);
  assert.match(chatScript, /pendingApproval/u);
  assert.match(chatScript, /handleJourneyInputRequested/u);
  assert.match(chatScript, /retryObjectiveActive/u);
  assert.match(chatScript, /retryPreviewActive/u);
  assert.match(chatScript, /destinationRetried &&/u);
  assert.match(chatScript, /destinationRecovered/u);
  assert.match(chatScript, /recoveryCardVisible/u);
  assert.match(chatScript, /previousRunFinished/u);
  assert.match(chatScript, /chatContainer\.appendChild\(card\)/u);
  assert.match(chatScript, /requirementsPreserved/u);
  assert.match(chatScript, /nativeOrchestration/u);
  assert.match(chatScript, /CLI task completed\./u);
  assert.match(chatFrame, /RADIA_IDE_SMOKE_NATURAL_VCL_RETRY_DESTINATION/u);
  assert.match(presenter, /journey_input_requested/u);
  assert.match(presenter, /New destination received\. Preparing the recovered project plan\./u);
  assert.match(presenter, /FActiveJourneyContext := LContext/u);
  assert.match(presenter, /FActiveJourneyDefinition := LDefinition/u);
  assert.match(presenter, /FActiveJourneyNative := True/u);
  assert.match(naturalVclRunner, /New-Item -ItemType File/u);
  assert.match(naturalVclRunner, /existing\.txt/u);
  assert.match(presenter, /not AObjective\.Contains/u);
  assert.match(presenter, /Create a Delphi project from the user requirements\./u);
  assert.ok(
    presenter.indexOf('FNativeOrchestrationOverride :=') <
      presenter.indexOf('if TryStartExternalAgentRun(AObjective')
  );
});

test('session isolation smoke rejects a pending action after chat switch', () => {
  assert.match(chatScript, /beginSessionIsolationSmoke/u);
  assert.match(chatScript, /session_isolation_smoke_result/u);
  assert.match(chatScript, /action: 'new_session'/u);
  assert.match(chatScript, /action: 'accept_intent_recommendation'/u);
  assert.match(chatScript, /pendingActionRejected/u);
  assert.match(chatFrame, /RADIA_IDE_SMOKE_SESSION_ISOLATION/u);
});
