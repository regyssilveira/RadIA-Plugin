const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

function read(relativePath) {
  return fs.readFileSync(relativePath, 'utf8');
}

test('chat uses bounded WebView recovery and shutdown-safe callbacks', () => {
  const frame = read('Source/UI/RadIA.UI.ChatFrame.pas');
  const lifecycle = read('Source/Core/RadIA.Core.WebViewLifecycle.pas');

  assert.match(frame, /TRadIAWebViewLifecycle\.Create\(2\)/u);
  assert.match(frame, /OnProcessFailed := EdgeBrowserProcessFailed/u);
  assert.match(frame, /ScheduleWebViewRecovery/u);
  assert.match(frame, /if FRecoveryQueued or GIsShuttingDown then/u);
  assert.match(frame, /FEdgeBrowser\.OnProcessFailed := nil/u);
  assert.match(lifecycle, /FRecoveryAttempts >= FMaximumRecoveryAttempts/u);
  assert.match(lifecycle, /if AShuttingDown/u);
});

test('chat preserves only bounded in-memory composer state across recovery', () => {
  const frame = read('Source/UI/RadIA.UI.ChatFrame.pas');
  const chat = read('Source/UI/Web/chat.js');

  assert.match(frame, /CMaximumDraftLength = 12000/u);
  assert.match(frame, /CMaximumScrollTop = 10000000/u);
  assert.match(frame, /restore_lifecycle_state/u);
  assert.match(chat, /action: 'webview_lifecycle_state'/u);
  assert.match(chat, /String\(promptTextarea\?\.value \|\| ''\)\.slice\(0, 12000\)/u);
  assert.match(chat, /case 'restore_lifecycle_state'/u);
  assert.doesNotMatch(chat, /(?:localStorage|sessionStorage)/u);
});

test('user guides explain automatic recovery and its in-memory boundary', () => {
  for (const guide of [
    'docs/guides/user_guide_chat_sessions.md',
    'docs/guides/user_guide_chat_sessions.en.md',
    'docs/guides/troubleshooting_agentic_platform.md',
    'docs/guides/troubleshooting_agentic_platform.en.md'
  ]) {
    const content = read(guide);
    assert.match(content, /WebView2/u);
    assert.match(content, /mem[oó]r(?:ia|y)/iu);
  }
});
