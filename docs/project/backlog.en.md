# RadIA backlog

This file contains open work only. History, completed milestones, metrics, and release notes do not
belong in the backlog.

The backlog does not record versions, completed deliveries, evidence, or internal plans.

## Active goal: complete and deterministic Delphi experience

Turn common Delphi developer objectives into simple, safe, and verifiable flows, reusing existing
tools before expanding the catalog.

The order below is mandatory; items within a milestone may run in parallel only when they do not
share contracts or IDE surfaces. Internal engineering plans remain separate from public
documentation.

## Cross-cutting foundation — automated usage tests

- [ ] **Integration and end-to-end platform:** automate isolated installation, Delphi startup,
  sanitized configuration, chat, tools, editor, Designer, build, tests, debugger, terminal, consent,
  and failure recovery on Delphi 12 and 13 targets.

The platform must have three layers:

1. service and adapter integration without opening the IDE;
2. OTA integration loaded into a disposable Delphi instance;
3. end-to-end user journeys with fixture projects, real actions, and verifiable evidence.

Gate: a clean run must install RadIA in an isolated environment, open every supported IDE, execute
the critical matrix, collect logs, screenshots, and structured results, and restore the environment
without human intervention. Failures must identify the stage, IDE version, and diagnostic artifact
without exposing credentials.

This gate is mandatory for every release together with calculator creation and functional testing
and immediate project creation, opening, and navigation.

## Milestone 1 — universal experience

- [ ] **Intent-driven universal command:** classify free-form requests, select chat, journey, or
  agent, and present a comprehensible action before execution.
- [ ] **Unified problems panel:** combine compiler, tests, coverage, FastMM5, DFM/Pascal audit,
  threading, and inline review findings with navigation and safe actions.

Gate: create, fix a build, test, and diagnose a defect from free-form prompts without requiring the
user to understand modes, journeys, or tool names.

## Milestone 2 — code intelligence

- [ ] **Safe semantic refactoring:** deliver Rename Symbol and Find All References first with
  preview, Pascal/DFM consistency, multi-file transactions, and rollback; then expand to
  hierarchies, Extract Method, Move Type, and Change Signature.
- [ ] **Impact-based test selection:** relate diffs, symbols, dependencies, fixtures, and coverage to
  execute and justify the smallest safe DUnitX test set.

Gate: rename a symbol used by multiple units and a DFM, run only affected tests, and revert the
entire operation without losing code.

## Milestone 3 — advanced diagnostics

- [ ] **Advanced debugger:** conditional breakpoints, hit counts, exceptions, and logpoints while
  respecting the effective capabilities of Delphi 12 and 13.
- [ ] **Automation for windowless controls:** add an authorized VCL adapter for `TGraphicControl`,
  frames, and custom controls without global coordinates.
- [ ] **Performance diagnostics:** measure scenarios, main-thread stalls, CPU, memory, and duration,
  comparing evidence before and after a correction.

Gate: reproduce a conditional defect, interact with a control without an `HWND`, and prove a
performance improvement across comparable executions.

## Milestone 4 — Delphi ecosystem

- [ ] **FireDAC and database assistant:** inventory connections, queries, parameters, transactions,
  and datasets, operating read-only by default.
- [ ] **Delphi dependency health:** detect missing or incompatible libraries, packages, GetIt, Boss,
  paths, and versions and provide actionable guidance.
- [ ] **Localization and resource audit:** inventory Pascal/DFM text, prepare extraction to
  `resourcestring`, and verify languages and visual layout.

Gate: diagnose a data application on a clean machine and produce reviewable corrections for
dependencies, data access, and localization.

## Definition of done

Each item requires:

- a documented contract and threat model before implementation;
- proven Delphi 12 and 13 support, with unavailable capabilities reported explicitly;
- unit, OTA integration, and end-to-end tests proportional to risk;
- an automated usage scenario in the regression matrix for every new behavior;
- preview, consent, fingerprint, and rollback for every mutation;
- simultaneous updates to manuals, references, hints, translations, and documentation tests;
- passing local build, DUnitX, applicable lint, and SonarQube;
- observable outcome evidence, not merely the existence of classes or tools.
