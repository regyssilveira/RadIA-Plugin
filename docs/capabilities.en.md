# Everything RadIA can do

This page is the functional map of RadIA 2.6.1.

| Area | What RadIA can do |
|---|---|
| Chat | Dockable panel, Markdown, Pascal highlighting, streaming, cancellation, a visible five-message follow-up queue, sessions, history, exports, templates, token and cost estimates. |
| Shared journey | Link chat, terminal, and editor by project-safe identity without copying history or process output. |
| Terminal | Use multi-tab ConPTY with streaming UTF-8, CJK, emoji and combining-character widths, reflow, extended colors, attributes, alternate screen, bracketed paste, SGR mouse, consent-gated OSC 8 links, history, and tree cancellation. |
| Help | `/help`, fillable command examples, and documentation links opened in the default browser. |
| Journeys | Conversational intake that preserves answers, plus minimal and controller-based DEXT project generation. |
| Providers | Gemini, OpenAI, Azure OpenAI, Claude, Bedrock, Copilot, DeepSeek, Groq, Qwen, Mistral, OpenRouter, Ollama, LM Studio, OpenAI-compatible and JSON-defined providers. |
| Editor | Read live buffers and selections, explain, review, refactor, optimize SQL, find bugs, scan warnings, generate tests and XML documentation, and compare up to three Ghost Text alternatives through dedicated FIM on Ollama/LM Studio with explicit fallback elsewhere. |
| Review | Smart Diff, inline reviews, reviewed fixes, safe apply and controlled revert. |
| Generation | DTOs and models from JSON or DDL, methods from comments and complete Delphi projects. |
| Templates | Console, VCL, FMX, Library, Package and DUnitX with preview, staging, validation, open, build and rollback. |
| Safe editing | Single-file and multi-file patches, base hashes, preconditions, previews, rollback and compound transactions. |
| Project structure | Reviewable addition and removal of units and forms. |
| Form Designer | Inspect forms and components, change layout and properties, add or remove components and create event handlers. |
| Build | Make, build, check, clean, structured diagnostics, status, timeout and cancellation. |
| DUnitX | Run, filter and cancel tests, parse NUnit XML and return structured failures and stack traces. |
| Debugger | Start, stop, pause, continue, step, manage breakpoints and watches, evaluate expressions, inspect call stacks and read the timeline. |
| Autonomous runtime diagnostics | Build and start under the IDE debugger, capture the authorized window before and after a bounded visual scenario, record an exception and stack, rebuild, compare evidence across distinct sessions and builds, and preserve a versioned regression. |
| Git | Status, diff, commit preview, fingerprint validation, selected paths and local commits. |
| Knowledge | Index, search, inspect, clear and rebuild local project knowledge while tracking IDE events. |
| Project health | Score IDE, compiler, build, tests, and local knowledge risks, then prepare a reviewed next action without running mutations. |
| Installation doctor | Diagnose the effective route, provider, conditional CLI/MCP, terminal, chat, and tool readiness with a next action. |
| RadIA status | Show a sanitized, filterable inventory of provider, agent, CLI, MCP, security, editor, project, tools, and logging state. |
| Scoped settings | Resolve provider, model, executor, and limits by request, session, project, global value, and safe default, with visible sources and inheritance controls. |
| Agent Mode | Plan approval, iterative tools, live progress, pause, resume, cancel, checkpoints, resource limits, and internal DUnitX/Git diff result compaction. |
| MCP | stdio bridge, named pipe, IDE discovery by PID, tool calls, cancellation and sanitized metrics. |
| Security | Risk levels, one queued native dialog for chat, agent, MCP, and terminal, readable source, redacted arguments, hints, revocation, audit, and workspace confinement. |
| Extensions | Visual creation, sandbox, install, export, signing, and management plus a versioned tool API protected by the policy pipeline. |
| Declarative extensions | Hot-reloaded commands, skills, journeys, knowledge, references, templates, aliases, and audited workflows with transactional package resources. |
| Skill portability | Project-scoped publication to four CLIs with preview, central consent, ownership hashes, rollback, and conflict preservation. |

Use the visual Agent On/Off button or `/agent on` and `/agent off`. Start an autonomous run with:

```text
/agent run <objective>
```

RadIA presents the plan before the first tool call. Regular questions remain ordinary chat turns.

## References

- [All 132 registered built-in tools](runtime_tool_catalog.en.md)
- [Operational reference for every tool](internal_tools_reference.en.md)
- [All slash commands](slash_commands.en.md)
- [Complete user manual](user_manual.en.md)
- [Feature catalog](features.en.md)
- [Agent result compaction](agent_result_compaction.en.md)
- [Project, session, and request settings](hierarchical_settings.en.md)
- [Documentation center](README.en.md)

The active IDE is authoritative: use `/tools` in chat or `tools/list` over MCP because context and
installed extensions can change the runtime catalog.
