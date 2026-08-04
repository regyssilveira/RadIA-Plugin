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
6. Preserve Delphi 11, 12, 13 Win32, and Delphi 13 IDE64.
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

## Milestones

### M0 — Blocking quality

- Resolve active Sonar bugs and code smells at their root causes.
- Automate lint, catalog, matrix, package integrity, and Sonar gates.
- Block release preparation when a mandatory gate fails.

**Outcome:** green global baseline and reproducible local pipeline.

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

**Outcome:** simple capabilities can be added without rebuilding RadIA or restarting the IDE.

### M5 — Private semantic knowledge

- Preserve deterministic lexical search as a fallback.
- Add optional embeddings and local vector storage.
- Support explicit consent, exclusions, and local or remote embedding providers.
- Incrementally index code, forms, projects, docs, symbols, and approved history.
- Explain every retrieved source and allow direct navigation.

**Outcome:** relevant large-solution context with privacy and traceability.

### M6 — Installation and first value

- Create a signed visual installer and prepare an IDE package-manager channel.
- Detect Delphi, architecture, WebView2, CLIs, authentication, and incompatible settings.
- Delegate third-party CLI installation to official channels with consent.
- Guide login without collecting credentials.
- Diagnose chat, provider, terminal, MCP, and the first tool after installation.
- Provide complete repair and removal workflows.

**Outcome:** first reviewed change without manual configuration-file editing.

### M7 — Specialized journeys

- Deliver auditable recipes for application creation, build repair, testing, and debugging.
- Add Delphi-specific modernization for units, forms, packages, and dependencies.
- Migrate legacy patterns with preview and compile gates.
- Add a project-health panel and shareable team recipes and policies.

**Outcome:** complete Delphi workflows rather than isolated requests.

### M8 — Leadership proof and release

- Run the complete build and test matrix.
- Validate inline assistance, terminal, execution center, extensions, and knowledge in a real IDE.
- Complete ten installation, usage, update, and shutdown cycles per supported combination.
- Pass the create, edit, design, test, debug, fix, and commit continuous journey.
- Regenerate four packages from one commit and publish independent hashes.
- Complete security, privacy, accessibility, and documentation audits.

**Outcome:** a proven, reproducible 2.0.0 candidate ready for a publication decision.

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
- The full journey passes on Delphi 11, 12, 13 Win32, and Delphi 13 IDE64.
