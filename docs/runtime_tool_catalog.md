# RadIA built-in tool catalog

> Generated from `docs/runtime_tools.json`. Do not edit manually. Run `scripts/Update-RadIA.RuntimeToolCatalog.ps1`.

This list contains only the built-in tools registered by the current package. Architecture ideas and roadmap items remain in `tool_catalog.md`.

## Workspace

| Tool | Source unit |
|---|---|
| `GetIDEState` | `RadIA.Core.WorkspaceTools.pas` |
| `GetActiveProject` | `RadIA.Core.WorkspaceTools.pas` |
| `GetActiveUnit` | `RadIA.Core.WorkspaceTools.pas` |
| `ListOpenFiles` | `RadIA.Core.WorkspaceTools.pas` |
| `ListProjectUnits` | `RadIA.Core.WorkspaceTools.pas` |
| `GetEditorContent` | `RadIA.Core.WorkspaceTools.pas` |
| `GetEditorSelection` | `RadIA.Core.WorkspaceTools.pas` |
| `GetCursorPosition` | `RadIA.Core.WorkspaceTools.pas` |
| `GetCompilerMessages` | `RadIA.Core.WorkspaceTools.pas` |

## Project health

| Tool | Source unit |
|---|---|
| `GetProjectHealth` | `RadIA.Core.ProjectHealthTools.pas` |

## Installation health

| Tool | Source unit |
|---|---|
| `GetInstallationHealth` | `RadIA.Core.InstallationHealthTools.pas` |

## IDE navigation and project graph

| Tool | Source unit |
|---|---|
| `ListProjectGroupProjects` | `RadIA.Core.IDENavigationTools.pas` |
| `GetProjectDependencies` | `RadIA.Core.IDENavigationTools.pas` |
| `GetUnitSymbols` | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToFile` | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToSymbol` | `RadIA.Core.IDENavigationTools.pas` |
| `ListIDEActions` | `RadIA.Core.IDENavigationTools.pas` |
| `ExecuteIDEAction` | `RadIA.Core.IDENavigationTools.pas` |

## Patches

| Tool | Source unit |
|---|---|
| `PreparePatch` | `RadIA.Core.PatchTools.pas` |
| `ApplyPatch` | `RadIA.Core.PatchTools.pas` |
| `RevertPatch` | `RadIA.Core.PatchTools.pas` |

## Multi-file patches

| Tool | Source unit |
|---|---|
| `PrepareMultiFilePatch` | `RadIA.Core.MultiFilePatchTools.pas` |
| `ApplyMultiFilePatch` | `RadIA.Core.MultiFilePatchTools.pas` |
| `RevertMultiFilePatch` | `RadIA.Core.MultiFilePatchTools.pas` |

## Development transactions

| Tool | Source unit |
|---|---|
| `PrepareDevelopmentTransaction` | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `ApplyDevelopmentTransaction` | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `RevertDevelopmentTransaction` | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `RejectDevelopmentTransactionStep` | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `RevertDevelopmentTransactionStep` | `RadIA.Core.DevelopmentTransactionTools.pas` |

## Project templates

| Tool | Source unit |
|---|---|
| `PreviewProjectTemplate` | `RadIA.Core.ProjectTemplateTools.pas` |
| `CreateProjectFromTemplate` | `RadIA.Core.ProjectTemplateTools.pas` |
| `RevertCreatedProject` | `RadIA.Core.ProjectTemplateTools.pas` |
| `OpenCreatedProject` | `RadIA.Core.ProjectTemplateTools.pas` |
| `ValidateCreatedProject` | `RadIA.Core.ProjectTemplateTools.pas` |

## Project files

| Tool | Source unit |
|---|---|
| `PrepareAddProjectFile` | `RadIA.Core.ProjectFileTools.pas` |
| `PrepareRemoveProjectFile` | `RadIA.Core.ProjectFileTools.pas` |
| `ApplyProjectFileChange` | `RadIA.Core.ProjectFileTools.pas` |
| `RevertProjectFileChange` | `RadIA.Core.ProjectFileTools.pas` |

## Inline reviews

| Tool | Source unit |
|---|---|
| `PublishInlineReview` | `RadIA.Core.InlineReviewTools.pas` |
| `ListInlineReviews` | `RadIA.Core.InlineReviewTools.pas` |
| `PrepareInlineReviewFix` | `RadIA.Core.InlineReviewTools.pas` |
| `RemoveInlineReview` | `RadIA.Core.InlineReviewTools.pas` |
| `ClearInlineReviews` | `RadIA.Core.InlineReviewTools.pas` |

## Build

| Tool | Source unit |
|---|---|
| `BuildProject` | `RadIA.Core.BuildTools.pas` |
| `CancelBuild` | `RadIA.Core.BuildTools.pas` |
| `GetBuildStatus` | `RadIA.Core.BuildTools.pas` |

## Form Designer inspection

| Tool | Source unit |
|---|---|
| `GetActiveForm` | `RadIA.Core.DesignerTools.pas` |
| `ListFormComponents` | `RadIA.Core.DesignerTools.pas` |

## Form Designer layout

| Tool | Source unit |
|---|---|
| `PrepareComponentLayout` | `RadIA.Core.DesignerMutationTools.pas` |
| `ApplyComponentLayout` | `RadIA.Core.DesignerMutationTools.pas` |
| `RevertComponentLayout` | `RadIA.Core.DesignerMutationTools.pas` |

## Form Designer properties

| Tool | Source unit |
|---|---|
| `PrepareComponentProperty` | `RadIA.Core.DesignerPropertyTools.pas` |
| `ApplyComponentProperty` | `RadIA.Core.DesignerPropertyTools.pas` |
| `RevertComponentProperty` | `RadIA.Core.DesignerPropertyTools.pas` |

## Form Designer components

| Tool | Source unit |
|---|---|
| `PrepareAddFormComponent` | `RadIA.Core.DesignerComponentTools.pas` |
| `PrepareRemoveFormComponent` | `RadIA.Core.DesignerComponentTools.pas` |
| `ApplyFormComponentChange` | `RadIA.Core.DesignerComponentTools.pas` |
| `RevertFormComponentChange` | `RadIA.Core.DesignerComponentTools.pas` |

## Form Designer events

| Tool | Source unit |
|---|---|
| `PrepareFormEventHandler` | `RadIA.Core.DesignerEventTools.pas` |
| `ApplyFormEventHandler` | `RadIA.Core.DesignerEventTools.pas` |
| `RevertFormEventHandler` | `RadIA.Core.DesignerEventTools.pas` |

## Debugger inspection

| Tool | Source unit |
|---|---|
| `GetDebuggerState` | `RadIA.Core.DebuggerTools.pas` |
| `ListBreakpoints` | `RadIA.Core.DebuggerTools.pas` |
| `GetCallStack` | `RadIA.Core.DebuggerTools.pas` |

## Debugger control

| Tool | Source unit |
|---|---|
| `PauseDebugging` | `RadIA.Core.DebuggerControlTools.pas` |
| `ContinueDebugging` | `RadIA.Core.DebuggerControlTools.pas` |
| `StepInto` | `RadIA.Core.DebuggerControlTools.pas` |
| `StepOver` | `RadIA.Core.DebuggerControlTools.pas` |
| `StepOut` | `RadIA.Core.DebuggerControlTools.pas` |
| `StopDebugging` | `RadIA.Core.DebuggerControlTools.pas` |

## Debugger breakpoints

| Tool | Source unit |
|---|---|
| `AddBreakpoint` | `RadIA.Core.DebuggerBreakpointTools.pas` |
| `RemoveBreakpoint` | `RadIA.Core.DebuggerBreakpointTools.pas` |

## Debugger sessions and watches

| Tool | Source unit |
|---|---|
| `EvaluateDebuggerExpression` | `RadIA.Core.DebuggerInspectionTools.pas` |
| `AddDebuggerWatch` | `RadIA.Core.DebuggerInspectionTools.pas` |
| `RemoveDebuggerWatch` | `RadIA.Core.DebuggerInspectionTools.pas` |
| `ListDebuggerWatches` | `RadIA.Core.DebuggerInspectionTools.pas` |
| `EvaluateDebuggerWatches` | `RadIA.Core.DebuggerInspectionTools.pas` |
| `StartDebugging` | `RadIA.Core.DebuggerInspectionTools.pas` |

## Project knowledge

| Tool | Source unit |
|---|---|
| `IndexProjectKnowledge` | `RadIA.Core.KnowledgeTools.pas` |
| `SearchProjectKnowledge` | `RadIA.Core.KnowledgeTools.pas` |
| `GetKnowledgeStatus` | `RadIA.Core.KnowledgeTools.pas` |
| `GetKnowledgeDocument` | `RadIA.Core.KnowledgeTools.pas` |
| `ClearProjectKnowledge` | `RadIA.Core.KnowledgeTools.pas` |

## DUnitX test runner

| Tool | Source unit |
|---|---|
| `RunDUnitXTests` | `RadIA.Core.DUnitXTools.pas` |
| `CancelDUnitXTests` | `RadIA.Core.DUnitXTools.pas` |
| `GetDUnitXStatus` | `RadIA.Core.DUnitXTools.pas` |

## Code coverage evidence

| Tool | Source unit |
|---|---|
| `GetCoverageSummary` | `RadIA.Core.CoverageTools.pas` |

## Debugger event timeline

| Tool | Source unit |
|---|---|
| `GetDebugTimeline` | `RadIA.Core.DebugTimelineTools.pas` |

## Reviewable local Git commits

| Tool | Source unit |
|---|---|
| `GetGitStatus` | `RadIA.Core.GitTools.pas` |
| `GetGitDiff` | `RadIA.Core.GitTools.pas` |
| `PreviewGitCommit` | `RadIA.Core.GitTools.pas` |
| `CommitChanges` | `RadIA.Core.GitTools.pas` |

## Resumo

- Registered groups: 25
- Registered built-in tools: 92
- Extensions can register additional tools at runtime.
- The `/tools` command remains authoritative for the active IDE instance.
