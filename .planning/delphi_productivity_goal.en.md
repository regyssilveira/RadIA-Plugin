# Delphi experience and productivity goal

## Objective

Allow a developer with minimal RadIA knowledge to describe a common objective in natural language
and obtain safe execution, readable progress, and verifiable evidence in Delphi 12 and 13.

## Observable outcome

RadIA must guide creation, understanding, refactoring, build, tests, debugging, performance, data
access, dependencies, and localization without requiring knowledge of modes, journeys, or internal
tools.

## Strategy

1. Reuse current tool, consent, transaction, fingerprint, and rollback contracts.
2. Deliver demonstrable vertical slices rather than isolated infrastructure.
3. Treat Delphi 12 and 13 differences as runtime-detected capabilities.
4. Keep the current WebView and evolve only required contracts and components.
5. Do not reserve a version until a milestone has approved builds, tests, and documentation.

## Cross-cutting foundation — usage test automation

Complete coverage will be built as a capability matrix rather than one fragile test that controls
the entire IDE. Each scenario declares Delphi version, surface, preconditions, actions, evidence,
and cleanup.

### Layer A — headless integration

- Exercise provider, tool, consent, transaction, and adapter contracts with deterministic doubles.
- Run without Delphi and fail quickly on contract regressions.

### Layer B — OTA integration

- Start a disposable Delphi 12 or 13 instance with an isolated Registry profile when allowed by the
  OTA.
- Install the locally produced package, open fixture projects, and invoke real IDE commands.
- Query state through an authenticated test channel compiled only into the harness.

### Layer C — end-to-end journeys

- Automate installation, onboarding, chat, consent, and visual surface actions.
- Validate project creation, editing, Designer, build, DUnitX, debugger, runtime, terminal, and
  failure recovery.
- Collect screenshots, sanitized logs, events, produced files, and functional results.

### Isolation and stability

- Use per-run workspaces, configuration, cache, fake credentials, and temporary projects.
- Separate deterministic offline scenarios from optional smoke tests requiring a real provider.
- Forbid absolute coordinates, fixed sleeps, or personal IDE state.
- Terminate child processes and restore Registry, files, and packages even after timeouts.
- Classify tests as `smoke`, `critical`, `extended`, and `provider-live`.

### First critical matrix

1. install and load RadIA in Delphi 12 and 13;
2. open chat, run `/doctor`, and validate diagnostics without a provider;
3. configure a simulated provider and receive a streaming response;
4. create, open, and build a VCL calculator;
5. run DUnitX and parse a controlled failure;
6. prepare, consent to, apply, and revert a change;
7. start the debugger, stop at a breakpoint, and inspect the stack;
8. open the terminal, run a command, and close the session;
9. close the IDE without a deadlock, AV, or orphan process.

Every improvement in this goal is complete only after adding or updating a scenario in this matrix.

### Foundation status

- Versioned contract, runner, and `startup` profile: complete.
- Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64: executed successfully.
- VCL calculator: `2 + 3 = 5` UI and five DUnitX tests proven on Delphi 12 and 13 compilers.
- Immediate project creation and opening: proven on all three IDE targets.
- Mandatory release-process integration: complete.
- Doctor, simulated provider, consent, failing DUnitX, debugger, and terminal scenarios: pending to
  expand the profile beyond startup.

## Milestones and dependencies

### M1 — universal experience

1. Define a small intent taxonomy and confidence levels.
2. Create a deterministic router with explicit fallback and local-only telemetry.
3. Unify the finding model used by existing surfaces.
4. Deliver a problems panel with filters, navigation, and safe actions.
5. Validate creation, build, test, and diagnostic prompts with beginner users.

Status: deterministic classification and the reviewable recommendation card are complete for
creation, build, tests, and diagnostics. The unified findings contract and Problems panel with
filters, safe navigation, and reviewable actions are also complete. Local telemetry and broader
validation with beginner users remain pending.

Dependencies: journeys, Agent Runtime, Tool Registry, Tool Views, and Project Health.

### M2 — code intelligence

1. Extend the index with symbol identities and references.
2. Deliver read-only Find All References.
3. Deliver transactional Rename Symbol for Pascal and DFM.
4. Build an impact graph connecting diffs, symbols, and DUnitX tests.
5. Select, execute, and explain affected tests.
6. Expand refactorings only after the foundation meets its gates.

Dependencies: Semantic Engine, DFM/Pascal Audit, MultiFilePatch, DevelopmentTransaction, DUnitX,
and Coverage.

### M3 — advanced diagnostics

1. Create a factual matrix of OTA breakpoint capabilities by IDE version.
2. Deliver conditions, hit counts, exceptions, and logpoints only where reliable.
3. Design an authenticated, bounded channel for the VCL adapter inside the debugged process.
4. Automate windowless controls through component identity.
5. Define bounded performance baselines and metrics.
6. Compare before-and-after evidence through versioned scenarios.

Dependencies: Debugger, RuntimeScenario, RuntimeEvidence, VisualRuntimeSession, and consent.

### M4 — Delphi ecosystem

1. Define read-only inventories for FireDAC, dependencies, and localization.
2. Deliver dependency diagnostics before any installation automation.
3. Deliver FireDAC analysis without storing credentials or running mutable SQL by default.
4. Prepare transactional text extraction to `resourcestring`.
5. Compare layouts across languages through existing snapshots.

Dependencies: DelphiEnvironment, ProjectKnowledge, DesignerVisualDiff, and DevelopmentTransaction.

## Cross-cutting gates

- Security and capability contract before every OTA or runtime adapter.
- No mutation without preview, consent, fingerprint, and rollback.
- Unit, OTA integration, and end-to-end tests on Delphi 12 and 13.
- Win32 and IDE64 builds where applicable.
- pt-BR/en-US documentation, hints, and documentation tests in the same delivery.
- Passing SonarQube with no suppressions.

## First executable slice

Implement the intent router in recommendation mode without automatic execution. It must classify
creation, build, test, and diagnostic prompts, explain the selected route, and let the user confirm,
review, or remain in regular chat. This slice validates the experience before expanding mutation
power.
