# Manual completo do RadIA 2.0

## 1. O que é o RadIA

O RadIA é um assistente de IA integrado ao Delphi 11, 12 e 13. Ele combina:

- chat com múltiplos providers;
- contexto vivo do editor e do projeto;
- geração e revisão de código;
- ferramentas estruturadas da IDE;
- integração com build, Form Designer e debugger;
- conhecimento local do projeto;
- acesso externo por MCP;
- consentimento, auditoria e proteção do workspace.

Este é o ponto de entrada recomendado para usuários. Os guias especializados vinculados ao longo
do documento detalham contratos, segurança, desenvolvimento e integração.

Para navegar por documentação de uso, arquitetura, qualidade e release, consulte o
[Centro de Documentação](README.md).

## 2. Primeiros passos

### 2.1 Abrir o painel

Depois de instalar o pacote correspondente à IDE, abra o Delphi. O RadIA é carregado como package
da IDE e disponibiliza seu painel acoplável. Posicione o painel como uma aba lateral ou janela
flutuante.

Se o painel ou package não aparecer:

1. confirme o registro do RadIA em `Component > Install Packages`;
2. confirme que a arquitetura da BPL corresponde à IDE;
3. feche todas as IDEs e reinstale o pacote correto;
4. consulte a [solução de problemas](troubleshooting_agentic_platform.md).

### 2.2 Configurar um provider

Abra `Tools > Options > Rad IA`, selecione um provider e informe suas credenciais ou endpoint.
Chaves suportadas são protegidas localmente com Windows DPAPI.

Também é possível usar Ollama ou LM Studio localmente. Consulte o
[guia de instalação e configuração](install_config.md).

### 2.3 Iniciar uma conversa

Selecione provider e modelo, crie uma sessão e escreva o prompt. Use `Ctrl + Enter` para enviar e
`Enter` para inserir uma nova linha. As setas para cima e para baixo navegam pelo histórico de
prompts.

## 3. Como ativar o modo agente

### 3.1 Botão e comandos do modo agente

A infraestrutura agentiva é inicializada automaticamente quando o package do RadIA é carregado.
O botão **Agent On/Off** controla se o chat pode executar tools. O mesmo estado pode ser alterado
com `/agent`, `/agent on` e `/agent off`.

No chat, o acesso às ferramentas é explícito:

```text
/tools
```

Esse comando mostra o catálogo realmente disponível na IDE atual. Ele é a fonte autoritativa,
porque versão da IDE, contexto e extensões podem alterar o catálogo.

Para executar uma ferramenta:

```text
/tool GetIDEState
```

Com argumentos JSON:

```text
/tool SearchProjectKnowledge {"query":"IRadIAToolRegistry","maxResults":10}
```

Para revogar permissões concedidas durante a sessão:

```text
/revoke-tools
```

Para iniciar uma execução autônoma, descreva um objetivo explícito:

```text
/agent run analise o projeto ativo, corrija o erro de compilação e valide o build
```

Antes da primeira tool, o chat exibe o plano proposto e aguarda **Approve plan**. A central viva
mostra objetivo, mensagem atual, passos e limites, tokens, tempo, custo e indicadores de mudanças,
build e testes. Cada etapa da timeline pode ser expandida para inspecionar argumentos, resultado ou
erro, correlação, duração e se a operação foi uma mutação. Seus botões ou os comandos
`/agent pause`, `/agent resume` e `/agent cancel` controlam a execução. Cada mudança de estado é
persistida em `RadIA\agent-checkpoints`, permitindo retomar a sessão depois de uma pausa.
Enquanto o plano aguarda aprovação, use **Edit plan** para revisar títulos e descrições antes de
qualquer tool. O equivalente digitável é `/agent plan [{"title":"Inspecionar","description":"..."}]`.
O RadIA aceita de 1 a 50 etapas, valida os limites e bloqueia edições depois do início da execução.
Quando a execução estiver pausada, cada item da timeline oferece **Replay step**. O comando
equivalente é `/agent replay <etapa>`. O replay usa a mesma tool e os mesmos argumentos auditados,
passa novamente pelo consentimento central, solicita confirmação adicional para mutações, registra
`replayOfStepIndex` e permanece pausado para revisão antes da retomada.
Use o botão **Runs** ou `/agent history [filtro]` para localizar execuções por objetivo, estado ou
ID da sessão. O índice mostra somente metadados; argumentos e resultados das tools não são expostos
pela pesquisa.
Para habilitar a estimativa e o limite monetário, configure o
[catálogo local de custos](agent_pricing.md).

O terminal integrado pode ser aberto pelo botão **Terminal** (`>_`) no cabeçalho do chat ou pelo
comando `/terminal`. Os dois caminhos abrem o mesmo terminal acoplável e preservam a preferência
entre interação visual e comandos digitados.

O botão **Agent On/Off** no cabeçalho e os comandos `/agent`, `/agent on` e `/agent off` controlam o
mesmo estado. Com o modo desligado, o catálogo continua disponível, mas chamadas de tools pelo chat
são recusadas até a reativação.

Prompts comuns continuam sendo enviados ao provider como conversa. O loop autônomo exige
`/agent run`, evitando que uma pergunta comum execute tools por acidente. Para automação externa e
descoberta programática, use também o [MCP](mcp_integration_guide.md).

O cartão da execução mostra a timeline expansível de cada tool, incluindo risco formal, duração,
correlação, argumentos, resultados, erros e arquivos afetados. Os arquivos são extraídos somente
de campos de caminho reconhecidos em chamadas mutáveis concluídas com sucesso; texto livre não é
tratado como caminho.

### 3.2 Consentimento

Ferramentas de leitura podem ser executadas diretamente. Operações mutáveis ou de execução exibem
um diálogo com ferramenta, risco e escopo:

- **Allow once:** autoriza somente aquela chamada;
- **Allow session:** autoriza chamadas compatíveis na sessão e escopo atuais;
- **Deny:** recusa sem modificar a IDE;
- **Cancel:** solicita o cancelamento de trabalho em andamento.

Permissão de sessão não é global. Projeto, ferramenta, cliente e escopo fazem parte da decisão.
Use `/revoke-tools` ou o botão **Revoke session permissions** para limpar todas as permissões da
sessão ativa.

Em **Settings > Security & Consent**, é possível configurar:

- timeout do diálogo entre 15 e 600 segundos;
- exibição ou ocultação dos argumentos da tool;
- permissão de sessão para escrita reversível;
- permissão de sessão, desabilitada por padrão, para escrita estrutural;
- permissão de sessão, desabilitada por padrão, para build, testes e execução.

Tools destrutivas ou sensíveis nunca oferecem permissão de sessão. Auditoria, sanitização de
secrets e confinamento ao workspace não podem ser desativados.

## 4. Tudo que o RadIA pode fazer

### 4.1 Chat, sessões e produtividade

- Chat acoplável com Markdown, realce Pascal e temas claro/escuro.
- Streaming incremental de respostas.
- Múltiplas sessões com criação, rename, exclusão e histórico local.
- Exportação de conversa para Markdown ou HTML.
- Histórico de prompts e cancelamento de requisições.
- Templates reutilizáveis, importação, exportação e slash commands customizáveis.
- Contagem estimada de tokens e custo.
- Limite mensal local de tokens.
- Respostas concisas configuráveis.

Consulte o [guia de chat e sessões](user_guide_chat_sessions.md).

### 4.2 Providers

O RadIA oferece integrações para:

- Google Gemini;
- OpenAI;
- Azure OpenAI;
- Anthropic Claude;
- AWS Bedrock;
- GitHub Copilot;
- DeepSeek;
- Groq;
- Alibaba Qwen;
- Mistral AI;
- OpenRouter;
- Ollama;
- LM Studio;
- endpoints customizados compatíveis com OpenAI;
- providers dinâmicos definidos por JSON.

A disponibilidade de modelos depende da conta, região, endpoint e provider. Web Login para contas
de consumidor foi removido; use API keys, OAuth suportado ou provider local conforme o guia.

### 4.3 Contexto e ações do editor

Pelo menu contextual do editor, o RadIA pode:

- explicar código;
- otimizar e refatorar;
- otimizar SQL;
- gerar testes DUnitX;
- localizar bugs e memory leaks prováveis;
- gerar documentação XML;
- revisar a unit;
- criar o corpo de um método a partir de comentário;
- analisar warnings de compilador, thread safety e recursos do Windows.

Sem seleção ativa, ações compatíveis usam a unit inteira como contexto.

Consulte o [guia de editor e geração](user_guide_editor_generation.md).

### 4.4 Geração

- Gerar DTOs e models a partir de JSON ou DDL.
- Produzir classes ou records para Delphi puro, REST.Json, DEXT e TMS Aurelius.
- Gerar projetos Delphi completos a partir de uma especificação.
- Criar documentação XML para Help Insight.
- Preparar código sugerido em Smart Diff antes da aplicação.

Código gerado deve sempre passar por revisão humana, compilação e testes.

### 4.5 Leitura da IDE, projeto e workspace

As ferramentas implementadas consultam:

- versão, arquitetura e estado da IDE;
- projeto e unit ativos;
- units do projeto;
- arquivos abertos;
- conteúdo e seleção vivos do editor;
- cursor;
- mensagens do compilador.

Exemplos:

```text
/tool GetActiveProject
/tool ListProjectUnits
/tool GetEditorSelection
/tool GetCompilerMessages
```

Arquivos fora do workspace autorizado são recusados.

### 4.6 Patches revisáveis

O ciclo seguro de edição usa:

1. `PreparePatch` para criar preview sem efeitos;
2. `ApplyPatch` para revalidar e aplicar;
3. `RevertPatch` para restaurar o conteúdo quando a revisão ainda é válida.

O RadIA compara arquivo, conteúdo original e hash-base. Uma edição concorrente invalida o preview
em vez de ser sobrescrita.

Consulte o [guia de ferramentas agentivas](user_guide_agentic_tools.md).

### 4.7 Build

- `BuildProject`: modos `make`, `build`, `check` e `clean`.
- `GetBuildStatus`: estado do build controlado.
- `CancelBuild`: cancelamento cooperativo.
- `GetCompilerMessages`: erros e warnings estruturados.

Build não autoriza automaticamente a execução do binário. Execução e debugger possuem risco e
consentimento próprios.

### 4.8 Testes DUnitX

- `RunDUnitXTests`: executa um runner `.exe` localizado dentro do projeto ativo.
- `GetDUnitXStatus`: informa se a execução está ociosa, em andamento ou concluída.
- `CancelDUnitXTests`: solicita o encerramento da execução ativa.

O RadIA solicita ao runner um relatório XML NUnit e devolve JSON estruturado com fixtures, testes,
status, duração, falhas e stack traces. É possível filtrar testes pelo nome e definir timeout entre
1 segundo e 10 minutos. Executáveis fora do workspace, reparse points e arquivos que não sejam
`.exe` são recusados. XML e log ficam em `.radia/test-results` para diagnóstico e auditoria.

O executável precisa registrar `TDUnitXXMLNUnitFileLogger`. Projetos DUnitX criados pelo assistente
do RadIA já incluem essa configuração.

### 4.9 Git revisável

`GetGitStatus` e `GetGitDiff` inspecionam o projeto ativo. `PreviewGitCommit` congela mensagem,
paths, diff e fingerprint sem alterar o index. Depois da revisão, `CommitChanges` exige
consentimento e cria somente um commit local. Push, reset destrutivo e descarte de arquivos não são
expostos. Consulte o [guia do fluxo Git](git_workflow.md).

### 4.10 Form Designer

No formulário ativo, o RadIA pode:

- identificar o form e listar componentes;
- preparar, aplicar e reverter layout;
- preparar, aplicar e reverter propriedades escalares;
- adicionar ou remover componentes VCL permitidos;
- criar e vincular event handlers;
- reverter mudanças quando as precondições continuam válidas.

Propriedades sensíveis, referências de objetos e tipos não suportados são recusados.

Consulte o [guia do Designer e debugger](user_guide_designer_debugger.md).

### 4.11 Debugger

O RadIA pode:

- acompanhar eventos da sessão com `GetDebugTimeline`;
- consultar estado, breakpoints e call stack;
- avaliar expressão sem permitir getters ou chamadas;
- manter e avaliar uma lista limitada de watches;
- iniciar depuração a partir do projeto ativo;
- pausar, continuar, executar step into, step over e step out;
- parar a sessão;
- adicionar e remover breakpoints em fontes Pascal do workspace.

Comandos dependem do estado atual. Por exemplo, avaliação exige processo pausado e frame válido.

`GetDebugTimeline` recebe `sinceSequence` e `maxCount`, permitindo que chat, agente e MCP acompanhem
somente os eventos novos. A timeline inclui lançamento, criação, mudança de estado e término do
processo, inclusão/alteração/remoção de breakpoints e alterações de memória. Os 500 eventos mais
recentes permanecem disponíveis em memória, enquanto uma trilha JSON Lines é gravada em
`.radia/debug/timeline.jsonl` dentro do projeto ativo.

### 4.12 Revisão inline

O RadIA pode publicar observações ancoradas a arquivo, hash e linhas do editor. Sugestões são
visuais e não alteram o código diretamente. Uma correção cria um preview de patch sujeito às mesmas
precondições, consentimento e reversão.

### 4.13 Conhecimento local

O índice local permite:

- indexar o projeto ativo;
- pesquisar símbolos e trechos;
- consultar status;
- ler documentos com limites;
- limpar e reconstruir dados derivados.

Notificações de edit, save, rename e close atualizam o índice incrementalmente. Os snapshots ficam
em `%APPDATA%\RadIA\Knowledge`.

Consulte o [guia de conhecimento local](user_guide_project_knowledge.md).

### 4.14 MCP e clientes externos

A bridge `RadIA.MCP.Bridge.exe` expõe o mesmo registry por stdio. Cada IDE publica
`%APPDATA%\RadIA\mcp.<pid>.json`, permitindo escolher a instância correta quando várias IDEs estão
abertas.

Clientes MCP usam `initialize`, `tools/list` e `tools/call`. Consentimento e workspace boundary
continuam obrigatórios.

Consulte o [guia de integração MCP](mcp_integration_guide.md).

### 4.15 Extensões

Packages confiáveis podem registrar novas ferramentas pela API versionada
`IRadIAToolExtension`. Extensões não contornam política, consentimento, auditoria ou cancelamento.

Consulte o [guia de extensões](tool_extension_guide.md).

## 5. Comandos de barra

Digite `/` no chat para abrir o menu. Os comandos principais incluem:

- `/tools`, `/tool` e `/revoke-tools`;
- `/explain`, `/refactor`, `/bugs`, `/review`;
- `/doc`, `/stacktrace`, `/sqloptimize`, `/scanwarnings`;
- `/createproject`, `/createprojectarch`;
- `/template` e comandos customizados.

Consulte a [referência de slash commands](slash_commands.md).

## 6. Segurança, dados e privacidade

- Credenciais suportadas são protegidas com DPAPI.
- Tools são classificadas por risco.
- Mutações usam consentimento e precondições.
- Paths são confinados ao workspace.
- Auditoria sanitizada fica em `%APPDATA%\RadIA\audit\tools.jsonl`.
- Índices locais são reconstruíveis.
- Named pipe MCP usa acesso local do usuário.
- Shutdown cancela solicitações e evita liberar WebView2 de forma insegura.

O conteúdo enviado ao provider segue a ação escolhida pelo usuário. Para código sensível, prefira
provider local e siga a política da organização.

Consulte o [modelo de segurança](tool_security_model.md) e o
[guia de compliance](compliance.md).

## 7. Compatibilidade

| IDE | Arquitetura | Estado |
|---|---|---|
| Delphi 11 | Win32 | Suportado e validado |
| Delphi 12 | Win32 | Suportado e validado |
| Delphi 13 | Win32 | Suportado e validado |
| Delphi 13 | IDE64 | Suportado e validado |

Use sempre o ZIP correspondente à versão e arquitetura da IDE.

## 8. Limitações importantes da versão 2.0

- Prompt livre não inicia automaticamente um loop autônomo de tools.
- `/tools` é a referência do catálogo disponível em runtime.
- O [catálogo gerado do runtime](runtime_tool_catalog.md) lista as 87 tools internas registradas.
- Algumas ideias do catálogo arquitetural são roadmap e podem não aparecer em `/tools`.
- Debugger e Designer dependem de contexto e estado válidos da IDE.
- Patches são recusados quando o buffer muda depois do preview.
- O RadIA não executa reset Git destrutivo nem aceita executável arbitrário no debugger.
- Análise de código por IA não substitui compilador, testes, FastMM ou revisão humana.

## 9. Onde procurar ajuda

- [Tudo que o RadIA pode fazer](capabilities.md)
- [Instalação e configuração](install_config.md)
- [Ferramentas agentivas](user_guide_agentic_tools.md)
- [O que faz e quando usar cada ferramenta](internal_tools_reference.md)
- [Catálogo das ferramentas internas](runtime_tool_catalog.md)
- [MCP](mcp_integration_guide.md)
- [Conhecimento local](user_guide_project_knowledge.md)
- [Designer e debugger](user_guide_designer_debugger.md)
- [Solução de problemas](troubleshooting_agentic_platform.md)
- [Arquitetura agentiva](agentic_architecture.md)
- [Segurança](tool_security_model.md)
