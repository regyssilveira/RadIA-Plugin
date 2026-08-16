# Agentive Tools Security Model

## 1. Objective

This model protects the user, the workspace and the `bds.exe` process against inappropriate actions,
ambiguous or executed with an outdated state.

Consent does not replace technical validation. Even an approved action must remain limited
to the stated scope and fails if its preconditions are not met.

## 2. Risk levels

|Level|Examples|Default policy|
|---|---|---|
|Read only|Read editor, project or messages|Allow|
|Reversible writing|Apply patch or insert text|Show diff and confirm|
|Structural writing|Change project, unit or form|Always confirm|
|Execution|Build, test or external process|Confirm by category|
|Destructive|Remove unit or component|Always confirm and highlight effect|
|Sensitive|Credentials, global configuration|Deny by default|

A sensitive tool can override the default denial only when its descriptor declares
`ConsentEveryTime`. In that case every call opens the dialog and `AllowSession` is never reused.

Tools federated by external MCP servers (names starting with `mcp.`) do not receive the automatic
read-only clearance. Because their risk level is declared by the configured grant rather than by
RadIA itself, the first call always opens the consent dialog. Choosing `AllowSession` keeps the
approval valid for the rest of the session.

## 3. Consent Decisions

- `AllowOnce`: only allows the current request.
- `AllowSession`: Allows the same tool and scope during the current session.
- `Deny`: refuses the request.
- `Cancel`: closes the flow that originated the request.

Session permissions:

- They do not survive restarting the IDE.
- They are not valid for another project.
- They do not expand paths or effects.
- They can be revoked by the UI.
- They do not automatically apply to destructive or sensitive actions.

### Central dialog and surfaces

Chat, native agent, MCP, and terminal use the same consent provider and native dialog, independently
of the panel that originated the call. The dialog shows a human-readable source, project, scope,
risk, and already-redacted arguments. Closing or undocking chat or terminal does not close a pending
request.

Only one dialog is active at a time. Concurrent requests wait in a queue bounded by the configured
timeout; IDE shutdown or an expired wait produces `Cancel`. No request is approved automatically.
Every button and the arguments area provide contextual hints.

## 4. Workspace boundary

Every file operation must:

1. Resolve the absolute path.
2. Determine the authorized root.
3. Reject parent traversal.
4. Inspect symlinks, junctions and reparse points.
5. Revalidate immediately before mutation.
6. Refuse paths outside the project without specific consent.
7. Never use `%USERPROFILE%`, volume root, or wide directory as an implicit scope.

IDE files and global settings are a separate scope of the project.

## 5. Mutation preconditions

An editor mutation must carry:

- Target file.
- Revision or read hash.
- Expected range.
- Original content expected.
- Proposed content.
- Encoding.
- Line ending.

The application must be refused when:

- The buffer has changed.
- The original excerpt does not exist.
- The excerpt appears ambiguous.
- The active file does not match the target.
- The project was closed.
- The IDE is closing.

## 6. External processes

Before starting a process, RadIA must show:

- Executable resolved.
- Arguments.
- Working directory.
- Operation category.
- Additional environment variables, with hidden secrets.

Mandatory controls:

- Child process associated with the session.
- Separate capture of stdout and stderr.
- Timeout.
- Process tree cancellation when safe.
- Limited work directory.
- Filtered environment.
- No shell commands when direct execution is possible.

## 7. Data protection

The writer must remove or mask:

- API keys.
- OAuth access and refresh tokens.
- AWS access keys and session tokens.
- Authorization headers.
- Cookies.
- Connection strings with password.
- Values ​​known by the credential store.

Sanitization must occur before:

- Audit.
- Error display.
- MCP response.
- Debug logs.

## 8. Audit

Each event must contain:

- Event ID.
- Correlation ID.
- Session.
- Date and duration.
- Tool and version.
- Project and scope.
- Risk.
- Sanitized arguments.
- Consent decision.
- End state.
- Affected files or resources.
- Sanitized error message.

End states:

- `Succeeded`
- `Denied`
- `Cancelled`
- `Failed`
- `PreconditionFailed`
- `Unsupported`

## 9. Local MCP

The MCP server must:

- Listen only locally.
- Prefer named pipe.
- Use ephemeral token when HTTP is required.
- Limit payload and competition.
- Reject requests during shutdown.
- Do not expose provider settings or credentials.
- Pass all calls through the same policy pipeline.
- Record the origin and logical identity of the client.
- Propagate `notifications/cancelled` to tools co-op tokens.
- Limit each connection to one in-flight call.
- Expose telemetry only as sanitized counters, without arguments, code, or credentials.

## 10. Form Designer and debugger

Designer mutations are structural and require confirmation.

Debugger control and application execution are classified as execution. Locals readings
may contain secrets and must be sanitized before reaching logs or external clients.

### 10.1. Local SQLite database

Inspection accepts only files inside the workspace. Queries use a read-only connection, row and
column bounds, consent on every execution, and redaction before grid and CSV rendering. DDL, DML,
compound statements, BLOB materialization, and SQLite runtimes outside the trusted Delphi
installation are rejected.

## 11. Fail safe

When in doubt, the operation must:

- Do not change status.
- Return structured error.
- Preserve current buffer.
- Release local objects.
- Only record sanitized data.
- Do not try alternative, more permissive paths.

## 12. Mandatory tests

- Denial without effect.
- Dialogue timeout.
- Session permission revocation.
- Path traversal.
- Junction/reparse point.
- Buffer modified after preview.
- Project closed during operation.
- Shutdown during request.
- Sanitization of each type of secret.
- External process cancelled.
- Success, failure and denial audit.
