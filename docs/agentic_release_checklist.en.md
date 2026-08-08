# Agentive release checklist

> **Historical checklist of the 1.x line.** Delphi 11 does not belong to the current 2.0 release.

The requirement-by-requirement assessment is in `agentic_completion_audit.md`.

## Technical scope

- [x] Internal registry shared between chat and MCP.
- [x] Workspace facade and OTA adapters isolated from the Core.
- [x] Central policy, consent, sanitization and audit pipeline.
- [x] Reversible patches with preview and review preconditions.
- [x] Build controlled, cancelable and without implicit execution.
- [x] Local named pipe with ACL, payload limit, cancellation, quota and metrics.
- [x] Independent MCP discovery per process.
- [x] Live Form Designer, debugger and inline review.
- [x] Incremental, persistent and rebuildable local knowledge.
- [x] Status and limited reading of index documents.
- [x] Versioned API for extensions and example external package.
- [x] ADRs record the boundaries of the internal registry and the OTA workspace.

## Automated compatibility

- [x] Delphi 11 Win32: package, bridge, extension and 590 tests.
- [x] Delphi 12 Win32: package, bridge, extension and 590 tests.
- [x] Delphi 13 Win32: package, bridge, extension and 590 tests.
- [x] Delphi 13 IDE64: package, bridge, extension and 590 tests.
- [x] Zero skipped tests, failures, errors or leaks.
- [x] Instrumented coverage: 78% in Delphi 12.
- [x] ESLint approved.
- [x] Line limit, trailing whitespace and `NOSONAR` checked.

## Distribution

- [x] Build Release reproducible by version and platform.
- [x] ZIP package includes BPL, DCP, bridge, web resources and WebView2Loader.
- [x] Manifest records version, Delphi, platform, configuration, size and SHA-256.
- [x] `SHA256SUMS.txt` is automatically updated with each package generated.
- [x] Installer validates manifest, version and architecture.
- [x] Installer refuses traversal, absolute paths, duplicates and undisclosed files.
- [x] The build itself runs `-ValidateOnly` before compressing the staging.
- [x] `-ValidateOnly` mode checks the package without changing the system.
- [x] Negative package tests cover corruption, version, platform, traversal, duplicity, and extra file.
- [x] Installer refuses execution while an IDE is open.
- [x] `build.ps1 -Install` also installs the MCP bridge.
- [x] Public version centralized and validated against `package.json` and `RadIA.rc`.
- [x] Migration preparatory notes published.
- [x] Generate the final four packages from the release commit.
- [x] Publish `SHA256SUMS.txt` with final packages.

## Remaining manual validations

- [x] Confirm actual editing, save, rename and closing by triggering the knowledge notifier.
- [x] Complete ten consecutive installation, use and shutdown cycles in Delphi 11.
- [x] Complete ten consecutive installation, use and shutdown cycles in Delphi 12.
- [x] Complete ten consecutive installation, use and shutdown cycles in Delphi 13 Win32.
- [x] Complete ten consecutive installation, use and shutdown cycles in Delphi 13 IDE64.
- [x] Load and unload `RadIASampleExtension` in a real IDE.
- [x] Validate two updated IDEs simultaneously and select each file `mcp.<pid>.json`.

## Publishing gate

The public version, tag, and release notes should only be created after all manual items
are approved and the packages are regenerated from the same commit. Do not reuse artifacts
produced before the final commit.
