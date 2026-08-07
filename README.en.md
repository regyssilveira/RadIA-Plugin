<div align="right">

[🇧🇷 Português](README.md) | [🇺🇸 English](README.en.md) | [🗺️ Roadmap](docs/roadmap.en.md) | [📋 Backlog](docs/backlog.en.md)

</div>

<p align="center">
  <img src="docs/images/radia_readme_banner-2.png" alt="Rad IA - AI Assistant for Delphi IDE" width="100%" />
</p>


# Rad IA - AI Assistant for Delphi IDE

**Rad IA** is an advanced AI assistant plugin designed specifically for the Embarcadero Delphi IDE (using the Open Tools API). It docks directly into the IDE sidebar, providing an interactive chat interface and deep contextual integration with the code editor to accelerate development, refactoring, and debugging.

<p align="center">
  <img src="docs/images/radia_ui_mockup.png" alt="Rad IA Chat Panel Mockup" width="100%" />
</p>

---

### 1. Development Guidelines and Language Standard

This project adopts clear language rules and design standards for both human developers and AI assistants (LLMs/Co-pilots) working on the codebase:

*   **AI & Human Interactions:**
    *   All chat interactions, pull request descriptions, task updates, and design discussions must be conducted in **Brazilian Portuguese (pt-BR)**.
    *   Commit messages must be written in **English (en-US)** following the [Commit Message Convention](docs/commit_convention.en.md).
    *   Branches must follow the `<type>/<short-description>` format documented in the [Branch Naming Convention](docs/branch_convention.en.md).
*   **Source Code & Architecture:**
    *   The source code is **100% written in English (en-US)**.
    *   All identifiers (unit names, variables, classes, methods, records, enums), parameters, data structures (JSON/XML), and inline comments must be written exclusively in English, following object-oriented Pascal naming conventions.
    *   Strict adherence to **Clean Code**, **SOLID**, **DRY**, and **KISS** with complete thread-safety.
*   **Official Documentation:**
    *   Available primarily in Portuguese ([README.md](README.md)) with an English translation ([README.en.md](README.en.md)).

### 2. Features
*   **Dockable Sidebar Chat:** A native-looking, dockable panel integrated into the Delphi IDE with a quick-action welcome screen, IDE-aligned Dark/Light themes, and a high-fidelity web-rendered chat window (Edge/WebView2) with full Markdown rendering and Delphi syntax highlighting.
*   **Multi-Provider AI Support:** Allows using your own API keys (BYOK) for **Google Gemini**, **OpenAI ChatGPT**, **Azure OpenAI**, **Anthropic Claude**, **AWS Bedrock**, **GitHub Copilot**, **DeepSeek**, **Groq**, **Alibaba Qwen**, **Mistral AI**, **OpenRouter**, **LM Studio**, and local **Ollama**.
*   **Native GitHub Copilot Integration:** Official support to connect directly to GitHub Copilot servers in the cloud (both personal and corporate subscriptions) with an integrated OAuth Device Flow and one-click importing of active VS Code credentials.
*   **Persistent Chat History:** Chat conversations are automatically saved locally in JSON format and can be loaded on demand from the welcome screen, avoiding chats being restored when the user does not need them.
*   **Shortcuts and Prompt History:** Integrated productivity shortcuts: use `Ctrl + Enter` to send prompts, `Enter` for line breaks, and keyboard arrows `↑` (up) and `↓` (down) inside the text input area to quickly cycle through previously typed and sent prompts.
*   **Context-Aware Editor Actions:** Right-click a selection or the active unit to:
    *   *Explain Code:* Analyze and explain the logic.
    *   *Optimize/Refactor:* Improve performance and apply clean code practices.
    *   *Optimize SQL Query:* Analyze and optimize SQL queries selected or at the cursor line.
    *   *Create Example from Comment:* Automatically generate the body of an empty method from a natural-language comment.
    *   *Generate Unit Tests:* Automatically output a DUnitX test structure.
    *   *Analyze for Bugs:* Scan selected block for memory leaks or logic errors.
    *   When no selection exists, Rad IA sends the whole active unit as context, preserving formatted Pascal blocks in chat and keeping `/explain` separated from review flows.
*   **Interactive Smart Diff View:** View refactored code recommendations side-by-side (Original vs. Suggested) highlighting changes in red/green with an **[Apply Changes]** button directly into the editor. The application safely replaces the original block and rejects the operation when the original text cannot be found, preventing duplicated code.
*   **Smart Build Debugger:** Context integration with the Delphi *Messages View*. Right-click on compilation errors to get instant AI fixes and solutions.
*   **Auto XML Documentation:** Automatically write Delphi-compliant XML help tags (`/// <summary>`) above methods.
*   **DTO and Model Converter:** Instantly generate Object Pascal classes (DTOs) or records from JSON payloads or SQL DDL scripts, with smart support for DEXT ORM, TMS Aurelius, REST.Json, and Vanilla Delphi.
*   **Customizable Slash Commands:** Run quick actions directly in the chat input (e.g., `/explain`, `/createprojectarch`). You can define new dynamic commands mapped to custom prompt templates in the plugin settings.
*   **Template Library & Backup:** Panel to manage reusable prompt templates with smart token replacement (`{code}`, `{specification}`) and built-in dialogs to export and import backups (JSON) with merge support.
*   **Secure API Key Registry Storage:** Keys are saved encrypted locally using the Windows Data Protection API (DPAPI) inside the Windows Registry.
*   **Request Cancellation and Action Locking:** A dynamic circular stop button integrated inside the prompt input aborts active requests instantly and safely. While processing, session actions, toolbar buttons, and chat switching are locked to preserve the active context.

*   **Configurable Concise Responses:** General option to prefer more direct AI answers, reducing long explanations and saving tokens without blocking detailed responses when explicitly requested.
*   **Secure Agentic Tools:** Chat executes structured editor, project, build, Form Designer, and
    debugger tools with risk-based consent and workspace confinement.
*   **Observable Agent Loop:** `/agent run` executes explicit objectives with a live progress card,
    pause, cancellation, checkpoints, and resume without turning ordinary questions into actions.
*   **Reviewable and Reversible Editing:** Patches use previews, base hashes, and preconditions,
    reject stale content, and support controlled reversal.
*   **Local MCP Server:** The stdio bridge connects clients to the intended IDE through per-PID
    discovery and a local named pipe, using the same policies as chat.
*   **Local Project Knowledge:** A rebuildable per-project index follows edit, save, rename, and
    close events to provide contextual search without an external indexing service.

### 2.1 Complete Feature Checklist

To check the development status, keyboard shortcuts, categories, and all integrated providers in detail, please refer to our:

👉 [**Complete Feature Checklist (docs/features.en.md)**](docs/features.en.md)

For a guided path from initial setup to tools, MCP, Designer, debugger, and local knowledge:

👉 [**Everything RadIA can do**](docs/capabilities.en.md)

👉 [**Complete RadIA 2.0 User Manual**](docs/user_manual.en.md)

To browse all functional, operational, and technical documentation:

👉 [**RadIA Documentation Center**](docs/README.en.md)

Quick references:

- [Everything RadIA can do](docs/capabilities.en.md)
- [What each tool does and when to use it](docs/internal_tools_reference.md)
- [All 123 built-in tools](docs/runtime_tool_catalog.md)
- [All slash commands](docs/slash_commands.en.md)

### 2.2 RadIA capabilities at a glance

| Area | What RadIA can do |
| :--- | :--- |
| **Chat and AI** | Use providers, streaming, sessions, templates, slash commands, and cancellation. |
| **Editor** | Read, explain, review, refactor, optimize SQL, find bugs, and generate tests. |
| **Safe editing** | Preview, validate base hashes, apply, and reverse patches without overwriting changes. |
| **Generation** | Create XML docs, DTOs, models, methods, and complete Delphi project structures. |
| **Workspace** | Inspect IDE, project group, modules, files, and authorized active context. |
| **Build** | Start and cancel builds, inspect state, and structure errors and warnings. |
| **Form Designer** | Inspect and change components, properties, events, and layout with consent. |
| **Debugger** | Inspect state, control execution, manage breakpoints, and evaluate expressions. |
| **Memory** | Instrument Debug, reproduce leaks, inspect stacks, compare the fix, and restore the DPR. |
| **Inline review** | Present editor suggestions and apply or reverse reviewed changes. |
| **Local knowledge** | Index projects, search symbols, and follow edit, save, rename, and close events. |
| **MCP** | Expose tools through stdio, a named pipe, and per-process discovery. |
| **Security** | Confine paths, classify risk, request consent, and keep a sanitized audit trail. |
| **Extensions** | Register external tools through the versioned public API. |
| **Providers** | Integrate Gemini, OpenAI, Azure, Claude, Bedrock, Copilot, Ollama, and others. |
| **Compatibility** | Run on Delphi 12 Win32 and Delphi 13 Win32/IDE64. |

Implemented tools are listed in the
[80 Built-in Tool Catalog](docs/runtime_tool_catalog.md). Contracts and planned evolution remain
in the [Architectural Catalog](docs/tool_catalog.md).

### 3. How It Works & Architecture
Rad IA is built entirely in Object Pascal (Delphi) using the **Open Tools API (OTA)** to interface with the IDE's editor services, message services, and theme services.
The user interface uses a hybrid architecture:
1.  **VCL Layout:** Handles the window docking, settings dialog, toolbars, registry storage, and integration actions.
2.  **Edge WebView2 Engine:** Displays the message history using local HTML5, CSS (incorporating glassmorphism/modern dark UI that adapts to the IDE theme), and JavaScript libraries (Prism.js and Marked.js) to render rich markdown and copyable code blocks without freezing the main IDE thread.
3.  **MVP (Model-View-Presenter) Pattern:** Presentation logic and flow coordination (such as sending messages, changing providers, and saving configuration) are completely decoupled from VCL forms and encapsulated in Presenters (`TChatPresenter` and `TConfigPresenter`), allowing UI components to act as passive Views.
4.  **Storage Abstraction (`ISettingsStorage`):** For better maintainability and testing isolation, the option persistence layer has been abstracted. In production, settings are stored in the Windows Registry (`TRegistrySettingsStorage`), while unit tests run against an in-memory storage (`TMemorySettingsStorage`), ensuring tests do not corrupt the developer's local registry keys.
5.  **Agentic Platform:** A registry shared by chat and MCP coordinates tools, the OTA workspace,
    consent, audit, patches, build, Designer, debugger, and local knowledge.

For an in-depth understanding of the plugin's infrastructure, asynchronous concurrent flows (streaming via background threads), WebView2 lifecycle management on IDE shutdown, and design patterns, please refer to our:

👉 [**Software Architecture Guide (docs/architecture_guide.en.md)**](docs/architecture_guide.en.md)

To understand the physical file structure, unit responsibilities mapping, and step-by-step guides for common maintenance tasks, please refer to our:

👉 [**Developer Source Code Guide (docs/source_code_guide.en.md)**](docs/source_code_guide.en.md)

### 4. Prerequisites
*   **IDE:** Embarcadero Delphi 12 Athens or Delphi 13, with the Win32 IDE or IDE64.
*   **OS:** Windows 10 / 11 (64-bit).
*   **Web Engine:** *Microsoft Edge WebView2 Runtime* installed on the Windows system.
*   **API Keys:** Active developer keys or a local Ollama instance.

### 5. Installation and Configuration

RadIA 2.2 provides a **single visual installer** for Delphi 12 Win32 and Delphi 13 Win32/IDE64.
PowerShell automation and manual installation remain available.
See the [visual installer guide](docs/visual_installer.en.md) for signing and channel publication.
For compilation, registration, and provider configuration, see:

The automated installer also synchronizes local WebView2 assets into `%APPDATA%\RadIA\Web` and
clears the local cache while the IDE is closed, preventing stale JavaScript after updates.

👉 [**Complete Installation and Configuration Guide (docs/install_config.en.md)**](docs/install_config.en.md)

### 5.1 Adding a New AI Provider (Plugin Architecture)

Rad IA employs a metadata-driven provider registry system (`TProviderRegistry`). This allows developers to add new AI backends in a fully dynamic and decoupled manner. For a step-by-step tutorial on how to implement your provider class and perform auto-registration, please check our:

👉 [**Guide for Adding New Providers (docs/new_provider_guide.en.md)**](docs/new_provider_guide.en.md)

### 5.2 Using GitHub Copilot Remotely (Native - Phase 2) or via Local Proxy (Phase 1)

Rad IA supports direct and remote integration with **GitHub Copilot** on the cloud (no local proxies required) through the plugin settings, including an integrated PIN-based login (OAuth Device Flow) and one-click VS Code credential importing.

If you prefer to run a local proxy compatible with the OpenAI API (Phase 1), this also remains supported via dynamic JSON provider registration. For more details, check out:

👉 [**GitHub Copilot Configuration Guide (docs/copilot_proxy_guide.en.md)**](docs/copilot_proxy_guide.en.md)

### 5.3 User and Feature Reference Guides

To get the most out of Rad IA features in your daily development workflow, check our detailed reference guides:

*   👉 [**Everything RadIA can do**](docs/capabilities.en.md): Complete functional map for chat,
    editor, generation, Agent Mode, MCP, Designer, build, tests, debugger, Git, and security.
*   👉 [**Complete RadIA 2.0 User Manual**](docs/user_manual.en.md): Entry point covering agentic
    tool access, capabilities, examples, security, limitations, and references.
*   👉 [**Editor Integration & Code Generation Guide (docs/user_guide_editor_generation.en.md)**](docs/user_guide_editor_generation.en.md): Context-aware editor actions, Smart Diff visual comparison, XML documentation, DTO converter, and full-project prompt generation.
*   👉 [**Diagnostics & Code Analysis Guide (docs/user_guide_diagnostics_analysis.en.md)**](docs/user_guide_diagnostics_analysis.en.md): Smart Build Debugger compilation assistance, call stack parsing via Stack Trace Assistant, and memory leak static auditing.
*   👉 [**Chat Panel & Session Management Guide (docs/user_guide_chat_sessions.en.md)**](docs/user_guide_chat_sessions.en.md): Input text shortcuts, prompt history navigation, persistent multi-sessions, and prompt template backups.
*   👉 [**Agentic Tools Guide**](docs/user_guide_agentic_tools.en.md): Consent, safe execution,
    patches, builds, and request examples.
*   👉 [**MCP Integration Guide**](docs/mcp_integration_guide.en.md): Stdio bridge, per-PID discovery,
    MCP sessions, security, and diagnostics.
*   👉 [**Local Knowledge Guide**](docs/user_guide_project_knowledge.en.md): Indexing, search,
    persistence, privacy, and rebuild.
*   👉 [**Agentic Designer and Debugger Guide**](docs/user_guide_designer_debugger.en.md):
    Components, properties, events, breakpoints, watches, and control.
*   👉 [**Agentic Troubleshooting**](docs/troubleshooting_agentic_platform.en.md): Tool, MCP,
    workspace, and knowledge diagnostics.
*   👉 [**Commit Message Convention (docs/commit_convention.en.md)**](docs/commit_convention.en.md): English commit message standard using prefixes like `feat`, `fix`, `docs`, `refactor`, and others.
*   👉 [**Branch Naming Convention (docs/branch_convention.en.md)**](docs/branch_convention.en.md): `<type>/<description>` standard with prefixes like `feat/`, `fix/`, `docs/`, `test/`, and `chore/`.
*   👉 [**Release Finalization Process (docs/release_process.en.md)**](docs/release_process.en.md): Checklist to update versions, validate builds, merge `develop`/`main`, create tags, and clean up branches.
*   👉 [**Developer Source Code Guide (docs/source_code_guide.en.md)**](docs/source_code_guide.en.md): Unit mapping, step-by-step common maintenance workflows, and best practices in the Delphi compiler.

---

### 6. Repository Structure
```
PluginDelphiIA/
│
├── .github/                            # GitHub configurations and templates
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md               # Bug report template (PT)
│   │   ├── bug_report.en.md            # Bug report template (EN)
│   │   ├── feature_request.md          # Feature request template (PT)
│   │   ├── feature_request.en.md       # Feature request template (EN)
│   │   └── config.yml                  # Template chooser configuration
│   └── pull_request_template.md        # Bilingual Pull Request template
│
├── docs/                               # Documentation and visual resources
│   ├── images/                         # UI screenshots and mockups
│   ├── backlog.md / backlog.en.md      # Kanban board and technical evolution backlog
│   ├── roadmap.md / roadmap.en.md      # Strategic milestones planning
│   ├── features.md / features.en.md    # Feature catalog and compatibility matrix
│   ├── install_config.md / .en.md      # Installation and API keys guide
│   ├── compliance.md / .en.md          # Legal notices, privacy, and compliance
│   ├── new_provider_guide.md / .en.md  # Guide to adding new providers
│   ├── user_guide_*.md                 # Detailed usage manuals (chat, editor, stack trace)
│   ├── mcp_integration_guide*.md       # MCP client integration with the IDE
│   ├── tool_*.md                       # Tool catalog, extensions, and security
│
├── RadIA.groupproj                     # Delphi Project Group solution
├── RadIA.dpk                           # Delphi design-time package source (BPL)
├── RadIA.dproj                         # Delphi package project configurations
├── RadIA.rc                            # Resource script file
│
├── Source/                             # Core plugin source code
│   ├── Core/                           # Core units (interfaces, settings, DTOs)
│   ├── Providers/                      # AI API Clients (Gemini, OpenAI, Claude, Ollama)
│   ├── Integration/                    # ToolsAPI IDE integration (hooks, wizards, options)
│   ├── MCP/                            # MCP stdio bridge for external clients
│   └── UI/                             # VCL Forms, Frames, and dialog windows
│       └── Web/                        # Local HTML5/JS chat resources (WebView2)
│           └── vendor/                 # Third-party libraries (Prism, Marked, diff2html)
│
├── Tests/                              # DUnitX Integration and Unit Tests
│   └── Source/                         # Unit tests implementation files
│
├── .editorconfig                       # Formatting and line ending standards
├── agents.md                           # Guidelines and restrictions for AI agents (LLMs)
├── build.ps1                           # Automated build and installation script
├── eslint.config.js                    # ESLint Javascript linter settings
└── package.json                        # Node npm package dependencies and scripts
```

### 7. Terms of Use and Corporate Compliance

For guidelines on corporate compliance (GDPR/LGPD), data privacy, API key encryption using Windows DPAPI, and legal disclaimers regarding AI-generated code, please refer to our:

👉 [**Terms of Use, Compliance, and Privacy Guide (docs/compliance.en.md)**](docs/compliance.en.md)
