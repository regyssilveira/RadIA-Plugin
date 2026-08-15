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
