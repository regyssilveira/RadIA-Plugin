# Release notes — RadIA 2.5.0

## Chat experience

- Organizes composer controls into two semantic rows: execution and conversation context.
- Reflows selectors, actions, and effective status according to the docked panel width.
- Preserves existing commands, shortcuts, and identifiers without changing the chat workflow.

## CLI installation

- Keeps npm as the preferred channel when it is already available.
- Uses official WinGet packages for Codex CLI and Claude Code when npm is unavailable.
- Keeps GitHub Copilot CLI on WinGet and displays the command before any execution.
- Explains that Gemini CLI still requires Node.js on Windows through its official channel.
- Preserves **Browse** for existing executables, per-step consent, and automatic post-install checks.

CLIs are not bundled into the RadIA installer. The manager uses official channels to reduce
obsolescence, installer size, and third-party software redistribution risks.

## Compatibility

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64.

The visual installer remains the only artifact required by end users.

## Validation

- 1,035 Delphi tests passed on Win32 targets, with no failures, errors, or leaks;
- 91 web tests, 36 documentation tests, and ESLint passed;
- runtime catalog validated with 132 tools;
- SonarQube Quality Gate `OK`, with zero issues.
