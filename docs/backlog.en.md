# Rad IA - Evolution Backlog

> **Active matrix:** Delphi 12 Win32 and Delphi 13 Win32/IDE64. Delphi 11 references in completed
> items describe only the historical matrix of that release and do not represent current support.

This document registers the development status, future planning, and technical implementation history of **Rad IA** plugin tasks.

---

## 📊 Kanban Dashboard

The board below separates delivered work, actual gaps, and items with no committed release. `0.x`
numbers are retained only for historical deliveries. The 2.7.0 line closes a deterministic baseline;
new items require a later formal baseline without reopening passed requirements.

| Feature / Task | Status | Difficulty | Priority | Target Version |
| :--- | :---: | :---: | :---: | :---: |
| **Secure Agentic Platform for Delphi 11/12/13** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v1.0.0 |
| **RadIA 2.0 Goal — Complete Development Journey** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.0.0 |
| **RadIA 2.0 Goal — Leading the Delphi Experience** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.0.0 |
| **2.1 Goal — Autonomous Runtime Failure Reproduction** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.1.0 |
| **2.2 Goal — Dynamic Memory Diagnostics with FastMM5** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.2.0 |
| **Diagnostics, CLI/MCP UX, and Centralized Documentation** | ✅ Completed | 🟡 Medium | ⭐⭐⭐⭐⭐ Critical | v2.2.1 |
| **DEXT Journeys, Integrated Help, and Conversational Intake** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.2.2 |
| **Explicit Routes, Restored Pro Login, and Universal Copy** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.3.1 |
| **Goal — Close six experience gaps** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.3.1 |
| **Goal — Expand the complete experience** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.4.0 |
| **Goal — Skill portability and high-fidelity terminal** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.4.0 |
| **Patch 2.6.2 — Chat usability and project creation** | ✅ Completed | 🟢 Low | ⭐⭐⭐⭐ High | v2.6.2 |
| **Deterministic functional closure** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.7.0 |
| **Verifiable Runtime Baseline and Catalog** | ✅ Completed | 🟡 Medium | ⭐⭐⭐⭐⭐ Critical | v1.0.x |
| **Native Observable Agent Runtime** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v1.1.0 |
| **Deterministic New Project Wizard** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v1.2.0 |
| **Multi-file Editing and Transactional Diff** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v1.3.0 |
| **Visual Design↔Code Flow** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐ High | v1.4.0 |
| **Self-correcting Build and DUnitX Runner** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v1.5.0 |
| **Event-driven Debug Agent** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v1.6.0 |
| **Reviewable Git and Delivery Pipeline** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐ High | v1.7.0 |
| **CLI Manager, Terminal, and Hybrid Experience** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.0.0 |
| **E2E Hardening and RadIA 2.0 Release** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.0.0 |
| **Editor Selection Fixes and Gemini OAuth Block** | ✅ Completed | 🟢 Low | ⭐⭐⭐⭐ High | v0.0.29 |
| **Open Tools API Adapter and Network Testing** | ✅ Completed | 🟡 Medium | ⭐⭐⭐⭐ High | v0.0.28 |
| **Resolution of Code Smells and Test Coverage Expansion** | ✅ Completed | 🟢 Low | ⭐⭐⭐⭐ High | v0.0.27 |
| **Real Provider Icons with Official SVGs** | ✅ Completed | 🟢 Low | ⭐⭐⭐⭐ High | v0.0.26 |
| **Simplified Web Login and Safe Apply Changes** | ✅ Completed | 🟢 Low | ⭐⭐⭐⭐ High | v0.0.25 |
| **Delphi Compiler & OS Warning Scanner** | ✅ Completed | 🟢 Low | ⭐⭐⭐⭐ High | v0.0.24 |
| **Smart SQL Optimizer in Editor** | ✅ Completed | 🟢 Low | ⭐⭐⭐⭐ High | v0.0.23 |
| **Automatic Code Review on Save** | 🔲 Pending | 🟡 Medium | ⭐⭐⭐⭐ High | No committed version |
| **Applied Refactoring History** | ✅ Absorbed by patches, timeline, and checkpoints | 🟢 Low | ⭐⭐⭐ Medium | v2.0.0 |
| **Uses Clause Optimizer (Clean Uses)** | 🔲 Pending | 🟡 Medium | ⭐⭐⭐⭐ High | No committed version |
| **Mock Generator for Unit Tests** | 🔲 Pending | 🟡 Medium | ⭐⭐⭐⭐ High | No committed version |
| **Smart Multi-Unit Trace Resolver** | 🔲 Pending | 🟡 Medium | ⭐⭐⭐⭐⭐ Critical | No committed version |
| **MadExcept / EurekaLog Context Extractor** | 🔀 Merge with trace diagnostics | 🟡 Medium | ⭐⭐⭐⭐⭐ Critical | No committed version |
| **OpenAPI/Swagger for existing projects** | 🟨 Partial; new DEXT projects covered | 🟡 Medium | ⭐⭐⭐⭐ High | Partial in v2.2.2; residual uncommitted |
| **Bidirectional Semantic Analysis (DFM x PAS)** | 🟨 Partial; mutations preserve consistency | 🟡 Medium | ⭐⭐⭐⭐ High | Residual has no committed version |
| **Version Migration Assistant (Smart Migrate)** | 🔲 Pending | 🟡 Medium | ⭐⭐⭐⭐ High | No committed version |
| **Cache Management Panel** | 🔲 Pending | 🟡 Medium | ⭐⭐⭐ Medium | No committed version |
| **BDE/ADO/dbExpress ➔ DEXT with FireDAC Migration** | 💡 Strategic opportunity | 🔴 High | ⭐⭐⭐⭐ High | No committed version |
| **Legacy Form Decomposer (Code-Behind)** | 💡 Strategic opportunity | 🔴 High | ⭐⭐⭐⭐ High | No committed version |
| **Threads and PPL Assistant** | 💡 Strategic opportunity | 🔴 High | ⭐⭐⭐⭐ High | No committed version |
| **Automated Internationalization (i18n Wizard)** | 🟨 Infrastructure ready; wizard pending | 🔴 High | ⭐⭐⭐⭐ High | Residual has no committed version |
| **Smart Inline Autocomplete (Ghost Text)** | ✅ Completed | 🔴 High | ⭐⭐⭐⭐⭐ Critical | v2.0.0 |
| **Project Docs Auto Generation (API.md)** | 🔲 Pending | 🟡 Medium | ⭐⭐⭐ Medium | No committed version |
| **Native macOS/Linux Support (Lazarus)** | 🚫 Discarded | 🔴 High | 🟢 Low | Out of scope |

---

## ✅ 1. Historical 2.0 execution record (completed)

*   Goal for leading the Delphi development experience.
    *   M0 completed: automated global Sonar gate with zero issues, 82.3% coverage, and 2.3%
        duplication, with reproducible evidence for the 2.0.0 candidate.
    *   M1–M3: deliver Ghost Text, an interactive terminal, and a unified execution center.
    *   M1 delivered in this increment: OTA Ghost Text capture now resolves the current symbol
        directly from the live buffer and cursor line, without depending on the saved file.
    *   M1 delivered in this increment: five configurable shortcuts use native OTA partial
        bindings with persistence, profile validation, duplicate rejection, and conflict detection.
    *   M1 delivered in this increment: multiline Ghost Text uses per-line virtual overlays, a
        continuation lane that avoids real code, and EOF overflow while preserving the buffer.
    *   M1 validated in real IDEs: local preparation and OTA painting passed on Delphi 11, 12, and
        13 Win32 plus Delphi 13 IDE64, with reproducible evidence and no provider content transfer.
    *   M2 delivered in this increment: an incremental ANSI SGR parser and rich output preserve
        colors and bold styling even when escape sequences arrive split across chunks.
    *   M2 delivered in this increment: continuous stdin keeps the input channel open and accepts
        prompt responses through **Send**, with thread-safe writes and tree cancellation preserved.
    *   M2 delivered in this increment: native ConPTY sessions use UTF-8 channels, character resize,
        dynamic fallback, and a real shell test covering input and shutdown.
    *   M2 delivered in this increment: incremental reverse search through `Ctrl+R` filters history
        and walks older matches without requiring the mouse.
    *   M2 delivered in this increment: a visual ANSI/CSI buffer preserves per-cell styling and
        applies carriage return, overwrite, movement, positioning, erase, and cursor save/restore.
    *   M2 complete: multiple tabbed sessions keep independent processes, buffers, and input;
        closing a tab cancels only its own tree and preserves at least one open session.
    *   M3 delivered in this increment: the execution center shows an expandable timeline with
        arguments, result, error, correlation, duration, mutation, and validation indicators.
    *   M3 delivered in this increment: the run index searches checkpoints through **Runs** or
        `/agent history`, without exposing tool arguments and results.
    *   M3 delivered in this increment: **Edit plan** and `/agent plan` revise the validated plan
        before approval and block changes after execution starts.
    *   M3 delivered in this increment: **Replay step** and `/agent replay` repeat an audited call
        only while paused, reusing consent and recording the source step.
    *   M3 delivered in this increment: each step shows the tool's formal risk and aggregates
        affected files only from recognized path fields.
    *   M3 delivered in this increment: structured evidence shows build duration and messages,
        plus the complete counts from the latest DUnitX run and authoritative coverage summary.
    *   M3 delivered in this increment: simple and multi-file patches show per-file diff blocks
        inside the timeline while apply and revert remain in the central consent flow.
    *   M3 delivered in this increment: status, diff, fingerprinted preview, and local commit SHA
        appear as reviewable Git evidence in the timeline, without automatic push.
    *   M3 delivered in this increment: state, breakpoints, call stack, actions, values, watches,
        and events appear as read-only debug evidence inside the timeline.
    *   M3 validated in real IDEs: approval, pause, persisted checkpoint, new-instance resume, and
        completion with `GetIDEState` passed on Delphi 11, 12, 13 Win32, and Delphi 13 IDE64.
    *   M4–M6: simplify extensions, semantic knowledge, and guided installation.
    *   M4 in progress: `*.radia.json` manifests add chat commands with a versioned schema, minimal
        permission, atomic validation, diagnostics, and reload without restarting the IDE.
    *   M4 delivered in this increment: **Tools > Rad IA Extensions...** installs, updates, enables,
        disables, diagnoses, and removes manifests; atomic writes and rollback preserve the working
        version when a candidate or the installed set is rejected.
    *   M4 delivered in this increment: `.radiaext` packages provide a versioned envelope, closed
        file list, size, and SHA-256; import blocks tampering, extra or duplicate entries, ZIP bombs,
        path traversal, and identity mismatches before transactional activation.
    *   M4 delivered in this increment: v2 packages use RSA-SHA256 verified by Windows CNG, public
        key fingerprints, first-use consent, an atomic trust store, and visual publisher revocation;
        v1 packages remain compatible through an explicit per-use warning.
    *   M4 delivered in this stage: the remote catalog has an asynchronous visual browser, search,
        persisted URL, bounded schema, HTTPS without redirects, transactional downloads, and
        package size, hash, identity, and publisher binding to signed packages.
    *   M4 delivered in this stage: manifest schema 2 adds declarative templates and skills,
        preserves schema 1 commands, and keeps every capability restricted to `chat.prompt`.
    *   M4 delivered in this stage: schema 3 publishes internal tool aliases in the registry shared
        by chat and MCP, with extension namespaces, explicit `tool.alias` permission, inherited
        risk, chain blocking, and catalog rollback when a target or registration is invalid.
    *   M4 delivered in this stage: schema 5 provides audited workflows of up to 16 internal tools
        without arbitrary shells, with inherited maximum risk, bounds, fail-fast, and per-step
        policy enforcement.
    *   M4 expansion implemented on the current branch: schema 6 and `.radiaext` v3 carry
        references, knowledge, templates, and assets; Addon Studio sandboxes, installs, exports,
        and signs the set with clean replacement, removal, and manifest/resource rollback.
    *   M4 validated in real IDEs: hot-load, shared registration, and audited two-step execution
        passed on Delphi 11, 12, 13 Win32, and Delphi 13 IDE64.
    *   M5 delivered in this stage: search and rebuild expose local latency, status reports the
        estimated size, and every response retains the isolated workspace identity without telemetry.
    *   M5 delivered in this stage: incremental indexing covers Pascal, textual DFM/FMX, projects,
        and documentation with confined discovery, limits, and one shared OTA policy.
    *   M5 delivered in this stage: the OpenAI-compatible remote foundation validates
        HTTPS/loopback, timeouts, limits, dimensions, and responses without putting the API key in
        the payload; visual activation remains blocked on separate remote consent.
    *   M5 delivered in this stage: embedding selection is fail-closed and keeps the local
        provider when remote use is disabled, lacks separate consent, or has invalid settings;
        enabling semantic search alone never authorizes source code transmission.
    *   M5 delivered in this stage: **Security & Consent** configures the remote provider without
        registry editing, protects the API key with DPAPI, and validates consent, endpoint, model,
        and limits before applying dynamic selection to the index.
    *   M5 delivered in this stage: completed and approved histories can feed the index after
        explicit consent, isolated by project and without tool payloads.
    *   M5 validated in real IDEs: local semantic indexing and search, provenance, navigation,
        metrics, retrieval, and isolation passed on Delphi 11, 12, 13 Win32, and Delphi 13 IDE64.
    *   M6 delivered in this stage: onboarding v2 runs `/doctor` directly; the first-value
        diagnostic returns a score, checks, and next action, verifies `GetIDEState`, and requires
        MCP only for a CLI executor.
    *   M6 delivered in this stage: the manifested release installer installs, repairs, and
        uninstalls with `-PlanOnly`, preserves the loader and user data by default, and removes
        `%APPDATA%\RadIA` only after explicit `-RemoveUserData`.
    *   M6 validated in real IDEs: doctor, chat, terminal, bridge, catalog, and first tool passed
        on Delphi 11, 12, 13 Win32, and Delphi 13 IDE64, including guidance when a provider is
        not configured yet.
    *   M6 delivered in this stage: one visual installer detects and selects all three targets,
        validates packages before compilation, and records SHA-256 hashes and Authenticode state.
        Code signing and marketplace distribution do not block publication of the open project.
    *   M6 automated in this stage: the tag workflow rebuilds all three packages from the exact
        commit, publishes hashes and evidence, and retains reproducible manual build instructions.
    *   M7–M8 completed: specialized journeys and the 2.0.0 candidate proven across the full matrix.
    *   M8 delivered: terminal proven across the full matrix with a native window, required
        controls, input, output, usable geometry, five associated labels, and 11 keyboard tab
        stops; Web surfaces passed semantic tests and UI Automation inspection.
    *   Plan and criteria: [Leadership goal](experience_leadership_goal.en.md).

*   In-IDE E2E hardening and RadIA 2.0 release preparation.
    *   Historical record: the matrix current at that time, Delphi 13 Win32/IDE64 installation,
        and three smoke cycles per architecture proved that milestone's catalog, rendered WebView2,
        real MCP editing, tool-driven build, that milestone's direct suite, VCL template
        creation/open/build/rollback, real Form Designer editing with consent,
        and a
        real debug flow with breakpoint, call stack, and timeline, plus the compiler-error,
        diagnostics, correction, rebuild, DUnitX, and a reviewable Git commit with selected paths.
    *   Historical compatibility record: Delphi 11 and 12 passed BPL loading, the MCP catalog
        current at that time, and clean shutdown; Delphi 13 passed three consecutive cycles while
        checking for any remaining root process.
    *   Visually completed: the panel is now created through OTA's native
        `INTACustomDockableForm` API as a `TOTADockForm`, with rendered WebView2, theme, chat, and
        agent-mode button, without the former blank screen. The IDE now owns the host, docking
        commands, and desktop state.
    *   Form Designer completed: real `TButton` creation, listing, and rollback through preview and
        consent, using native VCL classes and deterministic bounds.
    *   Build completed: unpersisted project groups no longer open modal dialogs during
        `ValidateCreatedProject`.
    *   Manual visual acceptance: lateral dropping remains user-driven because the elevated IDE
        blocks synthetic cross-process input. Native creation, visibility, and host persistence are
        covered by the automated smoke.
    *   Shutdown completed: editor and debugger OTA hooks are now unregistered before their objects
        are abandoned during shutdown, without freeing VCL/WebView2. The installed build passed
        three consecutive Delphi 13 load and shutdown cycles with the catalog current at that time
        and no `bds.exe` retention.
    *   Continuous matrix E2E completed: Delphi 11, 12, and 13 Win32 plus Delphi 13 IDE64
        autonomously passed template creation, Form Designer, live editing, failure and correction,
        build, 736 tests, debugging with call stack/timeline, a reviewable Git commit, and shutdown
        in one journey. Current consolidated proof must be generated by the integrated release gate.
    *   Native host completed: two real cycles proved `TOTADockForm` creation, visibility, IDE
        desktop geometry restoration, and clean shutdown. The lateral drop gesture remains a manual
        visual acceptance because the elevated IDE blocks synthetic cross-process input; this does
        not change the native docking capability supplied by OTA.
    *   Additional CDB diagnosis: retention happens before `ExitProcess`; one capture placed the
        main thread in `IdeservicesFileNotification`. A later AV inspected an already unloaded
        DevExpress BPL through an MMX call chain, but a smoke run with MMX temporarily disabled also
        retained `bds.exe`, ruling it out as the root cause. The correlation with
        `IdeservicesFileNotification` led to explicitly removing the editor and debugger OTA hooks;
        this fix closed the retention gate across three consecutive smoke cycles.

---

## 🚧 2. Active goal

The [skill portability and high-fidelity terminal goal](terminal_skill_portability_goal.en.md) is the
current execution line. It covers transactional publication of one skill to supported CLI formats
and terminal evolution toward a high-fidelity VT/TUI matrix on all three official targets. The
release will be prepared but not published without later authorization.

The [complete-experience expansion goal](experience_expansion_goal.en.md) is complete and records the
previous execution line. It covers completion alternatives, knowledge and template packages, visual
before/after
evidence, cross-surface consent, advanced terminal compatibility, refinement of the current
WebView, and a complete documentation audit, with mandatory acceptance on Delphi 12 Win32 and
Delphi 13 Win32/IDE64. The previous six-gap experience cycle completed in 2.3.1.

Other pending work remains uncommitted until a new triage. See the
[prioritization matrix](feature_prioritization_matrix.en.md) and [roadmap](roadmap.en.md).

---

## ✅ 3. Completed History

Check the implementation details of each completed feature grouped by target release version:

### Agentic platform completed

- Internal registry shared by chat, MCP, and extensions.
- OTA facade for workspace, editor, project, build, Form Designer, and debugger.
- Risk-based consent, sanitized audit, and workspace boundary.
- **Security & Consent** settings with timeout, arguments, risk-based memory, and immediate revoke.
- Reviewable and reversible patches protected by base hashes.
- Local MCP bridge with independent discovery per IDE process.
- Incremental and rebuildable knowledge isolated per project.
- Inline reviews and a versioned external extension API.
- Validated matrix for Delphi 11, 12, 13 Win32, and Delphi 13 IDE64.

See the [completion audit](agentic_completion_audit.en.md) and
[agentic roadmap](agentic_roadmap.en.md).

<details>
  <summary><b>📦 v0.0.29 — Editor Selection Fixes and Gemini OAuth Block (Click to expand)</b></summary>

  #### 1. Fixing Editor Selection Detection
  *   **Description**: Resolved a false positive issue where the Delphi IDE kept text marked in the background buffer (`LEditBuffer.EditBlock`) even after external clicks.
  *   **Details**:
      *   Refactored `GetSelectedText` in `TRadIAOTAEditorAdapter` to extract the selection from `LView.Block` (from the active view focused in the IDE) instead of `LEditBuffer.EditBlock`.
      *   Kept the filtering validation checking if the starting and ending selection coordinates differ (`StartingColumn <> EndingColumn` or `StartingRow <> EndingRow`).
      *   Programmatically collapsed the cursor with `LView.Position.Move` and cleared the block with `LEditBlock.Reset` after replacing the inserted text, ensuring newly generated texts do not remain selected.
      *   Adjusted code explanation fallbacks in `ChatPresenter` to use `.Trim.IsEmpty` to ignore selections containing only whitespaces.

  #### 2. Translating Typing Indicator
  *   **Description**: Fixed language in the visual status of AI response processing.
  *   **Details**:
      *   Translated the status string in the modern indicator in `chat.js` from `"Pensando..."` to `"Thinking..."` for total consistency with default coding and UI language guidelines (en-US).

  #### 3. Temporarily Blocking Google Gemini OAuth
  *   **Description**: Added a blocking warning dialog in the Gemini OAuth flow because Google's security verification is still pending.
  *   **Details**:
      *   Added an informative error dialog at the beginning of `StartOAuthLogin` and `SendPromptToAI`, instructing to use API Keys and temporarily blocking login and prompt submission using Gemini in OAuth mode.
      *   Removed references to "Web Login" from warnings, as the functionality was deprecated and fully removed in previous commits.

</details>

<details>
  <summary><b>📦 v0.0.28 — Open Tools API Adapter and Network Testing (Click to expand)</b></summary>

  #### 1. Decoupling Open Tools API (OTA)
  *   **Description**: Implemented an abstraction layer (Adapter) for the Delphi IDE code editor to isolate it in unit tests.
  *   **Details**:
      *   Created the `IRadIAEditorAdapter` interface containing methods for reading text, selection, cursor, and buffer replacement.
      *   Created the concrete `TRadIAOTAEditorAdapter` class that consumes the native Delphi `ToolsAPI` services.
      *   Registered the adapter in the IoC container (`TRadIAContainer`) and refactored the `RadIA.OTA.Helper` utility to consume the abstraction instead of direct static calls.

  #### 2. Editor Mocking and Offline Automated Tests
  *   **Description**: Created mock classes to simulate Delphi IDE behavior and validate text manipulation operations offline.
  *   **Details**:
      *   Implemented `TMockEditorAdapter` keeping virtual buffer and cursor in memory.
      *   Added unit tests covering XML documentation generation, boilerplate method generation, selection extraction, and safe code replacements.
      *   Refactored the `GetText` method within the adapter to keep cognitive complexity low.

  #### 3. Network Stress and Resilience Testing
  *   **Description**: Added tests to ensure stability under network latency and asynchronous streaming cancellation.
  *   **Details**:
      *   Added physical stream interruption and cancellation simulation in the `TMockHttpClient` mock.
      *   Created unit test case `TestProviderBase_CancellationAndTimeout` checking that background threads and loops terminate gracefully, avoiding IDE locks.
      *   Adjusted temporary file handling in template tests to avoid sharing and locking violations on Windows.

</details>

<details>
  <summary><b>📦 v0.0.27 — Resolution of Code Smells and Test Coverage Expansion (Click to expand)</b></summary>

  #### 1. Fixing SonarQube Code Smells
  *   **Description**: Complete elimination of static analysis violations inside the test runner unit (`ProviderBooster.pas`).
  *   **Details**:
      *   Removed inactive imports (`System.Classes` and `RadIA.Core.TokenUsage`) from the uses clause in the implementation section.
      *   Replaced all occurrences of `Writeln` with `WriteLn` (capitalized 'L') to conform with Pascal code style conventions and prevent mixed-case warnings.

  #### 2. Provider Integration Testing via RTTI
  *   **Description**: Implemented synchronous and isolated DUnitX tests to validate protected and virtual base URLs and model discovery endpoints.
  *   **Details**:
      *   Created private RTTI-based helpers (`InvokeGetBaseUrl`, `InvokeGetModelsDiscoveryUrl`, and `InvokeFilterModelId`) to access the protected scope of providers sychronously within offline tests.
      *   Validated `GetBaseUrl`, `GetModelsDiscoveryUrl`, and `FilterModelId` across multiple backends: `OpenAI` (with and without custom base URL), `DeepSeek`, `Groq`, `OpenRouter`, `Qwen`, `Mistral`, `LMStudio`, and `AzureOpenAI`.

  #### 3. Gemini Model Discovery Testing
  *   **Description**: Unit test coverage for dynamic model discovery in the Google Gemini provider.
  *   **Details**:
      *   Tested `FetchAvailableModelsAsync` and `ParseAvailableModelsFromJson` under successful conditions, network failures (throwing custom exceptions), and null/empty API keys.
      *   Validated model filtering (`IsModelValidForGeneration`) based on supported generation methods (`generateContent`).

  #### 4. JSON Error Parsing and Critical Code Coverage
  *   **Description**: Expanded unit test coverage for data mapping and network error parsing.
  *   **Details**:
      *   Added tests for `ProviderBase` (`ExtractErrorMessageFromJson`) to cover all JSON error formats (nested error objects, raw strings, and generic messages).
      *   Added conversion tests for invalid roles (`StringToMessageRole` throwing `EConvertError`) and `ChatMessage` properties, ensuring 100% code coverage for both `RadIA.Core.Types.pas` and `RadIA.Core.ChatMessage.pas`.
</details>

<details>
  <summary><b>📦 v0.0.26 — Visual Provider Icons and Architectural Refactoring (Click to expand)</b></summary>

  #### 1. Official AI SVG Icons
  *   **Description**: Replaced generic AI robot images and custom vectors with high-fidelity, accurate official brand logos extracted from the `@lobehub/icons-static-svg` (Lobe Icons) library.
  *   **Details**:
      *   Created precise path vectors and matching gradients for Gemini (blue-purple-pink linear gradient), OpenAI (green `#10A37F`), Claude (Anthropic `#D97706`), DeepSeek (baleia `#0D53FF`), Copilot (robot `#5856D6`), Mistral (origami `#FD5A24`), AWS Bedrock (orange `#FF9900`), LM Studio (`#EC4899`), Alibaba Qwen (`#615CED`), Groq (`#F97316`) and other native backends.
      *   SVGs render beautifully across both light and dark IDE themes.

  #### 2. Custom Provider Dropdown Seletor and Chat Message Avatars
  *   **Description**: Customized styled provider selection bar displaying the brand's logo and model name, alongside dynamic matching avatar bubbles inside chat logs.
  *   **Details**:
      *   The native select selector is visually hidden and proxies change events in JS, maintaining direct backward-compatibility with Delphi's Open Tools API hooks.
      *   Assistant message bubble avatars now dynamically inject the specific AI provider logo instead of the generic Rad IA assistant robot.

  #### 3. Architectural Decoupling and Dependency Inversion (DIP & IoC)
  *   **Description**: Comprehensive structural refactoring of the plugin codebase to remove concrete coupling, enable isolated background unit testing, and introduce dependency injection.
  *   **Details**:
      *   **`IRadIAService` Interface**: Centralized service abstraction and adaptation of consumers (`TRadIAChatPresenter`, `TRadIAFormAIDiff`, and `TRadIAEditorHook`) to consume the interface, cleaning up concrete couplings.
      *   **Composition Root (`RadIA.Providers.Link.pas`)**: Dedicated unit created to physically bind all concrete providers, removing direct imports from `TRadIAService` and enabling dynamic self-registration.
      *   **IoC Container (`TRadIAContainer`)**: Thread-safe generic container (built using `TMonitor`) managing service registrations during the IDE's boot flow (`RadIA.OTA.Register.pas`).
      *   **Open Tools API Decoupling (`IRadIAIDEAdapter`)**: Abstraction layer for all Delphi IDE editor and message services, enabling editor mock injection (`TMockIDEAdapter`) in offline regression tests.

  #### 4. I/O Isolation in Tests and Developer Data Safety
  *   **Description**: Absolute protection of developer's local settings, chats, and templates during unit test runs.
  *   **Details**:
      *   Parametrized base directories (`ABaseDir` in `TPromptTemplateManager`, `ASessionsDir` in `TRadIASessionManager`, `AWebFilesDir` in `TRadIAFormAIDiff`) allowing dynamic temporary path injection.
      *   Isolated folder setup in tests using GUID-based transient directories created during `Setup` and swept clean in `TearDown`, preventing unit test runs from erasing the developer's live production AppData profiles.

  #### 5. Regression Fix: Line Break Normalization in Editor (CRLF)
  *   **Description**: Shipped `IRadIATextNormalizer` service to resolve a regression causing code blocks to paste on a single continuous line.
  *   **Details**:
      *   The text normalizer converts line breaks (`LF`, `CR`) uniformly to Windows style (**CRLF - `#13#10`**) before inserting it into OTA edit buffers (`ReplaceActiveEditorText`, `InsertTextAtCursor`), ensuring the IDE renders block formatting correctly.

  #### 6. New Infrastructure Abstractions (DIP, SRP, i18n)
  *   **Description**: Separated infrastructure concerns into decoupled services for cleaner maintenance.
  *   **Details**:
      *   **HTTP Client (`IRadIAHttpClient`)**: Abstracted asynchronous network client wrapping `THTTPClient`, keeping providers clean of low-level sockets.
      *   **API Error Decoder (`IRadIAErrorDecoder`)**: Centralized parsing of JSON payloads and HTTP error status codes from different gateways (Gemini, OpenAI, Claude).
      *   **i18n Localization (`IRadIALocalizer`)**: Dictionary management service offering `pt-BR` and `en` translations for UI keys.
      *   **DRY Tests Consolidation**: Consolidated repetitive SSE stream and JSON payload assertions in `RadIA.Tests.ProvidersEx.pas` using private helpers, eliminating 500+ lines of duplicate tests.
      *   **Standard Naming Guide**: Refactored legacy types to align with `TRadIA` / `IRadIA` prefix conventions and renamed units to the physical namespace pattern `RadIA.*.pas`.
</details>

<details>
  <summary><b>📦 v0.0.25 — Simplified Web Login and Safe Apply Changes (Click to expand)</b></summary>

  #### 1. Simplified Web Login
  *   **Description**: The Web Login flow now opens the official provider page using the correct data folder, allowing the user to sign in or visually confirm the active session without relying on a hidden WebView.
  *   **Details**:
      *   The form detects already authenticated ChatGPT/Gemini sessions and exits the login flow with a clear confirmation message.
      *   The screen no longer displays misleading model names for Web Login providers, using the Rad IA brand and **Web Login** mode instead.
      *   The **Continue** button remains available for manual confirmation when the provider page requires interaction.

  #### 2. Safe Apply Changes in Smart Diff
  *   **Description**: The **Apply Changes** button no longer inserts new code on top of old content when the editor selection is lost while the diff dialog is open.
  *   **Details**:
      *   Whole-buffer replacement now calculates the real active editor text size before applying the OTA edit.
      *   When the original selection is no longer available, the plugin locates the original block in the editor and replaces only that range.
      *   If the original block cannot be found, applying the diff is rejected with an explicit message instead of duplicating code.
      *   Validated with `build.ps1 -DelphiVersion "23.0" -Test`, with 159 passing tests.
</details>

<details>
  <summary><b>📦 v0.0.24 — Delphi Compiler & OS Warning Scanner and Menu Protection (Click to expand)</b></summary>

  #### 1. Delphi Compiler & OS Warning Scanner
  *   **Description**: New **Scan Compiler & OS Warnings** menu action and `/scanwarnings` slash command to scan code for potential compilation warnings, VCL thread-safety issues, and Windows GDI leaks.
  *   **Details**:
      *   Uses the `rpScanWarnings` profile configured with temperature `0.2` and `8192` max tokens.
      *   Structured prompt mapping and comprehensive DUnitX unit test verification.

  #### 2. Editor Elision Fix (Delphi 13 Crash)
  *   **Description**: Fixed an Access Violation in the editor kernel DLL (`boreditu.dll`) that occurred intermittently on IDE startup or new unit creation.
  *   **Details**:
      *   Removed recursive visual controls and components popup scanning (`HookControlPopupMenus` / `UnhookControlPopupMenus`).
      *   Simplified hook focusing solely on intercepting the `EditorLocalMenu` popup event, bypassing IDE startup message loops conflicts.
</details>

<details>
  <summary><b>📦 v0.0.23 — Smart SQL Optimizer in Editor (Click to expand)</b></summary>

  #### 1. Smart SQL Optimizer in Editor
  *   **Description**: New **Optimize SQL Query** action in the editor context menu and `/sqloptimize` slash command for automated SQL query analysis and optimization.
  *   **Details**:
      *   The context menu captures the active selection or the current cursor line containing the SQL statement.
      *   Triggers the `/sqloptimize` command sending the SQL query inside a Markdown ```sql block to the AI.
      *   Configured `rpOptimizeSQL` request profile inside `TRadIAService.ResolveParameters` with a low temperature (`0.1`) and `8192` max tokens for accurate, precise responses.
      *   DUnitX unit test suite passed successfully (157 tests).
</details>

<details>
  <summary><b>📦 v0.0.22 — Concise Prompts and Editor Line Break Preservation (Click to expand)</b></summary>

  #### 1. Pascal Block Preservation in Editor Menus
  *   **Description**: Fixed editor context-menu flows to preserve line breaks and indentation when sending code to commands such as `/bugs`, `/explain`, and `/test`.
  *   **Details**:
      *   `TChatPresenter` now reuses the fenced Markdown block received from the menu before reading the editor again.
      *   Default templates now wrap `{code}` in `pascal` blocks, reducing the risk of inline rendering.
      *   Analysis, explanation, and test prompts were tuned for shorter, actionable responses.

  #### 2. Concise Response Setting
  *   **Description**: Added the **Prefer concise AI responses** general setting to reduce overly explanatory answers and save tokens.
  *   **Details**:
      *   The preference is persisted as `ConciseResponses` and enabled by default.
      *   `TRadIAService` injects the preference into the effective system prompt without duplicating provider-specific logic.
      *   Validation covers configuration persistence, configuration presenter behavior, and line-break preservation during slash command preprocessing.
      *   Validated with `build.ps1 -DelphiVersion "23.0" -Test`, with 157 passing tests.
</details>

<details>
  <summary><b>📦 v0.0.21 — Create Example from Comment (Click to expand)</b></summary>

  #### 1. Example Generation from Comment
  *   **Description**: New **Create Example from Comment** editor context-menu action to fill empty methods from a natural-language comment.
  *   **Details**:
      *   The parser detects the current method from the cursor and accepts `//`, `{ ... }`, and `(* ... *)` comments, including multiline blocks.
      *   The action rejects unsupported contexts, methods without comments, and methods that already contain code beyond whitespace and comments.
      *   Generated code is inserted directly below the comment, preserving the original intent and avoiding Smart Diff for this flow.
      *   The flow respects Web Login providers by opening the chat bridge before sending the prompt when required.
      *   The editor context hook was kept on the Delphi 12 and Delphi 13 validated behavior.
      *   Validated with `build.ps1 -DelphiVersion "23.0" -Test`, with 155 passing tests.
</details>

<details>
  <summary><b>📦 v0.0.20 — Smart Diff with Web Login and Configuration Persistence (Click to expand)</b></summary>

  #### 1. Smart Diff with Web Login Providers
  *   **Description**: Fixed the Smart Diff refactoring flow for providers authenticated through Web Login while keeping the chat window functional and the comparison view correctly rendered.
  *   **Details**:
      *   Smart Diff now reuses the Web Login path without requiring an API key when the active provider is configured for web authentication.
      *   Refactoring responses are requested as a single `pascal` code block, preserving the formatting returned by the AI.
      *   WebView extraction preserves line breaks and indentation from code blocks before sending content back to Delphi.

  #### 2. Configuration and Editor Stability
  *   **Description**: Adjustments to avoid configuration regressions and editor interference during project creation.
  *   **Details**:
      *   Provider-specific settings are read from and written to their own registry keys while keeping compatibility with legacy values.
      *   Automated tests no longer write to the user's real registry, preventing accidental Gemini configuration changes.
      *   The context-menu hook avoids accessing the editor's internal buffer while the IDE is still creating views.
      *   Validated with `build.ps1 -DelphiVersion "37.0" -Test` and `build.ps1 -DelphiVersion "23.0" -Test`, both with 144 passing tests.
</details>

<details>
  <summary><b>📦 v0.0.19 — Editor Actions with Active Unit Fallback (Click to expand)</b></summary>

  #### 1. Editor Menus Without Selection - Item #52
  *   **Description**: Editor context-menu actions now work even when the user does not select any code block.
  *   **Details**:
      *   **Explain**, **Generate Tests**, **Locate Bugs**, **Document Method**, and **Optimize/Refactor** try the current selection first.
      *   When there is no selection, Rad IA reads the whole active unit and sends that content as context to the chat or Smart Diff.
      *   Refactoring correctly marks when the suggestion should replace the whole buffer, avoiding cursor-only insertion.

  #### 2. Delphi 13 Stability and Editor Reading
  *   **Description**: Stability fix for Delphi 13 new project creation and safer active buffer reading.
  *   **Details**:
      *   The editor context-menu hook no longer uses OTA notifiers while editor views are being created, avoiding conflicts with Delphi 13 elision rebuilding.
      *   `IOTAEditReader` is now read in chunks, ensuring the active unit is captured correctly in Delphi 12 and Delphi 13.
      *   Validated with `build.ps1 -DelphiVersion "37.0" -Test` and `build.ps1 -DelphiVersion "23.0" -Test`, both with 143 passing tests.
</details>

<details>
  <summary><b>📦 v0.0.18 — Chat UX, Web Login, and Rad IA Branding Polish (Click to expand)</b></summary>

  #### 1. Chat Welcome Experience and IDE Theme - Items #46, #47
  *   **Description**: Refined chat startup and IDE theme adaptation to reduce visual noise and make first use more intuitive.
  *   **Details**:
      *   Added a welcome screen with a central animation, quick actions, and on-demand history loading.
      *   Treats the Mountain Mist IDE theme as light, keeping only dark and light modes in the chat CSS.
      *   Adjusted scrollbar width and fixed light-theme code blocks so Prism `pre` sections no longer show a dark border.
      *   Reduced the visual flash during the first WebView2 paint.

  #### 2. Sessions, Processing Locks, and Generator - Items #48, #49
  *   **Description**: Fixed multiple-chat behavior to prevent context loss during in-flight responses and make navigation more predictable.
  *   **Details**:
      *   Selecting a conversation no longer moves it to the top of the list.
      *   Session actions, toolbar buttons, edit, delete, create, clear, and conversation switching are locked while processing.
      *   Empty sessions are no longer restored as extra chats on the next startup.
      *   The **History** button was renamed to **Chats**, and the generator now takes the full area to prevent manipulating the chat list while it is open.

  #### 3. Web Login and Visual Identity - Items #50, #51
  *   **Description**: Improved the web login flow and aligned user-facing branding as **Rad IA**.
  *   **Details**:
      *   Web Login now shows clearer status messages, a visual fallback when the embedded browser takes too long to start, and a **Use Current Session** action for already-authenticated accounts.
      *   UI text, IDE menu, splash/about, documentation, and package metadata were reviewed to display **Rad IA** separated.
      *   Version metadata updated to `v0.0.18`.
      *   Validated with a local Delphi 12 (`23.0`) build and web asset linting with no blocking errors.
</details>

<details>
  <summary><b>📦 v0.0.17 — Editor Menu and WebView2 Chat Stabilization (Click to expand)</b></summary>

  #### 1. Editor Code Formatting and Slash Commands - Items #43, #44
  *   **Description**: Fixed editor context-menu flows so selected Pascal code is preserved as formatted chat blocks and each slash command resolves the correct template on the first execution.
  *   **Details**:
      *   Editor prompts now separate command, instruction, and fenced `pascal` code into clean Markdown lines.
      *   User messages containing fenced code blocks are rendered as Markdown, preserving Pascal highlighting and code actions.
      *   Added the native **Explain Code** template for `/explain` and migrated legacy review overlays to `/review`.
      *   Aligned global prompt handling with `PreProcessPrompt`, avoiding differences between menu-triggered commands and commands typed in chat.

  #### 2. Web Asset Installation and Cache Handling - Item #45
  *   **Description**: Hardened the multi-IDE installation flow to prevent Delphi 12/13 from loading stale WebView2 JavaScript after updates.
  *   **Details**:
      *   `chat.html` now loads `chat.js` with timestamp-based cache busting.
      *   `build.ps1 -Install` mirrors `Source\UI\Web` to the IDE public folder and `%APPDATA%\RadIA\Web`.
      *   The installer clears `%APPDATA%\RadIA\WebView2` while the IDE is closed.
      *   Sequential validation on Delphi 12 (`23.0`) and Delphi 13 (`37.0`) with **143 passing DUnitX tests** on both.
</details>

<details>
  <summary><b>📦 v0.0.16 — MVP Architecture Refactoring, Storage Abstraction, and Editor Robustness (Click to expand)</b></summary>

  #### 1. MVP Presentation Pattern & Configuration Storage Abstraction - Items #40, #41
  *   **Description**: Decoupled presentation logic and UI code for the Chat panel and Settings frame by introducing the MVP architecture pattern, and designed a flexible storage abstraction layer (`ISettingsStorage`) allowing deterministic testing with in-memory settings storage.
  *   **Details**:
      *   Created `RadIA.Core.SettingsStorage.pas` introducing the `ISettingsStorage` interface with two concrete implementations: `TRegistrySettingsStorage` (for production) and `TMemorySettingsStorage` (for unit tests).
      *   Refactored `RadIA.Core.Config.pas` to support dependency injection of the storage layer via `SetStorage`.
      *   Implemented the MVP pattern for the Chat UI by developing `TChatPresenter` and the `IChatView` interface, delegating logic out of `TChatFrame` (passive View).
      *   Implemented the MVP pattern for the Settings dialog by developing `TConfigPresenter` and the `IConfigView` interface, incorporating robust validations for URLs, temperatures, and integer parameters.
      *   Wrote and integrated mocked unit tests in `RadIA.Tests.ChatPresenter.pas`, `RadIA.Tests.ConfigPresenter.pas`, and `RadIA.Tests.EditorHook.pas`, achieving **135 successful tests** inside the console DUnitX test suite.

  #### 2. Editor Context Menu Robustness - Item #42
  *   **Description**: Strengthened the Delphi editor context-menu integration to reduce fragile VCL assumptions and preserve compatibility with Delphi 12/13 and third-party IDE plugins.
  *   **Details**:
      *   Registered OTA notifiers (`IOTAIDENotifier` and `IOTAEditorNotifier`) to schedule menu hooks when `.pas` files and editor views are opened or activated.
      *   Deferred context-menu hooking until after the IDE finishes building the `TEditWindow`, avoiding regressions when creating new projects and interacting with code folding/elision tree internals.
      *   Detects `TPopupMenu` instances both from form components and from the control tree (`Control.PopupMenu`), covering the real editor menu across IDE versions and layouts.
      *   Injects the **Rad IA** submenu at the top of the context menu after the IDE's original `OnPopup` handler rebuilds the default items.
</details>

<details>
  <summary><b>📦 v0.0.15 — Two-Layer Template Architecture (Click to expand)</b></summary>

  #### 1. Two-Layer Segregated Template Architecture (Native vs. User overlays) - Item #12c
  *   **Description**: Segregates default prompt templates hardcoded in the codebase from those customized by the user inside AppData, allowing updates without losing custom settings, using overlays and factory resets.
  *   **Details**:
      *   Two-layer loading logic merging default and custom templates at runtime inside `TPromptTemplateManager`.
      *   Automated cleanup of redundant unedited templates inside user AppData directory (`CleanRedundantUserTemplates`).
      *   Enhanced settings VCL UI featuring origin descriptors (`lblTemplateOrigin`) and contextual delete/restore buttons.
      *   Expanded unit test suite achieving 117 successful DUnitX assertions.
</details>

<details>
  <summary><b>📦 v0.0.14 — Dynamic Templates & Backup (Click to expand)</b></summary>

  #### 1. Dynamic Templates, Prompt Backups, and New Architecture - Item #12b
  *   **Description**: Total dynamic template customization for prompts and slash commands, including VCL JSON backup dialogs and Clean Architecture support.
  *   **Details**:
      *   Removed hardcoded ifs when resolving slash commands. The parser scans `TPromptTemplateManager` dynamically using `{code}`, `{specification}`, `{stacktrace}`, and `{argument}` placeholders.
      *   JSON import/export transactional dialogs with schema checks and options to *Merge* or *Overwrite* local templates.
      *   Shipped the new `'Create Project Delphi Architecture'` (`/createprojectarch`) template, incorporating Dependency Inversion, robust try..finally blocks, and Pascal naming standards.
      *   Updated test coverage in `RadIA.Tests.Templates.pas` verifying backup parsing and schema validations.
</details>

<details>
  <summary><b>📦 v0.0.13 — Prompt-Based Delphi Project Generation (Click to expand)</b></summary>

  #### 1. Full Project Generation (Prompt-Based) - Item #24b
  *   **Description**: Automated creation of full Delphi projects based on chat prompts, writing them to disk and opening them in the IDE.
  *   **Details**:
      *   Developed transactional builder class `TRadIAProjectGenerator` inside `RadIA.Core.ProjectGenerator.pas`.
      *   Requires a clean, empty folder for saving files, rolling back created files if write errors occur.
      *   Parsed and rendered files inside a glassmorphism project panel in WebView2 featuring file shortcuts and flash highlight.
</details>

<details>
  <summary><b>📦 v0.0.12 — AWS Bedrock Provider (Click to expand)</b></summary>

  #### 1. Native AWS Bedrock Provider with SigV4 Signatures and EventStream Parser - Item #33
  *   **Description**: Full native AWS Bedrock support featuring AWS Signature Version 4 (SigV4) signing and binary AWS EventStream real-time decoding.
  *   **Details**:
      *   Developed the provider client `TRadIABedrockProvider` inside `RadIA.Provider.Bedrock.pas` registered into the core registry.
      *   Developed the SigV4 cryptographic utility `TAwsSigV4Signer` inside `RadIA.Core.AwsSigner.pas` computing SHA-256 and HMAC-SHA-256 signatures for AWS request headers.
      *   Implemented `TAwsEventStreamParser` to incrementally parse and decode Bedrock's binary EventStream payload frames.
      *   Created a VCL settings page featuring DPAPI-encrypted storage for AWS credentials (Access Key, Secret Key, Region, and Session Token).
      *   Added unit tests to `RadIA.Tests.ProvidersEx.pas`, achieving **112 passing green assertions** in the test suite.
</details>

<details>
  <summary><b>📦 v0.0.11 — Azure, Qwen, and Mistral AI Providers (Click to expand)</b></summary>

  #### 1. Additional Native Providers (Azure OpenAI, Alibaba Qwen, and Mistral AI) - Items #30, #31, #32
  *   **Description**: Direct native support for Azure OpenAI, Alibaba Qwen (ModelStudio), and Mistral AI APIs, including settings panels, key acquisition shortcuts, SSE streaming, and sorted provider lists.
  *   **Details**:
      *   Developed provider classes `TRadIAAzureOpenAIProvider`, `TRadIAQwenProvider`, and `TRadIAMistralProvider` registered dynamically in `TProviderRegistry`.
      *   Saved secure API keys via Windows DPAPI and custom properties (like `AzureApiVersion`).
      *   Created VCL light/dark options tabs for each provider inside the IDE's options dialog.
      *   Implemented sorted lists inside `TProviderRegistry.GetProviders` ensuring **Ollama** and **LM Studio** sit at the bottom of all lists.
      *   Validated with tests inside `RadIA.Tests.ProvidersEx.pas` and mocked configurations inside `RadIA.Tests.Service.pas`.
</details>

<details>
  <summary><b>📦 v0.0.10 — Native GitHub Copilot Support (Click to expand)</b></summary>

  #### 1. Native GitHub Copilot Provider (Phase 2) - Item #29
  *   **Description**: Native integration with the GitHub Copilot cloud featuring PIN authentication (Device Flow) and one-click key import from VS Code, along with developer console shortcuts for other keys.
  *   **Details**:
      *   Developed unit `RadIA.Provider.GithubCopilot.pas` managing the temporary session tokens requested from `https://api.github.com/copilot_internal/v2/token`.
      *   Created UI dialog `RadIA.UI.GithubAuthForm.pas` handling the background PIN device login flow.
      *   Modified VCL settings page to display the Copilot tab with login controls and quick API Key hyperlink shortcuts.
</details>

<details>
  <summary><b>📦 v0.0.9 — Multi-IDE Build Support (Click to expand)</b></summary>

  #### 1. Multi-IDE Version Build Support - Item #27
  *   **Description**: Enhances build script stability (`build.ps1`) to support systems running multiple Delphi IDE instances, offering target version choice via shell parameters or interactive menus.
  *   **Details**:
      *   Implemented the `-DelphiVersion` compiler target flag.
      *   Scans the Windows Registry (`HKCU:\Software\Embarcadero\BDS`) to fetch physical install paths (`RootDir`) and version labels.
      *   Added an interactive console select menu when multiple IDEs are found.
      *   Replaced hardcoded C: paths with dynamic root mapping using `$rootDir`.
</details>

<details>
  <summary><b>📦 v0.0.8 — LM Studio Provider (Click to expand)</b></summary>

  #### 1. Native LM Studio Provider - Item #21c
  *   **Description**: Shipped native, optional support for local LM Studio instances featuring SSE streaming, model autodiscovery, and custom endpoints.
  *   **Details**:
      *   Created unit `RadIA.Provider.LMStudio.pas` hosting the provider and its auto-registration.
      *   Designed a dedicated VCL settings tab matching the IDE theme and persisting URL settings.
      *   Refactored the sidebar chat to load LM Studio optionally (hiding it from dropdown lists unless configured).
      *   Coded unit tests covering LM Studio JSON mapping and stream buffers inside `RadIA.Tests.ProvidersEx.pas`.
</details>

<details>
  <summary><b>📦 v0.0.6 — JSON Dynamic Providers (Click to expand)</b></summary>

  #### 1. Dynamic JSON Providers (Plugins without Recompilation) - Item #21b
  *   **Description**: Support for registering custom OpenAI-compatible providers by saving configuration `.json` files inside Rad IA's AppData directory, without compiling the plugin.
  *   **Details**:
      *   Iterates the directory at `%APPDATA%\RadIA\providers\` inside `TProviderRegistry.LoadJsonProviders`.
      *   Designed a generic client wrapper `TRadIAGenericOpenAIProvider` to serve as a universal OpenAI bridge.
      *   Handled fallbacks for optional API Keys and flags to list the loaded provider inside the chat sidebar.
      *   Built a test suite inside `RadIA.Tests.JSONProviders.pas`.
</details>

<details>
  <summary><b>📦 v0.0.4 — Productivity & Static Analysis (Click to expand)</b></summary>

  #### 1. DTO and Model Converter (JSON / DDL ➔ Delphi) - Item #22
  *   **Description**: Generates Object Pascal classes and records matching JSON payloads or SQL DDL scripts, with options for DEXT ORM, Aurelius, REST.Json, and Vanilla.
  *   **Details**:
      *   Programmed DTO builder `TRadIADTOBuilder` inside `RadIA.Core.DTO.Generator.pas` using flexible conversion rules.
      *   Mapped properties for DEXT ORM using Smart properties (`IntType`, `StringType`) and Lazy relations (`ILazy<T>`, `TValueLazy<T>`).
      *   Validated with 96 unit assertions inside `RadIA.Tests.DTOGenerator.pas`.

  #### 2. Stack Trace Assistant, Static Code Analysis, and Popup Menu - Items #23, #24, #25
  *   **Description**: Shipped integrated slash commands `/stacktrace` and `/bugs`, along with a WebView2 autocomplete command popup box.
  *   **Details**:
      *   Mapped prompt templates injecting editor context (active file buffer or selection).
      *   Crafted the dynamic CSS popup menu inside WebView2 reacting to keyboard arrows (`↑`/`↓`/`Enter`/`Esc`) and mouse hover.
</details>

<details>
  <summary><b>📦 v0.0.3 — Runtime Stability (Click to expand)</b></summary>

  #### 1. Dynamic and Decoupled Providers Architecture (Plugin-like) - Item #21
  *   **Description**: Refactored AI modules to support dynamic auto-registration of backends, removing cascaded ifs and hardcoded provider enums.
  *   **Details**:
      *   Created central registry `TProviderRegistry` housing metadata (`TProviderMetadata`) and delegate factories.
      *   Implemented auto-registration of 7 native providers inside their `initialization` sections.
      *   Decoupled `TRadIAService` which now resolves providers dynamically by calling `TProviderRegistry.CreateProvider` without static case loops.
      *   Added assertions inside `RadIA.Tests.Service.pas` covering registry integrity and error handling.
</details>

<details>
  <summary><b>📦 v0.0.2 — Multiple Sessions & Token Budgeting (Click to expand)</b></summary>

  #### 1. Multiple Chat Sessions - Item #5
  *   **Description**: Organizes conversations by project or task, preserving previous context across restarts.
  *   **Details**:
      *   Persists sessions to disk at `%APPDATA%\RadIA\sessions\<guid>.json` indexed via `sessions_index.json` using `TRadIASessionManager`.
      *   Collapsible sidebar UI (`pnlSessions`) with a `ListBox` and edit tools (New Chat, Rename, Delete) and a Toggle toolbar button (☰).
      *   Tested session persistence inside `RadIA.Tests.Sessions.pas`.

  #### 2. Local Token Quota and Budgeting - Item #19
  *   **Description**: Configures monthly limits to prevent surprise faturations, accumulating usage locally and blocking network requests.
  *   **Details**:
      *   Registry integration featuring automatic monthly quota resets.
      *   Visual budget settings inside the options panel.
      *   WebView status bar displaying real-time usage percentages.
      *   Tested block routines and quota cycles inside `RadIA.Tests.Quota.pas`.

  #### 3. Native OpenRouter Provider - Item #20
  *   **Description**: Connects directly to OpenRouter with SSE streaming, DPAPI key encryption, registry storage, and dynamic models listing.
  *   **Details**:
      *   Designed `RadIA.Provider.OpenRouter.pas` inheriting from `TRadIAOpenAICompatibleProvider`.
      *   Mapped registry paths, keys, and default models (`google/gemini-2.5-pro`, `meta-llama/llama-3.3-70b-instruct`, `deepseek/deepseek-r1`).
      *   Added VCL settings tab matching the IDE theme.
      *   Tested SSE buffering and responses inside `RadIA.Tests.ProvidersEx.pas`.

  #### 4. Context Window Management (Automated Trimming) - Item #10
  *   **Description**: Prevents token limit API errors by trimming old history entries when maximum size is reached.
  *   **Details**:
      *   Added `MaxHistoryMessages` settings field (Registry, default: 20).
      *   Manager client `TRadIAService.TrimHistory` cuts the oldest messages while keeping the system prompt and new inputs.
      *   Validated with 10 unit tests in `RadIA.Tests.Service.pas`.

  #### 5. Token Consumption Tracking - Item #14
  *   **Description**: Displays input/output token counts inside the chat status bar.
  *   **Details**:
      *   Coded `TTokenUsage` record to track inputs/outputs.
      *   Synced WebView status bar elements with Delphi.
      *   Tested count mappings inside `RadIA.Tests.TokenUsage.pas`.
</details>

<details>
  <summary><b>📦 v0.0.1 — Initial Release (Click to expand)</b></summary>

  #### 1. Prompt History Navigation (↑/↓) - Item #6
  *   **Description**: Allows developers to cycle through sent inputs using keyboard arrows.
  *   **Details**:
      *   Created manager class `TPromptHistoryManager` saving up to 50 history rows inside `%APPDATA%\RadIA\prompt_history.json`.
      *   Intercepted `memPromptKeyDown` events in the memo control.
      *   Tested navigation arrays inside `RadIA.Tests.PromptHistory.pas`.

  #### 2. OpenAI Compatible Endpoints - Item #8
  *   **Description**: Connects to any OpenAI-compatible gateway by changing the Base URL parameter.
  *   **Details**:
      *   Added `Custom Base URL` settings field (`IAIConfig.OpenAICustomBaseUrl`).
      *   Tested customizations inside `RadIA.Tests.Providers.pas`.

  #### 3. Export Conversations - Item #7
  *   **Description**: Exports the active chat history to Markdown (.md) or standalone HTML.
  *   **Details**:
      *   Added "Export" toolbar buttons triggering native file saving dialogs (`TSaveDialog`).
      *   Embedded Prism.js inside standalone HTML outputs.
      *   Tested export structures inside `RadIA.Tests.Exporter.pas`.

  #### 4. Prompt Templates - Item #12
  *   **Description**: Quick template menu replacing `{code}` placeholders with active selections.
  *   **Details**:
      *   Added VCL menu buttons and `/template` slash commands.
      *   Tested parser regexes inside `RadIA.Tests.Templates.pas`.

  #### 5. Project Context (.radia file) - Item #11
  *   **Description**: Custom system prompts and workspace contexts fetched from local project files.
  *   **Details**:
      *   Developed `TProjectContextLoader` searching `.radia` files in the active project root directory using `IOTAProject`.
      *   Tested workspace loader inside `RadIA.Tests.ProjectContext.pas`.

  #### 6. SSE Stream Responses - Item #4
  *   **Description**: Token-by-token server response streaming inside the chat window.
  *   **Details**:
      *   SSE streaming integrated inside OpenAI, Gemini, Claude, and Ollama.
      *   Intercepted network downloads using `TStreamingTargetStream` wrappers.
      *   Coded WebView receiver handlers (`appendMessage`, typing triggers).
      *   Tested stream buffering inside `RadIA.Tests.Streaming.pas`.

  #### 7. Ollama Integration & Persistent Chat - Item #3
  *   **Description**: Local offline modeling without key billing, and persistent chat lists.

  #### 8. DeepSeek & Groq Providers - Item #9
  *   **Description**: Integrated DeepSeek and Groq APIs natively.
  *   **Details**:
      *   Created clients `RadIA.Provider.DeepSeek.pas` and `RadIA.Provider.Groq.pas`.
      *   DPAPI encryption mapping for API keys.
      *   Tested payloads and streams inside `RadIA.Tests.ProvidersEx.pas`.

  #### 9. Request Aborts & Prompt Capsule UI - Item #17
  *   **Description**: Cancels pending AI queries at the socket level and introduces a modern capsule text input UI.
  *   **Details**:
      *   Aborts downloads by interrupting `THTTPClient.OnReceiveData` calls.
      *   Swap send buttons dynamically to a stop icon (`■`) during network requests.
      *   Styled the memo background using transparency attributes and borders.

  #### 10. Provider Preferences Configurations - Item #18
  *   **Description**: Individual temperature and max token parameters for each provider.
  *   **Details**:
      *   Persisted settings fields inside Windows Registry using the core config class.
      *   Mapped variables to JSON request builders.

  #### 11. Hybrid Connection and Login Web (Plus/Pro) - Item #28
  *   **Description**: Automates DOM inputs and parses chat data from consumer WebView instances, allowing Plus/Pro usage.
  *   *Details*:
      *   Designed settings toggles and bridges inside the options screen.
      *   Written `bridge.js` to override official UI layouts and scan stream text.
      *   Configured chromium UA values to bypass third-party login locks.

  #### 12. VCL Third Party Options Integration - Item #2
  *   **Description**: Hosts settings frames natively under the global IDE Third Party Options registry.
  *   **Details**:
      *   Developed config frame `TFrameAIConfig` and standalone popup form wrapper `TFormAIConfig`.
      *   Registered registry bridges using `INTAAddInOptions` API under **Third Party > Rad IA**.
      *   Styled options dynamically to match IDE light/dark styles.
</details>
