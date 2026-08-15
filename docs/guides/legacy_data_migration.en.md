# Incremental legacy data access migration

RadIA inventories BDE, ADO, and dbExpress references in the active project, classifies risk, and maps
FireDAC equivalents. The journey operates by technology and file and never performs an automatic full rewrite.

## Recommended flow

1. Run `InventoryLegacyDataAccess` to read the active `.dproj`, units, and forms.
2. Review every finding's technology, risk, FireDAC equivalent, and manual action.
3. Run `PlanLegacyMigrationBatches`; each batch is bounded to one technology and one file.
4. Use `PrepareLegacyMigrationBatch` to create a reversible preview for an eligible batch.
5. Review the diff and apply its `previewId` with `ApplyMultiFilePatch`.
6. Run `BuildProject` and `RunDUnitXTests`.
7. Record both results with `RecordLegacyMigrationGate`.
8. Use `GetLegacyMigrationReport` to track compatibility and manual work.

When either build or tests fail, gate recording reverts the applied batch. Text evidence for both gates is
required. Connections, drivers, aliases, transactions, and parameters remain manual because their semantics
cannot be inferred safely from component classes alone.

## DEXT and form decomposition

`PlanDextAndFormModernization` produces a plan after FireDAC stabilization: extract data access interfaces,
prove behavioral parity, introduce the DEXT boundary, and only then decompose forms by data, action, and
navigation responsibilities. The tool does not mutate code or the Designer.

## Limits

- up to 500 files, 2 MiB per file, and 2,000 findings per inventory;
- one-file previews per batch, subject to the normal patch limits;
- the agent must apply and validate one batch before preparing the next;
- files outside the active project are not inventoried.
