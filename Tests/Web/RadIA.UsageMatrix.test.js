const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve('.');
const manifestPath = path.join(root, 'Tests', 'Usage', 'usage-matrix.json');
const runnerPath = path.join(root, 'scripts', 'Test-RadIA.UsageMatrix.ps1');
const releaseRunnerPath = path.join(
  root,
  'scripts',
  'Test-RadIA.ReleaseUsage.ps1'
);

test('usage matrix covers every supported IDE target', () => {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  assert.equal(manifest.schemaVersion, 1);
  assert.deepEqual(
    manifest.targets.map((target) => target.id),
    ['delphi12-win32', 'delphi13-win32', 'delphi13-ide64']
  );
  assert.ok(manifest.targets.every((target) => target.required === true));
  assert.deepEqual(
    manifest.profiles.find((profile) => profile.id === 'startup').scenarioIds,
    ['ide-startup-shutdown']
  );
});

test('usage matrix plan is deterministic and does not start Delphi', () => {
  const output = execFileSync(
    'powershell.exe',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      runnerPath,
      '-Profile',
      'startup',
      '-RequirePackageProvenance',
      '-PlanOnly'
    ],
    { encoding: 'utf8' }
  );
  const plan = JSON.parse(output);
  assert.equal(plan.targetCount, 3);
  assert.equal(plan.scenarioCount, 1);
  assert.equal(plan.runCount, 3);
  assert.equal(plan.packageProvenanceRequired, true);
  assert.ok(
    plan.runs.every((run) => run.requiredEvidence.includes('clean-shutdown'))
  );
  assert.ok(
    plan.runs.every((run) => run.requiredEvidence.includes('no-orphan-processes'))
  );
});

test('release gate composes calculator, opening, and usage tests', () => {
  const source = fs.readFileSync(releaseRunnerPath, 'utf8');
  assert.match(source, /build\.ps1/u);
  assert.match(source, /-Test/u);
  assert.match(source, /Version = "23\.0"/u);
  assert.match(source, /Version = "37\.0"/u);
  assert.match(source, /Test-RadIA\.GeneratedProjects\.ps1/u);
  assert.match(source, /New-RadIA\.GeneratedProjectsEvidence\.ps1/u);
  assert.match(source, /Test-RadIA\.ProjectCreationNavigation\.ps1/u);
  assert.match(source, /Test-RadIA\.UsageMatrix\.ps1/u);
  assert.match(source, /-Profile "release"/u);
  assert.match(source, /RequirePackageProvenance/u);
});

test('release usage plan adds the intent recommendation contract once', () => {
  const output = execFileSync(
    'powershell.exe',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      runnerPath,
      '-Profile',
      'release',
      '-PlanOnly'
    ],
    { encoding: 'utf8' }
  );
  const plan = JSON.parse(output);
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  assert.equal(plan.scenarioCount, manifest.scenarios.length);
  assert.deepEqual(
    [...new Set(plan.runs.map((run) => run.scenarioId))].sort(),
    manifest.scenarios.map((scenario) => scenario.id).sort()
  );
  const intentRuns = plan.runs.filter(
    (run) => run.scenarioId === 'intent-recommendation'
  );
  assert.equal(plan.runCount, 6);
  assert.equal(intentRuns.length, 1);
  assert.equal(intentRuns[0].targetId, 'host-neutral');
  assert.ok(intentRuns[0].requiredEvidence.includes('chat-fallback'));
  const problemRuns = plan.runs.filter(
    (run) => run.scenarioId === 'unified-problems-panel'
  );
  assert.equal(problemRuns.length, 1);
  assert.equal(problemRuns[0].targetId, 'host-neutral');
  assert.ok(
    problemRuns[0].requiredEvidence.includes('safe-source-navigation')
  );
  const hierarchyRuns = plan.runs.filter(
    (run) => run.scenarioId === 'semantic-hierarchy-refactoring'
  );
  assert.equal(hierarchyRuns.length, 1);
  assert.ok(
    hierarchyRuns[0].requiredEvidence.includes('ambiguous-overload-blocked')
  );
});
