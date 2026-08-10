const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve('.');
const chatJs = fs.readFileSync(path.join(root, 'Source', 'UI', 'Web', 'chat.js'), 'utf8');
const presenter = fs.readFileSync(
  path.join(root, 'Source', 'UI', 'RadIA.UI.ChatPresenter.pas'),
  'utf8'
);

test('CLI stdout and stderr are forwarded to a visible activity surface', () => {
  assert.match(presenter, /PostCliActivity\(/u);
  assert.match(presenter, /'action', 'cli_activity'/u);
  assert.match(presenter, /TRadIACliProcessRunner\.Start\([\s\S]*?'output'/u);
  assert.match(presenter, /TRadIACliProcessRunner\.Start\([\s\S]*?'warning'/u);
  assert.match(chatJs, /function renderCliActivity\(data\)/u);
  assert.match(chatJs, /case 'cli_activity'/u);
  assert.match(chatJs, /cliActivityLog\.textContent/u);
});

test('CLI activity distinguishes terminal states and common structured events', () => {
  assert.match(chatJs, /command_execution/u);
  assert.match(chatJs, /file_change/u);
  assert.match(chatJs, /turn\.started/u);
  assert.match(chatJs, /phase === 'completed'/u);
  assert.match(chatJs, /phase === 'failed'/u);
});
