# RadIA backlog

This file contains open work only. History, completed milestones, metrics, and release notes do not
belong in the backlog.

## Current state

The active goal is the **FireDAC Advisor**. Work covers inventory, SQL, parameters, transactions,
configuration, drivers, thread safety, schemas, AI assistance, generation, reversible fixes,
migration, documentation, and validation on supported IDEs. The internal executable contract keeps
this cycle's security limits, test matrix, and definition of done.

The goal cannot close on a partial delivery. Completion requires every planned tool, unit, contract,
security, and integration tests, all 16 E2E scenarios, Delphi 12 and 13 builds, bilingual
documentation, and a requirement-by-requirement audit.

The available foundation covers inventory, selected and embedded SQL analysis, parameters,
transactions, configuration, thread safety, local SQLite schema comparison, and structured context
for AI explanations. Deterministic, write-free previews are also available for repositories, data
modules, queries, DTOs, and DUnitX fixtures, together with evidence-aware query optimization and
thread-safety plans. Applying and reverting those artifacts remain open. Reversible fixes now cover
proven parameter accessor mismatches and missing rollbacks with preview ownership and fingerprints.
Composite gates for isolated fixes remain open. Legacy migration now owns batch application and
FireDAC, build, and DUnitX gates with rollback. The E2E matrix contract now enumerates 16 scenarios
across Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64, producing 48 deterministic runs.
Fully connecting that plan to the real MCP/IDE runner and collecting runtime evidence remain open.
Seven read-only scenarios are connected and passing on all three targets, producing 21 real
executions: inventory, sanitized SQL analysis, credential redaction, missing transaction rollback,
cross-thread sharing, consented SQLite grid/CSV, and DML rejection with an unchanged database. The
other nine scenarios remain to be connected, and the smoke's controlled SQL input must be replaced
with a real editor selection.

A public extension repository or marketplace, C++Builder, Delphi 11, Lazarus, GetIt,
Embarcadero-exclusive integrations, and replacement of the current WebView remain out of scope.

## Definition of done for new items

Every new item must require:

- a documented contract and threat model before implementation;
- proven Delphi 12 and 13 support, with unavailable capabilities reported explicitly;
- unit, OTA integration, and end-to-end tests proportional to risk;
- an automated usage scenario in the regression matrix for every new behavior;
- preview, consent, fingerprint, and rollback for every mutation;
- simultaneous updates to manuals, references, hints, translations, and documentation tests;
- passing local build, DUnitX, applicable lint, and SonarQube;
- observable outcome evidence, not merely the existence of classes or tools.
