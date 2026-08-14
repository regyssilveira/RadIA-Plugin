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
