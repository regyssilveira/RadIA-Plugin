const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repositoryRoot = path.resolve('.');
const webRoot = path.join(repositoryRoot, 'Source', 'UI', 'Web');
const chatHtml = fs.readFileSync(path.join(webRoot, 'chat.html'), 'utf8');
const chatJs = fs.readFileSync(path.join(webRoot, 'chat.js'), 'utf8');
const chatCss = fs.readFileSync(path.join(webRoot, 'chat.css'), 'utf8');

test('composer exposes an accessible follow-up queue while a turn is active', () => {
  assert.match(chatHtml, /id="btn-queue-prompt"[^>]*title="Queue this message/u);
  assert.match(chatHtml, /aria-label="Queue message after current response"/u);
  assert.match(chatHtml, /<output id="queued-prompts"[^>]*aria-live="polite"/u);
  assert.match(chatHtml, /id="btn-edit-queued"[^>]*title=/u);
  assert.match(chatHtml, /id="btn-clear-queued"[^>]*title=/u);
});

test('composer queue is bounded and dispatches only after the active turn', () => {
  assert.match(chatJs, /MAX_QUEUED_PROMPTS = 5/u);
  assert.match(chatJs, /if \(requestInProgress \|\| queuedPrompts\.length === 0\) return/u);
  assert.match(chatJs, /if \(!inProgress\) setTimeout\(dispatchNextQueuedPrompt, 0\)/u);
  assert.match(chatJs, /if \(requestInProgress\) queuePrompt\(\)/u);
  assert.match(chatJs, /queuedPrompts\.length = 0/u);
});

test('queued follow-ups remain visible without widening the composer', () => {
  assert.match(chatCss, /#queued-prompts-text[\s\S]*text-overflow: ellipsis/u);
  assert.match(chatCss, /#btn-queue-prompt\.hidden[\s\S]*display: none/u);
  assert.match(chatCss, /@media \(max-width: 520px\)[\s\S]*\.execution-route,[\s\S]*display: none/u);
});
