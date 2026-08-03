# Agentic platform troubleshooting

## Tools and consent

| Symptom | Check and action |
|---|---|
| Tool is missing | Refresh the catalog and verify active project context and extensions. |
| Consent is not visible | Bring the IDE forward and check for another modal dialog. |
| Consent expired | Repeat the request and answer before the timeout. |
| Operation was denied | Review scope and risk; denial does not change the workspace. |
| Cancellation is delayed | Wait for a cooperative cancellation point during writes. |

## Editor and workspace

| Symptom | Check and action |
|---|---|
| Path rejected | Use a project file inside the authorized workspace. |
| Patch conflict | Create a new preview from current content; do not force an old hash. |
| File not found | Verify rename, active project, and the identity returned by OTA. |
| Build busy | Wait for or cancel the current build before starting another. |

## MCP

| Symptom | Check and action |
|---|---|
| Bridge exits | Verify the IDE and `%APPDATA%\RadIA\mcp.json`. |
| Wrong IDE | Pass the intended `mcp.<pid>.json`. |
| Named pipe missing | Verify the PID and restart the bridge. |
| Tool call pending | Check for a consent dialog in the IDE. |
| Protocol error | Send `initialize` before `tools/list` or `tools/call`. |

## Knowledge, Designer, and debugger

| Symptom | Check and action |
|---|---|
| Stale search | Save the file or rebuild the project index. |
| Designer unavailable | Open a supported form and activate its Designer. |
| Component changed | Create a new preview from current state. |
| Evaluation unavailable | Pause the process in a valid frame. |
| Control rejected | Inspect debugger state before the next command. |

## Local data

- Audit: `%APPDATA%\RadIA\audit\tools.jsonl`.
- Rebuildable knowledge: `%APPDATA%\RadIA\Knowledge`.
- MCP discovery: `%APPDATA%\RadIA\mcp.json` and `mcp.<pid>.json`.
- Web assets: `%APPDATA%\RadIA\Web`.
- Disposable WebView2 cache: `%APPDATA%\RadIA\WebView2`.

Close every IDE before removing local data. Preserve the audit file when compliance requires it,
and never edit discovery manually to point to another pipe.
