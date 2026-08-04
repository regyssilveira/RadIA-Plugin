# Inline assistance and Fill-in-the-Middle

This document describes the RadIA 2.0.0 inline-assistance architecture. Delivery is incremental.
The domain engine is implemented; automatic capture and visual presentation still need to be
connected to the Open Tools API.

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

## Planned editor actions

- Accept the entire suggestion.
- Accept only the next word.
- Reject the suggestion.
- Request an alternative.
- Disable by session, project, file, or language.

## Security and privacy

- Project context is an explicit request field, not hidden collection.
- Prefix, suffix, and context are bounded independently of the model context window.
- A cancelled request cannot publish a late response.
- Acceptance must validate the captured revision before inserting text.
- Local and remote providers share the same contract and cancellation rules.

## Implemented components

- `TRadIAInlineCompletionContext`: FIM context and stable cache key.
- `TRadIAInlineCompletionOptions`: debounce and limits.
- `IRadIAInlineCompletionProvider`: abstraction for local and remote models.
- `TRadIAServiceInlineCompletionProvider`: adapter for the active RadIA provider.
- `TRadIAInlineCompletionController`: cache, cancellation, sanitization, and acceptance actions.
- `IRadIAInlineCompletionView`: boundary preventing the engine from writing directly to the editor.

## Integration status

The next increment connects the controller to the existing OTA adapters, implements the Ghost Text
overlay, and registers acceptance and rejection shortcuts. The feature must not be advertised as
available to end users until that integration is complete and validated in a real IDE.
