const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const repositoryRoot = path.resolve('.');
const sourceRoot = path.join(repositoryRoot, 'Source');

function readSource(...segments) {
  return fs.readFileSync(path.join(sourceRoot, ...segments), 'utf8');
}

const modelCatalog = readSource('Core', 'RadIA.Core.Types.pas');
const configDefaults = readSource('Core', 'RadIA.Core.ConfigDefaults.pas');
const azureProvider = readSource('Providers', 'RadIA.Provider.AzureOpenAI.pas');
const bedrockProvider = readSource('Providers', 'RadIA.Provider.Bedrock.pas');
const copilotProvider = readSource('Providers', 'RadIA.Provider.GithubCopilot.pas');
const openAIProvider = readSource('Providers', 'RadIA.Provider.OpenAI.pas');

test('first-party fallback catalog uses the current stable model families', () => {
  assert.match(modelCatalog, /gpt-5\.6-(?:sol|terra|luna)/u);
  assert.match(modelCatalog, /gemini-3\.6-flash/u);
  assert.match(modelCatalog, /claude-sonnet-5/u);
  assert.match(configDefaults, /Result := 'gemini-3\.6-flash'/u);
});

test('selectable fallbacks do not expose retired legacy model families', () => {
  const selectableFallbacks = [
    modelCatalog,
    configDefaults,
    azureProvider,
    bedrockProvider,
    copilotProvider
  ].join('\n');

  assert.doesNotMatch(selectableFallbacks, /gpt-3\.5|gpt-4(?:o)?['"]/u);
  assert.doesNotMatch(selectableFallbacks, /gemini-1\.5/u);
  assert.doesNotMatch(selectableFallbacks, /claude-3(?:-|')/u);
});

test('ChatGPT OAuth discovers models from Codex before using fallbacks', () => {
  assert.match(openAIProvider, /'app-server'/u);
  assert.match(openAIProvider, /"method":"model\/list"/u);
  assert.doesNotMatch(openAIProvider, /compatible model \(gpt-5\.4/u);
});
