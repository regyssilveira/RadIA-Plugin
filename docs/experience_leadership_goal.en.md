# RadIA 2.0 goal: leading the Delphi experience

> **Status:** planned and in progress.
> **Target version:** 2.0.0, not yet published.

## Objective

Deliver the most complete agentic development experience for Delphi, continuously covering typing,
chat, reviewable editing, Form Designer, terminal, build, tests, debugging, knowledge, and delivery
without compromising safety, transparency, or compatibility.

Leadership must come from the integrated journey rather than an isolated tool count. Every
capability must be discoverable, observable, cancellable, and proven in a real IDE.

## Principles

1. Stay in the IDE flow from the first character to the commit.
2. Treat the live buffer and actual IDE state as primary sources.
3. Require preview, consent, and rollback in proportion to risk.
4. Work with the native agent, API providers, CLIs, and local models.
5. Make extensions simple without weakening confinement or auditability.
6. Concentrate compatibility on Delphi 12 Win32 and Delphi 13 Win32/IDE64.
7. Do not publish while objective gates remain open.

## Measurable outcomes

| Outcome | Acceptance target |
|---|---|
| Quality | Green global Sonar gate, zero vulnerabilities, and zero new issues |
| Inline assistance | First suggestion within 700 ms at p95 after debounce |
| Inline acceptance | Accept, reject, and switch suggestions using only the keyboard |
| Terminal | Interactive shell with ANSI, resize, continuous stdin, and tree shutdown |
| Journey | One panel follows intent, plan, tools, diffs, build, tests, and debugging |
| Extensibility | Install a declarative extension without recompiling or restarting the IDE |
| Knowledge | Local, incremental, opt-in, rebuildable lexical and semantic search |
| Installation | Finish the first workflow without manual configuration-file editing |
| Stability | Ten consecutive cycles per supported combination without leaks or orphan processes |

## Leadership scorecard

RadIA will only be considered the leader when it simultaneously exceeds the following axes.
Matching one isolated capability is not sufficient:

| Axis | Mandatory leadership evidence |
|---|---|
| Delphi journey | Create, edit, design, build, test, debug, fix, and deliver without leaving the IDE |
| Continuous assistance | Chat, Ghost Text, and contextual actions share context, policy, and history |
| IDE control | Live buffer, project, Form Designer, build, tests, and debugger are observed through OTA |
| Hybrid execution | Native agent, providers, CLIs, and local models use the same tools and consent layer |
| Security | Every relevant mutation has preview, scope, consent, audit, and proportional rollback |
| Transparency | Plan, tool, diff, cost, tokens, duration, result, and failure remain visible |
| Extensibility | Commands, skills, templates, and tools can be installed with explicit permissions |
| Knowledge | Incremental lexical and semantic retrieval is private, citable, and workspace-isolated |
| Operations | Installation, diagnostics, updates, repair, and removal are guided and reproducible |
| Compatibility | The same experience passes on Delphi 12 Win32 and Delphi 13 Win32/IDE64 |

Each axis receives one of these states: `missing`, `partial`, `equivalent`, or `leader`. The release
decision requires `leader` on every axis together with the M8 evidence.

## Execution status

| Milestone | Status | Gate to advance |
|---|---|---|
| M0 — Quality | Completed | Automated green global Sonar gate |
| M1 — Inline assistance | Completed | OTA Ghost Text, shortcuts, consent, and real matrix approved |
| M2 — Terminal | Complete | PTY, ANSI/CSI, tabs, stdin, resize, and process-tree shutdown validated |
| M3 — Unified center | Completed | Observable, pausable, resumable, and persistent journey |
| M4 — Extensions | Completed | Declarative installation and workflows proven in the real matrix |
| M5 — Knowledge | Completed | Private hybrid search proven in the real matrix |
| M6 — Installation | In progress | First value proven; signed channel remains pending |
| M7 — Journeys | Completed | End-to-end Delphi recipes approved |
| M8 — Proof and release | Completed | Matrix, ten cycles, and audits approved |

M1 now includes a Fill-in-the-Middle engine, debounce, cancellation, cache, limits, a decoupled
provider, opt-in continuous capture, scope controls, and OTA Ghost Text. Capture uses the live
buffer, cursor position, and current symbol. All five shortcuts are configurable OTA bindings,
validated and reloaded without restarting the IDE. Multiline suggestions now use per-line virtual
overlays, preserve line breaks on acceptance, and keep continuations separate from real code.
Visual acceptance passes on Delphi 12 Win32 and Delphi 13 Win32/IDE64. Evidence records
two-line preparation and OTA painting separately without persisting editor content.

M2 includes a visual ANSI/CSI buffer with cursor overwrite, rich output, continuous stdin, ConPTY
execution, character-dimension resize, reverse history search through `Ctrl+R`, and multiple tabbed
sessions. Each tab owns independent process, input, output, and lifecycle state. Styling and parser
state remain intact even when an escape sequence is split across chunks.

## Milestone transition rules

1. Code, documentation, and unit tests form one delivery.
2. A visual capability only finishes after validation in a real IDE.
3. A provider or CLI integration only finishes after cancellation, timeout, and failure are exercised.
4. A mutation only finishes after preview, consent, concurrent conflict, and rollback are tested.
5. Every round queries Sonar; no new issue may be incorporated into the baseline.
6. Every completed increment is committed and pushed from the working branch.
7. Release gates always use Delphi 12 Win32 and Delphi 13 Win32/IDE64.

## Milestones

### M0 — Blocking quality

- Resolve active Sonar bugs and code smells at their root causes.
- Automate lint, catalog, matrix, package integrity, and Sonar gates.
- Block release preparation when a mandatory gate fails.

**Outcome:** green global baseline and reproducible local pipeline.

M0 is complete with reproducible evidence in
[`sonar_quality_evidence_2.0.0.json`](sonar_quality_evidence_2.0.0.json): Quality Gate `OK`, zero
bugs, vulnerabilities, security hotspots, code smells, and unresolved issues; 82.3% global coverage,
2.3% duplication, and A ratings for reliability, security, and maintainability.

### M1 — Inline assistance and Ghost Text

- Build a decoupled Fill-in-the-Middle suggestion engine.
- Capture bounded prefix, suffix, language, symbol, and project context.
- Add debounce, cancellation, cache, and local and remote provider support.
- Render without changing the buffer before acceptance.
- Support accept all, accept next word, reject, and request alternative.
- Allow per-project, file, language, and session disablement.

**Outcome:** continuous, fast, reversible suggestions in the Delphi editor.

### M2 — First-class interactive terminal

- Replace command execution with a Windows-compatible pseudo-terminal layer.
- Support ANSI, colors, cursor, resize, continuous input, tabs, and multiple sessions.
- Add profiles, history, reverse search, snippets, and a command palette.
- Give terminal agents the same MCP, consent, diff, and audit path as chat.
- Shut down the full process tree without blocking IDE shutdown.

**Outcome:** a complete dockable terminal suitable for daily work.

### M3 — Unified execution center

Delivered in this increment: the live card is now an auditable timeline with the current message,
limits, tokens, cost, duration, correlation, arguments, results, errors, mutations, and build and
test indicators. The **Runs** button and `/agent history` search checkpoints by objective, status,
or session without exposing tool payloads.
The **Edit plan** editor and `/agent plan` revise 1–50 steps while execution awaits approval,
preserving the checkpoint and blocking changes after the first tool. Safe step replay is available
as well: **Replay step** and `/agent replay` repeat a call only in a paused run, pass
through consent again, record the source step, and remain paused for review.
Each step now presents the tool's formal risk classification and aggregates affected files from
recognized path fields. The summary does not interpret free-form argument or result text, avoiding
the exposure of arbitrary content as if it were a path.
Validation evidence is no longer merely binary: the checkpoint and live card show build status
and duration, compiler message count, and the DUnitX summary with totals, passes, failures, errors,
and ignored tests.
`PreparePatch`, `ApplyPatch`, `RevertPatch`, and their multi-file variants now include a visual
per-file review inside the timeline. The block shows three context lines and removed/added line
counts, and it does not provide a parallel mutation shortcut: apply and revert remain behind the
central consent flow.
The Git journey is integrated as well: `GetGitStatus` shows repository status, `GetGitDiff` and
`PreviewGitCommit` present a colored unified diff with file and line counts, and `CommitChanges`
records the resulting local SHA. The preview keeps its message, paths, and fingerprint visible
without offering an automatic push.
The debugging journey now has dedicated evidence as well: process state, source location, threads,
breakpoints, call stack, execution transitions, evaluated values, watches, and timeline events
appear inside their corresponding step. The visual layer consumes only the audited tool result and
bounds long lists, without introducing polling or controlling a session on its own.

The runtime journey is proven on Delphi 12 Win32 and Delphi 13 Win32/IDE64. The smoke uses a
deterministic local provider, executes `GetIDEState` through the real registry and policy, pauses
after the step, persists the checkpoint, destroys the runtime, and resumes in another instance
until completion. The versioned matrix is stored in `agent_runtime_smoke_evidence_2.0.0.json`.

- Build one timeline for intent, plan, model, tools, consent, and results.
- Include block diffs, build, tests, coverage, debugging, and Git.
- Support pause, cancellation, plan editing, step replay, and checkpoint resume.
- Show tokens, cost, time, changed files, and risk.
- Persist searchable sessions without secrets.

**Outcome:** the user always understands the current state and next action.

### M4 — Accessible extension platform

- Define versioned manifests for commands, prompts, skills, templates, and tools.
- Support declarative and scripted extensions while preserving the advanced BPL API.
- Validate signatures, permissions, paths, dependencies, versions, and integrity.
- Isolate execution and route every mutation through central policy.
- Add a visual manager and publish an SDK, examples, and package validator.

**Delivered so far:** hot-reload command manifests, transactional installation, closed packages
with limits and SHA-256, RSA-SHA256 through Windows CNG, fingerprints, first-use consent, a local
trust store, and visual publisher revocation. The remote catalog now has an asynchronous visual
browser, search, persisted URL, schema, HTTPS, limits, transactional downloads, and signed-package
binding. Schema 2 delivers hot-reloaded prompt commands, templates, and skills. Schema 3 adds
internal tool aliases with an extension-owned namespace, explicit `tool.alias` permission,
inherited risk metadata, shared chat/MCP registration, and catalog rollback on failure. Schema 5
replaces arbitrary scripts with workflows of 1–16 internal tools: risk, timeout, and idempotency
are derived, and every step re-enters consent and auditing.

**Outcome:** simple capabilities can be added without rebuilding RadIA or restarting the IDE.

### M5 — Private semantic knowledge

- Preserve deterministic lexical search as a fallback.
- Add optional embeddings and local vector storage.
- Support explicit consent, exclusions, and local or remote embedding providers.
- Incrementally index code, forms, projects, docs, symbols, and approved history.
- Explain every retrieved source and allow direct navigation.

**Outcome:** relevant large-solution context with privacy and traceability.

**Delivered:** hybrid retrieval with deterministic lexical fallback, an optional embedding
contract, a network-free local vector provider, versioned per-workspace persistence, and lexical
plus vector explanations for every result.

Local visual consent is now available under **Settings > Security & Consent**, disabled by default
and applied immediately without restarting the IDE. Configurable file and project exclusions block
queries immediately and remove persisted content on the next refresh. The optional
OpenAI-compatible remote provider remains inactive until the user explicitly authorizes it.

The remote integration includes an injectable OpenAI-compatible transport, HTTPS or loopback
endpoints, disabled redirects, timeouts, input and response limits, validated dimensions, and API
keys kept outside JSON. Failures continue to fall back to lexical search. Activation requires
separate remote consent and explicit visual configuration.

Remote embedding selection is now fail-closed: semantic search and network authorization are
independent decisions. Without remote enablement, separate consent, and a valid provider, the index
keeps using only the local provider. The settings screen exposes endpoint, model, protected
credential, dimensions, timeout, and input limit and applies changes without restarting the IDE.

Search and rebuild operations now publish local latency in milliseconds, status reports the
estimated index size, and every response preserves the project identity. With explained scores,
direct navigation, and independent workspace tests, relevance, latency, size, rebuild, and
isolation now have observable evidence without telemetry.

Incremental indexing now covers Pascal, textual DFM/FMX companions, DPROJ/GROUPPROJ files, and
Markdown, text, AsciiDoc, and reStructuredText documentation. Documentation discovery is confined
to the root and `docs/doc` folders with file-count, size, and workspace-boundary limits; the OTA
notifier uses the same centralized format policy.

For approved history, the sanitized checkpoint catalog preserves `projectId` and `planApproved`.
Its bounded query returns only completed runs with an approved plan belonging exactly to the
requested project. Opt-in ingestion adds these summaries to the index without exposing tool
arguments or results, and revocation blocks queries before physical removal on the next refresh.

The real semantic journey passes on Delphi 12 Win32 and Delphi 13 Win32/IDE64. The evidence
indexes the test project, searches semantically with `local-hash-v1`, and verifies provenance,
navigation, metrics, document retrieval, and workspace isolation. The versioned matrix is stored
in `knowledge_smoke_evidence_2.0.0.json`.

### M6 — Installation and first value

- Create a signed visual installer and prepare an IDE package-manager channel.
- Detect Delphi, architecture, WebView2, CLIs, authentication, and incompatible settings.
- Delegate third-party CLI installation to official channels with consent.
- Guide login without collecting credentials.
- Diagnose chat, provider, terminal, MCP, and the first tool after installation.
- Provide complete repair and removal workflows.

**Outcome:** first reviewed change without manual configuration-file editing.

Onboarding version 2 runs `/doctor` from a dedicated button. The diagnostic returns structured
checks, a score, and the next action, verifies `GetIDEState` as the first read-only tool, and does
not require MCP when the native executor is selected.

The release package now uses the same validated installer for `Install`, `Repair`, and `Uninstall`,
provides a read-only plan, preserves data and shared components by default, and requires
`-RemoveUserData` before deleting settings, audit, sessions, and knowledge.

The single visual installer detects and selects Delphi 12 Win32 and Delphi 13 Win32/IDE64.
Generation validates all three packages before compilation, records
SHA-256 and Authenticode state, and can sign with a certificate and timestamp. The `stable`
catalog is fail-closed: it rejects HTTP and any executable without a valid signature. Publication
remains pending only on a trusted external code-signing certificate and the final HTTPS URL. The
release workflow rebuilds all three targets from the tag, imports the PFX only for the job, requires
a signature and timestamp, publishes the distribution, and removes cryptographic material from
the runner even after failure.

The post-install diagnostic passes on Delphi 12 Win32 and Delphi 13 Win32/IDE64. The
evidence calls the doctor through the installed bridge, requires chat, terminal, the 90-tool
catalog, and `GetIDEState`, and preserves an actionable next step when the provider is not yet
configured. The versioned matrix is stored in `first_value_smoke_evidence_2.0.0.json`.

### M7 — Specialized journeys

- [x] Deliver auditable recipes for application creation, build repair, testing, and debugging.
- [x] Add Delphi-specific modernization for units, forms, packages, and dependencies.
- [x] Migrate legacy patterns with preview and compile gates.
- [x] Add a project-health card with a score, risks, and reviewable prioritized journeys.
- [x] Allow teams to share recipes and policies without sharing credentials.

**Outcome:** complete Delphi workflows rather than isolated requests.

The seven native recipes now contain four ordered phases, required evidence per phase, and three
completion criteria embedded in the Agent Runtime objective. User context remains separate and
cannot replace consent, plan review, or completion gates.

The catalog now contains seven recipes. `/journey modernize` inventories units, forms, packages,
dependencies, and targets before applying coherent batches. `/journey migrate` requires a
baseline, bounded scope, reversible transaction, and build, test, and health comparison per batch.

Declarative schema 4 publishes journeys and policies with hot reload. Shared journeys enter Agent
Runtime with mandatory RadIA gates appended; policies expand only through an explicit command.
Credential fields are rejected recursively and never enter extension packages.

### M8 — Leadership proof and release

- [x] Run the complete build and test matrix.
- [x] Validate inline assistance, terminal, execution center, extensions, and knowledge in real IDEs.
- [x] Approve complete keyboard and assistive-technology navigation in all three combinations.
- [x] Complete ten uninstall, install, repair, usage, and shutdown cycles per supported combination.
- [x] Validate a real upgrade between different package versions on every supported combination.
- [x] Pass the create, edit, design, test, debug, fix, and commit continuous journey.
- [x] Regenerate three packages from one commit and publish independent hashes.
- [x] Bind real IDE smoke tests to the package, commit, and installed BPL with fail-closed JSON evidence.
- [x] Automate the final security, privacy, accessibility, and documentation audit.

**Outcome:** a proven, reproducible 2.0.0 candidate ready for a publication decision.

The reproducible proof in `release_evidence_2.0.0.json` contains the three ZIP files in the active
matrix. All were built from commit `ad0b5a250cb9e7f7de8d390d84db1e15d8a43b10`, with internal
validation, independent SHA-256 hashes, and a clean tracked worktree.

The matrix in `ide_smoke_evidence_2.0.0.json` records the previous historical validation. The new
release proof must cover Delphi 12 Win32 and Delphi 13 Win32/IDE64, complete 10/10 cycles per target,
and validate the current 95-tool catalog. Every target must exercise native `TOTADockForm`
docking, restore the desktop state, and exit without
orphan processes. Every cycle ran `Uninstall`, installed version 1.0.0, upgraded to 2.0.0, and ran
`Repair`, while preserving user data and revalidating the manifest, hashes, registry, and installed
files before launching the IDE. The fail-closed consolidator derives the official proof from all
three execution JSON files and rejects target, cycle, upgrade, lifecycle, hash, commit, docking, BPL,
or catalog divergence.

The complete continuous journey is proven in
`continuous_journey_smoke_evidence_2.0.0.json`. In one flow from the same commit, every target
created and built a VCL project, changed and reverted the Form Designer, edited and saved the live
buffer, observed an intentional compiler failure, reverted the correction, rebuilt, passed 761
tests, stopped at a breakpoint with call stack and timeline evidence, created a reviewed Git
commit, and shut down without orphan processes. Delphi 12 Win32 and Delphi 13 Win32/IDE64
passed autonomously. The consolidator rejects dirty source, divergent SHAs, invalid installed-BPL
hashes, missing phases, incomplete tests, debugging without evidence, or a commit without a
reviewed diff.

Functional validation of all five surfaces in real IDEs is also complete. The terminal has
dedicated proof in `terminal_smoke_evidence_2.0.0.json`: its native window, required controls,
input, output, usable geometry, five associated labels, and nine keyboard tab stops passed on
Delphi 12 Win32 and Delphi 13 Win32/IDE64. The Delphi 13 IDE64 UI Automation tree confirmed
chat names, states, and descriptions, including Agent Mode, terminal, run history, settings,
conversation, and prompt. Inline assistance, the agent center, extensions, and knowledge remain
bound to their versioned matrices and the native-control or shared Web semantics used by all
targets.

The reproducible audit is stored in `release_audit_2.0.0.en.md`. It removed the only silent Web
connection at startup, added semantics and keyboard operation to Web surfaces, created a local
link and mojibake gate, and consolidated assistive-technology acceptance.

## Execution order

```text
M0 Quality
  ├── M1 Inline assistance
  ├── M2 Interactive terminal
  └── M3 Unified center
        ├── M4 Extensions
        ├── M5 Knowledge
        └── M6 Installation
              └── M7 Specialized journeys
                    └── M8 Proof and release
```

M1, M2, and the visual foundation of M3 may proceed in parallel after M0. M4 and M5 depend on the
policy, audit, and observability consolidated in M3. Publication depends on every milestone.

## Definition of Done

- The user receives assistance before, during, and after writing code.
- Chat and terminal have the same reach, safety, and review.
- Every suggestion or mutation can be understood, rejected, cancelled, or reverted.
- Extensions cannot bypass consent, workspace boundaries, or audit.
- Semantic knowledge is optional, private, and traceable.
- Installation, updates, repair, and removal are guided.
- Logs, telemetry, persisted prompts, and artifacts contain no secrets.
- Sonar, lint, tests, packages, and the IDE matrix remain green.
- The full journey passes on Delphi 12 Win32 and Delphi 13 Win32/IDE64.
