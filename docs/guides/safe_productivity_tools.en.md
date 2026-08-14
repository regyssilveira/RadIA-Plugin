# Safe API documentation and mocks

RadIA generates `API.md` and mock units from the local semantic index. Generation always starts
with a read-only preview: no file is created and no unit is registered at that stage.

## Generate `API.md`

1. Confirm that the semantic engine indexed the active project.
2. Run `PrepareApiDocumentation`; `fileName` is optional and defaults to `API.md`.
3. Review the returned path, content, and SHA-256.
4. Run `ApplyGeneratedArtifact` with the `previewId` only after review and consent.
5. Use `RevertGeneratedArtifact` to remove the file while it remains unchanged.

The document includes indexed project symbols only. RTL, VCL, unit references, and private members
do not enter the inventory. File and offset ordering makes the output reproducible.

## Generate a mock unit

1. Select an indexed interface such as `IOrderService`.
2. Run `PrepareMockUnit` with `interfaceName` and a valid Pascal `unitName`.
3. Optionally provide `relativeDirectory`; it defaults to `Tests`.
4. Keep `registerInProject` as `false` to create the unit without changing the project, or choose
   `true` after confirming that it should participate in the build.
5. Review the content and apply the same preview with `ApplyGeneratedArtifact`.

The mock inherits from `TInterfacedObject`, implements resolved interface methods, and generates
bodies that raise `ENotImplemented`. This keeps intent explicit: users must complete the double's
behavior before using it in tests.

## Guarantees and recovery

- existing files are never overwritten;
- paths outside the project root are rejected;
- previews expire and cannot be applied twice;
- writes use staging and atomic publication;
- project registration is optional and happens only after file creation;
- registration failure removes the newly created file;
- reversal is blocked if the user changes the artifact after application.

These tools do not modify existing signatures, implementations, DFM files, or other units.
