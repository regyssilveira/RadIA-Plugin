const RADIA_DEBUG_ACTION_TOOLS = new Set([
  'StartDebugging',
  'PauseDebugging',
  'ContinueDebugging',
  'StepInto',
  'StepOver',
  'StepOut',
  'StopDebugging'
]);

const RADIA_DEBUG_BREAKPOINT_TOOLS = new Set([
  'ListBreakpoints',
  'AddBreakpoint',
  'RemoveBreakpoint'
]);

const RADIA_DEBUG_WATCH_TOOLS = new Set([
  'AddDebuggerWatch',
  'RemoveDebuggerWatch',
  'ListDebuggerWatches',
  'EvaluateDebuggerWatches'
]);

function radIADebugEvidenceKind(toolName) {
  if (toolName === 'GetDebuggerState') {
    return 'state';
  }
  if (RADIA_DEBUG_BREAKPOINT_TOOLS.has(toolName)) {
    return 'breakpoints';
  }
  if (toolName === 'GetCallStack') {
    return 'callStack';
  }
  if (RADIA_DEBUG_ACTION_TOOLS.has(toolName)) {
    return 'action';
  }
  if (toolName === 'EvaluateDebuggerExpression') {
    return 'value';
  }
  if (RADIA_DEBUG_WATCH_TOOLS.has(toolName)) {
    return 'watches';
  }
  if (toolName === 'GetDebugTimeline') {
    return 'timeline';
  }
  return '';
}

function radIABoundedDebugItems(value, maximumCount = 100) {
  if (!Array.isArray(value)) {
    return [];
  }
  const safeMaximum = Math.max(1, Math.min(500, maximumCount));
  return value.slice(0, safeMaximum);
}

(function initializeRadIAAgentDebug(root) {
  const api = {
    boundedItems: radIABoundedDebugItems,
    evidenceKind: radIADebugEvidenceKind
  };
  if (typeof module === 'object' && module.exports) {
    module.exports = api;
  }
  if (root) {
    root.RadIAAgentDebug = api;
  }
})(typeof globalThis === 'undefined' ? this : globalThis);
