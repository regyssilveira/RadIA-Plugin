# RadIA Doctor

The `/doctor` command is the starting point when RadIA is installed but a capability does not work.
It runs a read-only local diagnostic, sends no credentials to a model, and changes no IDE, project,
or configuration state.

## What it evaluates

| Area | What the doctor confirms | When it needs attention |
|---|---|---|
| Effective route | Orchestration, provider transport, effective CLI, and MCP requirement | The visual selection does not match actual dependencies |
| Provider | Active provider and configured authentication method | API key, local URL, or authentication route is missing |
| CLI | Executable resolved through the same catalog used by chat | The effective route requires a CLI and it was not found |
| MCP | Bridge and client configuration | Only when an external executor depends on MCP |
| Terminal | ConPTY availability | Windows does not provide the interactive transport |
| Chat | Installed HTML, CSS, and JavaScript | Web assets are missing or installation is incomplete |
| Tools | Internal catalog and `GetIDEState` | The package did not register the first read-only tool |
| External MCP | Enabled servers, connections, tools, and errors | An enabled server cannot be used |

ChatGPT Pro via Codex CLI is a composed route: orchestration may remain **RadIA native**, while the
provider transport requires the Codex executable. That does not make MCP mandatory. The doctor
reports these three states separately.

## Reading the card

- **Score** summarizes applicable checks; an optional item is `not-required`.
- **Effective route** shows the path a message will actually follow.
- **Passed**, **failed**, and **not-required** distinguish optional capabilities from failures.
- **Next action** prepares a command or useful path; nothing runs automatically.
- Executable paths may be displayed for diagnostics, but tokens, keys, and sensitive arguments are
  never returned.

## Projects without Git

The Codex executor supplies the project directory explicitly and supports Delphi folders without a
Git repository in both new and resumed sessions. If an older version displays `Not inside a trusted
directory`, update RadIA and run `/cli new` before testing again.

## Current limits

The `full-local` profile verifies installation and configuration without making external calls. A
detected CLI may still require login, model access, or connectivity. Use **Settings > CLI & MCP >
Diagnose** for version and authentication-specific checks. Open-project, build, test, and local-index
problems belong to `/health`.

## Related commands

| Need | Command |
|---|---|
| Diagnose why something does not work | `/doctor` |
| Inventory everything currently configured | `/status` |
| Isolate one area | `/status provider`, `/status cli`, or `/status mcp` |
| Diagnose the open project | `/health` |
| Confirm this IDE catalog | `/tools` |

See also [Native and CLI executors](cli_executors.en.md), [Troubleshooting](troubleshooting_agentic_platform.en.md),
and [Settings](settings_reference.en.md).
