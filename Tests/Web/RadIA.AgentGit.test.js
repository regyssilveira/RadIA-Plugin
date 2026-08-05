const assert = require('node:assert/strict');
const test = require('node:test');
const agentGit = require('../../Source/UI/Web/RadIA.UI.AgentGit.js');

test('summarizeDiff classifies headers, additions, and removals', () => {
  const diff = [
    'diff --git a/Source/Unit1.pas b/Source/Unit1.pas',
    'index 1111111..2222222 100644',
    '--- a/Source/Unit1.pas',
    '+++ b/Source/Unit1.pas',
    '@@ -1,3 +1,3 @@',
    ' begin',
    '-  OldCall;',
    '+  NewCall;',
    ' end'
  ].join('\n');

  const summary = agentGit.summarizeDiff(diff);

  assert.deepEqual(summary.files, ['Source/Unit1.pas']);
  assert.equal(summary.additions, 1);
  assert.equal(summary.removals, 1);
  assert.equal(summary.tokens[0].kind, 'header');
  assert.equal(summary.tokens[6].kind, 'removal');
  assert.equal(summary.tokens[7].kind, 'addition');
});

test('summarizeDiff supports multiple files and Windows line endings', () => {
  const diff = [
    'diff --git a/One.pas b/One.pas',
    '--- a/One.pas',
    '+++ b/One.pas',
    '+one',
    'diff --git a/Two.pas b/Two.pas',
    '--- a/Two.pas',
    '+++ b/Two.pas',
    '-two'
  ].join('\r\n');

  const summary = agentGit.summarizeDiff(diff);

  assert.deepEqual(summary.files, ['One.pas', 'Two.pas']);
  assert.equal(summary.additions, 1);
  assert.equal(summary.removals, 1);
});
