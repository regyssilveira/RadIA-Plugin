const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const generatedProjectsScript = fs.readFileSync(
  path.join(repositoryRoot, 'scripts', 'Test-RadIA.GeneratedProjects.ps1'),
  'utf8'
);
const generatedProjectsEvidence = fs.readFileSync(
  path.join(repositoryRoot, 'scripts', 'New-RadIA.GeneratedProjectsEvidence.ps1'),
  'utf8'
);
const closureBaseline = JSON.parse(fs.readFileSync(
  path.join(repositoryRoot, 'docs', 'competitive_closure_baseline_2.7.json'),
  'utf8'
));
const promptMatrixScript = fs.readFileSync(
  path.join(repositoryRoot, 'scripts', 'Test-RadIA.NaturalProjectPrompts.ps1'),
  'utf8'
);

test('generated-project certification uses the supported DUnitX arguments', () => {
  assert.match(generatedProjectsScript, /"--hidebanner"/u);
  assert.match(generatedProjectsScript, /"--xmlfile:/u);
  assert.doesNotMatch(generatedProjectsScript, /"--no-logo"/u);
  assert.doesNotMatch(generatedProjectsScript, /"--xml=/u);
});

test('generated-project certification proves test counts and a clean source tree', () => {
  [
    'calculatorTestTotal -ne 5',
    'calculatorTestErrors -ne 0',
    'calculatorTestFailures -ne 0',
    'calculatorTestIgnored -ne 0',
    'sourceDirty = $sourceDirty'
  ].forEach(requirement => {
    assert.ok(
      generatedProjectsScript.includes(requirement),
      `Generated-project certification is missing ${requirement}`
    );
  });
  assert.match(generatedProjectsEvidence, /sourceDirty -eq \$false/u);
  assert.match(generatedProjectsEvidence, /calculatorUnitTests\.total -eq 5/u);
});

test('competitive closure baseline is fixed and contains only explicit gaps', () => {
  assert.equal(closureBaseline.targetVersion, '2.7.0');
  assert.deepEqual(
    closureBaseline.items.map(item => `${item.id}:${item.status}`),
    ['CC-01:passed', 'CC-02:passed', 'CC-03:passed', 'CC-04:passed']
  );
  assert.equal(closureBaseline.closureRule.open, 0);
  assert.ok(closureBaseline.permanentExclusions.includes('webview-replacement'));
  assert.ok(closureBaseline.permanentExclusions.includes('mandatory-cli-bundling'));
});

test('natural-project prompt evidence requires every template in both languages', () => {
  [
    'Console',
    'Vcl',
    'Fmx',
    'Library',
    'Package',
    'DUnitX',
    'Service'
  ].forEach(templateName => {
    assert.ok(promptMatrixScript.includes(`TestNatural${templateName}PromptPt`));
    assert.ok(promptMatrixScript.includes(`TestNatural${templateName}PromptEn`));
  });
  assert.match(promptMatrixScript, /sourceDirty = \$sourceDirty/u);
  assert.match(promptMatrixScript, /templateCount = 7/u);
});
