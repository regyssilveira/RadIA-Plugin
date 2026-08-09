const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const notifierSource = fs.readFileSync(
  path.join('Source', 'Integration', 'RadIA.OTA.DebugTimeline.pas'),
  'utf8'
);
const debuggerSource = fs.readFileSync(
  path.join('Source', 'Integration', 'RadIA.OTA.Debugger.pas'),
  'utf8'
);
const inlineReviewSource = fs.readFileSync(
  path.join('Source', 'Integration', 'RadIA.OTA.InlineReviews.pas'),
  'utf8'
);

test('debug start queues the official IDE Run action asynchronously', () => {
  assert.match(
    debuggerSource,
    /function StartDebugProject[\s\S]*?Sleep\(250\)[\s\S]*?TThread\.ForceQueue[\s\S]*?'starting'/u
  );
  assert.doesNotMatch(debuggerSource, /WaitForDebugProcess/u);
});

test('debug notifier never retains transient OTA process interfaces asynchronously', () => {
  assert.doesNotMatch(notifierSource, /TThread\.ForceQueue[\s\S]*?EnsureRuntimeSession\(Process\)/u);
});

test('debug lifecycle callbacks isolate timeline failures from the IDE debugger', () => {
  const protectedCallbacks = [
    'BeforeProgramLaunch',
    'CurrentProcessChanged',
    'ProcessCreated',
    'ProcessDestroyed',
    'ProcessStateChanged'
  ];

  protectedCallbacks.forEach(callbackName => {
    assert.match(
      notifierSource,
      new RegExp(`LogNotifierFailure\\('${callbackName}', E\\)`, 'u'),
      `${callbackName} must contain its own failure boundary`
    );
  });
});

test('breakpoint verification retries runtime-session correlation', () => {
  assert.match(
    notifierSource,
    /procedure TRadIAOTADebugTimelineNotifier\.BreakpointAdded[\s\S]*?RefreshRuntimeSession/u
  );
  assert.match(
    notifierSource,
    new RegExp(
      'procedure TRadIAOTADebugTimelineNotifier\\.RefreshRuntimeSession' +
        '[\\s\\S]*?EnsureRuntimeSession[\\s\\S]*?RecordRuntimeState',
      'u'
    )
  );
});

test('source breakpoint trigger records the authoritative stopped event', () => {
  const triggerRoutine = notifierSource.match(
    new RegExp(
      'function TRadIABreakpointTriggerNotifier\\.Trigger[\\s\\S]*?' +
        '(?=procedure TRadIABreakpointTriggerNotifier\\.Verified)',
      'u'
    )
  )?.[0] ?? '';
  assert.match(triggerRoutine, /rdekStopped/u);
  assert.match(triggerRoutine, /Result := trDefault/u);
  assert.match(
    notifierSource,
    /procedure TRadIAOTADebugTimelineNotifier\.BreakpointAdded[\s\S]*?Breakpoint\.AddNotifier/u
  );
});

test('transient process properties have initializing-safe fallbacks', () => {
  assert.match(
    notifierSource,
    /function TRadIAOTADebugTimelineNotifier\.ProcessId[\s\S]*?except[\s\S]*?Result := 0/u
  );
  assert.match(
    notifierSource,
    /function TRadIAOTADebugTimelineNotifier\.RuntimeProcessId[\s\S]*?except[\s\S]*?Result := 0/u
  );
  assert.match(
    notifierSource,
    /function TRadIAOTADebugTimelineNotifier\.ProcessState[\s\S]*?Result := 'initializing'/u
  );
});

test('inline review paint tolerates editor buffers closing during shutdown', () => {
  const findBlockRoutine = inlineReviewSource.match(
    new RegExp(
      'function TRadIAOTAInlineReviewFacade\\.FindBlock[\\s\\S]*?' +
        '(?=function TRadIAOTAInlineReviewFacade\\.FindHitTarget)',
      'u'
    )
  )?.[0] ?? '';
  assert.match(
    inlineReviewSource,
    new RegExp(
      'procedure TRadIAOTAInlineReviewFacade\\.HandleBeginPaint' +
        '[\\s\\S]*?GIsShuttingDown[\\s\\S]*?LBuffer := FView\\.Buffer' +
        '[\\s\\S]*?except',
      'u'
    )
  );
  assert.match(
    inlineReviewSource,
    /function TRadIAOTAInlineReviewFacade\.TryGetCurrentBuffer[\s\S]*?GIsShuttingDown[\s\S]*?except/u
  );
  assert.doesNotMatch(
    findBlockRoutine,
    /FView\.Buffer\.FileName/u
  );
  assert.match(
    inlineReviewSource,
    /procedure TRadIAOTAInlineReviewFacade\.EditorIdle[\s\S]*?GIsShuttingDown[\s\S]*?except/u
  );
  assert.match(
    inlineReviewSource,
    /procedure TRadIAOTAInlineReviewFacade\.HandlePaintLine[\s\S]*?GIsShuttingDown[\s\S]*?except/u
  );
  assert.match(
    inlineReviewSource,
    /procedure TRadIAOTAInlineReviewFacade\.HandlePaintGutter[\s\S]*?GIsShuttingDown[\s\S]*?except/u
  );
});
