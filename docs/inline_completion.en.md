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
7. The visual layer shows the suggestion without touching the buffer.

## Editor menu actions

| Action | Default shortcut |
|---|---|
| Request suggestion | `Ctrl+Alt+Space` |
| Accept the entire suggestion | `Ctrl+Alt+Right` |
| Accept only the next word | `Ctrl+Alt+Down` |
| Request an alternative | `Ctrl+Alt+]` |
| Reject the suggestion | `Ctrl+Alt+Backspace` |
| Accept review at the current line | `Ctrl+Alt+Enter` |
| Reject review at the current line | `Ctrl+Alt+R` |

The shortcuts appear in the **Rad IA** submenu of the editor context menu. The first request in
each session explains which context will be sent and requires explicit consent.

The shortcuts are native Open Tools API partial bindings and work directly in the editor without
opening the context menu. To change them, open **Rad IA > Settings > Security & Consent** and edit
**Inline shortcuts** using this format:

```text
request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right;
nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+];
reject=Ctrl+Alt+Backspace; terminal=Ctrl+Alt+T;
reviewAccept=Ctrl+Alt+Enter; reviewReject=Ctrl+Alt+R
```

The required actions are `request`, `accept`, `nextWord`, `alternative`, and `reject`. Terminal and
review decisions use `terminal`, `reviewAccept`, and `reviewReject`; legacy profiles receive the
default shortcuts automatically. RadIA does
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

Continuous assistance is disabled by default. To enable it, open **Rad IA > Settings > Security &
Consent** and select **Enable continuous inline completion**. The option itself explains that a
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
milestone passes visual validation on Delphi 12 Win32 and Delphi 13 Win32/IDE64. The smoke
opens a real unit, confirms the editor through MCP, and requires separate preparation and OTA
painting events. Evidence is stored in `inline_completion_smoke_evidence_2.0.0.json`.
