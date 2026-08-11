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
