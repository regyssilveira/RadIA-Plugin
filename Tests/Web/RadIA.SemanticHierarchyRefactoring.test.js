const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve('.');
const toolSource = fs.readFileSync(
  path.join(root, 'Source', 'Core', 'RadIA.Core.SemanticRefactoringTools.pas'),
  'utf8'
);
const delphiTests = fs.readFileSync(
  path.join(root, 'Tests', 'Source', 'RadIA.Tests.SemanticRefactoring.pas'),
  'utf8'
);

test('hierarchy rename remains preview-only and explicitly scoped', () => {
  assert.match(toolSource, /"includeHierarchy":\{"type":"boolean"\}/u);
  assert.match(toolSource, /"container":\{"type":"string"\}/u);
  assert.match(toolSource, /"signature":\{"type":"string"\}/u);
  assert.match(toolSource, /FQueries\.FindReferences\(LId, False, 1000/u);
  assert.match(toolSource, /LPatchResult := FPatches\.Prepare\(LSpecs\)/u);
  assert.doesNotMatch(toolSource, /FPatches\.Apply\(/u);
});

test('Delphi regression covers apply, rollback, and ambiguous overload', () => {
  assert.match(delphiTests, /RenamesMemberAcrossClassHierarchy/u);
  assert.match(delphiTests, /RejectsAmbiguousHierarchyMemberOverload/u);
  assert.match(delphiTests, /LPatches\.Apply\(LPreviewId\)\.Success/u);
  assert.match(delphiTests, /LPatches\.Revert\(LPreviewId\)\.Success/u);
  assert.match(delphiTests, /hierarchy_precondition_failed/u);
});
