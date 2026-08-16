const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const chatScript = fs.readFileSync('Source/UI/Web/chat.js', 'utf8');
const chatStyle = fs.readFileSync('Source/UI/Web/chat.css', 'utf8');
const tools = fs.readFileSync('Source/Core/RadIA.Core.LocalDatabaseTools.pas', 'utf8');
const service = fs.readFileSync('Source/Core/RadIA.Core.LocalDatabase.pas', 'utf8');
const guide = fs.readFileSync('docs/guides/local_database.md', 'utf8');
const englishGuide = fs.readFileSync('docs/guides/local_database.en.md', 'utf8');

test('local database tools remain workspace-local and read-only', () => {
  assert.match(tools, /InspectLocalSQLiteDatabase/u);
  assert.match(tools, /PreviewLocalSQLiteQuery/u);
  assert.match(tools, /FBoundary\.ValidatePath/u);
  assert.match(tools, /\.db', '\.sqlite', '\.sqlite3'/u);
  assert.match(service, /SQLITE_OPEN_READONLY/u);
  assert.match(service, /PRAGMA query_only=ON/u);
  assert.match(service, /sqlite3_stmt_readonly/u);
  assert.match(service, /CMaximumRows = 500/u);
});

test('database query UI paginates and renders untrusted values as text', () => {
  assert.match(chatScript, /function renderLocalDatabaseQuery/u);
  assert.match(chatScript, /const pageSize = 25/u);
  assert.match(chatScript, /cell\.textContent = value === null/u);
  assert.doesNotMatch(
    chatScript.match(/function renderLocalDatabaseQuery[\s\S]*?\n\}/u)?.[0] || '',
    /innerHTML/u
  );
  assert.match(chatScript, /Copy sanitized CSV/u);
  assert.match(chatStyle, /\.database-grid-viewport/u);
  assert.match(chatStyle, /max-height: 420px/u);
});

test('database previews redact secrets before grid and CSV serialization', () => {
  assert.match(service, /IsSensitiveColumn/u);
  assert.match(service, /\[redacted\]/u);
  assert.match(service, /exportSanitized/u);
  assert.match(service, /BuildCsv\(LColumns, LRows\)/u);
  assert.match(service, /\[binary %d bytes\]/u);
});

test('local database journey documents activation, consent, and limits', () => {
  for (const content of [guide, englishGuide]) {
    assert.match(content, /InspectLocalSQLiteDatabase/u);
    assert.match(content, /PreviewLocalSQLiteQuery/u);
    assert.match(content, /500/u);
    assert.match(content, /consent|consentimento/iu);
    assert.match(content, /workspace/iu);
    assert.match(content, /redact|sanitiz|sensíveis/iu);
  }
});
