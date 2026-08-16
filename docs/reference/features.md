# Recursos e Funcionalidades do Rad IA

Este é o inventário detalhado das funcionalidades integradas ao **RadIA**, com categoria, descrição
e status. Para descobrir o produto por área e acessar os respectivos guias de uso, comece pela
referência canônica [Tudo que o RadIA pode fazer](capabilities.md).

Este inventário complementa o mapa de capacidades; ele não o substitui como ponto de entrada para
usuários. A disponibilidade exata de tools depende da instalação e do contexto atuais e deve ser
consultada com `/tools`.

---

## Tabela Completa de Recursos

As ferramentas de geração segura também incluem **Geração de `API.md`** revisável e **Gerador de mocks** para
interfaces indexadas. Ambos usam preview determinístico, recusam sobrescrita e exigem consentimento para aplicar
ou registrar arquivos no projeto.

O diagnóstico inclui **Trace multiarquivo e importadores MadExcept/EurekaLog**, com confiança e navegação por
frame, sem modificar o projeto.

O **Painel de gerenciamento do cache** mostra uso do cache local de respostas e oferece limpeza seletiva ou
completa mediante confirmação, explicando que as entradas serão reconstruídas sob demanda.

A **Revisão automática ao salvar** pode ser habilitada no menu RadIA. A análise limitada ocorre em background e
publica achados descartáveis na revisão inline, sem modificar o arquivo salvo.

O **Clean Uses** prepara uma preview semântica conservadora, preserva cláusulas condicionais, units com
initialization/finalization e imports fora do projeto, e usa os patches reversíveis existentes para aplicação.

| Recurso | Categoria | Descrição | Status |
| :--- | :--- | :--- | :--- |
| **Smart SQL Optimizer** | Integração | Analisador e otimizador de strings de consultas SQL integrado diretamente ao menu contextual do editor do Delphi. | ✅ Concluído |
| **Scan Compiler & OS Warnings** | Integração | Varredura de código em busca de warnings do compilador Delphi, problemas de thread-safety e vazamentos de recursos (handles GDI). | ✅ Concluído |
| **Chat Lateral Acoplável** | Chat UX | Painel integrado à IDE rodando WebView2 com suporte a Markdown e Pascal highlight. | ✅ Concluído |
| **Entrada Orientada a Objetivos** | Chat UX | Tela inicial que começa por entender, corrigir, criar ou depurar, mantém a plataforma completa visível e prepara o pedido sem envio automático. | ✅ Concluído |
| **Tema Integrado à IDE** | Chat UX | Adaptação Dark/Light ao tema do Delphi, incluindo Mountain Mist como light, scrollbar e blocos de código consistentes. | ✅ Concluído |
| **Atalhos de Teclado** | Chat UX | Atalho `Ctrl + Enter` para enviar prompts e `Enter` para quebra de linha. | ✅ Concluído |
| **Persistência de Layout** | Chat UX | Salvamento e restauração automática de tamanho/posição flutuante e visibilidade no startup. | ✅ Concluído |
| **Streaming de Respostas** | Chat UX | Respostas incrementais token a token (SSE) nos provedores OpenAI, Gemini, Claude e Ollama. | ✅ Concluído |
| **Múltiplas Sessões de Chat** | Chat UX | Criação, renomeação, exclusão e isolamento de conversas em barra lateral retrátil (bloqueadas durante requisições ativas). | ✅ Concluído |
| **Histórico de Chat Persistente** | Chat UX | Salvamento automático em JSON e restauração sob demanda das sessões anteriores de chat. | ✅ Concluído |
| **Histórico de Prompts (↑/↓)** | Chat UX | Navegação rápida pelos prompts enviados anteriormente usando as setas do teclado. | ✅ Concluído |
| **Cancelamento de Requisições** | Chat UX | Permite abortar chamadas ativas de IA de forma assíncrona com botão stop e bloqueia ações de sessão durante processamento. | ✅ Concluído |
| **Fila de Continuações** | Chat UX | Permite escrever, enfileirar, editar ou limpar até cinco mensagens durante uma resposta, sem antecipá-las no histórico. | ✅ Concluído |
| **Exportação de Conversa** | Chat UX | Botão para salvar histórico nos formatos Markdown (.md) ou HTML autônomo com Prism.js. | ✅ Concluído |
| **Templates de Prompt** | Chat UX | Biblioteca de templates rápidos de prompt com substituição de código e o comando `/template`. | ✅ Concluído |
| **Slash Commands Dinâmicos** | Chat UX | Mapeamento dinâmico de templates para comandos de barra (ex: `/createprojectarch`), sincronizados e autocompletados no WebView2. | ✅ Concluído |
| **Doctor e Status do RadIA** | Diagnóstico | `/doctor` verifica prontidão e recomenda a próxima ação; `/status` inventaria configuração e disponibilidade sem expor credenciais. | ✅ Concluído (v2.2.1) |
| **Assistente CLI/MCP** | Integração | Detecta, explica, solicita consentimento, instala ou configura, valida e oferece fallback manual completo sem exigir reinício da IDE. | ✅ Concluído (v2.2.1) |
| **Rotas explícitas de execução** | Chat UX | Separa modo Chat/Agent, orquestração RadIA native e CLI direto, mostrando rota, transporte e credencial efetivos. | ✅ Concluído (v2.3.1) |
| **Recomendação por intenção** | Chat UX | Reconhece criação, build, testes e diagnóstico localmente; permite confirmar, revisar ou continuar no chat e mantém somente contadores locais sanitizados. | ✅ Concluído |
| **Painel de problemas unificado** | Chat UX | Reúne achados de build, DUnitX, cobertura, memória, DFM/PAS, threads e revisão com filtros, navegação e ações revisáveis. | ✅ Concluído |
| **Validação unificada de código Delphi** | Inteligência | Consolida regras nativas, Check do compilador, DelphiLint isolado e Sonar em achados navegáveis; quick fixes viram previews consentidos e reversíveis. | ✅ Concluído |
| **ChatGPT Pro via Codex CLI** | Provedor | Usa a sessão e a cota ChatGPT/Codex tanto como transporte do provider nativo quanto na execução CLI direta; API Key permanece separada. | ✅ Concluído (v2.3.1) |
| **Cópia universal de texto** | Chat UX | Oferece cópia para respostas, JSON, resultados de tools e demais payloads textuais, preservando o conteúdo original. | ✅ Concluído (v2.3.1) |
| **Ajuda integrada** | Chat UX | `/help` resume capacidades e abre os guias públicos no navegador padrão. | ✅ Concluído (v2.2.2) |
| **Jornadas DEXT conversacionais** | Projetos | Coleta requisitos ausentes em várias mensagens, preserva o contexto e gera APIs minimalistas ou com controllers. | ✅ Concluído (v2.2.2) |
| **Skills e Templates Declarativos** | Extensibilidade | Manifesto schema 2 com hot reload, autocomplete e permissão mínima `chat.prompt`. | ✅ Concluído |
| **Aliases Declarativos de Tools** | Extensibilidade | Schema 3 registra aliases seguros no chat e MCP, herdando risco, schemas e consentimento da tool interna. | ✅ Concluído |
| **Workflows Declarativos** | Extensibilidade | Schema 5 encadeia até 16 tools internas com risco herdado, limites e policy central por etapa, sem shell arbitrário. | ✅ Concluído |
| **Recursos Declarativos Empacotados** | Extensibilidade | Schema 6 e envelope `.radiaext` v3 transportam referências, conhecimento, templates e assets com hash, rollback e remoção transacional. | ✅ Concluído |
| **Captura Visual Runtime** | Debugger | Captura a janela autorizada antes e depois de um cenário real, sanitiza imagens e liga a timeline aos eventos efetivos da sessão. | ✅ Concluído |
| **Renderização de Código do Editor no Chat** | Chat UX | Prompts enviados pelo menu do editor preservam blocos fenced Markdown com realce Pascal também em mensagens do usuário. | ✅ Concluído |
| **Backup de Templates** | Chat UX | Exportação e importação transacional em JSON de templates com validação estrutural de esquema e opção de mesclagem na UI. | ✅ Concluído |
| **Google Gemini** | Provedor | Integração BYOK com descoberta dinâmica e fallback documentado de modelos atuais. | ✅ Concluído |
| **OpenAI ChatGPT** | Provedor | Integração por API Key e ChatGPT Pro via Codex, com descoberta dinâmica e fallback atual. | ✅ Concluído |
| **Login Híbrido (Web Login)**| Provedor | Permite alternar entre BYOK (API Keys) ou Login Web (Plus/Pro) para OpenAI e Gemini. | ❌ Removido (v0.0.29) |
| **Anthropic Claude** | Provedor | Integração BYOK com descoberta dinâmica e fallback documentado de modelos atuais. | ✅ Concluído |
| **DeepSeek** | Provedor | Suporte nativo aos modelos DeepSeek Chat e Reasoning via chaves próprias (BYOK). | ✅ Concluído |
| **Groq** | Provedor | Suporte nativo aos modelos Llama, Mixtral e Gemma na nuvem ultrarrápida da Groq via chaves próprias (BYOK). | ✅ Concluído |
| **OpenRouter** | Provedor | Suporte nativo ao OpenRouter com streaming SSE, carregamento de modelos dinâmico e integração completa. | ✅ Concluído |
| **GitHub Copilot Nativo** | Provedor | Suporte oficial direto à nuvem do Copilot com Device Flow integrado e importação de chaves do VS Code em um clique. | ✅ Concluído |
| **Azure OpenAI** | Provedor | Suporte nativo ao Azure OpenAI para compliance de TI corporativo, com URL de endpoint, deployment name e versão da API configuráveis. | ✅ Concluído |
| **Alibaba Qwen** | Provedor | Suporte nativo aos modelos Alibaba Qwen (ModelStudio/DashScope) via chaves próprias (BYOK). | ✅ Concluído |
| **Mistral AI** | Provedor | Suporte nativo aos modelos Mistral AI (Codestral, Mistral Large) via chaves próprias (BYOK). | ✅ Concluído |
| **AWS Bedrock** | Provedor | Suporte nativo ao AWS Bedrock com assinatura SigV4, desfragmentador EventStream e autenticação segura (IAM/DPAPI). | ✅ Concluído |
| **Ollama Local/Rede** | Provedor | Integração com modelos locais open-source sem chaves pagas e autodescoberta de tags. | ✅ Concluído |
| **LM Studio** | Provedor | Suporte nativo ao LM Studio com streaming SSE, autodescoberta de modelos locais e URL customizável. | ✅ Concluído |
| **Custom Base URL** | Provedor | Suporte a qualquer endpoint compatível com OpenAI (Groq, DeepSeek, LM Studio). | ✅ Concluído |
| **Provedores Dinâmicos** | Provedor | Arquitetura plugin-like orientada a metadados para registro dinâmico de novos modelos/backends de IA. | ✅ Concluído |
| **Provedores Dinâmicos via JSON** | Provedor | Inclusão de novos provedores compatíveis com a API OpenAI salvando arquivos JSON em `%APPDATA%\RadIA\providers\`. | ✅ Concluído |
| **Contexto de Projeto** | Inteligência | Carregamento automático de instruções de system e arquivos de contexto via `.radia`. | ✅ Concluído |
| **Rastreamento de Tokens e Custo**| Transparência | Contador dinâmico de consumo e custo acumulado estimado em USD (locale invariant). | ✅ Concluído |
| **Limite de Cota Local** | Transparência | Definição de limite de tokens mensal com bloqueio de chamadas e botão de reset. | ✅ Concluído |
| **Ações no Editor** | Integração | Submenu Rad IA no topo do menu de botão direito do editor para explicar código, otimizar/refatorar, gerar testes, localizar bugs, documentar métodos e revisar a unit ativa. Quando não há seleção, a unit inteira é usada como contexto. | ✅ Concluído |
| **Create Example from Comment** | Integração | Gera o corpo de métodos vazios a partir de comentários em linguagem natural dentro do `begin/end`, preservando o comentário e inserindo o exemplo direto no editor. | ✅ Concluído |
| **Smart Diff (Comparador)** | Integração | Visualização lado a lado de código sugerido vs. original com aplicação segura no editor, substituindo o bloco original e recusando a ação quando ele não é encontrado. | ✅ Concluído |
| **Smart Build Debugger** | Integração | Clique com o botão direito nos erros de compilação da IDE para correções instantâneas. | ✅ Concluído |
| **Documentação XML Automática** | Geração | Geração automática de comentários `/// <summary>` sobre os métodos da unit. | ✅ Concluído |
| **Conversor de DTO e Modelos** | Geração | Conversor de payload JSON ou DDL SQL para classes de dados (DTOs) ou records Object Pascal (com DEXT ORM, Aurelius, REST.Json ou Vanilla). | ✅ Concluído |
| **Geração de Projeto Completo** | Geração | Geração automática de projetos Delphi (.dpr, .pas, .dfm) via prompt do assistente, salvando-os em pasta vazia e carregando-os na IDE. | ✅ Concluído |
| **Generator em Tela Cheia** | Geração | Área de generator ocupa todo o painel e recolhe a lista de chats para evitar manipulação cruzada. | ✅ Concluído |
| **Menu Popup de Slash Commands (/)** | Chat UX | Menu flutuante de sugestões e autocompletar ao digitar `/` na caixa de entrada do chat. | ✅ Concluído |
| **Assistente de Stack Trace** | Integração | Analisador de logs de erro/stack trace integrado ao contexto da unit aberta. | ✅ Concluído |
| **Análise Estática de Código** | Integração | Varredura de código em busca de memory leaks (ausência de try..finally) e anti-padrões SOLID/Clean Code. | ✅ Concluído |
| **Armazenamento Seguro** | Segurança | Chaves de API salvas localmente criptografadas usando a API do Windows DPAPI. | ✅ Concluído |
| **Build e Instalação Multi-IDE** | Infraestrutura | Script PowerShell com suporte a múltiplos ambientes Delphi no registro, seleção interativa, sincronização de recursos WebView2 e limpeza de cache local. | ✅ Concluído |
| **Arquitetura MVP** | Infraestrutura | Desacoplamento completo entre UI VCL (Views) e lógica (Presenters) do Chat e Configurações. | ✅ Concluído |
| **Abstração de Armazenamento** | Infraestrutura | Persistência via `IRadIASettingsStorage`, com Registro em produção e memória nos testes. | ✅ Concluído |
| **Testes de Apresentação** | Infraestrutura | Suíte de testes automatizados com DUnitX validando lógica de Presenters com mocks de Views. | ✅ Concluído |
| **Perfis de criação de projeto** | Jornada | O perfil essencial cria e compila apenas o projeto solicitado; completo e personalizado preservam DUnitX opcional. | ✅ Concluído |
| **Menu RadIA agrupado** | Integração IDE | Todos os comandos do produto ficam em `Ferramentas > RadIA`. | ✅ Concluído |
| **Effort visível** | Chat | O usuário escolhe a profundidade de raciocínio no compositor, com padrão equilibrado. | ✅ Concluído |
| **Painel persistente na criação** | Jornada | O chat permanece visível durante a abertura do projeto e apresenta o andamento da criação e do build. | ✅ Concluído |
| **Experiência operacional unificada** | Chat | Mostra escopo, etapa atual, resultado esperado e opcionais escolhidos pelo usuário, preservando auditoria técnica sob demanda. | ✅ Concluído |
| **Hook do Editor** | Infraestrutura | Integração resiliente com o menu contextual do editor via hook VCL assíncrono, compatível com Delphi 12/13 e estável durante a criação de novos projetos. | ✅ Concluído |
| **Registry Agentivo** | Agentivo | Catálogo compartilhado por chat, MCP e extensões. | ✅ Concluído |
| **Consentimento e Auditoria** | Segurança | Decisões por escopo e trilha sanitizada. | ✅ Concluído |
| **Consentimento Central entre Superfícies** | Segurança | Chat, agente, MCP e terminal usam o mesmo diálogo resiliente, com fila limitada, origem, argumentos sanitizados e hints. | ✅ Concluído |
| **Patches Revisáveis** | Agentivo | Preview, hash-base, aplicação e reversão com detecção de conflito. | ✅ Concluído |
| **Workspace OTA** | Integração | Fachadas para editor, projeto, build, Designer e debugger. | ✅ Concluído |
| **Servidor MCP Local** | Integração | Bridge stdio, named pipe e discovery por PID. | ✅ Concluído |
| **Designer Agentivo** | Integração | Componentes, propriedades, eventos e layout revisáveis. | ✅ Concluído |
| **Debugger Agentivo** | Integração | Estado, controle, breakpoints, avaliação de expressões e watches. | ✅ Concluído |
| **Revisão Inline e por bloco** | Editor | Marcadores no gutter para aceitar, rejeitar, editar, explicar, navegar e aplicar alterações simples ou multiarquivo de forma transacional. | ✅ Concluído |
| **Ghost Text Multilinha** | Editor | Overlays virtuais por linha, aceite total ou por palavra e atalhos configuráveis sem alterar o buffer antes do aceite. | ✅ Concluído |
| **Alternativas de Ghost Text** | Editor | Painel de até três sugestões com navegação visual e atalhos configuráveis, sem alterar o buffer antes do aceite. | ✅ Concluído |
| **Contexto semântico do editor** | Editor | Unit, símbolo, imports e declarações próximas compartilhados entre Ghost Text, ações e agente, com inspeção somente leitura. | ✅ Concluído |
| **Referências semânticas Pascal/DFM** | Editor | Identidade estável, declarações e usos confirmados com arquivo, linha e coluna; homônimos e candidatos permanecem explícitos. | ✅ Concluído |
| **Rename Symbol transacional** | Editor | Renomeação exata em Pascal e DFM, inclusive arquivos fechados, com preview, hashes, consentimento, compensação e rollback. | ✅ Concluído |
| **Extract Method transacional** | Editor | Extrai uma seleção Pascal estruturalmente válida para um novo método, preservando o buffer até a aprovação da preview e permitindo reversão exata. | ✅ Concluído |
| **Change Signature transacional** | Editor | Altera declarações, implementações e chamadas confirmadas com mapeamento explícito de parâmetros, preview multiarquivo e rollback. | ✅ Concluído |
| **Move Type transacional** | Editor | Move um tipo de interface e suas implementações entre units, atualiza consumidores e `uses`, bloqueia dependências privadas ou ciclos e aplica somente após aprovação. | ✅ Concluído |
| **Terminal Unicode e TUI** | Terminal | Decodificação UTF-8 incremental, CJK, emoji, marcas combinantes, reflow e operações ICH/DCH/ECH sobre ConPTY. | ✅ Concluído |
| **Conhecimento Local** | Agentivo | Índice incremental e reconstruível por projeto. | ✅ Concluído |
| **Extensões de Tools** | Infraestrutura | API versionada e pacote externo de exemplo. | ✅ Concluído |
| **Extensões Declarativas Assinadas** | Segurança | Pacotes RSA-SHA256 com fingerprint, confiança no primeiro uso e revogação visual. | ✅ Concluído |
| **Addon Studio** | Extensibilidade | Criação, sandbox, instalação, exportação e assinatura visual de comandos, skills, conhecimento, templates, aliases, journeys e workflows. | ✅ Concluído |
| **Portabilidade de Skills** | Extensibilidade | Publicação transacional para quatro CLIs com preview, consentimento, hashes e preservação de conflitos. | ✅ Concluído |
| **Terminal de alta fidelidade** | Terminal | True color, atributos, alternate screen, bracketed paste, mouse SGR e links OSC 8 sob consentimento. | ✅ Concluído (v2.4.0) |
| **Delphi 12/13 e IDE64** | Compatibilidade | Delphi 12 Win32 e Delphi 13 Win32/IDE64. | ✅ Concluído |
| **Assistente de threads e PPL** | Concorrência | Detecta riscos e só prepara patches com sincronização VCL, cancelamento e tratamento de exceções validados. | ✅ Concluído |
| **Retrofit OpenAPI/Swagger** | APIs existentes | Inventaria rotas DEXT e prepara integração Swagger revisável sem recriar o projeto. | ✅ Concluído |
| **Adoção de DEXT e decomposição de forms** | Modernização | Prepara etapas reversíveis somente após migração validada, evidência de paridade e auditoria DFM/PAS; falhas de build ou testes revertem a etapa. | ✅ Concluído |
