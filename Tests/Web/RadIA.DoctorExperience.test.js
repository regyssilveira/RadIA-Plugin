const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const test = require('node:test');

const chat = readFileSync('Source/UI/Web/chat.js', 'utf8');
const health = readFileSync(
  'Source/Core/RadIA.Core.InstallationHealthTools.pas',
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
