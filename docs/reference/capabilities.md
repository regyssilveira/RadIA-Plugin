# Tudo que o RadIA pode fazer

Esta é a referência canônica, orientada ao usuário, sobre o que o RadIA pode fazer. Ela reúne as
capacidades disponíveis por área e aponta para as instruções detalhadas. Para consultar cada recurso
individualmente, com categoria e status, use o [inventário detalhado de funcionalidades](features.md).

Para distinguir implementação de planejamento:

- o [catálogo de ferramentas internas](runtime_tool_catalog.md) lista somente tools registradas;
- `/tools` mostra o catálogo disponível na instância atual da IDE;
- o [catálogo arquitetural](../development/tool_catalog.md) também contém contratos e evoluções planejadas;
- o [backlog](../project/backlog.md) não deve ser interpretado como funcionalidade entregue.

O agente combina o [perfil sanitizado do ambiente Delphi](delphi_environment_profile.md) com a
[orientação Delphi curada](delphi_guidance.md). Assim, regras de linguagem, memória, VCL, FMX,
Delphi 12, Delphi 13 e IDE64 entram no contexto com citações estáveis e consultáveis.

## Chat e produtividade

- Painel acoplável à IDE, modo flutuante e persistência de posição.
- Markdown, realce de sintaxe Pascal e temas claro/escuro.
- Respostas em streaming, cancelamento e fila visual de até cinco continuações com edição e limpeza.
- Múltiplas sessões, histórico local e exportação para Markdown ou HTML.
- Histórico de prompts, envio com `Ctrl + Enter` e seleção de provider e modelo.
- Estimativas e limites locais de tokens e custo.
- Templates editáveis, importáveis e exportáveis.
- Comandos internos e comandos personalizados.
- Ajuda integrada com `/help`, exemplos de comandos e links abertos no navegador padrão.
- Recomendação local de rota para criação, build, testes e diagnóstico, com confirmação, revisão ou
  permanência no chat antes de qualquer mudança de modo e contadores sanitizados em `/status intent`.
- Jornadas conversacionais que preservam respostas até concluir ou abandonar a coleta.
- Identidade de jornada compartilhada entre chat, terminal e editor, com vínculo, troca e isolamento
  por projeto sem copiar histórico ou saída de processos.

Consulte [Chat e sessões](../guides/user_guide_chat_sessions.md),
[Roteamento de intenção](intent_routing.md) e
[Comandos de barra](slash_commands.md). Para continuar a mesma tarefa entre superfícies, consulte
[Contexto compartilhado](../guides/shared_journey_context.md).

## Providers e modelos

O RadIA pode se conectar a Google Gemini, OpenAI, Azure OpenAI, Anthropic Claude, AWS Bedrock,
GitHub Copilot, DeepSeek, Groq, Alibaba Qwen, Mistral AI, OpenRouter, Ollama, LM Studio, endpoints
compatíveis com OpenAI e providers dinâmicos definidos em JSON.

Credenciais compatíveis são protegidas localmente com Windows DPAPI. A disponibilidade de modelos
depende do provider, da conta, da região e do endpoint.

Consulte [Instalação e configuração](../getting-started/install_config.md).

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
- sugerir Ghost Text por FIM dedicado no Ollama e LM Studio, com fallback explícito nos demais
  providers e diagnóstico de rota sem conteúdo do código;
- compartilhar unit, símbolo vigente, imports e declarações próximas entre Ghost Text, ações
  contextuais e agente, com inspeção somente leitura pelo menu do editor;
- preparar, aplicar e reverter correções revisadas.
- renomear membros em ancestrais e overrides como uma única alteração transacional, bloqueando
  overloads ou relações de herança ambíguas.

A conclusão estrutural local após `.` pertence ao fluxo de Ghost Text: ela pode fornecer uma
continuação inequívoca sem chamar a IA, mas não substitui nem injeta itens no popup nativo do
CodeInsight. Referências, hierarquia e membros ausentes também possuem escopo e acionamento próprios.
Consulte [Inteligência semântica no editor](semantic_intelligence.md) para a matriz verificável,
comandos, provas reproduzíveis e limites.

Quando uma ação compatível não recebe seleção, ela pode usar a unit ativa como contexto.

Consulte [Editor e geração](../guides/user_guide_editor_generation.md) e
[Diagnóstico e análise](../guides/user_guide_diagnostics_analysis.md).

## Projetos e estrutura

`GetDelphiEnvironmentProfile` inventaria versão, arquitetura, edição, capacidades, framework,
configuração, plataforma, search paths, packages e bibliotecas do projeto ativo. Caminhos externos
são sanitizados e a operação permanece somente leitura. Consulte
[Perfil do ambiente Delphi](delphi_environment_profile.md).

O RadIA pode:

- criar projetos pelos templates Console, VCL, FMX, Library, Package, DUnitX e Windows Service;
- visualizar antecipadamente os arquivos;
- criar em staging e validar hashes e precondições;
- abrir, compilar, validar e reverter o projeto criado;
- adicionar ou remover units e forms de forma revisável;
- executar transações compostas de código, projeto e Form Designer.

Consulte [New Project Wizard](../guides/project_wizard.md),
[Operações estruturais](../guides/project_file_operations.md) e
[Transações de desenvolvimento](../guides/development_transactions.md).

## Edição segura

As alterações estruturadas oferecem preview, hash-base, precondições, aplicação controlada,
reversão, patches de um ou vários arquivos e confinamento ao workspace. Uma mudança concorrente
invalida o preview em vez de ser sobrescrita.

Consulte [Ferramentas agentivas](../guides/user_guide_agentic_tools.md).

## Form Designer

Com um formulário válido aberto, o RadIA pode:

- identificar o form e listar componentes;
- preparar, aplicar e reverter mudanças de layout e propriedades;
- adicionar e remover componentes;
- criar e conectar event handlers;
- coordenar alterações de código, DFM e projeto;
- solicitar consentimento antes de mutações.

Consulte [Form Designer e debugger](../guides/user_guide_designer_debugger.md).

## Build e DUnitX

O RadIA pode executar `make`, `build`, `check` e `clean`, consultar estado, cancelar o build,
estruturar erros e warnings, aplicar timeout e usar o resultado como gate após mutações.

O runner DUnitX pode executar e filtrar testes, definir timeout, cancelar a execução, interpretar
NUnit XML e devolver fixtures, duração, falhas e stack traces estruturados. Os artefatos ficam em
`.radia/test-results`.

Consulte [Runner DUnitX](../guides/dunitx_runner.md).

### Validação de código

`ValidateDelphiCode` valida a unit ativa ou o projeto e normaliza regras nativas, mensagens atuais do
compilador, disponibilidade do DelphiLint e issues do Sonar no [Painel de problemas](problems_panel.md).
Cada fonte informa separadamente se passou, encontrou problemas, não foi solicitada, não está
configurada ou falhou. Quando solicitado, um Check nativo atualiza primeiro a evidência do compilador.
Correções estruturadas aparecem no painel e geram preview; nenhuma é aplicada automaticamente.

## Debugger

Durante uma sessão válida, o RadIA pode:

- iniciar, parar, pausar e continuar a depuração;
- executar Step Into, Step Over e Step Out;
- consultar estado e call stack;
- adicionar, remover e listar breakpoints;
- consultar capacidades e configurar condições, hit count, logpoints, frames e thread em breakpoints;
- avaliar expressões sem efeitos colaterais;
- adicionar, remover, listar e avaliar watches;
- consultar a timeline de eventos.

Consulte [Form Designer e debugger](../guides/user_guide_designer_debugger.md).

## Diagnóstico runtime autônomo

O RadIA pode transformar uma falha visual reproduzível em uma prova verificável:

- compilar o projeto e iniciar uma nova sessão pelo depurador da IDE;
- correlacionar projeto, processo, executável, build e identidade da sessão;
- descobrir somente janelas e controles Win32 ou VCL do processo depurado e seus descendentes;
- instrumentar reversivelmente um projeto Debug para alcançar controles VCL sem `HWND`;
- preparar um roteiro visual com preview, limites, fingerprint e consentimento;
- reproduzir uma exceção, capturar a pilha e registrar evidência sanitizada;
- capturar a janela autorizada antes e depois da interação e apresentar o par no chat;
- aplicar uma correção revisada, recompilar e repetir o mesmo roteiro;
- comparar falha e verificação entre sessões e builds distintos;
- medir o mesmo cenário em builds distintos e comparar duração, CPU, memória e responsividade;
- versionar o cenário em `.radia/runtime-scenarios` e executá-lo repetidamente como regressão.

A automação não aceita `HWND`, coordenadas globais ou processos arbitrários. Em Delphi 13 IDE64,
seletores cruzados para aplicações Win32 preservam classe e hierarquia quando o texto do controle
não está disponível.

O adaptador VCL é opt-in, autenticado por sessão e limitado. Sua inclusão exige preview e
consentimento, e pode ser revertida sem manter alterações nas units geradas.

Consulte [Diagnóstico Runtime Autônomo](../guides/runtime_debug_automation.md).

## Git local e revisável

Dentro do repositório do projeto ativo, o RadIA pode consultar status e diff, preparar o preview,
validar fingerprint, selecionar caminhos e criar um commit local. O fluxo não oferece push, reset
destrutivo ou descarte automático de alterações.

Consulte [Fluxo Git](../guides/git_workflow.md).

## Conhecimento local

O RadIA pode indexar arquivos, pesquisar código e símbolos, consultar o estado da indexação,
recuperar documentos e limpar ou reconstruir o índice. Eventos de edição, save, rename e
fechamento mantêm o conhecimento sincronizado.

Consulte [Conhecimento do projeto](../guides/user_guide_project_knowledge.md).

### Saúde do projeto

`GetProjectHealth` e o comando `/health` consolidam projeto ativo, encerramento da IDE, erros do
compilador, último build, última execução DUnitX e estado do conhecimento local. O relatório é
somente leitura, calcula um score de 0 a 100 e prioriza riscos críticos, altos e médios sem iniciar
build, testes ou indexação. No chat, cada risco pode oferecer **Preparar ação**: o botão apenas
preenche o comando recomendado, como `/journey fix-build`, para revisão e envio pelo usuário.

### Diagnóstico da instalação

`GetInstallationHealth` e `/doctor` verificam localmente a rota efetiva, provider, CLI quando
exigida pelo executor ou pelo transporte ChatGPT Pro, MCP somente quando exigido, terminal,
recursos web, tools internas e runtime MCP externo. O cartão não expõe credenciais e apresenta
score, checks classificados, rota, próxima ação e recomendações. Consulte [RadIA Doctor](doctor.md).

`GetRadIAStatus` e `/status` complementam o diagnóstico com um inventário sanitizado da
configuração e disponibilidade atuais. Use `/status` para a visão completa ou filtre com
`provider`, `agent`, `cli`, `mcp`, `security`, `editor`, `project`, `tools`, `logging` ou `settings`.
Caminhos
efetivos podem aparecer; chaves de API, tokens OAuth e argumentos de tools nunca são incluídos.

`/scope` e o botão **Settings > Scope** mostram provider, modelo, executor e limites efetivos com a
origem de cada campo. Overrides independentes podem valer para projeto, sessão ou próxima
solicitação e podem ser removidos para restaurar herança. Consulte
[Configurações por escopo](../guides/hierarchical_settings.md).

## Terminal integrado

O terminal VCL acoplável oferece múltiplas abas, perfis detectados, ConPTY interativo, entrada
contínua, histórico, snippets, paleta, cancelamento da árvore de processos e consentimento comum às
demais superfícies. O modelo de tela decodifica UTF-8 entre blocos, calcula largura de CJK, emoji e
marcas combinantes, reorganiza quebras automáticas no resize e interpreta cores de 256 posições e
true color, atributos, alternate screen, bracketed paste, mouse SGR e hyperlinks OSC 8. A abertura
de links exige consentimento. Consulte [Terminal](../guides/terminal.md) para uso, limites e solução alternativa.

## Modo agente

O modo agente oferece:

- ativação pelo botão Agent On/Off ou por `/agent on` e `/agent off`;
- execução explícita por `/agent run <objetivo>`;
- apresentação e aprovação do plano;
- execução iterativa de ferramentas e cartão de progresso;
- pausa, retomada, cancelamento e checkpoints;
- compactação interna de saídas extensas de DUnitX e Git diff antes da próxima decisão, preservando
  o resultado integral no checkpoint;
- limites de passos, tokens, tempo, custo e repetição;
- build e validação como parte do objetivo quando solicitados.

Perguntas comuns continuam como chat e não iniciam automaticamente um loop de ferramentas.

Consulte [Manual completo](../guides/user_manual.md), [Custos do agente](agent_pricing.md) e
[Compactação de resultados](../guides/agent_result_compaction.md).

## MCP

Clientes locais compatíveis com MCP acessam as mesmas ferramentas pela bridge stdio, named pipe e
discovery da IDE por PID. O protocolo oferece inicialização, `tools/list`, `tools/call`,
cancelamento e métricas sanitizadas, sempre sob as políticas do chat.

Consulte [Integração MCP](../guides/mcp_integration_guide.md).

## Segurança, consentimento e extensões

O RadIA aplica classificação de risco, consentimento por chamada ou sessão, revogação, timeout,
auditoria sanitizada, remoção de secrets, recusa de conteúdo desatualizado, cancelamento e
confinamento de paths. Operações destrutivas ou sensíveis não recebem autorização persistente.

Chat, agente, MCP e terminal usam um único diálogo nativo com fila limitada, origem legível,
argumentos sanitizados e hints. Tools sensíveis permanecem negadas por padrão; somente contratos
com `ConsentEveryTime` podem pedir autorização e nunca criam permissão de sessão.

Packages confiáveis podem registrar tools pela API `IRadIAToolExtension`, mas continuam sujeitos
às mesmas políticas.

Manifestos locais `*.radia.json` e pacotes íntegros `*.radiaext` podem adicionar comandos, skills,
jornadas, conhecimento, referências, templates, aliases e workflows auditados. O Addon Studio
cria, testa, instala, exporta e assina esses pacotes; atualização e remoção tratam manifesto e
recursos como uma unidade transacional, sem reiniciar. Consulte
[Extensões declarativas](../guides/declarative_extensions.md).

Uma skill criada no Addon Studio pode ser publicada para Codex, Claude Code, Gemini CLI e GitHub
Copilot CLI com preview, consentimento central, hashes de propriedade, rollback e preservação de
divergências manuais. Consulte [Portabilidade de skills](../guides/skill_portability.md).

Consulte [Modelo de segurança](tool_security_model.md) e
[Extensões](../development/tool_extension_guide.md).

## FireDAC, dependências e localização

`InspectFireDACProject` inventaria componentes e relações FireDAC com localização em PAS e DFM,
sem executar SQL nem devolver valores de credenciais. `InspectFireDACUsage` preserva compatibilidade
com as contagens anteriores e retorna o mesmo inventário estruturado. Análises especializadas cobrem
SQL, parâmetros, transações, configuração, thread safety e schema SQLite; geração e correções usam
preview, consentimento, fingerprint, build, DUnitX e rollback. Consulte o
[FireDAC Advisor](../guides/firedac_advisor.md). O RadIA também diagnostica paths e
manifestos ausentes sem instalar componentes e localiza textos visíveis em Pascal/DFM. Para localização,
`PrepareLocalizationExtraction` cria somente um preview imutável na unit ativa; `ApplyPatch` exige consentimento
e `RevertPatch` restaura a alteração. A comparação entre idiomas reutiliza os snapshots e o diff visual existentes.

## Banco SQLite local

O RadIA descobre tabelas, views e colunas de arquivos SQLite dentro do workspace. Também executa,
com consentimento em toda chamada, uma consulta somente leitura limitada a 500 linhas. O resultado
aparece em grid paginado e permite copiar um CSV sanitizado. Operações de escrita, múltiplas
instruções, arquivos externos ao projeto, BLOBs e valores de colunas sensíveis não atravessam essa
jornada. Consulte [Banco de dados local com segurança](../guides/local_database.md).

## Compatibilidade

| IDE | Arquitetura | Estado |
|---|---|---|
| Delphi 12 | Win32 | Suportado e validado |
| Delphi 13 | Win32 | Suportado e validado |
| Delphi 13 | IDE64 | Suportado e validado |

Delphi 11 é referência histórica e não faz parte da matriz vigente de build, teste, instalação ou
suporte.

## Referências rápidas

- [O que faz e quando usar cada ferramenta](internal_tools_reference.md)
- [Catálogo técnico das 212 ferramentas registradas](runtime_tool_catalog.md)
- [Todos os comandos de barra](slash_commands.md)
- [Manual completo](../guides/user_manual.md)
- [Recursos e funcionalidades](features.md)
- [Centro de documentação](../README.md)
