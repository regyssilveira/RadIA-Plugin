# Release notes — RadIA 2.4.2

## Fixes

- Makes the chat composer responsive in narrow panes and keeps the send button accessible.
- Prevents executor, provider, and model selectors from exceeding the available width when the pane
  is resized or docked.
- Converts the raw Codex newer-version error into clear, actionable guidance.
- Explains that **RadIA native + ChatGPT Pro via Codex CLI** keeps orchestration in RadIA while still
  using Codex CLI as the Pro account transport.
- Directs the user to update the channel or choose a newer executable, run diagnostics, and refresh
  the model list.
- Makes `/doctor --deep` reject Codex versions incompatible with the `gpt-5.6-*` family instead of
  treating any `codex --version` response as sufficient.

## Compatibility

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64.

The visual installer is the only artifact required by end users. The update preserves existing
settings, credentials, MCP servers, and local data.

## Validation

- 1,032 Delphi tests passed on each target without failures, errors, or leaks;
- 91 web tests, 36 documentation tests, and ESLint passed;
- build passed on all three supported targets;
- runtime catalog validated with 132 tools;
- SonarQube Quality Gate `OK`, with no issues.
