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

test('HTTP client is registered before code validation tools resolve it', () => {
  const httpClientRegistration = source.indexOf(
    'TRadIAContainer.Register<IRadIAHttpClient>'
  );
  const codeValidationRegistration = source.indexOf(
    'RegisterRadIACodeValidationTools('
  );

  assert.ok(httpClientRegistration >= 0);
  assert.ok(codeValidationRegistration > httpClientRegistration);
});

test('semantic routine service is registered before semantic tools resolve it', () => {
  const routineRegistration = source.indexOf(
    'TRadIAContainer.Register<IRadIASemanticRoutineService>'
  );
  const routineResolution = source.indexOf(
    'TRadIAContainer.Resolve<IRadIASemanticRoutineService>'
  );

  assert.ok(routineRegistration >= 0);
  assert.ok(routineResolution > routineRegistration);
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
