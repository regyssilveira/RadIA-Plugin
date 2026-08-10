const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const currentDirectory = path.resolve('Tests', 'Web');
const chatScript = fs.readFileSync(
  path.resolve(currentDirectory, '../../Source/UI/Web/chat.js'),
  'utf8'
);
const chatStyles = fs.readFileSync(
  path.resolve(currentDirectory, '../../Source/UI/Web/chat.css'),
  'utf8'
);

test('visual runtime card renders only local PNG data URLs', () => {
  assert.match(chatScript, /function renderVisualRuntimeSession\(data\)/u);
  assert.match(chatScript, /startsWith\('data:image\/png;base64,'\)/u);
  assert.match(chatScript, /case 'visual_runtime_session'/u);
  assert.doesNotMatch(chatScript, /visual-runtime-capture[\s\S]{0,500}innerHTML/u);
});

test('visual runtime card exposes before, after, state, and timeline', () => {
  assert.match(chatScript, /capture\.phase === 'after' \? 'After' : 'Before'/u);
  assert.match(chatScript, /visual-runtime-state/u);
  assert.match(chatScript, /visual-runtime-timeline/u);
  assert.match(chatStyles, /\.visual-runtime-captures/u);
  assert.match(chatStyles, /grid-template-columns: repeat\(auto-fit/u);
});
