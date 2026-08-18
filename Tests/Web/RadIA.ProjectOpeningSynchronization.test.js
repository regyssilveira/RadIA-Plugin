const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const projectOpeningSource = fs.readFileSync(
  path.join('Source', 'Integration', 'RadIA.OTA.ProjectOpening.pas'),
  'utf8'
);
const integrationSmokeSource = fs.readFileSync(
  path.join('scripts', 'Test-RadIA.KnowledgeNotifierSmoke.ps1'),
  'utf8'
);
const integrationGateSource = fs.readFileSync(
  path.join('scripts', 'Test-RadIA.ProjectCreationNavigation.ps1'),
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

test('IDE integration navigates immediately after opening a generated project', () => {
  assert.match(
    integrationSmokeSource,
    /OpenCreatedProject[\s\S]*?Invoke-RadIATool `[\s\S]*?NavigateToFile[\s\S]*?generatedFormSourcePath/u
  );
  assert.doesNotMatch(
    integrationSmokeSource,
    /immediateNavigation = Invoke-RadIAToolWithConsent/u
  );
  assert.match(
    integrationSmokeSource,
    /NavigateToFile[\s\S]*?GetKnowledgeStatus[\s\S]*?fileCount[\s\S]*?Get-RadIAKnowledgeDocumentWhenReady/u
  );
  assert.match(
    integrationSmokeSource,
    /function Get-RadIAKnowledgeDocumentWhenReady[\s\S]*?-Name "GetKnowledgeDocument"/u
  );
  assert.match(integrationSmokeSource, /unexpectedly waited for consent/u);
  assert.match(integrationGateSource, /SkipTemplateBuild/u);
  assert.match(integrationGateSource, /SkipBuildAndTests/u);
});
