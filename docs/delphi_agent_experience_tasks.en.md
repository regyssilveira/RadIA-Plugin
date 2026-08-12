# Delphi agent experience tasks

This list executes the [Delphi agent experience program](delphi_agent_experience_plan.en.md).
Valid states are `pending`, `in_progress`, `blocked`, and `completed`. A task may only be completed
after its code, tests, documentation, and applicable gates pass.

## Foundation

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-001 | Define profile, rule, audit, diff, and evidence contracts | — | completed |
| DX-002 | Create shared Delphi fixtures and OTA mocks | DX-001 | completed |
| DX-003 | Update registration, runtime catalog, and catalog tests | DX-001 | completed |

## Intelligent environment profile

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-101 | Collect IDE version, architecture, SKU, and capabilities | DX-001 | completed |
| DX-102 | Detect project framework, platform, and configuration | DX-101 | completed |
| DX-103 | Inventory search paths, packages, and libraries with limits | DX-101 | completed |
| DX-104 | Register `GetDelphiEnvironmentProfile` with sanitized output | DX-102, DX-103 | completed |
| DX-105 | Validate the profile on all three supported targets | DX-104 | completed |

## Curated Delphi knowledge

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-201 | Define a versioned rule schema and precedence policy | DX-001 | completed |
| DX-202 | Create initial language, memory, thread, VCL, and FMX rules | DX-201 | completed |
| DX-203 | Create Delphi 12, Delphi 13, and IDE64-specific rules | DX-201 | completed |
| DX-204 | Query by version, framework, topic, and identifier | DX-202, DX-203 | completed |
| DX-205 | Add rule citations to agent context and results | DX-204 | completed |

## DFM/PAS auditor

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-301 | Create a bounded parser for components, fields, and events | DX-002 | completed |
| DX-302 | Detect missing, orphaned, or incompatible handlers | DX-301 | completed |
| DX-303 | Detect inconsistent components, fields, classes, and names | DX-301 | completed |
| DX-304 | Register read-only auditing with severity and location | DX-302, DX-303 | completed |
| DX-305 | Prepare fixes through existing patches and transactions | DX-304 | completed |
| DX-306 | Validate conflicts, rollback, and false-positive controls | DX-305 | completed |

## Designer Visual Diff

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-401 | Define local visual snapshots, retention, and sanitization | DX-001 | completed |
| DX-402 | Capture previous and proposed states on the IDE main thread | DX-401 | completed |
| DX-403 | Diff components, bounds, and properties structurally | DX-301, DX-402 | completed |
| DX-404 | Render before/after comparison in the timeline | DX-403 | completed |
| DX-405 | Integrate acceptance, rejection, conflicts, and cleanup | DX-404 | completed |

## Autonomous execution contract

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-501 | Add file, operation, and summary-period limits | DX-001 | completed |
| DX-502 | Define completion criteria and mandatory gates | DX-501 | completed |
| DX-503 | Persist the contract in checkpoints without widening permissions | DX-502 | completed |
| DX-504 | Pause on ambiguity and contract violations | DX-503 | completed |
| DX-505 | Report changes, builds, tests, and remaining work | DX-504 | completed |

## Incremental modernization

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-601 | Inventory BDE, ADO, and dbExpress in code, DFM, and project | DX-304 | completed |
| DX-602 | Classify risks and map FireDAC equivalents | DX-601, DX-204 | completed |
| DX-603 | Prepare reversible migration batches | DX-305, DX-602 | completed |
| DX-604 | Gate every batch through build and tests | DX-503, DX-603 | completed |
| DX-605 | Report compatibility and manual actions | DX-604 | completed |
| DX-606 | Extend the journey to DEXT and form decomposition | DX-605 | completed |

## Delphi mentor

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-701 | Define beginner, cross-language, and experienced profiles | DX-201 | completed |
| DX-702 | Create templates anchored to code and applicable rules | DX-205, DX-701 | completed |
| DX-703 | Explain ownership, VCL/FMX, DFM, and packages | DX-702 | completed |
| DX-704 | Integrate the mentor with editor and chat without implicit retention | DX-703 | completed |

## Corporate security

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-801 | Inventory data flows, storage, and retention by route | DX-104, DX-503 | completed |
| DX-802 | Document credentials, auditing, telemetry, and deletion | DX-801 | completed |
| DX-803 | Create a local/remote matrix and provider guarantee boundaries | DX-802 | completed |
| DX-804 | Publish the pt-BR/en-US brief and link it from hubs | DX-803 | completed |

## Reproducible benchmark

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-901 | Define scenario, execution, and result schemas | DX-001 | completed |
| DX-902 | Create DFM/PAS, Designer, memory, and migration fixtures | DX-002, DX-901 | completed |
| DX-903 | Add build, DUnitX, IDE64, resume, and confinement scenarios | DX-503, DX-901 | completed |
| DX-904 | Implement a deterministic runner without telemetry | DX-902, DX-903 | completed |
| DX-905 | Report success, time, cost, and rollback comparably | DX-904 | completed |

## Closure

| ID | Task | Dependencies | Status |
| :--- | :--- | :--- | :--- |
| DX-990 | Update UI, hints, translations, manual, and central references | DX-105–DX-905 | completed |
| DX-991 | Run documentation, web, and DUnitX tests | DX-990 | completed |
| DX-992 | Validate Delphi 12 Win32, Delphi 13 Win32, and IDE64 builds | DX-991 | completed |
| DX-993 | Query SonarQube through REST and fix root causes | DX-992 | completed |
| DX-994 | Audit lines, literals, whitespace, catalog, and evidence | DX-993 | completed |
