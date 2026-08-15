# Agentive Tools Home Catalog

> This document describes the target architecture and includes roadmap items. To the verifiable list
> of the tools actually registered by the current package, see the
> [runtime generated catalog](../reference/runtime_tool_catalog.en.md). In the IDE, `/tools` remains the final source,
> as extensions can dynamically add tools.

## 1. Conventions

Public tool names are stable, in English, and use `PascalCase`. A change
incompatible arguments or results require a new version of the contract.

Each tool must declare:

- Category.
- Risk level.
- Capacity required.
- Input and output scheme.
- Response threshold.
- Idempotence.
- Timeout.
- Possible effects.

### Visual Intent Contract

Every successful execution that returns a JSON object receives the reserved field `_radiaView`. That
field allows chat, MCP and future visual surfaces to choose the same presentation without
know the particular rules of each tool:

```json
{
  "_radiaView": {
    "version": 1,
    "kind": "explorer",
    "action": "show_explorer",
    "sourceTool": "ListProjectUnits"
  }
}
```

The current types are `details`, `explorer`, `editor_navigation`, `diff`, and `activity`. Results of
error, arrays and truncated content are preserved. Customers who do not implement views may
ignore `_radiaView`; the remainder of the contract remains compatible.

|Tool family|Suggested view|
|---|---|
|File or symbol navigation|Editor|
|Preview, patch and Git diff|Diff|
|Build, test, debug and timeline|Activity|
|Project, units, symbols and status of the IDE|Explorer|
|Other tools|Details|

## 2. Initial slice

These tools form the first read-only increment:

|Tool|Main result|Risk|
|---|---|---|
|`GetIDEState`|Version, platform, shutdown status and capabilities|Read only|
|`GetActiveProject`|Design, path, configuration and platform|Read only|
|`ListProjectUnits`|Active project units|Read only|
|`GetActiveUnit`|Active unit and file|Read only|
|`ListOpenFiles`|Files opened in the IDE|Read only|
|`GetEditorContent`|Live content from the editor|Read only|
|`GetEditorSelection`|Selection and position|Read only|
|`GetCursorPosition`|Row and column|Read only|
|`GetCompilerMessages`|Structured errors and warnings|Read only|
|`FindInProject`|Scope-limited occurrences|Read only|

The returned content must indicate truncation, original size and revision/hash where applicable.

## 3. Editor

### Reading

- `GetEditorContent`
- `GetEditorSelection`
- `GetCursorPosition`
- `GetEditorLine`
- `ListOpenFiles`
- `FindInEditor`
- `FindInProject`
- `GetUnitSymbols`
- `GetEditorSemanticContext`
- `NavigateToFile`
- `NavigateToSymbol`

### Reversible writing

- `PreparePatch`
- `ApplyPatch`
- `RevertPatch`
- `InsertCodeAtCursor`
- `ReplaceEditorSelection`
- `ApplyTextPatch`
- `AddToUses`
- `RemoveFromUses`
- `SaveActiveFile`
- `SaveAllFiles`
- `UndoAgentChange`

All writes must use buffer revision as a precondition.

The implemented flow uses `PreparePatch` to generate an immutable preview with no effects,
`ApplyPatch` to apply only after consent and atomic revalidation, and `RevertPatch`
to restore the original content when the produced revision is still active.

### Inline review

- `PublishInlineReview`
- `ListInlineReviews`
- `PrepareInlineReviewFix`
- `ApplyInlineReviewFix`
- `RejectInlineReview`
- `RemoveInlineReview`
- `ClearInlineReviews`

Revisions are limited to 128 items, anchored to the file, full buffer hash, and range.
lines. The notifier supported in Delphi 12 and 13 underlines lines according to severity and
shows the message in the editor status. If the buffer changes, the revision stops rendering.
Suggestions do not write code directly: `PrepareInlineReviewFix` creates a preview in the service
patches, which remains subject to consent, preconditions, and rollback.
Direct applications are limited to 20 lines and 4,096 characters; above that, the result signals
`requiresSmartDiff` and the decision occurs on the full diff surface. Multi-file changes use
the transactional tools `PrepareMultiFilePatch`, `ApplyMultiFilePatch` and
`RevertMultiFilePatch`.

## 4. Project and project group

### Reading

- `GetActiveProject`
- `ListProjects`
- `ListProjectUnits`
- `GetProjectMetadata`
- `ListProjectConfigurations`
- `ListProjectPlatforms`
- `GetProjectSearchPath`
- `GetConditionalDefines`
- `GetProjectOutputPaths`
- `GetProjectDependencies`
- `ListProjectGroupProjects`

The tools above now directly use the project group and the OTA dependency graph. The navigation
per file only accepts files belonging to open projects; symbol navigation uses the buffer
I live from the active unit.

### IDE Safe Shares

- `ListIDEActions`
- `ExecuteIDEAction`

`ListIDEActions` returns only actions present in a navigation and viewing allowlist.
`ExecuteIDEAction` is classified as enforcement, requires consent, and refuses names outside this list.

### Structural writing

- `SetActiveConfiguration`
- `SetActivePlatform`
- `AddUnitToProject`
- `RemoveUnitFromProject`
- `CreateUnit`
- `CreateProjectFromTemplate`
- `SetProjectSearchPath`
- `SetConditionalDefines`
- `SetProjectOutputPath`

Changes to `.dproj`, `.dpr`, or `.groupproj` must produce preview and reversible logical backup.

## 5. Build and run

- `CompileProject`
- `BuildProject`
- `CleanProject`
- `CancelBuild`
- `GetBuildStatus`
- `GetCompilerMessages`
- `RunWithDebugger`
- `RunWithoutDebugger`
- `StopRunningProject`

Build does not equate to authorization to run binaries. Execution has its own consent.

The implemented `BuildProject` supports the `make`, `build`, `check` and `clean` modes, runs in
background by OTA and does not start the produced binary. `CancelBuild` and timeout only act on
background compilation currently controlled by RadIA.

## 6. Debugger

### Reading

- `GetDebuggerState`
- `GetCallStack`
- `EvaluateDebuggerExpression`
- `ListDebuggerWatches`
- `EvaluateDebuggerWatches`
- `ListBreakpoints`
- `GetCurrentExecutionLocation`

Implemented: `GetDebuggerState`, `ListBreakpoints`, `GetCallStack`, `EvaluateDebuggerExpression`,
`ListDebuggerWatches` and `EvaluateDebuggerWatches`. Operations are only
reading, executed on the main thread and return snapshots without retaining debugger interfaces.
The stack is only consulted when the OTA declares secure access and the access window closes in
`finally`.

Locals and other expressions in the current frame are queried by the OTA public evaluator with
`eseNone`, which prohibits calls, getters, and other side effects. The OTA does not publish an API for
enumerate the internal Locals/Watch window; That's why RadIA maintains its own list, limited to 32
expressions of up to 256 characters, and reevaluated by the current thread.

### Control

- `StartDebugging`
- `PauseDebugging`
- `StepInto`
- `StepOver`
- `StepOut`
- `ContinueDebugging`
- `StopDebugging`
- `AddBreakpoint`
- `RemoveBreakpoint`
- `AddDebuggerWatch`
- `RemoveDebuggerWatch`

Implemented: `PauseDebugging`, `ContinueDebugging`, `StepInto`, `StepOver`, `StepOut` and
`StopDebugging`. Each action validates the current state, uses only the public OTA, is non-idempotent, and
requires consent and auditing before reaching the adapter. Pause, continuation and steps have
risk `Execution`; termination has risk `Destructive` and never reuses session permission.
`AddBreakpoint` accepts only Pascal fonts within the workspace, rejects duplicates and reports
`RemoveBreakpoint` as reverse operation. `RemoveBreakpoint` requires destructive commit across
call. `StartDebugging` uses the IDE's official **Run** action, which recompiles when necessary, and
starts only the produced `TargetName`, without accepting an arbitrary executable path. The call
validates and queues the action, returns `starting` without tying the MCP request to the debugger
loop, and must be followed with `GetRuntimeDebugSession` and `WaitForDebuggerEvent` while running.
Use `GetDebuggerState` before starting or after a stop. The watch list is bounded internal state,
and its changes use structural consent.

## 7. Form Designer

### Reading

- `GetActiveForm`
- `ListFormComponents`
- `GetFormProperties`
- `GetComponentProperties`
- `CaptureActiveForm`
- `GetLiveFormText`

Initially implemented: `GetActiveForm` and `ListFormComponents`. They both read the Living Designer
via OTA, return snapshots and do not retain IDE interfaces or components.

The first changeable cycle is available by `PrepareComponentLayout`, `ApplyComponentLayout` and
`RevertComponentLayout`. The preview records original and proposed bounds; application and reversal
revalidate form, component and geometry immediately before the change.

Published scalar properties have the same cycle by `PrepareComponentProperty`,
`ApplyComponentProperty` and `RevertComponentProperty`. The adapter only accepts properties
writable with simple types, rejects `Name`, events and object references, revalidates value and type
before writing and tries to restore the original value if the application fails. Property names
associated with a password, secret, token, API key or connection string are also refused.

Creation and removal use `PrepareAddFormComponent`, `PrepareRemoveFormComponent`,
`ApplyFormComponentChange` and `RevertFormComponentChange`. The preview maintains class, name, parent and
geometry; the application revalidates the live form and the rollback performs the reverse operation. This
first version only accepts VCL controls from an explicit allowlist and requires explicit parent.

### Mutation

- `OpenFormDesigner`
- `OpenCodeEditor`
- `AddFormComponent` (implemented by preview cycle)
- `RemoveFormComponent` (implemented by preview cycle)
- `SetFormProperty`
- `SetComponentProperty`
- `MoveFormComponent`
- `ResizeFormComponent`
- `AddEventHandler` (implemented by preview cycle)

`PrepareFormEventHandler`, `ApplyFormEventHandler` and `RevertFormEventHandler` form a transaction
between the Pascal buffer and the live Form Designer. The signature is created by `IDesigner`, preserving the
actual type of event. Apply and rollback require binding and full buffer snapshot still
match the preview; User concurrent code is never silently overwritten.

## 8. Git

### Reading

- `GetGitStatus`
- `GetGitDiff`
- `GetCurrentBranch`
- `GetRecentCommits`

### Mutation

- `PreviewGitCommit`
- `CommitChanges`

`GetGitStatus`, `GetGitDiff`, `PreviewGitCommit` and `CommitChanges` are implemented. The preview
does not change the index and freezes paths, message, diff and fingerprint. The commit requires index initially
clean, revalidates the fingerprint and adds only the revised paths. No tools provided
destructive reset, unrestricted discard, or push.

## 9. Knowledge

- `IndexProjectKnowledge`
- `SearchProjectKnowledge`
- `ClearProjectKnowledge`
- `GetKnowledgeStatus`
- `GetKnowledgeDocument`

The five tools are implemented. Indexing is incremental and local; the search returns chunks
traceable; status exposes only aggregated counts; document reading returns content
limited with file, review and lines; cleaning removes only reconstructable derived data.

The lexical index now has optional local persistence by design. The snapshot is versioned,
atomically recorded under the RadIA data folder and identified by the project's SHA-256 hash.
Invalid or incompatible content is not loaded; the following indexing rebuilds it. The cleaning
removes memory and derived file without changing any workspace sources.

Edit, save, rename and close notifications only mark the project as changed. One
scheduler with debounce starts the incremental update in the background, maintains only indexes and
scalar identities of modules and stops scheduling work as soon as shutdown is detected.

Results must cite relevant file, symbol, revision and range.

## 10. Audit

- `QueryAuditLog`
- `GetAgentChanges`
- `GetPendingReviews`

The audit should not return secrets removed during sanitization.

## 11. Implementation order

1. Reading IDE, project and editor.
2. Build reading.
3. Security pipeline.
4. Patches and review.
5. Controlled build.
6. MCP.
7. Designer.
8. Debugger.
9. Knowledge.
10. Mutable Git.
11. Additional extensions per versioned contract.

## 12. Local extensions

Trusted packages can register additional tools via `IRadIAToolExtension`. The host receives
batch by a limited registrar, validate schemas, names, API version, prefix and collisions, and publish
all tools atomically.

External tools do not have an alternative execution path: chat and MCP continue to use the
central enforcer of policy, consent, audit and opt-out. The release of the token
`IRadIAToolExtensionRegistration` removes only tools belonging to the extension.

See `docs/tool_extension_guide.md` and the package at `Examples/ToolExtension`.

## 13. Criteria for adding a tool

A new tool only enters the registry when:

- Have a documented contract.
- Have testable fake implementation.
- Declare risk and effects.
- Validate all arguments.
- Respect workspace limits.
- Sanitize result and errors.
- Have cancellation testing when performing time-consuming work.
- Have defined behavior for shutdown.
- Indicate support by IDE version.
