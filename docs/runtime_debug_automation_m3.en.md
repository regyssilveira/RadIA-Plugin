# M3 — Bounded declarative execution

> **Historical status:** implementation, tests, and in-IDE validation completed for version 2.1.0.
> **Goal:** [Autonomous runtime failure reproduction](runtime_debug_automation_plan.en.md).

## Deliveries

- separate preparation and execution with an identified preview and immutable fingerprint;
- validation of every action and capability before creating the preview;
- mandatory execution consent for every call without remembered session permission;
- session and target revalidation immediately before every action;
- sequential execution bounded by action count, duration, and repetitions;
- invoke, set, select, close, cancel, wait, and text assertion actions;
- structured status with repetition, current action, completed actions, and failure;
- immediate wait cancellation by the agent, MCP, or emergency-stop tool;
- Windows messages capped at one second to keep emergency stop responsive;
- rejection of password controls, unknown IDs, external windows, and missing capabilities.

## Tools

| Tool | Risk | Use |
|---|---|---|
| `PrepareRuntimeScenario` | Read only | Validate and register the script without executing actions. |
| `RunRuntimeScenario` | Execution | Request consent and execute exactly the selected preview. |
| `CancelRuntimeScenario` | Read only | Trigger emergency stop without opening a consent dialog. |
| `GetRuntimeScenarioStatus` | Read only | Read progress, outcome, or interruption reason. |

`RunRuntimeScenario` uses the `ConsentEveryTime` policy. Even when the user allows other execution
permissions to be remembered for the session, every runtime scenario requires a new explicit
decision.

## Scenario format

```json
{
  "name": "Open and cancel the target form",
  "limits": {
    "maxActions": 2,
    "maxDurationMs": 10000,
    "maxRepetitions": 1
  },
  "actions": [
    {
      "kind": "invoke",
      "targetId": "<controlId returned by discovery>",
      "timeoutMs": 1000
    },
    {
      "kind": "cancel",
      "targetId": "<authorized windowId or controlId>",
      "timeoutMs": 1000
    }
  ]
}
```

Accepted kinds are `invoke`, `setValue`, `select`, `close`, `cancel`, `wait`, and `assert`. A `wait`
action has no target. `setValue`, `select`, and `assert` receive `value`. Coordinates, PIDs,
executable paths, and handles are not part of the contract.

## Automated evidence

- invalid scenarios and targets without capabilities are rejected during preparation;
- a session change invalidates the preview;
- repetitions execute the expected sequence;
- a failure stops subsequent actions;
- cancellation wakes a five-second wait in less than two seconds;
- an authorized button is invoked and an authorized editor is changed;
- password fields are rejected;
- the `Run` tool requires consent for every execution;
- the `Cancel` tool remains available without consent;
- the verifiable catalog contains 104 tools;
- 794 tests pass without leaks on the first validated target.

## Evidence still pending

Final M3 acceptance requires running the laboratory application in all three hosts, preparing the
script from discovered controls, reviewing the preview, consenting to execution, and reproducing
the failure while opening or cancelling the target form without touching any external window.

## Still missing from the goal

- M0–M3 evidence inside all three hosts;
- M4: diagnose, fix, and replay loop;
- M5: regression, evidence, and hardening.
