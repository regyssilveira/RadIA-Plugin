# Deterministic New Project Wizard

The RadIA New Project Wizard performs creation as a two-phase operation:

1. generate and review a deterministic manifest without modifying disk;
2. after approval, materialize in staging and publish the folder as a transaction.

## Templates

The current engine includes templates for:

- Console;
- VCL;
- FireMonkey;
- Library;
- Package;
- DUnitX;
- Windows Service.

Each request contains a valid Pascal name, Delphi version (`23.0` or `37.0`), and Windows
platforms (`Win32`, `Win64`, or both). Platform order, casing, and duplicates are normalized. The
same request always produces identical paths, content, hashes, template ID, and project GUID.

### Ready to debug after creation

Every generated project receives a `Debug` configuration with embedded symbols, debug DCUs,
stack frames, and optimization disabled. Source breakpoints therefore work immediately after
`Create & Open`, without manually editing the `.dproj`. The `Release` configuration remains
separate for optimized builds.

Generated `.dproj` files resolve the Delphi RTL and DCUs through
`$(BDS)\lib\$(Platform)\release`, because that variable is defined by the `rsvars.bat` loaded by
the IDE. DUnitX projects also include `$(BDS)\source\DUnitX` in the search path so validation works
on clean Delphi 12 and 13 installations.

## Preview

The JSON preview contains:

- schema version;
- canonical template ID;
- project name and type;
- Delphi version;
- platforms;
- path, UTF-8 size, and SHA-256 for every file.

The preview does not include file contents. `Tools > RadIA > RadIA New Project...` displays this
manifest before creation is enabled.

## Visual use without an open project

Enter the project name, template, Delphi version, and platforms; select an authorized root through
the native `Browse...` dialog; review the preview; then choose `Create & Open`. The root field is
read-only, so a path typed or suggested by an AI never grants access. Changing any option
invalidates the previous preview. If opening the committed project fails, RadIA rolls it back.

## Agent Runtime and MCP tools

The transactional flow is available through the protected registry shared by agent mode and MCP:

- `PreviewProjectTemplate` validates the request and returns the manifest and a `previewId` without writing;
- `CreateProjectFromTemplate` accepts only the `previewId`, requires structural-write consent, and publishes
  exactly the reviewed project;
- `RevertCreatedProject` accepts the same `previewId` and removes the project created by the transaction.
- `OpenCreatedProject` opens the committed `.dproj` on the IDE main thread.
- `ValidateCreatedProject` opens and builds the project; on failure, it closes modules and rolls back.

All calls pass through the policy executor, so they are audited, honor consent, and inherit execution limits.
Tool destinations must remain inside the active project root. Authorization without an open project
is a separate capability available only to the visual wizard after explicit folder selection.

## Filesystem transaction

After approval, files are written into a temporary sibling folder suffixed with
`.radia-stage-<GUID>`. The destination remains intact and empty during this phase.

Commit renames staging into the destination. If a later validation fails, rollback removes the
published project in full and restores an empty folder when it existed before. Destroying a
prepared transaction also removes staging.

Non-empty destinations, filesystem roots, existing files, and paths escaping staging are rejected.

## Integration status

The engine, preview, transaction, visual UI, option selection, and no-project authorized root
selection are implemented. Visual authorization does not broaden agent or MCP tool permissions.

Beyond unit tests, `scripts/Test-RadIA.GeneratedProjects.ps1` generates the templates through the
real engine and builds every `.dproj`. A VCL calculator uses the `essential` profile by default,
which generates and builds only the requested application. The `complete` profile, or `custom` with
the `dunitx` option, adds the companion project, exposes its executable in the preview, and enables
the five operation and division-by-zero tests through the RadIA runner. These extras are included
only after an explicit user request or choice. The current matrix covers Delphi 12 Win32 and Delphi
13 Win32/IDE64.

The calculator specification accepts `schemaVersion: 2` and the `features.operationHistory`
feature. When `enabled` is true, preview and creation preserve the operation list and its clear
action. The release matrix runs the application, records `2 + 3 = 5` in history, and confirms that
**Clear history** leaves the list empty on all three supported targets.
