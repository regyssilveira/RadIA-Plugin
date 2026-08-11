# Installation and Configuration Guide — Rad IA

This document separates end-user installation from contributor source builds.

---

## 1. Installation

Rad IA requires active and valid API keys to function with cloud models (Gemini, OpenAI, Claude, DeepSeek, or Groq) or a configured **Ollama** instance running on your machine or local network.

### Recommended end-user installation

1. Open the [latest release](https://github.com/regyssilveira/RadIA-Plugin/releases/latest).
2. Download `RadIA-v<version>-Setup.exe`, the only public installation artifact.
3. Close every Delphi instance.
4. Run the installer and select Delphi 12 Win32, Delphi 13 Win32, and/or Delphi 13 IDE64.
5. Open the IDE and run **Tools > Rad IA Getting Started > Run installation doctor** or `/doctor`.

Using a release does not require extracting a ZIP, installing PowerShell/npm, or compiling the
project. **Repair** reapplies files while preserving settings; **Uninstall** removes selected
architectures and preserves user data by default.

During installation, the installer also updates the HTML/CSS/JS assets used by WebView2 under
`%APPDATA%\RadIA\Web`. It clears the local `%APPDATA%\RadIA\WebView2` cache when no Delphi IDE is
open. If another Delphi version is in use, cache cleanup is deferred and installation continues
without interrupting that work; the refreshed assets take full effect after that IDE restarts.

The installer validates every Web resource declared by the manifest, not only the main page. It
also compares `WebView2Loader.dll` with the packaged copy and updates the file when required.
**Repair** reapplies and verifies the BPL, DCP, MCP Bridge, extension packager, loader, Delphi
registration, and every Web asset. Uninstall remains able to remove RadIA artifacts even when the
corresponding Delphi installation has already been removed.

After opening the IDE, use **Tools > Rad IA Getting Started > Run installation doctor** or type
`/doctor` in chat. The diagnostic verifies the effective route, provider, CLI and MCP only when
each is required, terminal, web assets, tools, and the external MCP runtime. It returns a card with
a score, checks, and next action without displaying tokens or credentials. See
[RadIA Doctor](doctor.en.md).

### Build from source

This flow is for contributors and users who deliberately chose to compile the open-source project.
It is not the normal release installation procedure.

1. Clone this repository to your computer.
2. Open the project group `RadIA.groupproj` in Delphi.
3. Right-click on `RadIA.bpl` in the Project Manager and click **Build**.
4. Right-click on `RadIA.bpl` again and click **Install**.
5. A confirmation dialog will appear, and the **Rad IA** panel will dock on the right side of your IDE.
6. Go to **Tools ➔ Rad IA Chat Panel** to display the chat, and click the **Settings** button at the top of the panel to configure your API keys.

---

## 2. Configuring Ollama (Local or Network)

**Ollama** lets you run open-source LLMs (Llama 3, Mistral, Phi-3, CodeLlama, etc.) directly on your machine or on a server in your local network — with no paid API dependency.

**Prerequisite:** Install Ollama from [https://ollama.com](https://ollama.com) and pull at least one model with `ollama pull llama3`.

* **For local use (same machine):**
  1. Start the Ollama server (on Windows, the service starts automatically after installation).
  2. The default URL `http://localhost:11434` is already pre-configured — **no changes required**.
  3. In the plugin settings (**Settings → Ollama Local/Network Settings**), confirm the URL reads `http://localhost:11434`.
  4. Select **Ollama** in the provider dropdown in the chat panel.

* **For network use (remote server):**
  1. Make sure Ollama is running on the remote server and listening on all interfaces. Set the environment variable `OLLAMA_HOST=0.0.0.0` on the server before starting the service.
  2. In the plugin settings (**Settings → Ollama Local/Network Settings**), set the URL to the server's IP address or hostname. Example: `http://192.168.1.100:11434`.
  3. Make sure port `11434` is reachable through the network's firewall.
  4. Select **Ollama** in the provider dropdown in the chat panel.

> **Note:** The plugin automatically discovers available models from the Ollama server via `/api/tags`. If the connection fails, it falls back to a built-in list of well-known model names.

> [!TIP]
> **Resolving Ollama CORS Issues:** If the plugin encounters Cross-Origin Resource Sharing (CORS) connection errors when making requests to a remote Ollama server, make sure to define the `OLLAMA_ORIGINS=*` environment variable on the hosting server before starting the Ollama service. This will authorize traffic originating from Rad IA's WebView2 component.

---

## 3. OpenAI API or ChatGPT Pro

Under **Settings > Providers > OpenAI**, choose one route:

- **API Key (BYOK)** uses HTTP, OpenAI API Platform billing, and its separate quota.
- **ChatGPT Pro via Codex CLI** uses the ChatGPT/Codex account session and quota. Click
  **Configure Codex CLI login**, select Codex under **CLI & MCP**, use **Start login**, and run
  **Diagnose** until the state reports `authentication: ready`.

In the composer, **RadIA native** keeps history, context, RTK, and orchestration in RadIA while using
Codex CLI only as provider transport. **Codex CLI direct** delegates the prompt to the external
client. Both Codex routes share the same login. Legacy OAuth settings migrate automatically and are
never sent to `api.openai.com`.

## 4. API Key Acquisition Guide by Provider

Enter the obtained keys in the plugin settings (**Settings** at the top of the chat panel):

1. **Google Gemini (Recommended)**
   * **How to obtain:** Access the [Google AI Studio Console](https://aistudio.google.com/).
   * **Instructions:** Log in, click **Create API Key** on the left sidebar menu, select your project, and copy the generated key.

2. **OpenAI ChatGPT**
   * **How to obtain:** Access the [OpenAI Platform](https://platform.openai.com/).
   * **Instructions:** Log in, navigate to **API Keys** in the side menu, click **Create new secret key**, and copy the token (starts with `sk-`).

3. **Anthropic Claude**
   * **How to obtain:** Access the [Anthropic Console](https://console.anthropic.com/).
   * **Instructions:** Log in, go to the **API Keys** tab, click **Create Key**, and copy the token (starts with `sk-ant-`).

4. **DeepSeek**
   * **How to obtain:** Access the [DeepSeek Platform Console](https://platform.deepseek.com/).
   * **Instructions:** Log in, go to the **API Keys** section, click **Create API Key**, and copy it.

5. **Groq Cloud**
   * **How to obtain:** Access the [Groq Console](https://console.groq.com/).
   * **Instructions:** Navigate to **API Keys**, click **Create API Key**, and copy it (starts with `gsk_`).

6. **Azure OpenAI**
   * **How to obtain:** Through the Microsoft Azure portal.
   * **Instructions:** Access your Azure OpenAI resource, go to **Keys and Endpoint**, and copy the Endpoint and one of the keys. In the Rad IA settings tab, configure the API Key, Endpoint URL, active Deployment Name, and the Azure API Version (default: `2024-02-15-preview`).

7. **Alibaba Qwen**
   * **How to obtain:** Access the [Alibaba Cloud DashScope/ModelStudio console](https://bailian.console.aliyun.com/).
   * **Instructions:** Create an API Key in the settings page and copy the token.

8. **Mistral AI**
   * **How to obtain:** Access the [Mistral AI Console](https://console.mistral.ai/).
   * **Instructions:** Go to the **API Keys** section, create a new key, and copy the token.

9. **AWS Bedrock**
   * **How to obtain:** Through the AWS Console (Amazon Web Services).
   * **Instructions:** Enable access to your desired models (such as Anthropic Claude or Meta Llama) inside the Bedrock console. Create IAM access credentials inside the AWS console to obtain an **Access Key ID** and a **Secret Access Key**. In the Rad IA options frame, configure these fields, enter the AWS **Region** where Bedrock is provisioned (e.g., `us-east-1`), and optionally provide the **Session Token** if you are using temporary IAM credentials.

   > [!IMPORTANT]
   > **IAM Permissions and Model Access in Bedrock:**
   > * The IAM access key used must have security policies attached that allow executing the actions `bedrock:InvokeModel` and `bedrock:InvokeModelWithResponseStream`.
   > * By default, AWS Bedrock requires you to request access to models individually in the AWS Console for the intended region (*Model Access* menu). Confirm that the selected model is enabled for the account and region before connecting it in Rad IA.

> **Note on Dynamic and Enterprise Providers:** You can also dynamically add new OpenAI-compatible API providers (such as GitHub Copilot or third-party proxies) by saving JSON configuration files under `%APPDATA%\RadIA\providers\`. For more details, check our [Guide for Adding New Providers (docs/new_provider_guide.en.md)](new_provider_guide.en.md) and the [GitHub Copilot Configuration Guide (docs/copilot_proxy_guide.en.md)](copilot_proxy_guide.en.md).

---

## 4. Contributor build and packaging

> This section is not required to install a release. Any ZIP mentioned below is a verified internal
> input used to build and test the visual installer; ZIP packages are not published.

The distribution package installs `RadIA.MCP.Bridge.exe` next to the BPL. For per-process
discovery, multi-IDE selection, handshake, consent, and troubleshooting, see the
[MCP Integration Guide](mcp_integration_guide.en.md).

The `.\build.ps1` script supports the following switches:

* `-Install`: Builds the plugin, copies binaries to public Delphi paths, synchronizes local WebView2 assets, and registers the package.
* `-Uninstall`: Clean uninstalls the plugin, deleting files and registry keys.
* `-Release`: Enables compiler optimizations and outputs a smaller BPL binary.
* `-IDE64`: Compiles and installs specifically for the 64-bit Delphi IDE in Delphi 13 Florence.
* `-DelphiVersion "<version>"`: Optional. Allows forcing a specific Delphi version installed in the system (e.g., `"23.0"`, `"37.0"`, `"Athens"`).
* `-Test`: Optional. Compiles and executes the unit test suite (DUnitX). By default, tests are omitted from the build process.

> [!TIP]
> **Multiple IDE Versions Support:** If you have more than one Delphi version installed on Windows and execute the script with `-Install` or `-Uninstall` without passing the `-DelphiVersion` parameter, the script will automatically list all valid installations found in the Registry and display a console menu for interactive selection.

> [!NOTE]
> **DUnitX Auto-Detection:** If the `-Test` parameter is provided, the installer automatically detects if the DUnitX framework is present in your selected Delphi installation. If DUnitX is missing, the script will display a warning, automatically disable tests execution, and proceed normally with compiling and installing the main plugin.

### Internal package repair and removal

The script bundled in the internal validation package supports `Install`, `Repair`, and `Uninstall`. Use
`-PlanOnly` to inspect every target without changing files or the Registry:

```powershell
# Repair binaries, bridge, and assets while preserving settings and data
powershell -ExecutionPolicy Bypass `
  -File .\Scripts\Install-RadIA.Package.ps1 `
  -DelphiVersion "37.0" -IDE64 -Mode Repair

# Preview removal; user data is preserved
powershell -ExecutionPolicy Bypass `
  -File .\Scripts\Install-RadIA.Package.ps1 `
  -DelphiVersion "37.0" -IDE64 -Mode Uninstall -PlanOnly

# Remove this architecture while preserving user data
powershell -ExecutionPolicy Bypass `
  -File .\Scripts\Install-RadIA.Package.ps1 `
  -DelphiVersion "37.0" -IDE64 -Mode Uninstall
```

Add `-RemoveUserData` only when settings, sessions, audit, knowledge, and caches under
`%APPDATA%\RadIA` must also be removed. The shared IDE `WebView2Loader.dll` is always preserved.
Public web assets are removed only when no RadIA architecture remains installed for that Delphi
version. Every mutating operation requires the IDE to be closed.


