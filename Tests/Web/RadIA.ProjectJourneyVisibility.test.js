const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const projectOpening = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'Integration', 'RadIA.OTA.ProjectOpening.pas'),
  'utf8'
);
const journeys = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'Core', 'RadIA.Core.Journeys.pas'),
  'utf8'
);

test('project transitions keep the RadIA chat visible', () => {
  const showCalls = projectOpening.match(/ShowRadIAChat;/gu) || [];
  assert.equal(showCalls.length, 2);
  assert.match(projectOpening, /if Result then\s+ShowRadIAChat;/u);
});

test('project creation requires explicit choices for optional features', () => {
  assert.match(journeys, /Never add tests or other optional project features/u);
  assert.match(journeys, /present explicit choices/u);
  assert.match(journeys, /only after the user explicitly selects or requests/u);
});
