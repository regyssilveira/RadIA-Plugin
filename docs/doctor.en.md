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

## Consented deep diagnostic

Use `/doctor --deep` when the local diagnostic is correct but execution still fails. RadIA displays
execution consent before starting. When approved, the `deep-active` profile:

- runs `--version` against the effective selected CLI;
- uses the non-interactive authentication status command when the CLI provides one;
- opens a temporary handshake with every enabled external MCP server;
- closes test sessions and shows each result in the same doctor card.

The diagnostic does not install, authenticate, repair, or change configuration. It also does not
send a billable model message merely to test a provider. CLIs without a non-interactive auth check
are reported as `not-supported` with the correct manual action. Results are sanitized: tokens, keys,
server arguments, and raw authentication command output are never included.

## Related commands

| Need | Command |
|---|---|
| Diagnose why something does not work | `/doctor` |
| Validate CLI and MCP through real execution | `/doctor --deep` |
| Inventory everything currently configured | `/status` |
| Isolate one area | `/status provider`, `/status cli`, or `/status mcp` |
| Diagnose the open project | `/health` |
| Confirm this IDE catalog | `/tools` |

See also [Native and CLI executors](cli_executors.en.md), [Troubleshooting](troubleshooting_agentic_platform.en.md),
and [Settings](settings_reference.en.md).
