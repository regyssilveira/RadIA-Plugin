# Migration to the agentive platform

> **Historical document.** The compatibility described below applies to the 1.x line. Delphi 11 is
> not part of the current 2.x matrix.

> The agentic platform was promoted to public version `1.0.0` after automated gates and real IDE
> smoke tests passed across the Delphi matrix available at that time.

## Compatibility

The 1.x line supported Delphi 11, Delphi 12, and Delphi 13. Delphi 13 packages were produced
separately for the Win32 IDE and IDE64. Do not load a Win32 BPL into `bin64\bds.exe` or a Win64 BPL
into the Win32 IDE.

Existing provider configurations remain valid. The upgrade does not remove API keys,
dynamic providers, chat sessions, or visual preferences.

## New local data

RadIA now creates derived data in `%APPDATA%\RadIA`:

- `audit\tools.jsonl`: sanitized tool audit;
- `Knowledge`: rebuildable snapshots of the local index;
- `mcp.json`: compatibility discovery for the latest MCP instance;
- `mcp.<pid>.json`: specific discovery of each IDE process;
- `Web`: local copy of interface resources;
- `WebView2`: disposable runtime cache.

The knowledge index and WebView2 cache can be removed and rebuilt. The audit file must not be
deleted automatically during an upgrade.

## MCP

The `RadIA.MCP.Bridge.exe` bridge is installed next to the BPL. Without arguments, it uses
`mcp.json`. To select a specific IDE, provide the full path to the corresponding
`mcp.<pid>.json` as the first argument.

Clients must run `initialize` before `tools/list` or `tools/call`. Mutable operations and
execution continue to require consent in the IDE, even when originated by MCP.

Transport remains local via named pipe. No TCP ports are opened by default.

## Tools and consent

Read-only tools can be used directly. Reversible writes, structural changes,
builds, debugger controls, and destructive operations follow the descriptor's risk rating.

Permissions granted for a session are not global: project, session, tool, and scope are
part of the consent key. A destructive permission is never reused silently.

## Extensions

External packages must declare `RadIA` in `requires`, implement `IRadIAToolExtension`, and maintain the
`IRadIAToolExtensionRegistration` token until `finalization`. Extensions compiled for an
incompatible architecture or API level are rejected.

See `tool_extension_guide.en.md` before migrating an internal integration that accesses the
container or registry directly.

## Installation

1. Save your work and close all Delphi instances.
2. Choose the ZIP corresponding to the IDE version and architecture.
3. Extract all content.
4. Run `Scripts\Install-RadIA.Package.ps1` with the correct version.
5. Open the IDE and confirm the RadIA panel.
6. For MCP, run the bridge installed next to the BPL.

The installer validates the SHA-256 manifest before copying files and rejects packages from another version or
architecture.

## Rollback

To go back to the previous version:

1. Close all IDEs.
2. Reinstall the BPL, DCP, bridge, and web resources from the previous package.
3. Preserve configurations and auditing.
4. Remove `Knowledge` only if the previous version does not recognize the snapshot format.
5. Reopen the IDE and confirm that there are no `mcp.<pid>.json` files left from terminated processes.
