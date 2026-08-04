# Inline assistance and Fill-in-the-Middle

This document describes the RadIA 2.0.0 inline-assistance architecture. Delivery is incremental.
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

| Action | Initial shortcut |
|---|---|
| Request suggestion | `Ctrl+Alt+Space` |
| Accept the entire suggestion | `Ctrl+Alt+Right` |
| Accept only the next word | `Ctrl+Alt+Down` |
| Request an alternative | `Ctrl+Alt+]` |
| Reject the suggestion | `Ctrl+Alt+Backspace` |

The shortcuts appear in the **Rad IA** submenu of the editor context menu. The first request in
each session explains which context will be sent and requires explicit consent.

## Security and privacy

- Project context is an explicit request field, not hidden collection.
- Prefix, suffix, and context are bounded independently of the model context window.
- A cancelled request cannot publish a late response.
- Acceptance must validate the captured revision before inserting text.
- File, revision hash, line, and column must still match at acceptance time.
- After partial acceptance, the view returns a new snapshot before the controller keeps the remainder.
- Local and remote providers share the same contract and cancellation rules.

## Implemented components

- `TRadIAInlineCompletionContext`: FIM context and stable cache key.
- `TRadIAInlineCompletionOptions`: debounce and limits.
- `IRadIAInlineCompletionProvider`: abstraction for local and remote models.
- `TRadIAServiceInlineCompletionProvider`: adapter for the active RadIA provider.
- `TRadIAInlineCompletionController`: cache, cancellation, sanitization, and acceptance actions.
- `IRadIAInlineCompletionView`: boundary preventing the engine from writing directly to the editor.
- `TRadIAOTAInlineCompletionSession`: OTA capture, optimistic validation, insertion, and Ghost Text.

## Integration status

The first OTA flow is deliberately user-triggered: it captures only the active buffer and basic
project metadata, displays the first line as Ghost Text, and never changes the buffer before
acceptance. Continuous capture, multiline virtual rows, configurable shortcuts, and project,
file, or language disable controls remain pending. The feature is only complete after visual
validation across the supported IDE matrix.
