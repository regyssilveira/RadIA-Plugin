# Release notes — RadIA 2.5.0

## Chat experience

- Organizes composer controls into two semantic rows: execution and conversation context.
- Reflows selectors, actions, and effective status according to the docked panel width.
- Preserves existing commands, shortcuts, and identifiers without changing the chat workflow.
- Keeps the plan approval card as the last visible result and offers `/agent resume` as a text
  alternative, preventing a duplicated message from hiding **Approve plan**.
- Adds a direct Chat, Agent, CLI, and MCP comparison table to the README and `/help`.
- Recognizes natural project-creation requests without requiring users to choose the executor first.
- Extracts absolute Windows paths, derives the name from the folder, and defaults to Win32 when no
  platform is specified, asking only for information that is actually missing.
- Shows live CLI activity and prevents external links from replacing the chat surface.
- Keeps advanced executor, session, journey, and scope controls behind **More**.

## Project creation and consent

- Adds deterministic composition for a functional VCL calculator.
- Opens, builds, runs, and validates the primary scenario before completing the journey.
- Reuses **Allow session** across compatible tools with the same origin, project, scope, and risk
  category, reducing repeated prompts without widening destructive permissions.
- Keeps `/revoke-tools` and category preferences as immediate revocation and opt-out controls.

## CLI installation

- Keeps npm as the preferred channel when it is already available.
- Uses official WinGet packages for Codex CLI and Claude Code when npm is unavailable.
- Keeps GitHub Copilot CLI on WinGet and displays the command before any execution.
- Explains that Gemini CLI still requires Node.js on Windows through its official channel.
- Preserves **Browse** for existing executables, per-step consent, and automatic post-install checks.
- Allows Agent mode to chat and create a new VCL project without an open project, using a private
  workspace until the project is created or opened.

CLIs are not bundled into the RadIA installer. The manager uses official channels to reduce
obsolescence, installer size, and third-party software redistribution risks.

## Compatibility

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64.

The visual installer remains the only artifact required by end users.

## Validation

- 1,046 Delphi tests passed on Win32 targets, with no failures, errors, or leaks;
- 97 web tests, 36 documentation tests, and ESLint passed;
- runtime catalog validated with 132 tools;
- SonarQube Quality Gate `OK`, with zero issues.
