# Guide for Adding New AI Providers to Rad IA

Thanks to the new **Dynamic Provider Architecture**, adding a new AI backend (such as DeepSeek, Claude, or a custom internal service) has become extremely simple and decoupled.

> [!NOTE]
> Rad IA adopts a dynamic registration architecture based entirely on strings. There are no global static AI provider enums in the plugin core. Adding a new backend is completely ad-hoc and autonomous, relying only on the auto-registration block of the provider unit itself.

---

## 🛠️ Step-by-Step to Create a New Provider

### 1. Create the Provider Unit
Create a new Pascal unit in the `Source/Providers` directory named after your provider (e.g., `RadIA.Provider.MyAwesomeAI.pas`).

### 2. Define the Provider Class
Your class must inherit from:
*   `TRadIAProviderBase` (if the provider uses a proprietary API/payload format and exclusive HTTP requests).
*   `TRadIAOpenAICompatibleProvider` (if the provider exposes an OpenAI-compatible API, inheriting all ready-to-use HTTP payloads, requests, and SSE streaming mechanisms).

Implement the constructor signature and mandatory methods:
```pascal
unit RadIA.Provider.MyAwesomeAI;

interface

uses
  System.SysUtils, System.Classes, RadIA.Core.Interfaces,
  RadIA.Core.Types, RadIA.Core.TokenUsage, RadIA.Provider.Base;

type
  TRadIAMyAwesomeAIProvider = class(TRadIAOpenAICompatibleProvider)
  protected
    function GetBaseUrl: string; override;
  public
    constructor Create(const AConfig: IRadIAConfig); override;
    function GetAvailableModels: TArray<string>; override;
    function GetName: string; override;
  end;
```

### 3. Implement the Provider Logic
In the `implementation` section, supply the base URL, default models, and configure the provider identification by setting `FProviderId`:

```pascal
implementation

uses
  RadIA.Core.ProviderRegistry;

constructor TRadIAMyAwesomeAIProvider.Create(const AConfig: IRadIAConfig);
begin
  inherited Create(AConfig);
  // ESSENTIAL: FProviderId must be set to the exact same string identifier
  // that will be used in the global auto-registration block (step 4).
  FProviderId := 'AwesomeAI';
end;

function TRadIAMyAwesomeAIProvider.GetBaseUrl: string;
begin
  Result := 'https://api.myawesomeai.com/v1';
end;

function TRadIAMyAwesomeAIProvider.GetAvailableModels: TArray<string>;
begin
  Result := TArray<string>.Create('awesome-chat-v1', 'awesome-coder-v2');
end;

function TRadIAMyAwesomeAIProvider.GetName: string;
begin
  Result := 'My Awesome AI';
end;
```

### 4. Auto-Register in the Global Registry
At the bottom of the file, add an `initialization` block to register the provider with `TProviderRegistry`. This tells the plugin how to instantiate the provider class, what the default models are, and if it requires an API key or custom endpoint URLs:

```pascal
initialization
  TProviderRegistry.RegisterProvider(
    TProviderMetadata.Create(
      'AwesomeAI',                   // Identifier ID (used in Windows registry subkeys)
      'My Awesome AI',               // Display Name in UI
      'https://api.myawesomeai.com', // Default Base URL
      True,                          // Requires API Key? (HasApiKey)
      False,                         // Supports custom endpoint URLs? (HasCustomUrl)
      ['awesome-chat-v1', 'awesome-coder-v2'], // Default fallback models list
      function(const ACfg: IRadIAConfig): IRadIAProvider
      begin
        Result := TRadIAMyAwesomeAIProvider.Create(ACfg);
      end
    )
  );

end.
```

> [!IMPORTANT]
> **Provider ID Naming Conventions:**
> The first argument of `TProviderMetadata.Create` (in this example, `'AwesomeAI'`) acts as the physical identification key for the provider and will be used as the Windows Registry subkey name for API keys and configuration persistence (e.g., `HKEY_CURRENT_USER\Software\RadIA\AwesomeAI`). 
> * It **must contain only simple alphanumeric characters** (e.g., `[A-Za-z0-9]`).
> * **Never use spaces, accents, slashes, or special characters**, as this will cause read/write failures when accessing the Windows Registry.

### 5. Add the Unit to the Package (`RadIA.dpk`)
Add your new unit to the `RadIA.dpk` package file (and `Tests/RadIATests.dpr` if applicable) so that the compiler includes it during compilation:

```pascal
contains
  RadIA.Provider.MyAwesomeAI in 'Source\Providers\RadIA.Provider.MyAwesomeAI.pas',
```

---

## ⚡ What Happens Next? (Automatic)
Without changing any other line of code in the plugin:
1.  **Persistence:** The `TRadIAConfig` class will automatically load and save API keys, models, timeouts, and temperatures for this provider under the `AwesomeAI` subkey in the Windows Registry using the new string-based APIs (e.g. `GetApiKey('AwesomeAI')`).
2.  **Instantiation:** The `TRadIAService` orchestrator will automatically intercept chat selector choices and resolve your dynamic factory registered inside `TProviderRegistry`.
3.  **Wizards and Options:** The new provider will immediately become available in the options frame, orchestrator, async execution loops, and SSE text streaming in a 100% dynamic way.

---

## 🔌 Adding Dynamic Providers via JSON (No Recompilation Plug-ins)

If the AI provider you want to add is **compatible with the OpenAI API** (which includes the vast majority of cloud services like Together AI, DeepInfra, OpenRouter, and local servers like LM Studio, vLLM, and LocalAI), you **do not need to write any Delphi code or compile the plugin**.

Simply create a JSON configuration file in the user's providers folder.

### 📂 Where to Place the JSON File
Save the file with a `.json` extension in the following directory:
`%APPDATA%\RadIA\providers\`
*(Example: `C:\Users\Username\AppData\Roaming\RadIA\providers\togetherai.json`)*

> [!NOTE]
> If the `providers` folder inside `%APPDATA%\RadIA\` does not exist, it will be automatically created when the Delphi IDE starts.

### 📝 JSON Structure
The configuration file must follow the format below:

```json
{
  "id": "TogetherAI",
  "displayName": "Together AI",
  "baseUrl": "https://api.together.xyz/v1",
  "apiKey": "your-api-key-here",
  "hasApiKey": true,
  "hasCustomUrl": true,
  "defaultModels": [
    "meta-llama/Llama-3-70b-chat-hf",
    "mistralai/Mixtral-8x7B-Instruct-v0.1"
  ]
}
```

#### Fields Description:
*   `id`: Unique identifier key in the registry and code (case-sensitive).
*   `displayName`: Friendly name that will appear on the settings screen and the provider selector.
*   `baseUrl`: Default base URL of the OpenAI-compatible API (typically ending in `/v1` or the root path).
*   `apiKey`: (Optional) API key for the provider. Recommended to load the key directly from the file, since dynamic providers do not have dedicated tab sheets designed in the options VCL interface.
*   `hasApiKey`: Indicates if the settings UI will require entering an API Key for this provider.
*   `hasCustomUrl`: Allows developers to override the base URL in the settings UI to redirect to a local proxy or custom server.
*   `defaultModels`: List of strings representing the default fallback models shown in the combo-box.

### ⚡ What Happens Next? (Automatic)
As soon as the Delphi IDE is restarted:
1.  **Scanning:** The `TProviderRegistry` will read the AppData folder, parse the `.json` files, and dynamically register each provider using the generic `TRadIAGenericOpenAIProvider` client class.
2.  **Configuration:** The new provider will automatically appear in the sidebar chat combo-box.
3.  **Persistence:** The `TRadIAConfig` class will automatically load and save API keys, models, timeouts, temperature, and custom URLs for this dynamic provider in the Windows Registry under the defined ID.
