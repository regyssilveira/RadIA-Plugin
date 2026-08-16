const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

function read(relativePath) {
  return fs.readFileSync(relativePath, 'utf8');
}

test('chat uses bounded WebView recovery and shutdown-safe callbacks', () => {
  const frame = read('Source/UI/RadIA.UI.ChatFrame.pas');
  const lifecycle = read('Source/Core/RadIA.Core.WebViewLifecycle.pas');
  const dockableForm = read('Source/Integration/RadIA.OTA.DockableForm.pas');
  const registration = read('Source/Integration/RadIA.OTA.Register.pas');
  const chat = read('Source/UI/Web/chat.js');

  assert.match(frame, /TRadIAWebViewLifecycle\.Create\(2\)/u);
  assert.match(frame, /OnProcessFailed := EdgeBrowserProcessFailed/u);
  assert.match(frame, /ScheduleWebViewRecovery/u);
  assert.doesNotMatch(frame, /FEdgeBrowser\.CloseBrowserProcess;/u);
  assert.match(frame, /if FRecoveryQueued or GIsShuttingDown then/u);
  assert.match(frame, /FEdgeBrowser\.OnProcessFailed := nil/u);
  assert.match(frame, /FEdgeBrowser\.ReinitializeWebView;/u);
  assert.match(
    frame,
    /EdgeBrowserProcessFailed\([\s\S]*?COREWEBVIEW2_PROCESS_FAILED_KIND_BROWSER_PROCESS_EXITED/u
  );
  assert.match(chat, /restoreLifecycleState\(state, smoke/u);
  assert.doesNotMatch(frame, /TTask\.Run/u);
  assert.match(frame, /beginLifecycleSmoke\(\)/u);
  assert.match(
    frame,
    /if not GIsShuttingDown then[\s\S]*?DetachEdgeBrowser\(True\);[\s\S]*?FreeAndNil\(FEdgeBrowser\)/u
  );
  assert.match(
    frame,
    /else[\s\S]*?DetachEdgeBrowser\(False\);[\s\S]*?FEdgeBrowser := nil;/u
  );
  assert.match(lifecycle, /FRecoveryAttempts >= FMaximumRecoveryAttempts/u);
  assert.match(lifecycle, /if AShuttingDown/u);
  assert.match(
    dockableForm,
    /destructor TRadIACustomDockableForm\.Destroy;[\s\S]*?DetachNativeForm;/u
  );
  assert.match(dockableForm, /OnShow := FPreviousOnShow;/u);
  assert.match(dockableForm, /OnClose := FPreviousOnClose;/u);
  assert.match(dockableForm, /RemoveFreeNotification\(FObserver\)/u);
  assert.match(
    registration,
    /FApplicationEvents\.OnMessage := OnApplicationMessage;/u
  );
  assert.match(
    registration,
    /RadIA\.OTA\.DockableForm\.PrepareDockableFormsForShutdown;/u
  );
  assert.match(
    dockableForm,
    /procedure PrepareDockableFormsForShutdown;[\s\S]*?ReleaseForm;/u
  );
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
  assert.match(
    read('docs/guides/user_guide_chat_sessions.md'),
    /Encerramento seguro/u
  );
  assert.match(
    read('docs/guides/user_guide_chat_sessions.en.md'),
    /Safe shutdown/u
  );
});
