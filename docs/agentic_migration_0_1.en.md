# Migration to the agentive platform

> **Historical document.** The compatibility described below corresponds to the 1.x line; Delphi 11 no
> integrates the current matrix of line 2.0.

> The agentive platform is promoted to the public version `1.0.0` after gate approval
> automated systems and real smokes from the Delphi matrix.

## Compatibility

The evolution maintains support for Delphi 11, Delphi 12 and Delphi 13. In Delphi 13 packages are produced
separate for IDE Win32 and IDE64. Do not load a Win32 BPL into `bin64\bds.exe`, nor a Win64 BPL
in the Win32 IDE.

Existing provider configurations remain valid. The upgrade does not remove API keys,
dynamic providers, chat sessions or visual preferences.

## New local data

RadIA now creates derived data in `%APPDATA%\RadIA`:

- `audit\tools.jsonl`: sanitized tool audit;
- `Knowledge`: rebuildable snapshots of the local index;
- `mcp.json`: Compatible discovery of the latest MCP instance;
- `mcp.<pid>.json`: specific discovery of each IDE process;
- `Web`: local copy of interface resources;
- `WebView2`: Runtime disposable cache.

The WebView2 index and cache can be removed and rebuilt. The audit file must not be
automatically deleted during upgrade.

## MCP

The `RadIA.MCP.Bridge.exe` bridge is now installed next to the BPL. Without arguments, she uses
`mcp.json`. To select a specific IDE, enter the full path to the respective IDE
`mcp.<pid>.json` as the first argument.

Customers must run `initialize` before `tools/list` or `tools/call`. Mutable operations and
execution continue to require consent in the IDE, even when originated by MCP.

Transport remains local via named pipe. No TCP ports are opened by default.

## Tools and consent

Reading tools can be used directly. Reversible writings, structural changes,
build, debugger and destructive operations follow the descriptor's risk rating.

Permissions granted for the session are not global: project, session, tool and scope do
part of the key. A destructive permission is not silently reused.

## Extensions

External packages must declare `RadIA` in `requires`, implement `IRadIAToolExtension`, and maintain the
token `IRadIAToolExtensionRegistration` to your `finalization`. Extensions compiled against another
incompatible architecture or API level are rejected.

See `tool_extension_guide.md` before migrating an internal integration based directly on
container or in the registry.

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
