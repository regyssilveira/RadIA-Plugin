# Corporate security brief

This brief describes RadIA behavior. Retention, training, residency, and deletion policies of the selected
service belong to the vendor or organization-operated infrastructure and require contractual verification.

## Data-flow matrix by route

| Route | Destination and data | Local storage | RadIA guarantee | External boundary |
|---|---|---|---|---|
| Native remote provider | HTTPS API; prompt, bounded history, and authorized context | settings, DPAPI credential, sanitized audit | consent, redaction, and limits before transmission | provider retention, training, residency, logs, and deletion |
| Compatible endpoint | user-defined HTTPS URL; native envelope | same local data as native route | URL validation and policy; no key copied to telemetry | endpoint identity, operation, and policy |
| External CLI | local process that can call its own services; objective and context | executor, external ID, project, and model; no token, prompt, or raw output in the link | bounded directory, timeout, cancellation, and output | CLI authentication, history, telemetry, and deletion |
| Local/external MCP | configured server; authorized call arguments | protected configuration and sanitized audit | central policy, consent, payload limit, and cancellation | MCP server data handling |
| Local provider | local/internal process or endpoint; prompt and context | local indexes, settings, and audit | no cloud-provider request initiated on this route | another machine still means internal network traffic |

## Storage, retention, and deletion

- credentials use Windows-user DPAPI and Registry storage;
- sanitized audit is stored at `%APPDATA%\RadIA\audit\tools.jsonl`;
- rebuildable indexes are stored at `%APPDATA%\RadIA\Knowledge`;
- approved history enters knowledge only when its explicit option is enabled;
- previews, checkpoints, evidence, and captures follow their specific guide limits.

RadIA promises no single corporate retention period. The organization defines retention, backup, and disposal.
Close every IDE before deleting local artifacts and preserve mandatory evidence. Credential deletion also
requires provider revocation. Unlinking a CLI session does not delete CLI-held data.

## Credentials, audit, and telemetry

Redaction masks API keys, OAuth/AWS tokens, authorization headers, cookies, and password-bearing connection
strings before audit, logs, and MCP responses. Audit records correlation, origin, tool, risk, decision, state,
and affected resources with sanitized arguments and errors.

RadIA sends no product telemetry containing code, prompts, or credentials. Sanitized counters may exist
locally. Providers, CLIs, endpoints, and MCP servers may have their own telemetry; RadIA cannot universally
disable or audit it.

Intent routing keeps only local recommendation and decision counters in
`%LOCALAPPDATA%\RadIA\Telemetry\intent-routing.jsonl`. Records contain the event, intent, confidence,
and UTC date; the API cannot accept prompts, code, commands, projects, providers, models, or
credentials. Values outside the allowlists become `Unknown`. Use `/status intent` to inspect the
sanitized aggregate.

## Approval checklist

1. Classify code and choose a permitted route.
2. Verify destination contract, region, retention, training, and deletion.
3. Use least privilege and define credential rotation and revocation.
4. Define retention and disposal for audit, knowledge, checkpoints, and evidence.
5. Validate consent, confinement, redaction, and incident response.

See [Security model](tool_security_model.en.md), [Compliance](../development/compliance.en.md),
[CLI executors](../guides/cli_executors.en.md), and [MCP integration](../guides/mcp_integration_guide.en.md).
