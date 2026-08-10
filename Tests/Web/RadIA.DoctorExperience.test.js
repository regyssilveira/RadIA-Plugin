const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const test = require('node:test');

const chat = readFileSync('Source/UI/Web/chat.js', 'utf8');
const health = readFileSync(
  'Source/Core/RadIA.Core.InstallationHealthTools.pas',
  'utf8'
);
const presenter = readFileSync(
  'Source/UI/RadIA.UI.ChatPresenter.pas',
  'utf8'
);

test('doctor renders readiness checks and the effective execution route', () => {
  assert.match(chat, /function renderInstallationHealth/u);
  assert.match(
    chat,
    /GetInstallationHealth:\s*\[renderInstallationHealth/u
  );
  assert.match(chat, /result\.effectiveRoute/u);
  assert.match(chat, /result\.checkDetails/u);
  assert.match(chat, /doctorActionCommand\(result\.nextAction\)/u);
});

test('doctor distinguishes provider transport, CLI, and MCP requirements', () => {
  assert.match(health, /'diagnosticVersion', '2\.0'/u);
  assert.match(health, /'profile', 'full-local'/u);
  assert.match(health, /'providerTransport'/u);
  assert.match(health, /'cliRequired'/u);
  assert.match(health, /'mcpRequired'/u);
  assert.match(health, /'nonGitWorkspaceSupported'/u);
});

test('deep doctor is consented and renders active CLI and MCP checks', () => {
  assert.match(health, /RunInstallationDeepDiagnostic/u);
  assert.match(health, /\.WithConsentEveryTime/u);
  assert.match(health, /'profile', 'deep-active'/u);
  assert.match(health, /AuthStatusArguments/u);
  assert.match(health, /TestServer\(LServer/u);
  assert.match(chat, /result\.activeChecks/u);
  assert.match(
    chat,
    /RunInstallationDeepDiagnostic:\s*\[renderInstallationHealth/u
  );
});

test('deep doctor rejects an outdated Codex transport for current models', () => {
  assert.match(health, /VersionMeetsMinimum\(LVersion, '0\.144\.4'\)/u);
  assert.match(health, /LActiveModel\.StartsWith\('gpt-5\.6-'/u);
  assert.match(health, /'nextAction', 'configure_cli'/u);
  assert.match(health, /run Diagnose and refresh the model list/u);
});

test('chat preflight directs clean machines without making npm mandatory', () => {
  assert.match(presenter, /function CheckChatPreflight/u);
  assert.match(presenter, /function CheckRequiredCli/u);
  assert.match(presenter, /You do not need npm to use RadIA/u);
  assert.match(presenter, /portable[\s\S]*Browse/u);
  assert.match(presenter, /Your message was not sent/u);
  assert.match(chat, /function renderChatPreflight/u);
  assert.match(chat, /textContent = 'Open Settings'/u);
  assert.match(chat, /textContent = 'Run \/doctor'/u);
  assert.match(chat, /setPromptText\(data\.pendingPrompt\)/u);
});
