# MCP integration guide

## Overview

RadIA exposes its agentic IDE catalog to local MCP clients. Communication between the bridge and
the IDE uses a Windows named pipe; no TCP port is opened by default.

## Requirements

- RadIA installed and loaded in a supported Delphi IDE.
- An open project when a tool requires workspace context.
- `RadIA.MCP.Bridge.exe` installed next to the BPL.
- A client that supports MCP over standard input and output.

## IDE discovery

Each process publishes `%APPDATA%\RadIA\mcp.<pid>.json`.
`%APPDATA%\RadIA\mcp.json` identifies the latest compatible instance.

With no argument, the bridge uses `mcp.json`:

```powershell
& "C:\path\RadIA.MCP.Bridge.exe"
```

To select a specific IDE, pass its discovery file:

```powershell
& "C:\path\RadIA.MCP.Bridge.exe" `
  "$env:APPDATA\RadIA\mcp.12345.json"
```

When multiple IDEs are running, match the PID in the file name to the intended `bds.exe` process.

## MCP session

The client must send `initialize` before `tools/list` or `tools/call`. The bridge transports MCP
messages over stdio and forwards them to the discovered named pipe.

Recommended sequence:

1. start the bridge;
2. send `initialize`;
3. call `tools/list`;
4. invoke a tool with `tools/call`;
5. handle results, errors, and cancellation;
6. stop the bridge when the session ends.

The list returned by `tools/list` is authoritative for that IDE instance. Local extensions may
change the catalog, so clients should not keep copied schemas indefinitely.

## Consent and security

External calls use the same policies as chat. A mutating tool may open a native consent dialog in
the IDE, and MCP use does not grant implicit authorization.

The transport is local, uses user ACLs, enforces payload and concurrency limits, and applies the
workspace boundary to MCP paths. Clients must handle structured errors, timeouts, and cancellation.

See the [security model](tool_security_model.md) and [tool catalog](tool_catalog.md).

## Troubleshooting

- **Bridge exits immediately:** verify that the IDE is running and discovery exists.
- **Wrong IDE:** pass the intended `mcp.<pid>.json` explicitly.
- **Tool unavailable:** refresh `tools/list` and verify its required IDE context.
- **Pending call:** check for a consent dialog in the IDE.
- **Pipe not found:** verify that the PID still exists and restart the bridge.
