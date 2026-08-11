# Release notes - RadIA 2.6.2

> **Status:** prepared on August 11, 2026 to stabilize the Delphi 12 and 13 test experience.

RadIA 2.6.2 is a patch release focused on chat usability, agent-driven project creation, and
installed-version diagnostics.

## Fixes

- the editor context menu shows RadIA actions at the top again without depending on third-party menu
  initialization order;
- long chat lists and selectors now expose wider clickable scrollbars;
- prompts sent from the editor menu preserve fenced Markdown blocks with Pascal highlighting;
- primary windows show the version in their captions, such as `Rad IA Chat v2.6.2`;
- natural project creation recognizes requests such as "make a basic calculator";
- generated projects use `$(BDS)\lib\$(Platform)\release` and include DUnitX when needed,
  avoiding `F1027 unit System not found` on clean installations;
- the generated-project smoke uses the current DUnitX runner options.

## Compatibility

- Delphi 12 Win32 installed for local testing;
- Delphi 13 Win32 installed for local testing;
- Delphi 13 IDE64 installed for local testing;
- operational catalog preserved with 132 tools.

## Release validation

- `npm run test:web`: 101 tests passed;
- `npm run lint`: no errors;
- `scripts\Test-RadIA.GeneratedProjects.ps1 -DelphiVersion "37.0" -SkipDext`: 11 generated
  projects passed and 5 calculator DUnitX tests passed;
- `build.ps1 -DelphiVersion "37.0" -Release -Test`: build, coverage, and tests passed.
