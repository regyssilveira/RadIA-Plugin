# Release notes — RadIA 2.6.0

> **Status:** approved for publication after all gates passed.

RadIA 2.6.0 closes the loop for creating a Delphi application from natural language. The acceptance
scenario creates a VCL calculator with no open project, preserves destination, name, and platform,
requests approval before changing files, opens and builds the project, runs DUnitX tests, and
validates the UI under the IDE debugger.

## Main deliveries

- deterministic VCL calculator template with isolated logic;
- companion DUnitX project generated with the application;
- five tests for addition, subtraction, multiplication, division, and division by zero;
- native journey that infers destination, name, platform, and project specification;
- application and test builds through IDE integration;
- generated test execution through `RunDUnitXTests`;
- debugging with correlated session, breakpoint, call stack, and timeline;
- safe discovery of the calculator window and its 18 controls;
- consented functional test that runs `2 + 3 =` and confirms `5` in the display;
- reproducible matrix for Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64.
- operational catalog synchronized with all 132 tools registered at runtime.

## Compatibility

- Delphi 12 Athens, Win32 IDE;
- Delphi 13, Win32 IDE;
- Delphi 13, IDE64;
- Win32 generated projects in the acceptance scenario.

## Release validation

Every gate in the [2.6.0 audit](release_audit_2.6.0.en.md) passed on a clean tree.
