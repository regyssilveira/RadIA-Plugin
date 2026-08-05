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
| `/terminal` | Opens the integrated dockable terminal. | Current IDE project and desktop. |
| `/tools` | Shows the tool catalog for the current IDE instance. | IDE state and extensions. |
| `/tool <name> {JSON}` | Runs a tool with optional JSON arguments. | Workspace and session. |
| `/revoke-tools` | Revokes permissions granted in the session. | Active chat session. |
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

## Customization and Command Backups

Rad IA allows you to edit, delete, or add new commands and prompt templates directly from the plugin options inside the IDE (`Tools -> Options -> Rad IA -> Templates`).

The `/agent` command family, `/terminal`, `/tools`, `/tool`, and `/revoke-tools` are internal
commands and cannot be replaced by templates.
See the [Complete RadIA User Manual](user_manual.en.md) for examples.

The remaining commands come from installed templates. Because templates can be edited, restored,
imported, or removed, typing `/` in chat is authoritative for the current profile.

Each template registry can define:
- **Slash Command**: The command string that triggers the template in chat (e.g., `/explain`).
- **Is Project Generator**: A boolean marking if the template produces executable files on disk.
- **Import/Export**: Export your templates to JSON files and import them on other machines transactionally, with options to Merge with existing templates or completely Overwrite them.

