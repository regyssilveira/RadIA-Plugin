const fs = require('node:fs');
const test = require('node:test');
const assert = require('node:assert/strict');

function read(relativePath) {
  return fs.readFileSync(relativePath, 'utf8');
}

test('terminal exposes bounded Delphi diagnostic navigation and chat handoff', () => {
  const frame = read('Source/UI/RadIA.UI.TerminalFrame.pas');
  const parser = read('Source/Core/RadIA.Core.TerminalDiagnostics.pas');

  assert.match(frame, /FOpenDiagnosticButton\.Caption := 'Open error'/);
  assert.match(frame, /FSendDiagnosticButton\.Caption := 'Send to chat'/);
  assert.match(frame, /FNavigation\.NavigateToFile/);
  assert.match(frame, /LDiagnostic\.ToChatPrompt\(FRedactor\)/);
  assert.match(parser, /CMaximumInputLength = 4096/);
  assert.match(parser, /CMaximumMessageLength = 512/);
  assert.match(parser, /IsSupportedFile/);
  assert.match(parser, /ARedactor\.Redact\(LPrompt\)/);
});

test('terminal guides document error navigation and sanitized chat handoff', () => {
  for (const guide of [
    'docs/guides/terminal.md',
    'docs/guides/terminal.en.md'
  ]) {
    const content = read(guide);
    assert.match(content, /Open error/);
    assert.match(content, /Send to chat/);
    assert.match(content, /\.pas/);
    assert.match(content, /13/);
  }
});
