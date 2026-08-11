# M5 — Regression, evidence, and hardening

## Objective

Turn an approved visual reproduction into an executable regression after rebuilding or opening a
new Delphi session, without persisting handles, opaque IDs, coordinates, or secrets.

## Versioned artifact

Each regression is stored at:

```text
.radia/runtime-scenarios/<id>.json
```

Schema 1 records an ID, timestamp, SHA-256 fingerprint, and scenario definition. Commit the file
with the project when it belongs to the regression suite. The formal reference is
[`runtime_regression_schema_v1.json`](runtime_regression_schema_v1.json).

Opaque IDs returned by `GetRuntimeWindows` and `GetRuntimeControlTree` belong only to the current
session and are rejected during persistence. Every action uses a replayable selector:

```json
{
  "className": "TButton",
  "text": "Cancel",
  "parentPath": "TTargetForm[0]"
}
```

Use `$root` as `parentPath` for a root window. Resolution occurs again only inside the authorized
process. Zero or multiple targets fail safely; RadIA never falls back to coordinates.

## Workflow

1. Run and confirm the correction through `/journey debug`.
2. When the cause is isolatable, create a focused DUnitX test with the project and patch tools.
3. When the failure depends on the visual lifecycle, call `PrepareRuntimeRegression`.
4. Review the path, fingerprint, and overwrite state.
5. Authorize `SaveRuntimeRegression` and commit the artifact when appropriate.
6. In a new debugging session, call `PrepareSavedRuntimeScenario`.
7. Authorize `RunRuntimeScenario`; a regression may request up to ten repetitions.

`ListRuntimeRegressions` discovers artifacts. `RevertRuntimeRegression` undoes only the tracked save
and refuses to overwrite changes made afterward.

## Safeguards

- writes are confined to the active project and fixed `.radia/runtime-scenarios` directory;
- IDs accept letters, digits, and hyphens only;
- artifacts are limited to 1 MiB;
- a temporary file and atomic replacement protect writes;
- project or file changes invalidate the preview;
- schema, ID, and fingerprint are revalidated before replay;
- content recognized by the secret redactor is rejected;
- every execution still requires fresh consent;
- shutdown, cancellation, and session changes keep using the M3 interruption mechanism.

## Laboratory application

The versioned
[`cancel-access-violation.json`](../Tests/RuntimeLab/.radia/runtime-scenarios/cancel-access-violation.json)
opens the modal form, cancels it, and allows up to ten repetitions after correction. Run the
failing scenario once to capture the exception; ten repetitions belong to corrected verification.

## Troubleshooting

| Result | Meaning | Action |
|---|---|---|
| `runtime_regression_not_replayable` | The scenario still uses an opaque ID or lacks a stable selector. | Read class, text, and path from the current tree and remove `targetId`. |
| `runtime_regression_unavailable` | Project, file, schema, or fingerprint changed. | Reopen the correct project and prepare again; never edit the fingerprint manually. |
| `runtime_target_not_found` | The selector does not exist in the current session. | Compare the current tree with the artifact and update it through preview. |
| `runtime_scenario_timeout` | The expected window or control did not appear in time. | Confirm the reproducible path and adjust a bounded wait. |
| `sensitive_runtime_target` | The target is a password field. | Remove the action; secrets do not belong in runtime regressions. |

## Historical M5 acceptance evidence

Automated evidence recorded when this delivery was accepted:

- verifiable catalog with 111 tools;
- Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64: 802/802 tests per target, with no failures,
  errors, ignored tests, or leaks;
- the executor test completes ten repetitions and twenty actions without fluctuation in every
  matrix suite;
- SonarQube passed with 82.5% new-code coverage, 0.97826% new-code duplication, and zero issues;
- global metrics: 82.9% coverage, 2.1% duplication, no bugs, vulnerabilities, hotspots, or smells,
  and all A ratings.

Final operational acceptance still requires real laboratory execution on all three hosts,
including ten corrected cycles without fluctuation, orphan process, or shutdown failure.
