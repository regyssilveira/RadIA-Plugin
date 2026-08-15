const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

const repositoryRoot = path.resolve('.');
const dockableForm = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'Integration', 'RadIA.OTA.DockableForm.pas'),
  'utf8'
);
const register = fs.readFileSync(
  path.join(repositoryRoot, 'Source', 'Integration', 'RadIA.OTA.Register.pas'),
  'utf8'
);

test('desktop-created native form is attached instead of duplicated', () => {
  assert.match(dockableForm, /FrameCreated[\s\S]*AttachNativeForm\(GetParentForm\(AFrame\)\)/u);
  assert.match(dockableForm, /FForm := AForm;[\s\S]*FForm\.FreeNotification\(FObserver\)/u);
});

test('saved desktop geometry is not overwritten by default dimensions', () => {
  assert.match(dockableForm, /FHasSavedWindowState := ADesktop\.SectionExists\(ASection\)/u);
  assert.match(
    dockableForm,
    /if not FHasSavedWindowState then[\s\S]*FForm\.Width := FDefaultWidth[\s\S]*FForm\.Height := FDefaultHeight/u
  );
});

test('visibility follows actual native form show and close events', () => {
  assert.doesNotMatch(register, /RestoreWindowVisibility/u);
  assert.match(
    dockableForm,
    /OnShow := FormShow;[\s\S]*OnClose := FormClose/u
  );
  assert.match(dockableForm, /FormShow[\s\S]*SaveVisibility\(True\)/u);
  assert.match(dockableForm, /FormClose[\s\S]*SaveVisibility\(False\)/u);
  assert.match(register, /DockableForm\.RestoreDockableFormVisibility/u);
});
