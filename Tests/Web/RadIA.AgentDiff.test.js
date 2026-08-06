const assert = require('node:assert/strict');
const test = require('node:test');
const agentDiff = require('../../Source/UI/Web/RadIA.UI.AgentDiff.js');

test('buildHunk returns only the changed block and surrounding context', () => {
  const original = [
    'line 1',
    'line 2',
    'line 3',
    'old line',
    'line 5',
    'line 6',
    'line 7',
    'line 8'
  ].join('\n');
  const proposed = original.replace('old line', 'new line');

  const hunk = agentDiff.buildHunk(original, proposed, 1);

  assert.equal(hunk.original, ['line 3', 'old line', 'line 5'].join('\n'));
  assert.equal(hunk.proposed, ['line 3', 'new line', 'line 5'].join('\n'));
  assert.equal(hunk.originalStartLine, 3);
  assert.equal(hunk.originalChangedLines, 1);
  assert.equal(hunk.proposedChangedLines, 1);
});

test('buildHunk reports inserted and removed line counts', () => {
  const inserted = agentDiff.buildHunk('begin\nend', 'begin\n  Run;\nend');
  assert.equal(inserted.originalChangedLines, 0);
  assert.equal(inserted.proposedChangedLines, 1);

  const removed = agentDiff.buildHunk('begin\n  Run;\nend', 'begin\nend');
  assert.equal(removed.originalChangedLines, 1);
  assert.equal(removed.proposedChangedLines, 0);
});

test('buildHunk accepts Windows line endings', () => {
  const hunk = agentDiff.buildHunk('one\r\ntwo\r\nthree', 'one\r\nchanged\r\nthree');

  assert.equal(hunk.originalChangedLines, 1);
  assert.equal(hunk.proposedChangedLines, 1);
  assert.match(hunk.original, /two/);
  assert.match(hunk.proposed, /changed/);
});

test('extractFiles recognizes simple and multi-file patch results', () => {
  const first = {
    targetFile: 'Source/One.pas',
    originalContent: 'old one',
    proposedContent: 'new one'
  };
  const second = {
    targetFile: 'Source/Two.pas',
    originalContent: 'old two',
    proposedContent: 'new two'
  };

  assert.deepEqual(agentDiff.extractFiles('PreparePatch', first), [first]);
  assert.deepEqual(
    agentDiff.extractFiles('ApplyMultiFilePatch', { files: [first, second] }),
    [first, second]
  );
  assert.deepEqual(agentDiff.extractFiles('BuildProject', first), []);
  assert.deepEqual(agentDiff.extractFiles('PrepareMultiFilePatch', {}), []);
});
