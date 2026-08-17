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
const runtimeCatalogPath = path.join(
  root,
  'docs',
  'reference',
  'runtime_tools.json'
);
const runnerPath = path.join(
  root,
  'scripts',
  'Test-RadIA.FireDACAdvisorMatrix.ps1'
);
const smokePath = path.join(root, 'scripts', 'Test-RadIA.IDESmoke.ps1');

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
  const catalog = JSON.parse(fs.readFileSync(runtimeCatalogPath, 'utf8'));
  const runtimeTools = new Set(catalog.groups.flatMap(group => group.tools));
  assert.deepEqual(
    [...new Set(manifest.scenarios.flatMap(item => item.tools))]
      .filter(tool => !runtimeTools.has(tool)),
    []
  );
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

test('FireDAC Advisor runner connects fifteen safe IDE scenarios', () => {
  const runner = fs.readFileSync(runnerPath, 'utf8');
  const smoke = fs.readFileSync(smokePath, 'utf8');
  const connectedScenarios = [
    'firedac-inventory-navigation',
    'firedac-selected-sql-analysis',
    'firedac-credential-redaction',
    'firedac-unsafe-transaction',
    'firedac-shared-thread-connection',
    'firedac-sqlite-grid-csv',
    'firedac-sqlite-dml-rejection',
    'firedac-repository-preview-denied',
    'firedac-repository-applied',
    'firedac-build-failure-rollback',
    'firedac-parameter-smart-diff',
    'firedac-stale-preview-rejection',
    'firedac-ado-migration-batch',
    'firedac-migration-gate-rollback',
    'firedac-project-context-reset'
  ];
  const connectedTools = [
    'InspectFireDACProject',
    'GetFireDACProjectReport',
    'AnalyzeFireDACQuery',
    'InspectFireDACConfiguration',
    'AuditFireDACTransactions',
    'AnalyzeFireDACThreadSafety',
    'PrepareFireDACThreadSafetyPlan',
    'InspectLocalSQLiteDatabase',
    'PreviewLocalSQLiteQuery',
    'GenerateFireDACRepositoryPreview',
    'ApplyGeneratedArtifact',
    'RevertGeneratedArtifact',
    'ValidateFireDACParameters',
    'PrepareFireDACParameterFix',
    'ApplyFireDACFix',
    'PreparePatch',
    'ApplyPatch',
    'RevertPatch',
    'InventoryLegacyDataAccess',
    'PlanLegacyMigrationBatches',
    'PrepareLegacyMigrationBatch',
    'ApplyLegacyMigrationBatch',
    'RecordLegacyMigrationGate',
    'GetActiveProject',
    'PreviewProjectTemplate',
    'CreateProjectFromTemplate',
    'OpenCreatedProject',
    'RevertCreatedProject',
    'BuildProject',
    'RunDUnitXTests'
  ];

  connectedScenarios.forEach(scenario => {
    assert.ok(runner.includes(`"${scenario}"`));
    assert.ok(smoke.includes(`"${scenario}"`));
  });
  connectedTools.forEach(tool => assert.ok(smoke.includes(`"${tool}"`)));
  assert.match(runner, /IDE execution is not connected for/);
  assert.match(smoke, /evidence must remain inside Output/);
  assert.match(smoke, /TRadIAConsentForm/);
  assert.match(smoke, /Allow once/);
  assert.match(smoke, /unsafe_sql/);
  assert.doesNotMatch(smoke, /radia-e2e-secret[^\r\n]*result/);
});

test('FireDAC Advisor plan supports deterministic scenario and target filters', () => {
  const output = execFileSync(
    'powershell.exe',
    [
      '-NoProfile',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      runnerPath,
      '-PlanOnly',
      '-ScenarioId',
      'firedac-inventory-navigation',
      '-TargetId',
      'delphi12-win32'
    ],
    { encoding: 'utf8' }
  );
  const plan = JSON.parse(output);
  assert.equal(plan.targetCount, 3);
  assert.equal(plan.scenarioCount, 16);
  assert.equal(plan.selectedTargetCount, 1);
  assert.equal(plan.selectedScenarioCount, 1);
  assert.equal(plan.runCount, 1);
  assert.equal(plan.runs[0].scenarioId, 'firedac-inventory-navigation');
  assert.equal(plan.runs[0].targetId, 'delphi12-win32');
});
