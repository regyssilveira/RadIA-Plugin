# Post-2.0 goal — Autonomous runtime failure reproduction

> **Status:** in execution; M0–M2 implemented with in-IDE validation pending, M3 is next.
> **Target version:** 2.1.0.
> **Scope:** Delphi 12 Win32 and Delphi 13 Win32/IDE64.
> **Plan paused during this goal:** [CLI continuity and advanced integration](competitive_leadership_plan.en.md).

## Goal

Enable RadIA to build an application, start it through the IDE debugger, execute a bounded visual
scenario, capture the failure and its context, propose a fix, rebuild, and replay the scenario to
prove the result.

The reference case is an Access Violation with no apparent cause when a form is opened or cancelled.
The complete flow must produce reproducible evidence, preserve user consent, and interact only with
the process started by the current debugging session.

## Current state

RadIA can already:

- build projects and run DUnitX tests;
- start, pause, continue, and stop a debugging session;
- step through code, manage breakpoints, and evaluate expressions;
- inspect debugger state, call stack, and timeline;
- prepare reviewable changes and rebuild after consent.

It cannot yet:

- discover forms and controls in the running application;
- invoke buttons, fill fields, or cancel a modal window;
- wait for visual events and correlate them with debugger events;
- record and replay a visual scenario as regression evidence;
- complete the reproduce, diagnose, fix, and verify loop end to end.

## Security boundaries

- Automation may access only the process started by the current debugger and its descendants.
- PID, creation time, executable, project, and build must be correlated before any action.
- No tool will accept an arbitrary window handle or global desktop coordinates.
- Selectors must use stable identity: class, name, text, Automation ID, and hierarchy.
- Every scenario has a preview, consent, timeout, action limit, and immediate cancellation.
- Password fields are never read, persisted, or included in evidence.
- Logs and captures follow the existing sensitive-data redaction policy.
- Closing the IDE, project, or debugger cancels automation without leaving orphan processes.

## Out of scope

- generic desktop automation or automation of third-party applications;
- execution in production processes or processes not started by the current session;
- bypassing UAC, session isolation, or other Windows protections;
- screen coordinates as the primary mechanism;
- replacing unit tests with visual tests;
- code injection into the application as an initial requirement.

## Proposed architecture

The core receives a neutral `IRadIARuntimeAutomationFacade`. OTA integration correlates project,
build, session, and process. A Windows adapter combines UI Automation with Win32 discovery for
windowed VCL controls. VCL controls without handles report their capability as unavailable; an
optional test probe is considered only after this gap is measured.

The planned high-level tools are:

| Tool | Responsibility |
|---|---|
| `GetRuntimeWindows` | List only windows owned by the current debugging session. |
| `GetRuntimeControlTree` | Return a sanitized control tree and stable selectors. |
| `PrepareRuntimeScenario` | Validate actions, risks, limits, and consent before execution. |
| `RunRuntimeScenario` | Execute a bounded declarative script in the authorized process. |
| `CancelRuntimeScenario` | Immediately stop the current script. |
| `GetRuntimeScenarioStatus` | Return script actions, waits, failures, and evidence. |
| `WaitForDebuggerEvent` | Await exception, breakpoint, exit, or state changes without busy-wait. |
| `CaptureRuntimeEvidence` | Record a sanitized diagnostic and regression result. |

## Milestones

### M0 — Baseline, contracts, and laboratory application

Details and matrix: [M0 baseline](runtime_debug_automation_m0.en.md).

- map the existing build, debug, consent, and cancellation lifecycle;
- create a VCL test application with deterministic failure on form open and cancellation;
- define selector, action, assertion, result, capability, and evidence contracts;
- document the threat model and Delphi 12/13 matrix.

**Acceptance:** deterministic manual reproduction on all three targets and contracts covered by tests.

**Still missing:** event correlation, visual discovery, execution, correction, and replay.

### M1 — Debugger correlation and waiting

Implementation and evidence: [M1 correlation](runtime_debug_automation_m1.en.md).

- assign stable identities to the debugging session and debugged process;
- correlate exception, stack, module, project, build, and scenario;
- implement cancellation-aware waits for exception, breakpoint, exit, and window;
- respect timeout, IDE shutdown, and project changes.

**Acceptance:** the laboratory failure returns a structured exception and stack on all three targets.

**Still missing:** control discovery, UI interaction, and scenario replay.

### M2 — Safe runtime discovery

Implementation and evidence: [Safe discovery M2](runtime_debug_automation_m2.en.md).

- list only windows from the authorized process and its descendants;
- expose hierarchy, modal state, owner, class, name, text, and control capabilities;
- produce stable selectors and report ambiguities;
- reject every process or window outside the session.

**Acceptance:** find the main form, target form, open and cancel actions, and prove rejection of an
external window.

**Still missing:** action execution, correction integration, and regression generation.

### M3 — Bounded declarative execution

- support invoke, click, fill, select, close, cancel, wait, and assert;
- require preview and consent before scenario execution;
- enforce action, time, and repetition limits plus a visible emergency stop;
- reject coordinates by default and diagnose controls that cannot be automated.

**Acceptance:** open and cancel the target form, trigger the deterministic failure, and never touch
an external window.

**Still missing:** closing the correction loop and turning reproduction into regression.

### M4 — Diagnose, fix, and replay

- integrate the scenario with `/journey debug`;
- build, start, execute, await the exception, and collect state, stack, and expressions;
- prepare a diff with hypothesis and evidence, preserving consent for every mutation;
- rebuild, replay the same scenario, and compare results.

**Acceptance:** a fix removes the Access Violation and the same scenario finishes without exception
on all three targets, with a complete consent trail.

**Still missing:** hardening, versioned regression, and a delivery gate.

### M5 — Regression, evidence, and gate

- generate a DUnitX test when the cause can be isolated;
- preserve a runtime scenario when the failure depends on the visual lifecycle;
- run ten consecutive cycles per target without fluctuation or orphan processes;
- validate accessibility, cancellation, shutdown, audit, tests, and SonarQube;
- document usage, limitations, troubleshooting, and complete examples.

**Acceptance:** a green Delphi 12/13 matrix, versioned scenario, reproducible evidence, and an
approved quality gate.

**Still missing:** nothing in this goal; the frozen plan can resume at Phase 0.

## Implementation order by complexity

| Order | Delivery | Complexity |
|---:|---|---|
| 1 | M0 — contracts and laboratory | Low |
| 2 | M1 — correlation and waiting | Medium |
| 3 | M2 — runtime discovery | High |
| 4 | M3 — safe execution | High |
| 5 | M4 — complete autonomous loop | Very high |
| 6 | M5 — regression and hardening | High |

## Definition of done

The goal is complete only when a user can describe the path to a failure, review the scenario, and
authorize RadIA to:

1. build and start the application under the debugger;
2. reproduce the issue without interacting with other applications;
3. capture exception, stack, state, and sufficient evidence;
4. propose a reviewable change;
5. rebuild and replay exactly the same scenario;
6. prove the failure is absent and leave an executable regression.

After M5, resume the CLI continuity plan at Phase 0 without changing its frozen scope.
