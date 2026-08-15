const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const registerSource = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'Integration', 'RadIA.OTA.Register.pas'),
  'utf8'
);

test('Delphi Tools menu exposes one RadIA root submenu', () => {
  assert.match(registerSource, /LRadIAMenu\.Name := 'mnuRadIAToolsRoot'/u);
  assert.match(registerSource, /LRadIAMenu\.Caption := 'RadIA'/u);
  assert.match(registerSource, /LHook\.PopulateToolsMenu\(LRadIAMenu\)/u);
  assert.match(registerSource, /LRadIAMenu\.Add\(LProjectWizardItem\)/u);
  assert.match(registerSource, /LRadIAMenu\.Add\(LExtensionManagerItem\)/u);
});

test('RadIA root submenu is removed as one owned menu tree', () => {
  assert.match(
    registerSource,
    /SameText\(LItem\.Name, 'mnuRadIAToolsRoot'\)/u
  );
});
