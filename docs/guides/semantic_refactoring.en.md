# Safe semantic refactoring

RadIA finds and renames Delphi symbols by semantic-index identity instead of global text replacement.
This avoids changing comments, strings, inactive conditional code, or homonyms from other units.

## Find references

Ask chat to find a symbol's usages or run `FindSymbolReferences`. Supply the unit when homonyms exist.
The result includes file, line, and column and can be opened with `NavigateToFile`. Uncertain occurrences
are marked as candidates and are never treated as exact silently.

## Inspect a type hierarchy

Ask chat for the hierarchy of a class, interface, record, or helper, or run `GetTypeHierarchy`. The
tool returns the requested type, its ancestors, and its descendants with each relationship depth.
Types inherited from RTL, VCL, FMX, or libraries outside the project remain visible as external even
when they are not indexed.

When two units declare types with the same name, supply `unit`. RadIA stops instead of silently
choosing a homonym. This query is read-only and never changes files.

```text
/tool GetTypeHierarchy {"type":"TMainForm","unit":"Main"}
```

## Rename a symbol

1. `PrepareRenameSymbol` accepts `symbol`, `newName`, and `unit` when required.
2. RadIA rejects invalid names, reserved words, ambiguous symbols, and references that changed after
   indexing.
3. The tool prepares one preview for all confirmed units and DFMs. Closed UTF-8 files are read without
   requiring the user to open them manually.
4. Review the preview and approve `ApplyMultiFilePatch`. Application requires reversible-write consent
   and revalidates every file hash before changing anything.
5. If one write fails, earlier writes are compensated. Use `RevertMultiFilePatch` to undo an applied
   rename.

Binary DFMs are not edited directly on disk. Open the form in Delphi to expose an editable
representation or convert it to textual DFM before renaming. RadIA fails safely when complete textual
content is unavailable.

## Example

```text
/tool PrepareRenameSymbol {"symbol":"SaveButtonClick","newName":"HandleSaveClick","unit":"Main"}
```

The result contains the `previewId`, affected files, and confirmed replacement count. Preparation never
mutates the workspace.

### Rename a member across its hierarchy

When a method has an ancestor declaration and overrides, explicitly request a hierarchy-wide member
rename. RadIA relates indexed types only, compares signatures without confusing directives such as
`virtual` and `override`, and combines declarations, implementations, and exact usages in one preview.

```text
/tool PrepareRenameSymbol {"symbol":"Execute","newName":"Run","container":"TBaseWorker","unit":"Worker","includeHierarchy":true}
```

For overloads, also supply the exact `signature`. A homonymous type, ambiguous unqualified ancestor,
overload without a signature, candidate reference, or changed file stops preparation. The result includes
`hierarchySymbolCount`; application and rollback still use `ApplyMultiFilePatch` and
`RevertMultiFilePatch`.

## Change a routine signature

Use `PrepareChangeSignature` to add, remove, rename, reorder, or change parameters of a procedure,
function, constructor, or destructor. The tool uses the routine's canonical identity to join its
declaration and implementation and changes only calls proven by the semantic index.

Supply:

- `symbol`: the routine's simple name;
- `oldSignature`: its complete current signature;
- `newSignature`: the desired complete signature;
- `unit` and `container`: recommended filters for methods and homonyms;
- `mappings`: `oldName`/`newName` pairs that preserve parameter identity across renames and reorders;
- `bindings`: `parameterName`/`expression` pairs for every new required parameter.

```text
/tool PrepareChangeSignature {"symbol":"Execute","unit":"Worker","container":"TWorker","oldSignature":"procedure Execute(const AValue: Integer);","newSignature":"procedure Execute(const AInput: Integer; const ATrace: Boolean);","mappings":[{"oldName":"AValue","newName":"AInput"}],"bindings":[{"parameterName":"ATrace","expression":"False"}]}
```

The result is a multi-file preview only. Review and approve `ApplyMultiFilePatch`; use
`RevertMultiFilePatch` to undo it. RadIA blocks preparation on ambiguous references, calls without an
explicit argument list, removed arguments with possible side effects, incomplete files, reference
limits, or content changed since indexing. Disambiguate or adjust the reported call and retry; no
partial change is applied.

## Extract a method

Select a complete block inside a method implementation and ask RadIA to extract it, or run:

```text
/tool PrepareExtractMethod {"methodName":"CalculateTotal"}
```

RadIA automatically finds the routine containing the selection, locates its class declaration, and
infers input, `const`, `var`, and `out` parameters. Preparation replaces the block with a call, adds the
declaration beside the original method, and creates the implementation before it as one transactional
preview. Review and approve `ApplyMultiFilePatch`; use `RevertMultiFilePatch` to restore the exact
previous content.

The operation is blocked when the selection is ambiguous, crosses control flow, uses `Result`, contains
early exits, is outside a class method, depends on an implicit local type, or requests an existing name.
A blocked operation changes no file and reports the precondition that must be corrected.

## Move a type between units

Use `PrepareMoveType` to move a top-level class, interface, record, or helper to another unit that already
belongs to the project:

```text
/tool PrepareMoveType {"symbol":"TWorker","destinationFile":"D:\Project\Worker.pas"}
```

The tool resolves one semantic identity, moves the declaration and every method implementation owned by
the type, carries required `uses` dependencies, and updates only consumers confirmed by the index. The
result is a multi-file preview; preparation writes nothing. Review and approve `ApplyMultiFilePatch`, and
use `RevertMultiFilePatch` to restore every file exactly.

RadIA blocks types associated with DFM or resources, incomplete buffers, a homonymous destination, an
ambiguous local routine, a private source-implementation dependency, candidate references, and every
cycle found in the complete interface `uses` graph. Correct the reported precondition and prepare again.
