# Internal RTK execution plan

## Goal

Deliver a native Delphi result-compaction capability that measurably reduces agent decision context,
preserves complete evidence, and lets the agent recover any omitted range without rerunning the
original tool.

## Execution outcome in version 2.3.0

All phases and gates in this plan are complete. The internal implementation achieved a 96.71%
corpus reduction, a 96.55% decision-context reduction, and no increase in repeated calls. The
Release matrix passed 892/892 tests with zero leaks on all three targets, the IDE64 smoke loaded 126
tools, and the SonarQube quality gate passed with no issues. Version 2.3.0 was published on August 8,
2026.

See the [viability audit](result_compaction_release_audit_2.3.0.en.md) and the
[measured evidence](result_compaction_evidence_2.3.0.json).

The authoritative execution plan is the Portuguese document:
[Plano de execução do RTK interno](rtk_execution_plan.md).

## Viability gates

The goal is complete only when the implementation proves all of the following:

- at least 30% median reduction across eligible tool results;
- at least 20% median reduction in total decision context across benchmark journeys;
- complete preservation of paths, positions, exit codes, errors, failures, and validation gates;
- range-based recovery of every omitted section without tool re-execution;
- less than 5% increase in repeated tool calls;
- P95 below 10 ms for 100 KiB and below 50 ms for 1 MiB on the reference machine;
- no leaks, no partial artifacts during cancellation or shutdown, and a green Delphi matrix;
- sanitized operation, configuration, diagnostics, documentation, and immediate rollback.

## Execution phases

| Phase | Outcome | Gate |
|---|---|---|
| F0 | Versioned contracts, sanitized corpus, A/B benchmark, and ADR. | Reproducible baseline. |
| F1 | Atomic full-result store plus summary and range retrieval tools. | Every omission is recoverable. |
| F2 | Global context budget with evidence priorities. | Decision snapshots always fit the budget. |
| F3 | Delphi-aware build, DUnitX, Git, knowledge, workspace, and debug compactors. | Critical fields preserved. |
| F4 | Deterministic semantic envelopes for older steps. | Long sessions shrink without extra loops. |
| F5 | Off/Conservative/Balanced profiles, status, metrics, and troubleshooting. | Safe operation and rollback. |
| F6 | Fuzzing, load, concurrency, shutdown, Delphi matrix, and final A/B benchmark. | All viability gates pass. |
| F7 | Opt-in rollout followed by evidence-based default enablement. | IDE smoke and rollback pass. |

Critical path: F0 → F1 → F2 → F4 → F5 → F6 → F7. F3 can proceed in parallel with F2 after F1.
The initial single-developer estimate is 40–62 working days, excluding the rollout observation window.

Start with RTK-001 through RTK-003 in the authoritative plan. Do not expand generic truncation to new
tools before the fidelity contract and baseline benchmark exist.
