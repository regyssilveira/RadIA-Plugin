const assert = require('node:assert/strict');
const test = require('node:test');
const agentDebug = require('../../Source/UI/Web/RadIA.UI.AgentDebug.js');

test('evidenceKind classifies debugger inspection and control tools', () => {
  assert.equal(agentDebug.evidenceKind('GetDebuggerState'), 'state');
  assert.equal(agentDebug.evidenceKind('ListBreakpoints'), 'breakpoints');
  assert.equal(agentDebug.evidenceKind('GetCallStack'), 'callStack');
  assert.equal(agentDebug.evidenceKind('StepOver'), 'action');
  assert.equal(agentDebug.evidenceKind('EvaluateDebuggerExpression'), 'value');
  assert.equal(agentDebug.evidenceKind('EvaluateDebuggerWatches'), 'watches');
  assert.equal(agentDebug.evidenceKind('GetDebugTimeline'), 'timeline');
  assert.equal(agentDebug.evidenceKind('BuildProject'), '');
});

test('boundedItems rejects non-arrays and applies safe limits', () => {
  const values = Array.from({ length: 600 }, (_, index) => index);

  assert.deepEqual(agentDebug.boundedItems(null), []);
  assert.equal(agentDebug.boundedItems(values, 10).length, 10);
  assert.equal(agentDebug.boundedItems(values, 1000).length, 500);
  assert.equal(agentDebug.boundedItems(values, 0).length, 1);
});
