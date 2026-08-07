const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const notifierSource = fs.readFileSync(
  path.join('Source', 'Integration', 'RadIA.OTA.DebugTimeline.pas'),
  'utf8'
);

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

test('transient process properties have initializing-safe fallbacks', () => {
  assert.match(notifierSource, /function TRadIAOTADebugTimelineNotifier\.ProcessId[\s\S]*?except[\s\S]*?Result := 0/u);
  assert.match(notifierSource, /function TRadIAOTADebugTimelineNotifier\.RuntimeProcessId[\s\S]*?except[\s\S]*?Result := 0/u);
  assert.match(notifierSource, /function TRadIAOTADebugTimelineNotifier\.ProcessState[\s\S]*?Result := 'initializing'/u);
});
