# Block-level change review

Block review lets you decide each proposed change directly in the editor before any file is
modified. RadIA displays a marker in the gutter — the margin to the left of the code — for every
block bound to the current file revision.

## When it is triggered

The session is created automatically when the agent or an integration runs `PreparePatch` or
`PrepareMultiFilePatch`. Preparing a change does not write to the buffer: it only calculates the
diff, separates blocks, and publishes markers. A new preparation replaces the previous session so
independent proposals cannot be mixed.

The related tools are:

| Tool | What it does | When to use it |
|---|---|---|
| `PreparePatch` | Prepares one file and publishes its blocks. | Before reviewing a simple change. |
| `PrepareMultiFilePatch` | Prepares a transaction across multiple files. | When the change spans units. |
| `ListBlockReviews` | Lists current blocks, files, lines, and decisions. | For the agent or `/tool` to inspect state. |
| `DecideBlockReview` | Accepts, rejects, or edits one block without writing the file. | To automate the same decision offered in the gutter. |
| `ApplyBlockReviews` | Applies every resolved block as one transaction. | After no decision remains pending. |
| `ClearBlockReviews` | Discards the session without changing files. | To abandon the whole proposal. |

## Markers and decisions

| Color | State | Effect when applied |
|---|---|---|
| Orange | Pending | Prevents application until a decision is made. |
| Green | Accepted | Uses the proposed text. |
| Gray | Rejected | Keeps the original text. |
| Purple | Edited | Uses the text adjusted in the visual diff. |

Left-click the marker to open **Accept block**, **Reject block**, **Edit block**, **Explain block**,
**Apply resolved review**, and **Discard review session**. Editing opens the visual diff with the
original and proposed text so you can adjust the result before saving the decision.

## Keyboard and editor menu

Every visual action has an equivalent in the editor context menu's **Rad IA** submenu and in
configurable Open Tools API bindings:

| Action | Profile name | Default shortcut |
|---|---|---|
| Accept the block at the cursor | `reviewAccept` | `Ctrl+Alt+Enter` |
| Reject the block at the cursor | `reviewReject` | `Ctrl+Alt+R` |
| Go to the next block | `reviewNext` | `Ctrl+Alt+PageDown` |
| Go to the previous block | `reviewPrevious` | `Ctrl+Alt+PageUp` |
| Edit the block at the cursor | `reviewEdit` | `Ctrl+Alt+E` |
| Explain the block at the cursor | `reviewExplain` | `Ctrl+Alt+I` |
| Apply the resolved session | `reviewApply` | `Ctrl+Alt+A` |
| Discard the session | `reviewClear` | `Ctrl+Alt+Delete` |

To customize them, open **Rad IA > Settings > Editor Assistance** and change **RadIA shortcut
profile**. Use semicolon-separated `action=shortcut` pairs. Legacy profiles remain valid and inherit
the new defaults; conflicts with the Delphi keymap are logged and the existing command keeps
priority.

## Safety and consistency

- Every block contains its file, range, and base-revision hash.
- If the buffer or file diverges, the marker becomes invalid and application is refused.
- An individual decision never writes to the editor.
- Every block must be resolved before application.
- Multi-file changes use preflight, checkpoint, and compensation, so a failure cannot leave a silent
  partial application.
- Rejecting every block completes the session without changing content.
- **Discard review session** removes only the proposal; it does not undo changes already applied.

## Recommended workflow

1. Request the change in chat or agent mode.
2. Wait for preparation and open the first indicated file.
3. Move through markers with the mouse, menu, or `reviewNext`/`reviewPrevious`.
4. Accept, reject, or edit every block.
5. Use **Apply resolved review** only after reviewing all files.
6. Build and run tests; when necessary, use the checkpoint or transaction-revert tool.

