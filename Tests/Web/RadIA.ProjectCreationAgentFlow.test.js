const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const navigationTools = fs.readFileSync(
  path.join('Source', 'Core', 'RadIA.Core.IDENavigationTools.pas'),
  'utf8'
);
const journeys = fs.readFileSync(
  path.join('Source', 'Core', 'RadIA.Core.Journeys.pas'),
  'utf8'
);
const presenter = fs.readFileSync(
  path.join('Source', 'UI', 'RadIA.UI.ChatPresenter.pas'),
  'utf8'
);
const e2e = fs.readFileSync(
  path.join('scripts', 'Test-RadIA.KnowledgeNotifierSmoke.ps1'),
  'utf8'
);

test('IDE navigation does not require consent for read-only editor movement', () => {
  for (const tool of [
    'NavigateToFile',
    'NavigateToSymbol',
    'NavigateToDevelopmentSurface'
  ]) {
    assert.match(
      navigationTools,
      new RegExp(`${tool}[\\s\\S]*?trReadOnly`, 'u')
    );
  }
});

test('project creation receives a journey-specific step budget', () => {
  assert.match(
    presenter,
    /AObjective\.Contains\([\s\S]*?Create a Delphi project from the user requirements\.[\s\S]*?LAgentMaxSteps := 40/u
  );
  assert.match(presenter, /LAgentMaxSteps := 20/u);
});

test('project creation contract orders creation, opening, indexing and reading', () => {
  assert.match(
    journeys,
    /Do not call NavigateToFile[\s\S]*?CreateProjectFromTemplate and OpenCreatedProject succeed/u
  );
  assert.match(
    journeys,
    /GetKnowledgeStatus[\s\S]*?project index is ready/u
  );
});

test('real IDE E2E navigates without consent and waits for knowledge readiness', () => {
  assert.match(
    e2e,
    /OpenCreatedProject[\s\S]*?Invoke-RadIATool `[\s\S]*?NavigateToFile/u
  );
  assert.doesNotMatch(e2e, /immediateNavigation = Invoke-RadIAToolWithConsent/u);
  assert.match(
    e2e,
    /NavigateToFile[\s\S]*?GetKnowledgeStatus[\s\S]*?fileCount[\s\S]*?GetKnowledgeDocument/u
  );
  assert.match(e2e, /unexpectedly waited for consent/u);
});
