# End-to-end Delphi journeys

Journeys turn isolated tools into complete Agent Runtime workflows. Every journey presents a plan
before the first mutation, uses central consent, records checkpoints, and keeps diffs, builds,
tests, debugger evidence, and Git visible in chat.

Type `/journey` to list the available recipes.

You may provide everything in the command or start with only the journey name. When information is
missing, RadIA keeps the journey active, asks for one item at a time, and adds every answer to the
same context. The agent starts only after intake is complete. Use `/journey cancel` to abandon the
intake and discard collected values; chat switching is blocked while intake is active.

Every recipe accepts optional context after the command, for example:

```text
/journey create VCL inventory application with FireDAC and SQLite
/journey dext-minimal
/journey dext-controllers project=BookingApi destination=D:\Projects platform=Win64 port=8080 health=/health endpoints="GET /bookings/{id} group=Bookings status=200 purpose=GetBooking"
/journey fix-build preserve the public API of CustomerService
/journey debug Access Violation while closing the orders form
/journey modernize reduce coupling without changing public interfaces
/journey migrate replace an ADO layer with FireDAC in reversible batches
```

Context is limited to 4,000 characters and appended to the structured objective. It never changes
consent rules or replaces plan review.

The complete local classification contract and its safeguards are documented in
[Intent routing](../reference/intent_routing.en.md).

Every recipe has four required phases. Each phase defines the expected work and the evidence that
must appear in the timeline. The run also receives three completion criteria, so the agent cannot
claim success merely because it produced a text response.

| Command | Objective |
|---|---|
| `/journey create [requirements]` | Create, organize, document, build, and explain a Delphi project. |
| `/journey dext-minimal [endpoints]` | Create and validate a DEXT server with direct routes. |
| `/journey dext-controllers [endpoints]` | Create and validate a DEXT server organized by controllers. |
| `/journey fix-build [constraints]` | Diagnose errors, apply a minimal repair, and rebuild. |
| `/journey tests [focus]` | Identify gaps, add DUnitX tests, and run validation. |
| `/journey debug [symptom]` | Reproduce a failure, collect evidence, fix, and validate. |
| `/journey modernize [scope]` | Modernize units, forms, packages, and dependencies in validated batches. |
| `/journey migrate [legacy pattern]` | Migrate a bounded pattern with a baseline, transaction, and rollback. |
| `/journey release [scope]` | Check gates and diff, then prepare a commit preview. |

### Intent recommendation from the conversation

Users do not need to know journey commands. Natural requests to create a project, repair a build,
run tests, or diagnose a failure first display a recommendation card. It reports the intent,
confidence, explanation, and proposed command without changing mode or running a tool.

- **Use recommended route** confirms the proposed journey.
- **Review command** places the command in the composer for editing.
- **Continue as chat** keeps the current route and sends the request as an ordinary conversation.

For phrases such as **“make a basic calculator”** or **“create a VCL calculator in
D:\Projects\Calculator”**, RadIA extracts absolute Windows paths, infers the name from the
destination or application type, and uses Win32 when no platform is specified. It asks only for
information that is actually missing after the user confirms the recommendation. After plan
approval, the workflow writes only inside the authorized root, opens the project in the IDE,
builds and runs it, and records validation evidence. The panel remains open through the transition
and shows progress to the user.

The type is also inferred without requiring the command: Console, VCL, FireMonkey/FMX, Library/DLL,
Package/BPL, DUnitX, or Windows Service. Equivalent Portuguese and English terms are accepted. If the
request does not safely identify one of these types, RadIA asks which template to use before preview.

For a generic VCL calculator, the journey uses the `essential` profile: it creates only the
application, opens the project, and completes the first build. After that build, RadIA presents
explicit choices to keep the project as-is, add DUnitX, or request other increments. Only after that
choice does `complete`, or `custom` with `dunitx`, include `companionTestProject` and
`companionTestExecutable`, build the companion suite, and run it with `RunDUnitXTests`.

When the request includes **operation history**, **calculation list**, or an equivalent phrase, that
requirement is preserved in the structured specification and preview. The generated calculator records
each completed operation in order and provides **Clear history**. The journey can only complete after
running real calculations, checking the history, and verifying that it can be cleared; a green build
alone does not satisfy this request.

If the destination directory already exists, the run reports the conflict and keeps the journey waiting
for another destination. The next reply replaces only the path: project type, platform, name, and
functional requirements — including history — remain in the objective. The recommendation card is
visibly consumed on the first click so it does not suggest that the same action is still available.

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

For BDE, ADO, and dbExpress, the `migrate` journey uses the dedicated
[FireDAC migration flow](legacy_data_migration.en.md): inventory, risk, per-file preview, build, tests,
and mandatory rollback when a gate fails. DEXT and form decomposition enter the plan only after the
FireDAC batches are stable.
