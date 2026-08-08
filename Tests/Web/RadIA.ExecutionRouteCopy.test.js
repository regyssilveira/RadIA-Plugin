const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const chatJs = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'Web', 'chat.js'),
  'utf8'
);
const chatHtml = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'Web', 'chat.html'),
  'utf8'
);
const presenter = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ChatPresenter.pas'),
  'utf8'
);
const configFrame = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ConfigFrame.pas'),
  'utf8'
);
const chatCss = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'Web', 'chat.css'),
  'utf8'
);

test('chat exposes the effective route independently from agent mode', () => {
  assert.match(chatHtml, /id="execution-route"/u);
  assert.match(chatHtml, /id="composer-route"/u);
  assert.match(chatHtml, /id="btn-agent-mode"/u);
  assert.match(chatHtml, /id="select-execution-route"/u);
  assert.match(chatHtml, /Send with/u);
  assert.match(chatJs, /function updateExecutionRoute\(route\)/u);
  assert.match(chatJs, /case 'execution_route'/u);
  assert.match(presenter, /function TRadIAChatPresenter\.BuildExecutionRouteJson/u);
  assert.match(presenter, /MCP is a separate external tool bridge/u);
  assert.match(chatJs, /function decorateAssistantRoute/u);
  assert.match(chatJs, /const ROUTE_AVATARS =/u);
  assert.match(chatJs, /native: '<svg/u);
  assert.match(chatJs, /cli: '<svg/u);
  assert.match(chatJs, /mcp: '<svg/u);
  assert.match(chatJs, /avatar\.innerHTML = ROUTE_AVATARS\[avatarKind\]/u);
  assert.match(chatJs, /message-route-marker/u);
  assert.match(chatJs, /message-route-label/u);
  assert.match(chatJs, /function updateComposerRoute/u);
  assert.match(chatJs, /function createResponseTechnicalSummary/u);
  assert.match(chatJs, /response-tool-chip/u);
  assert.match(chatJs, /function updateActiveExecutionStage/u);
  assert.match(chatJs, /RTK saved/u);
  assert.match(chatJs, /action: 'set_agent_executor'/u);
  assert.match(presenter, /procedure TRadIAChatPresenter\.SetAgentExecutor/u);
  assert.match(presenter, /if FAgentModeEnabled then[\s\S]*StartAgentRun\(LProcessed\)/u);
  assert.match(presenter, /if TryStartCliAgentRun\(LProcessed\) then/u);
  assert.match(presenter, /if ASettings\.Kind = aekCli then/u);
  assert.match(presenter, /AOrchestrator := 'external-cli'/u);
  assert.match(presenter, /Exit\('Chat \| ' \+ ACliClientId \+ ' CLI direct'\)/u);
  assert.match(presenter, /ChatGPT Pro via Codex CLI/u);
  assert.match(chatJs, /executionRouteSelector\.disabled = requestInProgress/u);
  assert.match(presenter, /Result\.AddPair\('cliClientId', LCliClientId\)/u);
  assert.doesNotMatch(presenter, /LLabel := 'Agent ·/u);
  assert.match(chatCss, /\.composer-executor-control select option/u);
  assert.match(chatCss, /color: CanvasText/u);
  assert.match(chatCss, /background-color: Canvas/u);
});

test('OpenAI API and ChatGPT Pro routes remain independent', () => {
  assert.match(presenter, /SameText\(AProvider, 'OpenAI'\)/u);
  assert.match(presenter, /SameText\(AAuthType, 'oauth_cli'\)/u);
  assert.match(presenter, /ATransport := 'codex-cli'/u);
  assert.match(presenter, /ChatGPT Pro via Codex CLI/u);
  assert.match(presenter, /GetOAuthAccessToken\(AProviderId\)/u);
  assert.match(presenter, /ADisplayName := 'ChatGPT Pro via Codex CLI'/u);
});

test('all textual response surfaces expose copy actions', () => {
  assert.match(chatJs, /function createTextCopyButton/u);
  assert.match(chatJs, /function appendCopyablePayload/u);
  assert.match(chatJs, /Copy response/u);
  assert.match(chatJs, /Copy tool result/u);
  assert.match(chatJs, /step\.arguments, 'Arguments'/u);
  assert.match(chatJs, /step\.success \? 'Result' : 'Error'/u);
});

test('copy actions use original payloads instead of rendered interface text', () => {
  assert.match(chatJs, /navigator\.clipboard\.writeText\(String\(text \?\? ''\)\)/u);
  assert.match(chatJs, /card\.dataset\.copyText = data\.success/u);
  assert.match(chatJs, /currentAssistantWrapper\.dataset\.copyText = currentAssistantText/u);
});

test('Codex CLI login reflects authentication state and supports logout', () => {
  assert.match(configFrame, /FBtnCliLogin\.Caption := 'Logout'/u);
  assert.match(configFrame, /FBtnCliLogin\.Caption := 'Start login'/u);
  assert.match(configFrame, /LDetection\.ExecutablePath \+ '" logout"'/u);
  assert.match(configFrame, /authentication: ready/u);
  assert.match(configFrame, /The status will refresh automatically after authorization/u);
  assert.doesNotMatch(configFrame, /LParameters := '\/k/u);
});
