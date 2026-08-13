# Inline assistance and Fill-in-the-Middle

This document describes the inline assistance available in RadIA.
The engine, explicit capture, and first visual overlay are now connected to the Open Tools API.

## Goal

The Fill-in-the-Middle (FIM) engine receives code before and after the cursor, file, language,
current symbol, and explicit project context. The provider must return only the missing cursor
content.

RadIA does not mutate the buffer while presenting a suggestion. A write occurs only when the user
accepts the whole suggestion or the next word.

## Engine flow

1. The IDE integration captures prefix, suffix, buffer revision, and authorized context.
2. Context is limited before leaving the IDE.
3. A new request cancels the previous request and restarts debounce.
4. A local cache avoids repeated calls for the same context.
5. Markdown fences, suffix overlap, and over-limit content are removed from the response.
6. Delivery occurs only while generation and revision are current.
7. Distinct alternatives remain attached to the same context and can be browsed.
8. The visual layer shows the selected suggestion and a compact panel without touching the buffer.

When a symbol is under the cursor, the completion worker queries the semantic index to append
declarations and inheritance-resolved members. The query does not run during OTA capture on the IDE
thread. If the semantic process is unavailable, the request continues with bounded unit context; the
editor remains responsive and Ghost Text remains available.

When the cursor follows member access, such as `Form.Sa`, RadIA queries the local structural index
first. The search filters the prefix, resolves inherited members, removes duplicates, and limits the
result to 20 candidates. An unambiguous continuation is displayed immediately without calling the
provider. Empty, ambiguous, or unavailable results automatically continue through the configured FIM
route. A new edit cancels both local and remote waits; route status reports `local semantic`, candidate
count, and latency when that route is used.

## Alternatives panel

After **Request an alternative**, RadIA keeps the previous suggestion instead of silently replacing
it. With two or more distinct responses, the editor displays up to three alternatives in a compact
panel below the active line. The selected option uses the IDE selection color and remains visible as
complete Ghost Text.

Use **Next Inline Suggestion** or **Previous Inline Suggestion** to compare responses. **Accept the
entire suggestion** and **Accept only the next word** always operate on the highlighted alternative.
Editing the buffer, changing files, or rejecting completion clears the complete set, preventing a
response from an old revision from being applied.

## Dedicated FIM route and fallback

Ghost Text has its own contract, separate from chat. RadIA checks provider capability at runtime;
it does not infer support from a model name.

- **Ollama:** uses `POST /api/generate` with separate `prompt` and `suffix` fields.
- **LM Studio:** uses `POST /v1/completions` with separate `prompt` and `suffix` fields.
- **Other providers:** explicitly use traditional completion fallback with delimited FIM context in
  the prompt.

If a dedicated route fails, RadIA tries traditional fallback for the same request. Changing the
file, revision, cursor, project, or journey cancels the previous request; a stale response cannot
reach the overlay.

Provider and model come first from `AutocompleteProvider` and `AutocompleteModel` when those
preferences exist; otherwise they use the active global provider and model. Selection applies only
to the inline request and does not mutate global settings.

To inspect the latest decision, use **Rad IA > Show Inline Completion Route Status** in the editor
menu or **Tools > Rad IA Inline Completion Route Status**. The dialog reports dedicated route or
fallback, provider, model, local latency, and fallback reason. The same diagnostic is logged without
prefix, suffix, or suggested content.

Use **Rad IA > Show Semantic Editor Context** in the editor menu or **Tools > Rad IA Semantic Editor
Context** to inspect the bounded metadata shared by Ghost Text, contextual actions, and the agent
before a request: active unit, symbol at the cursor, imports, and nearby declarations. Inspection is
read-only and does not change the buffer. When an action such as explain, test, or find bugs is
triggered from the menu, the same context accompanies the selected code or active unit.

## Editor menu actions

| Action | Default shortcut |
|---|---|
| Request suggestion | `Ctrl+Alt+Space` |
| Accept the entire suggestion | `Ctrl+Alt+Right` |
| Accept only the next word | `Ctrl+Alt+Down` |
| Request an alternative | `Ctrl+Alt+]` |
| Next stored suggestion | `Ctrl+Shift+Down` |
| Previous stored suggestion | `Ctrl+Shift+Up` |
| Reject the suggestion | `Ctrl+Alt+Backspace` |
| Accept review at the current line | `Ctrl+Alt+Enter` |
| Reject review at the current line | `Ctrl+Alt+R` |
| Next review block | `Ctrl+Alt+PageDown` |
| Previous review block | `Ctrl+Alt+PageUp` |
| Edit block at cursor | `Ctrl+Alt+E` |
| Explain block at cursor | `Ctrl+Alt+I` |
| Apply resolved review | `Ctrl+Alt+A` |
| Discard review session | `Ctrl+Alt+Delete` |

The submenu also offers **Show Inline Completion Route Status**, with no default shortcut, to
explain how the latest suggestion was executed.

The shortcuts appear in the **Rad IA** submenu of the editor context menu. The first request in
each session explains which context will be sent and requires explicit consent.

The shortcuts are native Open Tools API partial bindings and work directly in the editor without
opening the context menu. To change them, open **Rad IA > Settings > Editor Assistance** and edit
**Inline shortcuts** using this format:

```text
request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right;
nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+];
completionNext=Ctrl+Shift+Down; completionPrevious=Ctrl+Shift+Up;
reject=Ctrl+Alt+Backspace; terminal=Ctrl+Alt+T;
reviewAccept=Ctrl+Alt+Enter; reviewReject=Ctrl+Alt+R;
reviewNext=Ctrl+Alt+PageDown; reviewPrevious=Ctrl+Alt+PageUp;
reviewEdit=Ctrl+Alt+E; reviewExplain=Ctrl+Alt+I;
reviewApply=Ctrl+Alt+A; reviewClear=Ctrl+Alt+Delete
```

The required actions are `request`, `accept`, `nextWord`, `alternative`, and `reject`. Alternative
navigation uses `completionNext` and `completionPrevious`. Terminal and
review decisions use `terminal`, `reviewAccept`, `reviewReject`, `reviewNext`, `reviewPrevious`,
`reviewEdit`, `reviewExplain`, `reviewApply`, and `reviewClear`; legacy profiles receive the default
shortcuts automatically. See [block-level review](block_reviews.en.md) for markers, colors,
transactions, and navigation. RadIA does
not save incomplete profiles, invalid keys, or duplicate shortcuts. The profile reloads after
returning to the editor, without restarting the IDE. If the active Delphi keymap already owns a
shortcut, the existing command keeps priority and RadIA records the conflict in its log.

## Local visual diagnostic

The **Tools** menu and the editor **Rad IA** submenu provide **Preview Rad IA Ghost Text
Diagnostic**. The action:

- uses the real editor buffer and cursor position;
- presents two local lines through the same controller and overlay as a regular suggestion;
- does not call a provider, transmit context, or require a connection;
- does not mutate the buffer before acceptance;
- can be rejected or accepted through the same user-configured shortcuts.

The log records preparation and actual painting separately, including only the line count and file
name. Buffer and suggestion contents never enter this evidence. The diagnostic can therefore
distinguish an invoked action from an overlay actually processed by the OTA paint cycle.

## Continuous assistance and scope

Continuous assistance is disabled by default. To enable it, open **Rad IA > Settings > Editor
Assistance** and select **Enable ghost text (inline completion)**. The option itself explains that a
bounded context from the active buffer will be sent to the selected provider.

The same section configures:

- an idle delay between 250 and 5000 milliseconds;
- excluded languages separated by semicolons;
- excluded file-name or path fragments;
- excluded project-name or path fragments.

Changes take effect without restarting the IDE. The context menu also provides
**Pause/Resume Inline Completion for Session**. Session pause does not modify the persisted
preference and returns to its normal state when the IDE restarts.

Continuous mode uses the modern `INTACodeEditorEvents` API to observe paint cycles and editor
revisions; it does not periodically poll content. A snapshot is requested only when the file,
revision, or cursor position changes. Policy-blocked contexts never reach the provider.

## Security and privacy

- Project context is an explicit request field, not hidden collection.
- Prefix, suffix, and context are bounded independently of the model context window.
- A cancelled request cannot publish a late response.
- Acceptance must validate the captured revision before inserting text.
- File, revision hash, line, and column must still match at acceptance time.
- After partial acceptance, the view returns a new snapshot before the controller keeps the remainder.
- Local and remote providers share the same contract and cancellation rules.
- Continuous preference uses a new safe key that is disabled by default; old autocomplete
  settings do not grant consent implicitly.

## Implemented components

- `TRadIAInlineCompletionContext`: FIM context and stable cache key.
- `TRadIAInlineCompletionOptions`: debounce and limits.
- `IRadIAInlineCompletionProvider`: abstraction for local and remote models.
- `IRadIADedicatedFimProvider`: optional capability for a provider-native FIM route.
- `TRadIAFimCapabilityDiscovery`: contract-based selection without model-name heuristics.
- `TRadIAFimDiagnostic`: route, provider, model, latency, and fallback reason for the latest run.
- `TRadIAServiceInlineCompletionProvider`: adapter for the active RadIA provider.
- `TRadIAInlineCompletionController`: cache, cancellation, sanitization, and acceptance actions.
- `TRadIAInlineGhostLayout`: deterministic multiline virtual-overlay layout.
- `IRadIAInlineCompletionView`: boundary preventing the engine from writing directly to the editor.
- `TRadIAOTAInlineCompletionSession`: OTA capture, optimistic validation, insertion, and Ghost Text.

## Integration status

The manual OTA flow and opt-in continuous capture are connected. Both capture only the active
buffer, resolve the current symbol from the cursor line, and include basic project metadata.
Multiline suggestions are split into virtual overlays without changing the buffer. The first line
starts at the cursor; visible continuation lines use a lane after real text to avoid covering code,
and rows beyond end-of-file render below the final logical line. Full acceptance preserves every
line break, while partial acceptance refreshes the snapshot before keeping the remainder. The
integration is validated on Delphi 12 Win32 and Delphi 13 Win32/IDE64. Smoke testing opens a real
unit, confirms the editor through MCP, and requires preparation, OTA painting, acceptance, one undo
restoring the snapshot, and clean rejection. Detailed results belong in the pipeline, not in `docs`.
