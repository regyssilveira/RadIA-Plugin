const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const projectOpeningSource = fs.readFileSync(
  path.join('Source', 'Integration', 'RadIA.OTA.ProjectOpening.pas'),
  'utf8'
);

test('project opening waits until the generated project belongs to the IDE', () => {
  assert.match(
    projectOpeningSource,
    /function TRadIAOTAProjectOpeningFacade\.WaitForProjectOpen[\s\S]*?IsProjectOpenOnMainThread/u
  );
  assert.match(
    projectOpeningSource,
    /function TRadIAOTAProjectOpeningFacade\.OpenProject[\s\S]*?WaitForProjectOpen\(AProjectFileName\)/u
  );
});

test('project readiness compares the registered project path', () => {
  assert.match(
    projectOpeningSource,
    /LProjectGroup\.Projects\[LIndex\][\s\S]*?SameFileName\(LProject\.FileName, AProjectFileName\)/u
  );
});
