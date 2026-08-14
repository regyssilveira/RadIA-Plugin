# Manual completo do RadIA 2.13.0

> Para comparar Chat, Agent, CLI e MCP, use `/help`. Quando um plano aguardar aprovação, clique em
> **Approve plan** ou digite `/agent resume`.

## 1. O que é o RadIA

O RadIA é um assistente de IA integrado ao Delphi 12 e 13. Ele combina:

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
[Centro de Documentação](../README.md).

## 2. Primeiros passos

Digite `/help` no chat para consultar capacidades, comandos principais e links para os guias. Os
links são abertos no navegador padrão. Jornadas iniciadas sem todos os dados entram em coleta
conversacional e mantêm cada resposta até a execução ou até `/journey cancel`.

### 2.1 Abrir o painel

Depois de instalar o pacote correspondente à IDE, abra o Delphi. O RadIA é carregado como package
da IDE e disponibiliza seu painel acoplável. Posicione o painel como uma aba lateral ou janela
flutuante.

A visibilidade, o modo acoplado ou flutuante e as dimensões do painel acompanham o desktop da IDE e
são restaurados na próxima abertura do Delphi. Se o painel for fechado antes de sair, ele permanece
fechado na sessão seguinte; use `Tools > RadIA > Chat` para abri-lo novamente.

O caption do painel de chat e das janelas principais do RadIA mostra a versão carregada, por exemplo
`Rad IA Chat v2.13.0`, para facilitar suporte e conferência de instalação.

Se o painel ou package não aparecer:

1. confirme o registro do RadIA em `Component > Install Packages`;
2. confirme que a arquitetura da BPL corresponde à IDE;
3. feche todas as IDEs e reinstale o pacote correto;
4. consulte a [solução de problemas](troubleshooting_agentic_platform.md).

### 2.2 Configurar um provider

Abra `Tools > Options > Rad IA`, selecione um provider e informe suas credenciais ou endpoint.
Chaves suportadas são protegidas localmente com Windows DPAPI.

Também é possível usar Ollama ou LM Studio localmente. Consulte o
[guia de instalação e configuração](../getting-started/install_config.md).

### 2.3 Iniciar uma conversa

Selecione provider e modelo, crie uma sessão e escreva o prompt. Use `Ctrl + Enter` para enviar e
`Enter` para inserir uma nova linha. As setas para cima e para baixo navegam pelo histórico de
prompts.

No agente nativo, os modelos pertencem ao provider selecionado. A lista é recarregada ao trocar o
provider ou salvar as configurações, sem reiniciar o Delphi. No executor externo, o CLI administra
o modelo e o seletor fica desabilitado com uma indicação visual do cliente responsável.

O Rad IA consulta primeiro a lista de modelos oferecida pela conta e pelo endpoint configurados.
Somente quando essa descoberta falha, mostra um catálogo mínimo de fallback, atualizado com as
famílias estáveis atuais do provider. A lista descoberta sempre prevalece, pois disponibilidade,
região, plano e permissões podem variar. Os modelos do transporte ChatGPT OAuth/Codex são tratados
separadamente dos modelos da API OpenAI e são consultados pelo `model/list` do Codex App Server.
Se o Codex CLI não responder, o Rad IA mantém os modelos atuais de fallback no seletor.

Links externos exibidos nas respostas são abertos no navegador padrão do Windows. O painel do chat
permanece na página local do Rad IA e não é usado como navegador para esses destinos.

Quando **Enable local token quota** está desligado, execuções do agente mostram `tokens (unlimited)`
e não são interrompidas por um orçamento local de tokens. Limites da conta ou do provider continuam
independentes.

### 2.4 Mapa das configurações

A janela de configurações pode ser redimensionada ou maximizada e preserva um tamanho mínimo seguro
para evitar que controles sejam cortados.

| Aba | Para que serve | Quando alterar |
|---|---|---|
| Providers | Credenciais, login, endpoint e opções avançadas de cada provider | Ao conectar ou trocar o serviço de IA |
| System | Prompt de sistema aplicado às conversas | Quando precisar de instruções permanentes |
| Templates | Prompts reutilizáveis e comandos de barra personalizados | Ao padronizar tarefas recorrentes |
| General / Logs | Idioma, contexto, logs e limite local de tokens | Ao ajustar comportamento geral ou diagnóstico |
| Security & Consent | Aprovação por risco, timeout e permissões da sessão | Antes de permitir execução ou mutações |
| Knowledge & Embeddings | Conhecimento local, exclusões e embeddings remotos | Ao configurar recuperação de contexto do projeto |
| Editor Assistance | Ghost text, atraso, exclusões e atalhos | Ao configurar sugestões no editor |
| CLI & MCP | Executor nativo/externo, executável portátil, bridge e servidores MCP externos | Ao usar CLI, expor a IDE ou consumir um servidor MCP local |
| Memory Diagnostics | Caminho e limites do FastMM5 | Ao investigar leaks, double free ou use-after-free |

Cada campo e botão possui hint contextual. Para decisões de segurança, consulte o
[modelo de segurança](../reference/tool_security_model.md); para dependências entre modo nativo, CLI e MCP,
consulte a [matriz de executores](cli_executors.md). A finalidade, o momento de uso, as dependências
e os cuidados de cada opção estão na
[referência completa das configurações](../reference/settings_reference.md).

## 3. Como ativar o modo agente

Uma conversa vazia começa por objetivos: entender o projeto, corrigir um problema, criar algo ou
depurar uma aplicação. Essas ações apenas preparam o pedido. A mesma tela mantém visíveis as
capacidades de código, build, testes, debugger, Form Designer, terminal, MCP e skills. O usuário
pode começar pela intenção sem perder a percepção ou o acesso à plataforma completa.

### 3.1 Botão e comandos do modo agente

A infraestrutura agentiva é inicializada automaticamente quando o package do RadIA é carregado.
No compositor, **Mode: Chat** envia uma conversa comum pela rota escolhida em **Executor**, dentro
de **More**. Com
**RadIA native**, usa o provider selecionado sem executar tools registradas do RadIA; com um CLI,
envia diretamente ao processo externo, que conserva suas próprias capacidades e políticas.
**Mode: Agent** transforma a próxima mensagem em um objetivo agentivo e também usa **Executor**:
**RadIA native**, **Codex CLI**, **Claude Code**, **Gemini CLI** ou **GitHub Copilot CLI**. A escolha
é aplicada à próxima mensagem e salva como padrão. Os comandos `/agent`, `/agent on` e `/agent off`
continuam disponíveis.

Para o uso comum, não é preciso abrir **More** nem compreender todas as combinações. Um pedido que
claramente exige ações — por exemplo, criar um projeto VCL — é encaminhado automaticamente para a
jornada nativa adequada. **More** existe para sessões CLI, vínculo de jornada e sobrescritas de
configuração destinadas a usuários avançados.

Em **Configurações > CLI & MCP > Chat executor** permanecem o padrão e os caminhos dos executáveis.
Providers por API key e providers locais não exigem CLI. Para OpenAI, **OpenAI API via API Key** usa
o transporte HTTP nativo e a cobrança da plataforma API. **ChatGPT Pro via Codex CLI** usa a sessão e
a cota da conta ChatGPT/Codex. O login é compartilhado pelas duas rotas Codex, mas a orquestração não:
**RadIA native** mantém o controle no RadIA, enquanto **Codex CLI direto** entrega a execução ao CLI.

O caminho de um CLI portátil pode ser selecionado com **Browse...**. O mesmo caminho é usado por
**Diagnose**, pelo executor externo e pelo transporte ChatGPT Pro, sem exigir uma instalação npm.
Consulte [Orquestração nativa e executores por CLI](cli_executors.md) para a matriz completa.

O cabeçalho do chat mostra a rota efetiva da conversa. Exemplos incluem **Chat | OpenAI native**,
**Chat | RadIA native | ChatGPT Pro via Codex CLI**, **Agent | RadIA native | OpenAI** e
**Agent | codex CLI direct**. Esse
indicador representa o caminho realmente usado, não apenas a configuração selecionada. MCP aparece
separadamente porque é uma ponte para clientes externos e não o executor do chat interno.
Cada resposta também repete a identificação no cabeçalho e usa um avatar próprio: brilho RadIA para
transporte nativo, terminal para CLI e nós conectados para MCP. Os marcadores **N**, **>_** e **M** e
o nome ao lado informam a rota e a credencial efetivas, como **Native API**, **ChatGPT Pro via Codex
CLI** ou **Codex CLI direct**, evitando depender apenas de cor ou ícone.

### 3.2 Configurações por projeto, sessão e próxima solicitação

O botão **Settings > Scope** permite substituir provider, modelo, executor e limites sem alterar o
padrão global. Selecione projeto, sessão ou próxima solicitação, edite um campo e use **Apply**. Cada
linha mostra a origem efetiva; **Inherit** remove somente aquele override e **Restore all
inheritance** limpa o nível selecionado. `/scope` e `/status settings` oferecem a mesma informação
pelo teclado. A rota e os modelos são atualizados sem reiniciar o Delphi.

Consulte [Configurações por projeto, sessão e solicitação](hierarchical_settings.md) para a ordem de
precedência, comandos, formatos, persistência e segurança.

Antes do envio, a linha inferior do compositor permite escolher a rota e mostra a credencial e, quando aplicável, o
modelo selecionado. Durante o processamento, o avatar da rota recebe uma animação discreta e o texto
de estado informa se o RadIA está preparando a resposta, executando uma ferramenta ou processando o
resultado. Após a conclusão, um resumo técnico recolhível registra a rota, a duração e as ferramentas
utilizadas. No modo agente, a economia do RTK é exibida somente quando as métricas reais de compactação
estão presentes, em caracteres e percentual; o RadIA não estima nem inventa esse valor.

Enquanto o turno está ativo, escreva outra instrução e use **+1** ou `Ctrl + Enter` para enfileirá-la.
A fila visual comporta cinco mensagens, permite editar a próxima ou limpar todas e envia uma por vez
após a conclusão. Ela é local ao painel e ainda não faz parte do histórico. Veja
[Chat e sessões](user_guide_chat_sessions.md).

Respostas do assistente, resultados de ferramentas, argumentos JSON e erros textuais possuem uma
ação de cópia. A ação usa o conteúdo original do retorno, preservando indentação e quebras de linha
sem incluir botões, títulos ou outros elementos visuais. Blocos de código mantêm sua cópia própria.

No chat, o acesso às ferramentas é explícito:

```text
/tools
```

Esse comando mostra o catálogo realmente disponível na IDE atual. Ele é a fonte autoritativa,
porque versão da IDE, contexto e extensões podem alterar o catálogo.

O catálogo exibido no chat permite pesquisar por nome, finalidade ou risco. Cada tool apresenta
descrição, categoria de risco, orientação de acionamento direto ou pelo agente e o schema JSON
aceito. Abrir os detalhes não executa a ferramenta.

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
O [contrato de execução autônoma](autonomous_execution_contract.md) preserva no mesmo checkpoint os
limites de arquivos e operações, critérios de conclusão, gates de build/testes e resumos periódicos.
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
[catálogo local de custos](../reference/agent_pricing.md).

Na criação de projetos, a central apresenta primeiro uma visão operacional estável: preparação,
revisão da estrutura, criação dos arquivos, abertura no Delphi, build e conclusão. A etapa atual
permanece destacada enquanto o trabalho acontece. O cartão informa explicitamente que DUnitX e
outros adicionais não serão criados automaticamente e mostra o resultado esperado antes da
execução terminar. Métricas, riscos, evidências e argumentos continuam disponíveis em
**Technical details**, sem ocupar a leitura principal. Depois de um build bem-sucedido, ações como
**Add DUnitX tests** apenas preparam uma nova solicitação; o usuário ainda revisa e envia a escolha.

O terminal integrado pode ser aberto pelo botão **Terminal** (`>_`) no cabeçalho do chat ou por
**Ferramentas > RadIA > Rad IA Terminal**. Todos os comandos do produto ficam agrupados nesse
submenu, evitando que ações do RadIA se misturem com comandos nativos do Delphi.
comando `/terminal`. Os dois caminhos abrem o mesmo terminal acoplável e preservam a preferência
entre interação visual e comandos digitados.

Saída Unicode fragmentada, caracteres CJK, emoji, marcas combinantes, resize com reflow e operações
comuns de aplicações TUI são tratados pelo modelo de tela. Recursos gráficos ou protocolo de mouse
podem exigir um terminal externo. Veja a referência completa em [Terminal](terminal.md).

O chat, o terminal e o contexto enviado às ações do editor podem compartilhar uma identidade de
jornada sem duplicar o histórico da conversa nem a saída do terminal. O botão **Journey** permite
vincular ou desvincular visualmente; `/context`, `/context new`, `/context detach` e
`/context switch <id>` oferecem as mesmas operações pelo teclado. A troca é limitada ao projeto
ativo. Veja o [guia de contexto compartilhado](shared_journey_context.md).

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
Quando a jornada inclui validação, a seção **Validation evidence** apresenta status e duração do
build, quantidade de mensagens do compilador e contagens DUnitX de total, aprovados, falhas, erros
e ignorados. Quando existe um relatório oficial do Delphi Code Coverage, a mesma seção mostra o
percentual, as linhas cobertas e totais, a quantidade de arquivos-fonte e o caminho da evidência.
Esses dados permanecem no checkpoint e voltam a aparecer ao abrir o histórico.
Para criar servidores HTTP, use `/journey dext-minimal` ou `/journey dext-controllers`. As jornadas
transformam a lista de endpoints em uma especificação revisável, geram um projeto DEXT, abrem e
compilam o resultado. Consulte o [guia das jornadas DEXT](user_guide_dext_journeys.md).
Etapas de patch bem-sucedidas apresentam **Reviewed changes** dentro de seus detalhes. Cada arquivo
mostra apenas o bloco alterado, três linhas de contexto e os totais removidos/adicionados. Essa
visualização é somente para revisão; aplicar ou reverter continua sendo uma tool auditada e sujeita
ao consentimento configurado.
As etapas Git apresentam **Git evidence**. O status aparece como saída legível; diffs exibem linhas
adicionadas e removidas com cores, arquivos e totais; o preview de commit mostra mensagem,
quantidade de caminhos e fingerprint; e o commit concluído mostra o SHA local. O RadIA não faz
push automático por esse fluxo.
As tools de depuração apresentam **Debug evidence** com estado e localização, breakpoints, frames
da pilha, transições entre estados, avaliações, watches e eventos recentes. A interface não inicia
polling nem executa ações adicionais: ela mostra somente o resultado já autorizado e auditado da
etapa, limitando listas a um tamanho seguro para o WebView.

### 3.3 Consentimento

Ferramentas de leitura podem ser executadas diretamente. Operações mutáveis ou de execução exibem
um diálogo com ferramenta, risco e escopo:

- **Allow once:** autoriza somente aquela chamada;
- **Allow session:** autoriza chamadas compatíveis na sessão e escopo atuais;
- **Deny:** recusa sem modificar a IDE;
- **Cancel:** solicita o cancelamento de trabalho em andamento.

Permissão de sessão não é global. Ela é reutilizada somente para tools compatíveis da mesma
categoria de risco, origem, projeto e escopo. Uma aprovação estrutural pode, por exemplo, cobrir
preview, criação e abertura do mesmo projeto sem repetir o diálogo; não cobre execução nem ações
destrutivas. Tools marcadas para consentimento obrigatório continuam perguntando a cada chamada.
Use `/revoke-tools` ou o botão **Revoke session permissions** para limpar todas as permissões da
sessão ativa.

Em **Settings > Security & Consent**, é possível configurar:

- timeout do diálogo entre 15 e 600 segundos;
- exibição ou ocultação dos argumentos da tool;
- permissão de sessão para escrita reversível;
- permissão de sessão para escrita estrutural;
- permissão de sessão para build, testes e execução.

As três categorias vêm habilitadas para que **Allow session** esteja disponível. Elas podem ser
desativadas individualmente. Instalações anteriores recebem esse novo padrão uma vez; depois disso,
as escolhas salvas pelo usuário são preservadas.

Em **Settings > Knowledge & Embeddings**, é possível configurar:

- conhecimento semântico local, desabilitado por padrão, sem envio de código pela rede.
- memória local de resumos agentivos aprovados, desabilitada por padrão e isolada por projeto.
- exclusões de conhecimento por fragmentos de caminho de arquivo e projeto.

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

O Ghost Text captura prefixo e sufixo limitados sem alterar o buffer. Ollama e LM Studio recebem
uma solicitação FIM dedicada; outros providers usam fallback tradicional identificado. Use
**Show Inline Completion Route Status** no submenu Rad IA do editor para ver provider, modelo,
latência e motivo do fallback. Aceite, aceite parcial, alternativa e rejeição continuam disponíveis
por atalhos configuráveis. Consulte a [referência completa de FIM](inline_completion.md).

Alterações preparadas pelo agente também podem ser revisadas bloco a bloco diretamente no gutter.
Cada marcador permite aceitar, rejeitar, editar ou explicar a mudança; a navegação e a aplicação
possuem atalhos configuráveis e mudanças multiarquivo só são gravadas depois que todos os blocos
forem resolvidos. Consulte o [guia completo de revisão por bloco](block_reviews.md).

Consulte o [guia de editor e geração](user_guide_editor_generation.md).

### 4.4 Geração

- Gerar DTOs e models a partir de JSON ou DDL.
- Produzir classes ou records para Delphi puro, REST.Json, DEXT e TMS Aurelius.
- Gerar projetos Delphi completos a partir de uma especificação.
- Criar documentação XML para Help Insight.
- Gerar `API.md` e mocks por preview, sem sobrescrever código existente.
- Preparar código sugerido em Smart Diff antes da aplicação.

Código gerado deve sempre passar por revisão humana, compilação e testes.
Consulte [documentação de API e mocks seguros](safe_productivity_tools.md) para geração, aplicação e
reversão desses artefatos.

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

#### Perfis de criação

Ao pedir um projeto sem mencionar adicionais, o RadIA usa o perfil `essential`: cria somente os
arquivos necessários, abre o projeto e compila. O perfil `complete` acrescenta o projeto DUnitX e
seus testes iniciais. O perfil `custom` aceita `optionalFeatures` para selecionar, por enquanto,
`dunitx`. Depois de compilar a criação essencial, o RadIA apresenta escolhas para manter o projeto
como está ou adicionar recursos. Nenhum adicional é criado sem uma escolha explícita do usuário.

Durante esse fluxo, o painel do RadIA permanece aberto e apresenta o andamento da criação, abertura
e build. A transição do projeto não deve ocultar o chat nem exigir que o usuário o reabra.

Na linha principal do compositor, **Effort** controla a profundidade de raciocínio do executor
compatível. `Medium` é o padrão equilibrado; `Low` prioriza rapidez, enquanto `High` e
`Extra high` priorizam análise. A escolha fica visível e é preservada ao trocar o executor.

### 4.8 Testes DUnitX

- `RunDUnitXTests`: executa um runner `.exe` localizado dentro do projeto ativo.
- `GetDUnitXStatus`: informa se a execução está ociosa, em andamento ou concluída.
- `CancelDUnitXTests`: solicita o encerramento da execução ativa.
- `GetCoverageSummary`: lê o relatório oficial `Output/Coverage/CodeCoverage_Summary.xml` ou outro
  caminho informado dentro do projeto ativo, sem interpretar texto livre do console.

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

#### 4.11.1 Regressões visuais runtime

Use `CaptureRuntimeVisual` com o ID opaco devolvido por `GetRuntimeWindows`: `phase=before` captura
a janela antes do roteiro e `phase=after` conclui o card anterior/posterior no chat. Cada captura é
sensível, exige consentimento próprio e fica somente em memória por até dez minutos.

O card recebe diretamente do executor o início e o término de cada ação, a repetição, o tipo da
ação e o resultado final. Seletores, valores digitados e conteúdo dos controles não são exibidos.

Depois de corrigir uma falha dependente da interface, o RadIA pode preservar o roteiro em
`.radia/runtime-scenarios/<id>.json`. O artefato usa schema versionado e fingerprint e não salva
IDs opacos da sessão: cada alvo precisa de classe, texto e caminho estáveis. Para uma janela raiz,
use `parentPath` igual a `$root`.

O fluxo é `PrepareRuntimeRegression`, revisão, `SaveRuntimeRegression`, commit pelo usuário e,
em uma sessão futura, `PrepareSavedRuntimeScenario` seguido de `RunRuntimeScenario`. Preparar e
listar são somente leitura. Salvar e reverter são escritas reversíveis, enquanto cada execução do
cenário exige consentimento novo. Artefatos alterados sem atualizar o fingerprint são recusados.

O ciclo completo — build, nova sessão, reprodução, evidência, correção, verificação, comparação e
dez repetições — está em [Diagnóstico Runtime Autônomo](runtime_debug_automation.md). A comparação
só aceita evidências do mesmo projeto obtidas em sessões e builds distintos.

### 4.12 Revisão inline

O RadIA pode publicar observações ancoradas a arquivo, hash e linhas do editor. Sugestões são
visuais e não alteram o código diretamente. Na linha marcada, use o submenu **Rad IA** do editor ou
`Ctrl+Alt+Enter` para aceitar e `Ctrl+Alt+R` para rejeitar. O aceite pede confirmação, valida o
hash-base e aplica um patch transacional; a rejeição remove a marca sem alterar o buffer. Também é
possível preparar o preview pelo chat, agente ou MCP antes da decisão.

Revisões com mais de 20 linhas ou 4.096 caracteres são abertas no Smart Diff, onde cada bloco pode
ser aceito ou rejeitado antes da aplicação. Mudanças que abrangem mais de um arquivo usam a
transação multiarquivo e nunca são reduzidas a várias aplicações inline independentes.

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

Comandos, skills, jornadas, conhecimento, referências, templates, aliases e workflows declarativos
podem ser instalados em
**Ferramentas > RadIA > Rad IA Extensions...** como manifesto `*.radia.json` ou pacote íntegro `.radiaext`.
Workflows executam somente tools internas pela policy central; não interpretam shell ou binários.
O **Addon Studio...** cria, testa em sandbox, instala, exporta e assina o pacote. Para conteúdo
compartilhado, selecione **Resources folder** e informe um **Content file** relativo em
`references/`, `templates/` ou `knowledge/`. O gerenciador permite atualizar, habilitar,
desabilitar, diagnosticar e remover manifesto e recursos sem reiniciar.

Ao editar uma **Skill**, use **Publish skill to CLIs...** para selecionar os quatro destinos,
revisar paths e conflitos e publicar com consentimento central. Atualizações usam hashes de
propriedade e arquivos alterados manualmente são preservados. Consulte
[Portabilidade de skills](skill_portability.md).

Consulte o [guia de extensões](../development/tool_extension_guide.md) e
[extensões declarativas](declarative_extensions.md).

## 5. Comandos de barra

Digite `/` no chat para abrir o menu. Os comandos principais incluem:

- `/doctor` para prontidão, `/status` para inventário sanitizado e `/health` para o projeto;
- `/tools`, `/tool` e `/revoke-tools`;
- `/explain`, `/refactor`, `/bugs`, `/review`;
- `/doc`, `/stacktrace`, `/sqloptimize`, `/scanwarnings`;
- `/createproject`, `/createprojectarch`;
- `/template` e comandos customizados.

Consulte a [referência de slash commands](../reference/slash_commands.md).

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

Consulte o [modelo de segurança](../reference/tool_security_model.md) e o
[guia de compliance](../development/compliance.md).

## 7. Compatibilidade

| IDE | Arquitetura | Estado |
|---|---|---|
| Delphi 12 | Win32 | Suportado e validado |
| Delphi 13 | Win32 | Suportado e validado |
| Delphi 13 | IDE64 | Suportado e validado |

Use o instalador visual, que detecta e valida a versão e a arquitetura selecionadas.

## 8. Limitações importantes da versão atual

- Prompt livre não inicia automaticamente um loop autônomo de tools.
- `/tools` é a referência do catálogo disponível em runtime.
- O [catálogo gerado do runtime](../reference/runtime_tool_catalog.md) lista as 162 tools internas registradas.
- O [assistente de threads e PPL](threading_assistant.md) audita e prepara modernizações concorrentes seguras.
- O [retrofit OpenAPI/Swagger](openapi_retrofit.md) integra documentação em APIs DEXT existentes.
- A [modernização DEXT e de forms](dext_form_modernization.md) executa lotes reversíveis com gates.
- A automação runtime atua somente em controles VCL com janela própria; controles sem `HWND`
  informam capacidade indisponível.
- O RadIA reproduz e comprova a correção, mas a hipótese e o diff continuam sujeitos à revisão e ao
  consentimento do usuário.
- Algumas ideias do catálogo arquitetural são roadmap e podem não aparecer em `/tools`.
- Debugger e Designer dependem de contexto e estado válidos da IDE.
- Patches são recusados quando o buffer muda depois do preview.
- O RadIA não executa reset Git destrutivo nem aceita executável arbitrário no debugger.
- Análise de código por IA não substitui compilador, testes, FastMM ou revisão humana.

## 9. Onde procurar ajuda

Passe o mouse sobre campos e botões para ver a ajuda contextual. Nas Configurações, os hints
explicam formato, efeito e dependências; no chat, os botões informam a ação equivalente e atalhos
quando existirem. No terminal, os hints também documentam `Enter`, `Ctrl+R` e `Ctrl+P`.

- [Tudo que o RadIA pode fazer](../reference/capabilities.md)
- [Instalação e configuração](../getting-started/install_config.md)
- [Ferramentas agentivas](user_guide_agentic_tools.md)
- [O que faz e quando usar cada ferramenta](../reference/internal_tools_reference.md)
- [Catálogo das ferramentas internas](../reference/runtime_tool_catalog.md)
- [MCP](mcp_integration_guide.md)
- [Conhecimento local](user_guide_project_knowledge.md)
- [Designer e debugger](user_guide_designer_debugger.md)
- [Solução de problemas](troubleshooting_agentic_platform.md)
- [Arquitetura agentiva](../development/agentic_architecture.md)
- [Segurança](../reference/tool_security_model.md)
