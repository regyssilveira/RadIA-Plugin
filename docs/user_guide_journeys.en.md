# End-to-end Delphi journeys

Journeys turn isolated tools into complete Agent Runtime workflows. Every journey presents a plan
before the first mutation, uses central consent, records checkpoints, and keeps diffs, builds,
tests, debugger evidence, and Git visible in chat.

Type `/journey` to list the available recipes.

| Command | Objective |
|---|---|
| `/journey create` | Create, open, build, and explain a new Delphi project. |
| `/journey fix-build` | Diagnose compiler errors, apply a minimal repair, and rebuild. |
| `/journey tests` | Identify gaps, add DUnitX tests, and run relevant validation. |
| `/journey debug` | Reproduce a failure, collect debugger evidence, fix, and validate. |
| `/journey release` | Check health, build, tests, diff, and prepare a commit preview. |

## Execution model

1. The command visually enables agent mode when necessary.
2. RadIA converts the recipe into a structured objective.
3. The model creates a reviewable plan; no tool runs before approval.
4. Every operation passes through risk, consent, workspace boundary, sanitization, and auditing.
5. Users can pause, edit the plan, replay a step, resume, or cancel.
6. The result presents evidence and remaining risks instead of only a text response.

Recipes grant no additional permission. The release journey prepares a local preview but never
pushes or publishes artifacts without an explicit user instruction.

