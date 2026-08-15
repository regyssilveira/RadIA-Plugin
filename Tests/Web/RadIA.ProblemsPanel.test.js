const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve('.');
const chatHtml = fs.readFileSync(
  path.join(root, 'Source', 'UI', 'Web', 'chat.html'),
  'utf8'
);
const chatScript = fs.readFileSync(
  path.join(root, 'Source', 'UI', 'Web', 'chat.js'),
  'utf8'
);
const toolViews = fs.readFileSync(
  path.join(root, 'Source', 'Core', 'RadIA.Core.ToolViews.pas'),
  'utf8'
);
const problems = fs.readFileSync(
  path.join(root, 'Source', 'Core', 'RadIA.Core.Problems.pas'),
  'utf8'
);

test('every successful tool result receives the unified problems contract', () => {
  assert.match(toolViews, /TRadIAProblemExtractor\.Extract/u);
  assert.match(toolViews, /'_radiaProblems'/u);
  assert.match(toolViews, /RemovePair\('_radiaProblems'\)/u);
  assert.match(problems, /CMaxProblems = 200/u);
  assert.match(problems, /StableProblemId/u);
});

test('problems panel is accessible, filterable, and responsive', () => {
  assert.match(chatHtml, /id="btn-problems"/u);
  assert.match(chatHtml, /aria-controls="problems-panel"/u);
  assert.match(chatHtml, /id="problems-panel"[^>]*inert/u);
  assert.match(chatHtml, /id="problems-severity-filter"/u);
  assert.match(chatHtml, /id="problems-category-filter"/u);
  assert.match(chatHtml, /<ul id="problems-list"/u);
});

test('problem actions navigate safely or prepare a command for review', () => {
  assert.match(chatScript, /name: 'NavigateToFile'/u);
  assert.match(chatScript, /setPromptText\(problem\.recommendedCommand\)/u);
  assert.doesNotMatch(
    chatScript,
    /execute_tool[\s\S]{0,120}problem\.recommendedCommand/u
  );
});

test('problem collection is bounded by stable identifiers and chat lifecycle', () => {
  assert.match(chatScript, /COLLECTED_PROBLEMS\.set\(problem\.id, problem\)/u);
  assert.match(chatScript, /clearCollectedProblems\(\)/u);
  assert.match(chatScript, /currentProblemSessionId/u);
  assert.match(chatScript, /toggleAttribute\('inert'/u);
});
