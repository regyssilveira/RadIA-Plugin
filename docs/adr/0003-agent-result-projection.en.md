# ADR 0003 — Complete agent results and compacted projections

## Status

Accepted for version 2.3.0.

## Context

Large build, test, Git, and knowledge results consumed the model decision window. Truncating the only
available result would remove evidence and could force the tool to run again.

## Decision

The complete result is persisted by session and step as a SHA-256 artifact. Checkpoints, replay, UI,
and validation gates keep using that result. Only the boundary that assembles the model's next
context uses a deterministic, disposable projection.

Omitted content must reference an `artifactId` recoverable through `GetToolResultSummary` and
`GetToolResultRange`. Parsing failure, an unknown rule, or a larger projection passes through.
Metrics contain profile, rule, character counts, and duration only.

## Consequences

- The model receives less context while retaining detailed inspection.
- Storage requires quotas, retention, session boundaries, and cleanup.
- New rules require sanitized fixtures, fidelity checks, and benchmarks.
- `Off` provides immediate rollback without deleting checkpoints or artifacts.
