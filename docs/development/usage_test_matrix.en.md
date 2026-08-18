# Automated usage test matrix

The usage matrix validates RadIA as a product inside Delphi, complementing unit and Web tests. It is
mandatory for every release and covers Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64.

## Layers

| Layer | Purpose | Execution |
|---|---|---|
| Headless integration | Service, tool, consent, and adapter contracts | DUnitX and Node.js without the IDE |
| OTA integration | Package, catalog, commands, and actual IDE state | Real disposable Delphi instance |
| End to end | Complete user-visible journey | Fixture project, UI, build, tests, debug, and shutdown |

The versioned manifest is `Tests/Usage/usage-matrix.json`. Every scenario declares targets, cycle
count, timeout, and required evidence. The mandatory profile does not use absolute coordinates or a
real provider.

`host` contracts validate structure but do not prove a public promise. Only `user-journey` scenarios
running in the real IDE with true observable outcomes in their evidence can cover promises registered
in `Tests/Usage/release-promises.json`. Run the audit with:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleasePromises.ps1 `
  -Enforce
```

VCL creation starts in the real chat composer, accepts the recommendation shown to the user, and requires
structured evidence for preview, creation, opening, build, and execution. The journey fails on premature CLI
completion, an unavailable tool, a missing project file, or any required step that was not executed.

Session isolation also uses the real WebView: it leaves a recommendation pending in the previous
conversation, creates another conversation, confirms that history was cleared, and requires rejection of
the stale approval. Project switching and rollback remain covered by the IDE journey. No result may reuse
the consent boolean as a substitute for chat-session or pending-action isolation.

Each promise also declares its maximum duration, expected outcomes, and forbidden outcomes. Mandatory
coverage includes direct conversation, VCL creation, build repair, DUnitX, window persistence,
mutation-only consent, step budget, cancellation, provider/CLI recovery, installation and upgrade,
context isolation, and sensitive-data protection.

## Inspect the plan without opening Delphi

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile startup `
  -RequirePackageProvenance `
  -PlanOnly
```

`-PlanOnly` validates the manifest and returns JSON with every combination that would run. It does
not start, install, or modify the IDE.

## Run during development

Close every Delphi instance and run:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile startup
```

The aggregate result is written to `Output/Validation/UsageMatrix/usage-matrix.json`. In the `release`
profile, the orchestrator groups journeys by target and installs the matching package before running them. During
development, evidence reports a dirty source and no required package provenance; that result cannot
authorize a release.

## Mandatory release gate

After building the same clean revision and before producing official packages, run:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleaseUsage.ps1
```

This command composes the following gates without options to skip their main requirements:

1. run the complete RadIA DUnitX suites on Delphi 12 and 13;
2. run every registered integration and end-to-end scenario applicable to supported targets;
3. generate and build every supported template on Delphi 12 and 13;
4. perform the visual `2 + 3 = 5` operation in the VCL calculator;
5. run all five calculator DUnitX tests;
6. create, open, and immediately navigate a project on all three IDE targets;
7. explicitly install the current build and run the startup/shutdown matrix on all three targets;
8. route real beginner requests for creation, build, tests, and diagnostics, including educational
   fallback and sanitized local counters.

Once a feature enters the matrix, its scenario becomes mandatory in every following release. The
release runner accepts no filter, exclusion, or partial approval for these groups.

Package and installer provenance is validated afterwards by the packaging gate because those artifacts do not
exist yet while `Test-RadIA.ReleaseUsage.ps1` runs. Using `-RequirePackageProvenance` before
`New-RadIA.ReleaseEvidence.ps1` is invalid. The matrix compares the installed BPL with the local build from the
same revision; the runner installs that build on all three targets before the matrix, and the following stage binds
the revision to packages and the installer.

Before the first build and each installation, the gate stops only known RadIA auxiliary processes
(`RadIA.Semantic.Engine` and `RadIA.MCP.Bridge`) while no IDE is open. This prevents an orphan from a previous
session from locking binaries without terminating terminals or project processes.

An exact IDE startup-readiness failure allows one bounded retry of the same target. The first output is preserved
in evidence with `attemptCount: 2` and `startupRetryUsed: true`. Any functional, build, test, navigation, debug,
or shutdown failure blocks immediately without a retry.
The child process standard output and stderr are captured with its exit code; stderr cannot terminate the
orchestrator before it records the attempt and applies this policy.

If `DEXT_ROOT` is not configured, only DEXT templates are recorded as `not-required`; all other
templates and gates remain mandatory. When `DEXT_ROOT` exists, DEXT servers and endpoints are also
built and executed.

## Evidence and failures

Artifacts remain under `Output/Validation/ReleaseUsage` and are never published as release assets.
Each result records target, architecture, duration, status, and a sanitized output tail. A failure
preserves partial evidence and blocks publication; retrying a scenario does not convert its first
failure into a pass.

The `startup` profile proves that the package loaded, the tool contract is valid, shutdown is clean,
and no orphan process remains. The `release` profile also executes critical IDE-neutral contracts.
The first proves explicit intent-route confirmation, command review, chat fallback, and host
validation of the pending command. DUnitX runs sixteen natural prompts against the real Pascal
classifier; the host-neutral contract confirms that telemetry cannot accept prompt content. New
behavior must add manifest scenarios and contract tests to
`Tests/Web/RadIA.UsageMatrix.test.js`.
