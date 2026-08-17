const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve('.');
const manifestPath = path.join(
  root,
  'Tests',
  'Usage',
  'firedac-advisor-matrix.json'
);
const runnerPath = path.join(
  root,
  'scripts',
  'Test-RadIA.FireDACAdvisorMatrix.ps1'
);

test('FireDAC Advisor matrix defines all 16 goal scenarios', () => {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  assert.equal(manifest.schemaVersion, 1);
  assert.equal(manifest.scenarios.length, 16);
  assert.equal(new Set(manifest.scenarios.map(item => item.id)).size, 16);
  assert.deepEqual(
    manifest.targets.map(target => target.id),
    ['delphi12-win32', 'delphi13-win32', 'delphi13-ide64']
  );
  assert.ok(manifest.scenarios.every(item => item.tools.length > 0));
  assert.ok(manifest.scenarios.every(item => item.requiredEvidence.length > 0));
});

test('FireDAC Advisor plan expands to 48 deterministic IDE runs', () => {
  const output = execFileSync(
    'powershell.exe',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      runnerPath,
      '-PlanOnly'
    ],
    { encoding: 'utf8' }
  );
  const plan = JSON.parse(output);
  assert.equal(plan.targetCount, 3);
  assert.equal(plan.scenarioCount, 16);
  assert.equal(plan.runCount, 48);
  assert.equal(
    plan.runs.filter(run => run.rollbackExpected).length,
    6
  );
  assert.ok(
    plan.runs
      .filter(run => run.scenarioId === 'firedac-shutdown-during-analysis')
      .every(run => run.requiredEvidence.includes('no-deadlock'))
  );
});
