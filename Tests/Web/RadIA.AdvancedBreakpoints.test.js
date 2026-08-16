const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const root = path.resolve('.');
const core = fs.readFileSync(
  path.join(root, 'Source', 'Core', 'RadIA.Core.DebuggerBreakpointTools.pas'),
  'utf8'
);
const ota = fs.readFileSync(
  path.join(root, 'Source', 'Integration', 'RadIA.OTA.Debugger.pas'),
  'utf8'
);
const delphiTests = fs.readFileSync(
  path.join(root, 'Tests', 'Source', 'RadIA.Tests.DebuggerBreakpointTools.pas'),
  'utf8'
);

test('advanced breakpoint contract is bounded, consented, and reversible', () => {
  assert.match(core, /'ConfigureBreakpoint'/u);
  assert.match(core, /trReversibleWrite/u);
  assert.match(core, /"condition":\{"type":"string","maxLength":4096\}/u);
  assert.match(core, /"stackFrames":\{"type":"integer","minimum":0,"maximum":100\}/u);
  assert.match(core, /'previousConfiguration'/u);
  assert.match(core, /'inverseArguments'/u);
});

test('OTA uses native properties and exposes unsupported exception filters', () => {
  assert.match(ota, /ABreakpoint\.Expression := AConfiguration\.Condition/u);
  assert.match(ota, /ABreakpoint\.PassCount := AConfiguration\.HitCount/u);
  assert.match(ota, /ABreakpoint\.DoBreak := AConfiguration\.DoBreak/u);
  assert.match(ota, /ABreakpoint\.LogMessage := AConfiguration\.LogMessage/u);
  assert.match(core, /'exceptionFilters'/u);
  assert.match(core, /LCapabilities\.ExceptionFilters/u);
  assert.match(delphiTests, /ConfiguresAndRestoresAdvancedBreakpoint/u);
  assert.match(delphiTests, /ReportsAdvancedCapabilities/u);
});
