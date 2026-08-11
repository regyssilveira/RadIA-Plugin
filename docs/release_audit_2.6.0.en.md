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
- [ ] Final acceptance repeated on the definitive 2.6.0 commit with `sourceDirty=false`.

## Regression and quality gates

- [x] Complete build and 1,047 DUnitX tests on Delphi 12 Win32.
- [x] Complete build and 1,047 DUnitX tests on Delphi 13 Win32.
- [x] Complete build and 1,047 DUnitX tests on Delphi 13 IDE64.
- [x] 99 Web tests, ESLint, and 38 documentation tests pass.
- [ ] Current SonarQube Quality Gate passes with no new issues.
- [x] All three DUnitX suites confirm no memory leaks.

## Distribution gates

- [ ] The visual installer is created and validated.
- [ ] Installation and update pass on Delphi 12 and 13.
- [ ] Repair and removal pass.
- [ ] Release artifacts and hashes are verified.

## Documentation gate

- [ ] The PT/EN audit covers every tracked documentation file.
- [ ] Links, versions, discoverability, clarity, and mojibake pass validation.
- [ ] README, manuals, installation, tools, commands, and notes are synchronized.
