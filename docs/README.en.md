# RadIA documentation

This is the documentation entry point for RadIA 2.6.2. Start with the task you want to complete;
each subject has one primary guide to prevent duplicated or conflicting instructions.

> The `/tools` command is the most accurate reference for the current installation because the
> catalog may vary with IDE version, context, and installed extensions.

## Start using RadIA

| Goal | Start here | Continue with |
|---|---|---|
| Install on Delphi 12 or 13 | [Installation and configuration](install_config.en.md) | [Onboarding](onboarding.en.md) |
| Discover current capabilities | [Capabilities](capabilities.en.md) | [Feature catalog](features.en.md) |
| Configure a provider, agent, or CLI | [Installation](install_config.en.md) | [CLI executors](cli_executors.en.md) |
| Use different settings by project or conversation | [Scoped settings](hierarchical_settings.en.md) | [Slash commands](slash_commands.en.md) |
| Understand every settings tab | [Settings map](user_manual.en.md#21-settings-map) | [Security model](tool_security_model.en.md) |
| Look up a specific field or button | [Complete settings reference](settings_reference.en.md) | [Troubleshooting](troubleshooting_agentic_platform.en.md) |
| Use chat and sessions | [Chat and sessions](user_guide_chat_sessions.en.md) | [Slash commands](slash_commands.en.md) |
| Continue a task across chat, terminal, and editor | [Shared context](shared_journey_context.en.md) | [Chat and sessions](user_guide_chat_sessions.en.md) |
| Troubleshoot a problem | [Troubleshooting](troubleshooting_agentic_platform.en.md) | [Compatibility](delphi_compatibility_matrix.en.md) |
| Inspect configured RadIA state | [Doctor, status, health, and tools](slash_commands.en.md#which-diagnostic-command-to-use) | [Settings reference](settings_reference.en.md) |
| Understand effective values, sources, and inheritance | [Project, session, and request settings](hierarchical_settings.en.md) | [Settings reference](settings_reference.en.md) |

## Complete a development task

| Task | Primary guide |
|---|---|
| Explain, review, refactor, or generate code | [Editor and generation](user_guide_editor_generation.en.md) |
| Diagnose code, warnings, SQL, or a stack trace | [Diagnostics and analysis](user_guide_diagnostics_analysis.en.md) |
| Receive and diagnose Ghost Text/FIM suggestions | [Inline assistance and FIM](inline_completion.en.md) |
| Review changes block by block in the gutter | [Block-level review](block_reviews.en.md) |
| Create a Delphi project | [New Project Wizard](project_wizard.en.md) |
| Add or remove units and forms | [Project operations](project_file_operations.en.md) |
| Coordinate code, project, and Designer changes | [Development transactions](development_transactions.en.md) |
| Build, fix errors, and run tests | [End-to-end journeys](user_guide_journeys.en.md) |
| Create a DEXT server from endpoints | [DEXT server journeys](user_guide_dext_journeys.en.md) |
| Run DUnitX tests | [DUnitX runner](dunitx_runner.en.md) |
| Use Form Designer or debugger | [Designer and debugger](user_guide_designer_debugger.en.md) |
| Reproduce a visual failure | [Runtime diagnostics](runtime_debug_automation.en.md) |
| Diagnose memory problems | [FastMM5 diagnostics](fastmm5_diagnostic_session.en.md) |
| Use the integrated terminal | [Terminal](terminal.en.md) |
| Search project knowledge | [Project knowledge](user_guide_project_knowledge.en.md) |
| Review and create a local Git commit | [Git workflow](git_workflow.en.md) |

## Agent, tools, and security

| Subject | Authoritative document |
|---|---|
| Enable and operate agent mode | [User manual](user_manual.en.md) |
| Native agent and external executors | [CLI executors](cli_executors.en.md) |
| CLI capabilities and resume contracts | [CLI capability matrix](cli_capability_matrix.en.md) |
| Diagnose installation and the effective route | [RadIA Doctor](doctor.en.md) |
| Inspect configured RadIA state | [Doctor, status, health, and tools](slash_commands.en.md#which-diagnostic-command-to-use) |
| Understand effective values, sources, and inheritance | [Scoped settings](hierarchical_settings.en.md) |
| Available runtime tools | [Runtime tool catalog](runtime_tool_catalog.en.md) |
| Understand every tool and when it runs | [Operational tool reference](internal_tools_reference.en.md) |
| Consent, risk, and auditing | [Tool security model](tool_security_model.en.md) |
| Agent cost and limits | [Agent pricing](agent_pricing.en.md) |
| Plan internal result compaction | [Internal RTK execution plan](rtk_execution_plan.en.md) |
| Use and diagnose the internal RTK | [Agent result compaction and recovery](agent_result_compaction.en.md) |
| Review release 2.6.2 | [Release notes](release_notes_2.6.2.en.md) |
| Use tools from another client | [MCP integration](mcp_integration_guide.en.md) |

Provider, CLI executor, and MCP are independent settings. A declared authentication transport,
such as ChatGPT login through Codex, is the explicit exception.

## Extend and integrate

| Goal | Guide |
|---|---|
| Share commands, skills, knowledge, templates, aliases, and workflows | [Declarative extensions](declarative_extensions.en.md) |
| Publish one skill to supported CLIs | [Skill portability](skill_portability.en.md) |
| Register tools from a package | [Tool extension API](tool_extension_guide.en.md) |
| Add a provider | [Provider guide](new_provider_guide.en.md) |
| Integrate an MCP client | [MCP integration](mcp_integration_guide.en.md) |
| Inspect future tool contracts | [Architectural catalog](tool_catalog.en.md) |

The architectural catalog includes proposals. Use `/tools` or the generated runtime catalog to
inspect what the installed version actually provides.

## Develop and contribute

- [Required documentation policy](documentation_policy.en.md)
- [Active 2.6.0 goal](radia_2.6_goal.en.md)

| Subject | Guide |
|---|---|
| Architecture | [Architecture guide](architecture_guide.en.md) |
| Agent architecture | [Agent architecture](agentic_architecture.en.md) |
| Source map | [Source code guide](source_code_guide.en.md) |
| Supported compatibility | [Delphi matrix](delphi_compatibility_matrix.en.md) |
| Build and tests | [Installation and configuration](install_config.en.md) |
| Branch and commit conventions | [Branches](branch_convention.en.md) · [Commits](commit_convention.en.md) |
| Release process | [Release guide](release_process.en.md) |
| Privacy and licenses | [Compliance](compliance.en.md) |

## Planning and historical records

Roadmaps, backlogs, goals, milestone reports, release audits, and `*_evidence_*.json` files preserve
project history. They are not current user instructions. If historical content differs from a
primary guide, the current code, `/tools`, and the primary guides above take precedence.

Current execution plan:

- [Completed skill portability and terminal goal](terminal_skill_portability_goal.en.md).
- [2.6.2 release audit](release_audit_2.6.2.en.md) and previous audits.
- release notes: [2.6.2](release_notes_2.6.2.en.md), [2.6.1](release_notes_2.6.1.en.md),
  [2.6.0](release_notes_2.6.0.en.md),
  [2.5.0](release_notes_2.5.0.en.md),
  [2.4.2](release_notes_2.4.2.en.md), [2.4.1](release_notes_2.4.1.en.md),
  [2.4.0](release_notes_2.4.0.en.md), [2.3.1](release_notes_2.3.1.en.md), and
  [2.3.0](release_notes_2.3.0.en.md), including its
  [RTK audit](result_compaction_release_audit_2.3.0.en.md).
- [Completed complete-experience expansion goal](experience_expansion_goal.en.md).
- [Completed six-gap experience goal](competitive_leadership_plan.en.md).

Research records:

- [Free Claude Code ideas applicable to RadIA (pt-BR)](research/free-claude-code-radia-analysis.en.md).

## Current compatibility

| IDE | Architecture | Support |
|---|---|---|
| Delphi 12 Athens | Win32 | Supported and validated |
| Delphi 13 | Win32 | Supported and validated |
| Delphi 13 | IDE64 | Supported and validated |

Delphi 11 appears only in historical records and is outside the current support matrix.

Documentação em português: [Centro de documentação](README.md).
