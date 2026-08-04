# Agentic tools user guide

## Overview

RadIA can turn a chat request into structured Delphi IDE tool calls. Chat and MCP share the same
catalog, security policies, consent flow, and audit trail.

The **Agent On/Off** button in the chat header enables or blocks chat tool execution. The same state
can be changed with `/agent`, `/agent on`, or `/agent off`. Enter `/tools` to display the catalog and
`/tool <Name> {JSON}` to run a tool. Free-form prompts remain provider conversations and do not
automatically start an autonomous loop.

Use `/agent run <objective>` to start the autonomous loop. Before any tool runs, review the plan and
select **Approve plan**. The live card displays status, steps, tokens, and time and provides Pause,
Resume, and Cancel; the same controls are available through `/agent pause`, `/agent resume`, and
`/agent cancel`.

See the [tool catalog](tool_catalog.md) for tool names, parameters, and risk levels.
For a complete product overview, see the [Complete RadIA User Manual](user_manual.en.md).

## Operation flow

1. The user describes the intended outcome.
2. RadIA selects a tool compatible with the current IDE context.
3. Read operations run inside the authorized workspace.
4. Mutating operations show their scope, risk, and summary before execution.
5. Reviewable changes show a preview and validate their preconditions.
6. A structured result or error is returned to chat.
7. The decision and execution are written to the sanitized audit trail.

## Consent

- **Allow once:** allows only the presented operation.
- **Allow session:** reuses the decision only for the same session, project, tool, and scope.
- **Deny:** rejects the operation without changing the IDE or workspace.
- **Cancel:** requests cancellation of an operation in progress.

Authorization is not global. A different project, tool, scope, or risk may require new consent.
Destructive operations never reuse a lower-risk permission.

## Reads and mutations

Read tools inspect the editor, project, build, debugger, Designer, and local knowledge without
changing state. Mutating tools can:

- prepare, apply, and revert editor patches;
- add or remove project items;
- start or cancel builds;
- change Designer components, properties, events, and layout;
- control execution, breakpoints, and watches in the debugger.

Patches verify the file, original text, and base hash. If the document changed after preview, RadIA
rejects the application and requires a new preview.

## Example requests

- “List the project units and identify circular dependencies.”
- “Prepare a patch to extract this method, but do not apply it yet.”
- “Build the active project and summarize errors and warnings.”
- “Show the components in the active form.”
- “Add a breakpoint on this line and show the debugger state.”
- “Find where `IRadIAToolRegistry` is implemented in this project.”

If a required project, file, form, or debug session is missing, the tool fails safely and reports
the missing precondition.

## Audit and privacy

The audit trail is stored at `%APPDATA%\RadIA\audit\tools.jsonl`. Credentials and sensitive fields
are sanitized before writing. For risk and workspace confinement details, see the
[security model](tool_security_model.md).
