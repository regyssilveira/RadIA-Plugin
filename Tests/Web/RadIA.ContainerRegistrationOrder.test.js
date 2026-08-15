const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = fs.readFileSync(
  path.resolve('Source/Integration/RadIA.OTA.Register.pas'),
  'utf8'
);

test('DEXT form modernization resolves the DFM auditor only after registration', () => {
  const auditorRegistration = source.indexOf(
    'TRadIAContainer.Register<IRadIADfmPasAuditor>'
  );
  const modernizationRegistration = source.indexOf(
    'TRadIAContainer.Register<IRadIADextFormModernizationService>'
  );

  assert.ok(auditorRegistration >= 0);
  assert.ok(modernizationRegistration > auditorRegistration);
});

test('installers re-enable an exact RadIA package disabled after a failed startup', () => {
  const installers = [
    fs.readFileSync(path.resolve('build.ps1'), 'utf8'),
    fs.readFileSync(path.resolve('scripts/Install-RadIA.Package.ps1'), 'utf8')
  ];

  installers.forEach(installer => {
    assert.match(installer, /Disabled Packages/u);
    assert.match(
      installer,
      /Remove-ItemProperty[\s\S]*?-Name \$targetBpl/u
    );
  });
});

test('project-transition smoke reaches structured evidence generation', () => {
  const smoke = fs.readFileSync(
    path.resolve('scripts/Test-RadIA.KnowledgeNotifierSmoke.ps1'),
    'utf8'
  );
  const transitionBlock = smoke.match(
    /if \(\$ExerciseProjectTransition\) \{[\s\S]*?\n    \}/u
  );

  assert.ok(transitionBlock);
  assert.doesNotMatch(transitionBlock[0], /\breturn\b/iu);
  assert.match(smoke, /if \(-not \$ExerciseProjectTransition\) \{/u);
});
