const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const chatScript = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'Web', 'chat.js'),
  'utf8'
);
const chatStyles = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'Web', 'chat.css'),
  'utf8'
);

test('project creation exposes a stable user-facing operation timeline', () => {
  const labels = [
    'Preparing request',
    'Reviewing project structure',
    'Creating project files',
    'Opening project in Delphi',
    'Building the project',
    'Project ready'
  ];
  labels.forEach(label => assert.match(chatScript, new RegExp(label, 'u')));
  assert.match(chatScript, /aria-current/u);
  assert.match(chatScript, /result\?\.buildSucceeded === true/u);
  assert.match(chatStyles, /\.agent-operation-stage\.is-current/u);
});

test('project creation makes scope and expected result explicit', () => {
  assert.match(chatScript, /Not added automatically: DUnitX/u);
  assert.match(chatScript, /Optional additions remain your choice/u);
  assert.match(chatScript, /opens in Delphi and builds successfully/u);
});

test('technical agent details remain available below the simplified summary', () => {
  assert.match(chatScript, /agent-operation-summary/u);
  assert.match(chatScript, /agent-run-validation/u);
  assert.match(chatScript, /agent-run-impact/u);
  assert.match(chatScript, /agent-run-steps/u);
  assert.match(chatScript, /Technical details/u);
});

test('optional project additions are user-initiated after completion', () => {
  assert.match(chatScript, /state\.status !== 'completed'/u);
  assert.match(chatScript, /Add DUnitX tests/u);
  assert.match(chatScript, /setPromptText\(prompt\)/u);
  assert.match(chatScript, /only prepares a request for your review/u);
});
