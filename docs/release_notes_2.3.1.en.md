# Release notes — RadIA 2.3.1

Release date: August 8, 2026.

## Highlights

- Separate **Mode** and **Send with** selectors for Chat/Agent and RadIA native/direct CLI choices.
- Effective identity in the header, composer, and responses, with distinct native, CLI, and MCP avatars.
- Restored **ChatGPT Pro via Codex CLI**, using the ChatGPT/Codex session and quota without sending a
  legacy token to `api.openai.com`.
- **OpenAI API via API Key** remains a distinct HTTP route with API Platform billing and quota.
- Automatic migration from legacy OpenAI OAuth settings to `oauth_cli`, removing unused HTTP tokens.
- Copy buttons on responses, JSON, tool results, and every other copyable text surface.
- Resizable settings and consistent contrast in route selection.
- Diagnosable Codex CLI login, independent from native API-key provider credentials.

## Choosing a route

- Choose **RadIA native + ChatGPT Pro via Codex CLI** to keep history, context, RTK, and orchestration
  in RadIA while using the CLI only as authenticated provider transport.
- Choose **Codex CLI direct** to delegate the complete execution to Codex.
- Choose **OpenAI API via API Key** to use the API Platform and its separate quota.

Both Codex routes share the same login. Under **Settings > CLI & MCP > Codex CLI**, run **Diagnose**
and verify `authentication: ready`.

## Regression fix

Version 1.0 routed ChatGPT login through Codex CLI. A later split interpreted the `oauth` state as
native HTTP transport, causing 401/429 responses even when the Pro account had remaining quota.
Version 2.3.1 restores the correct transport, prevents silent API fallback, and exposes the route.

## Validation

- Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 built and installed.
- 888 instrumented DUnitX tests passed with zero leaks.
- 6 external-process tests passed.
- 50 web tests and ESLint passed.
- 78% instrumented coverage.
- SonarQube passed with 83.1% new-code coverage, 0.94% new duplication, and zero issues.

See the [user manual](user_manual.en.md), [executor matrix](cli_executors.en.md),
[settings reference](settings_reference.en.md), and [troubleshooting](troubleshooting_agentic_platform.en.md).
