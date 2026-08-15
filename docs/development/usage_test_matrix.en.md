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

The aggregate result is written to `Output/Validation/UsageMatrix/usage-matrix.json`. During
development, evidence reports a dirty source and no required package provenance; that result cannot
authorize a release.

## Mandatory release gate

After building and packaging the same clean revision, run:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleaseUsage.ps1
```

This command composes the following gates without options to skip their main requirements:

1. generate and build every supported template on Delphi 12 and 13;
2. perform the visual `2 + 3 = 5` operation in the VCL calculator;
3. run all five calculator DUnitX tests;
4. create, open, and immediately navigate a project on all three IDE targets;
5. run the startup and shutdown matrix with package provenance;
6. route real beginner requests for creation, build, tests, and diagnostics, including educational
   fallback and sanitized local counters.

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
