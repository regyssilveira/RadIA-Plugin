# Goal — eliminate RadIA's six competitive gaps

> **Status:** active, planned from RadIA 2.3.0.
> **Scope:** Delphi 12 Win32 and Delphi 13 Win32/IDE64.
> **Delivery version:** determined by the public behavior actually delivered; inherited backlog
> versions are not commitments.
> **Out of scope:** C++Builder, marketplace distribution, mandatory Authenticode signing, and
> replacement of the current WebView2 host.

## Objective

Eliminate six remaining functional gaps with reproducible evidence:

1. native CLI session continuity;
2. one context across chat, terminal, and editor;
3. block-level review directly in the gutter;
4. Fill-In-the-Middle (FIM) specialized completion;
5. external MCP client and server federation;
6. project, session, and request-level settings.

The goal closes only when all six contracts are implemented, documented, and approved across the
supported Delphi matrix. A UI-only, single-provider, or single-target delivery does not close a phase.

## Baseline to preserve

- A CLI-independent native agent with optional external executors.
- One tool registry shared by chat, agent, MCP, and extensions.
- Risk consent, sanitized audit, workspace boundaries, checkpoints, and rollback.
- ConPTY terminal, Ghost Text, inline review, debugger, Designer, build, DUnitX, and FastMM5.
- Provider and model discovery and switching without restarting the IDE.
- Central documentation plus `/doctor`, `/status`, and `/tools` aligned with runtime.

## Cross-cutting contracts

- Never persist credentials, tokens, or sensitive content as plain text.
- Late callbacks never cross sessions, projects, reviews, or IDE instances.
- Internal and external tools share the same risk and consent policy.
- Editor changes are preview-first, atomic, auditable, and reversible.
- UI reports the effective executor, model, setting source, and tool origin.
- Missing capabilities degrade explicitly, without silent fallback.
- User-visible work updates central references, guides, hints, translations, and documentation tests.
- Every phase closes with tests, Sonar, and evidence across the supported matrix.

## Execution plan

### Phase 0 — Baseline, contracts, and local metrics

- Version a capability matrix for Codex, Claude, Gemini, and GitHub Copilot executors.
- Define journey, conversation, session, project, and request identities.
- Define capability discovery contracts for resume, FIM, and model selection.
- Measure latency, cancellation, stale responses, and resumes locally without remote telemetry.
- Add fixtures and contract tests before changing persistence or UI.

**Acceptance:** versioned matrix, reviewed contracts, green baseline, and no new Sonar issue.

**Status:** completed. The typed catalog, five identity boundaries, bilingual matrix, and four
contract tests passed with 898/898 tests on all three targets. See the
[Phase 0 evidence](competitive_gap_phase_0_evidence_2.3.1.json).

**Still missing:** implementation of all six functional points.

### Phase 1 — Native CLI session continuity

- Capture and validate each CLI conversation identifier.
- Persist only non-secret executor, declared model, workspace, and identifier metadata.
- Create, resume, duplicate, detach, and close conversations.
- Use an explicit fallback for CLIs without stable resume; never simulate continuity.
- Correlate process, stream, consent, and response with their originating session.
- Expose state and actions through UI, commands, and `/status`.

**Acceptance:** after panel and IDE restart, each supported CLI resumes the correct conversation or
clearly starts fresh; tests prove isolation and stale-output rejection.

**Status:** complete. Codex, Claude, Gemini, and Copilot resume by identifier, with sanitized
metadata per conversation, late-response isolation, and equivalent composer and command actions.
The Delphi matrix passed with 904/904 tests per target. See the
[Phase 1 evidence](competitive_gap_phase_1_evidence_2.3.1.json).

**Still missing:** cross-surface context, hierarchical settings, FIM, gutter, and external MCP.

### Phase 2 — One context across chat, terminal, and editor

- Introduce a journey identity referencing conversation, project, and execution without duplication.
- Start in chat, continue in terminal, and request completion or review in the editor.
- Share executor, project, diagnostics, and selected artifacts rather than unrestricted history.
- Link, detach, and switch journeys through both UI and commands.
- Show the active journey on every surface and prevent cross-project mixing.
- Preserve native-agent consent, audit, checkpoints, and boundaries.

**Acceptance:** an authenticated journey crosses chat, terminal, and editor without losing identity
or copying another workspace's context; cancellation remains coherent on every surface.

**Status:** complete. Chat, terminal, and editor use the same identity per conversation and project,
with shared activity state, workspace isolation, a visual button, and commands to link, detach, renew,
and switch journeys. No history or process output is copied. The Delphi matrix passed with 916/916
tests per target. See the
[Phase 2 evidence](competitive_gap_phase_2_evidence_2.3.1.json).

**Still missing:** hierarchical settings, FIM, gutter, and external MCP.

### Phase 3 — Project, session, and request settings

- Implement explicit precedence: request > session > project > global > safe default.
- Cover compatible provider, model, executor, and limits; credentials remain secure and global.
- Keep project settings outside versioned files by default, with opt-in export.
- Display effective value, source, override, and restore-inheritance action.
- Use atomic read-merge-write updates while preserving unknown fields.
- Refresh models and capabilities on scope changes without restarting Delphi.

**Acceptance:** two projects and two sessions use distinct settings simultaneously; concurrent
writes lose no fields and UI, `/status`, and real execution agree on effective values.

**Status:** complete. Provider, model, executor, and limits use request > session > project > global
> safe-default precedence across native chat, the native agent, and external CLIs. **Settings >
Scope**, `/scope`, `/status settings`, and the composer route show the same effective values and
sources, restore inheritance, and refresh models without restarting the IDE. Project and session
scopes persist outside the repository; next-request values remain in memory and never cross a
conversation or workspace. Sanitized export is explicit and excludes credentials and the project
path. The Delphi matrix passed 937/937 tests per target. See the
[final Phase 3 evidence](competitive_gap_phase_3_evidence_2.3.1.json).
See the [Phase 3 foundation evidence](competitive_gap_phase_3_foundation_evidence_2.3.1.json).
Also see the
[Phase 3 persistence evidence](competitive_gap_phase_3_persistence_evidence_2.3.1.json).

**Still missing:** block gutter review and external MCP.

### Phase 4 — FIM-specialized completion

- Add a completion contract separate from chat.
- Discover FIM support by capability instead of model-name assumptions.
- Send bounded prefix, suffix, language, caret position, and budget.
- Keep an explicit traditional-completion fallback when FIM is unavailable.
- Cancel stale responses after caret, buffer, file, project, or journey changes.
- Expose local latency, model origin, and fallback reason for diagnostics.

**Completed:** the separate FIM contract, capability discovery, dedicated Ollama/LM Studio routes,
fallback, context cancellation, and visual diagnostics are implemented. Provider fixtures and a
real-editor smoke proved clean preview, acceptance, one undo, restoration, and clean rejection on
Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64.
See the
[Phase 4 foundation evidence](competitive_gap_phase_4_foundation_evidence_2.3.1.json).
Also see the
[final FIM matrix evidence](inline_completion_smoke_evidence_2.3.1.json).

**Acceptance:** fixtures prove prefix/suffix assembly and one real smoke per target accepts and
rejects Ghost Text without premature writes, with one undo and no unintended code disclosure.

**Still missing:** block gutter review and external MCP.

### Phase 5 — Block-level review directly in the gutter

- Provide accessible markers to accept, reject, edit, and explain each block.
- Bind every block to a revision hash and invalidate stale buffers.
- Apply partial decisions as transactions consistent with checkpoints and rollback.
- Provide keyboard and command equivalents for every visual action.
- Support multiple files without losing navigation, focus, or review state.
- Feed results into timeline and audit without duplicating diff truth.

**Implementation completed:** `TRadIABlockReviewEngine` separates independent changes, binds each
block to its file and base revision, assigns a stable identity, and recomposes the file from
individual accept, reject, or edit decisions. The engine preserves CRLF and bounds its comparison
matrix; files beyond the limit remain safe through one aggregated block. See the
[Phase 5 foundation evidence](competitive_gap_phase_5_foundation_evidence_2.3.1.json).

Single and multi-file previews automatically publish a block session. OTA gutter markers show
pending, accepted, rejected, and edited states. The marker menu can accept, reject, edit, explain,
apply, or discard; commands and configurable shortcuts provide the same actions and navigation
across blocks and files. Decisions do not write to the editor before application.
`ApplyBlockReviews` requires every block to be resolved and uses the existing multi-file
transaction, with SHA preflight and compensation. `ListBlockReviews`, `DecideBlockReview`,
`ApplyBlockReviews`, and `ClearBlockReviews` are part of the 130-tool catalog. See the
[Phase 5 transaction evidence](competitive_gap_phase_5_transaction_evidence_2.3.1.json).

**Acceptance proven:** 953 tests pass without failures or leaks on every target. Real smokes on
Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 publish reviews, paint line and gutter through
OTA, accept by keyboard, reject by mouse, and protect against stale revisions. See the
[final Phase 5 visual evidence](competitive_gap_phase_5_gutter_evidence_2.3.1.json).

**Still missing:** external MCP client and federation.

### Phase 6 — External MCP client and server federation

- Implement an MCP client separate from the existing server, including lifecycle and cancellation.
- Register local servers through a guided flow and import configuration only after preview.
- Discover tools, resources, and prompts with stable namespace and visible origin.
- Resolve collisions without silent renaming and retain internal tools during failures.
- Apply allowlists, workspace boundaries, consent, timeout, audit, and sanitization.
- Isolate process, secrets, and settings per server; safely disable and remove servers.
- Refresh health and next action in Settings, `/doctor`, and `/status` without restart.

**Foundation implemented:** external servers now have a validated contract for identity, command,
arguments, working directory, enabled state, and timeout. Discovered tools receive the stable
`mcp.<server>.<tool>` namespace and replace the previous snapshot only after complete validation.
Collisions, mismatched origins, invalid schemas, oversized descriptions, and publication from a
disabled server are rejected without affecting the internal catalog or the last valid snapshot.
See the
[Phase 6 foundation evidence](competitive_gap_phase_6_foundation_evidence_2.3.1.json).

**Stdio transport implemented:** every server runs as an isolated process through the job-object
infrastructure already used by RadIA. The transport sends and receives UTF-8 JSONL, limits every
message to 8 MiB, captures stderr, bounds stdin and receive waits, and terminates the process tree on
stop. An external-process test proves a real round trip and shutdown without an orphan process.

**Lifecycle and tools implemented:** the client negotiates `initialize` against supported MCP
versions, sends `notifications/initialized`, correlates responses by ID across notifications,
translates JSON-RPC errors, discovers `tools/list` without replacing the last valid snapshot after an
invalid response, and runs `tools/call` with the original name after resolving the federated
namespace. A server is not considered connected when version, capabilities, or identity is missing.

**Execution security implemented:** discovering an external tool does not authorize it. Every tool
requires an explicit grant that declares risk, per-call consent, and arguments containing paths; an
empty path list requires an equally explicit unbounded-access grant. The adapter converts the
external tool into RadIA's shared policy pipeline, so session decisions, consent, redaction, and
audit follow the same flow as internal tools. Paths outside the workspace are rejected before any
server call, and server-provided annotations can never reduce the locally defined risk.

**Active cancellation implemented:** when the execution token is cancelled, the client sends
`notifications/cancelled` with the original call ID and returns control without waiting for the
server timeout. A late response retains its old ID, is discarded by the correlator, and cannot
complete or contaminate the next call. Legacy clients remain compatible through the basic
interface, while clients exposing the cancellable interface receive the token end to end.

**Secure persistence implemented:** servers and grants are validated as one snapshot, fully
protected with the current user's Windows DPAPI identity, and written through atomic replacement.
Commands, arguments, working directories, grant paths, and possible secrets never appear as plain
text in the file. Corrupted, cross-user, oversized, or invalid payloads are rejected without partial
configuration or replacement of the previous snapshot. Server IDs and grant names must be unique.

**Pagination and content implemented:** `tools/list`, `resources/list`, and `prompts/list` follow
`nextCursor` with limits of 100 pages and 4,096 items, reject repeated cursors, and publish only
after every page is validated. Resources receive the federated
`mcp://<server>/resources/<uri>` URI and prompts use the `mcp.<server>.prompt.<name>` namespace,
preserving origin and identity. Invalid responses, schemas, URIs, names, descriptions, MIME types,
or arguments cannot replace the last valid catalog. Content catalogs remain optional for backwards
compatibility with existing integrations.

**Runtime and diagnostics implemented:** the runtime loads the protected snapshot, connects only
enabled servers, discovers content, and registers only explicitly granted tools in the shared
catalog. Replacement is atomic: invalid configuration or registration failure preserves previous
sessions and tools, while isolated failures never remove the internal catalog. `/doctor` and
`/status mcp` expose sanitized health and counts, distinguish the CLI bridge from the external
client, and never reveal commands, arguments, working directories, or paths. The same runtime can
refresh without restarting Delphi.
See the
[Phase 6 runtime and diagnostics evidence](competitive_gap_phase_6_runtime_evidence_2.3.1.json).

**Still in this phase:** the visual Settings experience and smokes with a complete MCP fixture and
one authorized real server.

**Acceptance:** one fixture and one authorized real server are discovered, perform read and consented
mutation, cancel correctly, and cannot bypass RadIA policy.

**Still missing:** only the integrated closure gate.

### Phase 7 — Integrated journey and goal closure

Run on all three supported combinations:

1. open two projects with distinct settings;
2. start and resume a CLI conversation;
3. continue the same journey in the terminal;
4. request FIM completion in the editor;
5. review a multi-file change by gutter block;
6. call an external MCP tool with consent;
7. build, test, debug, and review evidence;
8. restart the IDE, resume the journey, and exit without orphan processes.

**Acceptance:** versioned evidence for Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64; green
Delphi, web, documentation, and Sonar gates; ten consecutive use and shutdown cycles; documentation
validated against UI, commands, and runtime catalog.

**Still missing:** none of the six points in this goal.

## Order, dependencies, and complexity

| Order | Phase | Main point | Complexity | Dependency |
|---:|---|---|---|---|
| 1 | Phase 0 | Contracts | Medium | None |
| 2 | Phase 1 | CLI continuity | High | Phase 0 |
| 3 | Phase 2 | Unified context | High | Phase 1 |
| 4 | Phase 3 | Hierarchical settings | High | Phases 0–2 |
| 5 | Phase 4 | FIM | High | Phases 0 and 3 |
| 6 | Phase 5 | Block gutter | High | Phases 2 and 4 |
| 7 | Phase 6 | External MCP | Very high | Phases 0, 2, and 3 |
| 8 | Phase 7 | Integrated gate | Very high | All |

## Required evidence per stage

Every closed stage publishes covered requirements, changed surfaces, unit and integration tests,
runtime smokes, Sonar result, target-specific evidence, updated documentation and hints, a concise
remaining-goal summary, and a pushed working-branch commit.

## Completion definition

The goal is not complete while any gap is only prototyped, documented, available through one
executor, or validated on part of the matrix. The final audit maps every requirement in this file
to code, tests, runtime evidence, and documentation.
