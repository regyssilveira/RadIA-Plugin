# MCP integration guide

## Overview

RadIA exposes its agentic IDE catalog to local MCP clients. Communication between the bridge and
the IDE uses a Windows named pipe; no TCP port is opened by default.

RadIA also supports the inverse flow: it can act as a client of external MCP servers. The two roles
are independent:

- **RadIA as a server:** exposes IDE tools through the bridge documented in this guide;
- **RadIA as a client:** discovers tools, resources, and prompts from local servers and publishes
  only explicitly granted tools into RadIA's shared registry.

The client runtime loads with the IDE and can replace its snapshot without restarting Delphi. A
configuration, connection, or discovery failure preserves the internal catalog and the last valid
runtime. `/status mcp` returns only sanitized counts for servers, grants, tools, resources, prompts,
and errors; `/doctor` adds a separate check when the external runtime is available. Commands,
arguments, working directories, and granted paths never appear in these diagnostics.

Manage servers under **Settings > CLI & MCP > External MCP Servers**. Do not edit
`external-mcp.settings`: it is a current-user DPAPI envelope and has no supported manual editing
format.

### Consume an external server in RadIA

1. Open **External MCP Servers** and enter ID, name, command, arguments, directory, and timeout; or
   use **Import...** to load `mcpServers`/`servers` JSON into the local preview. Imported servers
   arrive disabled unless the file declares `"enabled": true`; enable each one deliberately before
   applying.
2. Use **Add / Update** and inspect the list. No process or file changes at this point.
3. Click **Test** to connect and discover tools, resources, and prompts without publishing a tool.
4. Select a discovered tool and create its local grant with risk, consent, and path arguments.
   Without a grant, the tool remains unavailable to the agent.
5. Click **Apply**, review the counts, and confirm. DPAPI protects the snapshot and the runtime
   refreshes in the background without restarting Delphi.
6. Check `/status mcp`; on failure, run `/doctor` and use **Refresh** after correcting the cause.

Removing a server also removes its grants from the preview. If **Apply**, **Refresh**, or discovery
fails, the previous runtime remains active. Sanitized diagnostics never include commands, arguments,
or paths.

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

## Client configuration

Clients that accept command-based MCP servers can use an equivalent configuration:

```json
{
  "mcpServers": {
    "radia-delphi": {
      "command": "C:\\path\\RadIA.MCP.Bridge.exe",
      "args": [
        "C:\\Users\\user\\AppData\\Roaming\\RadIA\\mcp.12345.json"
      ]
    }
  }
}
```

Remove `args` to use `mcp.json`. The root field name varies by client; preserve the command and
discovery argument.

Typical installed paths are:

```text
C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl\RadIA.MCP.Bridge.exe
C:\Users\Public\Documents\Embarcadero\Studio\37.0\Bpl\Win64\RadIA.MCP.Bridge.exe
```

Use the bridge matching the loaded package architecture.

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

### Implemented methods

- `initialize`
- `notifications/initialized`
- `ping`
- `tools/list`
- `tools/call`

Version 1.0 negotiates protocol `2025-06-18`.

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2025-06-18",
    "capabilities": {},
    "clientInfo": {
      "name": "my-client",
      "version": "1.0"
    }
  }
}
```

After the response, the client may send `notifications/initialized` and call `tools/list`.

```json
{
  "jsonrpc": "2.0",
  "id": 2,
  "method": "tools/call",
  "params": {
    "name": "GetActiveProject",
    "arguments": {}
  }
}
```

These raw messages are for diagnostics and integration development. Use the client's native MCP
implementation when available.

## Exposed capabilities

MCP publishes the same registry as chat, including available tools for:

- IDE, project, units, files, and editor;
- reviewable patches;
- build and compiler messages;
- Form Designer;
- debugger, breakpoints, and watches;
- inline reviews;
- local knowledge;
- extensions loaded by the IDE.

Call `tools/list` for every connection. The technical catalog describes the architecture, but the
runtime response is authoritative.

## Consent and security

External calls use the same policies as chat. A mutating tool may open a native consent dialog in
the IDE, and MCP use does not grant implicit authorization.

The transport is local, uses user ACLs, enforces payload and concurrency limits, and applies the
workspace boundary to MCP paths. Clients must handle structured errors, timeouts, and cancellation.

See the [security model](../reference/tool_security_model.en.md) and [tool catalog](../development/tool_catalog.en.md).

## Multiple IDE instances

Each `mcp.<pid>.json` represents one process. Match the PID and open project, configure one bridge
per discovery file, and give each client entry a distinct name. `mcp.json` is convenient for a
single IDE but may change when another process starts.

For reproducible automation, prefer `mcp.<pid>.json`.

## Operational verification

1. Open Delphi and a project.
2. Confirm that `mcp.<pid>.json` exists.
3. Start or reload the MCP server in the client.
4. Verify that `initialize` reports RadIA `2.17.2`.
5. Call `tools/list`.
6. Call `GetIDEState` and `GetActiveProject`.
7. Test mutable consent only in a disposable project.
8. Close the IDE and confirm that discovery and connection are removed.

## Troubleshooting

- **Bridge exits immediately:** verify that the IDE is running and discovery exists.
- **Wrong IDE:** pass the intended `mcp.<pid>.json` explicitly.
- **Tool unavailable:** refresh `tools/list` and verify its required IDE context.
- **Pending call:** check for a consent dialog in the IDE.
- The dialog is shared with chat, agent, and terminal, identifies **MCP client** as the source, and
  remains accessible when the chat panel is closed. Concurrent calls wait for the single slot only
  until the configured timeout.
- **Pipe not found:** verify that the PID still exists and restart the bridge.
- **Invalid schema:** discard the cached catalog and call `tools/list` again.
- **Wrong project:** select the discovery file for the intended PID.

See also the [Complete RadIA User Manual](user_manual.en.md).

## Safe CLI client provisioning

RadIA includes a provisioning engine for Codex CLI, Claude Code, Gemini CLI, and GitHub Copilot
CLI. Its visual integration is available on the settings screen, while the core contract
enforces this workflow:

1. detect missing, configured, drifted, or invalid configuration;
2. produce a preview without writing a file;
3. confirm that `RadIA.MCP.Bridge.exe` exists;
4. preserve MCP servers and preferences that are not owned by RadIA;
5. create `<configuration>.radia.bak` before every mutation;
6. add or repair only the `radia` entry;
7. read back and validate the written configuration;
8. restore the backup automatically when verification fails;
9. remove only the managed entry when the user disconnects a client.

JSON files are merged as objects and retain unrelated properties. In the Codex `config.toml`, RadIA
owns only the block delimited by `BEGIN/END RadIA managed MCP server`; content outside that block
remains intact. Invalid configurations are never overwritten.

The stable backup represents the state immediately before the latest mutation. Before provisioning
or removal through the UI, RadIA must always present the preview and request explicit consent.

### Using the settings screen

Open **RadIA > Settings > CLI & MCP** and follow this workflow:

1. select Codex, Claude, Gemini, or GitHub Copilot;
2. optionally enter a CLI executable that is not available through `PATH`;
3. review the suggested client configuration and bridge paths;
4. click **Diagnose** to check CLI detection and MCP state;
5. click **Preview** to review the exact proposed content;
6. use **Connect / Repair** and confirm the displayed configuration and backup;
7. use **Disconnect** to remove only the entry managed by RadIA.

The three paths are persisted independently for each client and restored when the screen is reopened.
An empty executable field keeps automatic `PATH` detection enabled.

The connection button remains disabled when the bridge is missing, the configuration is invalid,
or the client is already configured correctly. This screen never installs CLIs or changes client
configuration without visual confirmation.
## Runtime diagnostics over MCP

An MCP client can drive the same cycle available in Agent Mode:

1. `BuildProject` and `StartDebugging`;
2. `GetRuntimeDebugSession`, `GetRuntimeWindows`, and `GetRuntimeControlTree`;
3. `PrepareRuntimeScenario` and, after IDE consent, `RunRuntimeScenario`;
4. `CaptureRuntimeEvidence` with `phase=failure`;
5. reviewed fix application, a new build, and a new session;
6. scenario replay, `phase=verification`, and `CompareRuntimeEvidence`;
7. `PrepareRuntimeRegression`, `SaveRuntimeRegression`, and later
   `PrepareSavedRuntimeScenario`.

MCP never grants implicit authorization. Build, debugger, visual execution, and write operations
continue to show IDE consent. See
[Autonomous Runtime Diagnostics](runtime_debug_automation.en.md).

## Opt-in smoke with a real external server

Maintainers can reproduce the matrix with the official filesystem server pinned to `2026.7.10`.
The workflow requires Node.js with `npx`, downloads only into the `npx` cache, uses no credentials,
and creates a distinct temporary workspace for every execution.

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ExternalMcpRealServer.ps1 `
  -Consent `
  -EvidencePath Output\Validation\ExternalMcp\real-server.json
```

Without `-Consent`, the script exits before any download or execution. It requires the test binaries
for all three targets to be built, runs only the opt-in category, verifies temporary-artifact cleanup,
and generates evidence without local paths or file contents.
