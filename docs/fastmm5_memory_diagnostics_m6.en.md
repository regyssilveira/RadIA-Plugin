# Execution M6 — memory diagnostics hardening

> **Version:** 2.2.0
> **Backend:** FastMM5 5.07 provided by user
> **Scope:** Delphi 12 Win32, Delphi 13 Win32 and Delphi 13 IDE64

## Repeatability in the IDE

The smoke `Test-RadIA.MemoryDiagnosticIDE.ps1` accepts `-Cycles 1..10`. Each cycle prepares new
instrumentation, compiles, starts only the supervised process, reproduces the visual scenario,
waits for FastMM5 to finish, interprets the evidence, and restores the DPR.

|Target|Cycles|Final result|Restoration|
|---|---:|---|---|
|Delphi 12 Win32| 10/10 |4 deterministic groups|DPR hash preserved|
|Delphi 13 Win32| 10/10 |4 deterministic groups|DPR hash preserved|
|Delphi 13 IDE64| 10/10 |4 deterministic groups|DPR hash preserved|
|Delphi 13 Win32, control fixed| 10/10 |0 groups|DPR hash preserved|

Complete executions, including build/installation of the BPL, opening and closing of the IDE and ten
sessions, were between 100.4 and 117.5 seconds per target in the validation environment. The JSON evidence
in the case with leak it was below 14 KiB; the parser's configured limit remains at 50 MiB.

## Validated faults and outages

- cancellation during active scenario interrupts only the supervised PID;
- cancellation always involves restoration of the instrumentation;
- the global timeout also limits the active action and remaining repetitions;
- build failure restores DPR;
- recovery after interruption restores known original content;
- deviating user content produces `memory_recovery_conflict` and is not overwritten;
- Malformed JSON evidence is rejected without Access Violation;
- a clean run with readiness marker and no log returns zero groups, no missing backend.

## Comparable evidence and correction

- baseline and verification must have different builds and the same scenario fingerprint;
- possible results are `fixed`, `improved`, `unchanged`, `regressed`, and `incomparable`;
- `PrepareMemoryDiagnosticFix` ignores infrastructure frames and chooses the first frame in the project;
- allocation number can be used by `PrepareMemoryInstrumentation` to configure
`FastMM_DebugBreakAllocationNumber`;
- the corrected control proved the transition of four groups to zero without false positives.

## Remaining Gates

This page must be complemented by the final release audit with:

- builds and final tests Delphi 12 and Delphi 13;
- BPL Delphi 13 IDE64;
- lint and web testing;
- SonarQube;
- package smokes and visual installer;
- final installation in the three IDEs;
- hashes of published artifacts.
