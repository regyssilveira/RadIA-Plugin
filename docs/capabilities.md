# Tudo que o RadIA pode fazer

Esta página é o mapa funcional do RadIA 2.0. Ela reúne as capacidades disponíveis e aponta para
as instruções detalhadas.

Para distinguir implementação de planejamento:

- o [catálogo de ferramentas internas](runtime_tool_catalog.md) lista somente tools registradas;
- `/tools` mostra o catálogo disponível na instância atual da IDE;
- o [catálogo arquitetural](tool_catalog.md) também contém contratos e evoluções planejadas;
- o [backlog](backlog.md) não deve ser interpretado como funcionalidade entregue.

## Chat e produtividade

- Painel acoplável à IDE, modo flutuante e persistência de posição.
- Markdown, realce de sintaxe Pascal e temas claro/escuro.
- Respostas em streaming e cancelamento.
- Múltiplas sessões, histórico local e exportação para Markdown ou HTML.
- Histórico de prompts, envio com `Ctrl + Enter` e seleção de provider e modelo.
- Estimativas e limites locais de tokens e custo.
- Templates editáveis, importáveis e exportáveis.
- Comandos internos e comandos personalizados.

Consulte [Chat e sessões](user_guide_chat_sessions.md) e
[Comandos de barra](slash_commands.md).

## Providers e modelos

O RadIA pode se conectar a Google Gemini, OpenAI, Azure OpenAI, Anthropic Claude, AWS Bedrock,
GitHub Copilot, DeepSeek, Groq, Alibaba Qwen, Mistral AI, OpenRouter, Ollama, LM Studio, endpoints
compatíveis com OpenAI e providers dinâmicos definidos em JSON.

Credenciais compatíveis são protegidas localmente com Windows DPAPI. A disponibilidade de modelos
depende do provider, da conta, da região e do endpoint.

Consulte [Instalação e configuração](install_config.md).

## Editor, análise e geração

Pelo chat e pelo menu contextual do editor, o RadIA pode:

- ler a unit, a seleção, o cursor e o buffer ativo;
- explicar, revisar, refatorar e otimizar código;
- localizar bugs, vazamentos prováveis e falhas de lógica;
- analisar SQL e warnings de compilação, thread safety e recursos do Windows;
- gerar testes DUnitX e documentação XML;
- criar o corpo de um método a partir de um comentário;
- gerar DTOs e models a partir de JSON ou DDL;
- produzir código para Delphi puro, REST.Json, DEXT e TMS Aurelius;
- apresentar mudanças em Smart Diff e publicar revisões inline;
- preparar, aplicar e reverter correções revisadas.

Quando uma ação compatível não recebe seleção, ela pode usar a unit ativa como contexto.

Consulte [Editor e geração](user_guide_editor_generation.md) e
[Diagnóstico e análise](user_guide_diagnostics_analysis.md).

## Projetos e estrutura

O RadIA pode:

- criar projetos pelos templates Console, VCL, FMX, Library, Package e DUnitX;
- visualizar antecipadamente os arquivos;
- criar em staging e validar hashes e precondições;
- abrir, compilar, validar e reverter o projeto criado;
- adicionar ou remover units e forms de forma revisável;
- executar transações compostas de código, projeto e Form Designer.

Consulte [New Project Wizard](project_wizard.md),
[Operações estruturais](project_file_operations.md) e
[Transações de desenvolvimento](development_transactions.md).

## Edição segura

As alterações estruturadas oferecem preview, hash-base, precondições, aplicação controlada,
reversão, patches de um ou vários arquivos e confinamento ao workspace. Uma mudança concorrente
invalida o preview em vez de ser sobrescrita.

Consulte [Ferramentas agentivas](user_guide_agentic_tools.md).

## Form Designer

Com um formulário válido aberto, o RadIA pode:

- identificar o form e listar componentes;
- preparar, aplicar e reverter mudanças de layout e propriedades;
- adicionar e remover componentes;
- criar e conectar event handlers;
- coordenar alterações de código, DFM e projeto;
- solicitar consentimento antes de mutações.

Consulte [Form Designer e debugger](user_guide_designer_debugger.md).

## Build e DUnitX

O RadIA pode executar `make`, `build`, `check` e `clean`, consultar estado, cancelar o build,
estruturar erros e warnings, aplicar timeout e usar o resultado como gate após mutações.

O runner DUnitX pode executar e filtrar testes, definir timeout, cancelar a execução, interpretar
NUnit XML e devolver fixtures, duração, falhas e stack traces estruturados. Os artefatos ficam em
`.radia/test-results`.

Consulte [Runner DUnitX](dunitx_runner.md).

## Debugger

Durante uma sessão válida, o RadIA pode:

- iniciar, parar, pausar e continuar a depuração;
- executar Step Into, Step Over e Step Out;
- consultar estado e call stack;
- adicionar, remover e listar breakpoints;
- avaliar expressões sem efeitos colaterais;
- adicionar, remover, listar e avaliar watches;
- consultar a timeline de eventos.

Consulte [Form Designer e debugger](user_guide_designer_debugger.md).

## Git local e revisável

Dentro do repositório do projeto ativo, o RadIA pode consultar status e diff, preparar o preview,
validar fingerprint, selecionar caminhos e criar um commit local. O fluxo não oferece push, reset
destrutivo ou descarte automático de alterações.

Consulte [Fluxo Git](git_workflow.md).

## Conhecimento local

O RadIA pode indexar arquivos, pesquisar código e símbolos, consultar o estado da indexação,
recuperar documentos e limpar ou reconstruir o índice. Eventos de edição, save, rename e
fechamento mantêm o conhecimento sincronizado.

Consulte [Conhecimento do projeto](user_guide_project_knowledge.md).

### Saúde do projeto

`GetProjectHealth` e o comando `/health` consolidam projeto ativo, encerramento da IDE, erros do
compilador, último build, última execução DUnitX e estado do conhecimento local. O relatório é
somente leitura, calcula um score de 0 a 100 e prioriza riscos críticos, altos e médios sem iniciar
build, testes ou indexação. No chat, cada risco pode oferecer **Preparar ação**: o botão apenas
preenche o comando recomendado, como `/journey fix-build`, para revisão e envio pelo usuário.

### Diagnóstico da instalação

`GetInstallationHealth` e `/doctor` verificam localmente provider, executor, MCP somente quando
exigido pela CLI, terminal, recursos web e disponibilidade de `GetIDEState` como primeira tool
somente leitura. O resultado não expõe credenciais e inclui score, checks, próxima ação e
recomendações de configuração, provisionamento ou reparo.

## Modo agente

O modo agente oferece:

- ativação pelo botão Agent On/Off ou por `/agent on` e `/agent off`;
- execução explícita por `/agent run <objetivo>`;
- apresentação e aprovação do plano;
- execução iterativa de ferramentas e cartão de progresso;
- pausa, retomada, cancelamento e checkpoints;
- limites de passos, tokens, tempo, custo e repetição;
- build e validação como parte do objetivo quando solicitados.

Perguntas comuns continuam como chat e não iniciam automaticamente um loop de ferramentas.

Consulte [Manual completo](user_manual.md) e [Custos do agente](agent_pricing.md).

## MCP

Clientes locais compatíveis com MCP acessam as mesmas ferramentas pela bridge stdio, named pipe e
discovery da IDE por PID. O protocolo oferece inicialização, `tools/list`, `tools/call`,
cancelamento e métricas sanitizadas, sempre sob as políticas do chat.

Consulte [Integração MCP](mcp_integration_guide.md).

## Segurança, consentimento e extensões

O RadIA aplica classificação de risco, consentimento por chamada ou sessão, revogação, timeout,
auditoria sanitizada, remoção de secrets, recusa de conteúdo desatualizado, cancelamento e
confinamento de paths. Operações destrutivas ou sensíveis não recebem autorização persistente.

Packages confiáveis podem registrar tools pela API `IRadIAToolExtension`, mas continuam sujeitos
às mesmas políticas.

Manifestos locais `*.radia.json` e pacotes íntegros `*.radiaext` podem adicionar comandos de chat
com permissão `chat.prompt`, validação atômica e recarga sem reiniciar. Consulte
[Extensões declarativas](declarative_extensions.md).

Consulte [Modelo de segurança](tool_security_model.md) e
[Extensões](tool_extension_guide.md).

## Compatibilidade

| IDE | Arquitetura | Estado |
|---|---|---|
| Delphi 11 | Win32 | Suportado e validado |
| Delphi 12 | Win32 | Suportado e validado |
| Delphi 13 | Win32 | Suportado e validado |
| Delphi 13 | IDE64 | Suportado e validado |

## Referências rápidas

- [O que faz e quando usar cada ferramenta](internal_tools_reference.md)
- [Catálogo técnico das 88 ferramentas registradas](runtime_tool_catalog.md)
- [Todos os comandos de barra](slash_commands.md)
- [Manual completo](user_manual.md)
- [Recursos e funcionalidades](features.md)
- [Centro de documentação](README.md)
