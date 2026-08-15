# Move Type refactoring contract

This contract defines when RadIA can move a Delphi type between units without silently changing its
meaning. `PrepareMoveType` prepares the operation and never writes files during analysis.

## Supported scope

- a top-level class, interface, record, or helper declared in an active-project unit;
- a unique identity proven by the semantic index;
- existing source and destination units owned by the active project;
- the complete type declaration and its method implementations in the same source file;
- proven `uses` updates in the source, destination, and consumers;
- multi-file preview, per-file fingerprint, central consent, compensation, and rollback.

The type name and identity remain unchanged. Rename and move are separate operations; when both are
needed, complete and validate one before preparing the other.

## Mandatory preconditions

1. Every involved buffer must be complete and match the indexed revision.
2. The declaration must have unambiguous structural boundaries.
3. Every moved implementation must belong to the same canonical type identity.
4. Declaration dependencies must be available in the destination `interface`.
5. Implementation-only dependencies must remain in the destination `implementation`.
6. Removing the type must not leave inaccessible source-unit private references.
7. Updating `uses` clauses must not create an interface cycle.
8. No confirmed reference may depend only on the source unit after the move.

Preparation fails without a partial change when any proof is missing or ambiguous.

## Blocked cases

- forms, frames, or data modules associated with a DFM;
- nested, anonymous, or conditional types whose extent cannot be proven;
- types tied to `{$R}`, `{$RESOURCE}`, or another artifact that must move with them;
- implementations spread across include files or files that cannot be read completely;
- access to private symbols from the source unit;
- helpers whose target type would not remain visible in the destination;
- a destination homonym or interface cycle;
- candidate references, duplicate identities, or stale indexes.

The result must explain the block, involved files, and required recovery action. Users never need to
inspect plugin source code to discover the cause.

## Transaction and consent

`PrepareMoveType` returns only a `previewId`, dependency summary, and file list. The user reviews the
diff and authorizes `ApplyMultiFilePatch`. Application revalidates every revision before the first
write and compensates already changed files on failure. `RevertMultiFilePatch` restores previous
content while the preview remains valid.

## Minimum evidence

- structural-boundary tests for classes, interfaces, records, and helpers;
- a multi-file source, destination, and consumer test;
- proven rejection of DFM, private dependency, cycle, and stale revision;
- application and rollback with exact equality to the original files;
- Delphi 12 and 13 builds and tests;
- an integration scenario registered in the indivisible release gate.
