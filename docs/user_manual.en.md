# Complete RadIA 2.2.1 user manual

## 1. What RadIA is

RadIA is an AI assistant integrated with Delphi 12 and 13. It combines multi-provider chat,
live IDE context, code generation and review, structured IDE tools, build, Form Designer, debugger,
local project knowledge, MCP access, consent, auditing, and workspace protection.

This manual is the recommended user entry point. Specialized guides linked throughout the document
provide deeper contract, security, development, and integration details.

For usage, architecture, quality, and release documentation, see the
[Documentation Center](README.en.md).

## 2. Getting started

After installing the package for the intended IDE architecture, open Delphi and dock the RadIA
panel. Configure a provider under `Tools > Options > Rad IA`, select a model, create a session, and
send a prompt with `Ctrl + Enter`.

Supported credentials are protected locally with Windows DPAPI. Ollama and LM Studio can run
locally. See the [installation guide](install_config.en.md).

RadIA first requests the model list exposed by the configured account and endpoint. Only when
discovery fails does it show a minimal fallback catalog based on the provider's current stable
families. The discovered list always takes precedence because availability can vary by account,
region, plan, and permissions. ChatGPT OAuth/Codex transport models are kept separate from OpenAI
API models.

## 3. Enabling agent mode

### 3.1 Agent Mode button and commands

The agentic infrastructure starts automatically when the RadIA package loads. The
**Agent On/Off** button controls whether chat may execute tools. The same state can be changed with
`/agent`, `/agent on`, and `/agent off`.

In chat, tool access is explicit:

```text
/tools
```

This displays the catalog available in the current IDE and is the runtime source of truth.

The catalog can be searched by name, purpose, or risk. Each tool shows its description, risk
category, direct and agent activation guidance, and accepted JSON schema. Expanding details never
executes the tool.

Run a tool with:

```text
/tool GetIDEState
```

Pass JSON arguments after the tool name:

```text
/tool SearchProjectKnowledge {"query":"IRadIAToolRegistry","maxResults":10}
```

Revoke session permissions with:

```text
/revoke-tools
```

Start an autonomous run with an explicit objective:

```text
/agent run inspect the active project, fix the compiler error, and validate the build
```

Before the first tool, chat displays the proposed plan and waits for **Approve plan**. The live
execution center shows the objective, current message, steps and limits, tokens, time, cost, and
change, build, and test indicators. Each timeline step expands to show arguments, result or error,
correlation, duration, and whether it mutated the workspace. Use its controls or `/agent pause`,
`/agent resume`, and `/agent cancel`. Every state transition is persisted under
`RadIA\agent-checkpoints`, so a paused session can be resumed.
While a plan awaits approval, use **Edit plan** to revise titles and descriptions before any tool
runs. The keyboard equivalent is `/agent plan [{"title":"Inspect","description":"..."}]`. RadIA
accepts 1–50 steps, validates field limits, and blocks edits after execution starts.
While a run is paused, every timeline item offers **Replay step**. The command equivalent is
`/agent replay <step>`. Replay uses the same audited tool and arguments, passes through central
consent again, asks for extra confirmation on mutations, records `replayOfStepIndex`, and remains
paused for review before resuming.
Use the **Runs** button or `/agent history [query]` to find runs by objective, status, or session ID.
The index exposes metadata only; tool arguments and results are excluded from search results.
To enable monetary estimates and enforcement, configure the
[local pricing catalog](agent_pricing.en.md).

Open the integrated terminal with the **Terminal** (`>_`) button in the chat header or with the
`/terminal` command. Both paths open the same dockable terminal, supporting visual and
keyboard-driven workflows.

The **Agent On/Off** header button and `/agent`, `/agent on`, and `/agent off` commands control the
same state. When disabled, the catalog remains available, but chat tool calls are rejected until
Agent Mode is enabled again.

Regular prompts remain provider conversations. The autonomous loop requires `/agent run`, avoiding
accidental tool execution for ordinary questions. External automation remains available through
the [MCP bridge](mcp_integration_guide.en.md).

The live run card shows an expandable timeline for every tool, including formal risk, duration,
correlation, arguments, results, errors, and affected files. Files are extracted only from
recognized path fields in successful mutation calls; free-form text is not treated as a path.
When a journey includes validation, **Validation evidence** shows build status and duration,
compiler message count, and DUnitX totals, passes, failures, errors, and ignored tests. These data
remain in the checkpoint and return when the run is opened from history. When an authoritative
Delphi Code Coverage report exists, the same section shows its percentage, covered and total
lines, source-file count, and evidence path.
Successful patch steps present **Reviewed changes** inside their details. Each file shows only the
changed block, three context lines, and removed/added totals. This view is review-only; applying or
reverting remains an audited tool call subject to configured consent.
Git steps present **Git evidence**. Status is readable; diffs color added and removed lines while
showing files and totals; commit previews show their message, selected path count, and fingerprint;
and completed commits show the local SHA. RadIA does not push automatically through this flow.
Debugger tools present **Debug evidence** with state and location, breakpoints, stack frames, state
transitions, evaluations, watches, and recent events. The UI does not poll or execute additional
actions: it shows only the already authorized and audited step result, bounding lists to a safe
WebView size.

### 3.2 Consent

Read-only tools may run directly. Mutating and execution tools display their name, risk, and scope:

- **Allow once:** authorizes only the presented call;
- **Allow session:** authorizes compatible calls in the current session and scope;
- **Deny:** rejects without changing IDE state;
- **Cancel:** requests cooperative cancellation.

Session permission is not global. Project, tool, client, and scope are part of the decision.
Use `/revoke-tools` or **Revoke session permissions** to clear every active session grant.

Under **Settings > Security & Consent**, users can configure:

- consent dialog timeout from 15 to 600 seconds;
- whether tool arguments are shown;
- session permission for reversible writes;
- session permission, disabled by default, for structural writes;
- session permission, disabled by default, for builds, tests, and execution.
- local semantic project knowledge, disabled by default, without network code transmission.
- local memory of approved agent run summaries, disabled by default and isolated per project.
- knowledge exclusions using file and project path fragments.

Destructive and sensitive tools never offer session permission. Auditing, secret sanitization, and
workspace confinement cannot be disabled.

## 4. What RadIA can do

### 4.1 Chat and productivity

- Dockable Markdown chat with Pascal highlighting and IDE themes.
- Streaming responses and cancellation.
- Multiple persistent sessions and prompt history.
- Markdown and HTML conversation export.
- Reusable templates, backups, and custom slash commands.
- Token and estimated cost tracking with a local quota.

See the [chat guide](user_guide_chat_sessions.en.md).

### 4.2 Providers

RadIA integrates with Gemini, OpenAI, Azure OpenAI, Anthropic Claude, AWS Bedrock, GitHub Copilot,
DeepSeek, Groq, Alibaba Qwen, Mistral AI, OpenRouter, Ollama, LM Studio, OpenAI-compatible custom
endpoints, and JSON-defined dynamic providers.

Consumer Web Login was removed. Use supported API keys, OAuth, or local providers.

### 4.3 Editor and generation

RadIA can explain, review, refactor, optimize SQL, identify likely bugs and leaks, generate DUnitX
tests, create XML documentation, analyze warnings, and generate method bodies from comments.

It also generates DTOs and models from JSON or DDL and can create complete Delphi project
structures. Smart Diff lets users review generated changes before applying them.

See the [editor and generation guide](user_guide_editor_generation.en.md).

### 4.4 IDE and workspace tools

Implemented tools inspect IDE version and architecture, active project and unit, project units,
open files, live editor content and selection, cursor position, and compiler messages.

```text
/tool GetActiveProject
/tool ListProjectUnits
/tool GetEditorSelection
/tool GetCompilerMessages
```

Paths outside the authorized workspace are rejected.

### 4.5 Reviewable patches

The safe editing cycle uses `PreparePatch`, `ApplyPatch`, and `RevertPatch`. RadIA validates the
file, original text, and base hash. Concurrent edits invalidate the preview instead of being
overwritten.

See the [agentic tools guide](user_guide_agentic_tools.en.md).

### 4.6 Build

`BuildProject` supports `make`, `build`, `check`, and `clean`. `GetBuildStatus`, `CancelBuild`, and
`GetCompilerMessages` expose controlled execution and structured output. A build does not grant
permission to run its binary.

### 4.7 DUnitX tests

`RunDUnitXTests` runs a `.exe` test runner inside the active project workspace.
`GetDUnitXStatus` reports its state, and `CancelDUnitXTests` cancels the active process. RadIA reads
the native NUnit XML report and returns structured fixtures, test cases, durations, failures, and
stack traces. Test filters and a timeout from one second to ten minutes are supported.

Executables outside the workspace, reparse points, and non-`.exe` files are rejected. XML and log
artifacts are retained under `.radia/test-results`. DUnitX projects generated by RadIA already
register `TDUnitXXMLNUnitFileLogger`, which is required for structured reports.

`GetCoverageSummary` reads `Output/Coverage/CodeCoverage_Summary.xml`, or another workspace-confined
report path, and returns the authoritative stats without interpreting free-form console output.

### 4.8 Reviewable Git

`GetGitStatus` and `GetGitDiff` inspect the active project. `PreviewGitCommit` freezes the selected
message, paths, diff, and fingerprint without modifying the index. After review, `CommitChanges`
requires consent and creates a local commit only. Push, destructive reset, and file discard are not
exposed. See the [Git workflow guide](git_workflow.en.md).

### 4.9 Form Designer

RadIA can inspect the active form and components and prepare, apply, or revert component layout,
scalar properties, VCL component creation/removal, and event handlers. Sensitive properties and
unsupported object references are rejected.

### 4.10 Debugger

RadIA inspects debugger state, breakpoints, call stack, expressions, and watches. It can start,
pause, continue, step into, step over, step out, stop, and manage workspace breakpoints when IDE
state permits.

`GetDebugTimeline` accepts `sinceSequence` and `maxCount`, allowing chat, agent mode, and MCP to
consume only new events. RAD Studio notifications capture process launch, creation, state changes,
termination, breakpoint changes, and memory changes. The latest 500 events stay in memory, while a
JSON Lines audit trail is appended to `.radia/debug/timeline.jsonl` in the active project.

See the [Designer and debugger guide](user_guide_designer_debugger.en.md).

#### 4.10.1 Visual runtime regressions

After correcting a UI-dependent failure, RadIA can preserve its script under
`.radia/runtime-scenarios/<id>.json`. The artifact has a versioned schema and fingerprint and does
not store session-bound opaque IDs: every target needs a stable class, text, and path. Use
`parentPath` equal to `$root` for a root window.

The flow is `PrepareRuntimeRegression`, review, `SaveRuntimeRegression`, a user-controlled commit,
and, in a future debug session, `PrepareSavedRuntimeScenario` followed by `RunRuntimeScenario`.
Preparation and listing are read-only. Save and revert are reversible writes, while every scenario
execution requires fresh consent. An artifact changed without a matching fingerprint is rejected.

The complete build, new-session, reproduction, evidence, fix, verification, comparison, and
ten-replay workflow is documented in
[Autonomous Runtime Diagnostics](runtime_debug_automation.en.md). Evidence is comparable only for
the same project across distinct sessions and builds.

### 4.11 Inline review

Review findings are anchored to a file, hash, and line range. Suggestions remain visual until the
user decides. On the marked line, use the editor **Rad IA** submenu, `Ctrl+Alt+Enter` to accept, or
`Ctrl+Alt+R` to reject. Acceptance asks for confirmation, validates the base hash, and applies a
transactional patch; rejection removes the decoration without changing the buffer. Chat, agent
mode, and MCP can also prepare the preview before the decision. Stale reviews are never applied.

Reviews spanning more than 20 lines or 4,096 characters open in Smart Diff, where each block can be
accepted or rejected before application. Changes spanning multiple files use the multi-file
transaction and are never reduced to independent inline applications.

### 4.12 Local knowledge

RadIA indexes projects locally, searches symbols and excerpts, reports status, returns bounded
document content, and rebuilds derived data. Edit, save, rename, and close notifications update the
index incrementally.

See the [local knowledge guide](user_guide_project_knowledge.en.md).

### 4.13 MCP and extensions

`RadIA.MCP.Bridge.exe` exposes the same registry over stdio. Each IDE publishes
`%APPDATA%\RadIA\mcp.<pid>.json`, allowing clients to select the intended process. MCP calls keep
the same consent and workspace policies.

Trusted packages can add tools through the versioned `IRadIAToolExtension` API without bypassing
policy, audit, or cancellation.

Declarative commands, aliases, and workflows can be installed from
**Tools > Rad IA Extensions...** as a `*.radia.json` manifest or integrity-checked `.radiaext`
package. Workflows execute only internal tools through central policy and never interpret shell
code or binaries. The manager updates, enables, disables, diagnoses, and removes them without
restarting the IDE.

See the [MCP guide](mcp_integration_guide.en.md) and
[extension guide](tool_extension_guide.md), plus
[declarative extensions](declarative_extensions.en.md).

## 5. Slash commands

Type `/` to open the command menu. Main commands include:

- `/tools`, `/tool`, and `/revoke-tools`;
- `/explain`, `/refactor`, `/bugs`, and `/review`;
- `/doc`, `/stacktrace`, `/sqloptimize`, and `/scanwarnings`;
- `/createproject` and `/createprojectarch`;
- `/template` and custom commands.

See the [slash command reference](slash_commands.en.md).

## 6. Security and privacy

- Credentials are protected with DPAPI.
- Tools declare risk and mutating operations require consent.
- Paths are confined to the workspace.
- Sanitized audit data is stored at `%APPDATA%\RadIA\audit\tools.jsonl`.
- Rebuildable indexes are stored under `%APPDATA%\RadIA\Knowledge`.
- MCP uses a local named pipe.
- Shutdown cancels pending work and protects the WebView2 lifecycle.

See the [security model](tool_security_model.md) and
[compliance guide](compliance.en.md).

## 7. Compatibility

| IDE | Architecture | Status |
|---|---|---|
| Delphi 12 | Win32 | Supported and validated |
| Delphi 13 | Win32 | Supported and validated |
| Delphi 13 | IDE64 | Supported and validated |

## 8. Current version limitations

- Free-form prompts do not automatically start an autonomous tool loop.
- `/tools` is the authoritative runtime catalog.
- The [generated runtime catalog](runtime_tool_catalog.md) lists the 123 registered built-in tools.
- Runtime automation supports windowed VCL controls; controls without an `HWND` report unavailable
  capability.
- RadIA reproduces and verifies a correction, while the hypothesis and diff remain subject to user
  review and consent.
- Some architectural catalog entries remain roadmap items and may not appear in `/tools`.
- Debugger and Designer tools require valid IDE context and state.
- Patches are rejected after the buffer changes.
- RadIA does not provide destructive Git reset tools or arbitrary debugger executables.
- AI analysis does not replace compilation, tests, runtime leak detection, or human review.

## 9. Help and reference

Hover over fields and buttons to see contextual help. Settings hints explain format, effect, and
dependencies; chat buttons mention equivalent actions and shortcuts when available. Terminal
hints also document `Enter`, `Ctrl+R`, and `Ctrl+P`.

- [Everything RadIA can do](capabilities.en.md)
- [Installation](install_config.en.md)
- [Agentic tools](user_guide_agentic_tools.en.md)
- [What each tool does and when to use it](internal_tools_reference.md)
- [Internal tool catalog](runtime_tool_catalog.md)
- [MCP](mcp_integration_guide.en.md)
- [Local knowledge](user_guide_project_knowledge.en.md)
- [Designer and debugger](user_guide_designer_debugger.en.md)
- [Troubleshooting](troubleshooting_agentic_platform.en.md)
- [Agentic architecture](agentic_architecture.md)
- [Security](tool_security_model.md)
