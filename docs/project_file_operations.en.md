# Structural project operations

RadIA can create units, VCL forms, and FMX forms, and can unregister a file from the active project.
These operations use preview, consent, audit, and revert.

## Creating a unit or form

1. `PrepareAddProjectFile` accepts `unitName`, `kind` (`unit`, `vclForm`, or `fmxForm`), and
   `relativeDirectory`.
2. The result shows every path, content, and hash without writing to disk.
3. `ApplyProjectFileChange` accepts the `previewId`.
4. RadIA writes staging files, publishes all of them, and only then registers the `.pas` in the project.
5. `RevertProjectFileChange` unregisters the `.pas` and removes only files created by that transaction.

Files are not opened automatically, preventing focus changes during an agent run.

## Unregistering a project file

1. `PrepareRemoveProjectFile` accepts `fileName`.
2. `ApplyProjectFileChange` unregisters the file from the project.
3. The file remains on disk.
4. `RevertProjectFileChange` registers the same file again.

This flow does not expose generic physical deletion. Deleting a preexisting file requires an explicit
destructive operation and is never inferred from “remove from project”.

## Guarantees

- paths are confined to the active project root;
- existing files are never overwritten;
- physical creation happens before OTA registration;
- registration failure cleans every created file;
- logical removal precedes any possible disk cleanup;
- OTA execution is synchronized with the IDE main thread.
