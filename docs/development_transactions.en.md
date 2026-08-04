# Composite development transactions

A complete change usually spans more than one IDE surface: code, project structure, and Form Designer.
RadIA can group already reviewed previews into one compensating transaction.

## Supported operations

`PrepareDevelopmentTransaction` accepts an ordered list containing `kind` and `previewId`. Supported
kinds are:

- `multiFilePatch`;
- `projectFile`;
- `designerComponent`;
- `designerLayout`;
- `designerProperty`;
- `designerEvent`.

Each `previewId` must have been produced by its specific tool. The higher-level transaction does not
replace detailed previews; it preserves the reviewed decision from every domain.

## Apply

`ApplyDevelopmentTransaction` executes operations in the supplied order. If one step fails, every
earlier step is reverted in reverse order. The result becomes `applied` only when the full list succeeds.

## Revert

`RevertDevelopmentTransaction` undoes operations from last to first. If one revert fails, operations
already reverted are applied again, avoiding a partially reverted state.

## Safety

- at most 32 operations and 16 active composite previews;
- duplicate IDs within the same domain are rejected;
- local preview expiration;
- structural-write consent before apply;
- audit coverage for each specific tool and the higher-level transaction;
- explicit `compensation_failed` when the IDE prevents full state recovery.
