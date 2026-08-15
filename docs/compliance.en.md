# Terms of Use, Corporate Compliance, and Data Security

This document establishes the compliance guidelines, terms of use, and data privacy policies for the **Rad IA** plugin.

---

## 1. Trademark Disclaimer
All trademarks, logos, service marks, and trade names mentioned in this project, including
*Embarcadero Delphi*, *Microsoft Windows*, *Microsoft Edge*, *WebView2*, *Google Gemini*,
*OpenAI ChatGPT*, *Anthropic Claude*, *DeepSeek*, *Groq*, and *Ollama*, are the property of their
respective owners.

The use of these names and trademarks is solely for compatibility, configuration, and technology integration description purposes. **Rad IA** is an independent, open-source project and has no official affiliation, sponsorship, endorsement, or association with the owners of these trademarks.

---

## 2. Mandatory Code Review & Limitation of Liabilities
*   **Human Review Required:** Rad IA is a productivity assistant that generates code suggestions leveraging third-party AI models. Any generated suggestions (including refactorings, bug fixes, documentation, and unit tests) may contain inaccuracies, logic errors, or vulnerabilities. The user is **solely responsible** for reviewing, validating, testing, and approving any code suggested by the AI before integrating it into production environments.
*   **Limitation of Liabilities:** The creators and contributors of Rad IA shall not be held liable for any damages, data loss, loss of profits, security breaches, or service interruptions resulting from the use of AI-suggested code or the execution of this plugin within the IDE.

---

## 3. API Key Security (BYOK)
Rad IA operates under a "Bring Your Own Key" (BYOK) policy:
*   API keys entered in the settings panel are encrypted and stored locally on the user's machine using the Windows Data Protection API (**DPAPI**).
*   These keys are stored directly inside the Windows Registry for the current user and are never sent to external telemetry servers or third parties.
*   When executing requests, the keys are transmitted securely and directly to the official endpoints of the respective AI providers.

---

## 4. Data Privacy & Corporate Compliance (GDPR / LGPD)
When using cloud-based providers (Google Gemini, OpenAI, Anthropic, DeepSeek, or Groq), snippets of your selected source code and project context will be transmitted to their respective remote servers for processing.

*   **Confidential Corporate Use:** If you work on projects with restricted proprietary code or under strict corporate compliance regulations (such as GDPR or LGPD), **we strongly recommend using Ollama** configured locally.
*   **Total Offline Privacy:** By running local models offline (such as Llama 3, Phi-3, or Mistral via Ollama), all prompt and code processing is performed entirely within your machine or internal network, ensuring that no proprietary source code ever leaves your company's secure environment.

### Local agentic platform data

RadIA stores a sanitized audit trail at `%APPDATA%\RadIA\audit\tools.jsonl` and rebuildable indexes
at `%APPDATA%\RadIA\Knowledge`. This data remains local unless an authorized operation includes
project content in context sent to the selected provider.

Preserve audit data when required for traceability. Remove indexes only after closing every IDE
and according to the organization's retention policy.

### Chat surface and export protections

*   **Content Security Policy (CSP):** the chat and diff web surfaces declare a CSP that blocks
    remote connections and images (`connect-src 'none'`, `frame-src 'none'`,
    `img-src 'self' data:`). A model reply carrying malicious HTML therefore cannot send
    conversation fragments off the machine while it renders.
*   **Secret redaction on export:** exporting the conversation to Markdown or HTML runs the content
    through the secret redactor, which replaces `Bearer` tokens, AWS access keys, and sensitive
    JSON fields (`api_key`, `password`, `authorization`, among others) with `[REDACTED]`.
*   **Redaction in diagnostic logs:** the payload summary written to `%APPDATA%\RadIA\Logs` applies
    the same redaction before truncating the sample.
*   **CLI login without a shell interpreter:** guided authentication runs the CLI binary directly
    instead of going through `cmd.exe`, so special characters in the configured path are never
    interpreted as commands.
