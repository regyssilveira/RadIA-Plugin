<div align="right">

[Português](README.md) | [English](README.en.md) | [Documentation](docs/README.en.md) | [Roadmap](docs/roadmap.en.md)

</div>

<p align="center">
  <img src="docs/images/radia_readme_banner-2.png" alt="RadIA - AI assistant for Delphi" width="100%" />
</p>

# RadIA — AI assistant integrated into Delphi

RadIA connects chat, code generation, and an agent to real IDE tools. It can inspect and edit a
project, build it, run tests, control the debugger, interact with Form Designer, and collect
evidence that validates a fix, with consent and workspace boundaries.

## Start here

1. [Install and configure RadIA](docs/install_config.en.md).
2. Read the [user manual](docs/user_manual.en.md).
3. Use the [documentation hub](docs/README.en.md) to find guides by task.
4. Review the [capability map](docs/capabilities.en.md) for the current product scope.

Type `/help` in chat for a capability summary, primary commands, and documentation links. Links open
in the Windows default browser.

## Compatibility

| IDE | Architecture | Status |
|---|---|---|
| Delphi 12 Athens | Win32 | Supported and validated |
| Delphi 13 | Win32 | Supported and validated |
| Delphi 13 | IDE64 | Supported and validated |

Delphi 11 is outside the current support matrix.

## Main capabilities

| Area | What RadIA provides | Guide |
|---|---|---|
| Chat | Providers, streaming, sessions, templates, history, and commands | [Chat and sessions](docs/user_guide_chat_sessions.en.md) |
| Scoped settings | Provider, model, executor, and limits by project, session, or next request | [Scoped settings](docs/hierarchical_settings.en.md) |
| Editor | Explain, review, refactor, generate code, tests, DTOs, and documentation | [Editor and generation](docs/user_guide_editor_generation.en.md) |
| Ghost Text/FIM | Complete at the cursor through a dedicated route or diagnosable fallback | [Inline assistance and FIM](docs/inline_completion.en.md) |
| Projects | Create projects, units, and forms with preview and validation | [Project wizard](docs/project_wizard.en.md) |
| DEXT | Create minimal or controller-based APIs through guided journeys | [DEXT journeys](docs/user_guide_dext_journeys.en.md) |
| Build and tests | Build, structure errors, run DUnitX, and gate changes | [Journeys](docs/user_guide_journeys.en.md) |
| Designer and debugger | Components, events, execution, breakpoints, watches, and call stack | [Designer and debugger](docs/user_guide_designer_debugger.en.md) |
| Runtime diagnostics | Reproduce a visual failure, fix it, and replay the scenario | [Runtime diagnostics](docs/runtime_debug_automation.en.md) |
| Memory | Instrument Debug builds with FastMM5 and compare a fix | [FastMM5 diagnostics](docs/fastmm5_diagnostic_session.en.md) |
| Agent | Plan, execute tools, pause, resume, cancel, and restore checkpoints | [User manual](docs/user_manual.en.md) |
| MCP | Expose IDE tools to authorized local clients | [MCP integration](docs/mcp_integration_guide.en.md) |
| Knowledge | Index and search the local project | [Project knowledge](docs/user_guide_project_knowledge.en.md) |

## Native agent, CLI, provider, and MCP

These settings have separate responsibilities:

- a **provider** connects chat to a model through an API, local endpoint, or declared transport;
- the **native agent** runs tools, consent, and checkpoints inside RadIA;
- an **external CLI executor** delegates the objective to a user-installed Codex, Claude, Gemini,
  or Copilot client;
- **MCP** lets another authorized client use tools published by the IDE.

OpenAI API via API Key uses HTTP transport and API Platform billing. ChatGPT Pro uses the Codex CLI
session and quota. In the latter route, **RadIA native** keeps orchestration inside RadIA, while
**Codex CLI direct** delegates the complete execution to the CLI. See the
[executor matrix](docs/cli_executors.en.md).

## Tools and commands

- `/tools` shows tools available in the current installation and context.
- `/help` summarizes the product and links to the applicable documentation.
- `/journey` lists journeys that collect missing input without losing conversational context.
- `/scope` shows effective values and overrides or restores inheritance without an IDE restart.
- The [123-tool runtime catalog](docs/runtime_tool_catalog.md) lists built-in registrations.
- The [operational reference](docs/internal_tools_reference.md) explains purpose and activation.
- The [slash command guide](docs/slash_commands.en.md) documents commands and examples.
- The [security model](docs/tool_security_model.md) explains risk, consent, and auditing.

The runtime `/tools` response is authoritative. Roadmaps and architectural catalogs may include
proposals that are not yet available.

## Installation

To use RadIA, download only `RadIA-v<version>-Setup.exe` from the
[latest release](https://github.com/regyssilveira/RadIA-Plugin/releases/latest). Close Delphi, run
the installer, and select the intended IDEs. A release installation does not require a ZIP,
PowerShell/npm, or a local build.

To find and understand any settings field or button, see the
[complete settings reference](docs/settings_reference.en.md).

## Build from source

The commands below are intended for contributors:

```powershell
# Delphi 12 Win32
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test

# Delphi 13 Win32
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "37.0" -Test

# Delphi 13 IDE64
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "37.0" -IDE64 -Test
```

Close the IDE before installing or replacing a BPL. See the
[installation guide](docs/install_config.en.md) for complete instructions.

## Development and contribution

- [Architecture](docs/architecture_guide.en.md)
- [Source code map](docs/source_code_guide.en.md)
- [Compatibility matrix](docs/delphi_compatibility_matrix.md)
- [Branch convention](docs/branch_convention.en.md)
- [Commit convention](docs/commit_convention.en.md)
- [Release process](docs/release_process.en.md)
- [Backlog](docs/backlog.en.md)

Source code, identifiers, comments, and commits are written in English. The primary user
documentation is maintained in Brazilian Portuguese, with English versions where available.

## License

See [LICENSE](LICENSE) and the [compliance guide](docs/compliance.en.md).
