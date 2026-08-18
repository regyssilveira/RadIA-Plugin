const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const promises = JSON.parse(
  fs.readFileSync(path.join('Tests', 'Usage', 'release-promises.json'), 'utf8')
);
const gate = fs.readFileSync(
  path.join('scripts', 'Test-RadIA.ReleasePromises.ps1'),
  'utf8'
);

test('critical public promises have stable user-journey identifiers', () => {
  assert.deepEqual(
    promises.promises.map((promise) => promise.id),
    [
      'direct-conversational-answer',
      'natural-vcl-project-creation',
      'calculator-requirement-fidelity',
      'build-failure-repair',
      'dunitx-create-run-repair',
      'chat-window-state-persistence',
      'read-only-without-consent',
      'agent-completes-within-step-budget',
      'request-cancellation-recovery',
      'provider-cli-failure-recovery',
      'clean-install-and-upgrade',
      'project-session-isolation',
      'sensitive-data-redaction'
    ]
  );
  for (const promise of promises.promises) {
    assert.equal(promise.priority, 'critical');
    assert.equal(promise.requiredTargets.length, 3);
    assert.ok(promise.publicStatement.length > 20);
    assert.ok(promise.maximumDurationSeconds > 0);
    assert.ok(promise.expectedOutcomes.length > 0);
    assert.ok(promise.forbiddenOutcomes.length > 0);
  }
});

test('promise gate rejects contracts disguised as user E2E evidence', () => {
  assert.match(gate, /scope -ne "user-journey"/u);
  assert.match(gate, /scenario-is-not-a-user-journey/u);
  assert.match(gate, /observable-outcomes-missing/u);
  assert.match(gate, /maximum-duration-missing/u);
  assert.match(gate, /expected-outcomes-missing/u);
  assert.match(gate, /forbidden-outcomes-missing/u);
  assert.match(gate, /scenario-not-required-by-regression/u);
  assert.match(gate, /Release promises without mandatory user-journey E2E coverage/u);
});
