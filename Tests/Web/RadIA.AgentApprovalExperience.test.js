const assert = require('node:assert/strict');
const fs = require('node:fs');
const test = require('node:test');

const presenter = fs.readFileSync('Source/UI/RadIA.UI.ChatPresenter.pas', 'utf8');
const chatScript = fs.readFileSync('Source/UI/Web/chat.js', 'utf8');
const readme = fs.readFileSync('README.md', 'utf8');

test('awaiting approval keeps the actionable agent card visible', () => {
  assert.match(
    presenter,
    /if AResult\.Status <> asAwaitingApproval then[\s\S]*PostToWebView/u
  );
  assert.match(chatScript, /select Approve plan or type \/agent resume/u);
  assert.match(chatScript, /'Approve plan',[\s\S]*'approve_agent'/u);
});

test('first README reading compares modes and project requirements', () => {
  assert.match(readme, /## Qual modo usar\?/u);
  assert.match(readme, /Agent \+ RadIA native/u);
  assert.match(readme, /Precisa abrir um projeto\?/u);
  assert.match(presenter, /### Which mode should I use\?/u);
});
