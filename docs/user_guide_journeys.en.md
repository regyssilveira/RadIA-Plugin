# End-to-end Delphi journeys

Journeys turn isolated tools into complete Agent Runtime workflows. Every journey presents a plan
before the first mutation, uses central consent, records checkpoints, and keeps diffs, builds,
tests, debugger evidence, and Git visible in chat.

Type `/journey` to list the available recipes.

Every recipe accepts optional context after the command, for example:

```text
/journey create VCL inventory application with FireDAC and SQLite
/journey fix-build preserve the public API of CustomerService
/journey debug Access Violation while closing the orders form
/journey modernize reduce coupling without changing public interfaces
/journey migrate replace an ADO layer with FireDAC in reversible batches
```

Context is limited to 4,000 characters and appended to the structured objective. It never changes
consent rules or replaces plan review.

Every recipe has four required phases. Each phase defines the expected work and the evidence that
must appear in the timeline. The run also receives three completion criteria, so the agent cannot
claim success merely because it produced a text response.

| Command | Objective |
|---|---|
| `/journey create [requirements]` | Create, organize, document, build, and explain a Delphi project. |
| `/journey fix-build [constraints]` | Diagnose errors, apply a minimal repair, and rebuild. |
| `/journey tests [focus]` | Identify gaps, add DUnitX tests, and run validation. |
| `/journey debug [symptom]` | Reproduce a failure, collect evidence, fix, and validate. |
| `/journey modernize [scope]` | Modernize units, forms, packages, and dependencies in validated batches. |
| `/journey migrate [legacy pattern]` | Migrate a bounded pattern with a baseline, transaction, and rollback. |
| `/journey release [scope]` | Check gates and diff, then prepare a commit preview. |

## Execution model

1. The command visually enables agent mode when necessary.
2. RadIA converts the recipe into a structured objective.
3. The model creates a reviewable plan; no tool runs before approval.
4. Every operation passes through risk, consent, workspace boundary, sanitization, and auditing.
5. Users can pause, edit the plan, replay a step, resume, or cancel.
6. The result presents evidence and remaining risks instead of only a text response.

The `/journey` catalog reports phase and criterion counts. At run start, the objective sent to the
Agent Runtime enumerates ordered phases, required evidence, and final completion criteria. User
context remains separate and cannot remove these gates.

During project creation, external references are inspected only after the user authorizes the path
or URL. The plan records license provenance, explains dependencies, prefers suitable RTL
capabilities, organizes reusable units, updates the `.dproj`, writes applicable documentation,
and uses actual compiler diagnostics as feedback for the next reviewed correction.

Recipes grant no additional permission. The release journey prepares a local preview but never
pushes or publishes artifacts without an explicit user instruction.

Use **modernize** when structure and practices should evolve while behavior and public contracts
remain stable. Use **migrate** when replacing a bounded legacy technology in independently
reversible batches.
