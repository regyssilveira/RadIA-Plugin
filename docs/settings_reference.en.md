# Complete settings reference

This is the searchable source of truth for **Tools > Options > Rad IA**. Use `Ctrl+F` with the exact
tab, field, or button text. Secrets are stored with Windows DPAPI and must never be placed in prompts,
templates, logs, or screenshots. Saving provider settings refreshes models without restarting Delphi.

## Providers

| Option | When to use | Effect and care |
|---|---|---|
| API Key / Get API Key | To connect a cloud provider | The key authenticates calls and is DPAPI-protected; the link opens the official provider page. Billing remains with the provider. |
| Connection Method | To choose **API Key (BYOK)** or **ChatGPT Pro via Codex CLI** | API key uses HTTP and API Platform billing. ChatGPT Pro uses the Codex CLI session and quota, including with RadIA native orchestration. Legacy OAuth settings migrate automatically. |
| Configure Codex CLI login | Before using ChatGPT Pro | Opens Codex under **CLI & MCP**, where **Start login**, **Logout**, and **Diagnose** control and verify the shared session. |
| Sign In / Sign Out | To start or end a supported web session | Uses the provider's official authorization flow and updates the local session. |
| Custom Base URL | Only for an OpenAI-compatible endpoint | Empty uses OpenAI. Include `/v1` when required. Do not send secrets to an untrusted endpoint. |
| Server URL | For Ollama or LM Studio | Enter scheme, host, and port. Use HTTP only on loopback or trusted networks. These providers need no cloud key or CLI. |
| Temperature | To control output variation | Lower is more deterministic. Smart Parameters can manage this value. |
| Max Output Tokens | To cap one response | It is neither the total context window nor a billing cap. |
| Timeout | To bound provider waiting | Cancels local waiting and does not alter remote limits. |
| GitHub User Token | When an existing Copilot token is available | Stored with DPAPI; use only the current user's token. |
| Connect GitHub Account | To use GitHub device flow | Opens official authorization and stores the resulting token. |
| Import from VS Code | When VS Code already has compatible credentials | Imports without modifying VS Code settings. |
| Azure Endpoint / Deployment / API Version | When using Azure OpenAI | Use the full resource URL, the Azure deployment name, and a version supported by that resource. |
| AWS Access Key / Secret / Session Token / Region | When using Bedrock | Use least privilege. Session token is required for temporary credentials; region must expose the model. |
| IAM Console | To inspect AWS permissions | Opens AWS; RadIA never changes IAM policies. |

Claude, DeepSeek, Groq, OpenRouter, Alibaba Qwen, and Mistral use their API key and the common
advanced settings above. Provider account, region, plan, and permissions determine model availability.

## General / Logs

| Option | When to use | Effect and care |
|---|---|---|
| Auto (Smart Parameters) | Recommended by default | Chooses provider parameters that were not explicitly set. |
| Inject Delphi version in prompt | For version-sensitive code | Adds the active Delphi version to reduce incompatible output. |
| Prefer concise AI responses | For shorter defaults | Explicit requests can still ask for details. |
| Enable logging | While diagnosing a problem | Writes sanitized local diagnostics. |
| Log Folder Path / `...` | To select log storage | Choose a writable folder not shared with untrusted users. |
| Max Log File Size | To control disk use | Limits logs, not model responses. |
| Enable local token quota | To track a local monthly budget | When disabled, the agent has no local per-run token budget. Provider limits still apply. |
| Monthly Token Limit / Used Tokens | To configure and inspect local tracking | Usage is an estimate and may differ from provider accounting. |
| Reset Usage | To restart local tracking | Resets only the local counter. |
| Agent result compaction profile | To balance savings and diagnosis | `Conservative` is the default; `Balanced` reduces older-step budgets further; `Off` restores complete context. It does not alter checkpoints or tool results. |
| Maximum agent decision context characters | When the model window or journey requires a different limit | Accepts 16,000–1,000,000; default 120,000. Omitted content remains recoverable through result tools. |

## Security & Consent

| Option | When to use | Effect and care |
|---|---|---|
| Consent dialog timeout | To adjust decision time | Accepts 15–600 seconds. Expiration cancels and never approves. |
| Show tool arguments | Recommended for review | Shows sanitized JSON before approval. |
| Session permission for reversible writes | During trusted repeated edits | Offers scoped **Allow session** for compatible reversible operations. |
| Session permission for structural writes | Only for a trusted structural task | Disabled by default because it covers project structure. |
| Session permission for build/tests/execution | For repeated validation | Never bypasses auditing, limits, or workspace boundaries. |
| Revoke session permissions | After a task or when scope is uncertain | Immediately clears remembered permissions for the current IDE session. |

## Knowledge & Embeddings

| Option | When to use | Effect and care |
|---|---|---|
| Enable local semantic project knowledge | For semantic project search | Builds a reconstructable local index without network access. |
| Include approved run summaries | To recover approved decisions | Includes summaries only, never tool arguments or results. |
| Excluded file/project fragments | To omit sensitive, generated, or third-party areas | Semicolon-separated name or path fragments. |
| Use a remote embedding provider | When remote vectors are required | Sends nothing until separate consent and valid settings exist. |
| Consent to sending bounded project text | After reviewing endpoint and policy | Authorizes bounded transmission and can be revoked by clearing it. |
| Embedding endpoint / model / API key | To configure remote embeddings | HTTPS or loopback HTTP only; the key is DPAPI-protected. |
| Dimensions / timeout / maximum input | For compatibility and bounds | Dimension must match the model; timeout bounds waiting; input bounds sent text. |

## Editor Assistance

| Option | When to use | Effect and care |
|---|---|---|
| Enable ghost text (inline completion) | For suggestions while editing | Sends bounded context to the configured inline provider/model or, when empty, the active global provider/model. Uses dedicated FIM by capability and explicit fallback otherwise. |
| Idle delay | To balance speed and request volume | Accepts 250–5000 ms; lower requests earlier. |
| Excluded languages/files/projects | To suppress inline requests | Semicolon-separated language, name, or path fragments. |
| RadIA shortcuts | To customize keyboard access | Use semicolon-separated `action=shortcut` entries for `request`, `accept`, `nextWord`, `alternative`, `reject`, and `terminal`; conflicts are validated. |
| Show Inline Completion Route Status | To understand the latest request | In the editor Rad IA menu or Tools, reports route, provider, model, latency, and fallback reason without exposing code. |

See the [security model](tool_security_model.en.md) for risk classes and consent scope.

## CLI & MCP

CLI and MCP are independent. Native orchestration needs no CLI for API-key or local providers. MCP
allows an external client to use RadIA's protected tool registry.
The **CLI & MCP** and **External CLI clients** parent nodes show guidance only. Use **Chat
Orchestration** to choose native or external CLI execution, a specific client to configure its
installation, or **MCP Connection** to configure MCP connectivity only.

| Option | When to use | Effect and care |
|---|---|---|
| Chat executor | To choose native or external orchestration | Native uses RadIA; external delegates the objective to the selected CLI. |
| CLI client | To diagnose, install, or use an external CLI | Selects Codex, Claude, Gemini, or Copilot and its MCP profile. |
| CLI executable override | For a portable CLI or one outside PATH | Full `.exe`, `.cmd`, or `.bat` path shared by diagnosis and execution. |
| Browse | To select an existing CLI | A self-contained executable does not require Node.js/npm. |
| Diagnose | After install, path selection, or login | Resolves path, version, and authentication when supported. |
| Install/Update channel | When no usable executable exists | Shows official package, command, and prerequisites and runs only after confirmation. |
| Manual steps | When automation is not wanted or failed | Copies the official URL, complete command, expected names, and portable alternative. |
| Start login | After detection and before authenticated use | Opens a visible login terminal and repeats diagnosis when it closes. |
| MCP client configuration | For advanced path override | Full JSON/TOML path; the client default is detected automatically. |
| RadIA MCP bridge | Only after moving or repairing installation | Installed beside the BPL; no separate bridge download is required. |
| Preview | Before connecting | Shows proposed content without writing. |
| Connect / Repair | To add or fix the managed entry | Confirms, backs up to `.radia.bak`, writes, verifies, and restores on failure. |
| Disconnect | To remove integration | Removes only the RadIA-managed entry. |
| Test Handshake | After connecting | Runs `initialize`, `ping`, and `tools/list` without changing the project. |

The **MCP connection** block is explicitly independent from the chat executor. Sanitized setup and
repair history is stored at `%USERPROFILE%\RadIA\cli-mcp-setup-history.jsonl`.

### Guided flow and recovery

| Situation | What RadIA does | How to continue |
|---|---|---|
| Everything is configured | Detects path, version, and available authentication; installs nothing. | Use the executor or test the MCP handshake. |
| CLI is missing | Offers the official channel after showing command, source, and prerequisites. | Approve it or use **Browse...** for an existing executable. |
| Node.js/npm is missing | Offers Node.js LTS through WinGet under separate consent. | After success, RadIA revalidates and offers the CLI installation. |
| User declines | Makes no change. | Use **Manual steps**, **Browse...**, or keep native orchestration. |
| Installation fails | Shows actionable guidance, keeps output visible, and stores sanitized metadata. | Fix the reported cause, run **Diagnose**, and resume. |
| Manual installation | Searches override, `PATH`, npm, Node.js, and WinGet links. | Click **Diagnose**; Delphi does not need a restart. |
| MCP configuration is invalid | Does not overwrite the file and disables writes. | Fix the indicated file and create a new **Preview**. |
| First MCP setup | Shows a preview, requests consent, backs up, verifies, and enables handshake. | Run **Connect / Repair**, then **Test Handshake**. |

Cancelling or declining leaves the environment unchanged and keeps a visible alternative.

See [native and CLI executors](cli_executors.en.md) and [MCP integration](mcp_integration_guide.en.md).

## Effective settings by scope

The **Settings > Scope** button is in the chat composer rather than the global options window. It can
override provider, model, executor, maximum tokens, timeout, and agent budget for the active project,
current session, or next request only. Every row exposes **Source**, **Apply**, and **Inherit**;
**Restore all inheritance** clears the selected level. Credentials remain global.
**Export scope...** writes a sanitized project or session JSON only after explicit user selection;
the project path and secrets are excluded.

The same controls are available through `/scope`, while `/status settings` verifies the result. The
model list and effective route refresh without restarting Delphi. See
[Project, session, and request settings](hierarchical_settings.en.md) for precedence, formats,
persistence, and recovery.

## Memory Diagnostics

| Option | When to use | Effect and care |
|---|---|---|
| FastMM5 root / Browse | For dynamic memory investigation | Select the user-supplied directory containing `FastMM5.pas`; RadIA does not download or redistribute it. |
| License confirmation | Before using FastMM5 | Confirms that the user supplied it under its own license. |
| Validate installation | After selecting the root | Checks the layout without modifying the active project. |

See the [FastMM5 memory diagnostics plan and guide](fastmm5_memory_diagnostics_plan.en.md).

## System

**System Prompt** supplies stable instructions to new conversations. Use it for language,
architecture, or lasting constraints. Keep secrets and temporary task details out of it.

## Templates

| Option | When to use | Effect and care |
|---|---|---|
| New / Delete | To create or remove a reusable prompt | Deletion asks for confirmation; defaults can be restored. |
| Name / Description | To identify purpose and expected output | Use a unique name and actionable description. |
| Slash Command | To invoke the template in chat | Must start with `/`, be unique, and not collide with built-ins. |
| Template | To define reusable content | Placeholders are allowed; secrets are not. |
| Generate Complete Project | For multi-file output | Enables project-generation review handling. |
| Save Template | After reviewing content | Validates and persists it. |
| Export / Import | For backup or controlled sharing | Review imported content; merge preserves existing entries. |
| Restore Defaults | To recover distributed templates | Overwrites changed defaults after confirmation. |

For guided usage, return to the [user manual](user_manual.en.md). For scoped overrides, see
[project, session, and request settings](hierarchical_settings.en.md). For failures, use
[troubleshooting](troubleshooting_agentic_platform.en.md).
