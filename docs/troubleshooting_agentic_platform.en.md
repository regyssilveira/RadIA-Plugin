# Agentic platform troubleshooting

## Start with the right command

- Run `/doctor` when something does not work: it checks readiness and identifies the next action.
- Run `/status` to inspect configuration and availability without revealing credentials.
- Use `/status cli` or `/status mcp` to isolate those integrations.
- Use `/health` when the issue concerns the open Delphi project, build, tests, or local knowledge.
- Use `/tools` to verify whether a tool exists in the current IDE instance.

The [command reference](slash_commands.en.md#which-diagnostic-command-to-use) explains each choice.
The [RadIA Doctor guide](doctor.en.md) explains the effective route and every check.

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

## Provider and execution route

| Symptom | Check and action |
|---|---|
| ChatGPT Pro returns 401 or 429 | Select **ChatGPT Pro via Codex CLI**, open **Configure Codex CLI login**, and run **Diagnose**. An API key does not consume the Pro quota. |
| Codex reports that no response was generated | Refresh the model list and select a current model. RadIA treats this output as a transport error, preserves the cause, and recommends `/doctor --deep` instead of forwarding it to the agent as a JSON decision. |
| Login completed but chat does not recognize it | Close and reopen settings, then verify `authentication: ready`; RadIA reloads the session before sending. |
| Active route is unclear | Check **Send with** and the response header: **RadIA native** keeps internal orchestration; **CLI direct** delegates to the client. |
| Codex reports an untrusted directory | Update RadIA. The executor supplies the directory explicitly and supports non-Git Delphi projects in new and resumed sessions. Run `/doctor` to confirm the route and executable. |
| OpenAI API is required | Select **API Key (BYOK)** and configure a key with API Platform quota, separate from ChatGPT Pro. |

## Knowledge, Designer, and debugger

| Symptom | Check and action |
|---|---|
| Stale search | Save the file or rebuild the project index. |
| Designer unavailable | Open a supported form and activate its Designer. |
| Component changed | Create a new preview from current state. |
| Evaluation unavailable | Pause the process in a valid frame. |
| Control rejected | Inspect debugger state before the next command. |
| `Debug process not initialized` when pressing F9 | Update RadIA and restart the IDE. The timeline observer ignores transient OTA states and must never block manual debugging. If it persists, temporarily disable the package and preserve `%APPDATA%\RadIA\Logs` for diagnosis. |

## Local data

- Audit: `%APPDATA%\RadIA\audit\tools.jsonl`.
- Rebuildable knowledge: `%APPDATA%\RadIA\Knowledge`.
- MCP discovery: `%APPDATA%\RadIA\mcp.json` and `mcp.<pid>.json`.
- Web assets: `%APPDATA%\RadIA\Web`.
- Disposable WebView2 cache: `%APPDATA%\RadIA\WebView2`.

Close every IDE before removing local data. Preserve the audit file when compliance requires it,
and never edit discovery manually to point to another pipe.
