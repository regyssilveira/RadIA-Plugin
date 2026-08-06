# RadIA 2.0 technical leadership plan

> **Status:** frozen until version 2.0.0 is published.
> **Scope:** Delphi 12 Win32 and Delphi 13 Win32/IDE64.
> **Out of scope:** C++Builder, marketplace distribution, mandatory Authenticode signing, and
> replacement of the current WebView2 host.
> **Resume point:** start at Phase 0 — Baseline and contracts, without reopening scope decisions.

## Goal

Turn the delivered hybrid foundation into a continuous, provable experience: discover an executor,
authenticate, start or resume a conversation, share its context across chat, terminal, and editor,
review changes, and complete the journey inside the IDE.

The installer remains a convenience for an open-source project that users can also build. Missing
code signing does not block version 2.0. Distribution must publish a SHA-256 hash and reproducible
build and installation instructions.

## Ideas selected from the updated external review

The updated implementation review identified four ideas with material value:

1. Capture and persist each CLI conversation identifier so a session can continue instead of
   restarting on every message.
2. Treat configuration writes as transactions so two screens or services cannot erase each
   other's fields.
3. Bind consent requests to the execution and session that created them, explicitly preserving or
   cancelling a request when a chat is closed or changed.
4. Validate executors with real accounts in an end-to-end matrix covering streaming,
   cancellation, resume, MCP, and shutdown.

CLI inline completion, installation and authentication diagnostics, Copilot CLI, and Ghost Text
already exist in RadIA. They are part of the integrated gate and are not duplicate implementation
items.

SQLite is not an initial requirement. A persistence migration will only be considered if
measurements prove latency, excessive growth, or query needs that the current storage cannot meet.
WebView2 remains unchanged and creates no future item or backlog.

## Execution plan

### Phase 0 — Baseline and contracts

- Map the current Codex, Claude, Gemini, and GitHub Copilot executor lifecycle.
- Define a shared conversation identity, resume capability, and diagnostic contract.
- Record which CLIs provide stable identifiers and the safe fallback for those that do not.
- Add contract tests for arguments, parsing, timeout, cancellation, and partial output.

**Acceptance:** a versioned capability matrix, green current tests, and no new Sonar issue.

**Still missing afterward:** real persistence, cross-surface sharing, guided UX, and authenticated
proof.

### Phase 1 — Native CLI continuity

- Capture each executor's session or conversation identifier.
- Persist executor, model, working directory, and identifier without credentials.
- Resume conversations where supported.
- Clearly report whether a conversation resumed or started fresh.
- Prevent late output from being attached to the wrong session.

**Acceptance:** close and reopen the panel, continue a supported conversation, and prove that
messages cannot cross sessions.

**Still missing afterward:** shared chat, terminal, and editor context; transactional settings;
consent lifecycle; and the real matrix.

### Phase 2 — Unified chat, terminal, and editor context

- Bind chat and terminal to the same conversation identity when the user chooses to continue.
- Start, select, resume, and detach a session by both button and command.
- Reuse CLI selection, project, model, and diagnostics across all three surfaces.
- Keep tools, MCP, consent, audit, and workspace boundaries under RadIA policy.
- Show executor, authentication state, and session state without opening Settings.

**Acceptance:** a journey starts in chat, continues in terminal, and requests an editor completion
without losing executor, project, or conversation identity.

**Still missing afterward:** concurrency hardening, resilient consent, and authenticated proof in
the supported IDEs.

### Phase 3 — Resilient settings and consent

- Centralize settings updates as atomic read, merge, and write operations.
- Test two concurrent writers while preserving unknown fields.
- Bind each consent request to its execution and session identifier.
- Define deterministic behavior for chat switching, closing, and resuming.
- Discard stale cards, indicators, and callbacks without answering for the user.

**Acceptance:** concurrent tests lose no configuration and no consent becomes orphaned, targets the
wrong session, or receives an implicit decision.

**Still missing afterward:** advanced CodeInsight experience and the full authenticated matrix.

### Phase 4 — Advanced editor integration

- Unify context sources across Ghost Text, contextual actions, inline review, and chat.
- Navigate alternatives without writing to the buffer before acceptance.
- Show suggestion source, executor, and state accessibly.
- Preserve configurable shortcuts and return keys to the IDE when no valid suggestion exists.
- Cancel stale suggestions when caret, revision, or buffer changes.

**Acceptance:** accept, reject, and cycle alternatives from the keyboard, with a single undo and no
premature buffer change.

**Still missing afterward:** only end-to-end proof and final version gates.

### Phase 5 — Authenticated CLI matrix and closure

Run Codex, Claude, Gemini, and GitHub Copilot across the three supported combinations:

- detection, version, and authentication guidance;
- conversation start and resume;
- streaming and partial output;
- cancellation, timeout, and process-tree termination;
- read-only MCP call and consented mutation;
- chat and terminal continuity;
- inline completion and stale response rejection;
- IDE shutdown without orphan processes.

**Acceptance:** versioned evidence per CLI and target, green build and tests, green Sonar, and ten
consecutive install, use, docking, and shutdown cycles.

**Still missing afterward:** no mandatory technical item from this goal.

## Order and complexity

| Order | Phase | Complexity | Dependency |
|---:|---|---|---|
| 1 | Baseline and contracts | Low | None |
| 2 | Native CLI continuity | High | Phase 0 |
| 3 | Unified context | High | Phase 1 |
| 4 | Settings and consent | Medium | Phases 0 and 1 |
| 5 | Advanced editor integration | High | Phases 2 and 3 |
| 6 | Authenticated matrix | High | All |

## Permanent rules

- Check Sonar in every round and accept no new issue.
- Commit and push every completed stage from the working branch.
- At the end of every stage, report what closed, its evidence, and what remains for the goal.
- Do not expand scope to C++Builder, marketplace distribution, or a new WebView2 host.
- Do not block publication because a code-signing certificate is unavailable.
