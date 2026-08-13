const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = fs.readFileSync(
  path.join('Source', 'UI', 'RadIA.UI.ConfigFrame.pas'),
  'utf8'
);

test('orchestration explanation wraps inside the configuration page', () => {
  assert.match(source, /LOrchestrationHint\.AutoSize := False/u);
  assert.match(source, /LOrchestrationHint\.WordWrap := True/u);
  assert.match(source, /LOrchestrationHint\.Width := 430/u);
  assert.match(source, /LOrchestrationHint\.Height := 32/u);
});

test('dynamic CLI and MCP text has bounded non-overlapping layout', () => {
  assert.match(source, /FLblCliSectionTitle\.AutoSize := False/u);
  assert.match(source, /FLblMcpSectionTitle\.AutoSize := False/u);
  assert.match(source, /FLblMcpStatus\.WordWrap := True/u);
  assert.match(source, /FLblMcpStatus\.SetBounds\(16, 418, 590, 40\)/u);
  assert.match(source, /FBtnMcpPreview\.Top := 464/u);
  assert.match(source, /FMemoMcpPreview\.Top := 502/u);
});

test('dynamic provider login caption receives enough button width', () => {
  assert.match(source, /Configure Codex CLI login';\s+btnOpenAIWebLogin\.Width := 190/gu);
});

test('dynamic template origin remains inside the resizable client panel', () => {
  assert.match(source, /FLblTemplateOrigin\.AutoSize := False/u);
  assert.match(source, /FLblTemplateOrigin\.WordWrap := True/u);
  assert.match(source, /FLblTemplateOrigin\.Width := pnlTemplatesClient\.ClientWidth - 28/u);
  assert.match(source, /FLblTemplateOrigin\.Anchors := \[akLeft, akTop, akRight\]/u);
});
