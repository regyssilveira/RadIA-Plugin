# Rad IA - Roadmap de Evolução

> A evolução para uma plataforma agentiva está detalhada no
> [Roadmap da Evolução Agentiva](agentic_roadmap.md). Esse roadmap complementa as versões de
> produto abaixo e define gates próprios de arquitetura, segurança e compatibilidade.

Este documento descreve o planejamento estratégico e a visão de futuro do assistente de IA **Rad IA**, focado em trazer produtividade e resolver as dores reais do desenvolvedor Delphi no seu dia a dia.

> [!NOTE]
> O Rad IA segue um modelo de desenvolvimento **open-source orientado à comunidade**.
> *   Para uma visualização detalhada das prioridades, estimativas de esforço e impacto de cada recurso, consulte a [Matriz de Priorização (feature_prioritization_matrix.md)](feature_prioritization_matrix.md).
> *   Para os detalhes técnicos das implementações passadas e pendentes (como nomes de classes, testes DUnitX aprovados e commits), consulte o [Backlog de Evolução Técnica (backlog.md)](backlog.md).

---

## 📅 Histórico de Versões Concluídas

### v2.3.0 — RTK interno e contexto recuperável

- compactação determinística de resultados de DUnitX, Git diff, build e conhecimento;
- armazenamento integral por sessão com recuperação por summary/range;
- orçamento de contexto, perfis operacionais e métricas sanitizadas;
- catálogo de 126 ferramentas e evidência mensurada de viabilidade.

Abaixo estão listadas as conquistas e os valores entregues em cada versão já lançada do plugin:

### Plataforma agentiva segura — concluída

O RadIA evoluiu do chat multi-provider para uma plataforma integrada à IDE com registry de
ferramentas, workspace OTA, consentimento, auditoria, patches reversíveis, build, MCP, Form
Designer, debugger, revisão inline, conhecimento local e extensões versionadas.

A matriz vigente é validada no Delphi 12 Win32 e no Delphi 13 Win32/IDE64. Consulte o
[roadmap agentivo](agentic_roadmap.md) e a [auditoria de conclusão](agentic_completion_audit.md).

### v2.2.2 — Jornadas DEXT e experiência orientada

- jornadas DEXT minimalistas e com controllers, com coleta conversacional de requisitos;
- `/help` integrado, exemplos preenchíveis no menu `/` e links abertos no navegador padrão;
- configuração reorganizada por provider, CLI e MCP, com páginas-pai apenas descritivas;
- descoberta de modelos compatíveis por transporte e limite de tokens realmente opcional.

### v2.2.1 — Diagnóstico e experiência guiada

- `/doctor` estruturado com prontidão, recomendações e próxima ação;
- `/status` sanitizado e filtrável para provider, agente, CLI, MCP, segurança, editor e tools;
- instalação, autenticação e recuperação de CLI/MCP guiadas por consentimento;
- documentação reorganizada por tarefa e catálogo operacional de 124 ferramentas;
- estabilidade do debugger, atualização dinâmica de modelos e melhorias de layout e hints.

<details>
  <summary><b>📦 v0.0.29 — Correção de Seleção do Editor e Bloqueio do Gemini OAuth (Concluído)</b></summary>

  *   **Valor Entregue**: Resolução de problemas críticos na detecção e reset de seleção ativa do editor de código no Delphi, tradução do indicador de digitação no chat para o inglês padrão e bloqueio preventivo temporário do fluxo Google Gemini OAuth por pendência de aprovação de segurança da Google.
  *   **Destaques**:
      *   Correção na detecção de seleção de texto usando `LView.Block` ao invés de `LEditBuffer.EditBlock` para refletir de forma precisa a ausência de seleção visível e acionar o fallback de explicar a unit inteira.
      *   Reset e colapso programático do bloco de seleção do editor (`LEditBlock.Reset` e `LView.Position.Move`) após inserção de código automático para evitar que textos recém-gerados continuem marcados como selecionados.
      *   Tradução da mensagem do indicador moderno de digitação no chat de `"Pensando..."` para `"Thinking..."` para total aderência às diretrizes de idioma do código-fonte e interface (en-US).
      *   Implementação de barreiras preventivas de login e envio de prompts usando o Gemini no modo OAuth, exibindo avisos claros instruindo a usar API Keys devido ao status de verificação pendente, omitindo qualquer menção a "Web Login" (removido).
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.29)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.28 — Adapter da Open Tools API e Testes de Rede (Concluído)</b></summary>

  *   **Valor Entregue**: Desacoplamento da Open Tools API através de um novo design com Adapter (`IRadIAEditorAdapter`), permitindo a automação de testes do buffer do editor offline e a introdução de testes de rede contra travamentos na IDE do Delphi.
  *   **Destaques**:
      *   Criação de `IRadIAEditorAdapter` e `TRadIAOTAEditorAdapter` para isolar o acoplamento do plugin com a IDE do Delphi.
      *   Implementação de testes com `TMockEditorAdapter` que simula buffers de texto e ações de inserção, seleção, e substituição offline.
      *   Testes de resiliência a lentidão de rede e streaming assíncrono abortado via `TestProviderBase_CancellationAndTimeout`.
      *   Resolução de problemas de concorrência e file-locking no Windows ao manusear templates.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.28)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.27 — Resolução de Code Smells e Ampliação de Testes (Concluído)</b></summary>

  *   **Valor Entregue**: Eliminação completa de pendências técnicas (code smells) no SonarQube e estabilização de regressões através do aumento da cobertura de testes unitários automatizados nos provedores de inteligência artificial (atingindo 83.9% de cobertura geral e 81.0% em código novo), resultando na aprovação definitiva do Quality Gate.
  *   **Destaques**:
      *   Correção de violações de convenções de nomenclatura Pascal e remoção de imports inativos na suíte de testes.
      *   Criação de testes síncronos e isolados via RTTI para as propriedades de URLs e filtros de modelos dos provedores (OpenAI, DeepSeek, Groq, Mistral, Qwen, OpenRouter, AzureOpenAI e LMStudio).
      *   Cobertura robusta de descoberta de modelos no Gemini (`FetchAvailableModelsAsync`) sob sucesso, falha e chaves vazias.
      *   Testes de decodificação de múltiplos formatos de payloads de erro JSON da API base dos provedores.
      *   Cobertura total (100%) nas classes de dados fundamentais `RadIA.Core.Types` e `RadIA.Core.ChatMessage`.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.27)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.26 — Ícones de Provedores Visuais e Reformulação Arquitetural (Concluído)</b></summary>

  *   **Valor Entregue**: Interface do plugin com estética premium integrada com logotipos oficiais das IAs, somada a uma profunda reforma na arquitetura interna com inversão de controle (IoC), injeção de dependências (DIP) e isolamento de I/O nos testes para máxima estabilidade, segurança e testabilidade offline.
  *   **Destaques**:
      *   Substituição do Robô genérico por logos SVGs oficiais no chat, dropdown customizado de provedores na barra superior, e avatares dinâmicos coloridos por provedor.
      *   Introdução de container de IoC (`TRadIAContainer`) thread-safe e injeção de dependência para serviços e utilitários.
      *   Isolamento e abstração da API da IDE (`IRadIAIDEAdapter`), permitindo mockagem completa em testes unitários.
      *   Blindagem absoluta contra apagamento acidental de dados locais de produção através de injeção de diretórios temporários baseados em GUIDs nos testes.
      *   Correção de colagem de código em uma única linha no editor com o normalizador centralizado `IRadIATextNormalizer` (CRLF).
      *   Novos serviços desacoplados: cliente HTTP centralizado (`IRadIAHttpClient`), decodificador de erros de APIs (`IRadIAErrorDecoder`) e dicionário de localização (`IRadIALocalizer`).
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.26)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.25 — Web Login Simplificado e Apply Changes Seguro (Concluído)</b></summary>

  *   **Valor Entregue**: Login web mais direto e confiável para ChatGPT/Gemini, com confirmação explícita de sessão já autenticada, e aplicação de diffs mais segura no editor para evitar duplicação de código.
  *   **Destaques**: abertura da página oficial do provedor com a pasta de dados correta, fechamento automático quando a sessão já está logada, identificação visual como **Web Login** em vez de nome de modelo incorreto e substituição OTA baseada no bloco original quando a seleção do editor se perde.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.25)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.24 — Delphi Compiler & OS Warning Scanner e Proteção de Menus (Concluído)</b></summary>

  *   **Valor Entregue**: Auditoria estática inteligente de warnings de compilação e vazamento de handles visando a robustez do software, aliado à correção definitiva de travamentos de code folding (Elision) na IDE do Delphi 13.
  *   **Destaques**: Ação contextual de scan no editor, comando de barra `/scanwarnings`, perfil dedicado `rpScanWarnings` e proteção estrutural contra reentrância de hooks no menu do editor.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.24)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.23 — Smart SQL Optimizer no Editor (Concluído)</b></summary>

  *   **Valor Entregue**: Otimização inteligente e contextual de strings de consultas SQL diretamente no editor da IDE, sem sair do fluxo de trabalho.
  *   **Destaques**: Nova ação de contexto no editor, comando de barra `/sqloptimize`, parametrização dedicada de temperatura baixa (`0.1`) e alta quantidade de tokens no orquestrador do serviço, e suite de testes unitários DUnitX.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.23)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.22 — Prompts Concisos e Preservação de Quebras no Editor (Concluído)</b></summary>

  *   **Valor Entregue**: Respostas mais objetivas e menor gasto de tokens, com os menus do editor preservando a formatação Pascal enviada ao chat.
  *   **Destaques**: blocos `pascal` preservados em slash commands, templates padrão mais sucintos, nova opção **Prefer concise AI responses** persistida nas configurações e cobertura DUnitX para o fluxo de pré-processamento.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.22)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.21 — Create Example from Comment (Concluído)</b></summary>

  *   **Valor Entregue**: Menos fricção para transformar intenção em código Delphi, permitindo escrever a assinatura do método e um comentário de intenção para o Rad IA gerar o corpo automaticamente.
  *   **Destaques**: detecção do método pelo cursor, suporte a comentários `//`, `{ ... }` e `(* ... *)`, inserção direta abaixo do comentário, validações para evitar sobrescrever lógica existente e compatibilidade com Web Login.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.21)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.20 — Smart Diff com Web Login e Persistência de Configuração (Concluído)</b></summary>

  *   **Valor Entregue**: Refatorações pelo Smart Diff mais confiáveis com provedores Web Login, preservando a formatação do código e evitando regressões de configuração.
  *   **Destaques**: Smart Diff sem exigência indevida de API key em Web Login, resposta em bloco `pascal` único, preservação de indentação no bridge, isolamento dos testes de configuração do registro real e hook do editor menos intrusivo ao criar novos projetos.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.20)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.19 — Ações do Editor com Fallback para Unit Ativa (Concluído)</b></summary>

  *   **Valor Entregue**: Menos fricção no uso diário das ações do editor, permitindo acionar comandos mesmo sem selecionar código manualmente.
  *   **Destaques**: fallback automático para a unit ativa, Smart Diff substituindo o buffer inteiro quando apropriado, leitura do editor em blocos e hook contextual mais estável no Delphi 13 ao criar novos projetos.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.19)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.18 — Polimento de UX do Chat, Web Login e Marca Rad IA (Concluído)</b></summary>

  *   **Valor Entregue**: Experiência mais clara e previsível no uso diário do chat, com abertura mais suave, tema alinhado à IDE, sessões protegidas durante processamento e login web mais orientativo.
  *   **Destaques**: tela inicial com atalhos rápidos, histórico sob demanda, Mountain Mist tratado como light, múltiplos chats sem reordenação ao selecionar, bloqueio de ações durante respostas, generator em tela cheia, web login com fallback visual e marca exibida como **Rad IA**.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.18)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.17 — Menu do Editor e Chat WebView2 Estáveis (Concluído)</b></summary>

  *   **Valor Entregue**: Experiência mais previsível ao usar ações do editor: código selecionado chega ao chat formatado, `/explain` não cai mais em review e Delphi 12/13 carregam os recursos web atualizados.
  *   **Destaques**: blocos Pascal renderizados em mensagens do usuário, template nativo **Explain Code**, migração de slash command legado, cache busting de `chat.js` e instalador sincronizando `%APPDATA%\RadIA\Web`.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.17)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.16 — MVP, Storage Abstraction e Robustez do Editor (Concluído)</b></summary>

  *   **Valor Entregue**: Base interna mais testável e estável, com telas desacopladas em MVP e menu contextual do editor mais confiável no Delphi 12/13.
  *   **Destaques**: `TChatPresenter`, `TConfigPresenter`, `ISettingsStorage`, storage em memória para testes, hook do editor via notifiers OTA e submenu **Rad IA** no topo do menu contextual.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.16)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.15 — Templates em Duas Camadas e Overlays (Concluído)</b></summary>

  *   **Valor Entregue**: Segurança de que novas atualizações do plugin trazem prompts novos da comunidade sem sobrescrever ou apagar suas personalizações locais.
  *   **Destaques**: Segregação de templates nativos e de usuário, indicador visual de origem no menu de configurações e opção de "Restaurar Padrão".
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.15)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.14 — Templates Dinâmicos e Backup (Concluído)</b></summary>

  *   **Valor Entregue**: Liberdade para criar comandos personalizados barra (`/`) associados a prompts repetitivos e facilidade para migrar e compartilhar sua biblioteca de templates de IA entre computadores.
  *   **Destaques**: Customização dinâmica total de comandos barra, backup em JSON com controle de importação (mesclar ou sobrescrever) e template nativo de Clean Architecture Delphi.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.14)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.13 — Geração de Projetos Delphi Inteiros via Prompt (Concluído)</b></summary>

  *   **Valor Entregue**: Velocidade extrema no início de novas ideias e microsserviços. A IA cria a estrutura completa de pastas e arquivos e os carrega diretamente na sua IDE prontos para uso.
  *   **Destaques**: Gerador transacional de arquivos, painel visual com design *glassmorphism* no chat e abertura automática do projeto gerado na IDE do Delphi.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.13)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.12 — Provedor AWS Bedrock e Estabilização (Concluído)</b></summary>

  *   **Valor Entregue**: Integração com os modelos de ponta da Amazon (Anthropic Claude, Llama 3) em ambientes corporativos rígidos que demandam segurança em nuvens AWS.
  *   **Destaques**: Suporte nativo ao AWS Bedrock, assinador criptográfico SigV4 e parser de streaming binário.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.12)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.11 — Provedores Azure, Qwen e Mistral AI (Concluído)</b></summary>

  *   **Valor Entregue**: Expansão do catálogo de IAs nativas de ponta do plugin para atender a políticas de compliance de TI internas de diferentes empresas.
  *   **Destaques**: Suporte nativo para Azure OpenAI, Alibaba Qwen 2.5 e Mistral AI, com abas dedicadas e atalhos na tela de opções da IDE.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.11)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.10 — Suporte Nativo ao GitHub Copilot (Concluído)</b></summary>

  *   **Valor Entregue**: Autenticação oficial e simplificada com a IA de desenvolvimento mais popular do mundo diretamente do painel do Rad IA, sem a necessidade de proxies locais.
  *   **Destaques**: Suporte nativo ao GitHub Copilot na nuvem, fluxo de login interativo por PIN do dispositivo e importação do token ativo do VS Code em um clique.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.10)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.9 — Suporte Multi-IDE e Acentuação de Build (Concluído)</b></summary>

  *   **Valor Entregue**: Facilidade de implantação em computadores de desenvolvimento que rodam múltiplas versões da IDE do Delphi simultaneamente (ex: Alexandria e Athens).
  *   **Destaques**: Instalador PowerShell interativo com autodescoberta do registro do Windows e correções de encodings de consoles locais.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.9)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.8 — Provedor Local LM Studio e Estabilidade (Concluído)</b></summary>

  *   **Valor Entregue**: Autonomia de uso com modelos de IA locais e offline rodando em servidores corporativos ou computadores locais pelo LM Studio.
  *   **Destaques**: Provedor nativo do LM Studio e aba dedicada Claro/Escuro de configurações.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.8)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.7 — System Prompt Otimizado (Concluído)</b></summary>

  *   **Valor Entregue**: Respostas da IA muito mais rápidas, enxutas e focadas estritamente em código Delphi Object Pascal de qualidade, evitando explicações verborrágicas desnecessárias.
  *   **Destaques**: System Prompt otimizado de fábrica e respeito a preferências e customizações salvas pelo usuário.
</details>

<details>
  <summary><b>📦 v0.0.6 — Provedores via JSON e Suporte ao Copilot (Concluído)</b></summary>

  *   **Valor Entregue**: Extensibilidade imediata. Permite cadastrar qualquer nova IA de mercado compatível com a API da OpenAI apenas salvando um arquivo JSON, sem necessitar reinstalar ou compilar o plugin.
  *   **Destaques**: Provedores dinâmicos configuráveis por JSON local e conexões iniciais de proxies do Copilot.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.6)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.5 — Desacoplamento e Estabilização de UI (Concluído)</b></summary>

  *   **Valor Entregue**: Melhoria na robustez interna das opções da IDE e remoção definitiva de problemas de interface.
  *   **Destaques**: Migração interna para identificadores dinâmicos baseados em strings e correções na renderização de abas sob o menu da IDE.
</details>

<details>
  <summary><b>📦 v0.0.4 — Produtividade Avançada e Análise Estática (Concluído)</b></summary>

  *   **Valor Entregue**: Automatização de tarefas manuais repetitivas (como criar classes DTO) e análise rápida de pilha de erros no código ativo.
  *   **Destaques**: Conversor DTO (JSON/SQL para Pascal), Assistente de Stack Trace em relatórios de exceções, análise estática de memory leaks e popup visual flutuante de sugestões barra (`/`).
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.4)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.3 — Estabilidade de Runtime (Concluído)</b></summary>

  *   **Valor Entregue**: Garantia de que o plugin rode em background na IDE sem causar travamentos, vazamentos de memória da BPL ou Access Violations durante o uso diário.
  *   **Destaques**: Barramento central de registro dinâmico de IAs e ciclo de vida robusto com threads secundárias.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.3)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.2 — Múltiplas Sessões e Gestão de Consumo (Concluído)</b></summary>

  *   **Valor Entregue**: Organização das conversas por projetos e controle direto sobre os custos das chaves de API.
  *   **Destaques**: Sidebar de chat de múltiplas sessões persistentes, controle local de orçamento de tokens mensal na barra de status e integração com OpenRouter.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.2)](backlog.md).*
</details>

<details>
  <summary><b>📦 v0.0.1 — Lançamento Inicial (Concluído)</b></summary>

  *   **Valor Entregue**: A IA acoplada de forma nativa e fluida à IDE do Delphi, trazendo respostas incrementais rápidas e atalhos na tela.
  *   **Destaques**: Chat lateral VCL integrado com Edge WebView2, suporte a 6 provedores, streaming SSE, histórico local, atalhos contextuais no editor de código, comparador visual Diff de alterações, Smart Build Debugger e documentação XML automática.
  *   👉 *Veja os detalhes de implementação e testes no [Backlog Técnico (v0.0.1)](backlog.md).*
</details>

---

## Inventário futuro sem versão comprometida

Os números `0.1.0`, `0.2.0` e `0.3.0+` pertenciam ao planejamento anterior à linha 2.x e não são
mais versões-alvo. Após a versão 2.2.2, cada item abaixo precisa ser selecionado e detalhado em um
novo goal antes de receber versão.

### Pendências funcionais confirmadas

*   **Revisão Automática no Save**: o evento de save existe, mas ainda não dispara revisão em background.
*   **Diagnóstico multiarquivo de traces e logs de exceção**: `/stacktrace` existe, mas ainda não resolve automaticamente todas as units nem extrai dumps estruturados de MadExcept/EurekaLog.
*   **Otimizador de Cláusula Uses (Clean Uses)**: ainda não implementado.
*   **Gerador de Mocks para Testes**: ainda não implementado como jornada própria.
*   **Swagger/OpenAPI para projetos existentes**: novos projetos DEXT foram atendidos na 2.2.2; a leitura de rotas Horse/RAD Server existentes permanece pendente.
*   **Análise Semântica DFM vs PAS**: mutações atuais preservam consistência, mas a auditoria de órfãos permanece pendente.
*   **Smart Migrate**, **painel de cache** e **geração de API.md**: permanecem pendentes e não priorizados.

### Capacidade absorvida

*   **Histórico de Refatorações Aplicadas**: absorvido na 2.0.0 por patches reversíveis, timeline, auditoria e checkpoints.

### Oportunidades estratégicas
*   **Conversão BDE/ADO/dbExpress ➔ DEXT com FireDAC**: Assistente interativo de migração estrutural que converte componentes visuais obsoletos do DFM e reescreve a lógica do código Pascal para o DEXT ORM com FireDAC.
*   **Decompositor de Formulários (Code-Behind Extractor)**: Extração cirúrgica de lógica de negócios acoplada nos eventos de cliques de telas para classes de serviços limpas separadas.
*   **Assistente de Threads e PPL**: Auxiliar a reescrever rotinas pesadas síncronas para rodarem de forma assíncrona segura e sem travar a interface da aplicação.
*   **Internacionalização Automática (i18n Wizard)**: a infraestrutura de localização existe; falta o wizard para projetos do usuário.

### Fora do escopo

*   **Lazarus / Free Pascal**: descartado; o suporte vigente permanece Delphi 12 e 13.
