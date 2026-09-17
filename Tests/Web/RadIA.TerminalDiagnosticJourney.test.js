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

test('terminal direct input and dropped files remain scoped and reviewable', () => {
  const frame = read('Source/UI/RadIA.UI.TerminalFrame.pas');
  const terminal = read('Source/Core/RadIA.Core.Terminal.pas');

  assert.match(frame, /FDirectInputButton\.Caption := 'Direct input'/);
  assert.match(frame, /FindControl\(GetFocus\) <> FDirectInputButton/);
  assert.match(frame, /DragAcceptFiles\(Handle, True\)/);
  assert.match(frame, /'Send the dropped path or paths to the active terminal\?'/);
  assert.match(frame, /FSession\.WriteInput\(FScreen\.PreparePaste\(LFormattedPaths\)\)/);
  assert.doesNotMatch(frame, /PreparePaste\(LFormattedPaths \+ #13\)/);
  assert.match(terminal, /Result := Result \+ '"' \+ LPath \+ '"'/);
});

test('terminal metrics exclude command, path, key, and screen payload fields', () => {
  const frame = read('Source/UI/RadIA.UI.TerminalFrame.pas');
  const screen = read('Source/Core/RadIA.Core.TerminalScreen.pas');
  const metricFields = [
    'directInputUsed',
    'droppedItemCount',
    'temporaryImageCount',
    'resizeCount',
    'unrecognizedSequenceCount'
  ];

  metricFields.forEach(field => assert.match(`${frame}\n${screen}`, new RegExp(field)));
  ['commandText', 'screenContent', 'filePath', 'keyText']
    .forEach(field => assert.doesNotMatch(`${frame}\n${screen}`, new RegExp(`'${field}'`)));
});
