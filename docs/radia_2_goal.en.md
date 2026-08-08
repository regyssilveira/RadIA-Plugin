# RadIA 2.0 goal: complete development journey

> **Historical status:** goal completed and version 2.0.0 published.
> Evidence in this document proves the implemented baseline, but does not close the expanded
> release gates.

## Objective

Allow users to describe a Delphi application and, without leaving the IDE, follow deterministic
project creation, safe code and Form Designer changes, builds, DUnitX tests, debugging, validated
fixes, and a reviewable commit.

The workflow must be observable, cancellable, persistent, and protected by previews, consent,
auditing, and workspace confinement. The final delivery will be validated on Delphi 12 and 13.

## Sources of truth

- `/tools` represents the active IDE instance, including extensions.
- The [generated catalog](runtime_tool_catalog.en.md) records built-in tools verified against source.
- The [architectural catalog](tool_catalog.md) describes existing contracts and target capabilities.
- The [leadership goal](experience_leadership_goal.en.md) defines the next experience evolution.
- This document defines the completion criteria for the 2.0 goal.

## August 2026 baseline

| Capability | Current evidence | State for the goal |
|---|---|---|
| Registry and security | 80 built-in tools, policy, consent, and audit | Ready |
| Chat | Providers, streaming, sessions, Agent Mode, and observable loop | Ready |
| New project | Visual wizard and six deterministic templates | Ready |
| Live project | Inspection and transactional structural operations | Ready |
| Editor | Live buffer, patches, and multi-file transactions | Ready |
| Form Designer | Composite Design/Code transaction | Ready |
| Build | Self-correcting gate with mandatory rebuild | Ready |
| Tests | Structured and cancellable DUnitX runner | Ready |
| Debugger | State, control, and event-driven timeline | Ready |
| Git and delivery | Preview, diff, and reviewable local commit | Ready |
| Compatibility | Delphi 12 Win32 and Delphi 13 Win32/IDE64 | Keep the matrix green |

## Capabilities incorporated into the runtime

The original target gaps are now registered as built-in tools:

- structural unit and form creation;
- adding and removing project files;
- configuration and platform selection;
- structured DUnitX discovery and execution;
- debugger notifications and timeline;
- multi-file edit transactions;
- Git operations;
- a native agent loop.

The generated catalog contains 95 tools. The flows have tests proportional to their risk and passed
the in-IDE E2E validation for the 2.0 release.

## Milestones

### M0 — Verifiable baseline

- Keep the built-in catalog generated and validated by the build.
- Resolve runtime and documentation drift.
- Define the required E2E scenario and evidence.
- Preserve builds and tests across the supported matrix.

### M1 — Agent Runtime

- Plan, call tools, observe results, and continue to completion.
- Bound steps, tokens, cost, time, and repetition.
- Support pause, cancellation, checkpoints, and resume.
- Display plan, active step, tool, consent, and result.

Status: completed. The core executes decisions and tools, records observations, bounds steps and
repeated calls, and supports pause, cancellation, checkpoints, and resume. The provider adapter,
asynchronous controller, and live chat card are connected through `/agent run`. The plan requires
approval before the first tool, and persistent token, time, and cost limits are enforced. Cost uses
locally configured provider/model rates and never assumes unknown prices.

### M2 — New Project Wizard

- Provide deterministic Console, VCL, FMX, Library, Package, and DUnitX templates.
- Create in a workspace-confined staging area.
- Preview the tree and platform options.
- Open, build, and fully roll back on failure.

Status: completed. The deterministic six-template engine, SHA-256 preview,
staging/commit/rollback transaction, OTA opening, and initial build with automatic rollback are
implemented and exposed as tools. The visual wizard supports authorized folder selection without
an active project. All six generated projects compile through `.dproj` on Delphi 12 and 13.

### M3 — Transactional editing and Designer

- Treat the IDE buffer as the primary source.
- Apply or revert a multi-file change as one unit.
- Integrate inline diff and Undo.
- End visual mutations in Design and code mutations in Code.

Status: completed. Multi-file transactions provide one preview, full-buffer preflight,
compensating commit, and complete revert through `PrepareMultiFilePatch`, `ApplyMultiFilePatch`,
and `RevertMultiFilePatch`. The OTA facade reads and writes any open buffer without depending on
the active editor. Unit/form creation and removal also use preview, atomic publication, OTA
registration, and revert without deleting preexisting files. The higher-level transaction now
composes code, structure, components, layout, properties, and events with symmetric compensation.
The Delphi 13 E2E journey validated live-buffer patching, Form Designer property and component
changes, consent, rollback, and persistence of the reverted state.

### M4 — Build and tests

- Run the change, build, diagnose, fix, and rebuild cycle.
- Discover and execute DUnitX tests.
- Interpret failures and rerun affected tests.
- Include coverage and leak detection in evidence.

Status: completed and validated in Delphi 13. The runtime prevents completion after a mutation until
a successful `BuildProject` occurs. Build saves buffers through OTA and runs Delphi's official
MSBuild outside the IDE thread, with timeout, cancellation, and structured diagnostics. The smoke
confirmed an intentional compiler error, diagnostic reporting, reviewed patch rollback, successful
rebuild, and passing DUnitX. The runner confines NUnit XML artifacts under `.radia/test-results`.

### M5 — Debug Agent

- Receive process, pause, breakpoint, exception, and termination events.
- Maintain bounded timeline, threads, frames, stack, and watches.
- Diagnose, prepare a fix, and validate again with authorization.

Status: completed and validated in the IDE. The OTA integration publishes process, state, breakpoint,
and memory events to a bounded timeline persisted at `.radia/debug/timeline.jsonl`. The real Delphi
13 smoke confirmed build, breakpoint creation, startup through the IDE native Run action, stop,
call-stack and timeline reads, session termination, and breakpoint removal. Stack, frames, watches,
and controls remain available through debugger tools.

### M6 — Git and delivery

- Expose reviewable status, diff, branch, stage, and commit operations.
- Separate user changes from agent changes.
- Run quality gates before delivery.

Status: completed and validated in a disposable repository. The real journey confirmed status,
path-scoped diff, fingerprinted preview, consent, and a local commit. Commit `c503ae2` included only
the reviewed unit; files produced afterward remained outside the commit. RadIA does not push.

Status: completed. The local workflow exposes status, diff, preview, and commit for selected paths.
The preview uses a fingerprint, rejects a pre-staged index, and detects concurrent changes. No push,
reset, or discard tools are exposed, and commit remains subject to consent and audit.

### M7 — Release 2.0

- Pass the E2E scenario on supported IDE versions.
- Validate docking, WebView2, shutdown, resume, and orphan cleanup.
- Publish installer, migration guide, user manual, and release evidence.

Status: release 2.0.0 published and validated. The current build was installed on Delphi 12 Win32
and Delphi 13 Win32/IDE64. Smoke tests confirmed the installed BPL SHA-256, version, 95-tool
catalog, discovery cleanup, and the absence of descendant processes after shutdown. The chat panel
was also created as a `TOTADockForm` through
the native `INTACustomDockableForm` API and rendered in a real IDE without a blank screen.
Additional shutdown hardening removed late access to already destroyed VCL objects. `bds.exe`
retention was eliminated by unregistering editor and debugger OTA hooks before abandoning their
objects during shutdown, without freeing VCL/WebView2. Three consecutive cycles of the installed
build ended without an orphan process. Lateral dropping remains a manual visual acceptance because
the elevated IDE blocks synthetic cross-process input; host creation, visibility, and persistence
are automated. The continuous E2E journey below passed on Delphi 13.

## Historical validation evidence — August 4, 2026

The results below record the previous matrix. Current evidence must use only Delphi 12 Win32 and
Delphi 13 Win32/IDE64.

- Delphi 11, 12, and 13 Win32: 590 direct tests per version, with no failures, ignored tests, or leaks.
- Real Win32 smoke: Delphi 11 and 12 passed one load cycle, the MCP catalog current at that time,
  and clean
  shutdown; Delphi 13 passed three consecutive cycles under the hardened root-process assertion.
- Delphi 13 IDE64: 590 direct tests, with no failures, ignored tests, or leaks.
- 2.0.0 candidates: validated packages for Delphi 11/12/13 Win32 and Delphi 13 IDE64, with the complete
  manual and 1.x-to-2.0 migration guide published in the documentation.
- Delphi 13 Win32: three real load and shutdown cycles with the catalog current at that time and no
  orphan process.
- Delphi 13 Form Designer: a `TButton` was created, listed, and reverted in the live designer with
  preview and consent.
- Delphi 13 template build: the modal prompt for an unpersisted project group was eliminated.
- Delphi 13 IDE64: three real load and shutdown cycles with the catalog current at that time and no
  orphan process.
- Chat/WebView2: native `TOTADockForm` host and panel rendered in a real IDE without a blank screen,
  with the agent-mode visual control present.
- IDE desktop: two real cycles confirmed `TOTADockForm` visibility and geometry restoration; the
  lateral drop remains a manual visual acceptance because the elevated IDE blocks synthetic
  cross-process input.
- Delphi 13 MCP/IDE integration: disposable project opening, live-buffer read and patch, visual
  consent, save, tool-driven build, 513 tests through the DUnitX tool, rename, reindexing, and clean
  shutdown.
- Delphi 13 VCL template: deterministic preview, visual consent, transactional creation, real open,
  OTA build, rollback, module close, and restoration of the previous active project.
- Delphi 13 Form Designer: live form detection, `Caption` property preview, visual consent,
  application, revert, and persistence of the reverted state before project rollback.
- Quality: ESLint, runtime catalog validation, and `git diff --check` passed.

CDB diagnosis confirmed that retention happens before `ExitProcess`, during IDE file notifications.
MMX appeared in an AV call chain involving an already unloaded DevExpress BPL, but retention also
occurred with MMX temporarily disabled. RadIA now neutralizes its knowledge notifiers during
shutdown without freeing VCL/WebView2 objects. The stack correlation with
`IdeservicesFileNotification` led to explicitly removing editor and debugger OTA hooks; three
consecutive cycles of the hardened smoke confirmed the fix, ranging from 16.41 to 30.94 seconds.

This evidence validates installation, loading, catalog discovery, rendering, editing, build, tests,
shutdown, template creation, and safe Designer editing. The continuous journey with debugging, a
validated fix, and a reviewable Git commit also passed on Delphi 13.

## Competitive expansion before release

The following items belong to version 2.0.0 and reopen its release gate:

1. expand the OTA surface for navigation, symbols, project groups, dependencies, and IDE actions;
2. make intent-to-view a uniform tool contract;
3. complete inline diff with per-block acceptance and rejection;
4. implement a CLI Manager for Codex CLI, Claude Code, Gemini CLI, and GitHub Copilot CLI;
5. provision MCP with detection, backup, merge, testing, repair, and safe removal;
6. integrate a dockable terminal with profiles, history, snippets, and process-tree shutdown;
7. allow switching between the native agent and CLI executors without restarting the IDE;
8. provide optional official-channel installation, diagnostics, and onboarding;
9. validate Delphi 12 Win32 and Delphi 13 Win32/IDE64 before publishing the final artifacts.

OTA expansion delivered on this branch: seven tools now cover project groups, native dependencies,
live-buffer symbols, confined file or symbol navigation, and IDE actions protected by an allowlist
and consent.

Review experience delivered on this branch: successful JSON results now carry a uniform visual
intent for chat and MCP, while Smart Diff allows accepting or rejecting each block before applying
the selected composition to the editor.

Hybrid executors delivered on this branch: settings persist the native agent or one of four supported
CLIs without restarting the IDE. Non-interactive profiles use separated arguments and structured
output, with asynchronous streaming, JSONL normalization, timeout, and Job Object cancellation.
The dockable terminal, bounded history, snippets, and onboarding are also integrated.

MCP provisioning delivered on this branch: the provisioner covers the client catalog, preview,
drift detection, JSON merge, managed TOML block, backup, verification, repair, rollback, and
selective removal, with visual integration and operational diagnostics.

Visual integration delivered on this branch: the **CLI & MCP** category supports client selection,
path overrides, CLI and MCP diagnostics, proposal review, and explicit confirmation for connect,
repair, or selective removal. Optional official-channel installation and handshake diagnostics are
also complete.

CLIs will not be redistributed inside the package. With explicit consent, the installer will detect
existing installations and delegate installation or updates to each vendor's official channels.

Optional installation delivered on this branch: the **CLI & MCP** screen previews the official
command and prerequisites, asks for confirmation, and runs installation or update asynchronously
with observable output, timeout, and process-tree cancellation. Third-party binaries are never
redistributed.

Handshake diagnostics delivered on this branch: the screen starts the configured bridge against the
current IDE's `mcp.<pid>.json`, sends `initialize`, `notifications/initialized`, `ping`, and
`tools/list`, validates JSON-RPC responses, and reports protocol version and the live tool count.
The E2E test starts a real named-pipe server and bridge for the complete cycle.

Competitive expansion status: complete. All nine items are implemented; the final matrix and
reproducible artifacts remain preparation gates, without publishing a tag or release.

## Required E2E scenario

1. Create a VCL CRUD application from a description.
2. Open the project and complete its first build.
3. Create domain, persistence, form, and events.
4. Show and apply a multi-file review.
5. Generate and execute DUnitX tests.
6. Start the debugger and wait for a breakpoint.
7. Inspect the stack and safe values.
8. Prepare and apply a fix.
9. Rebuild and rerun tests.
10. Present and create a reviewable commit.

## Definition of Done

- No unsaved buffer is lost.
- Every relevant mutation has a preview, consent, or both.
- The agent can be paused, cancelled, and resumed.
- Build and tests finish green in the reference scenario.
- Debugger progress is event-driven, not based on blocking waits.
- The final diff matches the proposed commit.
- Audit records contain no secrets.
- There are no leaks, deadlocks, orphan discovery files, or orphan processes.
- Evidence covers Delphi 12 Win32 and Delphi 13 Win32/IDE64 according to the official matrix.
