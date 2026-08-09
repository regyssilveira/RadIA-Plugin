# Rad IA Slash Commands

Rad IA supports quick command shortcuts directly in the chat interface, enabling developers to run common tasks without typing long prompts or using the mouse.

---

## How to Use

Simply type the `/` character in the chat input area. A floating popup menu will appear below the input field, allowing you to select a command using the `↑`/`↓` arrow keys and press `Enter` to insert it.

---

## Available Commands

| Command | Description | Automatic IDE Context |
| :--- | :--- | :--- |
| `/agent [on\|off]` | Toggles or sets Agent Mode and synchronizes the visual button. | Active chat. |
| `/agent run <objective>` | Starts an observable agent loop with the current catalog. | Active session and workspace. |
| `/agent plan <JSON>` | Replaces the pending plan with a validated JSON array. | Plan awaiting approval. |
| `/agent replay <step>` | Replays the audited tool call for one step. | Paused agent run. |
| `/agent pause` | Safely interrupts the current decision and pauses the loop. | Active agent run. |
| `/agent resume` | Resumes the latest checkpoint for the session. | Paused agent run. |
| `/agent cancel` | Cancels the current decision and agent run. | Active agent run. |
| `/agent history [query]` | Searches runs by objective, status, or ID. | Local checkpoints. |
| `/help` | Summarizes RadIA capabilities and links to its documentation. | Public catalogs and guides. |
| `/terminal` | Opens the integrated dockable terminal; equivalent to the chat `>_` button. | Current IDE project and desktop. |
| `/settings` | Opens RadIA settings; equivalent to the chat gear button. | Local user configuration. |
| `/extensions` | Opens the visual extension manager. | Local extensions and publishers. |
| `/health` | Summarizes project health and prioritizes current risks. | IDE, compiler, build, tests, and local knowledge. |
| `/doctor` | Diagnoses installation and recommends the next action. | Provider, executor, conditional MCP bridge, terminal, chat, first tool, and the external MCP runtime when available. |
| `/status [filter\|--json]` | Shows a sanitized inventory of RadIA state. | Provider, agent, CLI, MCP, security, editor, project, tools, and logs. |
| `/status settings` | Shows effective provider, model, executor, and limits with each source. | Project, session, and next request. |
| `/scope` | Shows effective settings and applied precedence. | Equivalent to **Settings > Scope**. |
| `/scope <level> <field> <value>` | Creates an override at `project`, `session`, or `request` level. | Never changes credentials. |
| `/scope <level> inherit <field>` | Removes one field override and restores inheritance. | Keeps the other fields. |
| `/scope <level> clear` | Removes every override at that level. | Keeps global configuration. |
| `/cli session` | Shows whether the current conversation is linked to a resumable CLI session. | Current conversation, executor, and project. |
| `/cli new` | Detaches the external session; the next request starts a new CLI conversation. | Active conversation; it does not delete vendor data. |
| `/context` | Shows or links the journey shared by chat, terminal, and editor. | Active conversation and project. |
| `/context new` | Creates a new journey identity for the current conversation and project. | Discards only the previous transient link. |
| `/context detach` | Detaches the conversation from shared journey context. | Does not delete conversation, history, or CLI session. |
| `/context switch <id>` | Opens the conversation linked to the given journey. | Accepts only journeys from the active project. |
| `/journey` | Lists end-to-end Delphi recipes. | Native journey catalog. |
| `/journey cancel` | Abandons the active journey intake. | Context not yet executed. |
| `/journey create` | Creates, opens, builds, and explains a new project. | Agent Runtime and project tools. |
| `/journey dext-minimal` | Creates and validates a DEXT server with direct routes. | DEXT templates, build, and runtime. |
| `/journey dext-controllers` | Creates and validates a DEXT server with controllers. | DEXT templates, build, Swagger, and runtime. |
| `/journey fix-build` | Diagnoses and repairs a build with minimal changes. | Compiler, patches, and build. |
| `/journey tests` | Expands DUnitX tests and runs validation. | Project, patches, and DUnitX. |
| `/journey debug` | Guides reproduction, diagnosis, correction, and validation. | Debugger, patches, and build. |
| `/journey modernize` | Modernizes structure and practices in reviewable batches. | Graph, Designer, transactions, build, and tests. |
| `/journey migrate` | Migrates a legacy pattern with a baseline and rollback. | Graph, transactions, diff, build, and tests. |
| `/journey release` | Runs gates and prepares a local commit preview. | Health, build, tests, and Git. |
| `/tools` | Shows the tool catalog for the current IDE instance. | IDE state and extensions. |
| `/tool <name> {JSON}` | Runs a tool with optional JSON arguments. | Workspace and session. |
| `/revoke-tools` | Revokes permissions granted in the session. | Active chat session. |
| `/extensions reload` | Reloads declarative extensions and shows diagnostics. | Local extension directory. |
| `/explain` | Analyzes and explains the logic of the selected code block in the editor. | Sends the selected code snippet. |
| `/refactor` | Optimizes performance, readability, and applies SOLID/Clean Code best practices. | Sends the selected code snippet. |
| `/optimize` | Alias for code optimization and refactoring. | Sends the selected code snippet. |
| `/performance` | Analyzes bottlenecks and performance opportunities. | Sends the selected code snippet. |
| `/test` | Generates DUnitX unit tests for the selected code. | Sends the selected code snippet. |
| `/bugs` | Scans selected code for memory leaks, unhandled exceptions, and logic bugs. | Sends the selected code snippet. |
| `/doc` | Generates Delphi-compliant XML help documentation tags (`/// <summary>`) above methods. | Sends the selected method signature. |
| `/template` | Opens the quick prompt template library selector. | — |
| `/stacktrace` | Analyzes exception logs (MadExcept, EurekaLog, or RTL) and points to the root cause. | Sends the active unit file from the editor as context for the error line number. |
| `/review` | Runs a comprehensive static analysis of the active unit looking for leaks and anti-patterns. | Sends the full source code of the active editor file. |
| `/sqloptimize` | Analyzes and optimizes the selected SQL query, suggesting indexes, syntax corrections, and performance improvements. | Sends the selected SQL query string. |
| `/scanwarnings` | Scans the code for potential Delphi compiler warnings, thread-safety violations, and Windows GDI resource leaks. | Sends the selected code snippet or the active unit. |
| `/createproject` | Generates a complete vanilla Delphi project on disk and loads it in the IDE based on text specs. | — |
| `/createprojectarch` | Generates a Clean Architecture (SOLID) Delphi project on disk and loads it in the IDE. | — |

---

## Which diagnostic command to use

| Need | Command | Result |
|---|---|---|
| Find why RadIA is not ready | `/doctor` | Six baseline checks, the external MCP runtime when available, issues, recommendations, and the next action. |
| Review what is configured and available | `/status` | Every area, without keys, tokens, or sensitive payloads. |
| Inspect one area | `/status cli`, `/status mcp`, `/status provider` | Only the requested section. `mcp` separates the CLI bridge from sanitized external-runtime counts. It also accepts `agent`, `security`, `editor`, `project`, `tools`, `logging`, and `settings`. |
| Copy or process the complete structure | `/status --json` | Complete structured state returned by the tool. |
| Assess the open Delphi project | `/health` | Project, build, test, compiler, and local-knowledge risks. |
| Discover executable tools | `/tools` | Effective catalog for the current IDE instance. |

Start with `/doctor` when something does not work. Use `/status` when the question is “what is
configured now?”. Executable paths may appear, but credentials are never included.

## Customization and Command Backups

Rad IA allows you to edit, delete, or add new commands and prompt templates directly from the plugin options inside the IDE (`Tools -> Options -> Rad IA -> Templates`).

The `/agent` command family, `/terminal`, `/settings`, `/extensions`, `/health`, `/doctor`,
`/status`, `/scope`, `/tools`, `/tool`,
`/revoke-tools`, and
`/extensions reload` are internal
commands and cannot be replaced by templates.
See the [Complete RadIA User Manual](user_manual.en.md) for examples.

See [Project, session, and request settings](hierarchical_settings.en.md) for complete precedence,
accepted fields, persistence, and recovery examples.

Declarative extensions can add commands without recompiling or restarting the IDE. See
[Declarative extensions](declarative_extensions.en.md).

The remaining commands come from installed templates. Because templates can be edited, restored,
imported, or removed, typing `/` in chat is authoritative for the current profile.

Each template registry can define:
- **Slash Command**: The command string that triggers the template in chat (e.g., `/explain`).
- **Is Project Generator**: A boolean marking if the template produces executable files on disk.
- **Import/Export**: Export your templates to JSON files and import them on other machines transactionally, with options to Merge with existing templates or completely Overwrite them.

