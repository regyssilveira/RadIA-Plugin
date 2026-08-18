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

test('release gate composes calculator, opening, and usage tests', () => {
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
  assert.match(source, /Test-RadIA\.ProjectCreationNavigation\.ps1/u);
  assert.match(source, /Test-RadIA\.ReleasePromises\.ps1/u);
  assert.match(source, /-Enforce/u);
  assert.match(source, /Test-RadIA\.UsageMatrix\.ps1/u);
  assert.match(source, /-Profile "release"/u);
  assert.doesNotMatch(source, /RequirePackageProvenance/u);
  assert.match(source, /installationTargets/u);
  assert.match(source, /Install = \$true/u);
  assert.match(source, /Stop-RadIAReleaseAuxiliaryProcesses/u);
  assert.match(source, /Where-Object \{ -not \$_\.HasExited \}/u);
  assert.match(matrixSource, /Where-Object \{ -not \$_\.HasExited \}/u);
  assert.match(buildSource, /function Copy-RadIAReplaceableFile/u);
  assert.match(buildSource, /\.pending-delete-\$PID-/u);
  assert.match(source, /RadIA\.Semantic\.Engine/u);
  assert.match(source, /startupRetryUsed/u);
  assert.match(source, /attemptCount/u);
  assert.match(source, /Delphi did not become ready for the smoke test/u);
  assert.match(source, /The Delphi File menu did not open/u);
  assert.match(smokeSource, /\$attempt -le 3 -and -not \$menuOpened/u);
  assert.match(smokeSource, /SetForegroundWindow\(\$mainWindow\)/u);
  assert.match(smokeSource, /TRadIAOnboardingForm/u);
  assert.match(smokeSource, /\$onboardingWindow/u);
  assert.match(source, /The Delphi file dialog did not open/u);
  assert.match(source, /Test-RadIAReleaseJourneyRetryable/u);
  assert.match(source, /previousErrorActionPreference/u);
  assert.match(source, /\$ErrorActionPreference = "Continue"/u);
  assert.ok(
    source.indexOf('$installationTargets = @(') <
      source.indexOf('$openingTargets = @(')
  );
  const retryStart = source.indexOf('$firstAttemptOutput = $output');
  const retryEnd = source.indexOf('$attemptCount = 2', retryStart);
  const retryBlock = source.slice(retryStart, retryEnd);
  assert.match(retryBlock, /Install-RadIAReleaseTarget/u);
});

test('release usage plan separates host contracts from IDE journeys', () => {
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
  assert.equal(plan.runCount, 49);
  assert.equal(intentRuns.length, 1);
  assert.equal(intentRuns[0].targetId, 'host-neutral');
  assert.ok(intentRuns[0].requiredEvidence.includes('chat-fallback'));
  const conversationRuns = plan.runs.filter(
    (run) => run.scenarioId === 'first-conversation'
  );
  assert.equal(conversationRuns.length, 3);
  assert.ok(conversationRuns.every((run) => run.scope === 'user-journey'));
  const windowStateRuns = plan.runs.filter(
    (run) => run.scenarioId === 'chat-window-state-persistence'
  );
  assert.equal(windowStateRuns.length, 3);
  assert.ok(windowStateRuns.every(
    (run) => run.requiredEvidence.includes('boundsRestored')
  ));
  const creationRuns = plan.runs.filter(
    (run) => run.scenarioId === 'vcl-project-creation-lifecycle'
  );
  assert.equal(creationRuns.length, 3);
  assert.ok(creationRuns.every((run) => run.scope === 'ide-journey'));
  assert.ok(
    creationRuns.every((run) => run.requiredEvidence.includes('phases.buildPassed'))
  );
  const historyRuns = plan.runs.filter(
    (run) => run.scenarioId === 'calculator-history-fidelity'
  );
  assert.equal(historyRuns.length, 3);
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
