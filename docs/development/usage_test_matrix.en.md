# Automated usage test matrix

The usage matrix validates RadIA as a product inside Delphi, complementing unit and Web tests. It has
separate levels so routine delivery does not become a multi-hour certification.

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
structured evidence for preview, creation, opening, structural requirement preservation, and build without
starting the application by default. The journey fails on premature CLI completion, an unavailable tool, a
missing project file, or any required step that was not executed.

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

## Execution levels

| Level | When to use | Coverage |
|---|---|---|
| `release` | Every patch or minor publication | Complete suites, templates, startup on three targets, and critical journeys on Delphi 13 Win32 |
| `targeted` | Development and localized fixes | Only explicitly selected scenarios and targets |
| `regression` | Major releases, cross-cutting changes, or instability investigations | All 49 flows on every compatible target |

Run `regression` for changes to the installer, WebView2 lifecycle, IDE shutdown, session isolation,
security/consent, E2E orchestration, or the target matrix. Also run it before a major release, after a
failure that cannot be isolated, or when targeted selection cannot safely represent the changed surface.

## Run during development

Close every Delphi instance and run:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile startup
```

The aggregate result is written to `Output/Validation/UsageMatrix/usage-matrix.json`. The `release`
profile runs critical journeys on Delphi 13 Win32. During
development, evidence reports a dirty source and no required package provenance; that result cannot
authorize a release.

For a localized change, select the scenario and target explicitly:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile targeted `
  -ScenarioId calculator-history-fidelity `
  -TargetId delphi13-win32
```

Use `-PlanOnly` first to inspect cost and combinations without opening Delphi.

`natural-vcl-project-creation` deliberately starts with an existing directory. The scenario passes only
when the simulated user supplies another destination, the original requirements remain in the objective,
execution stays on the native orchestrator, and the project is created, opened, and built without starting
the application. This is the representative gate for the default experience. `calculator-history-fidelity`
and `vcl-project-creation-lifecycle` request and validate functional execution in a controlled environment.

The `targeted` profile uses the already installed build and never silently replaces a developer's IDE.
Explicitly install the intended revision with `build.ps1 -Install` first. The `startup`, `release`, and
`regression` profiles build and install their own packages per target.

## Mandatory release gate

After building the same clean revision and before producing official packages, run:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleaseUsage.ps1
```

Before occupying the machine, add `-PlanOnly` to obtain the aggregate plan without building, installing,
or opening Delphi.

This command composes the bounded mandatory gate:

1. run the complete RadIA DUnitX suites on Delphi 12 and 13;
2. run startup and shutdown smoke tests on all three supported targets;
3. generate and build every supported template on Delphi 12 and 13;
4. perform the visual `2 + 3 = 5` operation in the VCL calculator;
   the scenario also proves that a history request records `2 + 3 = 5` in the list and that clearing
   leaves the list empty;
5. run all five calculator DUnitX tests;
6. create, open, and immediately navigate a project on representative Delphi 13 Win32;
7. validate clean installation and upgrade on the representative target;
8. route real beginner requests for creation, build, tests, and diagnostics, including educational
   fallback and sanitized local counters.

The `regression` profile still contains every registered scenario exactly once and distributes them
across compatible targets. Run the full certification with:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.UsageMatrix.ps1 `
  -Profile regression `
  -EvidencePath Output\Validation\UsageMatrix\regression.json
```

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
and no orphan process remains. The `release` profile executes critical host contracts and representative
journeys. `targeted` requires `-ScenarioId`; `regression` prevents registered scenarios from falling out
of the full certification.
The first proves explicit intent-route confirmation, command review, chat fallback, and host
validation of the pending command. DUnitX runs sixteen natural prompts against the real Pascal
classifier; the host-neutral contract confirms that telemetry cannot accept prompt content. New
behavior must add manifest scenarios and contract tests to
`Tests/Web/RadIA.UsageMatrix.test.js`.
