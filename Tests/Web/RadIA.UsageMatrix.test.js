const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { execFileSync, spawnSync } = require('node:child_process');
const test = require('node:test');

const root = path.resolve('.');
const manifestPath = path.join(root, 'Tests', 'Usage', 'usage-matrix.json');
const runnerPath = path.join(root, 'scripts', 'Test-RadIA.UsageMatrix.ps1');
const releaseRunnerPath = path.join(
  root,
  'scripts',
  'Test-RadIA.ReleaseUsage.ps1'
);
const buildPath = path.join(root, 'build.ps1');
const smokeRunnerPath = path.join(
  root,
  'scripts',
  'Test-RadIA.KnowledgeNotifierSmoke.ps1'
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

test('release gate composes bounded critical validation', () => {
  const source = fs.readFileSync(releaseRunnerPath, 'utf8');
  const matrixSource = fs.readFileSync(runnerPath, 'utf8');
  const buildSource = fs.readFileSync(buildPath, 'utf8');
  const smokeSource = fs.readFileSync(smokeRunnerPath, 'utf8');
  assert.match(source, /build\.ps1/u);
  assert.match(source, /-Test/u);
  assert.match(source, /Version = "23\.0"/u);
  assert.match(source, /Version = "37\.0"/u);
  assert.match(source, /Test-RadIA\.GeneratedProjects\.ps1/u);
  assert.match(source, /New-RadIA\.GeneratedProjectsEvidence\.ps1/u);
  assert.match(source, /Test-RadIA\.ReleasePromises\.ps1/u);
  assert.match(source, /-Enforce/u);
  assert.match(source, /Test-RadIA\.UsageMatrix\.ps1/u);
  assert.match(source, /-Profile "startup"/u);
  assert.match(source, /-Profile "release"/u);
  assert.match(source, /\[switch\]\$PlanOnly/u);
  assert.match(source, /totalIdeRunCount/u);
  assert.doesNotMatch(source, /RequirePackageProvenance/u);
  assert.doesNotMatch(source, /installationTargets/u);
  assert.doesNotMatch(source, /openingTargets/u);
  assert.match(source, /Stop-RadIAReleaseAuxiliaryProcesses/u);
  assert.match(source, /Where-Object \{ -not \$_\.HasExited \}/u);
  assert.match(matrixSource, /Where-Object \{ -not \$_\.HasExited \}/u);
  assert.match(
    matrixSource,
    /\$Profile -in @\("startup", "release", "regression"\)/u
  );
  assert.match(buildSource, /function Copy-RadIAReplaceableFile/u);
  assert.match(buildSource, /\.pending-delete-\$PID-/u);
  assert.match(source, /RadIA\.Semantic\.Engine/u);
  assert.match(smokeSource, /\$attempt -le 3 -and -not \$menuOpened/u);
  assert.match(smokeSource, /SetForegroundWindow\(\$mainWindow\)/u);
  assert.match(smokeSource, /TRadIAOnboardingForm/u);
  assert.match(smokeSource, /\$onboardingWindow/u);
});

test('release usage plan is bounded to the representative target', () => {
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
  assert.equal(plan.targetCount, 1);
  assert.equal(plan.scenarioCount, 9);
  assert.equal(plan.runCount, 9);
  const intentRuns = plan.runs.filter(
    (run) => run.scenarioId === 'intent-recommendation'
  );
  assert.equal(intentRuns.length, 1);
  assert.equal(intentRuns[0].targetId, 'host-neutral');
  assert.ok(intentRuns[0].requiredEvidence.includes('chat-fallback'));
  const conversationRuns = plan.runs.filter(
    (run) => run.scenarioId === 'first-conversation'
  );
  assert.equal(conversationRuns.length, 1);
  assert.equal(conversationRuns[0].targetId, 'delphi13-win32');
  assert.ok(conversationRuns.every((run) => run.scope === 'user-journey'));
  const windowStateRuns = plan.runs.filter(
    (run) => run.scenarioId === 'chat-window-state-persistence'
  );
  assert.equal(windowStateRuns.length, 1);
  assert.ok(windowStateRuns.every(
    (run) => run.requiredEvidence.includes('boundsRestored')
  ));
  const historyRuns = plan.runs.filter(
    (run) => run.scenarioId === 'calculator-history-fidelity'
  );
  assert.equal(historyRuns.length, 1);
  assert.ok(historyRuns.every((run) => run.scope === 'user-journey'));
  assert.ok(historyRuns.every(
    (run) => run.requiredEvidence.includes('debugger.operationHistoryPassed')
  ));
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
  const breakpointRuns = plan.runs.filter(
    (run) => run.scenarioId === 'advanced-breakpoints'
  );
  assert.equal(breakpointRuns.length, 1);
  assert.ok(
    breakpointRuns[0].requiredEvidence.includes(
      'unsupported-exception-filter-explicit'
    )
  );
});

test('regression plan retains every scenario on compatible targets', () => {
  const output = execFileSync(
    'powershell.exe',
    [
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', runnerPath,
      '-Profile', 'regression', '-PlanOnly'
    ],
    { encoding: 'utf8' }
  );
  const plan = JSON.parse(output);
  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  assert.equal(plan.scenarioCount, manifest.scenarios.length);
  assert.equal(plan.runCount, 49);
  assert.deepEqual(
    [...new Set(plan.runs.map((run) => run.scenarioId))].sort(),
    manifest.scenarios.map((scenario) => scenario.id).sort()
  );
});

test('targeted plan runs only explicit scenarios and targets', () => {
  const output = execFileSync(
    'powershell.exe',
    [
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', runnerPath,
      '-Profile', 'targeted', '-ScenarioId', 'calculator-history-fidelity',
      '-TargetId', 'delphi13-win32', '-PlanOnly'
    ],
    { encoding: 'utf8' }
  );
  const plan = JSON.parse(output);
  assert.equal(plan.scenarioCount, 1);
  assert.equal(plan.runCount, 1);
  assert.equal(plan.runs[0].scenarioId, 'calculator-history-fidelity');
  assert.equal(plan.runs[0].targetId, 'delphi13-win32');
});

test('targeted plan rejects an implicit broad selection', () => {
  const result = spawnSync(
    'powershell.exe',
    [
      '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', runnerPath,
      '-Profile', 'targeted', '-PlanOnly'
    ],
    { encoding: 'utf8' }
  );
  assert.notEqual(result.status, 0);
  assert.match(
    `${result.stdout}${result.stderr}`,
    /targeted profile requires at least one -ScenarioId/u
  );
});
