# Agentive Evolution Validation Plan

> **Historical record of the 1.x matrix.** The Delphi 11 commands and results below do not belong
> to the current matrix. Current validation uses Delphi 12 Win32 and Delphi 13 Win32/IDE64.

## 1. Objective

This document defines the minimum evidence to consider each phase complete. A phase is not
terminated just because the package compiles.

## 2. Baseline

Before changing code:

- Register `git status --short`.
- Run build and tests on the available Delphi version.
- Record number of tests.
- Run ESLint when there is a change in `Source/UI/Web`.
- Register new warnings.

### Baseline registered on 2026-08-02

- Initially clean workspace.
- Delphi 12 Athens (`23.0`), Win32.
- Package `RadIA.dpk` compiled successfully: 22,259 lines and zero errors reported.
- The first build of the suite did not start because the `dcc32.exe` command line exceeded the
Windows limit.
- `build.ps1` now uses a temporary response file for the suite's parameters.
- The suite compiled and found 292 tests: 289 passed, three failed, and no leaks were detected.
detected.
- The three faults are in `RadIA.Tests.HttpClient` and depend on the local SonarQube. Two failed
due to network timeout and one was unable to access the version endpoint.
- The package and suite compile; the baseline is not fully green while the dependent tests
of SonarQube are not isolated or run with the available service.

## 3. Phase 1: reading and registration

Evidence:

- Registry refuses duplicate names.
- Invalid schemes are rejected.
- Read-only tools work with fake facade.
- Responses indicate truncation.
- Cancellation prevents late delivery.
- Closed project returns structured error.
- Build and DUnitX pass.
- Smoke test consult live editor and project.

## 4. Phase 2: security

Evidence:

- All calls go through the policy pipeline.
- Denial does not change state.
- Session permission is limited to the project and tool.
- Secrets do not appear in audit or errors.
- Paths outside the workspace are rejected.
- Shutdown cancels pending consents.

## 5. Phase 3: mutations and build

Evidence:

- Patch applies when preconditions are valid.
- Patch is rejected after competing edit.
- Encoding and line endings are preserved.
- Change can be reversed.
- Build returns structured messages.
- Agentive iterations obey the limit.
- Execution does not occur implicitly after build.

## 6. Phase 4: MCP

Evidence:

- `tools/list` corresponds to the registry.
- `tools/call` uses the policy pipeline.
- Named pipe only accepts local clients.
- HTTP only listens in loopback.
- Invalid token is refused.
- Payload above the limit is refused.
- Server closes next to the IDE.
- Child CLI processes are cancelable.

## 7. Phase 5: Designer, debugger and review

Evidence:

- Reading uses the live state of the form.
- Mutations keep PAS and DFM consistent.
- Full event handler is atomic or fully rolled back.
- Debugger returns structured state.
- Enforcement actions require consent.
- Inline review accepts and rejects changes.
- Saving does not leave bookmarks or inconsistent content.
- Fallback Smart Diff remains functional.

## 8. Phase 6: knowledge

Evidence:

- Parser identifies Delphi symbols covered by fixtures.
- Initial and incremental indexing produce the same final state.
- Exclusions are respected.
- Results cite origin and review.
- Corrupted index can be rebuilt.
- Purge only deletes the index of the target workspace.
- Lexical search works without providers or embeddings.

## 9. Quality Gates

For any phase:

- No Pascal literals longer than 255 characters.
- No routine with more than seven parameters.
- No lines of code longer than 120 characters.
- No whitespace trailing.
- No suppression comments from SonarQube.
- Local objects protected by `try..finally`.
- No circular dependencies between unit interfaces.
- Cognitive complexity per routine within limit.
- Code, comments and prompts in English.
- Documentation and communication in Portuguese.

## 10. Standard commands

Delphi 12:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test
```

Delphi 11:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "22.0" -Test
```

Delphi 13:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "37.0" -Test
```

Frontend:

```powershell
npx eslint
```

For quick validations without coverage report, add `-NoCoverage`. The final gate of a
delivery must maintain at least one execution with coverage.

## 11. Recording of evidence

Each delivery must inform:

- Files changed.
- Capabilities implemented.
- Tests added.
- Builds executed.
- Really validated IDEs.
- Known risks.
- Fallbacks.
- Items not yet verified.

### Phase 1 Evidence on 2026-08-02

- Package compiled in Delphi 12 Athens (`23.0`), Win32.
- Internal registry and executor added to Core.
- Nine registered read-only tools.
- Read-only OTA facade registered in the container.
- Suite with 310 tests: 310 passed, none ignored and no leaks.
- Explicitly disabled coverage with `-NoCoverage` in this run.

### Consolidated agentive baseline on 2026-08-02

- Delphi 11 Alexandria (`22.0`), Win32: 442/442 tests, no crashes, errors or leaks.
- Delphi 12 Athens (`23.0`), Win32: 442/442 tests, no crashes, errors or leaks.
- Delphi 13 Florence (`37.0`), Win32: 442/442 tests, without crashes, errors or leaks.
- A previous Delphi 11 run with 370 tests hit 78% of the selected lines.
- The MCP bridge, package and suite were compiled in all three versions.
- Delphi 13 Win32 loaded the BPL automatically in three consecutive cycles and exited between
1.98 s and 2.63 s, without crash, deadlock or second chance in the cycle observed under CDB.
- Delphi 11 Win32 loaded exactly the current BPL in three valid cycles and exited between
0.80 s and 0.86 s, without crash or deadlock.
- Delphi 12 Win32 loaded exactly the current BPL in three valid cycles and exited between
1.52 s and 1.99 s, without crash or deadlock.
- Real bridge confirmed MCP handshake, tool catalog, live buffer read, consent
native and audit. Bridge timeout has been extended to ten minutes to accommodate consent
human.
- The inline review was validated in an active project in Delphi 13: visual decoration by severity,
preview with file `.dpr`, apply to the predicted revision, revert to the original SHA, remove and
audited cleaning. The file on disk remained unchanged byte for byte during the cycle.
- Smoke fixed two flaws in the real adapter: associating content with `.dproj` instead of the buffer
`.dpr` and duplication of the terminal line break by the OTA writer.
- The knowledge scheduler now uses an injectable clock, removing temporal dependence on
debounce tests. The final matrix came back at 442/442 in Delphi 11, 12 and 13, with no leaks.
- Delphi 13 IDE64 compiled package, bridge and suite natively; 442/442 tests passed without fail
or leaks. BPL Win64 loaded `bin64\bds.exe` and responded to MCP as Win64 platform.
- The build uses the compiler, paths, and test executable for the selected platform. The coverage
propagates the suite's exit code with `-tec`; IDE64 uses direct execution because the local execution tool
coverage does not support Win64 executables.
- In clean IDE64 profile, the current Win64 BPL loaded in three consecutive cycles. MCP confirmed
project, `.dpr` editor and Win64 platform. Normal shutdowns completed between 1.62 s and 1.88 s,
no crash, deadlock, MCP discovery or orphan process.
- The MCP protocol processed 1,000 sequential requests, the server restarted 20 times removing
discovery every cycle and shutdown disconnected an idle client within the three-second limit.
- Per-process discovery is created and removed along with the server; shutdown preserves a
`mcp.json` that has been replaced by another instance.
- Two updated Delphi 13 IDEs published distinct endpoints and responded `GetIDEState` and
`GetActiveProject` with the explicit file for each PID.
- The example extension was loaded into the real IDE, increased the catalog from 57 to 58 tools and ran
`SampleProjectInfo`; After deregistration, a new IDE returned to 57 tools.
- Shutting down with the extension loaded removed discovery from the instance itself. The next startup
also eliminated orphan discovery from a dead process without affecting live endpoints.
- Delphi 13 Win32 completed ten consecutive cycles with handshake, `GetIDEState`, clean shutdown and
removal of discovery by PID, between 27.99 s and 31.48 s per cycle.
- Delphi 11 completed ten consecutive review cycles with a watchdog between 5.97 s and 9.51 s.
- Delphi 13 IDE64 completed ten consecutive cycles with MCP and cleanup between 37.77 s and 74.08 s.
- Delphi 12 completed ten consecutive cycles with handshake, `GetIDEState`, clean shutdown and
removal of discovery by PID, between 45.76 s and 74.18 s per cycle.
- A race observed in Delphi 11 prompted an external watchdog on the bridge. It validates PID and endpoint
before removing discovery after the process ends, regardless of the BPLs unload order.
- The IDE64 registry has been corrected to `BDS\37.0\Known Packages x64` as per the official separation
of 64-bit IDE packages.
- Transport stopped querying `GetActiveProject` during `initialize` and `tools/list`. Calls
of tools during the splash receive `-32004`, avoiding premature OTA synchronization with the main thread.
- `Allow once` Consent, cancellation and repeated destructive grant have regression; each
attempt generates audit and cancellation never runs the tool.
- `notifications/cancelled` achieves cooperative tools when running over the named pipe. Each
connection accepts an in-flight call and responds `-32003` to excessive concurrency.
- `radia/metrics` exposes only sanitized session counters: messages, completed calls,
current and peak activity, cancellations and rejections.
- The most recent instrumented run on Delphi 12 passed 442/442 tests and covered 9,390 tests.
11,940 lines selected, maintaining 78% coverage.
- Isolated smoke `Test-RadIA.KnowledgeNotifierSmoke.ps1` opened a copy of the project in Delphi 12,
indexed it by MCP, applied a reviewable edition with consent, noted the update
incremental of the live buffer, saved, renamed and closed the unit. The new identity appeared in the
index and the teardown did not leave an orphan MCP process or discovery.
