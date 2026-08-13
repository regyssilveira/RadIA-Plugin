const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const presenter = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.ChatPresenter.pas'),
  'utf8'
);

const helpTargets = [
  ['CReferenceRoot', 'slash_commands.md', 'docs/reference/slash_commands.md'],
  ['CGuidesRoot', 'user_guide_journeys.md', 'docs/guides/user_guide_journeys.md'],
  ['CGuidesRoot', 'user_guide_dext_journeys.md', 'docs/guides/user_guide_dext_journeys.md'],
  ['CReferenceRoot', 'settings_reference.md', 'docs/reference/settings_reference.md'],
  ['CGuidesRoot', 'hierarchical_settings.md', 'docs/guides/hierarchical_settings.md']
];

test('every integrated help link targets an existing public document', () => {
  helpTargets.forEach(([root, fileName, localPath]) => {
    assert.ok(presenter.includes(`${root} + '${fileName}`), `${root}/${fileName}`);
    assert.ok(fs.existsSync(path.join(repositoryRoot, localPath)), localPath);
  });
  assert.doesNotMatch(presenter, /CDocsRoot/u);
});
