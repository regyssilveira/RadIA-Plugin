# Release notes — RadIA 2.4.0

> **Status:** candidate prepared on the working branch. Not published yet.

## Highlights

- One skill definition can be published to Codex, Claude Code, Gemini CLI, and GitHub Copilot CLI
  from Addon Studio.
- Preview shows destinations, creation, update, unchanged output, and conflicts before any write.
- Central consent, atomic replacement, rollback, and ownership hashes protect the workspace.
- Manually changed replicas are never overwritten or removed silently.
- The terminal separates ConPTY transport, VT emulation, and VCL rendering through its own contract.
- ANSI colors, 256 colors, and true color are preserved for foreground and background.
- Bold, italic, underline, inverse video, and selective reset are rendered.
- Alternate screen restores the primary screen; bracketed paste and SGR mouse require negotiation.
- OSC 8 hyperlinks accept only `http`, `https`, and `mailto`, require a double-click, and request
  consent for every opening.
- Direct Codex CLI supports non-Git Delphi projects in new and resumed conversations with an
  explicit working directory.
- ChatGPT Pro preserves the real Codex error instead of turning it into an empty response or a
  generic JSON-decision failure.
- `/doctor` 2.0 displays the effective route, separate CLI/MCP dependencies, classified checks, and
  a next action in a dedicated visual card.
- `/doctor --deep` requests consent and runs real CLI version/authentication probes plus temporary
  handshakes against enabled external MCP servers without changing configuration.

## How to use

To publish a skill, open **Tools > Rad IA Addon Studio**, select an extension containing skills, and
click **Publish skill to CLIs...**. Select destinations, review complete paths, and authorize the
operation. See [Skill portability](skill_portability.en.md).

Open the terminal from the **>_ Terminal** button, `/terminal`, the menu, or the configurable
shortcut. Applications automatically enable the VT modes they need. See [Terminal](terminal.en.md).

## Compatibility and upgrade

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64.

No manual migration is required. Existing extensions remain valid, and CLI replicas are created
only after an explicit action. The visual installer remains the normal end-user path; a ZIP is not
required for installation.

## Candidate validation

- 1,029/1,029 DUnitX tests passed on each target with no failures, errors, or leaks;
- real ConPTY streaming, continuous input, and resize passed on all three targets;
- Codex CLI 0.147.0, Claude Code 2.1.226, Gemini CLI 0.54.4, and GitHub Copilot CLI 1.0.78 detected;
- 86/86 web and documentation tests passed, including links, bilingual pairs, navigation, mojibake,
  and the absence of prohibited references;
- ESLint passed;
- SonarQube passed with 82.7% global coverage and zero issues.
- installed visual smoke passed on Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 with 131
  tools, controls, input, output, palette, profiles, and keyboard navigation.

See the [reproducible terminal evidence](terminal_high_fidelity_evidence_2.4.0.json) and the
[installed visual matrix](terminal_smoke_evidence_2.4.0.json).

Tagging, merging, and publishing require explicit authorization.

Hashes from the audit produced before these fixes remain historical evidence. Candidate artifacts
must be regenerated before publication to include the Codex executor and Doctor 2.1 changes.
