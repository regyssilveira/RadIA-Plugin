# Operational reference of internal tools

This page explains RadIA's 132 internal tools: what each one does and at what stage
it is usually triggered.

The [generated catalog](runtime_tool_catalog.en.md) remains the technical source for registered names.
In the IDE, `/tools` is the final source because extensions and context can change the available list.

## How a tool is activated

A tool can be called in four ways:

1. **Agent mode:** the runtime chooses the tool necessary to fulfill the approved plan.
2. **Command `/tool`:** the user calls directly, for example `/tool GetIDEState`.
3. **MCP:** A local client runs `tools/call` after querying `tools/list`.
4. **Internal flow:** a RadIA visual action or composite step uses the same tool.

Reading tools typically run without confirmation. Writing, build, testing, Git,
Designer and debugger go through the risk policy and can request consent.

Groups with `Prepare`, `Apply` and `Revert` follow this cycle:

- `Prepare`: creates a preview and does not change the project;
- `Apply`: revalidates preconditions, requests consent when necessary and makes the change effective;
- `Revert`: undoes an application that is still valid and may also require consent.

## Workspace and editor

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetIDEState`|Returns version, architecture and general state of the IDE.|At the beginning of an objective or when the agent needs to check current Delphi capabilities.|
|`GetActiveProject`|Identifies the active project and its authorized path.|Before design, build, test, Git, or generation operations.|
|`GetActiveUnit`|Identifies the active unit in the editor.|When the request refers to the file or code the user is viewing.|
|`ListOpenFiles`|Lists open files and available buffers.|To locate live context or avoid reading an outdated copy of the disk.|
|`ListProjectUnits`|Lists the units belonging to the active project.|In architectural analysis, dependency search and multi-file planning.|
|`GetEditorContent`|Reads the live contents of an IDE buffer.|Before analyzing or preparing a change, including when there are unsaved changes.|
|`GetEditorSelection`|Reads the current editor selection.|In actions directed at a snippet, such as explaining, reviewing, testing or refactoring.|
|`GetCursorPosition`|Returns cursor file, row and column.|To contextualize errors, symbols, insertions and anchored revisions.|
|`GetCompilerMessages`|Collects structured errors and warnings.|After a build or when the objective involves fixing build failures.|

## Recovering compressed results

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetToolResultSummary`|Returns hash, size and step of an integral result preserved by the agent.|When a compressed step reports a `artifactId` and the agent needs to verify its identity before retrieving content.|
|`GetToolResultRange`|Retrieves a limited range of the full result without rerunning the original tool.|When the compressed context omitted a necessary piece of build, test, diff, or other stored result.|

## Project and installation health

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetProjectHealth`|Consolidates configuration, build, messages, tests and maintenance signals from the active project.|At the beginning of a journey, before proposing improvements or to confirm that the project is ready to move forward.|
|`GetInstallationHealth`|Diagnoses the effective route, provider, CLI, MCP, terminal, chat, tools, and installation.|After installing or updating, during onboarding, or when a capability does not work.|
|`RunInstallationDeepDiagnostic`|Runs sanitized effective-CLI version/authentication probes and temporary external MCP handshakes.|Through `/doctor --deep`, after explicit consent, when the local diagnostic does not explain a real failure.|
|`GetRadIAStatus`|Returns a sanitized, filterable inventory of current RadIA configuration, availability, and readiness.|Using the command `/status`, when checking an installation or before providing configuration and support guidance.|
|`GetMemoryDiagnosticsStatus`|Checks FastMM5 directory, version, license acceptance and diagnostic DLL for current platform.|Before starting a memory diagnostic or when investigating why the resource is not ready.|
|`ConfigureMemoryDiagnostics`|Saves the user-supplied directory and explicit acceptance of the FastMM5 license, returning the resulting readiness.|Via the configuration wizard or by direct call after structural consent.|
|`PrepareMemoryInstrumentation`|Creates a preview with fingerprint to insert FastMM5 first into the project and enable diagnostics only in Debug.|Before changing the DPR, after confirming that FastMM5, platform and configuration are ready.|
|`ApplyMemoryInstrumentation`|Revalidates the fingerprint and applies the preview to the DPR live buffer with IDE Undo support.|After user structural review and consent, before diagnostic build.|
|`RevertMemoryInstrumentation`|Restore exactly the contents of the DPR captured before instrumentation.|At the end of a temporary session, on cancellations, and when the user undoes persistent instrumentation.|
|`ParseMemoryDiagnosticLog`|Interprets a limited and authorized FastMM5 log, grouping events, bytes, classes, stacks, lines and fingerprints.|After a diagnostic run or when importing a log located within the active workspace.|
|`PrepareMemoryDiagnosticSession`|Prepare a single preview with instrumentation, warm-up, repetitions and runtime scenario, without running the project.|When the user requests a full memory diagnosis and before execution consent.|
|`RunMemoryDiagnosticSession`|Instruments, compiles, starts only the supervised process, runs the scenario, collects the log, and restores the DPR.|After preview review and explicit consent for composite session.|
|`CancelMemoryDiagnosticSession`|Cancels build, scenario and only the process supervised by the active memory session.|When the user cancels or when the execution limit is reached.|
|`GetMemoryDiagnosticSessionStatus`|Informs the current phase, operational message, preview and cancellation status.|During a long session, via chat or MCP, to monitor progress without interfering with execution.|
|`CompareMemoryDiagnosticEvidence`|Compares baseline and verification of different builds under the same scenario and classifies as `fixed`, `improved`, `unchanged`, `regressed` or `incomparable`.|After applying a fix and repeating the original scenario exactly.|
|`PrepareMemoryDiagnosticFix`|Choose the first frame of the project, enter file, line, routine and allocation number and forward the edit to `PreparePatch`.|After selecting a leak or error group whose stack contains project code.|

## Navigation, symbols and project groups

|Tool|What it does|When it is triggered|
|---|---|---|
|`ListProjectGroupProjects`|Lists projects loaded into the current project group.|To understand solutions with separate executables, packages, libraries or tests.|
|`GetProjectDependencies`|Query the actual dependencies of the active project via OTA.|Before deciding build order, impact or relationship between projects.|
|`GetUnitSymbols`|Extracts classes, records, interfaces and routines from the active buffer with their lines.|To find statements without blindly searching text.|
|`NavigateToFile`|Opens a file belonging to a loaded project and positions the cursor.|When an analysis, error, or plan points to a specific file, row, and column.|
|`NavigateToSymbol`|Positions the editor on a symbol of the active unit.|After `GetUnitSymbols` or when the user asks to show a statement.|
|`NavigateToDevelopmentSurface`|Activates Code or Design in the project file.|Between Code/Design stages.|
|`ListIDEActions`|Lists only actions available in the safe allowlist.|Before offering a visual action from the IDE.|
|`ExecuteIDEAction`|Performs an allowlisted action upon consent.|To open IDE panels or searches without fragile UI automation.|

File navigation is confined to open projects. Executing actions uses a fixed allowlist,
passes `execution` classification and does not accept arbitrary names received from the agent or MCP.

## Patch a file

|Tool|What it does|When it is triggered|
|---|---|---|
|`PreparePatch`|Produces preview and base hash for a change to a file.|After analysis and before any simple editing.|
|`ApplyPatch`|Revalidates the preview and applies the patch to the correct buffer or file.|After approval and consent of the proposed change.|
|`RevertPatch`|Restores previous content when preconditions remain valid.|When the user or agent decides to undo an applied patch.|

## Multi-file patches

|Tool|What it does|When it is triggered|
|---|---|---|
|`PrepareMultiFilePatch`|Creates a single preview for coordinated changes across multiple files.|In refactorings that cross units or require related changes.|
|`ApplyMultiFilePatch`|Applies the set after validating all files.|When the full preview has been approved and no files are out of date.|
|`RevertMultiFilePatch`|Reverses the set of files in a coordinated manner.|To fully undo an applied multi-file change.|

## Block reviews

|Tool|What it does|When it is triggered|
|---|---|---|
|`ListBlockReviews`|Lists revision-bound blocks and their current decisions.|After a single or multi-file preview publishes a review session.|
|`DecideBlockReview`|Records accept, reject, or edit without changing a buffer.|From an editor action, command, chat, or MCP during review.|
|`ApplyBlockReviews`|Composes all decisions and applies files in one transaction.|When no block remains pending and write consent is granted.|
|`ClearBlockReviews`|Discards the session and decisions without changing files.|To cancel review or abandon a stale preview.|

## Development Transactions

|Tool|What it does|When it is triggered|
|---|---|---|
|`PrepareDevelopmentTransaction`|Assembles a transaction with code, project and Designer changes.|When an objective needs to change different surfaces as a single unit.|
|`ApplyDevelopmentTransaction`|Executes transaction steps and preserves rollback data.|After review of the composite operation and required permissions.|
|`RejectDevelopmentTransactionStep`|Rejects a pending step.|Before the selective application.|
|`RevertDevelopmentTransactionStep`|Reverses the last applied step.|No gradual rollback.|
|`RevertDevelopmentTransaction`|Undo the applied steps in a safe order.|When a compound transaction needs to be rolled back.|

## Project templates

|Tool|What it does|When it is triggered|
|---|---|---|
|`PreviewProjectTemplate`|Renders a template's tree and files without saving them.|When creating Console, VCL, FMX, Library, Package, DUnitX or DEXT server.|
|`CreateProjectFromTemplate`|Publishes the project prepared using staging and validations.|After the user approves the name, destination, template and preview.|
|`RevertCreatedProject`|Removes files created by the operation in a controlled manner.|When the creation needs to be undone and the hashes still match.|
|`OpenCreatedProject`|Open the project that was just created in the IDE.|Upon successful publication or by explicit request.|
|`ValidateCreatedProject`|Compiles and validates the generated project structure.|At the end of the creation flow or when the agent needs to confirm that the template works.|

## Project files

|Tool|What it does|When it is triggered|
|---|---|---|
|`PrepareAddProjectFile`|Prepares the creation and inclusion of a unit or form.|Before adding a new file to the project structure.|
|`PrepareRemoveProjectFile`|Prepares the removal of a unit or form.|Before deleting the reference and associated files.|
|`ApplyProjectFileChange`|Effective the prepared inclusion or removal.|After preview and structural consent.|
|`RevertProjectFileChange`|Restores the previous structure and files.|To undo an applied structural change.|

## Inline reviews

|Tool|What it does|When it is triggered|
|---|---|---|
|`PublishInlineReview`|Publishes an observation anchored to file, hash, and lines.|When a review finds an issue it should appear in the editor.|
|`ListInlineReviews`|Lists current inline revisions.|To resume an analysis or consult pending issues before applying corrections.|
|`PrepareInlineReviewFix`|Converts a review suggestion into a patch preview.|When the user decides to correct a published observation.|
|`ApplyInlineReviewFix`|Applies a suggestion anchored to the current review and removes the resolved tag.|After reviewing the block and consenting to the buffer change.|
|`RejectInlineReview`|Rejects a suggestion and removes its tag without changing the buffer.|When the user does not want to embed the suggested block.|
|`RemoveInlineReview`|Removes a specific revision without changing the code.|After resolving, discard or consider the observation invalid.|
|`ClearInlineReviews`|Clears the requested scope revisions.|When closing a review round or restarting analysis.|

## Build

|Tool|What it does|When it is triggered|
|---|---|---|
|`BuildProject`|Runs `make`, `build`, `check`, or `clean` with structured diagnostics.|To validate changes, reproduce errors, or meet the build gate.|
|`CancelBuild`|Requests co-op cancellation of the active build.|By the cancel button, by the agent or when a timeout is reached.|
|`GetBuildStatus`|Returns state, duration and result of the controlled build.|While the agent tracks the build or before starting another.|

## Form Designer inspection

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetActiveForm`|Identifies the active form and its design context.|Before querying or modifying components.|
|`ListFormComponents`|Lists components, classes, basic properties, and hierarchy.|To understand the form and plan visual changes.|

## Form Designer Layout

|Tool|What it does|When it is triggered|
|---|---|---|
|`PrepareComponentLayout`|Creates preview of position, size, alignment or anchoring.|Before moving or resizing a component.|
|`ApplyComponentLayout`|Applies the layout after revalidating form and component.|After approval of the visual change.|
|`RevertComponentLayout`|Restores the previous layout.|When the visual change needs to be undone.|

## Form Designer Properties

|Tool|What it does|When it is triggered|
|---|---|---|
|`PrepareComponentProperty`|Prepares the move of a compatible property.|Before changing Caption, Text, Enabled, or another supported property.|
|`ApplyComponentProperty`|Sets the property in Living Designer.|After preview and consent.|
|`RevertComponentProperty`|Restores the property's previous value.|To undo an applied property change.|

## Form Designer Components

|Tool|What it does|When it is triggered|
|---|---|---|
|`PrepareAddFormComponent`|Prepares class, name, parent and position of a new component.|When the objective calls for the inclusion of a non-visual control or component.|
|`PrepareRemoveFormComponent`|Prepares for removal and captures the state required for rollback.|Before deleting an existing component.|
|`ApplyFormComponentChange`|Adds or removes the prepared component.|After Designer validation and structural consent.|
|`RevertFormComponentChange`|Reverses the addition or removal.|When component changes need to be undone.|

## Form Designer events

|Tool|What it does|When it is triggered|
|---|---|---|
|`PrepareFormEventHandler`|Prepares event method, signature, body and link.|When a component needs to respond to Click, Change or other supported event.|
|`ApplyFormEventHandler`|Creates the method and connects the event in a coordinated way.|After code and design change review.|
|`RevertFormEventHandler`|Removes or restores the previous method and link.|To undo the creation or change of the handler.|

## Debugger inspection

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetDebuggerState`|Returns current state, process, thread, and location.|Before any debug command or during session monitoring.|
|`ListBreakpoints`|Lists breakpoints known by the IDE.|To understand where execution may stop or avoid duplication.|
|`GetCallStack`|Returns the stack for the current thread and frame.|When execution is paused and it is necessary to locate the source of a failure.|

## Debugger control

|Tool|What it does|When it is triggered|
|---|---|---|
|`PauseDebugging`|Requests to pause the running application.|When you need to inspect the current state.|
|`ContinueDebugging`|Resumes a paused session.|After completing the inspection or changing breakpoints.|
|`StepInto`|Advances by entering the called routine.|To follow a relevant call in detail.|
|`StepOver`|Executes the current line without entering calls.|To advance through the flow at the current routine level.|
|`StepOut`|Continue until you get out of your current routine.|When the internal analysis has finished and must return to the caller.|
|`StopDebugging`|Ends the debug session.|Upon completion of the diagnosis, cancel the objective or reach a terminal condition.|

## Breakpoints

|Tool|What it does|When it is triggered|
|---|---|---|
|`AddBreakpoint`|Adds a breakpoint to a valid file and line.|Before starting or continuing to note a specific point.|
|`RemoveBreakpoint`|Removes an existing breakpoint.|When the point is no longer needed or interferes with the flow.|

## Session, expressions and watches

|Tool|What it does|When it is triggered|
|---|---|---|
|`EvaluateDebuggerExpression`|Evaluates a safe expression in the paused frame.|To query a variable, field or expression without calling code with side effects.|
|`AddDebuggerWatch`|Adds an expression to the controlled list of watches.|When a value must be tracked over several steps.|
|`RemoveDebuggerWatch`|Removes a controlled watch.|When the expression no longer needs to be monitored.|
|`ListDebuggerWatches`|Lists watches maintained by RadIA.|Before evaluating or rearranging the monitored set.|
|`EvaluateDebuggerWatches`|Evaluates the watches in the current frame.|After a pause or step to compare the observed values.|
|`StartDebugging`|Validates and queues the IDE's official Run action without blocking the MCP request.|After specific execution consent; while running, follow with `GetRuntimeDebugSession` and `WaitForDebuggerEvent`.|

## Project knowledge

|Tool|What it does|When it is triggered|
|---|---|---|
|`IndexProjectKnowledge`|Builds or updates the project's local index.|On the first search, after relevant changes or by explicit request.|
|`SearchProjectKnowledge`|Searches files and snippets and offers direct opening of the source in chat.|When the agent needs to locate context beyond the active unit.|
|`GetKnowledgeStatus`|Reports status, count and update of the index.|To decide if a search can be used or if it needs to be reindexed.|
|`GetKnowledgeDocument`|Retrieves chunks and offers direct opening of the source in chat.|After the search identifies a result that needs detailed reading.|
|`ClearProjectKnowledge`|Removes the rebuildable index from the project.|To fix inconsistencies, address privacy, or force reconstruction.|

## DUnitX Tests

|Tool|What it does|When it is triggered|
|---|---|---|
|`RunDUnitXTests`|Runs the authorized runner and interprets the NUnit XML report.|After the build or when the objective requires validating tests.|
|`CancelDUnitXTests`|Requests the end of test execution.|By user, agent or timeout.|
|`GetDUnitXStatus`|Returns execution progress, result, and artifacts.|While the agent monitors the tests or collects failures.|

## Code coverage

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetCoverageSummary`|Reads block `stats` from the official Delphi Code Coverage report, confined to the active project.|After testing, when `CodeCoverage_Summary.xml` is available to record percentage, lines and files covered.|

## Debug timeline

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetDebugTimeline`|Returns recent process, state, breakpoint, and memory events.|To follow the session without destructive polling and explain the debug sequence.|

## Runtime debugger correlation

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetRuntimeDebugSession`|Returns session, real PID, project, executable, build and last sequence correlated.|After starting debugging and before observing or automating the application.|
|`WaitForDebuggerEvent`|Waits for process states without busy-wait and includes the stack when stall or exception occurs.|To synchronize the agent with exception, stop, termination, or future window discovery.|
|`CancelDebuggerWait`|Immediately stops active waiting.|When canceling the objective, switching projects, or ending debugging.|

## Secure discovery of the running application

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetRuntimeWindows`|Lists authorized windows with opaque ID, process, class, sanitized text, owner, state and capabilities. In IDE64, the identity remains secure even when a Win32 application does not expose text.|After committing the runtime session and before preparing a visual scenario.|
|`GetRuntimeControlTree`|Returns the sanitized hierarchy of controls with their own window, without accepting or exposing `HWND`.|To find possible actions in a window returned by `GetRuntimeWindows`.|

## Limited runtime scenarios

|Tool|What it does|When it is triggered|
|---|---|---|
|`PrepareRuntimeScenario`|Validates actions, targets, capabilities, duration, repetitions and creates a preview with fingerprint. Targets that only appear after a previous action are dynamically validated at execution.|After discovery and before requesting consent to interact with the application.|
|`RunRuntimeScenario`|Revalidates the session and executes exactly the approved preview, restricting selectors to the visible and enabled root window of the correlated process.|After the user reviews the script; requires new consent for every execution.|
|`CancelRuntimeScenario`|Stops execution or an active wait without requesting consent.|By emergency stop button or command, by the agent or by the MCP.|
|`GetRuntimeScenarioStatus`|Returns state, repetition, current action, total completed and eventual failure.|To follow the script and collect its structured result.|

## Runtime visual capture

|Tool|What it does|When it is triggered|
|---|---|---|
|`CaptureRuntimeVisual`|Captures a bounded PNG of the visible, restored window owned by the current session PID, retains it in memory, and publishes before/after in the local chat card.|After `GetRuntimeWindows`: use `phase=before` before interaction and `phase=after` afterwards; every call requires consent.|

## Runtime diagnostic evidence

|Tool|What it does|When it is triggered|
|---|---|---|
|`CaptureRuntimeEvidence`|Records session, build, scenario, last event, stack and up to ten expressions in sanitized evidence identified by fingerprint.|Once when reproducing the crash and again, with `phase=verification`, after applying the fix and recompiling.|
|`CompareRuntimeEvidence`|Compares a failure evidence with a verification evidence and reports whether they are comparable and whether the failure has been removed.|After repeating the same scenario in a new session and in a different build; does not change code or replace human review.|

## Versioned runtime regressions

|Tool|What it does|When it is triggered|
|---|---|---|
|`PrepareRuntimeRegression`|Validates a scenario with repeatable selectors, rejects IDs linked to the session and creates the artifact preview.|After proving the correction and before writing the regression to the project.|
|`SaveRuntimeRegression`|Writes the preview to `.radia/runtime-scenarios/<id>.json` with schema, fingerprint and atomic writing.|After review and consent for reversible writing.|
|`RevertRuntimeRegression`|Restores the previous artifact or removes the file created by the corresponding application.|When the user undoes the recording still tracked by the current runtime.|
|`ListRuntimeRegressions`|Lists the active project's versioned scenarios.|To discover available regressions without running the application.|
|`PrepareSavedRuntimeScenario`|Validates artifact integrity, rebinds persisted selectors to the current session, and creates an executable preview.|After starting new debug session; execution continues in `RunRuntimeScenario` with its own consent and can repeat the script up to the versioned limit.|

## Local Git

|Tool|What it does|When it is triggered|
|---|---|---|
|`GetGitStatus`|Query branch and changes from the active project repository.|Before editing, reviewing, or staging a commit.|
|`GetGitDiff`|Returns the diff allowed for review.|To check the result of changes and select paths.|
|`PreviewGitCommit`|Prepares message, files and fingerprint without creating the commit.|When the target requests a reviewable local commit.|
|`CommitChanges`|Revalidates the preview and creates only the local commit.|After review, consent and fingerprint confirmation.|

## Trigger examples

By direct command:

```text
/tool GetIDEState
/tool SearchProjectKnowledge {"query":"IRadIAToolRegistry","maxResults":10}
/tool BuildProject {"mode":"check"}
```

By agent objective:

```text
/agent run localize a origem do erro, prepare a correção, valide o build e execute os testes
```

In this example, the agent can combine workspace read, local knowledge, patch, build,
compiler messages and DUnitX. Exact selection depends on the approved plan and results of
each step.

For MCP, first query `tools/list` and then use `tools/call`. Look
[MCP Integration](mcp_integration_guide.en.md).

## Important limits

- Presence in the catalog does not guarantee that the tool is valid in the current state of the IDE.
- Designer requires compatible form and design context.
- Evaluation and call stack require paused debugger and valid frame.
- Build, testing, execution, Git, and mutations may require consent.
- `Apply` and `Revert` depend on the identifier and preconditions produced by the previous step.
- Paths outside the workspace, outdated content, and unsupported operations are rejected.
