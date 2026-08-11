# Release audit 2.6.0

> **Status:** in progress. No pending item may be interpreted as approved.

## Functional gates

- [x] A complete prompt preserves destination, name, and platform and reaches approval before mutation.
- [x] The VCL calculator and companion DUnitX project are generated atomically.
- [x] The application and tests build through the IDE on all three targets.
- [x] Five generated DUnitX tests pass on all three targets.
- [x] The debugger provides a session, breakpoint, call stack, and timeline on all three targets.
- [x] The `2 + 3 = 5` visual scenario passes on all three targets.
- [x] The documentation catalog matches all 132 tools registered at runtime.
- [x] Final acceptance was repeated on the definitive 2.6.0 code; the final packages are bound to
  commit `d3d8187` with `sourceDirty=false`.

## Regression and quality gates

- [x] Complete build and 1,047 DUnitX tests on Delphi 12 Win32.
- [x] Complete build and 1,047 DUnitX tests on Delphi 13 Win32.
- [x] Complete build and 1,047 DUnitX tests on Delphi 13 IDE64.
- [x] 99 Web tests, ESLint, and 38 documentation tests pass.
- [x] Current SonarQube Quality Gate passes with 82.6% new-code coverage, 0.92% new duplication,
  and zero new violations.
- [x] All three DUnitX suites confirm no memory leaks.

## Distribution gates

- [x] The visual installer is created, validated, and intentionally unsigned under the project policy.
- [x] Installation passes on Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64.
- [x] Repair and removal pass on all three targets through the automated package lifecycle.
- [x] Release artifacts and hashes are verified in `release_evidence_2.6.0.json`.

Reproducible evidence for the `Uninstall` → `Install` → `Repair` → IDE startup cycles:

- `Output/Validation/Release2.6Install/Delphi12-Win32.json`;
- `Output/Validation/Release2.6Install/Delphi13-Win32.json`;
- `Output/Validation/Release2.6Install/Delphi13-IDE64.json`.

On each target, the installed BPL had the same SHA-256 as the BPL inside the proven package. The visual
installer requires the user to confirm the Windows UAC prompt; neither the project nor its tests automate
that operating-system permission.

## Documentation gate

- [x] The PT/EN audit covers all 214 tracked Markdown files.
- [x] The 38 documentation tests validate links, versions, discoverability, clarity, and mojibake.
- [x] README, manuals, installation, tools, commands, and notes are synchronized.
- [x] All 50 tracked JSON files under `docs` pass syntax parsing.

Primary navigation remains task-oriented. Historical references were consolidated under planning and
historical records without making old documents unreachable. Operational documentation uses version
2.6.0, the Delphi 12/13 matrix, and the generated catalog of 132 tools.

The analyzer ran with Delphi 12/`VER360`. The official script now explicitly overrides the selected
Delphi installation and compiler version instead of inheriting stale server settings.
