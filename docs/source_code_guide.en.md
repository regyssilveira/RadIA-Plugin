# Developer Source Code Guide - Rad IA

This document serves as a practical map of the **Rad IA** codebase. It aims to guide new programmers in navigating and understanding the repository, detailing the responsibility of each unit, and teaching how to perform common modifications safely and consistently.

For a conceptual understanding of the layered architecture, design patterns, and concurrent network flows, read the [Software Architecture Guide](architecture_guide.en.md) first.

---

## 1. Directory Structure and Code Flow

The plugin source code is concentrated in the `Source/` directory and subdivided according to architectural responsibility:

```
Source/
├── Core/           # Central business logic, models, configuration, and utilities
├── Providers/      # Adapters and clients for AI providers (Gemini, OpenAI, etc.)
├── Integration/    # Delphi IDE integration via Open Tools API (OTA)
├── MCP/            # Executable stdio MCP bridge
└── UI/             # VCL-based user interfaces and Web components
    └── Web/        # HTML5/JS/CSS logic running inside WebView2 (EdgeBrowser)
```

---

## 2. Technical Unit Dictionary

### 2.1 Core Layer (`Source/Core/`)
Contains the central business rules of Rad IA. It is agnostic to the IDE and physical visual interface components.

| Unit | Technical Purpose |
| :--- | :--- |
| [RadIA.Core.Interfaces.pas](../Source/Core/RadIA.Core.Interfaces.pas) | Fundamental contracts (Interfaces) that decouple all layers of the plugin. |
| [RadIA.Core.Config.pas](../Source/Core/RadIA.Core.Config.pas) | Concrete implementation of global configuration (`TRadIAConfig`), managing endpoints, tokens, and secure keys. |
| `RadIA.Core.SettingsStorage.pas` | `IRadIASettingsStorage` contract; uses `TRadIARegistrySettingsStorage` in production and `TRadIAMemorySettingsStorage` in tests. |
| [RadIA.Core.Container.pas](../Source/Core/RadIA.Core.Container.pas) | Static and thread-safe IoC container for dependency injection and class lifecycle decoupling. |
| [RadIA.Core.Service.pas](../Source/Core/RadIA.Core.Service.pas) | Main orchestrator (`TRadIAService`). Manages chat sessions, provider activation, and caching. |
| [RadIA.Core.InlineCompletion.pas](../Source/Core/RadIA.Core.InlineCompletion.pas) | FIM and fallback contracts, capability discovery, bounded context, cache, cancellation, diagnostics, and Ghost Text control. |
| [RadIA.Core.Sessions.pas](../Source/Core/RadIA.Core.Sessions.pas) | Business logic for managing historical chat sessions and automatic local persistence in JSON files. |
| [RadIA.Core.PromptTemplates.pas](../Source/Core/RadIA.Core.PromptTemplates.pas) | Manages the reusable prompt catalog, slash commands, and dynamic tag replacement. |
| [RadIA.Core.Localizer.pas](../Source/Core/RadIA.Core.Localizer.pas) | Internationalization (i18n) component for dynamic localization of user interface strings. |
| [RadIA.Core.CredentialProtector.pas](../Source/Core/RadIA.Core.CredentialProtector.pas) | Encrypts and decrypts local API keys using the Windows Data Protection API (DPAPI). |
| [RadIA.Core.HttpClient.pas](../Source/Core/RadIA.Core.HttpClient.pas) | HTTP client based on the native `THTTPClient`, specialized in asynchronous consumption and SSE chunk streaming. |
| [RadIA.Core.ProjectContext.pas](../Source/Core/RadIA.Core.ProjectContext.pas) | Extracts information from the active unit in the editor or files within the current Delphi project structure. |
| [RadIA.Core.ProjectGenerator.pas](../Source/Core/RadIA.Core.ProjectGenerator.pas) | Logic for generating scaffolds and structural templates for new Delphi projects from prompts. |
| [RadIA.Core.DTO.Generator.pas](../Source/Core/RadIA.Core.DTO.Generator.pas) | Reverse engineering mechanism for converting SQL DDLs and JSON into Delphi class structures. |
| [RadIA.Core.EditorAdapter.pas](../Source/Core/RadIA.Core.EditorAdapter.pas) | `IRadIAEditorAdapter` interface and `TRadIAOTAEditorAdapter` implementation of the Adapter pattern to decouple the code editor from the Delphi IDE. |
| `RadIA.Core.Tools` and `ToolRegistry` | Agentic tool contracts, descriptors, and shared registry. |
| `RadIA.Core.ToolSecurity` and `WorkspaceBoundary` | Policy, audit, and path confinement. |
| `RadIA.Core.ConsentPresentation` | Readable source, uniform consent presentation, and redacted arguments. |
| `RadIA.Core.ConsentGate` | Serializes dialogs and bounds concurrent-request waiting. |
| `RadIA.Core.PseudoTerminal` | Manages ConPTY, process trees, resize, UTF-8 input, and streaming output decoding. |
| `RadIA.Core.TerminalScreen` | Emulates VT state, display-width-aware Unicode cells, and line reflow on resize. |
| `RadIA.Core.Workspace*` | Workspace facade and editor and project tools. |
| `RadIA.Core.Patches` and `PatchTools` | Patch preview, preconditions, application, and reversal. |
| `RadIA.Core.Build*` | Controlled build-cycle contracts and tools. |
| `RadIA.Core.Designer*` | Component, property, event, and layout facades and tools. |
| `RadIA.Core.Debugger*` | State, control, breakpoint, evaluation, and watch tools. |
| `RadIA.Core.VisualRuntimeSession` | Bounded visual session bound to the complete debug-process identity. |
| `RadIA.Core.RuntimeVisualTools` | Consented before/after capture for the local chat visual card. |
| `RadIA.Core.RuntimeScenario` | Runs the bounded scenario and publishes real visual-timeline events. |
| `RadIA.Core.Knowledge*` | Indexing, persistence, scheduling, search, and bounded reads. |
| `RadIA.Core.Mcp` | MCP protocol, sessions, cancellation, metrics, and dispatch. |
| `RadIA.Core.ExternalMcp` | Isolated contracts and catalog for consuming external MCP servers with stable namespaces. |
| `RadIA.Core.ExternalMcpContent` | Atomic resource and prompt catalogs with federated identities. |
| `RadIA.Core.ExternalMcpTransport` | Bounded JSONL stdio transport with process isolation, timeout, and tree termination. |
| `RadIA.Core.ExternalMcpClient` | JSON-RPC lifecycle, correlation, discovery, tools, and active cancellation by request ID. |
| `RadIA.Core.ExternalMcpSecurity` | Explicit grants, shared policy, consent, audit, and workspace path validation. |
| `RadIA.Core.ExternalMcpSettings` | Validated, current-user-protected, atomically persisted MCP snapshot. |
| `RadIA.Core.ExternalMcpRuntime` | Loads protected snapshots, connects enabled servers, discovers content, registers granted adapters, and publishes sanitized health without restart. |
| `RadIA.Core.ExternalMcpImport` | Imports `mcpServers`/`servers` as an atomic validated preview without executing or persisting during parsing. |
| `RadIA.Core.HierarchicalSettings` | Values, origins, and precedence across request, session, project, global, and safe defaults. |
| `RadIA.Core.HierarchicalSettingsStore` | Atomic JSON scope persistence with hashed names and unknown-field preservation. |
| `RadIA.Core.AgentExecutorContracts` and `AgentExecutors` | Capability, resume, and isolated execution contracts for external CLI clients. |
| `RadIA.Core.JourneyContext` | Project-isolated identity shared by chat, terminal, and editor. |
| `RadIA.Core.BlockReviews`, `BlockReviewSessions`, and `BlockReviewTools` | Block decisions, base revisions, and transactional gutter application. |
| `RadIA.Core.DeclarativeExtensions` | Parsing, validation, and hot reload for commands, skills, aliases, journeys, and workflows. |
| `RadIA.Core.DeclarativeExtensionPackages` | Integrity, installation, and transactional rollback for `.radiaext` packages and resources. |
| `RadIA.Core.ExtensionStudio` | Draft, preview, and validation services used by the visual extension editor. |
| `RadIA.Core.SkillPortability` | Canonical model and CLI skill format and path adapters. |
| `RadIA.Core.SkillReplicas` | Preview, ownership hashes, atomic writes, rollback, and safe removal. |
| `RadIA.Core.Extensions` | Versioned API and extension registration lifecycle. |

### 2.2 Providers Layer (`Source/Providers/`)
Encapsulates provider-specific HTTP communication with Artificial Intelligence APIs.

| Unit | Technical Purpose |
| :--- | :--- |
| [RadIA.Provider.Base.pas](../Source/Providers/RadIA.Provider.Base.pas) | Abstract base class (`TRadIAProviderBase`) that standardizes lifecycle and asynchronous requests. |
| [RadIA.Provider.Gemini.pas](../Source/Providers/RadIA.Provider.Gemini.pas) | Native integration with the Google Gemini API (including stream parsing and chat history). |
| [RadIA.Provider.GithubCopilot.pas](../Source/Providers/RadIA.Provider.GithubCopilot.pas) | Adapter for secure connection, device login (OAuth), and consumption of GitHub Copilot APIs. |
| [RadIA.Provider.Ollama.pas](../Source/Providers/RadIA.Provider.Ollama.pas) | Local Ollama client, including dedicated FIM through `/api/generate`. |
| [RadIA.Provider.Claude.pas](../Source/Providers/RadIA.Provider.Claude.pas) | Specific connector for the Anthropic Claude API. |
| [RadIA.Provider.LMStudio.pas](../Source/Providers/RadIA.Provider.LMStudio.pas) | Local LM Studio connector, including dedicated FIM through `/v1/completions`. |
| [RadIA.Provider.DeepSeek.pas](../Source/Providers/RadIA.Provider.DeepSeek.pas) | Adapter for consuming DeepSeek Chat and Coder models. |
| [RadIA.Provider.AzureOpenAI.pas](../Source/Providers/RadIA.Provider.AzureOpenAI.pas) | Enterprise integration with Azure OpenAI Service endpoints. |

### 2.3 Integration Layer (`Source/Integration/`)
Uses Delphi's extension APIs (**Open Tools API - OTA**) to dock visual panels and monitor the code editor.

| Unit | Technical Purpose |
| :--- | :--- |
| [RadIA.OTA.Register.pas](../Source/Integration/RadIA.OTA.Register.pas) | Plugin entry point. Registers the main Wizard in the IDE (`TRadIAWizard`) and initializes the IoC container. |
| [RadIA.OTA.EditorHook.pas](../Source/Integration/RadIA.OTA.EditorHook.pas) | Action interceptor hook. Manages right-click context menus in the Delphi IDE code editor. |
| [RadIA.OTA.ContextParser.pas](../Source/Integration/RadIA.OTA.ContextParser.pas) | Extracts and normalizes source code from the text editor to send as context in AI prompts. |
| [RadIA.OTA.DockableForm.pas](../Source/Integration/RadIA.OTA.DockableForm.pas) | `INTACustomDockableForm` adapter that delegates host creation, docking, and IDE desktop persistence to OTA. |
| [RadIA.OTA.Helper.pas](../Source/Integration/RadIA.OTA.Helper.pas) | Encapsulates complex text manipulation utility functions, consuming the active editor via `IRadIAEditorAdapter`. |
| [RadIA.OTA.MessageViewHook.pas](../Source/Integration/RadIA.OTA.MessageViewHook.pas) | Intercepts and manages error and warning items in the IDE's "Messages" tab to enable the Smart Build Debugger. |
| `RadIA.OTA.Workspace` and `TextReader` | OTA workspace facade and safe buffer reads. |
| `RadIA.OTA.Consent` | Native dialog and mutating-tool decisions. |
| `RadIA.OTA.Build` | Build adapter and structured result capture. |
| `RadIA.OTA.Designer` | Live Form Designer adapter on the IDE main thread. |
| `RadIA.OTA.Debugger` | IDE debugger state and control adapter. |
| `RadIA.OTA.RuntimeDiscovery` | Authorized window discovery and bounded PNG capture for the debug process. |
| `RadIA.OTA.InlineCompletion` | Live-editor context capture and integration for Ghost Text and its alternatives. |
| `RadIA.OTA.InlineReviews` | Inline review presentation and lifecycle through modern `INTACodeEditorEvents`. |
| `RadIA.OTA.Knowledge*` | Local index and edit, save, rename, and close notifications. |
| `RadIA.MCP.NamedPipe` | Local server, ACL, per-PID discovery, and transport. |

### 2.4 MCP Bridge (`Source/MCP/`)

| Unit | Technical Purpose |
| :--- | :--- |
| `RadIA.MCP.Bridge.dpr` | Stdio bridge that discovers the IDE and forwards MCP to the local pipe. |

### 2.5 User Interface Layer (`Source/UI/`)
VCL forms and frames developed under the MVP (Model-View-Presenter) pattern.

| Unit | Technical Purpose |
| :--- | :--- |
| [RadIA.UI.ChatFrame.pas](../Source/UI/RadIA.UI.ChatFrame.pas) | Physical View of the chat panel. Contains the WebView2 component and prompt input fields. |
| [RadIA.UI.ChatPresenter.pas](../Source/UI/RadIA.UI.ChatPresenter.pas) | Chat Presenter. Coordinates sending, canceling, stream rendering, and message history. |
| [RadIA.UI.ConfigFrame.pas](../Source/UI/RadIA.UI.ConfigFrame.pas) | Physical View for configuration settings (API keys, endpoints, themes, limits). |
| [RadIA.UI.ConfigPresenter.pas](../Source/UI/RadIA.UI.ConfigPresenter.pas) | Configuration Presenter. Loads and saves settings synchronously. |
| [RadIA.UI.DiffForm.pas](../Source/UI/RadIA.UI.DiffForm.pas) | Side-by-side comparison screen (Smart Diff) with buttons to accept or reject the suggested refactoring. |
| `RadIA.UI.TerminalFrame` and `TerminalTabsFrame` | ConPTY terminal, tabs, profiles, history, snippets, and Unicode/TUI presentation. |
| `RadIA.UI.ExternalMcpFrame` | External MCP server registration, testing, grants, and settings application. |
| `RadIA.UI.ExtensionStudioForm` | Visual creation, testing, installation, export, and signing of declarative extensions. |
| `RadIA.UI.SkillPortabilityForm` | Destination selection, preview, consent, publication, and replica removal. |


---

## 3. Practical Maintenance Workflows

### 3.1 Adding a New Configuration Setting
If you need to save and expose a new configuration setting to the user (e.g., "Model Temperature"):

```mermaid
graph TD
    A[1. Add property in IRadIAConfig] --> B[2. Implement property in TRadIAConfig]
    B --> C[3. Add visual control in TFrameConfig]
    C --> D[4. Update mapping in TRadIAConfigPresenter]
```

1.  **Configuration Interface**: In [RadIA.Core.Interfaces.pas](../Source/Core/RadIA.Core.Interfaces.pas), declare read and write methods in the `IRadIAConfig` interface:
    ```pascal
    function GetModelTemperature: Double;
    procedure SetModelTemperature(const AValue: Double);
    property ModelTemperature: Double read GetModelTemperature write SetModelTemperature;
    ```
2.  **Persistence Implementation**: In [RadIA.Core.Config.pas](../Source/Core/RadIA.Core.Config.pas), implement the methods. Use the `FStorage` instance to write the information to the Registry:
    ```pascal
    function TRadIAConfig.GetModelTemperature: Double;
    begin
      Result := FStorage.ReadDouble('ModelTemperature', 0.7); // 0.7 is the default value
    end;

    procedure TRadIAConfig.SetModelTemperature(const AValue: Double);
    begin
      FStorage.WriteDouble('ModelTemperature', AValue);
    end;
    ```
3.  **Add to the Graphical Interface**:
    *   Open the configuration frame [RadIA.UI.ConfigFrame.dfm](../Source/UI/RadIA.UI.ConfigFrame.dfm) in the Delphi IDE.
    *   Insert a suitable visual control (e.g., `TEdit` or `TComboBox`) and give it a standard name (e.g., `edtModelTemperature`).
    *   In the corresponding `.pas` file, declare the corresponding property in the `IRadIAConfigView` interface to expose the value to the Presenter.
4.  **Synchronize in the Presenter**: In [RadIA.UI.ConfigPresenter.pas](../Source/UI/RadIA.UI.ConfigPresenter.pas), modify the synchronization methods:
    *   In the `LoadSettings` method, load from the Model to the View:
        `FView.ModelTemperature := FConfig.ModelTemperature;`
    *   In the `SaveSettings` method, save from the View to the Model:
        `FConfig.ModelTemperature := FView.ModelTemperature;`

### 3.2 Modifying the Chat Web Interface (WebView2)
The chat interface is drawn locally using packaged web files. All HTML/JS chat logic is located in the `Source/UI/Web/` subdirectory.

*   **Main HTML**: [chat.html](../Source/UI/Web/chat.html) (Contains the visual structure and chat container).
*   **Stylesheets**: [chat.css](../Source/UI/Web/chat.css) (Controls the base chat layout) and [chat-theme.css](../Source/UI/Web/chat-theme.css) (Controls color variables for Light/Dark themes adapted from the IDE).
*   **JS Logic**: [chat.js](../Source/UI/Web/chat.js) (Handles message rendering, markdown parsing, and chat UI events) and [bridge.js](../Source/UI/Web/bridge.js) (Implements the communication bridge data channel between the BPL and WebView2).

> [!IMPORTANT]
> Any modification to JS files or web layout in `Source/UI/Web` requires running the linter to ensure there are no syntax bugs. In the project root, run:
> ```bash
> npx eslint
> ```
> The automated installer (`build.ps1`) takes care of synchronizing these files to `%APPDATA%\RadIA\Web` in local deployments so that the IDE can locate them.

---

## 4. Object Pascal Technical Rules for Source Modifications

When working in this codebase, you must strictly adhere to the following Delphi compiler constraints:

### 4.1 Avoiding the 255-Character String Literal Limit (Error E2056)
The Delphi compiler (especially in 32-bit versions used in the IDE) fails to compile continuous blocks of strings with more than 255 characters inside single quotes.
*   **Incorrect**:
    ```pascal
    LPrompt := 'This is an excessively long prompt instruction that will easily exceed the limit allowed by the Delphi compiler if not properly broken down with explicit concatenations at compile time...';
    ```
*   **Correct**:
    ```pascal
    LPrompt := 'This is an excessively long prompt instruction that ' +
               'will easily exceed the limit allowed by the Delphi compiler ' +
               'if properly broken down with concatenations.';
    ```

### 4.2 Manual Memory Management and try..finally
Delphi does not have a Garbage Collector for class instances. Whenever you create a local instance of an object, ensure its safe destruction using protection blocks:
```pascal
LList := TStringList.Create;
try
  // Perform processing on the list
finally
  LList.Free; // Frees the allocated memory even if a prior exception occurs
end;
```
*   *Note*: Always prefer the `.Free` method. Use `FreeAndNil(LVar)` only if the local variable might be reused or queried as `Assigned(LVar)` after deallocation.

### 4.3 Thread-Safety in IDE Screens
Streaming HTTP operations run in secondary background threads (`TTask`). Since VCL and the WebView2 engine are not thread-safe, **never** update visual elements directly from within the background thread.
*   **Incorrect**:
    ```pascal
    TTask.Run(procedure
    begin
      FWebBrowser.Navigate(LUrl); // Thread error in VCL!
    end);
    ```
*   **Correct**:
    ```pascal
    TTask.Run(procedure
    begin
      // Execute background HTTP call...
      TThread.Queue(nil,
        procedure
        begin
          FView.AppendMessage('user', LResponseText); // Safely runs on the main UI thread
        end);
    end);
    ```

### 4.4 WebView2 Lifecycle during IDE Shutdown
When closing the Delphi IDE, the WebView2 engine (`TEdgeBrowser`) can cause severe COM deadlocks if destroyed synchronously by the VCL.
*   When dynamically creating `TEdgeBrowser` instances, always pass `nil` as the Owner:
    `FEdgeBrowser := TEdgeBrowser.Create(nil);`
*   In the `Destroy` destructor of any form containing WebView2, check the state of the global `GIsShuttingDown` flag (located in `RadIA.Core.Types.pas`):
    ```pascal
    if not GIsShuttingDown then
    begin
      if Assigned(FEdgeBrowser) then
        FreeAndNil(FEdgeBrowser);
    end
    else
    begin
      if Assigned(FEdgeBrowser) then
        FEdgeBrowser.Parent := nil; // Detach visually without forcing synchronous COM release
    end;
    ```
