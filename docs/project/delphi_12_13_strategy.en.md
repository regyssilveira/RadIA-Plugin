# Delphi 12/13 Strategy and Experience Leadership

## Product decision

Starting with line 2.0, RadIA is developed, validated and distributed to:

- Delphi 12 with Win32 IDE;
- Delphi 13 with Win32 IDE;
- Delphi 13 with IDE64.

Delphi 11 stops receiving new packages, fixes, regression tests and operational support.
Old evidence remains in the repository as history only and does not represent the matrix
current.

This decision allows for deeper integration with editor, Form Designer, debugger, terminal and Open
Tools API, preserving a relevant installed base without loading the older generation.

## Objective

Deliver the most complete Delphi development experience: start a project, generate and
review code, design forms, compile, test, debug, operate the terminal and complete the
Git journey without leaving the context controlled by RadIA.

## Principles

1. A user intent must produce an understandable, reviewable, and reversible journey.
2. Chat, endpoint, MCP, and agent mode must share tools, consent, and auditing.
3. Operations on code and Designer must present preview before mutation.
4. Each automation must have observable evidence of results.
5. External resources must be discovered and configured without capturing credentials.
6. New capabilities must pass Delphi 12 Win32, Delphi 13 Win32, and IDE64 before being
considered ready.

## Execution plan

### Phase 0 — Consolidate Delphi 12/13 as a platform

- Remove Delphi 11 from the parameters accepted by the build.
- Produce Delphi 12 Win32, Delphi 13 Win32 and Delphi 13 IDE64 packages.
- Remove old installer targets, CI and evidence generators.
- Update requirements, onboarding, compatibility matrix and release.
- Preserve old evidence with explicit history marking.
- Create a gate that rejects new active targets other than BDS 23.0 and BDS 37.0.

**Completion criteria:** build, tests, installer and release reject BDS 22.0 and accept only
BDS 23.0 and BDS 37.0 on supported architectures.

### Phase 1 — Templates and project creation

- Consolidate templates for Console, VCL, FMX, Library, Package and DUnitX.
- Add Windows services and multi-tier applications.
- Show files, platforms and dependencies before creation.
- Create the project in reversible transaction.
- Allow analysis of authorized reference implementations with license registration and provenance.
- Prefer adequate RTL resources before introducing external dependencies.
- Organize reusable units, update references and produce README/NOTICE when applicable.
- Open the project, compile, read diagnostics and repeat revised fixes until stabilized.
- Allow declarative templates installed by the catalog.

**Completion criteria:** a user creates, opens, compiles, and runs each supported project type
without editing files manually.

### Phase 2 — CLI Manager

- Detect Codex, Claude, Gemini, GitHub Copilot and local runners.
- View installation, version, authentication, availability and update.
- Direct installations to official channels with consent.
- Provision MCP and validate handshake automatically.
- Allow choosing API, CLI or local model per session and per project.
- Create diagnosis and repair for inconsistent configurations.

**Completion criteria:** each executor can be prepared and validated by the interface, without editing
Manual JSON, TOML or global variables.

### Phase 3 — Addon Studio

- Create assistants for commands, skills, aliases, workflows and journeys.
- Validate schema, permissions, risks, limits and signature in real time.
- Provide isolated test execution and audit inspection.
- Package, install and update by visual manager.
- Publish SDK, examples and compatibility diagnosis.

**Completion criteria:** a working extension can be created, tested, and installed without
recompile the BPL.

### Phase 4 — Unified Code/Design Journey

- Transform interface requests into a visual plan.
- Present preview of components, properties, events and files.
- Apply changes to the Living Designer and the editor within the same transaction.
- Automatically navigate between Design and Code according to the stage.
- Incorporate build, testing, execution and debugging into the timeline.
- Allow rejection and rollback per step.

**Completion criteria:** creating a complete screen goes through Designer, code, build and
execution in a single audited journey.

### Phase 5 — Terminal 2.0

- Add multiple sessions and tabs.
- Create profiles for PowerShell, CMD, Git Bash, and AI CLIs.
- Deliver search, history, snippets and command palette.
- Make all shortcuts configurable.
- Share directory, project context, MCP, and consent with chat.
- Ensure resize, ANSI, Unicode and complete closure of the process tree.

**Completion criteria:** the integrated terminal meets daily use without requiring an external window.

### Phase 6 — Inline Review

- Show small changes directly in the editor without modifying the buffer.
- Allow accepting or rejecting each block by keyboard or mouse.
- Reposition markers after scrolling and concurrent editing.
- Invalidate previews when base hash changes.
- Forward large or multi-file changes to Smart Diff.
- Validate stability, accessibility and performance in Delphi 12 Win32 and Delphi 13 Win32/IDE64.

**Completion criteria:** small changes are reviewed in the editor and complex changes
remain protected by Smart Diff.

### Phase 7 — Leadership test

- Measure time from installation to first revised change.
- Run complete journeys in Delphi 12 Win32 and Delphi 13 Win32/IDE64.
- Validate keyboard, screen reader, themes and DPI scales.
- Perform repeated cycles of installation, repair, upgrade, use and shutdown.
- Publish hashes and reproducible evidence of the two packages.
- Maintain regression-free Sonar, lint, tests and audits.

**Completion criteria:** all critical journeys have automated evidence and approval in
Real FDI in the three targets.

## Order by complexity

1. Templates and project creation.
2. CLI Manager.
3. Addon Studio.
4. Unified Code/Design journey.
5. Terminal 2.0.
6. Inline review.

The first three phases quickly expand the first value. The last three concentrate the largest
integration risk with the IDE and must reuse consent, transactions and audit already
consolidated.

## Indicators

|Indicator|Goal|
| :--- | :--- |
|Active targets|Delphi 12 Win32 and Delphi 13 Win32/IDE64|
|Manual configuration for executors|Zero required files|
|Project creation until first build|A guided journey|
|Mutation without preview or consent|Zero|
|Orphaned process after shutdown|Zero|
|Tools outside of core policy|Zero|
|Quality Gate|Approved|
|Critical journey tests|100% approved|
