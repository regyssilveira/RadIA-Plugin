# User Guide: Chat Panel & Session Management

> Chat can also execute structured IDE tools. See the
> [Agentic Tools Guide](user_guide_agentic_tools.en.md) for consent, previews, cancellation,
> auditing, and results.

This guide details the operation of **Rad IA**'s chat interface, productivity shortcuts, multiple session management, and template backup/customization workflows.

---

## 1. Sidebar Chat Interface (WebView2)

Rad IA docks directly within the Delphi IDE sidebar, providing a modern chat panel powered by the **Microsoft Edge WebView2** engine.

*   **Smart Themes**: The interface automatically detects the active IDE theme (Light or Dark) and adapts its color scheme and styles to maintain visual harmony.
*   **Markdown & Syntax Highlighting**: AI responses support full Markdown formatting and Object Pascal-optimized syntax highlighting (using locally bundled Marked.js and Prism.js).
*   **Responsive dock**: The composer separates execution — mode, executor, provider, and model —
    from context — CLI session, journey, scope, and effective route — into two rows. As the panel
    narrows, each row reorganizes independently into compact columns without horizontal scrolling.

---

## 2. Productivity Shortcuts in Chat

The Rad IA chat text input area features shortcuts designed to speed up prompt typing and navigation:

*   `Ctrl + Enter`: Sends the typed prompt to the active AI.
*   `Enter`: Inserts a line break in the current prompt.
*   Up Arrow `↑` / Down Arrow `↓`: Allows you to quickly navigate through the history of prompts you have typed and sent in this workspace session.
*   `/` (Slash) character: Opens the floating autocomplete popup listing registered slash command shortcuts.

### Continue writing while RadIA works

During a response, the primary button remains **Cancel request** and a **+1** button appears. Write a
follow-up and select **+1**, or press `Ctrl + Enter`, to queue it for the current conversation. The
composer shows the count and a preview of the next message.

- up to five messages may wait;
- **Edit** returns the next message to the editor without losing the current draft;
- **Clear** discards the entire local queue;
- the next message is sent only after the current turn ends;
- provider, model, executor, and journey remain locked during the turn and are resolved again when
  the queued message is sent;
- the queue exists only in panel memory: it does not enter history before sending and does not
  survive closing or reloading chat.

---

## 3. Multiple Sessions & Persistent History

Rad IA organizes your work into persistent conversation sessions. History is saved locally in secure JSON files under `%APPDATA%\RadIA\sessions\`.

### Managing Conversations:
1.  **Collapsible Sidebar**: Click the menu (hamburger) icon in the upper-left corner of the chat to open the sessions sidebar.
2.  **Create New Chat**: Click the **[New Chat]** button to open a clean channel detached from previous conversations.
3.  **Rename Chat**: **Double-click inline** on the chat title in the sidebar to edit it, and press `Enter` to save the new name.
4.  **Delete Chat**: Click the trash icon next to the conversation title to remove it permanently from local history.
5.  **Safety Isolation**: The sessions sidebar and chat creation/deletion are dynamically disabled while an AI streaming response is actively transmission.

### CLI executor sessions

When chat uses an external CLI executor, each RadIA conversation separately preserves the identifier
needed to continue that conversation in the client. The composer shows **Session: Resume** when a
compatible link exists and **Session: New** when the next message will start a new external
conversation. Use **New CLI session** or `/cli new` to start over without deleting the visible RadIA
history. See [CLI executors](cli_executors.en.md) for limits and privacy.

### Journey shared with terminal and editor

Each conversation can keep a journey identity linked to the active project. The **Journey** button
shows **Link** or **Detach**, and the composer displays the shortened identifier. Switching the
conversation restores its journey without copying messages into the terminal or editor. Use
`/context`, `/context new`, `/context detach`, and `/context switch <id>` for the same keyboard-driven
actions. See [Shared context](shared_journey_context.en.md) for limits, privacy, and project isolation.

---

## 4. Exporting Conversations

You can save the history of any chat for documentation or team sharing:

1.  At the top of the active chat panel, click the **Export** button.
2.  Select the desired format:
    *   **Markdown (.md)**: Ideal for saving in Git repositories or internal wikis.
    *   **Standalone HTML**: Generates a complete HTML file with all CSS styles and Pascal syntax highlighting scripts embedded, allowing offline viewing of the formatted chat in any browser.

---

## 5. Template Library & Backups

Templates allow you to create custom shortcuts (Slash Commands) containing reusable instructions. Rad IA segregates native system templates from those created or modified by you.

### Managing Templates:
1.  In the Delphi IDE, navigate to **Tools -> Options -> Third Party -> Rad IA -> Templates**.
2.  On this screen, you will see the list of active templates. The origin indicator will show:
    *   `Default System (Read-Only)`: Integrated plugin templates.
    *   `Default System (Customized)`: Native templates that you edited (saved as local overlays).
    *   `User Custom`: New templates that you registered.
3.  **Restore Default**: If you modify a system template and wish to revert, select it and click **Restore Default** (the overlay will be deleted and the original prompt re-enabled).

### Backup (Export / Import):
*   **Export**: Click **Export** on the templates panel to save your entire active library (including new templates and overrides) to a JSON file.
*   **Import**: Click **Import** and select the backup JSON file. Rad IA will validate the schema and offer two integration choices:
    *   *Merge*: Adds the new overrides while preserving already configured local templates.
    *   *Overwrite*: Completely replaces the local library with the backup content.

> [!CAUTION]
> **Warning on Overwriting Templates:**
> The **Overwrite** option irreversibly deletes all your custom templates and new local commands that are not included in the imported backup JSON file. We strongly recommend making a safety export of your current library before executing an overwrite import.

---

## 6. Conversation-specific settings

Use **Settings > Scope** in the composer to apply a provider, model, executor, or limits only to the
current conversation. The `session` source confirms that the session overrides project and global
defaults. Use **Inherit** to restore one field or **Restore all inheritance** to clear the session.
`/scope session ...` provides the same keyboard flow. See
[Project, session, and request settings](hierarchical_settings.en.md).
