# Guia de Instalação e Configuração — Rad IA

Este documento separa a instalação para usuários finais da compilação destinada a contribuidores.

---

## 1. Instalação

O Rad IA exige chaves de API válidas e ativas para funcionar com provedores de nuvem (Gemini, OpenAI, Claude, DeepSeek ou Groq) ou uma instância configurada do **Ollama** rodando localmente ou na rede.

### Instalação recomendada para usuários

1. Abra a [release mais recente](https://github.com/regyssilveira/RadIA-Plugin/releases/latest).
2. Baixe `RadIA-v<versão>-Setup.exe`, o único artefato público de instalação.
3. Feche todas as instâncias do Delphi.
4. Execute o instalador e selecione Delphi 12 Win32, Delphi 13 Win32 e/ou Delphi 13 IDE64.
5. Abra a IDE e execute **Tools > Rad IA Getting Started > Run installation doctor** ou `/doctor`.

Não é necessário extrair ZIP, instalar PowerShell/npm ou compilar o projeto para usar o Rad IA.
**Repair** reaplica os arquivos mantendo configurações; **Uninstall** remove as arquiteturas
selecionadas e preserva os dados do usuário por padrão.

Durante a instalação, o instalador também atualiza os recursos HTML/CSS/JS usados pelo WebView2 em
`%APPDATA%\RadIA\Web`. O cache local `%APPDATA%\RadIA\WebView2` é limpo quando nenhuma IDE Delphi
está aberta. Se outra versão do Delphi estiver em uso, a limpeza é adiada e o instalador continua sem
interromper o trabalho; os recursos atualizados passam a valer integralmente após reiniciar essa IDE.

Depois de abrir a IDE, use **Tools > Rad IA Getting Started > Run installation doctor** ou digite
`/doctor` no chat. O diagnóstico verifica provider, executor, MCP quando necessário, terminal,
recursos web e a primeira tool somente leitura. Ele retorna score, checks e próxima ação sem
mostrar tokens ou credenciais.

### Compilação a partir do código-fonte

Este fluxo é destinado a contribuidores e usuários que escolheram compilar o projeto aberto.
Ele não é o procedimento normal de instalação de uma release.

1. Clone o repositório em sua máquina.
2. Abra o grupo de projetos `RadIA.groupproj` no Delphi.
3. Clique com o botão direito em `RadIA.bpl` no Project Manager e selecione **Build**.
4. Clique novamente com o botão direito em `RadIA.bpl` e selecione **Install**.
5. A janela de confirmação de instalação da IDE será exibida, e o painel do **Rad IA** aparecerá acoplado na lateral da IDE.
6. Acesse o menu **Tools ➔ Rad IA Chat Panel** para exibir o chat, e clique no botão **Settings** no topo do painel para configurar suas chaves de API e começar.

---

## 2. Configurando o Ollama (Local ou em Rede)

O **Ollama** permite executar LLMs de código aberto (Llama 3, Mistral, Phi-3, CodeLlama etc.) diretamente na sua máquina ou em um servidor na rede local — sem dependência de APIs pagas.

**Pré-requisito:** Instale o Ollama a partir de [https://ollama.com](https://ollama.com) e baixe pelo menos um modelo com `ollama pull llama3`.

* **Para uso local (mesma máquina):**
  1. Inicie o servidor Ollama (o serviço é iniciado automaticamente após a instalação no Windows).
  2. A URL padrão já está configurada como `http://localhost:11434` — **nenhuma alteração é necessária**.
  3. Nas configurações do plugin (**Settings → Ollama Local/Network Settings**), confirme que a URL está como `http://localhost:11434`.
  4. Selecione **Ollama** no combo de provedores do chat.

* **Para uso em rede (servidor remoto):**
  1. Certifique-se que o Ollama está rodando no servidor remoto com escuta em todos os endereços. Defina a variável de ambiente `OLLAMA_HOST=0.0.0.0` no servidor antes de iniciar o serviço.
  2. Nas configurações do plugin (**Settings → Ollama Local/Network Settings**), defina a URL para o endereço IP ou hostname do servidor. Exemplo: `http://192.168.1.100:11434`.
  3. Certifique-se de que a porta `11434` está acessível no firewall da rede.
  4. Selecione **Ollama** no combo de provedores do chat.

> **Nota:** O plugin descobre automaticamente os modelos disponíveis no servidor Ollama via `/api/tags`. Se a conexão falhar, exibirá modelos padrão conhecidos como fallback.

> [!TIP]
> **Resolução de Erros de CORS no Ollama:** Caso o plugin encontre erros de conexão de origem cruzada (CORS) ao realizar requisições para um servidor Ollama remoto, certifique-se de definir a variável de ambiente `OLLAMA_ORIGINS=*` no servidor de hospedagem antes de iniciar o serviço do Ollama. Isso habilitará o tráfego a partir do componente WebView2 do Rad IA.

---

## 3. OpenAI API ou ChatGPT Pro

Em **Settings > Providers > OpenAI**, escolha uma das rotas:

- **API Key (BYOK)** envia por HTTP para a plataforma OpenAI API e usa sua cobrança e quota próprias.
- **ChatGPT Pro via Codex CLI** usa a sessão e a cota da conta ChatGPT/Codex. Clique em
  **Configure Codex CLI login**, confirme o cliente Codex em **CLI & MCP**, use **Start login** e
  execute **Diagnose** até o estado mostrar `authentication: ready`.

No compositor, **RadIA native** mantém histórico, contexto, RTK e orquestração no RadIA, usando o
Codex CLI apenas como transporte do provider. **Codex CLI direct** entrega o prompt diretamente ao
cliente externo. As duas rotas Codex compartilham o mesmo login. Configurações antigas de OAuth são
migradas automaticamente e nunca são enviadas a `api.openai.com`.

## 4. Guia de Obtenção de Chaves de API por Provedor

Insira as chaves obtidas nas configurações do plugin (**Settings** no topo do painel de chat):

1. **Google Gemini (Recomendado)**
   * **Como obter:** Acesse o [Google AI Studio](https://aistudio.google.com/).
   * **Instruções:** Faça login, clique em **Create API Key** no painel lateral esquerdo, selecione o projeto e copie a chave.

2. **OpenAI ChatGPT**
   * **Como obter:** Acesse a [OpenAI Platform](https://platform.openai.com/).
   * **Instruções:** Faça login, acesse **API Keys** no menu lateral, clique em **Create new secret key** e copie o token gerado (iniciado em `sk-`).

3. **Anthropic Claude**
   * **Como obter:** Acesse o [Anthropic Console](https://console.anthropic.com/).
   * **Instruções:** Crie conta/login, acesse **API Keys**, clique em **Create Key** e copie a chave (iniciada em `sk-ant-`).

4. **DeepSeek**
   * **Como obter:** Acesse o [DeepSeek Console](https://platform.deepseek.com/).
   * **Instruções:** Faça login, acesse **API Keys**, clique em **Create API Key** e copie o token.

5. **Groq Cloud**
   * **Como obter:** Acesse o [Groq Console](https://console.groq.com/).
   * **Instruções:** Acesse **API Keys**, clique em **Create API Key** e copie o token (iniciado em `gsk_`).

6. **Azure OpenAI**
   * **Como obter:** Através do portal de gerenciamento da nuvem Microsoft Azure.
   * **Instruções:** Acesse o recurso do Azure OpenAI criado, vá na seção **Keys and Endpoint**, e copie o Endpoint e uma das chaves (Key 1 ou Key 2). Nas opções do Rad IA, configure a API Key, a URL do Endpoint, o Deployment Name mapeado para o modelo ativo e a versão da API (padrão: `2024-02-15-preview`).

7. **Alibaba Qwen**
   * **Como obter:** Acesse o console [DashScope/ModelStudio da Alibaba Cloud](https://bailian.console.aliyun.com/).
   * **Instruções:** Crie sua chave na seção de API Keys e copie o token.

8. **Mistral AI**
   * **Como obter:** Acesse o console do [Mistral AI Console](https://console.mistral.ai/).
   * **Instruções:** Acesse a seção **API Keys**, crie uma nova chave e copie o token gerado.

9. **AWS Bedrock**
   * **Como obter:** Através do Console da AWS (Amazon Web Services).
   * **Instruções:** Habilite o acesso aos modelos desejados (como Claude da Anthropic ou Llama da Meta) na console do Bedrock. Crie credenciais de acesso IAM no console da AWS para obter uma **Access Key ID** e uma **Secret Access Key**. Nas opções do Rad IA, configure esses dois campos, informe a **Região** da AWS onde o Bedrock está provisionado (ex: `us-east-1`) e, opcionalmente, forneça o **Session Token** se estiver utilizando credenciais temporárias do IAM.

   > [!IMPORTANT]
  > **Permissões IAM e Acesso a Modelos no Bedrock:**
   > * A chave de acesso IAM utilizada deve possuir políticas de segurança anexadas que permitam a execução das ações `bedrock:InvokeModel` e `bedrock:InvokeModelWithResponseStream`.
   > * Por padrão, a AWS Bedrock exige que você solicite acesso aos modelos individualmente no Console AWS da região desejada (menu *Model Access*). Certifique-se de que o acesso aos modelos que planeja utilizar (como Claude 3 da Anthropic) já foi solicitado e concedido antes de tentar conectá-los no Rad IA.

> **Nota sobre Provedores Dinâmicos e Corporativos:** Você também pode adicionar de forma dinâmica novos provedores compatíveis com a API OpenAI (incluindo o GitHub Copilot ou proxies de terceiros) salvando arquivos JSON em `%APPDATA%\RadIA\providers\`. Para mais detalhes, consulte o [Guia para Adição de Novos Provedores (docs/new_provider_guide.md)](new_provider_guide.md) e o [Guia de Configuração do GitHub Copilot (docs/copilot_proxy_guide.md)](copilot_proxy_guide.md).

---

## 4. Build e empacotamento para contribuidores

> Esta seção não é necessária para instalar a release. Os ZIPs mencionados abaixo são entradas
> internas verificáveis usadas para construir e testar o instalador visual; eles não são publicados.

O script `.\build.ps1` aceita os seguintes parâmetros:

* `-Install`: Compila, copia os arquivos binários para a pasta pública do Delphi, sincroniza os recursos WebView2 locais e cria o registro do pacote no Windows.
* `-Uninstall`: Desinstala o plugin de forma limpa apagando arquivos e chaves de registro.
* `-Release`: Ativa as otimizações do compilador Delphi e gera uma BPL menor.
* `-IDE64`: Compila e instala o plugin especificamente para a IDE de 64 bits do Delphi 13 Florence.
* `-DelphiVersion "<versao>"`: Opcional. Permite forçar o uso de uma versão específica do Delphi instalada no sistema (ex: `"23.0"`, `"37.0"`, `"Athens"`).
* `-Test`: Opcional. Compila e executa a suíte de testes unitários (DUnitX). Por padrão, os testes são omitidos do processo de compilação.
* `-Package`: Gera um arquivo ZIP autocontido em `Output\Packages`, com manifesto SHA-256,
  instalador, BPL, DCP, bridge MCP, WebView2Loader, recursos web, documentação e exemplo de extensão.

> [!TIP]
> **Suporte a Múltiplas Versões da IDE:** Se você possuir mais de uma versão do Delphi instalada no Windows e executar o script com `-Install` ou `-Uninstall` sem passar o parâmetro `-DelphiVersion`, o script listará automaticamente as versões instaladas encontradas no registro e exibirá um menu no console para que você selecione de forma interativa qual deseja utilizar.

> [!NOTE]
> **Autodetecção do DUnitX:** Se o parâmetro `-Test` for fornecido, o instalador verifica automaticamente se o framework DUnitX está instalado no Delphi selecionado. Se o DUnitX não for encontrado, o script exibirá um aviso no console, desativará a execução dos testes de forma automática e prosseguirá normalmente com a compilação e instalação do plugin principal.

### Pacotes internos de validação

Para gerar um pacote Release:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "23.0" -Release -Package
```

Para validar internamente o pacote extraído, feche todas as IDEs e execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File .\Scripts\Install-RadIA.Package.ps1 -DelphiVersion "23.0"
```

Para verificar o pacote sem instalar ou exigir o fechamento da IDE:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File .\Scripts\Install-RadIA.Package.ps1 `
  -DelphiVersion "23.0" -ValidateOnly
```

Para o Delphi 13 IDE64, gere e instale usando `-IDE64`. O instalador recusa uma versão ou arquitetura
diferente da registrada no manifesto. Também recusa paths absolutos, traversal, duplicidades,
arquivos ausentes, arquivos não manifestados, tamanhos divergentes e hashes SHA-256 inválidos.

Na IDE64, o package é registrado no subkey oficial
`HKCU\Software\Embarcadero\BDS\37.0\Known Packages x64`. A IDE Win32 continua usando
`Known Packages`; os binários permanecem separados em `Bpl` e `Bpl\Win64`.

O diretório interno `Output\Packages` também recebe `SHA256SUMS.txt` para a montagem da release.

Antes da publicação, execute a suíte positiva e negativa contra cada pacote:

```powershell
$version = (Get-Content package.json -Raw | ConvertFrom-Json).version
powershell.exe -ExecutionPolicy Bypass `
  -File .\scripts\Test-RadIA.Package.ps1 `
  -PackagePath ".\Output\Packages\RadIA-v$version-Delphi-23.0-Win32-Release.zip" `
  -DelphiVersion "23.0"
```

Para o pacote IDE64 do Delphi 13, acrescente `-IDE64`. A suíte confirma a validação íntegra e
também exige rejeição de arquivos extras, conteúdo corrompido, versão ou plataforma incompatível,
path traversal e caminhos duplicados no manifesto.

### Manutenção do pacote interno

O script incluído no pacote interno também executa manutenção reproduzível. Use `-PlanOnly` para revisar
todos os alvos sem alterar arquivos ou Registro:

```powershell
# Reparar binários, bridge e recursos mantendo configurações e dados
powershell -ExecutionPolicy Bypass `
  -File .\Scripts\Install-RadIA.Package.ps1 `
  -DelphiVersion "37.0" -IDE64 -Mode Repair

# Ver o plano de desinstalação; dados do usuário ficam preservados
powershell -ExecutionPolicy Bypass `
  -File .\Scripts\Install-RadIA.Package.ps1 `
  -DelphiVersion "37.0" -IDE64 -Mode Uninstall -PlanOnly

# Desinstalar esta arquitetura, preservando dados
powershell -ExecutionPolicy Bypass `
  -File .\Scripts\Install-RadIA.Package.ps1 `
  -DelphiVersion "37.0" -IDE64 -Mode Uninstall
```

Somente acrescente `-RemoveUserData` ao modo `Uninstall` quando também quiser remover
configurações, sessões, auditoria, conhecimento e caches em `%APPDATA%\RadIA`. O loader
`WebView2Loader.dll` da IDE é sempre preservado. Recursos web públicos só são removidos quando
nenhuma arquitetura do RadIA permanece instalada naquela versão do Delphi. Toda operação que
altera o sistema exige a IDE fechada.

A bridge MCP é instalada ao lado da BPL como `RadIA.MCP.Bridge.exe`. Clientes externos podem usar
esse executável sem depender da árvore de fontes ou do diretório `Output`.

Para discovery por processo, seleção entre várias IDEs, handshake, consentimento e diagnóstico,
consulte o [Guia de Integração MCP](mcp_integration_guide.md).

