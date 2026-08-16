# Deterministic competitive gap closure goal

## Objective

Close every actionable difference in RadIA's Delphi experience with reproducible evidence. The work
must produce user-visible gains and prevent delivered capabilities from being reported as pending
again without a proven regression.

## Observable outcome

A user with minimal RadIA knowledge can complete code with semantic resolution, implement contracts,
navigate, create and change forms, follow agent progress, work with databases, use the terminal,
authorize journeys, and understand the sources used by the assistant. These flows remain stable on
Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64.

## Permanent closure rule

Each workstream has a versioned record under `Output/Validation/CompetitiveClosure` with its baseline,
scenarios, metrics, result, and Git revision. A workstream becomes `closed` only when all criteria pass
on the same clean commit. It may then be reopened only by a reproducible regression, a user scenario
with expected and actual results, a same-environment material benchmark difference, or a new public
and comparable external capability. Marketing lists, vendor-exclusive integration, and unsupported
claims do not reopen work. Future comparisons must consume the last approved ledger first.

## Closed scope

1. semantic completion, missing members, navigation, and Ghost Text;
2. intent-driven journeys across Designer, Code, Problems, tests, and debugger;
3. simplified chat and observable native-agent and CLI progress;
4. a safe visual database experience;
5. a journey-aware terminal;
6. current-WebView dock, undock, resize, and recovery robustness;
7. explainable local knowledge;
8. journey-scoped consent;
9. semantic-engine isolation, recovery, and metrics.

## Out of scope

- a public extension repository, marketplace, or remote registry;
- C++Builder, Delphi 11, Lazarus, or DCU reading;
- GetIt, commercial signing, or Embarcadero-exclusive integration;
- replacing the current WebView2 or creating a DirectComposition component;
- reproducing proprietary capabilities without a verifiable public contract.

## Execution phases

| Phase | Delivery | Deterministic gate |
|---|---|---|
| F0 | Baseline manifest and closure ledger | Every criterion is evidence-backed as passed, failed, not-supported, or not-applicable before implementation starts. |
| F1 | Proven semantic intelligence | At least 99% corpus structural success, zero silent span divergence, warm p95 at most 50 ms, all missing-member fixtures compile on Delphi 12/13, idempotence, recovery, and ranked Ghost Text alternatives. |
| F2 | Intent-to-surface journey | A prompt creates and changes a VCL application, opens the correct Designer/Code/Problems/test/debug surface, builds, tests, and debugs on all targets without manual surface selection. |
| F3 | Chat and operational progress | Valid routes are recommended, incompatible combinations are hidden, consent is locatable, and no active period longer than two seconds shows only an unexplained thinking state. |
| F4 | Safe database journey | A local fixture supports schema discovery, reviewed read-only SQL, bounded execution, virtualized results, and sanitized export; destructive, secret, and unbounded cases are blocked. |
| F5 | Journey-aware terminal | Profiles, searchable palette, favorites, reverse history, safe file links, chat handoff, restoration, Unicode/TUI, and clean shutdown pass on all targets. |
| F6 | Current WebView lifecycle | Twenty-five dock/undock/resize cycles per target preserve content and recover focus with no persistent blank view, deadlock, AV, or orphan process. |
| F7 | Explainable knowledge | Fixture queries return deterministic sources and explain selection, absence, stale state, and fallback; excluded or cross-project content never leaks. |
| F8 | Journey-scoped consent | The calculator journey completes without redundant approvals while destructive actions remain individually confirmed; expiration, revocation, conflict, and project switching pass. |
| F9 | Semantic supervision | Fault injection for crash, hang, incompatible response, and invalid cache never blocks `bds.exe`, loses a buffer, or requires an IDE restart. |
| F10 | Integrated closure | Lint, docs/web tests, Delphi DUnitX, semantic corpus, benchmarks, OTA/E2E matrix, calculator, templates, Sonar, docs, installer, and one all-closed ledger pass on the same clean commit. |

## F1 mandatory semantic scenarios

- completion after `.` for locals, parameters, fields, properties, `Self`, `Result`, and globals;
- chains of at least four segments, inheritance, generics, aliases, and unit shadowing;
- independent Delphi 12 and 13 profiles with defines and inactive code;
- idempotent implementation of interfaces, abstract members, overloads, calling conventions, and generics;
- navigation across declaration, implementation, ancestor, override, Pascal reference, and DFM reference;
- bounded fallback when the semantic process is unavailable;
- up to three ranked Ghost Text alternatives with diagnosable latency and origin.

## Cross-cutting requirements

- no mutation without preview, consent, fingerprint, and rollback where applicable;
- no second semantic engine or duplicated source of truth;
- no unbounded SQL, arbitrary process, global coordinates, raw handle, or plaintext secret;
- PT-BR/en-US documentation, UI hints, and documentation tests in the same change;
- a usage-matrix scenario for every user-visible behavior;
- Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 evidence where applicable;
- approved SonarQube without suppressions.

## Execution order

`F0 -> F1 -> F2 -> F3 -> F4 -> F5 -> F6 -> F7 -> F8 -> F9 -> F10`.

F1 closes the semantic foundation used by later phases. F2 and F3 stabilize the primary experience.
Database and terminal work follow navigation and progress. Lifecycle, knowledge, consent, and
supervision consolidate the platform before final closure.

## Goal completion condition

The goal ends only when all nine workstreams are `closed` in the ledger for the same approved commit.
There is no partial release and no new competitive comparison may replace this gate.
