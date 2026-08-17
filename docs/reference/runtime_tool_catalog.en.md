# RadIA built-in tool catalog

> Generated from the runtime manifest and Pascal tool descriptors. Do not edit manually. Run `scripts/Update-RadIA.RuntimeToolCatalog.ps1`.

This list contains only the built-in tools registered by the current package. Architecture ideas and roadmap items remain in `tool_catalog.md`.

## Workspace

| Tool | Purpose | Source unit |
|---|---|---|
| `GetIDEState` | Returns the active Delphi IDE version and capabilities. | `RadIA.Core.WorkspaceTools.pas` |
| `GetActiveProject` | Returns metadata for the active Delphi project. | `RadIA.Core.WorkspaceTools.pas` |
| `GetActiveUnit` | Returns the active Delphi unit name. | `RadIA.Core.WorkspaceTools.pas` |
| `ListOpenFiles` | Lists files currently open in the Delphi IDE. | `RadIA.Core.WorkspaceTools.pas` |
| `ListProjectUnits` | Lists units owned by the active Delphi project. | `RadIA.Core.WorkspaceTools.pas` |
| `GetEditorContent` | Returns the live active editor content with a revision. | `RadIA.Core.WorkspaceTools.pas` |
| `GetEditorSelection` | Returns the active editor selection and cursor position. | `RadIA.Core.WorkspaceTools.pas` |
| `GetCursorPosition` | Returns the active editor cursor position. | `RadIA.Core.WorkspaceTools.pas` |
| `GetCompilerMessages` | Returns structured compiler messages from the IDE. | `RadIA.Core.WorkspaceTools.pas` |

## Delphi environment

| Tool | Purpose | Source unit |
|---|---|---|
| `GetDelphiEnvironmentProfile` | Returns a sanitized profile of the active Delphi IDE and project. | `RadIA.Core.DelphiEnvironmentTools.pas` |

## Semantic code generation

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareMissingMembers` | Prepares an idempotent patch for indexed interface members missing from a class. | `RadIA.Core.SemanticMemberTools.pas` |

## Semantic index queries

| Tool | Purpose | Source unit |
|---|---|---|
| `GetSemanticContext` | Returns indexed declarations and resolved inherited members for a Delphi symbol. | `RadIA.Core.SemanticQueryTools.pas` |
| `FindSymbolReferences` | Finds confirmed Delphi symbol declarations and references. Ambiguous occurrences are excluded unless explicitly requested. | `RadIA.Core.SemanticQueryTools.pas` |

## Semantic type hierarchy

| Tool | Purpose | Source unit |
|---|---|---|
| `GetTypeHierarchy` | Returns indexed Delphi ancestors and descendants without changing code. | `RadIA.Core.SemanticHierarchyTools.pas` |

## Semantic refactoring

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareRenameSymbol` | Prepares an exact semantic Delphi symbol rename, optionally across a proven class hierarchy. | `RadIA.Core.SemanticRefactoringTools.pas` |

## Semantic signature refactoring

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareChangeSignature` | Prepares a transactional Delphi routine signature change across declarations, implementations, and calls. | `RadIA.Core.SemanticChangeSignatureTools.pas` |

## Semantic method extraction

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareExtractMethod` | Prepares a transactional Extract Method refactoring from the active Delphi selection. | `RadIA.Core.SemanticExtractMethodTools.pas` |

## Semantic type movement

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareMoveType` | Prepares a transactional Delphi type move between project units. | `RadIA.Core.SemanticMoveTypeTools.pas` |

## Unified Delphi code validation

| Tool | Purpose | Source unit |
|---|---|---|
| `ValidateDelphiCode` | Validates Delphi code with native, compiler, DelphiLint, and Sonar evidence. | `RadIA.Core.CodeValidationTools.pas` |

## Code validation fixes

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareCodeValidationFix` | Prepares a fingerprinted preview for a DelphiLint suggested fix. | `RadIA.Core.CodeValidationFixes.pas` |

## Curated Delphi guidance

| Tool | Purpose | Source unit |
|---|---|---|
| `GetDelphiGuidance` | Returns cited Delphi guidance filtered by environment and topic. | `RadIA.Core.DelphiGuidanceTools.pas` |

## DFM and Pascal consistency

| Tool | Purpose | Source unit |
|---|---|---|
| `AuditActiveDfmPasConsistency` | Audits the active DFM and Pascal pair without modifying either file. | `RadIA.Core.DfmPasAuditTools.pas` |
| `PrepareDfmPasAuditFix` | Prepares a reviewable Pascal patch for a supported DFM audit finding. | `RadIA.Core.DfmPasAuditTools.pas` |

## Designer visual diff

| Tool | Purpose | Source unit |
|---|---|---|
| `CaptureDesignerVisualSnapshot` | Captures a bounded in-memory snapshot of the active Form Designer. | `RadIA.Core.DesignerVisualDiffTools.pas` |
| `CompareDesignerVisualSnapshots` | Returns a timeline-ready before and after Designer comparison. | `RadIA.Core.DesignerVisualDiffTools.pas` |
| `DecideDesignerVisualDiff` | Accepts or rejects a visual comparison without mutating the Designer. | `RadIA.Core.DesignerVisualDiffTools.pas` |
| `ClearDesignerVisualDiffArtifacts` | Clears bounded in-memory Designer snapshots and comparisons. | `RadIA.Core.DesignerVisualDiffTools.pas` |

## Agent result recovery

| Tool | Purpose | Source unit |
|---|---|---|
| `GetToolResultSummary` | Return metadata for a complete agent tool result artifact. | `RadIA.Core.AgentResultTools.pas` |
| `GetToolResultRange` | Return a bounded range from a complete agent tool result artifact. | `RadIA.Core.AgentResultTools.pas` |

## Project health

| Tool | Purpose | Source unit |
|---|---|---|
| `GetProjectHealth` | Scores project health and recommends prioritized Delphi journeys. | `RadIA.Core.ProjectHealthTools.pas` |

## Installation health

| Tool | Purpose | Source unit |
|---|---|---|
| `GetInstallationHealth` | Diagnoses the effective route, CLI, MCP, terminal, chat, tools, and installation readiness. | `RadIA.Core.InstallationHealthTools.pas` |
| `RunInstallationDeepDiagnostic` | Runs consented CLI version and authentication probes plus external MCP handshakes. | `RadIA.Core.InstallationHealthTools.pas` |
| `GetRadIAStatus` | Returns a sanitized, filterable snapshot of RadIA configuration and readiness. | `RadIA.Core.InstallationHealthTools.pas` |

## IDE navigation and project graph

| Tool | Purpose | Source unit |
|---|---|---|
| `ListProjectGroupProjects` | Lists every project in the active Delphi project group. | `RadIA.Core.IDENavigationTools.pas` |
| `GetProjectDependencies` | Lists project dependencies configured by the active project group. | `RadIA.Core.IDENavigationTools.pas` |
| `GetUnitSymbols` | Lists declarations and source lines from the active unit. | `RadIA.Core.IDENavigationTools.pas` |
| `GetEditorSemanticContext` | Returns the active unit, symbol, imports, and nearby declarations. | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToFile` | Opens a source file owned by an open project and selects a position. | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToSymbol` | Moves the active editor to a declared symbol. | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToDevelopmentSurface` | Activates Code or Design from an explicit surface or development intent. | `RadIA.Core.IDENavigationTools.pas` |
| `ListIDEActions` | Lists available IDE actions from the safe allowlist. | `RadIA.Core.IDENavigationTools.pas` |
| `ExecuteIDEAction` | Executes a consented IDE action from the safe allowlist. | `RadIA.Core.IDENavigationTools.pas` |

## Patches

| Tool | Purpose | Source unit |
|---|---|---|
| `PreparePatch` | Prepares an immutable editor patch preview without changing the buffer. | `RadIA.Core.PatchTools.pas` |
| `ApplyPatch` | Applies a reviewed patch when the active buffer revision still matches. | `RadIA.Core.PatchTools.pas` |
| `RevertPatch` | Reverts an applied patch when the buffer still matches its proposed revision. | `RadIA.Core.PatchTools.pas` |

## Multi-file patches

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareMultiFilePatch` | Prepares one immutable preview for a multi-buffer edit transaction. | `RadIA.Core.MultiFilePatchTools.pas` |
| `ApplyMultiFilePatch` | Applies all reviewed buffer edits or compensates every partial write. | `RadIA.Core.MultiFilePatchTools.pas` |
| `RevertMultiFilePatch` | Reverts all applied buffer edits or restores the proposed transaction. | `RadIA.Core.MultiFilePatchTools.pas` |

## Block reviews

| Tool | Purpose | Source unit |
|---|---|---|
| `ListBlockReviews` | Lists revision-bound patch blocks and their pending review decisions. | `RadIA.Core.BlockReviewTools.pas` |
| `DecideBlockReview` | Records accept, reject, edit, or commented change requests without buffer mutation. | `RadIA.Core.BlockReviewTools.pas` |
| `ApplyBlockReviews` | Applies all resolved block decisions as one preconditioned multi-file transaction. | `RadIA.Core.BlockReviewTools.pas` |
| `ClearBlockReviews` | Discards the active review session without changing editor buffers. | `RadIA.Core.BlockReviewTools.pas` |

## Development transactions

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareDevelopmentTransaction` | Groups reviewed code, project, and Designer previews. | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `ApplyDevelopmentTransaction` | Applies all grouped operations with reverse-order compensation. | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `RevertDevelopmentTransaction` | Reverts all grouped operations with symmetric compensation. | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `RejectDevelopmentTransactionStep` | Rejects one pending step before the reviewed plan is applied. | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `RevertDevelopmentTransactionStep` | Reverts the latest applied step while preserving plan ordering. | `RadIA.Core.DevelopmentTransactionTools.pas` |

## Project templates

| Tool | Purpose | Source unit |
|---|---|---|
| `PreviewProjectTemplate` | Previews deterministic project files without changing the workspace. | `RadIA.Core.ProjectTemplateTools.pas` |
| `CreateProjectFromTemplate` | Creates the reviewed project atomically from an immutable preview. | `RadIA.Core.ProjectTemplateTools.pas` |
| `RevertCreatedProject` | Removes a project previously created from the same reviewed preview. | `RadIA.Core.ProjectTemplateTools.pas` |
| `OpenCreatedProject` | Opens a committed generated project in the Delphi IDE. | `RadIA.Core.ProjectTemplateTools.pas` |
| `ValidateCreatedProject` | Opens and builds a generated project, rolling it back on failure. | `RadIA.Core.ProjectTemplateTools.pas` |

## Project files

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareAddProjectFile` | Previews deterministic unit or form files without writing. | `RadIA.Core.ProjectFileTools.pas` |
| `PrepareRemoveProjectFile` | Previews unregistering a file without deleting it from disk. | `RadIA.Core.ProjectFileTools.pas` |
| `ApplyProjectFileChange` | Creates files before registration or unregisters without deletion. | `RadIA.Core.ProjectFileTools.pas` |
| `RevertProjectFileChange` | Reverts the reviewed project file structure change. | `RadIA.Core.ProjectFileTools.pas` |

## Safe productivity artifacts

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareApiDocumentation` | Previews deterministic API.md content from indexed public project symbols. | `RadIA.Core.ProductivityGenerationTools.pas` |
| `PrepareMockUnit` | Previews an isolated Pascal mock unit for an indexed interface. | `RadIA.Core.ProductivityGenerationTools.pas` |
| `ApplyGeneratedArtifact` | Creates one reviewed artifact and optionally registers a Pascal unit. | `RadIA.Core.ProductivityGenerationTools.pas` |
| `RevertGeneratedArtifact` | Removes an unchanged artifact created from the reviewed preview. | `RadIA.Core.ProductivityGenerationTools.pas` |

## Project stack trace diagnostics

| Tool | Purpose | Source unit |
|---|---|---|
| `AnalyzeProjectStackTrace` | Parses Delphi, MadExcept, or EurekaLog traces and resolves frames across project units. | `RadIA.Core.StackTraceTools.pas` |

## Clean uses analysis

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareCleanUses` | Prepares a conservative semantic preview that removes unused Pascal units. | `RadIA.Core.CleanUsesTools.pas` |

## Thread and PPL safety

| Tool | Purpose | Source unit |
|---|---|---|
| `AnalyzeThreadingRisks` | Detects VCL access, cancellation, and exception-handling risks in Delphi background work. | `RadIA.Core.ThreadingAssistantTools.pas` |
| `PrepareThreadModernization` | Validates safeguards and prepares a reviewable Delphi threading patch. | `RadIA.Core.ThreadingAssistantTools.pas` |

## Existing API OpenAPI retrofit

| Tool | Purpose | Source unit |
|---|---|---|
| `InventoryExistingApiRoutes` | Inventories existing DEXT minimal routes and controller attributes without changing the project. | `RadIA.Core.OpenApiRetrofitTools.pas` |
| `PrepareOpenApiRetrofit` | Prepares a reviewable Swagger integration patch for an existing DEXT startup unit. | `RadIA.Core.OpenApiRetrofitTools.pas` |

## DEXT and form modernization

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareDextFormModernization` | Validates migration, parity, DEXT boundaries, and DFM/Pascal consistency before a reversible patch. | `RadIA.Core.DextFormModernizationTools.pas` |
| `RecordDextFormModernizationGate` | Records build and test evidence and reverts the modernization when a gate fails. | `RadIA.Core.DextFormModernizationTools.pas` |

## Inline reviews

| Tool | Purpose | Source unit |
|---|---|---|
| `PublishInlineReview` | Publishes a revision-anchored review in the active editor. | `RadIA.Core.InlineReviewTools.pas` |
| `ListInlineReviews` | Lists reviews that match the active editor revision. | `RadIA.Core.InlineReviewTools.pas` |
| `PrepareInlineReviewFix` | Creates a reversible patch preview from a review suggestion. | `RadIA.Core.InlineReviewTools.pas` |
| `ApplyInlineReviewFix` | Applies one revision-anchored inline review suggestion. | `RadIA.Core.InlineReviewTools.pas` |
| `RejectInlineReview` | Rejects one inline review without changing the buffer. | `RadIA.Core.InlineReviewTools.pas` |
| `RemoveInlineReview` | Removes one inline review decoration. | `RadIA.Core.InlineReviewTools.pas` |
| `ClearInlineReviews` | Clears all RadIA inline review decorations. | `RadIA.Core.InlineReviewTools.pas` |

## Build

| Tool | Purpose | Source unit |
|---|---|---|
| `BuildProject` | Builds the active project without running its output. | `RadIA.Core.BuildTools.pas` |
| `CancelBuild` | Requests cancellation of the active background build. | `RadIA.Core.BuildTools.pas` |
| `GetBuildStatus` | Returns the current or most recent build status. | `RadIA.Core.BuildTools.pas` |

## Form Designer inspection

| Tool | Purpose | Source unit |
|---|---|---|
| `GetActiveForm` | Returns a snapshot of the active live Form Designer. | `RadIA.Core.DesignerTools.pas` |
| `ListFormComponents` | Lists components from the active live Form Designer. | `RadIA.Core.DesignerTools.pas` |

## Form Designer layout

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareComponentLayout` | Prepares an immutable preview for a component layout change. | `RadIA.Core.DesignerMutationTools.pas` |
| `ApplyComponentLayout` | Applies a reviewed layout change to the live Form Designer. | `RadIA.Core.DesignerMutationTools.pas` |
| `RevertComponentLayout` | Reverts an applied layout change when preconditions still match. | `RadIA.Core.DesignerMutationTools.pas` |

## Form Designer properties

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareComponentProperty` | Prepares an immutable preview for a safe component property change. | `RadIA.Core.DesignerPropertyTools.pas` |
| `ApplyComponentProperty` | Applies a reviewed property change to the live Form Designer. | `RadIA.Core.DesignerPropertyTools.pas` |
| `RevertComponentProperty` | Reverts an applied property change when preconditions still match. | `RadIA.Core.DesignerPropertyTools.pas` |

## Form Designer components

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareAddFormComponent` | Prepares a reviewed preview for adding an allowlisted VCL component. | `RadIA.Core.DesignerComponentTools.pas` |
| `PrepareRemoveFormComponent` | Prepares a reviewed preview for removing an allowlisted VCL component. | `RadIA.Core.DesignerComponentTools.pas` |
| `ApplyFormComponentChange` | Applies a reviewed component creation or removal. | `RadIA.Core.DesignerComponentTools.pas` |
| `RevertFormComponentChange` | Reverts an applied component creation or removal. | `RadIA.Core.DesignerComponentTools.pas` |

## Form Designer events

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareFormEventHandler` | Prepares an atomic source and Form Designer event handler preview. | `RadIA.Core.DesignerEventTools.pas` |
| `ApplyFormEventHandler` | Creates and binds a reviewed handler through the live Form Designer. | `RadIA.Core.DesignerEventTools.pas` |
| `RevertFormEventHandler` | Unbinds the handler and restores the reviewed Pascal source snapshot. | `RadIA.Core.DesignerEventTools.pas` |

## Debugger inspection

| Tool | Purpose | Source unit |
|---|---|---|
| `GetDebuggerState` | Returns a read-only snapshot of the IDE debugger. | `RadIA.Core.DebuggerTools.pas` |
| `ListBreakpoints` | Lists source breakpoints without changing debugger state. | `RadIA.Core.DebuggerTools.pas` |
| `GetCallStack` | Returns the current debugger thread call stack without changing execution. | `RadIA.Core.DebuggerTools.pas` |

## Debugger control

| Tool | Purpose | Source unit |
|---|---|---|
| `PauseDebugging` | Pauses the current debug process. | `RadIA.Core.DebuggerControlTools.pas` |
| `ContinueDebugging` | Continues the current stopped debug process. | `RadIA.Core.DebuggerControlTools.pas` |
| `StepInto` | Executes the next source statement and steps into calls. | `RadIA.Core.DebuggerControlTools.pas` |
| `StepOver` | Executes the next source statement without entering calls. | `RadIA.Core.DebuggerControlTools.pas` |
| `StepOut` | Continues until the current routine returns. | `RadIA.Core.DebuggerControlTools.pas` |
| `StopDebugging` | Terminates the current debug process. | `RadIA.Core.DebuggerControlTools.pas` |

## Debugger breakpoints

| Tool | Purpose | Source unit |
|---|---|---|
| `AddBreakpoint` | Adds a reviewed source breakpoint inside the active workspace. | `RadIA.Core.DebuggerBreakpointTools.pas` |
| `RemoveBreakpoint` | Removes an existing source breakpoint after explicit confirmation. | `RadIA.Core.DebuggerBreakpointTools.pas` |
| `GetAdvancedBreakpointCapabilities` | Reports reliable advanced breakpoint capabilities for Delphi 12 and 13. | `RadIA.Core.DebuggerBreakpointTools.pas` |
| `ConfigureBreakpoint` | Configures a conditional breakpoint, hit count, logpoint, or thread filter. | `RadIA.Core.DebuggerBreakpointTools.pas` |

## Debugger sessions and watches

| Tool | Purpose | Source unit |
|---|---|---|
| `EvaluateDebuggerExpression` | Evaluates an expression without debugger side effects. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `AddDebuggerWatch` | Adds an expression to the bounded RadIA watch list. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `RemoveDebuggerWatch` | Removes an expression from the RadIA watch list. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `ListDebuggerWatches` | Lists the bounded RadIA debugger watch expressions. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `EvaluateDebuggerWatches` | Evaluates all RadIA watches without side effects. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `StartDebugging` | Validates and queues the active project under the debugger without blocking the MCP request. | `RadIA.Core.DebuggerInspectionTools.pas` |

## Project knowledge

| Tool | Purpose | Source unit |
|---|---|---|
| `IndexProjectKnowledge` | Incrementally indexes local Delphi source files for offline search. | `RadIA.Core.KnowledgeTools.pas` |
| `SearchProjectKnowledge` | Searches the active project index and returns traceable source chunks. | `RadIA.Core.KnowledgeTools.pas` |
| `GetKnowledgeStatus` | Returns local index status and aggregate counts for the active project. | `RadIA.Core.KnowledgeTools.pas` |
| `GetKnowledgeDocument` | Returns bounded traceable chunks for one indexed project file. | `RadIA.Core.KnowledgeTools.pas` |
| `ClearProjectKnowledge` | Removes the derived local index for the active project. | `RadIA.Core.KnowledgeTools.pas` |

## DUnitX test runner

| Tool | Purpose | Source unit |
|---|---|---|
| `RunDUnitXTests` | Run a workspace-confined DUnitX executable and return its NUnit report. | `RadIA.Core.DUnitXTools.pas` |
| `CancelDUnitXTests` | Cancel the active DUnitX test process. | `RadIA.Core.DUnitXTools.pas` |
| `GetDUnitXStatus` | Return the current DUnitX runner status. | `RadIA.Core.DUnitXTools.pas` |

## Impact-based DUnitX tests

| Tool | Purpose | Source unit |
|---|---|---|
| `PlanImpactedDUnitXTests` | Explains the smallest safe DUnitX fixture set for workspace changes. | `RadIA.Core.TestImpactTools.pas` |
| `RunImpactedDUnitXTests` | Plans, explains, and runs impacted DUnitX fixtures or the full suite. | `RadIA.Core.TestImpactTools.pas` |

## Code coverage evidence

| Tool | Purpose | Source unit |
|---|---|---|
| `GetCoverageSummary` | Read an authoritative Delphi Code Coverage summary from the workspace. | `RadIA.Core.CoverageTools.pas` |

## Debugger event timeline

| Tool | Purpose | Source unit |
|---|---|---|
| `GetDebugTimeline` | Read debugger lifecycle events captured from RAD Studio notifications. | `RadIA.Core.DebugTimelineTools.pas` |

## Runtime debugger correlation

| Tool | Purpose | Source unit |
|---|---|---|
| `GetRuntimeDebugSession` | Return the correlated project, build, and debug process identity. | `RadIA.Core.RuntimeDebugTools.pas` |
| `WaitForDebuggerEvent` | Wait for a correlated debugger event and capture its call stack. | `RadIA.Core.RuntimeDebugTools.pas` |
| `CancelDebuggerWait` | Cancel the active debugger event wait immediately. | `RadIA.Core.RuntimeDebugTools.pas` |

## Runtime window discovery

| Tool | Purpose | Source unit |
|---|---|---|
| `GetRuntimeWindows` | List opaque windows confined to the active runtime debug session. | `RadIA.Core.RuntimeDiscoveryTools.pas` |
| `GetRuntimeControlTree` | Return safe selectors and capabilities for an authorized window. | `RadIA.Core.RuntimeDiscoveryTools.pas` |

## Bounded runtime scenarios

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareRuntimeScenario` | Validate and preview a bounded runtime scenario without executing it. | `RadIA.Core.RuntimeScenarioTools.pas` |
| `RunRuntimeScenario` | Execute one prepared runtime scenario after explicit consent. | `RadIA.Core.RuntimeScenarioTools.pas` |
| `CancelRuntimeScenario` | Immediately stop the active runtime scenario without consent. | `RadIA.Core.RuntimeScenarioTools.pas` |
| `GetRuntimeScenarioStatus` | Return progress and outcome for the current runtime scenario. | `RadIA.Core.RuntimeScenarioTools.pas` |

## Runtime visual capture

| Tool | Purpose | Source unit |
|---|---|---|
| `CaptureRuntimeVisual` | Capture a bounded PNG of one visible window owned by the active runtime process. | `RadIA.Core.RuntimeVisualTools.pas` |

## Runtime diagnostic evidence

| Tool | Purpose | Source unit |
|---|---|---|
| `CaptureRuntimeEvidence` | Capture sanitized session, scenario, exception, stack, and values. | `RadIA.Core.RuntimeEvidenceTools.pas` |
| `CompareRuntimeEvidence` | Compare failure and verification evidence across rebuilt sessions. | `RadIA.Core.RuntimeEvidenceTools.pas` |

## Versioned runtime regressions

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareRuntimeRegression` | Validate a replayable visual scenario and preview its artifact. | `RadIA.Core.RuntimeRegressionTools.pas` |
| `SaveRuntimeRegression` | Save the reviewed runtime regression under the active project. | `RadIA.Core.RuntimeRegressionTools.pas` |
| `RevertRuntimeRegression` | Restore or remove the artifact written by a regression save. | `RadIA.Core.RuntimeRegressionTools.pas` |
| `ListRuntimeRegressions` | List versioned visual regressions in the active project. | `RadIA.Core.RuntimeRegressionTools.pas` |
| `PrepareSavedRuntimeScenario` | Load a saved regression and prepare it for the current session. | `RadIA.Core.RuntimeRegressionTools.pas` |

## Reviewable local Git commits

| Tool | Purpose | Source unit |
|---|---|---|
| `GetGitStatus` | Return Git status scoped to the active Delphi project workspace. | `RadIA.Core.GitTools.pas` |
| `GetGitDiff` | Return an unstaged Git diff for workspace-confined paths. | `RadIA.Core.GitTools.pas` |
| `PreviewGitCommit` | Preview selected paths and freeze their fingerprint without staging. | `RadIA.Core.GitTools.pas` |
| `CommitChanges` | Create the reviewed local Git commit without pushing. | `RadIA.Core.GitTools.pas` |

## FastMM5 memory diagnostics

| Tool | Purpose | Source unit |
|---|---|---|
| `GetMemoryDiagnosticsStatus` | Checks FastMM5 configuration, version, license acknowledgement, and runtime library readiness. | `RadIA.Core.FastMM5.pas` |
| `ConfigureMemoryDiagnostics` | Stores the user-provided FastMM5 root and explicit license acknowledgement, then reports readiness. | `RadIA.Core.FastMM5.pas` |

## Reversible memory instrumentation

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareMemoryInstrumentation` | Previews reversible FastMM5 instrumentation for the active Debug project without changing its IDE buffer. | `RadIA.Core.MemoryInstrumentation.pas` |
| `ApplyMemoryInstrumentation` | Applies a fresh FastMM5 instrumentation preview to the live project source buffer. | `RadIA.Core.MemoryInstrumentation.pas` |
| `RevertMemoryInstrumentation` | Restores the exact project source captured before FastMM5 instrumentation. | `RadIA.Core.MemoryInstrumentation.pas` |

## Reversible VCL runtime instrumentation

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareRuntimeVclInstrumentation` | Previews reversible VCL runtime instrumentation for the active Debug project. | `RadIA.Core.RuntimeVclInstrumentation.pas` |
| `ApplyRuntimeVclInstrumentation` | Adds the reviewed runtime adapter units and starts them only in the instrumented application. | `RadIA.Core.RuntimeVclInstrumentation.pas` |
| `RevertRuntimeVclInstrumentation` | Removes unchanged runtime adapter units and restores the reviewed project source. | `RadIA.Core.RuntimeVclInstrumentation.pas` |

## Comparable runtime performance

| Tool | Purpose | Source unit |
|---|---|---|
| `BeginRuntimePerformanceMeasurement` | Starts bounded sampling for the active runtime session before a reviewed scenario. | `RadIA.Core.RuntimePerformance.pas` |
| `CompleteRuntimePerformanceMeasurement` | Stops sampling after a successful scenario and returns bounded evidence. | `RadIA.Core.RuntimePerformance.pas` |
| `CompareRuntimePerformanceEvidence` | Compares the same scenario across distinct runtime sessions and builds. | `RadIA.Core.RuntimePerformance.pas` |
| `CancelRuntimePerformanceMeasurement` | Cancels active performance sampling without producing evidence. | `RadIA.Core.RuntimePerformance.pas` |

## FireDAC query diagnostics

| Tool | Purpose | Source unit |
|---|---|---|
| `AnalyzeFireDACQuery` | Analyzes bounded SQL text without connecting to or querying a database. | `RadIA.Core.FireDAC.Tools.pas` |
| `ValidateFireDACParameters` | Validates FireDAC binding names, types, directions, sizes, and null state without executing SQL. | `RadIA.Core.FireDAC.Tools.pas` |
| `ExplainFireDACQuery` | Structures deterministic SQL facts, hypotheses, and limitations for AI explanation. | `RadIA.Core.FireDAC.Tools.pas` |
| `ExplainFireDACFinding` | Structures a FireDAC finding for AI explanation without accepting evidence or secret values. | `RadIA.Core.FireDAC.Tools.pas` |

## Delphi ecosystem diagnostics

| Tool | Purpose | Source unit |
|---|---|---|
| `InspectFireDACUsage` | Returns the structured FireDAC project inventory while preserving legacy usage counters. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `InspectFireDACProject` | Inventories FireDAC components and relationships in bounded PAS and DFM files without executing SQL. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `GetFireDACProjectReport` | Returns a bounded FireDAC inventory and sanitized embedded SQL analysis without execution. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `AuditFireDACTransactions` | Audits bounded Pascal transaction flows without executing SQL or connecting to a database. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `InspectFireDACConfiguration` | Inspects bounded FireDAC configuration while discarding credentials and absolute paths. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `DiagnoseFireDACEnvironment` | Diagnoses static FireDAC driver configuration without connections or installation. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `AnalyzeFireDACThreadSafety` | Finds shared FireDAC components and unsafe UI access in bounded background contexts. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `DiagnoseDelphiDependencies` | Diagnoses Delphi project search paths and dependency manifests without installing anything. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `AuditDelphiLocalization` | Inventories user-visible Pascal and DFM literals for localization review. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `PrepareLocalizationExtraction` | Prepares an immutable patch that moves one active-unit literal to resourcestring. | `RadIA.Core.DelphiEcosystemTools.pas` |

## Safe local database inspection

| Tool | Purpose | Source unit |
|---|---|---|
| `InspectLocalSQLiteDatabase` | Reads tables, views, and columns from a workspace-local SQLite database without executing user SQL. | `RadIA.Core.LocalDatabaseTools.pas` |
| `PreviewLocalSQLiteQuery` | Runs one reviewed read-only SQLite query with bounded rows and sanitized grid and CSV output. | `RadIA.Core.LocalDatabaseTools.pas` |
| `CompareFireDACCodeWithSchema` | Compares typed FireDAC expectations with an authorized workspace-local SQLite schema. | `RadIA.Core.LocalDatabaseTools.pas` |
| `GenerateFireDACSchemaReport` | Generates a sanitized FireDAC-oriented report from a workspace-local SQLite schema. | `RadIA.Core.LocalDatabaseTools.pas` |

## FastMM5 log evidence

| Tool | Purpose | Source unit |
|---|---|---|
| `ParseMemoryDiagnosticLog` | Parses a bounded FastMM5 log inside the active workspace into structured, fingerprinted memory events. | `RadIA.Core.FastMM5LogParser.pas` |

## Composed memory diagnostic sessions

| Tool | Purpose | Source unit |
|---|---|---|
| `PrepareMemoryDiagnosticSession` | Previews an instrumented FastMM5 runtime scenario with warmup and measured repetitions. | `RadIA.Core.MemoryDiagnosticSession.pas` |
| `RunMemoryDiagnosticSession` | Builds, debugs, reproduces, stops, parses, and reverts a prepared memory diagnostic. | `RadIA.Core.MemoryDiagnosticSession.pas` |
| `CancelMemoryDiagnosticSession` | Cancels the active memory diagnostic, debugger, build, and runtime scenario. | `RadIA.Core.MemoryDiagnosticSession.pas` |
| `GetMemoryDiagnosticSessionStatus` | Returns the current composed memory diagnostic phase and cancellation state. | `RadIA.Core.MemoryDiagnosticSession.pas` |

## Delphi mentor

| Tool | Purpose | Source unit |
|---|---|---|
| `ExplainSelectedDelphiCode` | Builds a level-aware explanation anchored to selected Delphi code and cited rules. | `RadIA.Core.DelphiMentor.pas` |

## Legacy data migration

| Tool | Purpose | Source unit |
|---|---|---|
| `InventoryLegacyDataAccess` | Inventories BDE, ADO and dbExpress references in the active project. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `PlanLegacyMigrationBatches` | Groups legacy data findings into bounded technology and file batches. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `PrepareLegacyMigrationBatch` | Prepares a reversible preview for deterministic changes in one batch. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `RecordLegacyMigrationGate` | Records build and test evidence, reverting a failed applied batch. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `GetLegacyMigrationReport` | Reports batch compatibility, gate evidence and required manual actions. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `PlanDextAndFormModernization` | Plans DEXT adoption and form decomposition after data migration. | `RadIA.Core.LegacyDataMigrationTools.pas` |

## Memory evidence correction workflow

| Tool | Purpose | Source unit |
|---|---|---|
| `CompareMemoryDiagnosticEvidence` | Compares two independent memory sessions and classifies the result. | `RadIA.Core.MemoryEvidence.pas` |
| `PrepareMemoryDiagnosticFix` | Selects the first project allocation frame for a reviewable patch. | `RadIA.Core.MemoryEvidence.pas` |

## Summary

- Registered groups: 65
- Registered built-in tools: 199
- Extensions can register additional tools at runtime.
- The `/tools` command remains authoritative for the active IDE instance.
