# Agentic Form Designer and debugger guide

## Event-driven timeline

`GetDebugTimeline` records Open Tools API notifications instead of continuously polling the
debugger. Pass the last received `sequence` as `sinceSequence` to retrieve only new events. Each
item contains its UTC timestamp, kind, process, state, and details. A persistent JSON Lines trail
is stored at `.radia/debug/timeline.jsonl` in the active project.

## Form Designer

Designer tools operate on the active form. They can inspect components, properties, events, and
layout and prepare reviewable mutations.

Examples:

- “List the components and hierarchy of this form.”
- “Show the published properties of this button.”
- “Prepare a `Caption` change without applying it.”
- “Bind this event to an existing method.”
- “Align the selected components and show a preview.”

A mutation validates the form, component, and base value. RadIA rejects the operation if the
Designer changed after preview. Changes run on the IDE main thread and require consent.

## Debugger

Debugger tools inspect state, process, thread, current location, breakpoints, expressions, and
watches. Control tools can start, continue, pause, or stop a session when IDE state permits.

Examples:

- “Show the current debugger state.”
- “Add a breakpoint on the current line.”
- “Evaluate `LResult` in the current frame.”
- “Add `FClient.Connected` to watches.”
- “Continue execution.”

Evaluation requires a paused process and valid context. Continue requires an active session, and
some breakpoint changes are unavailable during debugger transitions.

### Advanced breakpoints in Delphi 12 and 13

Before configuring an advanced breakpoint, RadIA runs
`GetAdvancedBreakpointCapabilities`. The effective matrix for both supported Delphi versions is:

| Capability | Status | Notes |
|---|---|---|
| Condition | Available | Uses the IDE breakpoint's native expression. |
| Hit count | Available | `0` disables it; positive values use the native counter. |
| Logpoint | Available | Can log a message, expression, result, and frames without stopping when `break=false`. |
| Thread condition | Available | Accepts the identifier or name recognized by the debugger. |
| Global exception filters | Unavailable | OTA exposes no reliable global API; RadIA reports the limitation and does not simulate it. |

Create a breakpoint with `AddBreakpoint` first. Then ask in natural language, for example:

- “Stop here only when `OrderId = 42`.”
- “Skip the first four hits and stop on the fifth.”
- “Log `Customer.Name` and four frames without stopping.”

`ConfigureBreakpoint` changes only requested fields, preserves the others, and returns
`previousConfiguration`, `inverseTool`, and `inverseArguments`. The same tool can therefore restore
the previous configuration after new consent. `ListBreakpoints` shows effective conditions, counters,
log actions, and thread filters.

## Safety

Control and mutation commands require consent. Results are bounded and sanitized, OTA failures are
reported safely, and shutdown cancels pending requests. Always confirm the structured result and
the resulting IDE state.
