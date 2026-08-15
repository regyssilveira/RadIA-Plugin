const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { cwd } = require('node:process');
const test = require('node:test');

const root = cwd();
const chatScript = fs.readFileSync(path.join(root, 'Source', 'UI', 'Web', 'chat.js'), 'utf8');
const presenter = fs.readFileSync(
  path.join(root, 'Source', 'UI', 'RadIA.UI.ChatPresenter.pas'),
  'utf8'
);

test('intent recommendation exposes three explicit user decisions', () => {
  assert.match(chatScript, /Use recommended route/u);
  assert.match(chatScript, /Review command/u);
  assert.match(chatScript, /Continue as chat/u);
});

test('host validates recommendation actions against pending state', () => {
  assert.match(presenter, /if not FPendingIntentActive then/u);
  assert.match(presenter, /accept_intent_recommendation/u);
  assert.match(presenter, /review_intent_recommendation/u);
  assert.match(presenter, /dismiss_intent_recommendation/u);
});

test('natural intent creates a recommendation instead of direct journey execution', () => {
  assert.match(presenter, /TRadIAIntentRouter\.TryRecommend/u);
  assert.match(presenter, /PostIntentRecommendation\(LRecommendation\)/u);
  assert.doesNotMatch(
    presenter,
    /function TRadIAChatPresenter\.TryHandleInferredJourney/u
  );
});
