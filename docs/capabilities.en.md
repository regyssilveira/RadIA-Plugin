# Everything RadIA can do

This page is the functional map of RadIA 2.0.

| Area | What RadIA can do |
|---|---|
| Chat | Dockable panel, Markdown, Pascal highlighting, streaming, cancellation, sessions, history, exports, templates, token and cost estimates. |
| Providers | Gemini, OpenAI, Azure OpenAI, Claude, Bedrock, Copilot, DeepSeek, Groq, Qwen, Mistral, OpenRouter, Ollama, LM Studio, OpenAI-compatible and JSON-defined providers. |
| Editor | Read live buffers and selections, explain, review, refactor, optimize SQL, find bugs, scan warnings, generate tests and XML documentation. |
| Review | Smart Diff, inline reviews, reviewed fixes, safe apply and controlled revert. |
| Generation | DTOs and models from JSON or DDL, methods from comments and complete Delphi projects. |
| Templates | Console, VCL, FMX, Library, Package and DUnitX with preview, staging, validation, open, build and rollback. |
| Safe editing | Single-file and multi-file patches, base hashes, preconditions, previews, rollback and compound transactions. |
| Project structure | Reviewable addition and removal of units and forms. |
| Form Designer | Inspect forms and components, change layout and properties, add or remove components and create event handlers. |
| Build | Make, build, check, clean, structured diagnostics, status, timeout and cancellation. |
| DUnitX | Run, filter and cancel tests, parse NUnit XML and return structured failures and stack traces. |
| Debugger | Start, stop, pause, continue, step, manage breakpoints and watches, evaluate expressions, inspect call stacks and read the timeline. |
| Git | Status, diff, commit preview, fingerprint validation, selected paths and local commits. |
| Knowledge | Index, search, inspect, clear and rebuild local project knowledge while tracking IDE events. |
| Project health | Score IDE, compiler, build, tests, and local knowledge risks, then prepare a reviewed next action without running mutations. |
| Installation doctor | Score provider, executor, conditional MCP, terminal, chat, and first-tool readiness with a next action. |
| Agent Mode | Plan approval, iterative tools, live progress, pause, resume, cancel, checkpoints and resource limits. |
| MCP | stdio bridge, named pipe, IDE discovery by PID, tool calls, cancellation and sanitized metrics. |
| Security | Risk levels, consent, revocation, audit, secret redaction and workspace confinement. |
| Extensions | Visual manifest/package manager plus a versioned tool API protected by the policy pipeline. |
| Declarative extensions | Hot-reloaded commands, aliases, and audited tool workflows with explicit minimal permissions. |

Use the visual Agent On/Off button or `/agent on` and `/agent off`. Start an autonomous run with:

```text
/agent run <objective>
```

RadIA presents the plan before the first tool call. Regular questions remain ordinary chat turns.

## References

- [All 88 registered built-in tools](runtime_tool_catalog.md)
- [Operational reference for every tool](internal_tools_reference.md)
- [All slash commands](slash_commands.en.md)
- [Complete user manual](user_manual.en.md)
- [Feature catalog](features.en.md)
- [Documentation center](README.en.md)

The active IDE is authoritative: use `/tools` in chat or `tools/list` over MCP because context and
installed extensions can change the runtime catalog.
