# M1 — Debugger correlation and waiting

> **Status:** implementation complete; in-IDE validation pending.
> **Goal:** [Autonomous runtime failure reproduction](runtime_debug_automation_plan.en.md).

## Deliveries

- thread-safe runtime session, process, and event coordinator;
- identity by session, real Windows PID, creation time, project, executable, and build;
- build fingerprint formed from the launched executable size and UTC timestamp;
- immediate wait invalidation when a new session begins;
- condition-based waiting without polling, with a five-minute maximum timeout;
- immediate cancellation by command, agent, or MCP request;
- structured call stack capture for stopped and exception events;
- `IOTADebuggerNotifier` integration;
- bounded retention of the latest 500 runtime events.

## Tools

| Tool | Use |
|---|---|
| `GetRuntimeDebugSession` | Confirm the correlated identity and latest sequence. |
| `WaitForDebuggerEvent` | Wait for running, stopped, exception, exit, or window events. |
| `CancelDebuggerWait` | Explicitly cancel the active wait. |

`WaitForDebuggerEvent` also receives the common cancellation token. Cancelling the agent or an MCP
request therefore wakes the wait immediately without requiring a second call.

## Observed states

| OTA state | Runtime event |
|---|---|
| `psRunning` | `running` |
| `psStopped` | `stopped` |
| `psException`, `psFault`, `psResFault` | `exception` |
| `psTerminated`, `psNoProcess` | `processExited` |

A stop is not automatically labelled as a breakpoint because OTA does not expose a reliable origin
in this callback. The stack and state are returned without inventing that distinction.

## Automated evidence

- an incomplete session cannot be used;
- a stale session cannot attach a process;
- changing the session invalidates a wait;
- timeout uses a condition without busy-wait;
- direct cancellation wakes the wait;
- common contract cancellation interrupts the tool;
- an exception returns PID, details, and a structured stack;
- the verifiable catalog contains 98 tools.

## Evidence still pending

Final M1 acceptance requires starting the laboratory application in all three hosts and proving that
the Access Violation returns an `exception` event and structured stack. This remains associated with
the M0 visual-validation dependency.

## Still missing from the goal

- M0/M1 evidence inside all three hosts;
- M2: safe window and control discovery;
- M3: bounded declarative execution;
- M4: diagnose, fix, and replay loop;
- M5: regression, evidence, and hardening.
