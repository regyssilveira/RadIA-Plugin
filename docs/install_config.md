# Guia de Instalação e Configuração — Rad IA

Este documento descreve detalhadamente o processo de instalação, compilação e configuração do plugin **Rad IA** para a IDE do Delphi.

---

## 1. Instalação

O Rad IA exige chaves de API válidas e ativas para funcionar com provedores de nuvem (Gemini, OpenAI, Claude, DeepSeek ou Groq) ou uma instância configurada do **Ollama** rodando localmente ou na rede.

O plugin pode ser instalado de duas formas:

### Opção A: Instalação Automatizada (PowerShell) - Recomendada

Esta opção compila o plugin, copia os binários para os diretórios públicos oficiais do Delphi e registra o plugin no Registro do Windows automaticamente. Se for necessário rodar a suíte de testes unitários (**DUnitX**), basta adicionar o parâmetro `-Test` ao comando.

Durante a instalação, o script também atualiza os recursos HTML/CSS/JS usados pelo WebView2 em `%APPDATA%\RadIA\Web` e limpa o cache local `%APPDATA%\RadIA\WebView2` quando a IDE está fechada. Isso evita que versões diferentes do Delphi carreguem arquivos JavaScript antigos após uma atualização.

1. Abra o console do Windows PowerShell.
2. Certifique-se de que a pasta `bin` da instalação do Delphi contendo o `dcc32` está presente no PATH do sistema.
3. Execute o comando na raiz do projeto de acordo com a arquitetura da sua IDE:
   * **Para a IDE padrão de 32 bits (Delphi 11 e 12)**:
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\build.ps1 -Install
     ```
   * **Para a IDE de 64 bits (Delphi 13 Florence)**:
     ```powershell
     powershell -ExecutionPolicy Bypass -File .\build.ps1 -Install -IDE64
     ```
4. Pronto! O plugin estará instalado e ativo no próximo startup da IDE.

### Opção B: Instalação Manual via IDE

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

## 3. Guia de Obtenção de Chaves de API por Provedor

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

## 4. Script de Build PowerShell (Opções Avançadas)

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

### Pacote de distribuição

Para gerar um pacote Release:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "23.0" -Release -Package
```

Depois de extrair o ZIP, feche todas as IDEs e execute o instalador incluído:

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

O diretório `Output\Packages` também recebe `SHA256SUMS.txt` com o hash de cada ZIP disponível.

Antes da publicação, execute a suíte positiva e negativa contra cada pacote:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File .\scripts\Test-RadIA.Package.ps1 `
  -PackagePath .\Output\Packages\RadIA-v2.0.0-Delphi-22.0-Win32-Release.zip `
  -DelphiVersion "22.0"
```

Para o pacote IDE64 do Delphi 13, acrescente `-IDE64`. A suíte confirma a validação íntegra e
também exige rejeição de arquivos extras, conteúdo corrompido, versão ou plataforma incompatível,
path traversal e caminhos duplicados no manifesto.

A bridge MCP é instalada ao lado da BPL como `RadIA.MCP.Bridge.exe`. Clientes externos podem usar
esse executável sem depender da árvore de fontes ou do diretório `Output`.

Para discovery por processo, seleção entre várias IDEs, handshake, consentimento e diagnóstico,
consulte o [Guia de Integração MCP](mcp_integration_guide.md).

