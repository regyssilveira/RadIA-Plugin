# Native orchestration and executors via CLI

RadIA offers two independent choices: **agent orchestration** and **provider authentication
transport**. In the composer, select **Mode: Agent** and choose the executor under **Send with**. The
choice applies to the next message, is persisted as the default, and does not require restarting the
IDE. **Settings > CLI & MCP > Chat executor** keeps paths, diagnostics, and the same default.

- **RadIA native orchestration** runs the loop, tools, consents and checkpoints
within RadIA. It does not silently switch to an external executor.
- **External CLI orchestration** delivers the objective directly to the selected CLI.
- **Mode: Chat** sends a conversation through the selected route. Native mode does not use registered
  RadIA tools; an external CLI retains its own capabilities. **Mode: Agent** sends an objective to
  the executor selected under **Send with**. Neither option changes provider authentication.

API-key providers and local providers work without a CLI. **ChatGPT Pro via Codex CLI** is an explicit
exception: Codex CLI is the provider transport even when orchestration is native. The CLI login is
shared; choosing direct CLI changes orchestration, not the account. To operate without CLIs, use an API key or another
provider that offers native HTTP or local transport.

## Supported profiles

|Executor|Non-interactive mode|Requested output|
|---|---|---|
|Codex CLI|`exec`|JSONL|
|Claude Code|`-p`|Streaming JSON|
|Gemini CLI|`-p`|Streaming JSON|
|GitHub Copilot CLI|`-p`|JSONL|

RadIA keeps arguments separate until process creation and applies argument escaping
of Windows only at the execution boundary. The prompt is not concatenated to a shell command.

The [contractual capability matrix](cli_capability_matrix.en.md) separates vendor-published
features from behavior already used by the current RadIA version. ID resume is used for all four
supported executors. FIM remains conditional on an executor-specific contract.

## Optional installation via the official channel

In **Settings > CLI & MCP**, the **Install channel** or **Update channel** button displays the
complete command and
the prerequisites before requesting confirmation. After approval, the installation runs outside the
IDE thread, shows stdout and stderr on the panel and has timeout and tree closure
processes. This channel is optional: the **Browse...** button allows you to select a `.exe`, `.cmd` or
`.bat` already exists. In this case, Node.js and npm are not required for RadIA to use the executable.

|Executor|Channel used by Rad IA|Official package|
|---|---|---|
|Codex CLI|npm when available; WinGet without npm|`@openai/codex` / `OpenAI.Codex`|
|Claude Code|npm when available; WinGet without npm|`@anthropic-ai/claude-code` / `Anthropic.ClaudeCode`|
|Gemini CLI|npm|`@google/gemini-cli`|
|GitHub Copilot CLI|WinGet|`GitHub.Copilot`|

**Install/Update** selects the channel automatically. When npm is available, RadIA keeps the npm
flow. Without npm, Codex and Claude use their official WinGet packages, while Copilot continues to
use WinGet. Every command is displayed and requires consent before execution. Gemini CLI still
requires Node.js on Windows through its official channel; RadIA explains this limitation, offers the
guided prerequisite installation, and keeps **Browse** available for an existing installation.

RadIA does not copy a CLI into the plugin directory. With npm, the command is commonly placed under
`%APPDATA%\npm`. WinGet manages packages under `%LOCALAPPDATA%\Microsoft\WinGet\Packages` and
typically exposes command links under `%LOCALAPPDATA%\Microsoft\WinGet\Links`. A path selected with
**Browse** stays in its original location; RadIA only stores and uses that path.

Without an open Delphi project, CLI conversations and agents remain available in a private workspace
under the RadIA data directory (`RadIA\cli-workspace`). This allows Agent mode to create a new VCL
project from scratch. After a project is created or opened, new executions use its actual directory.
Only tools that genuinely depend on an existing project, such as build, debug, and tests, report that
prerequisite when invoked.

Identifiers come from an internal catalog and are validated against metacharacters before
execution. Rad IA does not download, package, or redistribute binaries from these vendors. Authentication
continues to be done by the CLI itself after installation.

### Guided installation and recovery wizard

Before executing any command, RadIA checks the manager required by the official channel. Se
an npm-based CLI does not find Node.js/npm, it offers to install Node.js LTS by `winget`
as an independent step, showing the command and asking for consent. The CLI installation has
a second confirmation. If `winget` also does not exist, no blind attempt is made: RadIA opens
the official page and shows the necessary action.

**Manual steps** copies and displays the official URL, full command, expected executable names, and
the alternative of selecting a portable `.exe`, `.cmd` or `.bat`. **Start login** opens the command
client authentication on a visible terminal; when closing this terminal, the version and
authentication is repeated automatically.

After installing, the resolver searches `PATH` as well as known npm, Node.js, and
WinGet. Thus, a newly installed executable can be used by the current IDE without restarting Delphi. THE
installation button becomes **Cancel** during a step in progress.

When Codex CLI is not found or cannot be started, diagnostics and chat show the
resolved path and the expected npm global path, typically
`%APPDATA%\npm\codex.cmd`. Use **Browse...** to select another accessible executable. The executable
internal codex app distributed through the Microsoft Store may remain protected by Windows.

MCP installations, upgrades, and connections/repairs only write sanitized metadata to
`%USERPROFILE%\RadIA\cli-mcp-setup-history.jsonl`; authentication commands, tokens, and raw output do not
are persisted.

## Detection and installed version

When opening the **CLI & MCP** panel, changing the client or using **Diagnose**, RadIA first looks for the
configured path and then `PATH` from Windows. Diagnostics, ChatGPT Pro and external execution
use the same resolver and therefore the same effective path. When it finds the executable, it calls
`--version` in the background, with a timeout of ten seconds, and displays on the screen itself:

- name and version informed by the CLI;
- path actually used;
- diagnostic failure, without preventing configuration or updating.

A delayed response is discarded if the user switches clients during the check. That
diagnostics does not authenticate, does not change files, and does not start an agent session. Login continues
being controlled by the CLI itself.

Chat repeats this resolution before sending whenever the effective route depends on a CLI. If the
executable is absent, the message is neither sent nor discarded: RadIA explains the dependency,
keeps the text in the composer, and offers Settings and `/doctor`. Users may point **Browse** to a
portable executable; installing Node.js/npm is only an option for npm channels, never a condition
for using RadIA or a portable CLI.

### Authentication diagnostics

After release, RadIA runs a read-only probe when the vendor makes a
stable non-interactive command:

|Executor|automatic probe|Login guidance|
|---|---|---|
|Codex CLI|`codex login status`|`codex login`|
|Claude Code|`claude auth status`|`claude auth login`|
|Gemini CLI|Not available|start `gemini` and use `/auth`|
|GitHub Copilot CLI|Not available|`copilot login`|

The dashboard shows **authentication: ready** when the probe ends successfully. Otherwise,
shows **authentication: required** and the correction command. For customers without an official probe,
the status is presented as a manual check, without trying to infer login from the existence of
files or environment variables.

## Selection and security

- **RadIA native orchestration** remains the default and uses the tools, consents and checkpoints
internal.
- **External CLI orchestration** uses the client chosen in the same panel and the detected or configured path.
- An unknown identifier or corrupted configuration is automatically returned to the agent
native.
- The selection does not enable automatic approval options for CLIs.
- MCP continues to be provisioned and diagnosed separately.

This configuration establishes the profiles and persistent preference used by the described transport
next.

## Chat-integrated execution

In the native agent, the chat selector displays the models made available by the active provider. To the
save a provider or executor change, RadIA reloads this list asynchronously and applies
the change immediately, without restarting Delphi. Delayed responses from the previous provider are
discarded.

In the external executor, the model is managed by the CLI itself. Because supported clients do not
offer a uniform and stable contract to discover and select models, the chat selector is
disabled and reports **Model managed by <CLI>**. Configure the model through CLI mechanisms
chosen; When returning to the native agent, the selector returns to using the provider's models.

When **External CLI orchestration** is active and there is a Delphi project open, agent mode forwards the
target to CLI detected using project folder as working directory. The process:

- runs outside the interface thread;
- captures stdout and stderr incrementally, with memory limit;
- normalizes the final JSON or JSONL response to the conversation;
- has a 15-minute timeout;
- enters a Windows Job Object;
- terminates the entire process tree when canceling, timeout or closing RadIA.

### External conversation continuity

Each RadIA conversation keeps its own link to a CLI conversation. After a successful run, RadIA
captures the structured identifier returned by the client and stores only the executor, external
identifier, project directory, and declared model. Tokens, credentials, prompts, and raw output are
not part of this index.

On the next request, RadIA resumes automatically only when the executor and project directory still
match the link. Switching RadIA conversations also isolates the external session. A response that
finishes after that switch is saved to the conversation that started it and is not inserted into the
conversation currently visible.

- **Session: Resume** confirms that the next request will reuse the link.
- **Session: New** means that the CLI will start a new conversation.
- Use **New CLI session** or `/cli new` to detach the current external conversation.
- Use `/cli session` to inspect the linked identifier and executor.
- Creating another conversation with **New chat** creates an independent scope; returning to the
  previous conversation restores its own link.

Detaching ends continuity in RadIA but does not erase data retained by the CLI vendor. There is no
universal remote deletion operation, so any such removal must use that client's own mechanisms.

If the executable is not available, RadIA does not start a partial execution: it reports the
problem and directs the user to diagnosis in **CLI & MCP**. The selection can be changed to the
native agent and applies to the next request, without restarting the IDE.

## Configuration scenarios

|Scenario|Settings|Does it require Node.js/npm on Windows?|
|---|---|---|
|Native agent with API key|Native orchestration + API provider|No|
|Native agent with local provider|Native orchestration + Ollama/LM Studio|No|
|ChatGPT Pro|Any orchestration + Codex CLI path|No, if an existing executable is selected|
|External agent|External orchestration + CLI selected|No, if an existing executable is selected|
|Guided installation of Codex/Claude/Gemini|Optional installation channel|Yes|

CLIs installed only within WSL do not appear in Windows `PATH` and are not treated as a
`codex.exe` native. Until a dedicated WSL executor exists, use a Windows executable pointed to by
override field or select a provider that does not depend on CLI.

The dockable terminal reuses the same transport, streaming, timeout and cascade cancellation.
See [Terminal](terminal.en.md).
