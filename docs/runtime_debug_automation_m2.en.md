# M2 — Safe runtime discovery

> **Status:** implementation and automated tests complete; in-IDE validation pending.
> **Goal:** [Autonomous runtime failure reproduction](runtime_debug_automation_plan.en.md).

## Deliveries

- process correlation through PID, creation time, and executable path;
- strict inclusion of the debugged process and descendants created during the session;
- discovery of top-level windows, ownership, and windowed VCL controls;
- session-scoped opaque identifiers without exposing or accepting `HWND`;
- control tree with class, sanitized text, hierarchy path, state, and capabilities;
- timeout-protected text reads so a paused application cannot block discovery;
- mandatory redaction of password-field contents;
- rejection of changed sessions, external windows, and unknown identifiers.

## Tools

| Tool | Use |
|---|---|
| `GetRuntimeWindows` | List only windows owned by the authorized process and its descendants. |
| `GetRuntimeControlTree` | Return the sanitized tree for a window identified by its opaque ID. |

Both tools obtain the current session directly from the coordinator. Callers do not provide a PID,
executable, or handle, so their arguments cannot expand the authorized scope.

## Reported capabilities

| Capability | Recognized controls |
|---|---|
| `invoke` | windowed buttons |
| `setValue` | windowed editors and memos |
| `select` | windowed combos and lists |
| `close` | top-level windows |

A capability only describes a possible action. Execution remains blocked until M3 adds preview,
consent, bounds, and an emergency stop.

## Intentional limitations

- graphical controls without an `HWND` do not appear in the tree yet;
- there is no global-coordinate automation;
- model- or user-supplied handles are not accepted;
- Automation ID and ambiguous-selector diagnostics will be strengthened before M3 execution;
- discovery does not click, close, or modify any control.

## Automated evidence

- the authorized form and button are found through opaque IDs;
- owned-window relationships are preserved;
- every result belongs to the authorized process;
- an unknown opaque ID is rejected;
- no JSON response contains `handle` or `HWND`;
- a password field returns only `[redacted]`;
- the verifiable catalog contains 100 tools.

## Evidence still pending

Final acceptance requires running the laboratory application in all three supported hosts and
locating its main form, target form, and open/cancel controls. Validation must include an external
window to prove exclusion in the real IDE environment.

## Still missing from the goal

- M0–M2 evidence inside all three hosts;
- M3: bounded declarative execution;
- M4: diagnose, fix, and replay loop;
- M5: regression, evidence, and hardening.
