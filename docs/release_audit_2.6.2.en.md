# Release audit 2.6.2

> **Status:** approved on August 11, 2026 to stabilize testing on Delphi 12 and 13.

## Functional gates

- [x] The editor context menu includes RadIA actions at the top.
- [x] Long chat selectors and lists expose a visible wider scrollbar.
- [x] Prompts generated from the editor menu preserve code formatting.
- [x] Primary windows show the installed version in their captions.
- [x] The creation journey recognizes natural calculator requests.
- [x] Generated projects resolve the RTL through `$(BDS)` and include DUnitX when needed.
- [x] The operational catalog remains synchronized with all 132 tools registered at runtime.

## Regression and quality gates

- [x] `npm run test:web`: 101 tests passed.
- [x] `npm run lint`: no errors.
- [x] `scripts\Test-RadIA.GeneratedProjects.ps1 -DelphiVersion "37.0" -SkipDext`: 11 generated
  projects passed.
- [x] `build.ps1 -DelphiVersion "37.0" -Release -Test`: build, coverage, and tests passed.

## Documentation gate

- [x] `project_wizard.md` and `project_wizard.en.md` document the generated-project search path.
- [x] Release notes and this audit exist in Portuguese and English.
- [x] The main hubs point to release 2.6.2.
