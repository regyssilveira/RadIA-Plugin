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

test('header compacts actions before content becomes crowded', () => {
  assert.match(
    chatCss,
    /@media \(max-width: 1100px\)[\s\S]*\.header-action-btn \.btn-label[\s\S]*display: none/u
  );
  assert.match(chatCss, /\.execution-route \{[\s\S]*text-overflow: ellipsis/u);
  assert.match(chatHtml, /class="header-title"[^>]*>RadIA</u);
});

test('composer separates execution and context into responsive rows', () => {
  assert.match(chatCss, /#chat-wrapper[\s\S]*min-width: 0/u);
  assert.match(chatCss, /#chat-footer[\s\S]*min-width: 0[\s\S]*width: 100%/u);
  assert.match(chatHtml, /composer-control-row composer-execution-row/u);
  assert.match(chatHtml, /composer-control-row composer-context-row/u);
  assert.match(
    chatCss,
    /\.composer-execution-row[\s\S]*grid-template-columns: repeat\(2, minmax\(0, 1fr\)\)/u
  );
  assert.match(
    chatCss,
    /\.composer-context-row[\s\S]*grid-template-columns: repeat\(3, minmax\(0, 1fr\)\)/u
  );
  assert.match(chatCss, /\.composer-context-row \.composer-route[\s\S]*grid-column: 1 \/ -1/u);
  assert.match(chatCss, /\.composer-executor-control select[\s\S]*max-width: none/u);
  assert.match(
    chatCss,
    /@media \(max-width: 360px\)[\s\S]*\.composer-control-label[\s\S]*display: none/u
  );
});

test('composer keeps advanced execution choices out of the initial reading path', () => {
  assert.match(chatHtml, /id="btn-composer-advanced"[^>]*aria-expanded="false"/u);
  assert.match(chatHtml, /composer-context-row hidden[\s\S]*id="composer-advanced-options"/u);
  assert.match(chatHtml, /composer-advanced-options[\s\S]*id="select-execution-route"/u);
  assert.match(chatJs, /function setComposerAdvancedVisible\(visible\)/u);
  assert.match(chatJs, /setComposerAdvancedVisible\(visible\)/u);
});

test('composer exposes reasoning effort as an explicit user choice', () => {
  assert.match(chatHtml, /id="select-reasoning-effort"/u);
  assert.match(
    chatHtml,
    /composer-execution-row[\s\S]*id="select-reasoning-effort"[\s\S]*id="btn-composer-advanced"/u
  );
  assert.match(chatHtml, /<option value="medium" selected>Medium<\/option>/u);
  assert.match(chatJs, /action: 'set_reasoning_effort'/u);
  assert.match(chatJs, /data\.reasoningEffort \|\| 'medium'/u);
  assert.match(chatHtml, /id="effort-dropdown-trigger"[\s\S]*id="effort-options-list"/u);
  assert.match(chatJs, /function updateEffortSelection\(effort = 'medium'\)/u);
  assert.match(chatCss, /\.composer-effort-control \.custom-dropdown-trigger::after \{[\s\S]*right: 3px/u);
});

test('welcome screen starts with goals while keeping the complete platform visible', () => {
  assert.match(chatJs, /What do you want to accomplish\?/u);
  assert.match(chatJs, /Understand this project/u);
  assert.match(chatJs, /Fix a problem/u);
  assert.match(chatJs, /Create something/u);
  assert.match(chatJs, /Debug an application/u);
  assert.match(chatJs, /Code<\/span><span>Build<\/span><span>Tests<\/span><span>Debugger/u);
  assert.match(chatJs, /Form Designer<\/span><span>Terminal<\/span><span>MCP<\/span><span>Skills/u);
  assert.match(chatJs, /setPromptText\('\/help'\)/u);
});

test('welcome actions prepare requests without sending automatically', () => {
  assert.match(chatJs, /button\.addEventListener\('click', \(\) => setPromptText\(action\.command\)\)/u);
  assert.doesNotMatch(
    chatJs,
    /welcome-action-btn[\s\S]{0,500}postMessageToDelphi\(\{ action: 'send_prompt'/u
  );
});
