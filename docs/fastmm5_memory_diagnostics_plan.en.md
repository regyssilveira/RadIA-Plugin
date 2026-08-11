# Goal 2.2 — Dynamic memory diagnostics with FastMM5

> **Status:** completed; M0 through M6 passed for release 2.2.0.
> **Target version:** 2.2.0.
> **Scope:** Delphi 12 Win32 and Delphi 13 Win32/IDE64, diagnosing Win32 and Win64 applications.
> **Dependency:** optional, user-supplied and user-licensed FastMM5.

## Versioning decision

The next version is `2.2.0`. This integration adds a backward-compatible capability without
removing or changing existing public contracts, so Semantic Versioning requires a `MINOR` increment.

## Goal

Enable RadIA to instrument a Debug configuration reversibly, run a runtime scenario, capture and
parse FastMM5 events, locate allocation stacks, prepare a fix, and replay the same scenario to prove
that a leak or memory error was removed.

The workflow must distinguish transient growth, shutdown leaks, repeated snapshot growth, heap
corruption, double frees, use-after-free errors, and resources that do not belong to the heap.

## Dependency and licensing model

- RadIA will not redistribute FastMM5 source code or binaries.
- Users select a local installation or a dependency already owned by the project.
- Settings show the detected version, paths, architectures, and license acknowledgement.
- RadIA remains fully functional when FastMM5 is absent.
- Documentation explains the GPLv3 or commercial-license choice.

## Planned tools

The planned surface includes status and readiness inspection, prepare/apply/revert instrumentation,
bounded diagnostic scenarios, cancellation and progress, leak evidence capture and comparison,
source navigation, allocation breakpoints, and versioned memory regressions. Final names will be
validated against the active registry to avoid duplication.

## Architecture

The core will define backend-neutral contracts such as `IRadIAMemoryDiagnosticsFacade` and
`IRadIAMemoryDiagnosticsBackend`. `TRadIAFastMM5Backend` will be the first adapter. Instrumentation
will be transactional, Debug-only, fingerprinted, consented, architecture-aware, and fully
reversible.

Collection will combine confined event logs, PID-correlated `OutputDebugString` messages, optional
snapshots, controlled shutdown, MAP files, symbols, and debugger stacks. Structured evidence will
be sanitized; raw memory contents will never be sent to a model by default.

## Milestones

### M0 — Baseline, licensing, and laboratory

**Status:** completed. See [M0 execution evidence](fastmm5_memory_diagnostics_m0.en.md).

Freeze the supported FastMM5 contract, create deterministic leak and memory-error cases, define the
schemas, and prove the reports manually on all supported targets.

### M1 — Detection and configuration

**Status:** completed. See
[FastMM5 configuration](fastmm5_configuration.en.md).

Implement backend detection, settings, architecture validation, doctor integration, and readiness
inspection without redistributing FastMM5.

### M2 — Reversible instrumentation

**Status:** completed. See
[Reversible memory instrumentation](fastmm5_instrumentation.en.md).

Implement transactional prepare/apply/revert for DPR and Debug configuration while preserving live
buffers, encoding, unrelated options, and rollback after interrupted execution.

### M3 — Collection and parser

**Status:** completed. See
[FastMM5 log collection and parsing](fastmm5_evidence_parser.en.md).

Parse leak summaries, details, stacks, classes, sizes, allocation numbers, corruption, double frees,
and use-after-free events from fixtures and real applications.

### M4 — Scenarios, snapshots, and evidence

Reuse the v2.1 runtime scenario engine, add warm-up and snapshots, perform controlled shutdown, and
publish navigable evidence through chat and MCP.

### M5 — Fix, comparison, and regression

Prepare a reviewable fix, replay on a new build and session, classify the result, support allocation
breakpoints, and save versioned memory regressions.

### M6 — Hardening and release 2.2.0

Run ten cycles per target, validate cancellation and restoration, complete documentation, pass all
build/test/lint/Sonar gates, install final packages on all three targets, and publish only after the
complete matrix passes.

## Definition of done

Users can configure their own FastMM5 installation, instrument Debug after consent, reproduce and
locate a leak, navigate to its allocation stack, prepare a fix, replay the same scenario, prove the
leak is gone, retain a regression, and revert instrumentation without residual changes on Delphi 12
Win32, Delphi 13 Win32, and Delphi 13 IDE64.

## Out of scope for 2.2.0

- Redistributing or sublicensing FastMM5.
- Enabling instrumentation in Release builds by default.
- Attaching to processes outside the authorized debug session.
- Treating heap diagnostics as GDI, handle, COM, or GPU-resource diagnostics.
- Supporting FastMM4, madExcept, EurekaLog, or other backends in this version.
- Sending raw memory block contents to providers.
