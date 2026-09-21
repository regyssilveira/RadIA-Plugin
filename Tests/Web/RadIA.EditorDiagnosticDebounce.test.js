const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');

test('editor diagnostics debounce full unit capture and cancel stale work', () => {
  const hook = fs.readFileSync(
    path.join(repositoryRoot, 'Source', 'Integration', 'RadIA.OTA.EditorHook.pas'),
    'utf8'
  );
  const session = fs.readFileSync(
    path.join(repositoryRoot, 'Source', 'Integration', 'RadIA.OTA.InlineCompletion.pas'),
    'utf8'
  );

  assert.match(session, /function CaptureCursor\(/u);
  assert.match(
    hook,
    /CaptureCursor\([\s\S]*?\.Observe\([\s\S]*?CancelActive[\s\S]*?\.Stop/u
  );
  assert.match(
    hook,
    /Decision <> eddReady[\s\S]*?\.Capture\(LContext\)/u
  );
  assert.match(
    hook,
    /IsAllowed\([\s\S]*?MarkSubmitted\(LRequestKey\)/u
  );
  assert.doesNotMatch(hook, /FInlineCompletionLastKey/u);
});
