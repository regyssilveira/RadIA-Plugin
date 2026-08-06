# Rad IA Features and Capabilities

This document contains the complete checklist, categorization, and development status of all features integrated into the **Rad IA** plugin.

---

## Complete Feature Checklist

v0.0.25 note: the plugin now protects Smart Diff **Apply Changes** against duplicated code when the original editor selection is lost.

| Feature | Category | Description | Status |
| :--- | :--- | :--- | :--- |
| **Smart SQL Optimizer** | Integration | Scans and optimizes SQL query strings directly from the Delphi editor context menu. | ✅ Completed |
| **Scan Compiler & OS Warnings** | Integration | Scans the code block for potential Delphi compiler warnings, thread-safety pitfalls, and Windows GDI leaks. | ✅ Completed |
| **Dockable Sidebar Chat** | Chat UX | IDE-integrated panel running WebView2 with Markdown and Pascal highlighting. | ✅ Completed |
| **Chat Welcome Screen** | Chat UX | Welcome screen with a central animation, quick actions, and on-demand history loading. | ✅ Completed |
| **IDE Theme Integration** | Chat UX | Dark/Light adaptation to the Delphi theme, including Mountain Mist as light, scrollbar polish, and consistent code blocks. | ✅ Completed |
| **Keyboard Shortcuts** | Chat UX | Shortcut `Ctrl + Enter` to send prompts and simple `Enter` for line breaks. | ✅ Completed |
| **Layout Persistence** | Chat UX | Automatic saving and restoration of floating window size/position and visibility at startup. | ✅ Completed |
| **Streaming Responses** | Chat UX | Real-time incremental token rendering (SSE) for OpenAI, Gemini, Claude, and Ollama. | ✅ Completed |
| **Multiple Chat Sessions** | Chat UX | Create, rename, delete, and isolate conversations in a collapsible sidebar, with actions locked during active requests. | ✅ Completed |
| **Persistent Chat History** | Chat UX | Automatic local JSON storage and on-demand reload of previous chat sessions. | ✅ Completed |
| **Prompt Navigation (↑/↓)** | Chat UX | Terminal-like keyboard arrow history lookup in prompt input. | ✅ Completed |
| **Request Cancellation** | Chat UX | Abort active AI HTTP requests asynchronously using a dynamic stop button and lock session actions while processing. | ✅ Completed |
| **Export Conversation** | Chat UX | Save current active chats to Markdown (.md) or standalone rich HTML formats. | ✅ Completed |
| **Prompt Templates** | Chat UX | Quick prompt template library with token replacement and the `/template` command. | ✅ Completed |
| **Dynamic Slash Commands** | Chat UX | Dynamic mapping of templates to slash commands (e.g. `/createprojectarch`), synced and autocompleted in WebView2. | ✅ Completed |
| **Declarative Skills and Templates** | Extensibility | Schema 2 manifest with hot reload, autocomplete, and minimal `chat.prompt` permission. | ✅ Completed |
| **Declarative Tool Aliases** | Extensibility | Schema 3 registers safe chat/MCP aliases that inherit internal tool risk, schemas, and consent. | ✅ Completed |
| **Declarative Workflows** | Extensibility | Schema 5 chains up to 16 internal tools with inherited risk, bounds, and per-step central policy, without arbitrary shells. | ✅ Completed |
| **Editor Code Rendering in Chat** | Chat UX | Prompts sent from the editor menu preserve fenced Markdown code blocks with Pascal highlighting also in user messages. | ✅ Completed |
| **Template Backup & Restore** | Chat UX | Transactional JSON import and export with schema validations and merge/overwrite UI options. | ✅ Completed |
| **Google Gemini** | Provider | Native BYOK integration for Gemini 1.5 Pro and Gemini 1.5 Flash models. | ✅ Completed |
| **OpenAI ChatGPT** | Provider | Native BYOK integration for GPT-4o, GPT-4o-mini, and others. | ✅ Completed |
| **Hybrid Login (Web Login)**| Provider | Choose between BYOK (API Keys) or Web Login (Plus/Pro) for OpenAI and Gemini. | ❌ Removed (v0.0.29) |
| **Anthropic Claude** | Provider | Native BYOK integration for Claude 3 Haiku and Claude 3.5 Sonnet. | ✅ Completed |
| **DeepSeek** | Provider | Native BYOK integration for DeepSeek Chat and Reasoning models. | ✅ Completed |
| **Groq** | Provider | Native BYOK integration for Llama, Mixtral, and Gemma models via Groq's high-speed cloud. | ✅ Completed |
| **OpenRouter** | Provider | Native OpenRouter support with SSE streaming, dynamic model selection, and complete settings integration. | ✅ Completed |
| **Native GitHub Copilot** | Provider | Direct, remote connection to GitHub Copilot cloud (personal/business) with integrated PIN Device Flow and one-click VS Code token import. | ✅ Completed |
| **Azure OpenAI** | Provider | Native Azure OpenAI support for corporate IT compliance with customizable endpoint URL, deployment name, and API version. | ✅ Completed |
| **Alibaba Qwen** | Provider | Native BYOK integration for Alibaba Qwen (ModelStudio/DashScope) models. | ✅ Completed |
| **Mistral AI** | Provider | Native BYOK integration for Mistral AI (Codestral, Mistral Large) models. | ✅ Completed |
| **AWS Bedrock** | Provider | Native support for AWS Bedrock with SigV4 signing, EventStream parser, and secure credentials (IAM/DPAPI). | ✅ Completed |
| **Ollama Local/Network** | Provider | Connects to local open-source models with no paid API keys and dynamic tags discovery. | ✅ Completed |
| **LM Studio** | Provider | Native LM Studio support with SSE streaming, local models auto-discovery, and customizable server URL. | ✅ Completed |
| **Custom Base URL** | Provider | Route OpenAI API payload to other endpoints like Groq, DeepSeek, or LM Studio. | ✅ Completed |
| **Dynamic Providers** | Provider | Metadata-driven plugin-like architecture for registering new models and AI backends dynamically. | ✅ Completed |
| **Dynamic JSON Providers** | Provider | Add new OpenAI-compatible providers by saving JSON files into `%APPDATA%\RadIA\providers\`. | ✅ Completed |
| **Project Context** | Intelligence | Automatic project context loading (system prompts/custom files) via `.radia`. | ✅ Completed |
| **Tokens & Cost Tracking** | Control | Status bar counter for session token usage and USD estimated cost. | ✅ Completed |
| **Local Quota Control** | Control | Define a monthly token limit with request blocking and a manual reset button. | ✅ Completed |
| **Editor Context Actions** | Integration | Rad IA submenu at the top of the editor right-click menu to explain code, optimize/refactor, generate tests, find bugs, document methods, and review the active unit. When there is no selection, the whole unit is used as context. | ✅ Completed |
| **Create Example from Comment** | Integration | Generates the body of empty methods from natural-language comments inside `begin/end`, preserving the comment and inserting the example directly into the editor. | ✅ Completed |
| **Interactive Smart Diff** | Integration | Side-by-side original/suggested diff view with safe editor application, replacing the original block and rejecting the action when the block cannot be found. | ✅ Completed |
| **Smart Build Debugger** | Integration | Message tab integration to resolve compiler issues with one-click fixes. | ✅ Completed |
| **Auto XML Documentation** | Generation | Write Delphi-compliant XML help comments above methods automatically. | ✅ Completed |
| **DTO & Model Converter** | Generation | Convert JSON or SQL DDL payloads into Object Pascal data classes (DTOs) or records (DEXT ORM, Aurelius, REST.Json, or Vanilla). | ✅ Completed |
| **Complete Project Generation** | Generation | Automatic creation of Delphi projects (.dpr, .pas, .dfm) from a prompt, saving them to an empty folder and opening them in the IDE. | ✅ Completed |
| **Full-Screen Generator** | Generation | Generator area uses the whole panel and collapses the chat list to avoid cross-session manipulation. | ✅ Completed |
| **Slash Commands Popup Menu (/)** | Chat UX | Floating suggestions and autocomplete menu when typing `/` in the chat input. | ✅ Completed |
| **Stack Trace Assistant** | Integration | Error log/stack trace analyzer integrated with active unit context. | ✅ Completed |
| **Static Code Analysis** | Integration | Code scan for memory leaks (missing try..finally) and SOLID/Clean Code anti-patterns. | ✅ Completed |
| **Secure Credentials** | Security | API Keys saved securely inside the Windows Registry using DPAPI. | ✅ Completed |
| **Multi-IDE Build & Install** | Infrastructure | PowerShell script supporting multiple registry Delphi environments, interactive selection, WebView2 asset synchronization, and local cache cleanup. | ✅ Completed |
| **MVP Architecture** | Infrastructure | Complete decoupling between VCL UI (Views) and logic (Presenters) in the Chat and Settings frames. | ✅ Completed |
| **Storage Abstraction** | Infrastructure | Persistence abstraction via `ISettingsStorage` allowing in-memory configurations. | ✅ Completed |
| **Presentation Testing** | Infrastructure | Automated DUnitX test suite validating Presenters logic with mocked Views. | ✅ Completed |
| **Editor Hook** | Infrastructure | Resilient editor context-menu integration using an asynchronous VCL hook, compatible with Delphi 12/13 and stable during new project creation. | ✅ Completed |
| **Agentic Registry** | Agentic | Catalog shared by chat, MCP, and extensions. | ✅ Completed |
| **Consent and Audit** | Security | Scoped decisions and a sanitized audit trail. | ✅ Completed |
| **Reviewable Patches** | Agentic | Preview, base hash, apply, and reversal with conflict detection. | ✅ Completed |
| **OTA Workspace** | Integration | Facades for editor, project, build, Designer, and debugger. | ✅ Completed |
| **Local MCP Server** | Integration | Stdio bridge, named pipe, and per-PID discovery. | ✅ Completed |
| **Agentic Designer** | Integration | Reviewable components, properties, events, and layout. | ✅ Completed |
| **Agentic Debugger** | Integration | State, control, breakpoints, expression evaluation, and watches. | ✅ Completed |
| **Inline Review** | Editor | Visual review with controlled apply and reversal in the editor. | ✅ Completed |
| **Multiline Ghost Text** | Editor | Per-line virtual overlays, full or next-word acceptance, and configurable shortcuts without pre-acceptance buffer changes. | ✅ Completed |
| **Local Knowledge** | Agentic | Incremental, persistent, rebuildable, per-project index. | ✅ Completed |
| **Tool Extensions** | Infrastructure | Versioned API and sample package for external tools. | ✅ Completed |
| **Signed Declarative Extensions** | Security | RSA-SHA256 packages with fingerprints, first-use trust, and visual revocation. | ✅ Completed |
| **Delphi 11/12/13 and IDE64** | Compatibility | Validated Win32 matrix plus Delphi 13 IDE64. | ✅ Completed |
