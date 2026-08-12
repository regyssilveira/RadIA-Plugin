# Rad IA onboarding

Onboarding presents a short journey through the essential surfaces of Rad IA. He appears
automatically once for each version of the flow and can be reopened at any time
**Tools > Rad IA Getting Started**.

Closing the window stops the stream without changing settings. Rad IA only records the current step
to not display the window again automatically. When reopening through the menu, the journey continues from
last stage visited. The **Finish** button records the completion.

## Steps

|Step|What does it teach|Action available|
|---|---|---|
|Chat|Open the dockable panel and chat about the active project|**Open chat**|
|Provider and executor|Configure a provider and choose native agent or CLI|**Open provider settings**|
|Security|Review consent before reading, changing, building, debugging, or committing|**Open consent settings**|
|CLI and MCP|Diagnose CLIs and connect, repair, or remove the MCP bridge|**Open CLI and MCP settings**|
|Terminal|Execute commands with streaming, history, snippets and cancellation|**Open terminal**|
|Readiness|Run `/doctor` in chat and get score, checks and next action|**Run installation doctor**|
|New project|Create a deterministic Delphi project and continue in Agent Mode|**Create a project**|

Actions open the actual product screens. Onboarding remains available in the background so that the
user returns to the script after saving or closing the open surface.

## Recommended first configuration

1. Configure at least one provider in **AI Providers**.
2. Under **Security & Consent**, choose how risky operations should request approval.
3. In **CLI & MCP**, keep the native agent or select an already installed CLI and run the
diagnosis.
4. Connect the MCP only to the desired clients after reviewing the configuration preview.
5. Run **Run installation doctor**. With the native executor, MCP is not a requirement; with a CLI,
bridge and MCP configuration become part of the acceptance.
6. Confirm that `firstToolReady` is active and run the first read-only tool.
7. Open chat and visually enable **Agent Mode** when you want Rad IA to plan and use
internal tools.

Onboarding does not install CLIs, modify MCP files, or activate consents on its own. All
Operation continues depending on the user's explicit action on the corresponding screens.
