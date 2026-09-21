const assert = require('node:assert/strict');
const childProcess = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const orchestratorPath = path.join(
  repositoryRoot,
  'scripts',
  'Invoke-RadIA.Release.ps1'
);
const orchestrator = fs.readFileSync(orchestratorPath, 'utf8');

function readPlan(...argumentsList) {
  const output = childProcess.execFileSync(
    'powershell.exe',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      orchestratorPath,
      '-PlanOnly',
      ...argumentsList
    ],
    { cwd: repositoryRoot, encoding: 'utf8' }
  );
  return JSON.parse(output);
}

test('release orchestration is a non-publishing dry run by default', () => {
  const plan = readPlan();
  assert.equal(plan.mode, 'dry-run');
  assert.equal(plan.mutatesRemote, false);
  assert.doesNotMatch(plan.steps.join(','), /publish-existing-tag/u);
});

test('release orchestration preserves gates and exact provenance checks', () => {
  [
    'npm run lint',
    'npm run test:web',
    'Test-RadIA.SupportedTargets.ps1',
    'Test-RadIA.SonarQualityGate.ps1',
    'Test-RadIA.ReleaseUsage.ps1',
    'New-RadIA.ReleaseEvidence.ps1',
    'New-RadIA.VisualInstaller.ps1',
    'Test-RadIA.VisualInstaller.ps1',
    'sourceCommit -ne $sourceCommit',
    'stagedHash -ne $installerEvidence.sha256'
  ].forEach(fragment => assert.ok(orchestrator.includes(fragment), fragment));
});

test('publication requires an explicit mode, main, and an exact existing tag', () => {
  const plan = readPlan('-Publish');
  assert.equal(plan.mode, 'publish');
  assert.equal(plan.mutatesRemote, true);
  assert.match(plan.steps.join(','), /publish-existing-tag/u);
  assert.match(orchestrator, /\$branch -ne "main"/u);
  assert.match(orchestrator, /\$tagCommit -ne \$sourceCommit/u);
  assert.match(orchestrator, /if \(\$Publish\)[\s\S]*gh release/u);
});

test('Sonar gate rejects an analysis from another revision', () => {
  const sonarGate = fs.readFileSync(
    path.join(repositoryRoot, 'scripts', 'Test-RadIA.SonarQualityGate.ps1'),
    'utf8'
  );
  assert.match(sonarGate, /additionalFields=scannerContext/u);
  assert.match(sonarGate, /sonar\\\.projectBaseDir/u);
  assert.match(sonarGate, /\$analysisTimestamp -lt \$commitTimestamp/u);
});
