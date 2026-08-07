# Configuration Guide: GitHub Copilot in Rad IA via Local Proxy (Phase 1)

This guide walks you through using your personal or corporate **GitHub Copilot** subscription (and other cloud-based enterprise AI assistants) inside **Rad IA** without implementing complex native authentication flows.

By leveraging the new **Dynamic JSON Providers** feature (introduced in version `v0.0.6`), we can easily integrate Rad IA with a local proxy service compatible with the OpenAI API format.

---

## ⚙️ How does the Proxy Architecture work?

The flow consists of running a lightweight helper service locally on your development machine. This service handles secure OAuth authentication with GitHub and translates Rad IA's standard OpenAI API payloads into GitHub Copilot's internal API requirements:

```
[ Rad IA (Delphi IDE) ] 
       │  (Standard OpenAI API payload)
       ▼
[ Local Proxy (Port 8080) ] 
       │  (Token signing and Header proxying)
       ▼
[ GitHub Copilot Servers (Cloud) ]
```

---

## 🛠️ Step-by-Step Configuration for GitHub Copilot

The most stable and widely used open-source proxy for this purpose is **[copilot-gpt4-service](https://github.com/aaamoon/copilot-gpt4-service)**.

### Step 1: Running the Local Proxy

You can launch the local proxy service in one of two quick ways:

#### Option A: Via Docker (Recommended)
If you have Docker installed on your machine, run the following command in your terminal to start the container in background:
```bash
docker run -d --name copilot-gpt4-service -p 8080:8080 aaamoon/copilot-gpt4-service
```

#### Option B: Download the Native Executable
1. Go to the **[copilot-gpt4-service Releases](https://github.com/aaamoon/copilot-gpt4-service/releases)** page.
2. Download the binary matching your operating system (e.g., `copilot-gpt4-service-windows-amd64.exe`).
3. Run the downloaded file. It will spin up a console window running on port `8080` (`http://localhost:8080`) by default.

---

### Step 2: Retrieve your GitHub Copilot Token

Once the local proxy is up and running, authenticate with your GitHub account to generate the local access token:

1. Open your web browser and go to: **`http://localhost:8080/copilot/tokens`** (or `http://127.0.0.1:8080/copilot/tokens`).
2. The proxy system will display a link and a device authentication PIN (Device Flow) from GitHub.
3. Click the link, log in with your GitHub account (which must have an active Copilot subscription), and submit the PIN code.
4. After authorization, the page will output a JSON payload containing an access token starting with **`ghu_...`** or **`gho_...`**.
5. **Copy this entire Token string**. You will use it as your `apiKey`.

---

### Step 3: Register the Dynamic Provider in Rad IA

Now that you have the proxy running and your Copilot token:

1. On Windows, navigate to Rad IA's dynamic providers folder:
   * Press `Win + R`, type `%APPDATA%\RadIA\providers\` and press `Enter`. (If the `providers` folder does not exist, create it).
2. Create a new file named **`github-copilot.json`**.
3. Open the file in a text editor and paste the following configuration, replacing the token with your own:

```json
{
  "id": "github-copilot",
  "displayName": "GitHub Copilot",
  "baseUrl": "http://localhost:8080/v1",
  "apiKey": "ghu_paste_your_token_here_...",
  "defaultModels": [
    "gpt-5.4"
  ]
}
```

4. Save the file.

---

### Step 4: Restart the Delphi IDE

1. If your Delphi IDE is open, close and reopen it.
2. Rad IA will automatically detect `github-copilot.json`, parse its details, and add **GitHub Copilot** to the provider selection list in the chat sidebar.
3. **You are ready!** Your chat conversations, code explanations, and refactoring requests in Rad IA will now be processed quickly and securely through your GitHub Copilot enterprise/personal infrastructure.

---

## 🔒 Security and Enterprise Compliance

*   **Credential Isolation**: The `ghu_...` token stays stored locally on your development machine.
*   **Data Handling**: Prompts and source code snippets are sent to GitHub's secure cloud endpoints according to your organization's subscription terms (which typically enforce non-training clauses).
*   **Access Control**: No login information is shared with unauthorized third parties. The proxy only authenticates and forwards standard VCL payloads to official GitHub APIs.
