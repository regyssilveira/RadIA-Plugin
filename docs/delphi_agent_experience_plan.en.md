# Delphi agent experience program

## Objective

Evolve RadIA through nine integrated deliveries that make Delphi assistance visual, semantically
safe, environment-aware, suitable for legacy modernization, and demonstrable through reproducible
evidence. This document is an execution plan; only capabilities registered in the runtime catalog
and approved by their gates may be described as available.

## Execution principles

1. Reuse the OTA workspace, transactions, consent, auditing, checkpoints, and local knowledge.
2. Keep every mutation project-confined and protected by preview, fingerprint, and rollback.
3. Never capture code, screens, or metadata silently.
4. Deliver pt-BR/en-US documentation, hints, and tests with every visible behavior.
5. Validate Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 before completion.

## Deliveries and acceptance criteria

### E1 — Intelligent Delphi environment profile

Deliver `GetDelphiEnvironmentProfile` with IDE, architecture, project, framework, configuration,
platform, search paths, packages, and detected libraries. The response must identify each data
source, limit collections, exclude secrets, and remain read-only.

Acceptance: unit contracts, sanitized output, and smoke tests on all three supported targets.

### E2 — Curated and versioned Delphi knowledge

Deliver rules loaded on demand by version, framework, and topic, with stable identifiers, source,
applicability, and concise guidance. Organization rules may extend product rules but cannot
silently override product security rules.

Acceptance: deterministic lookup, version fallback, and rule citations in agent results.

### E3 — Bidirectional DFM/PAS auditor

Analyze `.pas`/`.dfm` pairs without changing files and detect missing or incompatible handlers,
inconsistent components and fields, unknown classes, duplicate names, and orphan references.
Corrections must be prepared through existing patch or transaction services.

Acceptance: positive and negative fixtures, no false positives in official fixtures, and fixes with
preview, concurrent-conflict detection, and rollback.

### E4 — Form Designer Visual Diff

Capture authorized previous and proposed states, generate structural and visual diffs, and present
them in the same timeline step. Images must remain local and follow configured retention.

Acceptance: creation, removal, property, and layout changes are comparable; rejection leaves the
Designer unchanged.

### E5 — Autonomous execution contract

Extend current budgets with completion criteria, mandatory gates, file and operation limits, pause
policy, and periodic summaries. Resume must preserve the original limits.

Acceptance: deterministic stop at every limit, pause on ambiguity, and a final report containing
build, test, and change evidence.

### E6 — Incremental legacy modernization

Deliver inventory, risk, reversible-batch, and validation journeys for BDE, ADO, and dbExpress to
FireDAC, followed by DEXT and form decomposition extensions.

Acceptance: no automatic full rewrite; every batch compiles or rolls back and retains compatibility
and manual-action reports.

### E7 — Delphi mentor

Deliver explanations adapted to user level for language, ownership, VCL/FMX, DFM, projects, and
packages, anchored to selected code and applicable curated rules.

Acceptance: beginner, cross-language, and experienced profiles; project content is never retained
as learning material without consent.

### E8 — Corporate security brief

Document data flow by route: remote provider, compatible endpoint, CLI, MCP, and local execution.
Cover storage, retention, deletion, credentials, auditing, telemetry, and guarantees that depend on
the selected vendor.

Acceptance: pt-BR/en-US versions, valid central links, and documentation tests.

### E9 — Reproducible Delphi benchmark

Publish versioned scenarios for DFM/PAS consistency, Designer, memory, migration, DUnitX, builds,
IDE64, resume, and confinement. Measure success, duration, interventions, rollback, and cost when
available without turning local results into telemetry.

Acceptance: deterministic runner, versioned schema, secret-free fixtures, and comparable reports.

## Delivery order

| Wave | Deliveries | Main dependency |
| :--- | :--- | :--- |
| 1 | E1 and E2 | Existing workspace and knowledge |
| 2 | E3 and E4 | Profile, Designer, and transactions |
| 3 | E5 | Runtime, checkpoints, and evidence |
| 4 | E6 and E7 | Profile, rules, and DFM/PAS auditor |
| 5 | E8 and E9 | Stabilized contracts from prior waves |

## Program completion gate

- Runtime catalog and tool reference are synchronized.
- Central documentation, manual, guides, hints, and translations are updated.
- Documentation, web, and DUnitX tests pass.
- Builds pass on Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64.
- SonarQube is queried only through its REST API and the Quality Gate passes.
- No line exceeds 120 characters, no literal exceeds 255 characters, and no trailing whitespace remains.
