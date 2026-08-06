const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const documentationRoot = path.join(repositoryRoot, 'docs');

function markdownFiles(directory) {
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const entryPath = path.join(directory, entry.name);
    if (entry.isDirectory()) {
      return markdownFiles(entryPath);
    }
    return entry.isFile() && entry.name.endsWith('.md') ? [entryPath] : [];
  });
}

const files = [
  path.join(repositoryRoot, 'README.md'),
  ...markdownFiles(documentationRoot)
];
const mojibakePattern = /[\u00c3\u00c2\ufffd]|\u00e2[\u0080-\u00bf]/u;
const markdownLinkPattern = /!?\[[^\]]*\]\((?<target>[^)]+)\)/gu;

test('documentation has no common mojibake markers', () => {
  files.forEach(fileName => {
    const content = fs.readFileSync(fileName, 'utf8');
    assert.doesNotMatch(content, mojibakePattern, path.relative(repositoryRoot, fileName));
  });
});

test('documentation local links resolve to existing paths', () => {
  files.forEach(fileName => {
    const content = fs.readFileSync(fileName, 'utf8');
    for (const match of content.matchAll(markdownLinkPattern)) {
      let target = match.groups.target.trim();
      if (target.startsWith('<') && target.endsWith('>')) {
        target = target.slice(1, -1);
      }
      target = target.split('#', 1)[0];
      if (!target || /^[a-z][a-z0-9+.-]*:/iu.test(target)) {
        continue;
      }
      const resolved = path.resolve(path.dirname(fileName), decodeURIComponent(target));
      assert.ok(
        fs.existsSync(resolved),
        `${path.relative(repositoryRoot, fileName)} references missing path: ${target}`
      );
    }
  });
});
