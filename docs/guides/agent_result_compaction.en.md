# Agent result compaction and recovery

RadIA's internal RTK reduces large results before the model's next decision. While retained, the
complete result remains the source of truth and can be recovered without repeating a build, test,
Git, or other tool.

## Configuration

Open **Tools > Options > Rad IA > General / Logs**.

| Profile | Behavior |
|---|---|
| `Off` | Sends complete results and disables budget envelopes. Use for rollback or diagnosis. |
| `Conservative` | Compacts eligible results and keeps a larger context margin. |
| `Balanced` | Recommended default. Uses the deterministic compactor with a smaller budget. |

**Maximum agent decision context characters** accepts 16,000 through 1,000,000 characters; the
default is 120,000. `RADIA_RESULT_COMPACTION_PROFILE` can temporarily override the persisted profile.

RTK works with incremental context: each decision receives only the four most recent steps, a periodic
summary, and recoverable references. The tool catalog is filtered by capability and objective.
Conversational history is not resent to the planner; the current objective and audited state are its
source of truth.

## Current rules

- DUnitX strips ANSI, groups consecutive repeated lines, and preserves the beginning, tail, failures,
  and errors.
- Git diff preserves headers and the beginning and tail of large diffs.
- Build preserves errors and fatals while limiting routine messages.
- Knowledge limits large content while preserving file, score, and provenance.
- Tools without a known rule pass through unchanged.
- A projection is applied only when it is smaller than the original JSON.
- Parsing or validation failure falls back to the original JSON.
- Runtime control trees prefer semantic paths and remove native duplicates when both represent the same
  form, without removing the window root.

## Preservation and recovery

Complete results are stored by session and step with SHA-256 and atomic writes. A session keeps its
100 newest artifacts within 64 Mi characters; reaching either limit evicts the oldest artifacts
instead of blocking new runs. An artifact accepts 8 Mi characters. Artifacts also expire after 14
days and cleanup runs when the plugin loads.

Compacted context reports `artifactId`, hash, size, and `fullResultAvailable`. The agent can use:

- `GetToolResultSummary` to confirm hash, size, and step;
- `GetToolResultRange` to recover up to 4,096 characters per call.

A response with `hasMore=false` completes recovery for that range. RadIA does not turn this tool result
into another artifact and, if the model immediately repeats the same read, returns structured guidance
to continue functional validation. A further repetition is still stopped by the safety limit.

Both tools enforce the active session and reject traversal, session spoofing, and invalid ranges.
Checkpoints, replay, UI, and validation gates preserve the reference. After retention evicts an old
artifact, the retrieval tools report that it is no longer available.

## Metrics and diagnostics

`/status agent` and `GetRadIAStatus` report the profile, recovery availability, and context limit. The
sanitized `AgentTokens` log separates context and catalog characters and records
`history=state-only` to confirm conversational history was not resent. Decision snapshots aggregate
counts, duration, and rule name only; they do not store code, prompts, arguments, or secrets.

When a run starts, awaits approval, completes, pauses, or fails, the local log also receives an
`agentRunSummary` event. It contains only an irreversible run identifier, state, normalized stop reason,
duration, decisions, tools, failures, repetitions, recoveries, and validation rejections. Token values are
provider-reported counters only; `usageStatus=unknown` explicitly identifies unavailable usage. The event
never contains the objective, prompt, arguments, results, paths, or original session and project identifiers.

Stable reasons distinguish completion, pending approval, pause, cancellation, a missing or partial decision,
an invalid plan, an empty tool, a repeated call, and duration, token, or cost limits. This classification is
independent from the human-readable message shown to the user.

Values include `completed`, `awaitingApproval`, `paused`, `cancelled`, `agentReportedFailure`, `planFailure`,
`emptyToolName`, `repeatedToolCall`, `durationLimit`, `tokenBudget`, and `costBudget`.

When an identical consecutive call repeats a tool that has just succeeded, the runtime reuses the prior
evidence and does not execute the tool again. The auditable step reports
`successful_result_already_available`, while `suppressedToolCallCount` measures the actual saving. A failed
call remains eligible for retry, and a strict user-configured repetition limit still takes precedence.

### Efficiency baseline

With logging enabled, generate a sanitized baseline from the latest runs:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Measure-RadIA.AgentEfficiency.ps1 `
  -LastRuns 100 `
  -PairingKey create-project-delphi13-standard `
  -OutputPath Output\AgentEfficiencyBaseline.json
```

Compare another sample of the same workflow, provider, model, and configuration:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Measure-RadIA.AgentEfficiency.ps1 `
  -LastRuns 100 `
  -PairingKey create-project-delphi13-standard `
  -BaselinePath Output\AgentEfficiencyBaseline.json `
  -OutputPath Output\AgentEfficiencyCurrent.json
```

The aggregator uses only the latest summary for each run without exporting `runId` values or paths. It
measures decisions, executed and suppressed tools, recovered repetitions, duration, first-decision latency,
and reported tokens. Runs with `usageStatus=unknown` are excluded from token averages, so unavailable usage
is never shown as zero. `PairingKey` identifies the same scenario, provider, model, and configuration; only
its truncated hash is written to evidence.

After capturing two samples with the same key and run count, apply the relative gate:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.AgentEfficiencyGate.ps1 `
  -BaselinePath Output\AgentEfficiencyBaseline.json `
  -CurrentPath Output\AgentEfficiencyCurrent.json `
  -OutputPath Output\AgentEfficiencyGate.json
```

By default, each sample must contain at least 20 runs, measure responsiveness in every run, and report token
usage for the same non-zero run count. The gate rejects increases above 20% for duration or first-decision
latency and above 10% for decisions, tools, or tokens. Thresholds are explicit script parameters; do not use
different keys or shrink the sample to make a regression pass.

Run the reproducible benchmark with:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.ResultCompaction.ps1
```

Historical viability evidence remains available through Git history and GitHub Releases.
