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
const ideSmoke = fs.readFileSync(
  path.join(repositoryRoot, 'scripts', 'Test-RadIA.IDESmoke.ps1'),
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

test('native desktop owns docking while actual window messages persist user intent', () => {
  assert.match(
    dockableForm,
    /AMessage\.Msg = CM_SHOWINGCHANGED[\s\S]*SaveVisibility\(FForm\.Visible\)/u
  );
  assert.match(
    dockableForm,
    /AMessage\.Msg = WM_EXITSIZEMOVE[\s\S]*SavePersistedBounds/u
  );
  assert.match(
    dockableForm,
    /PrepareDockableFormsForShutdown[\s\S]*PersistCurrentState[\s\S]*ReleaseForm/u
  );
  assert.match(register, /DockableForm\.RestoreDockableFormVisibility/u);
  assert.match(
    dockableForm,
    /if not FHasSavedWindowState then[\s\S]*LoadPersistedBounds/u
  );
});

test('native host state is observed even when OTA suppresses form messages', () => {
  assert.match(
    dockableForm,
    /FTimer\.Interval := 500;[\s\S]*FTimer\.OnTimer := TimerEvent/u
  );
  assert.match(
    dockableForm,
    /SynchronizeCurrentState[\s\S]*FForm\.BoundsRect[\s\S]*FForm\.Visible/u
  );
  assert.match(
    dockableForm,
    /procedure TRadIACustomDockableForm\.FormRemoved;[\s\S]*SavePersistedBounds;[\s\S]*SaveVisibility\(False\)/u
  );
});

test('dockable forms register directly during the package Register procedure', () => {
  assert.match(
    register,
    /procedure Register;[\s\S]*DockableForm\.RegisterDockableForm;[\s\S]*LWizardServices\.AddWizard/u
  );
  assert.doesNotMatch(
    register,
    /constructor TRadIAWizard\.Create;[\s\S]*DockableForm\.RegisterDockableForm/u
  );
});

test('real IDE smoke rejects automatic chat opening from a hidden state', () => {
  assert.match(ideSmoke, /\[switch\]\$ExpectDockHidden/u);
  assert.match(
    ideSmoke,
    /if \(\$ExpectDockHidden\)[\s\S]*Get-RadIADockInfo[\s\S]*opened despite the persisted hidden state/u
  );
});
