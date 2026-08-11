# Goal 2.6 — complete development loop

> **Status:** in progress on the `develop` branch.
> **Target version:** 2.6.0.
> **Matrix:** Delphi 12 Win32 and Delphi 13 Win32/IDE64.

## Required outcome

Version 2.6.0 is ready only when RadIA can receive a prompt with no project open and, with clear
user consent:

1. infer or request only the genuinely missing requirements;
2. show a reviewable preview and create the project atomically;
3. open the created project in the IDE;
4. build and repair errors from real Delphi compiler messages;
5. start the application through the IDE debugger and observe its state;
6. exercise the primary functional scenario and record the result;
7. generate and run relevant DUnitX tests;
8. provide build, debugging, behavior, and test evidence without claiming success from generated text.

The minimum acceptance scenario is a VCL calculator created from natural language. The flow must
validate all four operations, division by zero, application build, debugger execution, functional
UI, and a DUnitX suite with no failures or leaks.

## Internal milestones

All milestones belong to version 2.6.0 and are not intermediate public releases.

| Milestone | Delivery | Status |
|---|---|---|
| M0 | Session, security, consent, and evidence contracts | Pending |
| M1 | Safe inspection of windows and controls in the debugged application | Pending |
| M2 | Safe and cancellable control interaction | Pending |
| M3 | Failure reproduction, diagnosis, repair, and revalidation | Pending |
| M4 | Prompt-driven calculator with build, debug, UI test, and DUnitX | In progress; technical matrix proven |
| M5 | Deeper semantic knowledge of Delphi projects | Pending |
| M6 | Unified inline experience and progressively disclosed options | Pending |
| M7 | SIXEL support in the integrated terminal | Pending |
| M8 | Generalization across supported templates | Pending |
| M9 | Deep Doctor, documentation, final matrix, and stabilization | Pending |

The current WebView remains unchanged. C++, Lazarus, marketplace distribution, signing, and
commercial installation are outside this goal.

## Evidence already obtained for M4

The deterministic calculator template now contains isolated logic and its own DUnitX suite.
`scripts/Test-RadIA.GeneratedProjects.ps1` proves, for each target:

- calculator prompt inference;
- transactional creation of the application and test project;
- successful compilation of both projects;
- UI execution producing `2 + 3 = 5`;
- five DUnitX tests for all operations and division by zero;
- structured output for the evidence matrix.

This evidence does not complete M4 yet. The same flow must still run through a real RadIA session
from the conversation surface without the harness invoking tools directly.

The real harness has already proven on Delphi 12 Win32 and Delphi 13 Win32/IDE64 that RadIA creates
and opens the calculator, builds the application and companion DUnitX project through the IDE, runs
all five tests through `RunDUnitXTests`, starts under the debugger, captures session, stack, and
timeline data, and shuts down without stale discovery. A presenter test separately proves that the
natural-language prompt starts the correct guided journey.

## Final 2.6.0 gates

- RadIA builds and DUnitX pass on all three targets with no leaks;
- the prompt-started calculator flow passes on all three targets;
- the generated application is opened, built, and started through the IDE debugger;
- UI behavior and unit tests pass with reproducible evidence;
- Web tests, ESLint, and documentation tests pass;
- SonarQube Quality Gate passes with no new issues;
- installation, update, repair, and removal pass on Delphi 12 and 13;
- PT/EN documentation is audited for versions, links, clarity, discoverability, mojibake, and obsolete content;
- `develop` is integrated into `main` only after every gate passes.
