const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve('.');
const configForm = fs.readFileSync(
  path.join(root, 'Source', 'UI', 'RadIA.UI.ConfigForm.dfm'),
  'utf8'
);
const configFrame = fs.readFileSync(
  path.join(root, 'Source', 'UI', 'RadIA.UI.ConfigFrame.dfm'),
  'utf8'
);
const configPresenter = fs.readFileSync(
  path.join(root, 'Source', 'UI', 'RadIA.UI.ConfigPresenter.pas'),
  'utf8'
);

test('settings window can be resized without shrinking below its safe layout', () => {
  assert.match(configForm, /BorderStyle = bsSizeable/u);
  assert.match(configForm, /Constraints\.MinHeight = 559/u);
  assert.match(configForm, /Constraints\.MinWidth = 856/u);
});

test('OpenAI separates API billing from ChatGPT Pro transport', () => {
  assert.match(configFrame, /'API Key \(BYOK\)'/u);
  assert.match(configFrame, /'ChatGPT Pro via Codex CLI'/u);
  assert.doesNotMatch(configFrame, /RadIA OAuth/u);
  assert.doesNotMatch(configFrame, /Codex CLI OAuth/u);
  assert.match(configPresenter, /SetProviderAuthType\('OpenAI', 'oauth_cli'\)/u);
});
