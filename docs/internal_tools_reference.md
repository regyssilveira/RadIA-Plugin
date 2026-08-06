# Referência operacional das ferramentas internas

Esta página explica as 88 ferramentas internas do RadIA 2.0: o que cada uma faz e em qual etapa
ela costuma ser acionada.

O [catálogo gerado](runtime_tool_catalog.md) continua sendo a fonte técnica dos nomes registrados.
Na IDE, `/tools` é a fonte final porque extensões e contexto podem alterar a lista disponível.

## Como uma ferramenta é acionada

Uma ferramenta pode ser chamada por quatro caminhos:

1. **Modo agente:** o runtime escolhe a ferramenta necessária para cumprir o plano aprovado.
2. **Comando `/tool`:** o usuário chama diretamente, por exemplo `/tool GetIDEState`.
3. **MCP:** um cliente local executa `tools/call` depois de consultar `tools/list`.
4. **Fluxo interno:** uma ação visual ou etapa composta do RadIA usa a mesma ferramenta.

Ferramentas de leitura normalmente executam sem confirmação. Escritas, build, testes, Git,
Designer e debugger passam pela política de risco e podem solicitar consentimento.

Os grupos com `Prepare`, `Apply` e `Revert` seguem este ciclo:

- `Prepare`: cria um preview e não altera o projeto;
- `Apply`: revalida precondições, solicita consentimento quando necessário e efetiva a mudança;
- `Revert`: desfaz uma aplicação ainda válida e também pode exigir consentimento.

## Workspace e editor

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetIDEState` | Retorna versão, arquitetura e estado geral da IDE. | No início de um objetivo ou quando o agente precisa verificar capacidades do Delphi atual. |
| `GetActiveProject` | Identifica o projeto ativo e seu caminho autorizado. | Antes de operações de projeto, build, teste, Git ou geração. |
| `GetActiveUnit` | Identifica a unit ativa no editor. | Quando a solicitação se refere ao arquivo ou código que o usuário está vendo. |
| `ListOpenFiles` | Lista arquivos abertos e buffers disponíveis. | Para localizar contexto vivo ou evitar ler uma cópia desatualizada do disco. |
| `ListProjectUnits` | Lista as units pertencentes ao projeto ativo. | Em análises de arquitetura, busca de dependências e planejamento multi-arquivo. |
| `GetEditorContent` | Lê o conteúdo vivo de um buffer da IDE. | Antes de analisar ou preparar uma alteração, inclusive quando há mudanças não salvas. |
| `GetEditorSelection` | Lê a seleção atual do editor. | Em ações direcionadas a um trecho, como explicar, revisar, testar ou refatorar. |
| `GetCursorPosition` | Retorna arquivo, linha e coluna do cursor. | Para contextualizar erros, símbolos, inserções e revisões ancoradas. |
| `GetCompilerMessages` | Coleta erros e warnings estruturados. | Depois de um build ou quando o objetivo envolve corrigir falhas de compilação. |

## Navegação, símbolos e project groups

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `ListProjectGroupProjects` | Lista os projetos carregados no project group atual. | Para entender soluções com executável, packages, bibliotecas ou testes separados. |
| `GetProjectDependencies` | Consulta as dependências reais do projeto ativo pela OTA. | Antes de decidir ordem de build, impacto ou relacionamento entre projetos. |
| `GetUnitSymbols` | Extrai classes, records, interfaces e rotinas do buffer ativo com suas linhas. | Para localizar declarações sem pesquisar texto cegamente. |
| `NavigateToFile` | Abre um arquivo pertencente a um projeto carregado e posiciona o cursor. | Quando uma análise, erro ou plano aponta para arquivo, linha e coluna específicos. |
| `NavigateToSymbol` | Posiciona o editor em um símbolo da unit ativa. | Depois de `GetUnitSymbols` ou quando o usuário pede para mostrar uma declaração. |
| `ListIDEActions` | Lista somente ações disponíveis na allowlist segura. | Antes de oferecer uma ação visual da IDE. |
| `ExecuteIDEAction` | Executa uma ação allowlisted após consentimento. | Para abrir painéis ou buscas da IDE sem automação de UI frágil. |

Navegação de arquivo é confinada aos projetos abertos. A execução de ações usa uma allowlist fixa,
passa pela classificação `execution` e não aceita nomes arbitrários recebidos do agente ou MCP.

## Patch de um arquivo

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PreparePatch` | Produz preview e hash-base para uma alteração em um arquivo. | Depois da análise e antes de qualquer edição simples. |
| `ApplyPatch` | Revalida o preview e aplica o patch ao buffer ou arquivo correto. | Após aprovação e consentimento da mudança proposta. |
| `RevertPatch` | Restaura o conteúdo anterior quando as precondições continuam válidas. | Quando o usuário ou agente decide desfazer um patch aplicado. |

## Patches de vários arquivos

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareMultiFilePatch` | Cria um preview único para alterações coordenadas em vários arquivos. | Em refatorações que atravessam units ou exigem mudanças relacionadas. |
| `ApplyMultiFilePatch` | Aplica o conjunto depois de validar todos os arquivos. | Quando o preview completo foi aprovado e nenhum arquivo ficou desatualizado. |
| `RevertMultiFilePatch` | Reverte o conjunto de arquivos de forma coordenada. | Para desfazer integralmente uma alteração multi-arquivo aplicada. |

## Transações de desenvolvimento

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareDevelopmentTransaction` | Monta uma transação com mudanças de código, projeto e Designer. | Quando um objetivo precisa alterar diferentes superfícies como uma única unidade. |
| `ApplyDevelopmentTransaction` | Executa as etapas da transação e preserva dados de reversão. | Depois da revisão da operação composta e das permissões necessárias. |
| `RevertDevelopmentTransaction` | Desfaz as etapas aplicadas em ordem segura. | Quando uma transação composta precisa ser revertida. |

## Templates de projetos

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PreviewProjectTemplate` | Renderiza a árvore e os arquivos de um template sem gravá-los. | Ao criar Console, VCL, FMX, Library, Package ou DUnitX. |
| `CreateProjectFromTemplate` | Publica o projeto preparado usando staging e validações. | Depois que o usuário aprova o nome, destino, template e preview. |
| `RevertCreatedProject` | Remove de forma controlada os arquivos criados pela operação. | Quando a criação precisa ser desfeita e os hashes ainda correspondem. |
| `OpenCreatedProject` | Abre na IDE o projeto que acabou de ser criado. | Após a publicação bem-sucedida ou por solicitação explícita. |
| `ValidateCreatedProject` | Compila e valida a estrutura do projeto gerado. | No fim do fluxo de criação ou quando o agente precisa confirmar que o template funciona. |

## Arquivos do projeto

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareAddProjectFile` | Prepara a criação e inclusão de uma unit ou form. | Antes de adicionar um novo arquivo à estrutura do projeto. |
| `PrepareRemoveProjectFile` | Prepara a remoção de uma unit ou form. | Antes de excluir a referência e os arquivos associados. |
| `ApplyProjectFileChange` | Efetiva a inclusão ou remoção preparada. | Depois do preview e do consentimento estrutural. |
| `RevertProjectFileChange` | Restaura a estrutura e os arquivos anteriores. | Para desfazer uma alteração estrutural aplicada. |

## Revisões inline

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PublishInlineReview` | Publica uma observação ancorada em arquivo, hash e linhas. | Quando uma revisão encontra um problema que deve aparecer no editor. |
| `ListInlineReviews` | Lista as revisões inline atuais. | Para retomar uma análise ou consultar pendências antes de aplicar correções. |
| `PrepareInlineReviewFix` | Converte a sugestão de uma revisão em preview de patch. | Quando o usuário decide corrigir uma observação publicada. |
| `RemoveInlineReview` | Remove uma revisão específica sem alterar o código. | Depois de resolver, descartar ou considerar a observação inválida. |
| `ClearInlineReviews` | Limpa as revisões do escopo solicitado. | Ao encerrar uma rodada de revisão ou reiniciar a análise. |

## Build

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `BuildProject` | Executa `make`, `build`, `check` ou `clean` com diagnóstico estruturado. | Para validar mudanças, reproduzir erros ou cumprir o gate de build. |
| `CancelBuild` | Solicita o cancelamento cooperativo do build ativo. | Pelo botão de cancelamento, pelo agente ou quando um timeout é atingido. |
| `GetBuildStatus` | Retorna estado, duração e resultado do build controlado. | Enquanto o agente acompanha a compilação ou antes de iniciar outra. |

## Inspeção do Form Designer

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetActiveForm` | Identifica o formulário ativo e seu contexto de design. | Antes de consultar ou modificar componentes. |
| `ListFormComponents` | Lista componentes, classes, propriedades básicas e hierarquia. | Para entender o formulário e planejar alterações visuais. |

## Layout do Form Designer

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareComponentLayout` | Cria preview de posição, tamanho, alinhamento ou ancoragem. | Antes de mover ou redimensionar um componente. |
| `ApplyComponentLayout` | Aplica o layout depois de revalidar form e componente. | Após aprovação da mudança visual. |
| `RevertComponentLayout` | Restaura o layout anterior. | Quando a alteração visual precisa ser desfeita. |

## Propriedades do Form Designer

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareComponentProperty` | Prepara a mudança de uma propriedade compatível. | Antes de alterar Caption, Text, Enabled ou outra propriedade suportada. |
| `ApplyComponentProperty` | Define a propriedade no Designer vivo. | Depois do preview e consentimento. |
| `RevertComponentProperty` | Restaura o valor anterior da propriedade. | Para desfazer uma alteração de propriedade aplicada. |

## Componentes do Form Designer

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareAddFormComponent` | Prepara classe, nome, parent e posição de um novo componente. | Quando o objetivo pede a inclusão de um controle ou componente não visual. |
| `PrepareRemoveFormComponent` | Prepara a remoção e captura o estado necessário à reversão. | Antes de excluir um componente existente. |
| `ApplyFormComponentChange` | Adiciona ou remove o componente preparado. | Após validação do Designer e consentimento estrutural. |
| `RevertFormComponentChange` | Reverte a inclusão ou remoção. | Quando a alteração de componentes precisa ser desfeita. |

## Eventos do Form Designer

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareFormEventHandler` | Prepara método, assinatura, corpo e vínculo do evento. | Quando um componente precisa responder a Click, Change ou outro evento suportado. |
| `ApplyFormEventHandler` | Cria o método e conecta o evento de forma coordenada. | Depois da revisão da mudança de código e design. |
| `RevertFormEventHandler` | Remove ou restaura o método e o vínculo anteriores. | Para desfazer a criação ou alteração do handler. |

## Inspeção do debugger

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetDebuggerState` | Retorna estado, processo, thread e localização atuais. | Antes de qualquer comando de debug ou durante o acompanhamento da sessão. |
| `ListBreakpoints` | Lista breakpoints conhecidos pela IDE. | Para entender onde a execução pode parar ou evitar duplicações. |
| `GetCallStack` | Retorna a pilha do thread e frame atuais. | Quando a execução está pausada e é necessário localizar a origem de uma falha. |

## Controle do debugger

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PauseDebugging` | Solicita a pausa da aplicação em execução. | Quando é preciso inspecionar o estado atual. |
| `ContinueDebugging` | Retoma uma sessão pausada. | Depois de concluir a inspeção ou alterar breakpoints. |
| `StepInto` | Avança entrando na rotina chamada. | Para acompanhar em detalhe uma chamada relevante. |
| `StepOver` | Executa a linha atual sem entrar nas chamadas. | Para avançar pelo fluxo no nível da rotina atual. |
| `StepOut` | Continua até sair da rotina atual. | Quando a análise interna terminou e deve voltar ao chamador. |
| `StopDebugging` | Encerra a sessão de depuração. | Ao concluir o diagnóstico, cancelar o objetivo ou atingir uma condição terminal. |

## Breakpoints

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `AddBreakpoint` | Adiciona um breakpoint em arquivo e linha válidos. | Antes de iniciar ou continuar para observar um ponto específico. |
| `RemoveBreakpoint` | Remove um breakpoint existente. | Quando o ponto não é mais necessário ou interfere no fluxo. |

## Sessão, expressões e watches

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `EvaluateDebuggerExpression` | Avalia uma expressão segura no frame pausado. | Para consultar variável, campo ou expressão sem chamar código com efeitos colaterais. |
| `AddDebuggerWatch` | Adiciona uma expressão à lista controlada de watches. | Quando um valor deve ser acompanhado ao longo de vários passos. |
| `RemoveDebuggerWatch` | Remove um watch controlado. | Quando a expressão não precisa mais ser monitorada. |
| `ListDebuggerWatches` | Lista os watches mantidos pelo RadIA. | Antes de avaliar ou reorganizar o conjunto acompanhado. |
| `EvaluateDebuggerWatches` | Avalia os watches no frame atual. | Após uma pausa ou step para comparar os valores observados. |
| `StartDebugging` | Inicia o projeto ativo sob o debugger. | Depois de build bem-sucedido e consentimento específico de execução. |

## Conhecimento do projeto

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `IndexProjectKnowledge` | Constrói ou atualiza o índice local do projeto. | Na primeira busca, após mudanças relevantes ou por solicitação explícita. |
| `SearchProjectKnowledge` | Pesquisa arquivos e trechos e oferece abertura direta da origem no chat. | Quando o agente precisa localizar contexto além da unit ativa. |
| `GetKnowledgeStatus` | Informa estado, contagem e atualização do índice. | Para decidir se uma busca pode ser usada ou se é preciso reindexar. |
| `GetKnowledgeDocument` | Recupera chunks e oferece abertura direta da origem no chat. | Depois que a busca identifica um resultado que precisa de leitura detalhada. |
| `ClearProjectKnowledge` | Remove o índice reconstruível do projeto. | Para corrigir inconsistências, atender privacidade ou forçar reconstrução. |

## Testes DUnitX

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `RunDUnitXTests` | Executa o runner autorizado e interpreta o relatório NUnit XML. | Depois do build ou quando o objetivo exige validar testes. |
| `CancelDUnitXTests` | Solicita o encerramento da execução de testes. | Pelo usuário, agente ou timeout. |
| `GetDUnitXStatus` | Retorna progresso, resultado e artefatos da execução. | Enquanto o agente acompanha os testes ou coleta falhas. |

## Cobertura de código

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetCoverageSummary` | Lê o bloco `stats` do relatório oficial do Delphi Code Coverage, confinado ao projeto ativo. | Depois dos testes, quando `CodeCoverage_Summary.xml` está disponível para registrar percentual, linhas e arquivos cobertos. |

## Timeline de debug

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetDebugTimeline` | Retorna eventos recentes de processo, estado, breakpoint e memória. | Para acompanhar a sessão sem polling destrutivo e explicar a sequência do debug. |

## Git local

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetGitStatus` | Consulta branch e alterações do repositório do projeto ativo. | Antes de editar, revisar ou preparar um commit. |
| `GetGitDiff` | Retorna o diff permitido para revisão. | Para verificar o resultado das mudanças e selecionar caminhos. |
| `PreviewGitCommit` | Prepara mensagem, arquivos e fingerprint sem criar o commit. | Quando o objetivo solicita um commit local revisável. |
| `CommitChanges` | Revalida o preview e cria somente o commit local. | Depois da revisão, consentimento e confirmação do fingerprint. |

## Exemplos de acionamento

Por comando direto:

```text
/tool GetIDEState
/tool SearchProjectKnowledge {"query":"IRadIAToolRegistry","maxResults":10}
/tool BuildProject {"mode":"check"}
```

Por objetivo do agente:

```text
/agent run localize a origem do erro, prepare a correção, valide o build e execute os testes
```

Nesse exemplo, o agente pode combinar leitura do workspace, conhecimento local, patch, build,
mensagens do compilador e DUnitX. A seleção exata depende do plano aprovado e dos resultados de
cada etapa.

Por MCP, consulte primeiro `tools/list` e depois use `tools/call`. Veja
[Integração MCP](mcp_integration_guide.md).

## Limites importantes

- A presença no catálogo não garante que a ferramenta seja válida no estado atual da IDE.
- Designer exige formulário e contexto de design compatíveis.
- Avaliação e call stack exigem debugger pausado e frame válido.
- Build, testes, execução, Git e mutações podem exigir consentimento.
- `Apply` e `Revert` dependem do identificador e das precondições produzidos pela etapa anterior.
- Paths fora do workspace, conteúdo desatualizado e operações não suportadas são recusados.
