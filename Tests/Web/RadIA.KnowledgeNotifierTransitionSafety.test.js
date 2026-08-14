const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const notifierSource = fs.readFileSync(
  path.join('Source', 'Integration', 'RadIA.OTA.KnowledgeNotifier.pas'),
  'utf8'
);
const transitionSmokeSource = fs.readFileSync(
  path.join('scripts', 'Test-RadIA.KnowledgeNotifierSmoke.ps1'),
  'utf8'
);
const releaseProcessSource = fs.readFileSync(
  path.join('docs', 'development', 'release_process.md'),
  'utf8'
);

test('module replacement cannot insert a duplicate attachment key', () => {
  assert.match(
    notifierSource,
    /LNotifierIndex := AModule\.AddNotifier\(ANotifier\);[\s\S]*?FAttachments\.AddOrSetValue/u
  );
  assert.doesNotMatch(
    notifierSource,
    /LNotifierIndex := AModule\.AddNotifier\(ANotifier\);[\s\S]*?FAttachments\.Add\(/u
  );
});

test('knowledge timer blocks reentry and contains transient OTA failures', () => {
  assert.match(
    notifierSource,
    /procedure TRadIAOTAKnowledgeNotifier\.TimerEvent[\s\S]*?if FRefreshing then[\s\S]*?FRefreshing := True/u
  );
  assert.match(
    notifierSource,
    /RefreshAttachments;[\s\S]*?Knowledge attachment refresh failed/u
  );
  assert.match(
    notifierSource,
    /finally[\s\S]*?FRefreshing := False/u
  );
});

test('release gate closes one generated project before opening another', () => {
  assert.match(
    transitionSmokeSource,
    /ExerciseProjectTransition[\s\S]*?RevertCreatedProject[\s\S]*?OpenCreatedProject[\s\S]*?NavigateToFile/u
  );
  assert.match(releaseProcessSource, /Test-RadIA\.KnowledgeProjectTransition\.ps1/u);
});
