const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const scriptPath = path.join(
  repositoryRoot,
  'scripts',
  'Measure-RadIA.AgentEfficiency.ps1'
);
const gateScriptPath = path.join(
  repositoryRoot,
  'scripts',
  'Test-RadIA.AgentEfficiencyGate.ps1'
);

function metricLine(payload) {
  return `2026-09-21 10:00:00.000 - [AgentMetrics] ${JSON.stringify(payload)}`;
}

function runMeasurement(logPath, outputPath, baselinePath = '') {
  const args = [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    scriptPath,
    '-LogPath',
    logPath,
    '-OutputPath',
    outputPath,
    '-LastRuns',
    '10',
    '-PairingKey',
    'agent-create-project-fixture'
  ];
  if (baselinePath) {
    args.push('-BaselinePath', baselinePath);
  }
  return spawnSync('powershell.exe', args, {
    cwd: repositoryRoot,
    encoding: 'utf8'
  });
}

function runGate(baselinePath, currentPath, outputPath) {
  return spawnSync('powershell.exe', [
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    gateScriptPath,
    '-BaselinePath',
    baselinePath,
    '-CurrentPath',
    currentPath,
    '-OutputPath',
    outputPath,
    '-MinimumRuns',
    '2'
  ], {
    cwd: repositoryRoot,
    encoding: 'utf8'
  });
}

test('agent efficiency measurement aggregates latest sanitized run summaries', () => {
  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'radia-agent-efficiency-'));
  const logPath = path.join(temporaryDirectory, 'radia.log');
  const outputPath = path.join(temporaryDirectory, 'evidence.json');
  const comparisonPath = path.join(temporaryDirectory, 'comparison.json');
  const lines = [
    '2026-09-21 09:59:00.000 - [Debug] SECRET_PROMPT',
    metricLine({
      event: 'agentRunSummary',
      runId: 'run-a',
      status: 'awaitingApproval',
      stopReason: 'awaitingApproval',
      decisionCount: 1,
      toolCallCount: 0,
      suppressedToolCallCount: 0,
      repeatedDecisionCount: 0,
      recoveredRepeatCount: 0,
      durationMilliseconds: 10,
      usageStatus: 'reported',
      promptTokens: 20,
      completionTokens: 5
    }),
    metricLine({
      event: 'agentRunSummary',
      runId: 'run-a',
      status: 'completed',
      stopReason: 'completed',
      decisionCount: 3,
      toolCallCount: 1,
      suppressedToolCallCount: 1,
      repeatedDecisionCount: 1,
      recoveredRepeatCount: 1,
      durationMilliseconds: 100,
      firstDecisionDurationMilliseconds: 30,
      usageStatus: 'reported',
      promptTokens: 100,
      completionTokens: 25
    }),
    metricLine({
      event: 'agentRunSummary',
      runId: 'run-b',
      status: 'failed',
      stopReason: 'durationLimit',
      decisionCount: 2,
      toolCallCount: 1,
      suppressedToolCallCount: 0,
      repeatedDecisionCount: 0,
      recoveredRepeatCount: 0,
      durationMilliseconds: 300,
      firstDecisionDurationMilliseconds: 50,
      usageStatus: 'unknown',
      promptTokens: 0,
      completionTokens: 0
    })
  ];

  try {
    fs.writeFileSync(logPath, `${lines.join('\r\n')}\r\n`, 'utf8');
    const measurement = runMeasurement(logPath, outputPath);
    assert.equal(measurement.status, 0, measurement.stderr || measurement.stdout);

    const evidenceText = fs.readFileSync(outputPath, 'utf8');
    const evidence = JSON.parse(evidenceText);
    assert.equal(evidence.sample.analyzedRuns, 2);
    assert.equal(evidence.sample.responsivenessMeasuredRunCount, 2);
    assert.equal(evidence.sample.tokenUsageMeasuredRunCount, 1);
    assert.equal(evidence.metrics.averageDecisionCount, 2.5);
    assert.equal(evidence.metrics.averageFirstDecisionDurationMilliseconds, 40);
    assert.equal(evidence.metrics.totalToolCallCount, 2);
    assert.equal(evidence.metrics.totalSuppressedToolCallCount, 1);
    assert.equal(evidence.metrics.toolCallSuppressionPercent, 33.33);
    assert.equal(evidence.metrics.repeatRecoveryPercent, 100);
    assert.equal(evidence.metrics.averagePromptTokens, 100);
    assert.equal(evidence.metrics.averageTotalTokens, 125);
    assert.equal(evidence.statusCounts.completed, 1);
    assert.equal(evidence.statusCounts.failed, 1);
    assert.doesNotMatch(
      evidenceText,
      /SECRET_PROMPT|run-a|run-b|agent-create-project-fixture/u
    );

    const comparison = runMeasurement(logPath, comparisonPath, outputPath);
    assert.equal(comparison.status, 0, comparison.stderr || comparison.stdout);
    const comparedEvidence = JSON.parse(fs.readFileSync(comparisonPath, 'utf8'));
    assert.equal(comparedEvidence.comparison.decisionCountDeltaPercent, 0);
    assert.equal(comparedEvidence.comparison.toolCallCountDeltaPercent, 0);
    assert.equal(comparedEvidence.comparison.durationDeltaPercent, 0);
    assert.equal(comparedEvidence.comparison.promptTokensDeltaPercent, 0);
    assert.equal(comparedEvidence.comparison.totalTokensDeltaPercent, 0);
    assert.equal(comparedEvidence.comparison.responsivenessDeltaPercent, 0);
  } finally {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
});

test('paired efficiency gate accepts equal samples and rejects relative regressions', () => {
  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'radia-agent-gate-'));
  const baselinePath = path.join(temporaryDirectory, 'baseline.json');
  const currentPath = path.join(temporaryDirectory, 'current.json');
  const gatePath = path.join(temporaryDirectory, 'gate.json');
  const evidence = {
    schemaVersion: 2,
    sample: {
      analyzedRuns: 2,
      pairingKeyHash: 'safe-pairing-hash',
      responsivenessMeasuredRunCount: 2,
      tokenUsageMeasuredRunCount: 2
    },
    metrics: {
      averageDurationMilliseconds: 100,
      averageDecisionCount: 2,
      averageToolCallCount: 1,
      averageTotalTokens: 80,
      averageFirstDecisionDurationMilliseconds: 25
    }
  };

  try {
    fs.writeFileSync(baselinePath, JSON.stringify(evidence), 'utf8');
    fs.writeFileSync(currentPath, JSON.stringify(evidence), 'utf8');
    const accepted = runGate(baselinePath, currentPath, gatePath);
    assert.equal(accepted.status, 0, accepted.stderr || accepted.stdout);
    assert.equal(JSON.parse(fs.readFileSync(gatePath, 'utf8')).passed, true);

    const regressed = JSON.parse(JSON.stringify(evidence));
    regressed.metrics.averageDurationMilliseconds = 125;
    fs.writeFileSync(currentPath, JSON.stringify(regressed), 'utf8');
    const rejected = runGate(baselinePath, currentPath, gatePath);
    assert.notEqual(rejected.status, 0);
    const gate = JSON.parse(fs.readFileSync(gatePath, 'utf8'));
    assert.equal(gate.passed, false);
    assert.deepEqual(
      gate.comparisons.filter(item => !item.passed).map(item => item.name),
      ['duration']
    );
  } finally {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
});

test('paired efficiency gate rejects incomparable samples', () => {
  const temporaryDirectory = fs.mkdtempSync(path.join(os.tmpdir(), 'radia-agent-pair-'));
  const baselinePath = path.join(temporaryDirectory, 'baseline.json');
  const currentPath = path.join(temporaryDirectory, 'current.json');
  const evidence = {
    schemaVersion: 2,
    sample: {
      analyzedRuns: 2,
      pairingKeyHash: 'baseline-hash',
      responsivenessMeasuredRunCount: 2,
      tokenUsageMeasuredRunCount: 2
    },
    metrics: {}
  };

  try {
    fs.writeFileSync(baselinePath, JSON.stringify(evidence), 'utf8');
    const unpaired = JSON.parse(JSON.stringify(evidence));
    unpaired.sample.pairingKeyHash = 'different-hash';
    fs.writeFileSync(currentPath, JSON.stringify(unpaired), 'utf8');
    const result = runGate(baselinePath, currentPath, '');
    assert.notEqual(result.status, 0);
    assert.match(result.stderr, /same non-empty pairing key/u);
  } finally {
    fs.rmSync(temporaryDirectory, { recursive: true, force: true });
  }
});
