# Attachable terminal

When a journey is linked in chat, the terminal header shows the same identifier, project, and
activity state. Command authorization uses that identity without submitting chat history or previous
output. See [Shared context](shared_journey_context.en.md).

RadIA 2.0 includes a native terminal that can be plugged into the IDE. It is available on all three targets
official: Delphi 12 Win32, Delphi 13 Win32 and Delphi 13 IDE64.

## How to open

There are four equivalent forms:

1. Click the **>_Terminal** button in the chat header.
2. Type `/terminal` in chat and send the command.
3. Use **Tools > RadIA > Rad IA Terminal**.
4. Press the configured shortcut. The default is `Ctrl+Alt+T`.

The button and command call the same native action. The terminal is not inserted inside WebView2:
it uses its own VCL panel, registered by the Open Tools API as a dockable window.

Internally, ConPTY transport, VT emulation, and the VCL renderer are independent layers. The UI uses
`IRadIATerminalEmulator` without knowing the parser or third-party types. The current native core is
behind that interface, allowing evolution and fallback without changing sessions, consent, or docking.

## Shortcut configuration

Open **Rad IA > Settings > Security & Privacy** and locate **RadIA shortcuts**. The profile contains
`action=shortcut` pairs separated by semicolons:

```text
request=Ctrl+Alt+Space; accept=Ctrl+Alt+Right; nextWord=Ctrl+Alt+Down; alternative=Ctrl+Alt+]; reject=Ctrl+Alt+Backspace; terminal=Ctrl+Alt+T
```

Change only the value of `terminal` to choose another binding. Shortcuts must be valid
and unique within the profile. The configuration is validated before being saved, preventing the terminal from
conflicts with accepting, rejecting, or requesting an inline suggestion.

Profiles saved by previous versions, without the `terminal` entry, remain valid and receive
automatically defaults to `Ctrl+Alt+T`.

## Features

- simultaneous sessions in independent tabs;
- fixed profiles for Windows PowerShell and Command Prompt;
- profile for Git Bash when the Git for Windows installation is in `PATH`;
- profiles for Codex, Claude, Gemini and GitHub Copilot only when the executable is detected;
- working directory based on the active Delphi project folder;
- interactive execution by ConPTY, with fallback to pipes;
- continuous input to respond to prompts from active processes;
- incremental capture of stdout and stderr;
- ANSI SGR with normal, bright, 256-color, and true-color foregrounds and backgrounds;
- bold, italic, underline, inverse video, and selective attribute reset;
- alternate screen with restoration of primary content and cursor;
- bracketed paste negotiated by the process;
- mouse clicks for applications that enable SGR tracking;
- identifiable OSC 8 hyperlinks opened by double-click after consent;
- cursor movement, carriage return, line and screen cleaning;
- automatic resizing of the pseudo-console;
- Unicode over UTF-8 channels with streaming decoding across read boundaries;
- correct display width for CJK, emoji, and combining marks;
- reflow on resize while preserving explicit line breaks;
- TUI insert, delete, and erase character operations, including fragmented VT sequences;
- persistent history of the last 200 commands;
- incremental reverse search with `Ctrl+R`;
- snippets for build, tests and Git;
- searchable and deduplicated palette over snippets and history, opened with `Ctrl+P`;
- cancellation of the complete process tree;
- maximum timeout of 30 minutes per command;
- isolated closure of each flap.

## Usage flow

1. Open a project in the IDE.
2. Open the terminal by button, `/terminal`, menu or shortcut.
3. Use **New terminal** to create another session.
4. Choose the active tab shell.
5. Type a command or select a snippet.
6. Click **Run** or press Enter.
7. When the process requests input, type the response and use **Send**.
8. Use **Stop** to cancel the process and its subprocesses.
9. Use **Close terminal** to remove only the active tab.

To recall a command without using the mouse, type part of the command and press `Ctrl+R`. press
again to scroll through older occurrences. A manual edit restarts the search.

To search by purpose or by the command text itself, press `Ctrl+P` in the search field.
command. Type in the **Command palette** box and select a result labeled
`[snippet]` or `[history]`. The palette eliminates duplicates: when a snippet and history have
the same command, the documented version of the snippet appears only once.

## Unicode, resize, and TUI applications

The ConPTY transport retains incomplete UTF-8 bytes until the next read. An emoji or ideograph split
by Windows across two blocks therefore does not become a replacement character. The screen uses
display width: CJK and emoji occupy two columns, while a combining mark joins the previous character
without advancing the cursor.

When the panel becomes narrower or wider, automatically wrapped lines are rearranged for the new
width. Line breaks emitted by the process remain hard breaks. The emulator also preserves CSI and OSC
state across blocks and supports cursor movement/save, screen and line erase, SGR, character insertion
(`ICH`), deletion (`DCH`), and erasure (`ECH`). The 256-color and true-color modes preserve foreground
and background. Bold, italic, underline, and inverse video are rendered independently.

TUI applications may enable the alternate screen with `1047` or `1049`; leaving it restores the
primary content and cursor. Input is wrapped as bracketed paste only after the process enables `2004`.
Clicks are sent with the SGR protocol only after a tracking mode (`1000`, `1002`, or `1003`) and
protocol `1006` have been enabled.

OSC 8 links appear underlined. Double-click one to request authorization and open an `http`, `https`,
or `mailto` URI; other schemes are rejected. Authorization is requested for every opening through
the same central policy used by the rest of RadIA.

Applications requiring features not yet emulated, such as sixel graphics, inline images, or mouse
protocols other than SGR, continue to run but may show simplified output. Open them in your preferred
external terminal when needed; RadIA does not modify or block the process.

## Security and privacy

The terminal executes exactly the command entered by the user. It does not activate agent mode or
adds standalone options to CLIs. History is saved in
`%APPDATA%\RadIA\terminal-history.json` and contains only profile, command, time and exit code.
Stdout, stderr, tokens and credentials are not persisted by history.

Before starting a process, the terminal requests authorization from the same execution policy used
via chat, MCP and agent mode. **Allow once**, **Allow for session**, **Deny** and **Cancel** have the
same semantics on all these surfaces. A session permission is limited to the project and can
be removed in **Security & Consent > Revoke session permissions**. Authorizations are registered
in the same auditable log as the tools, with secrets removed before persistence.

The request identifies **Terminal** as its source, preserves journey and project in the correct
fields, and uses the panel-independent native dialog. Arguments are redacted before display.

The working directory and active project identifier make up the authorization scope. In a
AI profile, the MCP paths configured for that client also enter the audited context;
the terminal does not read or write the contents of the MCP files during this step.

AI profiles reuse the CLI Manager catalog. Therefore, the terminal does not maintain a second
list of names or paths: only actually detected CLIs are presented. Executables
`.cmd` and `.bat` are safely launched from Command Prompt; native executables are called
directly. The text you enter becomes the initial prompt or command for the selected CLI.

Each execution receives a Windows Job Object. Cancel execution, close the tab, download the
plugin or terminating the IDE terminates the main process and its children. Visual updates are
queued on the main thread and ignored when the panel no longer exists.

## Docking and focusing

The native host creates the frame and connects the entire hierarchy of parents before requesting focus. That
prevents the `Control TEdit has no parent window` error seen when opening the terminal during creation
of the panel in Delphi 13. Focus is applied deferred only when:

- the form is visible and has a handle;
- the command field has a valid parent and handle;
- the field window is visible and enabled.

The IDE itself persists position, size, visibility, and coupled state.

## Evidence

The automated matrix runs in the validation pipeline. Smoke requires useful
geometry, input and output, the **New terminal**, **Close terminal**, **Run**, **Stop**, and
**Clear**, the five accessible labels, at least 11 navigable points per Tab, two profiles and one
non-empty palette. The current matrix exclusively covers Delphi 12 Win32, Delphi 13 Win32 and Delphi
13 IDE64, all with the current catalog of 162 tools. Detailed evidence remains outside `docs` as
historical record.
