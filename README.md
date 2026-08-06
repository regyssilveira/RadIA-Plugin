<div align="right">

[🇧🇷 Português](README.md) | [🇺🇸 English](README.en.md) | [🗺️ Roadmap](docs/roadmap.md) | [📋 Backlog](docs/backlog.md)

</div>

<p align="center">
  <img src="docs/images/radia_readme_banner-2.png" alt="Rad IA - Assistente de IA para Delphi IDE" width="100%" />
</p>


# Rad IA - Assistente de IA para Delphi IDE

**Rad IA** é um plugin assistente de IA avançado projetado especificamente para a IDE do Embarcadero Delphi (usando a Open Tools API). Ele se acopla diretamente à barra lateral da IDE, fornecendo uma interface de chat interativa e integração contextual profunda com o editor de código para acelerar o desenvolvimento, refatoração e depuração.

<p align="center">
  <img src="docs/images/radia_ui_mockup.png" alt="Rad IA Chat Panel Mockup" width="100%" />
</p>

---

### 1. Diretrizes de Desenvolvimento e Padrão de Linguagem

Este projeto adota regras claras de idioma e padrões de design para desenvolvedores humanos e assistentes de IA (LLMs/Co-pilots) que trabalham na base de código:

*   **Interações de IA e Humanos (AI & Human Interactions):**
    *   Toda conversa no chat, descrições de pull requests, tarefas e discussões de design devem ser conduzidas em **Português do Brasil (pt-BR)**.
    *   Mensagens de commit devem ser escritas em **Inglês (en-US)** seguindo a [Convenção de Mensagens de Commit](docs/commit_convention.md).
    *   Branches devem seguir o formato `<tipo>/<descricao-curta>` documentado na [Convenção de Nomes de Branch](docs/branch_convention.md).
*   **Código Fonte & Arquitetura (Source Code & Architecture):**
    *   O código fonte é **100% escrito em Inglês (en-US)**.
    *   Todos os identificadores (nomes de units, variáveis, classes, métodos, records, enums), parâmetros, estruturas de dados (JSON/XML) e comentários embutidos no código devem ser escritos exclusivamente em inglês, seguindo as convenções e padrões Pascal.
    *   Adoção rigorosa de **Clean Code**, **SOLID**, **DRY** e **KISS** com total isolamento em threads (thread-safety).
*   **Documentação Oficial (Documentation):**
    *   Disponível principalmente em Português ([README.md](README.md)) com tradução equivalente em Inglês ([README.en.md](README.en.md)).

### 2. Funcionalidades
*   **Chat Lateral Acoplável (Dockable):** Painel integrado à IDE com visual nativo do Delphi, tela inicial com atalhos rápidos, temas Dark/Light alinhados à IDE e janela de chat em HTML5/JS moderno (WebView2) com suporte a Markdown e realce de sintaxe Pascal.
*   **Suporte a Múltiplas IAs:** Permite usar chaves de API próprias (BYOK) para **Google Gemini**, **OpenAI ChatGPT**, **Azure OpenAI**, **Anthropic Claude**, **AWS Bedrock**, **GitHub Copilot**, **DeepSeek**, **Groq**, **Alibaba Qwen**, **Mistral AI**, **OpenRouter**, **LM Studio** e **Ollama** local.
*   **Integração Nativa com GitHub Copilot:** Suporte oficial para conectar-se diretamente aos servidores do GitHub Copilot (pessoal ou corporativo) na nuvem, com fluxo de autenticação do dispositivo embutido (OAuth Device Flow) e importação em um clique das credenciais ativas do VS Code.
*   **Histórico de Chat Persistente:** O histórico de conversas é salvo automaticamente localmente em formato JSON e pode ser carregado sob demanda na tela inicial, evitando restaurar chats que o usuário não quer abrir naquele momento.
*   **Atalhos e Histórico de Prompts:** Atalhos integrados para aumentar a produtividade: `Ctrl + Enter` para enviar prompts, `Enter` para quebra de linha, e uso das setas `↑` (para cima) e `↓` (para baixo) na área de digitação para navegar rapidamente pelo histórico dos prompts que já foram digitados e enviados.
*   **Ações de Contexto no Editor:** Clique com o botão direito em uma seleção ou na unit ativa para:
    *   *Explicar Código:* Analisar didaticamente a lógica.
    *   *Otimizar/Refatorar:* Melhorar a performance e aplicar princípios SOLID/Clean Code.
    *   *Otimizar Consulta SQL:* Analisar e otimizar queries SQL selecionadas ou na linha do cursor.
    *   *Create Example from Comment:* Gerar automaticamente o corpo de um método vazio a partir de um comentário em linguagem natural.
    *   *Gerar Testes Unitários:* Gerar estruturas prontas de testes usando DUnitX.
    *   *Localizar Bugs:* Buscar memory leaks, exceptions soltas e falhas de lógica.
    *   Quando não houver seleção, o Rad IA envia a unit inteira como contexto, preservando blocos Pascal formatados no chat e mantendo `/explain` separado dos fluxos de review.
*   **Comparador Visual Inteligente (Smart Diff):** Visualização de refatorações lado a lado
    (Original vs. Sugerido), com aceite ou rejeição por bloco. O botão **[Aplicar Selecionados]**
    substitui o trecho original com segurança e recusa a operação quando ele não é encontrado.
*   **Depurador de Compilação (Smart Build):** Integração com a aba *Messages* do Delphi. Clique com o botão direito nos erros de compilação da IDE para obter explicações e correções instantâneas.
*   **Documentação XML Automática:** Geração de comentários XML estruturados (`/// <summary>`) acima do cabeçalho de métodos para alimentar o Help Insight.
*   **Conversor de DTO e Modelos:** Geração automática e instantânea de classes (DTOs) e records Object Pascal a partir de JSON ou scripts de tabelas SQL (DDL), com suporte inteligente a DEXT ORM, TMS Aurelius, REST.Json e Vanilla Delphi.
*   **Comandos de Barra Customizáveis (Slash Commands):** Execução de ações rápidas digitando comandos no chat (ex: `/explain`, `/createprojectarch`). Permite cadastrar novos comandos dinâmicos associados a templates de prompts personalizados pelas opções do plugin.
*   **Biblioteca de Templates e Backup:** Interface para gerenciamento de prompts reutilizáveis com substituição inteligente de marcadores (`{code}`, `{specification}`) e diálogos para exportação e importação de backups (JSON) com suporte a mesclagem.
*   **Armazenamento Seguro de Chaves:** Credenciais criptografadas localmente via Windows DPAPI e salvas no Registro do Windows.
*   **Cancelamento e Bloqueio de Ações:** Botão de parada dinâmico redondo integrado na cápsula do prompt para interromper requisições assíncronas de forma segura. Durante o processamento, ações de sessão, botões da barra superior e troca de chats ficam bloqueados para preservar o contexto ativo.

*   **Respostas Concisas Configuráveis:** Opção geral para preferir respostas mais objetivas da IA, reduzindo explicações longas e economizando tokens sem impedir respostas detalhadas quando solicitadas explicitamente.
*   **Ferramentas Agentivas Seguras:** O chat executa ferramentas estruturadas do editor, projeto,
    build, Form Designer e debugger, com consentimento por risco e confinamento ao workspace.
*   **Loop Agentivo Observável:** `/agent run` executa objetivos em etapas com cartão de progresso,
    pausa, cancelamento, checkpoint e retomada sem transformar perguntas comuns em ações.
*   **Edição Revisável e Reversível:** Patches usam preview, hash-base e precondições, recusam
    conteúdo desatualizado e permitem reversão controlada.
*   **Servidor MCP Local:** A bridge stdio conecta clientes MCP à instância correta da IDE por
    discovery por PID, usando named pipe local e as mesmas políticas do chat.
*   **Conhecimento Local do Projeto:** Um índice reconstruível por projeto acompanha edição, save,
    rename e fechamento para oferecer busca contextual sem serviço externo.

### 2.1 Tabela Completa de Recursos (Features)

Para conferir o status de desenvolvimento, atalhos de teclado, categorias e todos os provedores integrados em detalhes, consulte o nosso:

👉 [**Catálogo Completo de Recursos (docs/features.md)**](docs/features.md)

Para aprender desde a configuração inicial até tools, MCP, Designer, debugger e conhecimento local:

👉 [**Tudo que o RadIA pode fazer**](docs/capabilities.md)

👉 [**Manual Completo do RadIA 2.0**](docs/user_manual.md)

Para navegar por toda a documentação funcional, operacional e técnica:

👉 [**Centro de Documentação do RadIA**](docs/README.md)

Referências rápidas:

- [Tudo que o RadIA pode fazer](docs/capabilities.md)
- [O que faz e quando usar cada ferramenta](docs/internal_tools_reference.md)
- [Todas as 95 ferramentas internas](docs/runtime_tool_catalog.md)
- [Todos os comandos de barra](docs/slash_commands.md)

### 2.2 Capacidades do RadIA em um relance

| Área | O que o RadIA pode fazer |
| :--- | :--- |
| **Chat e IA** | Usar providers, streaming, sessões, templates, slash commands e cancelamento. |
| **Editor** | Ler código, explicar, revisar, refatorar, otimizar SQL, localizar bugs e gerar testes. |
| **Edição segura** | Preparar preview, validar hash-base, aplicar e reverter patches sem sobrescrever mudanças. |
| **Geração** | Criar documentação XML, DTOs, models, métodos e estruturas de projetos Delphi. |
| **Workspace** | Consultar IDE, projeto, project group, módulos, arquivos e contexto ativo autorizado. |
| **Build** | Iniciar e cancelar builds, acompanhar estado e estruturar erros e warnings. |
| **Form Designer** | Consultar e alterar componentes, propriedades, eventos e layout com consentimento. |
| **Debugger** | Consultar estado, controlar execução, gerenciar breakpoints e avaliar expressões. |
| **Revisão inline** | Apresentar sugestões no editor e aplicar ou reverter alterações revisadas. |
| **Conhecimento local** | Indexar projetos, pesquisar símbolos e acompanhar edit, save, rename e close. |
| **MCP** | Expor tools a clientes locais por bridge stdio, named pipe e discovery por processo. |
| **Segurança** | Confinar paths, classificar risco, solicitar consentimento e manter auditoria sanitizada. |
| **Extensões** | Criar comandos, skills, aliases, journeys e workflows no Addon Studio, instalar pacotes e registrar tools pela API pública. |
| **Providers** | Integrar Gemini, OpenAI, Azure, Claude, Bedrock, Copilot, Ollama e outros backends. |
| **Compatibilidade** | Operar no Delphi 12 Win32 e no Delphi 13 Win32/IDE64. |

As ferramentas implementadas estão no
[Catálogo das 95 Ferramentas Internas](docs/runtime_tool_catalog.md). Contratos e evoluções
planejadas permanecem no [Catálogo Arquitetural](docs/tool_catalog.md).

### 3. Como Funciona e Arquitetura
O Rad IA é construído inteiramente em Object Pascal (Delphi) usando a **Open Tools API (OTA)** para interagir com o editor de código, gerenciamento de mensagens e detecção de temas da IDE.
A interface utiliza uma arquitetura híbrida:
1.  **VCL Nativa:** Gerencia o acoplamento da janela, a tela de configurações, ações de menus, gravação segura no registro e chamadas assíncronas.
2.  **Motor WebView2 (Edge):** Exibe as mensagens e respostas da IA utilizando HTML5, CSS e JS locais (Marked.js para Markdown e Prism.js para realce de sintaxe). A interface se adapta automaticamente ao tema da IDE (Light/Dark) e roda de forma fluida sem congelar a IDE.
3.  **Padrão MVP (Model-View-Presenter):** A lógica de apresentação e a coordenação de fluxos (como envio de mensagens, troca de provedores e salvamento de configurações) são totalmente desacopladas do formulário VCL e encapsuladas em Presenters (`TChatPresenter` e `TConfigPresenter`), permitindo que a interface gráfica atue como uma View passiva.
4.  **Abstração de Armazenamento (`ISettingsStorage`):** Para maior manutenibilidade e testabilidade, o mecanismo de persistência de opções foi abstraído. Em produção, os dados são salvos no Registro do Windows (`TRegistrySettingsStorage`), enquanto nos testes unitários são persistidos temporariamente em memória (`TMemorySettingsStorage`), garantindo isolamento total dos testes sem corromper as credenciais reais do desenvolvedor.
5.  **Plataforma Agentiva:** Um registry compartilhado pelo chat e MCP coordena ferramentas,
    workspace OTA, consentimento, auditoria, patches, build, Designer, debugger e conhecimento local.

Para uma compreensão aprofundada da infraestrutura do plugin, fluxos concorrentes assíncronos (streaming via background threads), ciclo de vida do WebView2 no encerramento da IDE e padrões de projeto aplicados, consulte o nosso:

👉 [**Guia de Arquitetura de Software (docs/architecture_guide.md)**](docs/architecture_guide.md)

Para entender a estrutura física dos arquivos de código-fonte, mapeamento de responsabilidade de cada unit e guias passo a passo de como fazer manutenções comuns, consulte o nosso:

👉 [**Guia dos Arquivos Fontes para o Desenvolvedor (docs/source_code_guide.md)**](docs/source_code_guide.md)

### 4. Requisitos do Sistema
*   **IDE:** Embarcadero Delphi 12 Athens ou Delphi 13, com IDE Win32 ou IDE64.
*   **OS:** Windows 10 / 11 (64-bit).
*   **Web Engine:** *Microsoft Edge WebView2 Runtime* instalado no sistema Windows (pré-instalado em versões modernas do Windows). **Importante:** A DLL `WebView2Loader.dll` correspondente à arquitetura da IDE deve estar presente na pasta `bin` da instalação do Delphi (ex: `C:\Program Files (x86)\Embarcadero\Studio\<versao>\bin`) ou no PATH do sistema.
### 5. Instalação e Configuração

O Rad IA 2.0 possui um **instalador visual único** para Delphi 12 Win32 e Delphi 13 Win32/IDE64.
A automação via PowerShell e a instalação manual continuam
disponíveis. Para o fluxo visual, assinatura e canal, consulte o
[guia do instalador](docs/visual_installer.md). Para compilação, registro e configuração de
providers, consulte:

O instalador automatizado também sincroniza os recursos locais do WebView2 em `%APPDATA%\RadIA\Web`
e limpa o cache local quando a IDE está fechada, evitando recursos JavaScript obsoletos após
atualizações.

👉 [**Guia de Instalação e Configuração Completo (docs/install_config.md)**](docs/install_config.md)

### 5.1 Adicionando um Novo Provedor de IA (Arquitetura Plug-in)

O Rad IA adota uma arquitetura de registro de provedores orientada a metadados (`TProviderRegistry`). Isso permite adicionar novos backends de IA de forma totalmente dinâmica e desacoplada. Para um tutorial passo a passo de como implementar sua classe de provedor e realizar o auto-registro, consulte o nosso:

👉 [**Guia para Adição de Novos Provedores (docs/new_provider_guide.md)**](docs/new_provider_guide.md)

### 5.2 Usando GitHub Copilot Remoto (Nativo - Fase 2) ou via Proxy Local (Fase 1)

O Rad IA suporta a integração direta e remota com o **GitHub Copilot** na nuvem, sem necessidade
de proxies locais. As opções incluem login integrado por PIN e importação das credenciais do
VS Code em um clique.

Caso prefira rodar um proxy local compatível com a API da OpenAI (Fase 1), isso também continua suportado através do registro de provedor dinâmico em arquivo JSON. Para mais detalhes, consulte:

👉 [**Guia de Configuração do GitHub Copilot (docs/copilot_proxy_guide.md)**](docs/copilot_proxy_guide.md)

### 5.3 Guias de Uso e Referência de Recursos

Para aprender a tirar o máximo proveito das funcionalidades do Rad IA no seu dia a dia de desenvolvimento, consulte os nossos manuais práticos e detalhados:

*   👉 [**Tudo que o RadIA pode fazer**](docs/capabilities.md): Mapa funcional completo do chat,
    editor, geração, agente, MCP, Designer, build, testes, debugger, Git e segurança.
*   👉 [**Manual Completo do RadIA 2.0**](docs/user_manual.md): Ponto de entrada com ativação das
    ferramentas agentivas, capacidades, exemplos, segurança, limitações e referências.
*   👉 [**Guia de Integração com Editor & Geração de Código (docs/user_guide_editor_generation.md)**](docs/user_guide_editor_generation.md): Ações contextuais de editor, comparador visual Smart Diff, documentação XML e criação de DTOs e projetos do zero.
*   👉 [**Guia de Diagnóstico de Erros & Análise de Código (docs/user_guide_diagnostics_analysis.md)**](docs/user_guide_diagnostics_analysis.md): Explicações e correções de erros com o Smart Build Debugger, decodificação de logs com o Assistente de Stack Trace e auditorias estáticas contra vazamento de memória.
*   👉 [**Guia do Painel de Chat & Gerenciamento de Sessões (docs/user_guide_chat_sessions.md)**](docs/user_guide_chat_sessions.md): Atalhos de digitação, histórico de prompts, múltiplas sessões persistentes e backups de templates.
*   👉 [**Guia das Ferramentas Agentivas**](docs/user_guide_agentic_tools.md): Consentimento,
    execução segura, patches, build e exemplos de solicitações.
*   👉 [**Guia de Integração MCP**](docs/mcp_integration_guide.md): Bridge stdio, discovery por PID,
    sessão MCP, segurança e diagnóstico.
*   👉 [**Guia do Conhecimento Local**](docs/user_guide_project_knowledge.md): Indexação, busca,
    persistência, privacidade e reconstrução.
*   👉 [**Guia do Designer e Debugger Agentivos**](docs/user_guide_designer_debugger.md):
    Componentes, propriedades, eventos, breakpoints, watches e controle.
*   👉 [**Solução de Problemas Agentivos**](docs/troubleshooting_agentic_platform.md): Diagnóstico de
    ferramentas, MCP, workspace e conhecimento.
*   👉 [**Convenção de Mensagens de Commit (docs/commit_convention.md)**](docs/commit_convention.md): Padrão de mensagens em inglês com prefixos como `feat`, `fix`, `docs`, `refactor` e outros.
*   👉 [**Convenção de Nomes de Branch (docs/branch_convention.md)**](docs/branch_convention.md): Padrão `<tipo>/<descrição>` com prefixos como `feat/`, `fix/`, `docs/`, `test/` e `chore/`.
*   👉 [**Processo de Finalização de Release (docs/release_process.md)**](docs/release_process.md): Checklist para atualizar versão, validar build, mergear `develop`/`main`, criar tag e limpar branches.
*   👉 [**Guia dos Arquivos Fontes para o Desenvolvedor (docs/source_code_guide.md)**](docs/source_code_guide.md): Mapeamento de unidades, fluxo passo a passo de manutenção comum e melhores práticas no compilador Delphi.

---

### 6. Estrutura do Repositório
```
PluginDelphiIA/
│
├── .github/                            # Configurações do GitHub e templates
│   ├── ISSUE_TEMPLATE/
│   │   ├── bug_report.md               # Template de relato de bug (PT)
│   │   ├── bug_report.en.md            # Template de relato de bug (EN)
│   │   ├── feature_request.md          # Template de sugestão de recurso (PT)
│   │   ├── feature_request.en.md       # Template de sugestão de recurso (EN)
│   │   └── config.yml                  # Configuração de seletor de issues
│   └── pull_request_template.md        # Template bilíngue de Pull Request
│
├── docs/                               # Documentação e recursos visuais
│   ├── images/                         # Capturas de tela e mockups da UI
│   ├── backlog.md / backlog.en.md      # Quadro Kanban e backlog de evolução técnica
│   ├── roadmap.md / roadmap.en.md      # Planejamento estratégico de milestones
│   ├── features.md / features.en.md    # Catálogo de recursos e matriz de compatibilidade
│   ├── install_config.md / .en.md      # Guia de instalação e chaves de API
│   ├── compliance.md / .en.md          # Avisos legais, privacidade e compliance
│   ├── new_provider_guide.md / .en.md  # Guia para adicionar novos provedores
│   ├── user_guide_*.md                 # Guias detalhados de uso (chat, editor, stack trace)
│   ├── mcp_integration_guide*.md       # Integração de clientes MCP com a IDE
│   ├── tool_*.md                       # Catálogo, extensões e segurança das ferramentas
│
├── RadIA.groupproj                     # Grupo de Projetos do Delphi
├── RadIA.dpk                           # Pacote Delphi de design-time (BPL)
├── RadIA.dproj                         # Configurações do projeto Delphi
├── RadIA.rc                            # Arquivo de recursos de compilação
│
├── Source/                             # Código-fonte principal do plugin
│   ├── Core/                           # Units centrais (interfaces, configurações, DTOs)
│   ├── Providers/                      # Clientes de API (Gemini, OpenAI, Claude, Ollama)
│   ├── Integration/                    # Integração com a Open Tools API da IDE (Hooks, Options)
│   ├── MCP/                            # Bridge MCP stdio para clientes externos
│   └── UI/                             # Telas, Frames e diálogos em VCL
│       └── Web/                        # Componentes locais do chat em HTML5/JS (WebView2)
│           └── vendor/                 # Bibliotecas de terceiros (Prism, Marked, diff2html)
│
├── Tests/                              # Testes de Integração e Unitários (DUnitX)
│   └── Source/                         # Units com as classes de testes
│
├── .editorconfig                       # Padrão de formatação e quebra de linhas do projeto
├── agents.md                           # Diretrizes e restrições para agentes de IA (LLMs)
├── build.ps1                           # Script PowerShell de build e instalação automatizada
├── eslint.config.js                    # Configurações do linter ESLint do Javascript
└── package.json                        # Gerenciador npm de dependências de linter e scripts
```

### 7. Termos de Uso e Compliance Corporativo

Para diretrizes de conformidade corporativa (LGPD/GDPR), privacidade de dados, segurança de credenciais com Windows DPAPI e avisos legais sobre código gerado por IA, consulte o nosso:

👉 [**Guia de Termos de Uso, Compliance e Privacidade (docs/compliance.md)**](docs/compliance.md)
