# Autonomous Runtime Diagnostics

RadIA 2.1 can reproduce a visual failure in a VCL application started by the IDE debugger, capture
evidence, prepare a reviewable fix, rebuild, replay the scenario, and prove whether the failure was
removed.

## When to use it

Use this workflow for UI-dependent failures such as an Access Violation when a form is opened,
closed, or cancelled, a sequence-dependent error, an intermittent failure that needs deterministic
replay, or a regression that cannot be adequately isolated in a unit test.

When the cause can be isolated without the UI, also prefer a DUnitX test. Runtime scenarios
complement unit tests; they do not replace them.

## Requirements

- Delphi 12 Win32 or Delphi 13 Win32/IDE64;
- an active project that builds for Win32 or Win64;
- Agent Mode enabled through **Agent On/Off** or `/agent on`;
- consent enabled for build, debugger, runtime execution, and writes;
- a VCL application with windowed controls (`HWND`).

An MCP client can also drive the workflow. The same consent and security rules apply.

## Complete workflow

1. Describe the exact path to the failure and the expected outcome.
2. RadIA builds with `BuildProject` and starts the IDE debugger with `StartDebugging`.
3. `GetRuntimeDebugSession` correlates session, PID, creation time, executable, project, and build.
4. `GetRuntimeWindows` and `GetRuntimeControlTree` discover only authorized process elements.
5. `PrepareRuntimeScenario` creates a bounded, fingerprinted preview.
6. After consent, `RunRuntimeScenario` executes the script.
7. `CaptureRuntimeEvidence` records the exception, stack, state, and expressions.
8. RadIA prepares a hypothesis and diff; no change is applied without review.
9. After approval, the project is rebuilt and a new debug session starts.
10. The same scenario is replayed and `verification` evidence is captured.
11. `CompareRuntimeEvidence` requires the same project but distinct sessions and builds.
12. After `outcome=fixed`, the scenario can be saved and replayed as a regression.

## Example request

```text
/agent run Reproduce the Access Violation triggered by clicking
"Fail when form cancels" and then "Cancel". Capture the stack,
propose a fix, rebuild, replay the scenario, and leave a visual
regression with 10 repetitions.
```

The plan is shown before the first execution. Every risky tool keeps its own consent step.

## Tools

| Stage | Main tools |
|---|---|
| Build | `BuildProject`, `GetBuildStatus`, `CancelBuild` |
| Session | `StartDebugging`, `GetDebuggerState`, `GetRuntimeDebugSession`, `StopDebugging` |
| Discovery | `GetRuntimeWindows`, `GetRuntimeControlTree` |
| Scenario | `PrepareRuntimeScenario`, `RunRuntimeScenario`, `GetRuntimeScenarioStatus`, `CancelRuntimeScenario` |
| Evidence | `WaitForDebuggerEvent`, `CaptureRuntimeEvidence`, `CompareRuntimeEvidence` |
| Fix | `PreparePatch`, `ApplyPatch`, `RevertPatch` |
| Regression | `PrepareRuntimeRegression`, `SaveRuntimeRegression`, `ListRuntimeRegressions`, `PrepareSavedRuntimeScenario` |

See the [operational tool reference](internal_tools_reference.md) and the
[generated catalog](runtime_tool_catalog.md).

## Scenarios and selectors

A scenario defines a name, limits, and actions. Supported actions are `invoke`, `setValue`,
`select`, `close`, `cancel`, `wait`, and `assert`. Targets use stable identity such as class, text,
Automation ID, and hierarchy path.

Targets that appear only after an earlier action are resolved during execution. When Delphi 13
IDE64 controls a Win32 application, Windows may not expose control text. RadIA then uses class and
path only within the visible, enabled root window, preventing confusion between an active modal form
and its disabled owner.

Arbitrary handles, global coordinates, and windows from other processes are rejected.

## Evidence and comparison

Evidence includes its `failure` or `verification` phase, session/project/executable/build identity,
scenario outcome and action count, last debugger event, accessible stack, up to ten sanitized
expressions, and a content fingerprint.

Comparison is valid only when failure evidence contains an exception, verification evidence belongs
to the same project, and session and build IDs are both distinct. `outcome=fixed` means the failure
was reproduced and the verified run completed without the same exception condition.

## Versioned regression

`SaveRuntimeRegression` writes
`.radia/runtime-scenarios/<regressionId>.json` with a schema, fingerprint, and atomic write. It does
not persist transient session IDs. In a later run, start a new debug session, call
`PrepareSavedRuntimeScenario`, review and authorize `RunRuntimeScenario`, and confirm the final
repetition and action count.

The user decides when to add the artifact to version control.

## Security and consent

- Automation is confined to the debugged process and its descendants.
- Password controls are redacted.
- Build, debug, scenario execution, and writes preserve IDE consent.
- Scenario cancellation does not require new consent.
- Project changes, process termination, and IDE shutdown invalidate the session.
- Every new debug process receives a new session identity.

## Limitations

- VCL controls without their own window cannot be automated by this mechanism.
- Applications running at a different integrity level may be inaccessible.
- Execution uses semantic identity, not computer vision or screen coordinates.
- A passing visual run alone does not prove leak freedom or general logical correctness.
- Compilation, DUnitX, static analysis, and human review remain part of the gate.

## Troubleshooting

- **No windows:** wait for `running` and confirm `GetRuntimeDebugSession.complete=true`.
- **`runtime_target_not_found`:** refresh discovery and inspect class, text, and path.
- **Not comparable:** stop, rebuild, and start a new session before verification.
- **Security-software startup exception:** inspect the stack and continue only when it is outside
  project code.
- **Scenario timeout:** use one repetition for failure capture and the full saved scenario after the
  fix.
- **Rejected artifact:** regenerate and review the preview because its fingerprint is stale.

## Version 2.1 acceptance

The form-cancellation Access Violation laboratory case was proven on Delphi 12 Win32, Delphi 13
Win32, and Delphi 13 IDE64. Every target completed reproduction, capture, fix, new build, new
session, `fixed` comparison, and a ten-replay regression. The build matrix ran 806 tests per target
without failures or leaks, while SonarQube retained an `OK` Quality Gate.
