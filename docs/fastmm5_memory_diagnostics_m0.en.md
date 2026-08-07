# M0 execution — FastMM5 baseline and memory laboratory

> **Status:** completed and validated on all three targets.
> **Validated backend:** user-supplied FastMM5 5.07 at `D:\Delphi\FastMM5`.

## Confirmed baseline

- `FastMM5.pas` declares `CFastMM_Version = 507`.
- Both Win32 and Win64 Full Debug Mode libraries are present.
- The local source matches official commit `823ba351842a69977c509ff74d68acf08b3a1bc1`.
- No FastMM5 source or binary was copied into the RadIA repository.

## Delivered contracts

`RadIA.Core.MemoryDiagnostics.pas` defines bounded sessions, backend readiness, events, opaque stack
frames, allocation groups, snapshots, evidence, comparability rules, and a backend-neutral
collection interface.

The public schemas are:

- [`memory_diagnostic_evidence_schema_v1.json`](memory_diagnostic_evidence_schema_v1.json);
- [`memory_diagnostic_comparison_schema_v1.json`](memory_diagnostic_comparison_schema_v1.json).

## Laboratory proof

The `clean` and `transient` modes finish without a leak report. The deterministic `leak` mode
reports `TStringList` allocations and resolves `RunLeakCase` to lines 32–33. The `double-free` and
`use-after-free` modes produce a freed-object event and a nonzero exit code without a message box.

This behavior passed on Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 Win64/IDE64.

## Remaining goal

M1–M6 remain: configuration and readiness, reversible instrumentation, parser, scenario and
snapshot integration, fix/comparison/regression, hardening, installation, and release 2.2.0.
