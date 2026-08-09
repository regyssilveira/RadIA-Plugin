# Shared journey context

Shared context lets one task continue across chat, terminal, and editor without copying complete
history between surfaces. Each journey references only the RadIA conversation, Delphi project,
current executor, and activity state.

## How to use it

When a conversation is opened or selected with an active project, RadIA creates or restores a
journey for that combination. The composer shows **Journey: _identifier_**, and the terminal shows
the same identifier and project.

- Click **Journey > Detach** or use `/context detach` to stop sharing.
- Click **Journey > Link** or use `/context` to link again.
- Use `/context new` to discard the current link and create a new identity.
- Selecting another conversation restores its journey. Use `/context switch <identifier>` to find
  and directly open another journey from the active project.
- Switching conversations restores that conversation's journey.
- Switching projects creates a different journey and prevents workspace mixing.

`/context` also reports the active conversation, executor, and identifier. Switching is rejected
when the identifier belongs to another project, preventing workspace mixing.

## What crosses surfaces

| Data | Shared | Reason |
|---|---|---|
| Journey identifier | Yes | Correlate chat, terminal, and editor |
| RadIA conversation | Reference | Isolate chats |
| Delphi project | Reference | Prevent context from another workspace |
| Executor | Yes | Explain the effective route |
| `idle`, `running`, or `cancelling` state | Yes | Keep activity lifecycle coherent |
| Complete chat history | No | Avoid unrestricted exposure and context |
| Complete terminal output | No | Avoid implicit log submission |
| Content from other files | No | Respect editor selection and limits |

The editor adds only journey, conversation, and executor to project context when the active file
belongs to the same `.dproj` directory. The terminal uses the identity in command authorization and
continues to require configured consent.

## Cancellation and privacy

Chat and terminal publish the same activity state. When cancellation is requested, the journey
moves to `cancelling`; when the process callback completes, it returns to `idle`. This state grants
no permission, transfers no credentials, and does not replace each process cancellation control.

Journeys live only in the current IDE instance memory. Conversations and CLI sessions keep their
own persistence; closing Delphi removes transient journey links.
