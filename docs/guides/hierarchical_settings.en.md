# Project, session, and request settings

RadIA can use different providers, models, executors, and limits without changing global settings.
For example, you can keep a local model as the default, use OpenAI for one project, and set a lower
budget only for the next request.

## Where to open it

In the chat composer, select **Settings > Scope**. The dialog shows the effective value and source of
every field. Keyboard users can type `/scope`; `/status settings` shows the same state as text.

## Precedence

When the same field exists at multiple levels, RadIA uses this order:

1. next request;
2. current chat session;
3. active project;
4. global configuration;
5. RadIA safe default.

Fields inherit independently. A project can override only its provider while continuing to inherit
the global model, executor, timeout, and limits.

## Available fields

| Field | What it controls | Expected values |
|---|---|---|
| Provider | Service used by native chat and agent execution | Registered provider id such as `OpenAI` or `Gemini` |
| Model | Model sent to the native provider | Identifier accepted by the selected provider |
| Executor | Route used by the next message | `native`, `codex`, `claude`, `gemini`, or `copilot` |
| Maximum tokens | Native request output limit | Non-negative integer |
| Timeout (ms) | Native request or CLI execution timeout | Positive integer in milliseconds |
| Agent token budget | Total token budget for an agent run | Non-negative integer; `0` means no dedicated limit |

Credentials, tokens, and secrets cannot be overridden by these scopes. They remain in the secure
global provider or CLI configuration.

Without a timeout override, a native route uses the provider's global timeout, while a CLI route
keeps its 15-minute operational limit. `/scope` already displays the value for the effective route.

## Choosing a scope

- **Active project:** applies to every session for that `.dproj` file in this installation.
- **Current chat session:** applies only to the current conversation and wins over the project.
- **Next request only:** applies to the next successfully started execution in the current
  conversation and project, then is discarded; it never crosses into another session or workspace.

A project override requires an open project. A session override requires an active conversation. The
UI disables unavailable levels, while commands explain the required correction.

## Using the visual interface

1. Select **Settings > Scope**.
2. Choose **Active project**, **Current chat session**, or **Next request only**.
3. Edit only the required field and select **Apply**.
4. Check **Source** to identify the level supplying the effective value.
5. Select **Inherit** to remove one field override, or **Restore all inheritance** to clear the
   selected level.
6. To share configuration, select project or session and use **Export scope...**. The chosen file
   contains only known fields from that level, without the project path, credentials, or conversation
   content. Export never occurs automatically.

The composer route and model list refresh immediately; restarting Delphi is not required.

## Using commands

```text
/scope
/scope project provider OpenAI
/scope project model gpt-5.4
/scope session executor claude
/scope session timeout-ms 45000
/scope request max-tokens 2000
/scope request token-budget 12000
/scope project inherit model
/scope session clear
/status settings
```

General syntax:

```text
/scope <project|session|request> <field> <value>
/scope <project|session|request> inherit <field>
/scope <project|session|request> clear
```

Accepted fields are `provider`, `model`, `executor`, `max-tokens`, `timeout-ms`, and `token-budget`.
Unknown providers or executors, empty values, and invalid limits are rejected without changing the
previous scope.

## Persistence and security

Project and session overrides are stored outside the repository by default under
`%APPDATA%\RadIA\settings\scopes`. File names contain a hash of the scope identifier instead of the
original path. Writes are atomic and preserve fields introduced by future versions. RadIA never
overwrites a corrupted scope file; it reports the error so the user can inspect it.

Next-request overrides remain only in memory. These files never contain API keys, OAuth tokens,
prompt content, or conversation history.

## Diagnostics

- Use `/scope` to compare effective values and sources.
- Use `/status settings` for the same section inside RadIA diagnostics.
- Use `/status` to combine this state with provider, agent, CLI, MCP, editor, and project details.
- If an external CLI is unavailable, run `/doctor` and follow its action. RadIA does not silently
  fall back to the native executor.
