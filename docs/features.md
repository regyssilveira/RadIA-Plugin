# Recursos e Funcionalidades do Rad IA

Este documento contém o checklist completo de recursos, categorização e status de desenvolvimento de todas as funcionalidades integradas ao plugin **Rad IA**.

---

## Tabela Completa de Recursos

Nota v2.3.1: seleção explícita entre RadIA native e CLI direto, identidade visual por rota,
cópia em todas as respostas textuais e ChatGPT Pro restaurado exclusivamente pelo Codex CLI.

Nota v2.2.2: `/help`, jornadas DEXT conversacionais, descoberta de modelos compatível com o
transporte ativo, limite local de tokens opcional e refinamentos da configuração CLI/MCP.

Nota v2.2.1: diagnóstico `/doctor`, `/status` sanitizado, experiência guiada de CLI/MCP,
documentação centralizada e correções de estabilidade do debugger e da UI.

Nota v0.0.25: o plugin agora protege o **Apply Changes** do Smart Diff contra duplicação de código quando a seleção original do editor é perdida.

| Recurso | Categoria | Descrição | Status |
| :--- | :--- | :--- | :--- |
| **Smart SQL Optimizer** | Integração | Analisador e otimizador de strings de consultas SQL integrado diretamente ao menu contextual do editor do Delphi. | ✅ Concluído |
| **Scan Compiler & OS Warnings** | Integração | Varredura de código em busca de warnings do compilador Delphi, problemas de thread-safety e vazamentos de recursos (handles GDI). | ✅ Concluído |
| **Chat Lateral Acoplável** | Chat UX | Painel integrado à IDE rodando WebView2 com suporte a Markdown e Pascal highlight. | ✅ Concluído |
| **Tela Inicial do Chat** | Chat UX | Tela inicial com animação central, ações rápidas e carregamento de histórico sob demanda. | ✅ Concluído |
| **Tema Integrado à IDE** | Chat UX | Adaptação Dark/Light ao tema do Delphi, incluindo Mountain Mist como light, scrollbar e blocos de código consistentes. | ✅ Concluído |
| **Atalhos de Teclado** | Chat UX | Atalho `Ctrl + Enter` para enviar prompts e `Enter` para quebra de linha. | ✅ Concluído |
| **Persistência de Layout** | Chat UX | Salvamento e restauração automática de tamanho/posição flutuante e visibilidade no startup. | ✅ Concluído |
| **Streaming de Respostas** | Chat UX | Respostas incrementais token a token (SSE) nos provedores OpenAI, Gemini, Claude e Ollama. | ✅ Concluído |
| **Múltiplas Sessões de Chat** | Chat UX | Criação, renomeação, exclusão e isolamento de conversas em barra lateral retrátil (bloqueadas durante requisições ativas). | ✅ Concluído |
| **Histórico de Chat Persistente** | Chat UX | Salvamento automático em JSON e restauração sob demanda das sessões anteriores de chat. | ✅ Concluído |
| **Histórico de Prompts (↑/↓)** | Chat UX | Navegação rápida pelos prompts enviados anteriormente usando as setas do teclado. | ✅ Concluído |
| **Cancelamento de Requisições** | Chat UX | Permite abortar chamadas ativas de IA de forma assíncrona com botão stop e bloqueia ações de sessão durante processamento. | ✅ Concluído |
| **Exportação de Conversa** | Chat UX | Botão para salvar histórico nos formatos Markdown (.md) ou HTML autônomo com Prism.js. | ✅ Concluído |
| **Templates de Prompt** | Chat UX | Biblioteca de templates rápidos de prompt com substituição de código e o comando `/template`. | ✅ Concluído |
| **Slash Commands Dinâmicos** | Chat UX | Mapeamento dinâmico de templates para comandos de barra (ex: `/createprojectarch`), sincronizados e autocompletados no WebView2. | ✅ Concluído |
| **Doctor e Status do RadIA** | Diagnóstico | `/doctor` verifica prontidão e recomenda a próxima ação; `/status` inventaria configuração e disponibilidade sem expor credenciais. | ✅ Concluído (v2.2.1) |
| **Assistente CLI/MCP** | Integração | Detecta, explica, solicita consentimento, instala ou configura, valida e oferece fallback manual completo sem exigir reinício da IDE. | ✅ Concluído (v2.2.1) |
| **Rotas explícitas de execução** | Chat UX | Separa modo Chat/Agent, orquestração RadIA native e CLI direto, mostrando rota, transporte e credencial efetivos. | ✅ Concluído (v2.3.1) |
| **ChatGPT Pro via Codex CLI** | Provedor | Usa a sessão e a cota ChatGPT/Codex tanto como transporte do provider nativo quanto na execução CLI direta; API Key permanece separada. | ✅ Concluído (v2.3.1) |
| **Cópia universal de texto** | Chat UX | Oferece cópia para respostas, JSON, resultados de tools e demais payloads textuais, preservando o conteúdo original. | ✅ Concluído (v2.3.1) |
| **Ajuda integrada** | Chat UX | `/help` resume capacidades e abre os guias públicos no navegador padrão. | ✅ Concluído (v2.2.2) |
| **Jornadas DEXT conversacionais** | Projetos | Coleta requisitos ausentes em várias mensagens, preserva o contexto e gera APIs minimalistas ou com controllers. | ✅ Concluído (v2.2.2) |
| **Skills e Templates Declarativos** | Extensibilidade | Manifesto schema 2 com hot reload, autocomplete e permissão mínima `chat.prompt`. | ✅ Concluído |
| **Aliases Declarativos de Tools** | Extensibilidade | Schema 3 registra aliases seguros no chat e MCP, herdando risco, schemas e consentimento da tool interna. | ✅ Concluído |
| **Workflows Declarativos** | Extensibilidade | Schema 5 encadeia até 16 tools internas com risco herdado, limites e policy central por etapa, sem shell arbitrário. | ✅ Concluído |
| **Recursos Declarativos Empacotados** | Extensibilidade | Schema 6 e envelope `.radiaext` v3 transportam referências, conhecimento, templates e assets com hash, rollback e remoção transacional. | ✅ Concluído |
| **Renderização de Código do Editor no Chat** | Chat UX | Prompts enviados pelo menu do editor preservam blocos fenced Markdown com realce Pascal também em mensagens do usuário. | ✅ Concluído |
| **Backup de Templates** | Chat UX | Exportação e importação transacional em JSON de templates com validação estrutural de esquema e opção de mesclagem na UI. | ✅ Concluído |
| **Google Gemini** | Provedor | Suporte nativo aos modelos Gemini 1.5 Flash e Pro via chaves próprias (BYOK). | ✅ Concluído |
| **OpenAI ChatGPT** | Provedor | Suporte nativo aos modelos GPT-4o, GPT-4o-mini e outros. | ✅ Concluído |
| **Login Híbrido (Web Login)**| Provedor | Permite alternar entre BYOK (API Keys) ou Login Web (Plus/Pro) para OpenAI e Gemini. | ❌ Removido (v0.0.29) |
| **Anthropic Claude** | Provedor | Suporte nativo aos modelos Claude 3 Haiku e Claude 3.5 Sonnet. | ✅ Concluído |
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
| **Hook do Editor** | Infraestrutura | Integração resiliente com o menu contextual do editor via hook VCL assíncrono, compatível com Delphi 12/13 e estável durante a criação de novos projetos. | ✅ Concluído |
| **Registry Agentivo** | Agentivo | Catálogo compartilhado por chat, MCP e extensões. | ✅ Concluído |
| **Consentimento e Auditoria** | Segurança | Decisões por escopo e trilha sanitizada. | ✅ Concluído |
| **Patches Revisáveis** | Agentivo | Preview, hash-base, aplicação e reversão com detecção de conflito. | ✅ Concluído |
| **Workspace OTA** | Integração | Fachadas para editor, projeto, build, Designer e debugger. | ✅ Concluído |
| **Servidor MCP Local** | Integração | Bridge stdio, named pipe e discovery por PID. | ✅ Concluído |
| **Designer Agentivo** | Integração | Componentes, propriedades, eventos e layout revisáveis. | ✅ Concluído |
| **Debugger Agentivo** | Integração | Estado, controle, breakpoints, avaliação de expressões e watches. | ✅ Concluído |
| **Revisão Inline e por bloco** | Editor | Marcadores no gutter para aceitar, rejeitar, editar, explicar, navegar e aplicar alterações simples ou multiarquivo de forma transacional. | ✅ Concluído |
| **Ghost Text Multilinha** | Editor | Overlays virtuais por linha, aceite total ou por palavra e atalhos configuráveis sem alterar o buffer antes do aceite. | ✅ Concluído |
| **Conhecimento Local** | Agentivo | Índice incremental e reconstruível por projeto. | ✅ Concluído |
| **Extensões de Tools** | Infraestrutura | API versionada e pacote externo de exemplo. | ✅ Concluído |
| **Extensões Declarativas Assinadas** | Segurança | Pacotes RSA-SHA256 com fingerprint, confiança no primeiro uso e revogação visual. | ✅ Concluído |
| **Addon Studio** | Extensibilidade | Criação, sandbox, instalação, exportação e assinatura visual de comandos, skills, conhecimento, templates, aliases, journeys e workflows. | ✅ Concluído |
| **Delphi 12/13 e IDE64** | Compatibilidade | Delphi 12 Win32 e Delphi 13 Win32/IDE64. | ✅ Concluído |
