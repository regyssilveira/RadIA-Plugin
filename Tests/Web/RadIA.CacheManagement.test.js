const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');

test('cache manager exposes inspection and consented selective cleanup', () => {
  const form = fs.readFileSync(
    path.join(repositoryRoot, 'Source', 'UI', 'RadIA.UI.CacheManager.pas'),
    'utf8'
  );
  const menu = fs.readFileSync(
    path.join(repositoryRoot, 'Source', 'Integration', 'RadIA.OTA.EditorHook.pas'),
    'utf8'
  );

  assert.match(form, /ListCacheEntries/u);
  assert.match(form, /Remove selected/u);
  assert.match(form, /MessageDlg/u);
  assert.match(form, /rebuilt on demand/u);
  assert.match(menu, /Rad IA Cache Manager/u);
});
