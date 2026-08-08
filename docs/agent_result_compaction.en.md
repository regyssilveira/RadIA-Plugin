# Agent result compaction and recovery

RadIA's internal RTK reduces large results before the model's next decision. The complete result
remains the source of truth and can be recovered without repeating a build, test, Git, or other tool.

## Configuration

Open **Tools > Options > Rad IA > General / Logs**.

| Profile | Behavior |
|---|---|
| `Off` | Sends complete results and disables budget envelopes. Use for rollback or diagnosis. |
| `Conservative` | Recommended default. Compacts eligible results and keeps a larger context margin. |
| `Balanced` | Uses the same deterministic compactor with a smaller budget for older steps. |

**Maximum agent decision context characters** accepts 16,000 through 1,000,000 characters; the
default is 120,000. `RADIA_RESULT_COMPACTION_PROFILE` can temporarily override the persisted profile.

## Current rules

- DUnitX strips ANSI, groups consecutive repeated lines, and preserves the beginning, tail, failures,
  and errors.
- Git diff preserves headers and the beginning and tail of large diffs.
- Build preserves errors and fatals while limiting routine messages.
- Knowledge limits large content while preserving file, score, and provenance.
- Tools without a known rule pass through unchanged.
- A projection is applied only when it is smaller than the original JSON.
- Parsing or validation failure falls back to the original JSON.

## Preservation and recovery

Complete results are stored by session and step with SHA-256 and atomic writes. A session accepts up
to 100 artifacts and 64 Mi characters; an artifact accepts 8 Mi characters. Artifacts expire after
14 days and cleanup runs when the plugin loads.

Compacted context reports `artifactId`, hash, size, and `fullResultAvailable`. The agent can use:

- `GetToolResultSummary` to confirm hash, size, and step;
- `GetToolResultRange` to recover up to 65,536 characters per call.

Both tools enforce the active session and reject traversal, session spoofing, and invalid ranges.
Checkpoints, replay, UI, and validation gates preserve the complete result.

## Metrics and diagnostics

`/status agent` and `GetRadIAStatus` report the profile, recovery availability, and context limit.
Decision snapshots aggregate counts, duration, and rule name only; they do not store code, prompts,
arguments, or secrets.

Run the reproducible benchmark with:

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.ResultCompaction.ps1
```

See the [2.3.0 viability evidence](result_compaction_release_audit_2.3.0.en.md).
