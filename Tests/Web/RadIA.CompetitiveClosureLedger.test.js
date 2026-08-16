const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { randomUUID } = require('node:crypto');
const { spawnSync } = require('node:child_process');

const repositoryRoot = path.resolve('.');
const validator = path.join(
  repositoryRoot,
  'scripts',
  'Test-RadIA.CompetitiveClosureLedger.ps1'
);
const manifestPath = path.join(
  repositoryRoot,
  '.planning',
  'competitive_closure_manifest.json'
);
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
const packageManifest = JSON.parse(
  fs.readFileSync(path.join(repositoryRoot, 'package.json'), 'utf8')
);
const headCommit = spawnSync(
  'git',
  ['rev-parse', 'HEAD'],
  { cwd: repositoryRoot, encoding: 'utf8' }
).stdout.trim();

function createLedger() {
  return {
    schemaVersion: 1,
    goalId: manifest.goalId,
    productVersion: packageManifest.version,
    sourceCommit: headCommit,
    sourceDirty: false,
    generatedAtUtc: new Date().toISOString(),
    status: 'active',
    fronts: manifest.fronts.map(front => ({
      id: front.id,
      title: front.title,
      status: 'not-tested',
      checks: front.requiredChecks.map(id => ({
        id,
        status: 'not-tested',
        command: '',
        artifact: '',
        targets: []
      }))
    }))
  };
}

function closeCheck(ledger, frontIndex, checkIndex, targets = manifest.supportedTargets) {
  const front = ledger.fronts[frontIndex];
  const check = front.checks[checkIndex];
  const evidenceName = `test-${randomUUID()}.json`;
  const relativeArtifact = path.join(
    'Output',
    'Validation',
    'CompetitiveClosure',
    'TestArtifacts',
    evidenceName
  );
  const artifact = path.join(repositoryRoot, relativeArtifact);
  check.status = 'closed';
  check.command = 'npm run test:semantic-corpus:12';
  check.artifact = relativeArtifact;
  check.targets = [...targets];
  fs.mkdirSync(path.dirname(artifact), { recursive: true });
  fs.writeFileSync(artifact, JSON.stringify({
    schemaVersion: 1,
    productVersion: ledger.productVersion,
    sourceCommit: ledger.sourceCommit,
    frontId: front.id,
    checkId: check.id,
    command: check.command,
    targets: [...targets],
    status: 'passed'
  }, null, 2));
  return check;
}

function validateLedger(ledger) {
  const temporaryRoot = fs.mkdtempSync(
    path.join(os.tmpdir(), 'radia-closure-ledger-')
  );
  const ledgerPath = path.join(temporaryRoot, 'ledger.json');
  fs.writeFileSync(ledgerPath, JSON.stringify(ledger, null, 2));
  try {
    return spawnSync(
      'powershell.exe',
      [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        validator,
        '-LedgerPath',
        ledgerPath,
        '-RepositoryRoot',
        repositoryRoot
      ],
      { cwd: repositoryRoot, encoding: 'utf8' }
    );
  } finally {
    ledger.fronts.flatMap(front => front.checks).forEach(check => {
      if (check.artifact && check.artifact.includes('TestArtifacts')) {
        fs.rmSync(path.join(repositoryRoot, check.artifact), { force: true });
      }
    });
    fs.rmSync(temporaryRoot, { recursive: true, force: true });
  }
}

function combinedOutput(result) {
  return `${result.stdout || ''}\n${result.stderr || ''}`;
}

test('accepts an active ledger without promoting untested fronts', () => {
  const result = validateLedger(createLedger());

  assert.equal(result.status, 0, combinedOutput(result));
  assert.match(result.stdout, /status=active; fronts=9/u);
});

test('rejects a closed front with a required check that is not closed', () => {
  const ledger = createLedger();
  ledger.fronts[0].status = 'closed';
  closeCheck(ledger, 0, 0);
  const result = validateLedger(ledger);

  assert.notEqual(result.status, 0);
  assert.match(
    combinedOutput(result),
    /is closed with required checks that are not closed/u
  );
});

test('rejects evidence produced from another commit', () => {
  const ledger = createLedger();
  ledger.sourceCommit = '0000000000000000000000000000000000000000';
  const result = validateLedger(ledger);

  assert.notEqual(result.status, 0);
  assert.match(combinedOutput(result), /sourceCommit does not match/u);
});

test('rejects evidence produced from another product version', () => {
  const ledger = createLedger();
  ledger.productVersion = '2.6.2';
  const result = validateLedger(ledger);

  assert.notEqual(result.status, 0);
  assert.match(combinedOutput(result), /productVersion does not match/u);
});

test('rejects a closed check without reproducible command and artifact', () => {
  const ledger = createLedger();
  ledger.fronts[0].checks[0].status = 'closed';
  const result = validateLedger(ledger);

  assert.notEqual(result.status, 0);
  assert.match(combinedOutput(result), /requires command and artifact evidence/u);
});

test('rejects a closed check without all supported targets', () => {
  const ledger = createLedger();
  closeCheck(ledger, 0, 0, ['delphi12-win32']);
  const result = validateLedger(ledger);

  assert.notEqual(result.status, 0);
  assert.match(combinedOutput(result), /Targets for closed check/u);
});
