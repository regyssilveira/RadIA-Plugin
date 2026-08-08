# Agentive Evolution Roadmap

> **Historical document of line 1.x.** The current matrix of line 2.0 contains only Delphi 12
> Win32 and Delphi 13 Win32/IDE64. References to Delphi 11 below record old validations.

## goal

Evolve RadIA from a multi-provider chat assistant to a secure, agentive platform
integrated with Delphi, preserving stability upon shutdown
IDE and independent implementation.

## State

|Phase|Scope|State|
|---|---|---|
| 0 |Architecture, contracts and gates|Completed|
| 1 |Workspace facade and read-only tools|Implemented; smoke OTA D11/D12/D13 approved|
| 2 |Consent, policies and audit|Implemented; real flow D13 approved|
| 3 |Reviewable patches and build cycle|Implemented; approved reversible real flow|
| 4 |Local MCP and CLI providers|Implemented; bridge and pipe stress approved|
| 5 |Live designer, debugger and inline review|Implemented; D13 real review approved|
| 6 |Incremental local knowledge|Implemented; notifier events covered by tests|
| 7 |Extensibility, hardening and release|Completed|

## Prioritized upcoming milestones

The agentive goal has been completed. Subsequent evolutions must be opened as new versioned goals.

Goal indicators:

- 100% of changeable tools undergo consent and audit.
- 100% of changes to code or Designer have preview and preconditions.
- Zero crashes, errors or leaks in DUnitX D11/D12/D13 Win32 array.
- Zero crashes or deadlocks in ten consecutive cycles of installation, use and shutdown per IDE.
- No reading or writing outside of the authorized workspace.

## Phase 0: documentary foundation

Deliveries:

- [Agentive architecture](agentic_architecture.en.md).
- [Tool Catalog](tool_catalog.en.md).
- [Security model](tool_security_model.en.md).
- [Compatibility matrix](delphi_compatibility_matrix.en.md).
- [Validation plan](agentic_validation_plan.en.md).
- [Tool Registration ADR](adr/0001-internal-tool-registry.en.md).
- [Workspace facade ADR](adr/0002-workspace-facade.en.md).

Gate:

- Revised contracts and boundaries against current code.
- First implementation slice defined.
- Registered build and testing baseline.

Result:

- Documentation and ADRs created.
- Package compiled in Delphi 12.
- The suite started compiling again after adopting the response file in `build.ps1`.
- DUnitX Baseline: 292 tests, 289 passes, three failures dependent on local SonarQube and zero
leak, according to [validation plan](agentic_validation_plan.en.md).

## Phase 1: first deployable slice

Objective:

Create the internal registry, executor, and a minimal read-only facade.

Tools:

- `GetIDEState`
- `GetActiveProject`
- `GetActiveUnit`
- `ListOpenFiles`
- `ListProjectUnits`
- `GetEditorContent`
- `GetEditorSelection`
- `GetCursorPosition`
- `GetCompilerMessages`

Gate:

- Tools tested with fake facade.
- OTA integration validated within the IDE.
- No writing available.
- Build and DUnitX approved in available IDEs.

Partial result:

- Tool Registry and executor implemented in Core.
- Read-only facade implemented over OTA.
- Nine read-only tools registered in the container.
- Catalog, execution and results of tools visually integrated into the chat.
- `/tools` and `/tool` commands available without forwarding the request to the AI ​​provider.
- 313 tests passed in Delphi 12, without failures or leaks.
- Validation within the IDE and other available versions is still pending to complete the phase.

## Phase 2: security

Add policy pipeline, consent, sanitization and audit before any tool
changeable.

Partial result:

- Execution context includes source, session, project, and scope.
- Centralized policy enforcer between clients and the concrete executor.
- Read-only tools are allowed without a prompt.
- Changeable tools require explicit decision; sensitive tools are denied by default.
- Session permissions are scoped by session, project, tool, and scope, and are revocable.
- Initial redaction covers Bearer tokens, AWS keys, and sensitive JSON fields.
- Audit structured in JSON Lines records decision, result, duration and sanitized arguments.
- Native consent UI offers allow once, allow in session, deny, and cancel.
- Dialog has fail-safe timeout and automatically cancels during shutdown.
- Command `/revoke-tools` immediately removes all session permissions.
- Workspace boundary rejects volume root, parent traversal, external paths and reparse points.
- 327 tests passed in Delphi 11, 12 and 13 Win32, without failures or leaks.
- Visual validation within the IDE and real testing with junction/reparse point still pending.

Gate:

- Denial without effect.
- Limited session permission.
- Secrets sanitized.
- Secure shutdown during consent.

## Phase 3: editing and building

Apply patches with preconditions, review, verification, and rollback.

Partial result:

- Patch service maintains immutable and temporary previews in memory.
- Preview requires active file, base hash, unique original snippet and authorized workspace.
- Apply and rollback revalidate file, project, workspace, and review immediately before writing.
- Adapter OTA compares and changes the buffer atomicly on the main thread.
- `PreparePatch`, `ApplyPatch` and `RevertPatch` registered with appropriate risks.
- Chat presents before/after comparison and requests consent to apply or reverse.
- Buffers changed after the preview are preserved and return `precondition_failed`.
- Size and quantity limits protect the memory of the `bds.exe` process.
- 340 tests passed in Delphi 11, 12 and 13 Win32, without failures or leaks.
- Tools now run outside the main thread and deliver results via the UI queue with lifecycle guard.
- `BuildProject` supports make, build, check and clean without executing the produced binary.
- Build uses OTA build service, consent, timeout, cancellation and mutual exclusion.
- `GetBuildStatus` and `CancelBuild` expose structured tracking and stopping.
- Result includes design, configuration, platform, duration and available diagnostics.
- Encoding on the real adapter, Undo OTA and smoke test within the IDE still pending.

Gate:

- Buffer conflicts detected.
- Diff approved before application.
- Encoding preserved.
- Structured build.
- Rollback validated.

## Phase 4: MCP and CLIs

Expose the registry via named pipe and optional HTTP loopback, initially integrating Codex CLI.

Partial result:

- MCP protocol `2025-06-18` implemented over JSON-RPC 2.0.
- Lifecycle, `ping`, `tools/list`, `tools/call` and unresponsive notifications implemented.
- The same registry and policy enforcer used by chat serves MCP clients.
- Named pipe uses ephemeral endpoint, ACL restricted to the owner and the system, maximum payload of 1 MiB and
one isolated session per connection.
- Bridge stdio allows integration with standard MCP clients without exposing network listener.
- The bridge waits up to ten minutes for responses to accommodate human consent without abandoning
the call while the IDE is still running the tool.
- Each process publishes `mcp.<pid>.json`, while `mcp.json` preserves compatibility with clients
existing instances and points to the most recently started instance.
- Shutdown always removes discovery from the instance itself and only removes the legacy file when
you still own it, without deleting the endpoint from another IDE.
- The bridge accepts one file path per instance and detects ambiguities when one does not exist.
legacy owner across multiple IDEs.
- Initialization waits for the endpoint to be ready and propagates pipe creation failures.
- Automated testing covers actual round-trip through the named pipe and its cleanup.
- Smoke test in Delphi 13 confirmed handshake, `tools/list`, live buffer read, consent
native and audit by bridge stdio.
- HTTP loopback and targeted integration with CLI providers were kept as optional.
- Current baseline on Delphi 11, 12 and 13 Win32: 442/442 tests, no failures or leaks.

Gate:

- Shared security with chat.
- Local authentication.
- Payload limits.
- Shutdown without orphaned processes or listeners.

## Phase 5: deep integration

Add live Form Designer, debugger and inline review.

Partial result:

- Independent facades for Form Designer and debugger have been added to Core.
- `GetActiveForm` returns form, unit, DFM, class, components and live Designer selection.
- `ListFormComponents` returns visual and non-visual components, hierarchy, selection, and geometry.
- `GetDebuggerState` returns process, state, executable, location, status, threads and breakpoints.
- `ListBreakpoints` returns file, line, enablement and validity of each breakpoint.
- `GetCallStack` returns frames, headers, and source positions from the current thread when accessible.
- Pause, resume, step into/over/out and stop use non-idempotent execution tools.
- Each command validates the state of the process and relies on shared consent and auditing.
- Breakpoints can only be added and removed in Pascal sources within the workspace.
- Addition is reversible; Removal is destructive and requires confirmation on each call.
- The five read-only tools use the same registry, policy, audit, chat and MCP.
- OTA interfaces are only accessed on the main thread and immediately converted into snapshots.
- No references to components, form editors, processes, threads, frames or breakpoints are retained.
- Component layout has immutable and temporary preview, application and rollback with preconditions.
- `PrepareComponentLayout`, `ApplyComponentLayout` and `RevertComponentLayout` are in the registry.
- Enforcement and rollback require structural consent and are recorded in the shared audit.
- The adapter changes the live component on the main thread, marks the Designer as modified and tries
restore the original bounds if the application fails.
- The chat presents visual comparison of bounds and explicit buttons to apply and reverse.
- Published scalar properties can be prepared, applied, and reversed with preconditions.
- `Name`, events, objects and other structural types are rejected by the real adapter.
- The chat features before/after comparison and explicit actions for Designer properties.
- Creation and removal of allowlisted VCL controls have preview, structural consent,
preconditions and reversal by the inverse operation.
- Event handlers have preview, signature generation via `IDesigner`, link to DFM vivo,
Pre/post snapshots of the Pascal buffer and rollback conditioned by preconditions.
- Evaluation of locals/expressions uses the current thread without side effects; watches are limited,
managed by RadIA and evaluated by the native debugger.
- `StartDebugging` exclusively compiles and starts the active project target.
- Inline revisions are anchored to the buffer revision, rendered by severity, and invalidated by
any competing edition; suggestions reuse the reversible patch cycle.
- Current baseline on Delphi 11, 12 and 13 Win32: 442/442 tests, no failures or leaks.
- The current BPL loaded automatically in three valid cycles per version: Delphi 11 terminated between
0.80 s and 0.86 s; Delphi 12, between 1.52 s and 1.99 s; Delphi 13, between 1.98 s and 2.63 s. There was no
crash or deadlock.
- Inline review real smoke in Delphi 13 confirmed visual decoration, consent, audit,
apply to the buffer, revert to the original SHA, reject and clean up without changing the file on disk.
- smoke revealed and corrected incorrect buffer identity `.dproj` and duplication of break
terminal line during full replacements by the OTA writer.
- Delphi 13 IDE64 compiled package, bridge and suite natively, with 442/442 tests passed. The BPL
Win64 loaded in three cycles in `bin64\bds.exe`, opened the project and responded to MCP as Win64.
Normal shutdowns completed between 1.62 s and 1.88 s, with no orphan process or MCP discovery.

Gate:

- Consistent SBP and DFM.
- Atomic event handler.
- Debugger operations supported.
- Smart Diff remains as fallback.

## Phase 6: knowledge

Create structural parser, lexical index and incremental update. Embeddings remain optional.

Partial result:

- Local service maintains independent indexes per project without depending on external services.
- Chunking recognizes units, sections, classes, records, interfaces, methods and Delphi routines.
- Each chunk records file, symbol, revision, start line, end line and content.
- Unchanged files are preserved; Changed revisions only replace the affected document.
- Files removed from the project are also removed from the index.
- The OTA source reads open buffers before disk and enforces workspace boundary.
- Closed files are limited to 2 MiB and only supported Pascal extensions are indexed.
- `IndexProjectKnowledge`, `SearchProjectKnowledge` and `ClearProjectKnowledge` are in the registry.
- `GetKnowledgeStatus` exposes loaded state and counts of files and chunks.
- `GetKnowledgeDocument` returns traceable chunks of an indexed file with explicit limit of
content and truncation flag.
- Search results have a lexical score and content limited to 4,000 characters per hit.
- Cleaning the derived index requires consent and it can be completely rebuilt.
- Versioned local snapshots are atomically persisted by project hashing outside the workspace.
- Missing, incompatible, or corrupted files are ignored and rebuilt by the next indexing.
- Project cleanup removes both the in-memory index and the corresponding persisted snapshot.
- Module notifiers mark the index as dirty on edit, save, rename and close.
- A scheduler applies debounce and performs the incremental update in the background.
- The notifier does not retain OTA interfaces and stops new schedules during shutdown.
- Events `Modified`, `AfterSave`, `ModuleRenamed` and `Destroyed` have integration tests
deterministic statements that confirm marking the index as changed.
- Smoke in Delphi 13 confirmed automatic package loading, MCP handshake, local indexing
initial and traceable search. Automated live buffer editing remains manual validation.
- Current baseline on Delphi 11, 12 and 13 Win32: 442/442 tests, no failures or leaks.

Gate:

- Search works offline.
- Traceable sources and reviews.
- Index can be rebuilt and removed.

## Phase 7: Consolidation

Add knowledge packs, versioned templates, hardening and release documentation.

Partial result:

- API level 1 extensions published without exposing the internal container.
- Batch logging is atomic and rejects collisions without leaving partially registered tools.
- Declared prefix delimits ownership of each extension's tools.
- Registration token removes tools before offloading external BPL.
- External tools reuse the core policy, consent, audit, and MCP pipeline.
- Standalone package `RadIASampleExtension` built on Delphi 11, 12 and 13 Win32 and Delphi 13
Win64.
- Extension guide and external example published.
- `build.ps1 -Package` generates self-contained ZIP with SHA-256 manifest and version-validated installer
and architecture.
- The installation flow now distributes the MCP bridge with the BPL.
- Release checklist separates completed automated gates from actual validations still pending.
- Centralized public version avoids divergence between About, MCP handshake, BPL resource and package.
- Migration preparatory notes document on-premises data, MCP, consent, extensions, and rollback.

Gate:

- Delphi matrix approved.
- Tested migrations.
- Stress and shutdown tests approved.
- Published extension documentation.
