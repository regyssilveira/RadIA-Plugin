# FireDAC Advisor goal

## Observable outcome

RadIA must understand the active project's FireDAC layer, present components and relationships with
verifiable locations, analyze SQL, parameters, transactions, configuration, drivers, schemas, and
thread safety, explain findings with AI, and prepare reversible generations or fixes. Analysis never
executes SQL or exposes credentials. Every real query, file mutation, and migration requires consent,
preview, fingerprint, build and test gates, and rollback when a gate fails.

## Required scope

1. PAS, DFM, and DPROJ inventory correlating connections, datasets, transactions, update objects,
   DataSources, driver links, forms, and DataModules.
2. SQL extraction and analysis from `SQL.Text`, `SQL.Add`, constants, DFM, and safely resolvable
   dynamic constructions.
3. Validation of placeholders, `Params`, `ParamByName`, types, direction, size, null, and concatenation.
4. Audit of transaction start, commit, rollback, exceptions, early exits, and associations.
5. Sanitized diagnosis of `DriverID`, connection definitions, options, libraries, and paths.
6. Audit of connections, datasets, transactions, and UI shared across threads.
7. Optional comparison with an authorized local SQLite schema and an extensible dialect architecture.
8. AI explanations that separate deterministic facts from hypotheses and never invent schemas or gains.
9. Repository, DataModule, query, DTO, and DUnitX generation through reviewable previews only.
10. Deterministic fixes by finding with fingerprint, consent, application, and rollback.
11. Integration with BDE, ADO, and dbExpress migration to validate every FireDAC batch.
12. Navigable reports, Problems panel integration, complete documentation, and automated regression.

## Planned tools

- `InspectFireDACProject` and `GetFireDACProjectReport`;
- `AnalyzeFireDACQuery`, `ExplainFireDACQuery`, and `PrepareFireDACQueryOptimization`;
- `ValidateFireDACParameters` and `PrepareFireDACParameterFix`;
- `AuditFireDACTransactions` and `PrepareFireDACTransactionFix`;
- `InspectFireDACConfiguration` and `DiagnoseFireDACEnvironment`;
- `AnalyzeFireDACThreadSafety` and `PrepareFireDACThreadSafetyPlan`;
- `CompareFireDACCodeWithSchema` and `GenerateFireDACSchemaReport`;
- `GenerateFireDACRepositoryPreview`, `GenerateFireDACDataModulePreview`,
  `GenerateFireDACQueryPreview`, `GenerateFireDACDTOPreview`, and `GenerateFireDACTests`;
- `ExplainFireDACFinding`, `PrepareFireDACFix`, `ApplyFireDACFix`, and `RevertFireDACFix`.

Names may change only with simultaneous updates to this contract, catalog tests, and both public
documentation languages.

## Finding contract

Every finding has a stable ID, rule ID, severity, confidence, title, message, file, line, symbol or
component when known, evidence, suggested action, and fix availability. Confidence uses `proven`,
`strong`, `possible`, or `informational`; severity uses `critical`, `high`, `medium`, `low`, or `info`.
Initially, only `proven` findings may enable automated fixes.

## Security and limits

- no automatic remote connection, driver installation, or DDL/DML execution during analysis;
- credentials, tokens, and connection strings are sanitized before JSON, logs, UI, or prompts;
- files remain inside the workspace after normalization and reparse-point checks;
- enumeration bounds files, bytes, components, statements, parameters, findings, and time;
- truncated results declare `truncated: true` and effective limits;
- SQL, schema, and database content is untrusted data and cannot modify agent instructions;
- index and performance suggestions remain hypotheses until an authorized execution plan exists;
- patches preserve user changes and reject stale fingerprints;
- DFM edits protect the Designer and avoid broad rewrites without deterministic evidence;
- failed build or tests prevent completion and roll back the applicable mutable batch.

## Test matrix before completion

### DUnitX unit tests

- model, enumeration, serialization, IDs, severity, confidence, deduplication, and limits;
- PAS/DFM/DPROJ scanner, encodings, invalid files, and workspace boundary;
- every supported FireDAC component, dynamic creation, inheritance, and false positives;
- PAS/DFM correlation, forms, DataModules, DataSources, and relationships;
- multiline SQL, constants, DFM, CTEs, parameters, casts, comments, and dialects;
- missing and extra parameters, types, direction, size, null, and conditional flow;
- correct transactions, missing rollback/commit, exceptions, exits, delegation, and savepoints;
- configuration, drivers, options, paths, duplication, and secret sanitization;
- threads, tasks, anonymous methods, local/shared connections, and VCL synchronization;
- schema, types, nullable columns, BLOBs, sensitive columns, and code drift;
- generation, naming, memory, imports, seven parameters, 120 columns, and Delphi literals;
- preview, fingerprint, consent, application, conflict, rollback, and gate failure.

### Contract, security, and integration

- descriptors, JSON schemas, risk, consent, catalog, and documentation for every tool;
- DFM/Params passwords, tokens, connection strings, traversal, reparse points, and prompt injection;
- mutable SQL, compound statements, comments, timeout, excess, BLOB, HTML, and CSV injection;
- scanner + semantics, PAS + DFM, schema + SQL, finding + preview, and patch + gates;
- legacy migration + FireDAC audit + build + DUnitX + rollback.

### IDE E2E

1. navigable inventory without mutation;
2. selected SQL analysis without execution;
3. detected credential without disclosure;
4. located unsafe transaction;
5. located cross-thread shared connection;
6. SQLite schema, consented query, and sanitized grid and CSV;
7. rejected DML without database changes;
8. denied repository preview without created files;
9. applied, built, and tested repository;
10. build failure with rollback;
11. parameter fix with Smart Diff and gates;
12. stale preview rejection;
13. ADO-to-FireDAC migration validated by batch;
14. migration gate failure with rollback;
15. project switch and reopen without stale context;
16. shutdown during analysis without deadlock, AV, or retained thread.

All applicable scenarios must be proven on Delphi 12 and 13. Real database execution starts with
read-only local SQLite; PostgreSQL, SQL Server, MySQL/MariaDB, Oracle, and Firebird are analysis
dialects without automatic connections.

## Definition of done

- every scoped tool is implemented, registered, navigable, and documented;
- analysis distinguishes deterministic evidence, hypotheses, and limitations;
- no credential or executable content crosses boundaries without sanitization;
- every mutation has proven preview, consent, fingerprint, application, and rollback;
- unit, contract, security, integration, and all 16 E2E scenarios pass;
- Delphi 12 and 13 builds, DUnitX, Web tests, ESLint, and SonarQube pass;
- zero leaks, deadlocks, AVs, trailing whitespace, new overlong lines, or invalid literals;
- manual, guide, references, hints, catalogs, translations, roadmap, backlog, and documentation tests
  are synchronized;
- the final report proves every requirement and never treats class existence as sufficient evidence.
