# FireDAC Advisor

FireDAC Advisor inspects the active Delphi project's data layer, produces navigable findings, and
prepares reviewable changes. Analysis is static by default: it does not open connections, execute
SQL, or return passwords, tokens, or connection strings.

## Before you start

1. Open the project in Delphi 12 or 13.
2. Use **Agent + RadIA native** so RadIA can compose IDE tools.
3. Confirm the active project and state the goal, for example: `audit this project's FireDAC usage
   and prioritize the risks`.
4. Review every consent request before a local query, application, or reversal.

Use `/tools` to confirm the installed catalog. Findings also reach the problems panel with file,
line, rule, severity, confidence, and sanitized evidence.

## Inventory and diagnostics

`InspectFireDACProject` locates components and relationships in PAS and DFM files. The consolidated
report can combine that inventory with:

- embedded or selected SQL, statements, placeholders, and parameters;
- transactions without safe commit or rollback handling;
- configuration, `DriverID`, drivers, and libraries;
- connections, datasets, transactions, or UI shared across threads;
- differences between FireDAC types and an authorized local SQLite schema.

`InspectFireDACUsage` remains available for older automation and uses the same inventory. SQL
analysis never executes or echoes the query. Without a real schema, explanations keep deterministic
facts, hypotheses, and limitations separate.

## SQL and local SQLite

To analyze a query, select its SQL in the editor and request `analyze the selected FireDAC SQL
without executing it`. To compare code and schema, provide a SQLite file inside the workspace.
Reading rows requires consent on every call and accepts only one bounded, sanitized read-only
statement; DML, multiple statements, BLOBs, and sensitive values are rejected.

See [Safe local database access](local_database.en.md).

## Generation and fixes

Advisor can prepare deterministic previews for a repository, data module, query, DTO, and DUnitX
fixture. Preparation does not write files. Creation occurs only after review, consent, and
fingerprint revalidation; reversal is rejected after a later change.

Automatic fixes are limited to proven findings and supported rules. The flow is:

1. validate the finding;
2. prepare the preview and open Smart Diff;
3. consent to application;
4. build and run DUnitX;
5. revert after a failed gate or on request, while preconditions remain valid.

Current deterministic fixes cover incompatible parameter accessors and missing rollback handling.
Optimization and thread-safety plans neither promise gains nor apply changes on their own.

## Legacy data-access migration

The migration flow inventories BDE, ADO, and dbExpress, plans batches, and prepares their FireDAC
replacement. Each applied batch requires consent and is accepted only after FireDAC, build, and
DUnitX gates. A failed gate reverts the batch and restores the legacy source.

See [Legacy data-access migration](legacy_data_migration.en.md).

## Guarantees and boundaries

- Paths remain confined to the active project.
- Credentials are removed from arguments, results, audit records, grids, and CSV output.
- A stale preview never overwrites a later edit.
- Static analysis does not replace execution plans, benchmarks, builds, tests, or human review.
- Real database access is restricted to the consented read-only local SQLite flow.
- Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 are in the supported matrix.

See every tool in the [operational reference](../reference/internal_tools_reference.en.md).
