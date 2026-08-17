# RadIA documentation

This is the entry point for RadIA documentation. Choose a goal; documents are organized by task,
not by release.

Folders separate getting started, usage guides, reference, development, and project direction.
Internal plans, audits, test results, and release notes do not belong in this tree.

> Use `/tools` to inspect the exact tools available in the current installation. Use
> `/doctor --deep` to validate configuration and prerequisites.

## Get started

[Open the getting-started path](getting-started/README.en.md).

| Goal | Document |
|---|---|
| Install on Delphi 12 or 13 | [Installation and configuration](getting-started/install_config.en.md) |
| Complete the first configuration | [Getting started](getting-started/onboarding.en.md) |
| Use the visual installer | [Visual installer](getting-started/visual_installer.en.md) |

## Use RadIA

[See all usage guides](guides/README.en.md).

| I want to... | Document |
|---|---|
| Understand modes, chat, agent, and consent | [User manual](guides/user_manual.en.md) |
| Understand request, session, and project precedence | [Scoped settings](guides/hierarchical_settings.en.md) |
| Create, edit, build, and test projects | [End-to-end journeys](guides/user_guide_journeys.en.md) |
| Run only affected DUnitX tests | [Impact-based tests](guides/impact_based_tests.en.md) |
| Audit and modernize a FireDAC layer | [FireDAC Advisor](guides/firedac_advisor.en.md) |
| Create a project from chat | [New Project Wizard](guides/project_wizard.en.md) |
| Use chat and sessions | [Chat and sessions](guides/user_guide_chat_sessions.en.md) |
| Work with the editor and generate code | [Editor and generation](guides/user_guide_editor_generation.en.md) |
| Work with the Designer and debugger | [Designer and debugger](guides/user_guide_designer_debugger.en.md) |
| Diagnose problems and stack traces | [Diagnostics and analysis](guides/user_guide_diagnostics_analysis.en.md) |
| Collect and navigate tool findings | [Problems panel](reference/problems_panel.en.md) |
| Reproduce runtime failures | [Runtime diagnostic automation](guides/runtime_debug_automation.en.md) |
| Diagnose leaks with FastMM5 | [Memory diagnostics](guides/fastmm5_diagnostic_session.en.md) |
| Inspect and query local SQLite | [Safe local database](guides/local_database.en.md) |
| Use the integrated terminal | [Terminal](guides/terminal.en.md) |
| Configure and use CLIs | [Native and CLI executors](guides/cli_executors.en.md) |
| Configure and use MCP | [MCP integration](guides/mcp_integration_guide.en.md) |
| Troubleshoot installation or usage | [Troubleshooting](guides/troubleshooting_agentic_platform.en.md) |

## Reference

[Open the complete reference index](reference/README.en.md).

| Information | Reference |
|---|---|
| Everything RadIA can do | [Capability map](reference/capabilities.en.md) |
| Understand completion, references, members, and CodeInsight boundaries | [Semantic intelligence](reference/semantic_intelligence.en.md) |
| Inspect each feature, its category, and its status | [Detailed inventory](reference/features.en.md) |
| Settings fields and buttons | [Settings](reference/settings_reference.en.md) |
| Understand settings tabs | [Settings map](guides/user_manual.en.md#21-settings-map) |
| Slash commands and diagnostics | [Commands](reference/slash_commands.en.md#which-diagnostic-command-to-use) |
| Complete state and diagnostics | [Doctor](reference/doctor.en.md) |
| Build, test, memory, and review findings | [Problems panel](reference/problems_panel.en.md) |
| Internal tools and when they run | [Internal tools](reference/internal_tools_reference.en.md) |
| Generated catalog for the current version | [Runtime catalog](reference/runtime_tool_catalog.en.md) |
| Delphi compatibility | [Compatibility matrix](reference/delphi_compatibility_matrix.en.md) |
| Providers, models, and CLI routes | [CLI capability matrix](reference/cli_capability_matrix.en.md) |
| Security and consent | [Security model](reference/tool_security_model.en.md) |

## Develop and contribute

[Open the development index](development/README.en.md).

| Subject | Document |
|---|---|
| Architecture | [Architecture guide](development/architecture_guide.en.md) |
| Units and responsibilities | [Source code guide](development/source_code_guide.en.md) |
| Build, tests, and contribution | [Installation and configuration](getting-started/install_config.en.md) |
| Create providers | [Provider guide](development/new_provider_guide.en.md) |
| Create tool extensions | [Extension API](development/tool_extension_guide.en.md) |
| Conventions | [Branches](development/branch_convention.en.md) · [Commits](development/commit_convention.en.md) |
| Work with Git | [Git workflow](guides/git_workflow.en.md) |
| Documentation policy | [Documentation as product](development/documentation_policy.en.md) |
| Release process | [Release](development/release_process.en.md) |

## Project direction

There is no active execution goal at this time. New initiatives become active only after receiving
a verifiable contract in the backlog.

- [Project direction index](project/README.en.md).
- [Roadmap](project/roadmap.en.md): direction and future outcomes.
- [Backlog](project/backlog.en.md): only open, verifiable work.

Release notes, downloads, and publication evidence live in
[GitHub Releases](https://github.com/regyssilveira/RadIA-Plugin/releases). Removed historical files
remain available through Git history.

Documentação em português: [Central de documentação](README.md).
