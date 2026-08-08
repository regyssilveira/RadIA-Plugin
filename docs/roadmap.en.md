# Rad IA - Evolution Roadmap

This document outlines the strategic planning and long-term vision of the **Rad IA** AI assistant, focusing on bringing productivity and solving real pain points for Delphi developers in their daily workflows.

> [!NOTE]
> Rad IA follows a **community-driven open-source development model**.
> *   For a detailed view of feature priorities, effort estimates, and impacts, check the [Feature Prioritization Matrix (feature_prioritization_matrix.md)](feature_prioritization_matrix.md).
> *   For technical details of past and pending implementations (such as class names, successful DUnitX tests, and commits), refer to the [Evolution Backlog (backlog.en.md)](backlog.en.md).

---

## 📅 Completed Releases History

### v2.3.0 — Internal RTK and recoverable context

- deterministic DUnitX, Git diff, build, and knowledge result compaction;
- complete per-session storage with summary/range recovery;
- context budget, operational profiles, and sanitized metrics;
- 126-tool catalog and measured viability evidence.

Below are the achievements and values delivered in each release version of the plugin:

### Secure agentic platform — completed

RadIA evolved from multi-provider chat into an IDE-integrated platform with a tool registry, OTA
workspace, consent, audit, reversible patches, build, MCP, Form Designer, debugger, inline review,
local knowledge, and versioned extensions.

The active matrix is validated on Delphi 12 Win32 and Delphi 13 Win32/IDE64. See the
[agentic roadmap](agentic_roadmap.md) and [completion audit](agentic_completion_audit.md).

### v2.2.2 — DEXT journeys and guided experience

- guided CLI/MCP setup and configuration organized by provider, CLI, and MCP responsibility;
- minimal and controller-based DEXT journeys with conversational requirement intake;
- integrated `/help`, fillable slash-command examples, and external-browser documentation links;
- transport-compatible model discovery and a truly optional Agent Runtime token limit.

### v2.2.1 — Diagnostics and guided experience

- structured `/doctor` with readiness, recommendations, and next action;
- sanitized and filterable `/status` for provider, agent, CLI, MCP, security, editor, and tools;
- consent-guided CLI/MCP installation, authentication, and recovery;
- task-oriented documentation and an operational catalog of 124 tools;
- debugger stability, dynamic model refresh, and layout and hint improvements.

<details>
  <summary><b>📦 v0.0.29 — Editor Selection Fixes and Gemini OAuth Block (Completed)</b></summary>

  *   **Value Delivered**: Fixed critical issues regarding editor active selection detection and resets inside Delphi IDE, translated typing status to English, and implemented safety warnings to block the Google Gemini OAuth flow due to verification pending status.
  *   **Highlights**:
      *   Corrected text selection detection by querying `LView.Block` instead of `LEditBuffer.EditBlock` to accurately recognize when there is no visible active selection on screen, thus fallback to explaining the entire unit.
      *   Introduced programmatical reset and cursor collapsing (`LEditBlock.Reset` and `LView.Position.Move`) after replacing/inserting code to prevent newly generated code from staying marked as selected in Delphi.
      *   Translated the modern typing indicator text in the chat from `"Pensando..."` to `"Thinking..."` for complete consistency with standard en-US project-wide locale guidelines.
      *   Implemented preventive barriers for Gemini OAuth logins and queries, displaying clear warning messages asking the user to use API Keys for now due to pending verification status, omitting any mention of the deprecated "Web Login".
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.29)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.28 — Open Tools API Adapter and Network Testing (Completed)</b></summary>

  *   **Value Delivered**: Decoupled the dependency on the Delphi Open Tools API by introducing the `IRadIAEditorAdapter` pattern, enabling offline automated testing of the IDE code editor buffer and introducing network tests against IDE hangs.
  *   **Highlights**:
      *   Created `IRadIAEditorAdapter` and `TRadIAOTAEditorAdapter` to isolate the plugin from direct Delphi `ToolsAPI` dependencies.
      *   Added unit tests via `TMockEditorAdapter` simulating virtual text buffers, cursor movements, selection, and safe code replacements.
      *   Tested resilience under network latency and streaming cancellation using `TestProviderBase_CancellationAndTimeout`.
      *   Resolved resource sharing and file locking issues when handling template files on Windows.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.28)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.27 — Resolution of Code Smells and Test Coverage Expansion (Completed)</b></summary>

  *   **Value Delivered**: Complete elimination of technical debt (code smells) on SonarQube and regression protection through expanded automated unit testing for AI providers (reaching 83.9% overall coverage and 81.0% on new code), satisfying Quality Gate thresholds.
  *   **Highlights**:
      *   Fixed Pascal casing nomenclature and unused implementation imports inside the unit testing suite.
      *   Created isolated RTTI-based synchronous tests to validate base URLs and model filtering logic for multiple backends (OpenAI, DeepSeek, Groq, Mistral, Qwen, OpenRouter, AzureOpenAI, and LMStudio).
      *   Robust test coverage for Gemini model discovery (`FetchAvailableModelsAsync`) under success, network failure, and missing key scenarios.
      *   Unit testing for nested and direct JSON error parsing formats in the shared provider base class.
      *   Reached 100% code coverage on core data types `RadIA.Core.Types` and `RadIA.Core.ChatMessage`.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.27)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.26 — Visual Provider Icons and Architectural Refactoring (Completed)</b></summary>

  *   **Value Delivered**: Premium and high-fidelity visual identification of each AI provider using official SVG vector logos, combined with a deep architectural overhaul introducing Dependency Inversion (DIP), Dependency Injection, and I/O test isolation for maximum stability and offline testability.
  *   **Highlights**:
      *   Replaced the generic robot icon with official brand SVGs in the chat panel, customized provider dropdown, and dynamic colored assistant message avatars.
      *   Introduced a thread-safe IoC Container (`TRadIAContainer`) and dependency injection for core services and utilities.
      *   Isolated and decoupled the Delphi IDE API (`IRadIAIDEAdapter`), allowing complete mock support inside DUnitX tests.
      *   Complete developer AppData protection inside tests using GUID-based transient folders created on `Setup` and swept clean in `TearDown`.
      *   Fixed editor code pasting on a single line by integrating the CRLF line-break normalizer `IRadIATextNormalizer`.
      *   Decoupled utilities into specialized services: HTTP client (`IRadIAHttpClient`), API error parser (`IRadIAErrorDecoder`), and localized translation provider (`IRadIALocalizer`).
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.26)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.25 — Simplified Web Login and Safe Apply Changes (Completed)</b></summary>

  *   **Value Delivered**: More direct and reliable ChatGPT/Gemini web login, with explicit confirmation for already authenticated sessions, and safer diff application in the editor to prevent duplicated code.
  *   **Highlights**: official provider page opened with the correct data folder, automatic exit when the session is already signed in, visual identification as **Web Login** instead of a misleading model name, and OTA replacement based on the original block when the editor selection is lost.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.25)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.24 — Delphi Compiler & OS Warning Scanner and Menu Protection (Completed)</b></summary>

  *   **Value Delivered**: Intelligent static auditing of compiler warnings and Windows resource leaks for code robustness, combined with a permanent resolution for editor elision (code folding) crashes in the Delphi 13 IDE.
  *   **Highlights**: Contextual scan editor action, `/scanwarnings` slash command, dedicated `rpScanWarnings` profile, and structural protection against reentrant menu hook events.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.24)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.23 — Smart SQL Optimizer in Editor (Completed)</b></summary>

  *   **Value Delivered**: Smart, contextual optimization of SQL query strings directly in the IDE editor, without breaking the developer's active workflow.
  *   **Highlights**: New context menu item in the editor, `/sqloptimize` slash command, dedicated low-temperature (`0.1`) and high-token configuration mapped in the service layer, and comprehensive DUnitX test coverage.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.23)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.22 — Concise Prompts and Editor Line Break Preservation (Completed)</b></summary>

  *   **Value Delivered**: More direct responses with lower token usage, while editor menu actions preserve Pascal formatting when sending code to chat.
  *   **Highlights**: preserved `pascal` blocks in slash commands, shorter default templates, new persisted **Prefer concise AI responses** setting, and DUnitX coverage for preprocessing behavior.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.22)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.21 — Create Example from Comment (Completed)</b></summary>

  *   **Value Delivered**: Less friction to turn intent into Delphi code, allowing users to write a method signature and an intent comment so Rad IA can generate the method body automatically.
  *   **Highlights**: cursor-based method detection, support for `//`, `{ ... }`, and `(* ... *)` comments, direct insertion below the comment, validations to avoid overwriting existing logic, and Web Login compatibility.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.21)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.20 — Smart Diff with Web Login and Configuration Persistence (Completed)</b></summary>

  *   **Value Delivered**: More reliable Smart Diff refactorings with Web Login providers, preserving code formatting and preventing configuration regressions.
  *   **Highlights**: Smart Diff no longer requires API keys for Web Login providers, responses are requested as a single `pascal` block, the bridge preserves code indentation, configuration tests are isolated from the user's real registry, and the editor hook is less intrusive during new project creation.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.20)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.19 — Editor Actions with Active Unit Fallback (Completed)</b></summary>

  *   **Value Delivered**: Less friction in daily editor actions, allowing commands to run even when the user has not manually selected code.
  *   **Highlights**: automatic fallback to the active unit, Smart Diff replacing the whole buffer when appropriate, chunked editor reading, and a more stable Delphi 13 context-menu hook during new project creation.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.19)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.18 — Chat UX, Web Login, and Rad IA Branding Polish (Completed)</b></summary>

  *   **Delivered Value**: A clearer and more predictable daily chat experience, with smoother startup, IDE-aligned theming, protected sessions during processing, and a more helpful web login flow.
  *   **Highlights**: welcome screen with quick actions, on-demand history loading, Mountain Mist treated as light, multiple chats no longer reordered on selection, actions locked during responses, full-screen generator, visual web login fallback, and the product name displayed as **Rad IA**.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.18)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.17 — Stable Editor Menu and WebView2 Chat (Completed)</b></summary>

  *   **Value Delivered**: More predictable editor actions: selected code reaches the chat formatted, `/explain` no longer falls into review, and Delphi 12/13 load updated web assets consistently.
  *   **Highlights**: Pascal blocks rendered in user messages, native **Explain Code** template, legacy slash-command migration, `chat.js` cache busting, and installer synchronization of `%APPDATA%\RadIA\Web`.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.17)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.16 — MVP, Storage Abstraction, and Editor Robustness (Completed)</b></summary>

  *   **Value Delivered**: A more testable and stable internal foundation, with MVP-decoupled screens and a more reliable Delphi 12/13 editor context menu.
  *   **Highlights**: `TChatPresenter`, `TConfigPresenter`, `ISettingsStorage`, in-memory settings storage for tests, editor hooks via OTA notifiers, and the **Rad IA** submenu at the top of the editor context menu.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.16)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.15 — Two-Layer Templates and Overlays (Completed)</b></summary>

  *   **Value Delivered**: Assures that new plugin updates bring fresh community prompts without overriding or erasing your local personal customizations.
  *   **Highlights**: Segregation of native and user templates, visual origin indicator in IDE options, and a "Restore Default" action.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.15)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.14 — Dynamic Templates and Backups (Completed)</b></summary>

  *   **Value Delivered**: Freedom to create custom slash commands (`/`) mapped to repetitive prompts, and ease in migrating/sharing your prompt libraries between different workstations.
  *   **Highlights**: Full dynamic slash commands customization, JSON backup importing/exporting with merge or overwrite options, and a native Clean Architecture Delphi template.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.14)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.13 — Full Project Generation via Prompts (Completed)</b></summary>

  *   **Value Delivered**: Extreme speed when starting new ideas and microservices. The AI constructs the entire folder structure and files, loading them directly into your active IDE ready to run.
  *   **Highlights**: Transactional file generator, high-fidelity glassmorphism file explorer in chat, and automated project loading inside the Delphi IDE.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.13)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.12 — AWS Bedrock Provider & Stabilization (Completed)</b></summary>

  *   **Value Delivered**: Integration with top Amazon models (Anthropic Claude, Llama 3) inside strict enterprise environments demanding security under AWS cloud environments.
  *   **Highlights**: Native AWS Bedrock support, SigV4 cryptographic signing, and binary EventStream parser.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.12)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.11 — Azure, Qwen, and Mistral AI Providers (Completed)</b></summary>

  *   **Value Delivered**: Expansion of the plugin's native AI catalog to comply with internal IT security policies of different companies.
  *   **Highlights**: Native support for Azure OpenAI, Alibaba Qwen 2.5, and Mistral AI, with dedicated tabs and shortcuts inside the IDE options panel.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.11)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.10 — Native GitHub Copilot Support (Completed)</b></summary>

  *   **Value Delivered**: Native, official, and simplified authentication with the world's most popular coding AI directly from the Rad IA chat panel, without local proxies.
  *   **Highlights**: Native cloud GitHub Copilot support, interactive device PIN login workflow, and one-click active token import from VS Code settings.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.10)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.9 — Multi-IDE Support and Build Encording (Completed)</b></summary>

  *   **Value Delivered**: Ease of deployment on workstation environments running multiple Delphi IDE installations simultaneously (e.g., Alexandria and Athens).
  *   **Highlights**: Interactive PowerShell installer with Windows Registry autodiscovery, and localized console encoding fixes.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.9)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.8 — Local LM Studio Provider and Stability (Completed)</b></summary>

  *   **Value Delivered**: Workstation autonomy using local, offline AI models running on private corporate servers or local hardware via LM Studio.
  *   **Highlights**: Native LM Studio provider, and a dedicated light/dark IDE settings page.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.8)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.7 — Optimized System Prompt (Completed)</b></summary>

  *   **Value Delivered**: Faster, cleaner, and strictly focused AI responses targeting quality Delphi Object Pascal code, bypassing verbose explanations.
  *   **Highlights**: Factory-optimized default system prompt that respects existing user customizations saved in the Windows Registry.
</details>

<details>
  <summary><b>📦 v0.0.6 — JSON Providers and Copilot Proxy Support (Completed)</b></summary>

  *   **Value Delivered**: Instant extensibility. Allows adding any new AI compatible with the OpenAI API protocol simply by saving a local JSON file, without reinstalling or compiling the BPL.
  *   **Highlights**: Dynamic providers loadable via local JSON configs, and initial support for Copilot proxy utilities.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.6)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.5 — Decoupling and UI Settings Fixes (Completed)</b></summary>

  *   **Value Delivered**: Improved internal robustness of IDE third-party options and permanent removal of tab overlaps.
  *   **Highlights**: Migrated configuration keys to dynamic string-based identifiers, and fixed UI frame rendering in Delphi's Options.
</details>

<details>
  <summary><b>📦 v0.0.4 — Advanced Productivity and Static Analysis (Completed)</b></summary>

  *   **Value Delivered**: Automation of repetitive tasks (like writing DTO models) and call stack analyses matching the active code editor line.
  *   **Highlights**: DTO converter (JSON/SQL to Pascal), Stack Trace Assistant for exception logs, static analysis for memory leaks, and a WebView2 slash command (`/`) popup autocomplete menu.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.4)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.3 — Runtime Stability (Completed)</b></summary>

  *   **Value Delivered**: Assurance that the plugin runs smoothly in the background without causing IDE crashes, BPL memory leaks, or Access Violations in everyday usage.
  *   **Highlights**: Central registry for dynamic AI loading, and thread-safe callbacks during background async HTTP requests.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.3)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.2 — Multiple Sessions and Token Budgeting (Completed)</b></summary>

  *   **Value Delivered**: Conversation organization separated by task or project, and budget controls over API key usage.
  *   **Highlights**: Collapsible multiple persistent sessions sidebar, local monthly token limit widget inside status bar, and OpenRouter support.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.2)](backlog.en.md).*
</details>

<details>
  <summary><b>📦 v0.0.1 — Initial Release (Completed)</b></summary>

  *   **Value Delivered**: The AI natively coupled inside the Delphi IDE sidebar, providing quick incremental token responses and visual editor shortcuts.
  *   **Highlights**: Dockable chat panel with WebView2, support for 6 AI backends, SSE streaming, local history, editor right-click menu actions, Smart Diff side-by-side visual comparison, Smart Build compilation error debugger, and auto XML documentation.
  *   👉 *See implementation details and tests in the [Technical Backlog (v0.0.1)](backlog.en.md).*
</details>

---

## Uncommitted future inventory

The `0.1.0`, `0.2.0`, and `0.3.0+` numbers belonged to planning before the 2.x line and are no
longer target versions. After 2.2.2, each item must be selected and detailed in a new goal before it
receives a version.

### Confirmed functional gaps

*   **Automatic Code Review on Save**: the save event exists, but does not trigger background review.
*   **Multi-file trace and exception-log diagnostics**: `/stacktrace` exists, but does not yet resolve all units automatically or extract structured MadExcept/EurekaLog dumps.
*   **Uses Clause Optimizer (Clean Uses)**: not implemented.
*   **Mock Generator for Unit Tests**: not implemented as a dedicated journey.
*   **Swagger/OpenAPI for existing projects**: new DEXT projects were covered in 2.2.2; scanning existing Horse/RAD Server routes remains pending.
*   **Bidirectional DFM vs PAS Analysis**: current mutations preserve consistency, but orphan auditing remains pending.
*   **Smart Migrate**, **cache panel**, and **API.md generation** remain pending and unprioritized.

### Absorbed capability

*   **Applied Refactoring History**: absorbed in 2.0.0 by reversible patches, timeline, audit, and checkpoints.

### Strategic opportunities
*   **BDE/ADO/dbExpress ➔ DEXT with FireDAC Migration**: Interactive assistant that converts legacy data access controls and rewrites code for the modern DEXT ORM using FireDAC.
*   **Legacy Form Decomposer (Code-Behind Extractor)**: Decouple business logic out of form visual button clicks into standalone service units.
*   **Threads and PPL Assistant**: Helper to rewrite heavy synchronous routines to run asynchronously using thread-safe task handlers.
*   **Automated Internationalization (i18n Wizard)**: localization infrastructure exists; the user-project wizard remains pending.

### Out of scope

*   **Lazarus / Free Pascal**: discarded; current support remains Delphi 12 and 13.
