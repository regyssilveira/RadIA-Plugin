# M0 — Runtime automation baseline and contracts

> **Status:** in progress.
> **Goal:** [Autonomous runtime failure reproduction](runtime_debug_automation_plan.en.md).

## Implemented deliveries

- neutral `IRadIARuntimeAutomationFacade`;
- mandatory session, process, project, executable, and build identity;
- selector, action, limits, scenario, and result contracts;
- validation for stable selectors and bounded scenarios;
- VCL laboratory application with deterministic failure on form open or cancellation;
- reproducible script to build the laboratory with Delphi 12 or 13;
- unit tests for the security contracts.

These contracts do not register agent tools yet. They bound the future implementation so the M1–M3
adapters cannot silently expand access to the desktop.

## Laboratory application

The project is at `Tests/RuntimeLab/RadIARuntimeLab.dproj` and exposes two paths:

1. `btnFailOnOpen` opens the target form and raises an Access Violation during `FormShow`;
2. `btnFailOnCancel` opens the target form and `btnCancel` raises the same failure when invoked.

Both paths converge in `TriggerDeterministicAccessViolation`, keeping the origin and stack
predictable. The failure is intentional and exists only in this test application.

Build it with:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Build-RadIA.RuntimeLab.ps1 `
  -DelphiVersion "23.0"
```

Use `37.0` for Delphi 13.

## M0 acceptance matrix

| IDE host | Application | Build | Open | Cancel | Manual debugging |
|---|---|---|---|---|---|
| Delphi 12 Win32 | Win32 | Passed | Pending | Pending | Pending |
| Delphi 13 Win32 | Win32 | Passed | Pending | Pending | Pending |
| Delphi 13 IDE64 | Win32 | Passed | Pending | Pending | Pending |

M0 is complete only after both actions stop at the intentional line with a readable stack in every
host. An isolated build does not replace this evidence.

## Threat model

| Threat | Boundary defined by the contract | Evidence required in later phases |
|---|---|---|
| Target another application | Complete session identity is mandatory | Negative test with external window |
| Reuse an old PID | PID and creation time are inseparable | PID recycling test |
| Execute an unlimited script | Action, duration, and repetition limits | Timeout and cancellation tests |
| Select an ambiguous control | Selector requires stable identity | Ambiguity test |
| Expose a visual secret | Evidence will be sanitized | Password control test |
| Leave an orphan process | Session belongs to the current debugger | Stop and shutdown tests |
| Mutate code without approval | Facade does not modify files | Existing consent integration |

## Architecture decisions

- The core does not depend on UI Automation, Win32, or OTA.
- Session correlation is implemented before window discovery.
- The first version does not accept window handles supplied by the model.
- Coordinates are not part of the action contract.
- VCL controls without a handle report their capability as unavailable.
- An in-application probe is considered only after discovery coverage is measured.

## Still missing after this stage

- complete manual reproduction in all three matrix combinations;
- M1: correlation and cancellation-aware debugger waiting;
- M2: safe window and control discovery;
- M3: bounded declarative execution;
- M4: diagnose, fix, and replay loop;
- M5: regression, evidence, and hardening.
