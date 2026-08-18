# Complete RadIA 2.17.3 user manual

> Use `/help` to compare Chat, Agent, CLI, and MCP. When a plan awaits approval, select
> **Approve plan** or type `/agent resume`.

## 1. What RadIA is

RadIA is an AI assistant integrated with Delphi 12 and 13. It combines multi-provider chat,
live IDE context, code generation and review, structured IDE tools, build, Form Designer, debugger,
local project knowledge, MCP access, consent, auditing, and workspace protection.

This manual is the recommended user entry point. Specialized guides linked throughout the document
provide deeper contract, security, development, and integration details.

For usage, architecture, quality, and release documentation, see the
[Documentation Center](../README.en.md).

## 2. Getting started

Type `/help` in chat for capabilities, primary commands, and guide links. Links open in the default
browser. Journeys started without every required value enter conversational intake and retain each
answer until execution or `/journey cancel`.

Direct questions such as “who are you?” or “what is FireDAC?” stay in Chat even while the Agent
button is enabled. They neither create a plan nor request approval. If Chat uses a CLI executor,
the question receives an isolated low-effort conversational run and does not inherit the previous
agent task session.

After installing the package for the intended IDE architecture, open Delphi and dock the RadIA
panel. Configure a provider under `Tools > Options > Rad IA`, select a model, create a session, and
send a prompt with `Ctrl + Enter`.

Docked or floating mode follows the native Delphi desktop. RadIA also records the actual visibility
and last floating geometry to preserve the user's choice when the IDE switches between named
layouts such as `Startup Layout` and `Debug Layout`. If the panel is closed before exiting, it
remains closed in the next session; use `Tools > RadIA > Chat` to open it again.

The chat panel caption and primary RadIA windows show the loaded version, for example
`Rad IA Chat v2.17.3`, so support can confirm the installed build quickly.

Supported credentials are protected locally with Windows DPAPI. Ollama and LM Studio can run
locally. See the [installation guide](../getting-started/install_config.en.md).

RadIA first requests the model list exposed by the configured account and endpoint. Only when
discovery fails does it show a minimal fallback catalog based on the provider's current stable
families. The discovered list always takes precedence because availability can vary by account,
region, plan, and permissions. ChatGPT OAuth/Codex transport models are kept separate from OpenAI
API models and are queried through the Codex App Server `model/list` method. If Codex CLI does not
respond, Rad IA keeps the current fallback models in the selector.

External links shown in responses open in the Windows default browser. The chat panel remains on
Rad IA's local page and is not used as a browser for those destinations.

When **Enable local token quota** is disabled, agent runs show `tokens (unlimited)` and are not
stopped by a local token budget. Account and provider limits remain independent.

### 2.1 Settings map

The settings window can be resized or maximized and keeps a safe minimum size to prevent controls
from being clipped.

| Tab | Purpose | When to change it |
|---|---|---|
| Providers | Credentials, login, endpoint, and provider-specific advanced options | When connecting or changing the AI service |
| System | System prompt applied to conversations | When permanent instructions are required |
| Templates | Reusable prompts and custom slash commands | When standardizing recurring tasks |
| General / Logs | Language, context, logs, and local token quota | When adjusting general behavior or diagnostics |
| Security & Consent | Risk approval, timeout, and session grants | Before allowing execution or mutations |
| Knowledge & Embeddings | Local knowledge, exclusions, and remote embeddings | When configuring project context retrieval |
| Editor Assistance | Ghost text, delay, exclusions, and shortcuts | When configuring editor suggestions |
| CLI & MCP | Native/external executor, portable executable, bridge, and external MCP servers | When using a CLI, exposing the IDE, or consuming a local MCP server |
| Memory Diagnostics | FastMM5 path and execution limits | When investigating leaks, double free, or use-after-free |

Every field and button provides a contextual hint. See the [security model](../reference/tool_security_model.en.md)
for security decisions and the [executor matrix](cli_executors.en.md) for native, CLI, and MCP
dependencies. The purpose, usage, dependencies, and care for every option are in the
[complete settings reference](../reference/settings_reference.en.md).

## 3. Enabling agent mode

An empty conversation starts with goals: understand the project, fix a problem, create something,
or debug an application. These actions only prepare the request. The same screen keeps code, build,
test, debugger, Form Designer, terminal, MCP, and skill capabilities visible. Users can start from
their intent without losing awareness of or access to the complete platform.

### 3.1 Agent Mode button and commands

The agentic infrastructure starts automatically when the RadIA package loads.

In the composer, **Mode: Chat** sends a regular conversation through the route selected under
**Executor**, inside **More**. **RadIA native** uses the selected provider without registered RadIA tools; a CLI sends
directly to the external process, which retains its own capabilities and policies. **Mode: Agent**
turns the next message into an agent objective and also uses **Send with**: **RadIA
native**, **Codex CLI**, **Claude Code**, **Gemini CLI**, or **GitHub Copilot CLI**. The selection
applies to the next message and is saved as the default. The `/agent`, `/agent on`, and `/agent off`
commands remain available.

For common use, users do not need to open **More** or understand every combination. A request that
clearly requires actions, such as creating a VCL project, is routed to the appropriate native
journey. **More** remains available for CLI sessions, journey links, and advanced configuration
overrides. **Settings > CLI & MCP > Chat executor** retains defaults and executable paths. Provider
authentication remains independent from the agent executor.

OpenAI offers two explicit credential paths. **OpenAI API via API Key** uses native HTTP transport and
API Platform billing. **ChatGPT Pro via Codex CLI** uses the ChatGPT/Codex account session and quota.
Both Codex routes share the same CLI login, but not the same orchestration: **RadIA native** keeps
control in RadIA, while **Codex CLI direct** delegates execution to the CLI.

The chat header displays the conversation's effective route. Examples include **Chat | OpenAI
native**, **Chat | RadIA native | ChatGPT Pro via Codex CLI**, **Agent | RadIA native | OpenAI**, and
**Agent | codex CLI direct**. The indicator represents the path actually in use. MCP
remains separate because it is a bridge for external clients, not the internal chat executor.
Each response repeats this identity in its header and uses a distinct avatar: the RadIA sparkle for
native transport, a terminal for CLI, and connected nodes for MCP. The **N**, **>_**, and **M** markers
and the adjacent name identify the effective route and credential path, such as **Native API**,
**ChatGPT Pro via Codex CLI**, or **Codex CLI direct**, so the distinction never depends only on color
or an icon.

### 3.2 Project, session, and next-request settings

The **Settings > Scope** button overrides provider, model, executor, and limits without changing the
global default. Select project, session, or next request, edit one field, and choose **Apply**. Every
row shows its effective source; **Inherit** removes only that override and **Restore all
inheritance** clears the selected level. `/scope` and `/status settings` expose the same information
from the keyboard. Routes and models refresh without restarting Delphi.

See [Project, session, and request settings](hierarchical_settings.en.md) for precedence, commands,
formats, persistence, and security.

Before sending, the composer footer shows the route, credential, and selected model when applicable.
While processing, the route avatar uses a subtle animation and the status text identifies whether
RadIA is preparing the response, running a tool, or processing its result. After completion, a
collapsible technical summary records the route, duration, and tools used. In agent mode, RTK savings
appear only when actual compaction metrics are present, in characters and percentage; RadIA does not
estimate or fabricate this value.

While a turn is active, write another instruction and use **+1** or `Ctrl + Enter` to queue it. The
visible queue holds five messages, lets you edit the next one or clear all, and sends one at a time
after completion. It is local to the panel and is not history yet. See [Chat and sessions](user_guide_chat_sessions.en.md).

Assistant responses, tool results, JSON arguments, and textual errors provide a copy action. It uses
the original returned content, preserving indentation and line breaks without including buttons,
titles, or other visual elements. Code blocks retain their dedicated copy action.

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
The [autonomous execution contract](autonomous_execution_contract.en.md) preserves file and operation
limits, completion criteria, build/test gates, and periodic summaries in the same checkpoint.
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
[local pricing catalog](../reference/agent_pricing.en.md).

During project creation, the execution center first presents a stable operational view: preparation,
structure review, file creation, opening in Delphi, build, and completion. The current stage remains
highlighted while work continues. The card explicitly states that DUnitX and other additions are not
created automatically and shows the expected result before execution finishes. Metrics, risks,
evidence, and arguments remain available under **Technical details** without dominating the primary
reading path. After a successful build, actions such as **Add DUnitX tests** only prepare a new
request; the user still reviews and sends that choice.

Open the integrated terminal with the **Terminal** (`>_`) button in the chat header or through
**Tools > RadIA > Rad IA Terminal**. All product commands are grouped in this submenu so RadIA
actions remain visually distinct from native Delphi commands.
`/terminal` command. Both paths open the same dockable terminal, supporting visual and
keyboard-driven workflows.

The screen model handles fragmented Unicode output, CJK, emoji, combining marks, resize reflow, and
common TUI operations. Graphics or mouse protocols may require an external terminal. See the full
[terminal reference](terminal.en.md).

Chat, terminal, and the context sent to editor actions can share a journey identity without
duplicating conversation history or terminal output. The **Journey** button links or detaches it
visually; `/context`, `/context new`, `/context detach`, and `/context switch <id>` provide the same
keyboard-driven operations. Switching is restricted to the active project. See the
[shared context guide](shared_journey_context.en.md).

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
Use `/journey dext-minimal` or `/journey dext-controllers` to create HTTP servers. The journeys turn
the endpoint list into a reviewable specification, generate a DEXT project, open it, and build the
result. See the [DEXT journey guide](user_guide_dext_journeys.en.md).
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

### 3.3 Consent

Read-only tools may run directly. Mutating and execution tools display their name, risk, and scope:

- **Allow once:** authorizes only the presented call;
- **Allow session:** authorizes compatible calls in the current session and scope;
- **Deny:** rejects without changing IDE state;
- **Cancel:** requests cooperative cancellation.

Session permission is not global. It is reused only by compatible tools with the same risk category,
origin, project, and scope. A structural grant may cover preview, creation, and opening for the same
project without repeating the dialog; it does not cover execution or destructive actions. Tools
marked for mandatory consent still prompt on every call.
Use `/revoke-tools` or **Revoke session permissions** to clear every active session grant.

Under **Settings > Security & Consent**, users can configure:

- consent dialog timeout from 15 to 600 seconds;
- whether tool arguments are shown;
- session permission for reversible writes;
- session permission for structural writes;
- session permission for builds, tests, and execution.

All three categories are enabled by default so **Allow session** is available. Users may disable
each category independently. Existing installations receive this new default once; subsequent
saved choices are preserved.

Under **Settings > Knowledge & Embeddings**, users can configure:

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
- Markdown and HTML conversation export with automatic redaction of known tokens and secrets.
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

`API.md` and mock units use a separate read-only preview before consented creation. Existing files
are never overwritten. See [safe API documentation and mocks](safe_productivity_tools.en.md).

Ghost Text captures bounded prefix and suffix without mutating the buffer. Ollama and LM Studio
receive a dedicated FIM request; other providers use an identified traditional fallback. Use
**Show Inline Completion Route Status** in the editor Rad IA submenu to see provider, model,
latency, and fallback reason. Configurable shortcuts still provide full acceptance, partial
acceptance, alternatives, and rejection. See the [complete FIM reference](inline_completion.en.md).

Changes prepared by the agent can also be reviewed block by block directly in the gutter. Each
marker can accept, reject, edit, or explain the change; navigation and application have configurable
shortcuts, and multi-file changes are written only after every block is resolved. See the
[complete block-review guide](block_reviews.en.md).

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

#### Creation profiles

When a project request does not mention additions, RadIA uses the `essential` profile: it creates
only the required files, opens the project, and builds it. The `complete` profile adds the DUnitX
project and its initial tests. The `custom` profile accepts `optionalFeatures`, currently including
`dunitx`. After the essential project builds, RadIA presents choices to keep the project as-is or
add features. No optional feature is created without an explicit user choice.

Throughout this flow, the RadIA panel remains open and presents creation, project-opening, and build
progress. A project transition must not hide chat or require users to reopen it.

In the composer's main row, **Effort** controls reasoning depth for compatible executors.
`Medium` is the balanced default; `Low` favors speed, while `High` and `Extra high` favor analysis.
The choice remains visible and is preserved when switching executors.

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

Use `CaptureRuntimeVisual` with an opaque ID returned by `GetRuntimeWindows`: `phase=before`
captures the window before the script and `phase=after` completes the before/after chat card. Every
capture is sensitive, requires its own consent, and remains only in memory for up to ten minutes.

The card receives each action start and finish, repetition, action kind, and final result directly
from the executor. Selectors, entered values, and control content are not displayed.

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

Declarative commands, skills, journeys, knowledge, references, templates, aliases, and workflows
can be installed from
**Tools > RadIA > Rad IA Extensions...** as a `*.radia.json` manifest or integrity-checked `.radiaext`
package. Workflows execute only internal tools through central policy and never interpret shell
code or binaries. **Addon Studio...** creates, sandboxes, installs, exports, and signs the package.
For shared content, select **Resources folder** and enter a relative **Content file** under
`references/`, `templates/`, or `knowledge/`. The manager updates, enables, disables, diagnoses,
and removes manifests and resources without restarting the IDE.

When editing a **Skill**, use **Publish skill to CLIs...** to select the four destinations, review
paths and conflicts, and publish with central consent. Updates use ownership hashes and preserve
manually changed files. See [Skill portability](skill_portability.en.md).

See the [MCP guide](mcp_integration_guide.en.md) and
[extension guide](../development/tool_extension_guide.en.md), plus
[declarative extensions](declarative_extensions.en.md).

## 5. Slash commands

Type `/` to open the command menu. Main commands include:

- `/doctor` for readiness, `/status` for sanitized inventory, and `/health` for the project;
- `/tools`, `/tool`, and `/revoke-tools`;
- `/explain`, `/refactor`, `/bugs`, and `/review`;
- `/doc`, `/stacktrace`, `/sqloptimize`, and `/scanwarnings`;
- `/createproject` and `/createprojectarch`;
- `/template` and custom commands.

See the [slash command reference](../reference/slash_commands.en.md).

## 6. Security and privacy

- Credentials are protected with DPAPI.
- Tools declare risk and mutating operations require consent.
- Paths are confined to the workspace.
- Sanitized audit data is stored at `%APPDATA%\RadIA\audit\tools.jsonl`.
- Rebuildable indexes are stored under `%APPDATA%\RadIA\Knowledge`.
- MCP uses a local named pipe.
- Shutdown cancels pending work and protects the WebView2 lifecycle.

See the [security model](../reference/tool_security_model.en.md) and
[compliance guide](../development/compliance.en.md).

## 7. Compatibility

| IDE | Architecture | Status |
|---|---|---|
| Delphi 12 | Win32 | Supported and validated |
| Delphi 13 | Win32 | Supported and validated |
| Delphi 13 | IDE64 | Supported and validated |

## 8. Current version limitations

- Free-form prompts do not automatically start an autonomous tool loop.
- `/tools` is the authoritative runtime catalog.
- The [generated runtime catalog](../reference/runtime_tool_catalog.en.md) lists the 213 registered built-in tools.
- The [thread and PPL assistant](threading_assistant.en.md) audits and prepares safe concurrency modernization.
- The [OpenAPI/Swagger retrofit](openapi_retrofit.en.md) integrates documentation into existing DEXT APIs.
- [DEXT and form modernization](dext_form_modernization.en.md) executes reversible, gated batches.
- [FireDAC Advisor](firedac_advisor.en.md) audits, previews, fixes, and migrates data access through gates.
- Runtime automation uses Win32 controls by default. VCL controls without an `HWND` require the
  reviewed Debug instrumentation, consent, a rebuild, and a new session; see the
  [runtime diagnostics guide](runtime_debug_automation.en.md#vcl-controls-without-an-hwnd).
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

- [Everything RadIA can do](../reference/capabilities.en.md)
- [Installation](../getting-started/install_config.en.md)
- [Agentic tools](user_guide_agentic_tools.en.md)
- [What each tool does and when to use it](../reference/internal_tools_reference.en.md)
- [Internal tool catalog](../reference/runtime_tool_catalog.en.md)
- [MCP](mcp_integration_guide.en.md)
- [Local knowledge](user_guide_project_knowledge.en.md)
- [Designer and debugger](user_guide_designer_debugger.en.md)
- [FireDAC Advisor](firedac_advisor.en.md)
- [Troubleshooting](troubleshooting_agentic_platform.en.md)
- [Agentic architecture](../development/agentic_architecture.en.md)
- [Security](../reference/tool_security_model.en.md)
