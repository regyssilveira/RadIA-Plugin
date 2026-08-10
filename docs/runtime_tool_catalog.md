# Catálogo de ferramentas internas do RadIA

> Gerado pelo manifesto do runtime e pela referência operacional. Não edite manualmente. Execute `scripts/Update-RadIA.RuntimeToolCatalog.ps1`.

Esta lista contém somente as ferramentas internas registradas pelo pacote atual. Ideias de arquitetura e roadmap permanecem em `tool_catalog.md`.

## Workspace e editor

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetIDEState` | Retorna versão, arquitetura e estado geral da IDE. | `RadIA.Core.WorkspaceTools.pas` |
| `GetActiveProject` | Identifica o projeto ativo e seu caminho autorizado. | `RadIA.Core.WorkspaceTools.pas` |
| `GetActiveUnit` | Identifica a unit ativa no editor. | `RadIA.Core.WorkspaceTools.pas` |
| `ListOpenFiles` | Lista arquivos abertos e buffers disponíveis. | `RadIA.Core.WorkspaceTools.pas` |
| `ListProjectUnits` | Lista as units pertencentes ao projeto ativo. | `RadIA.Core.WorkspaceTools.pas` |
| `GetEditorContent` | Lê o conteúdo vivo de um buffer da IDE. | `RadIA.Core.WorkspaceTools.pas` |
| `GetEditorSelection` | Lê a seleção atual do editor. | `RadIA.Core.WorkspaceTools.pas` |
| `GetCursorPosition` | Retorna arquivo, linha e coluna do cursor. | `RadIA.Core.WorkspaceTools.pas` |
| `GetCompilerMessages` | Coleta erros e warnings estruturados. | `RadIA.Core.WorkspaceTools.pas` |

## Recuperação de resultados do agente

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetToolResultSummary` | Retorna hash, tamanho e step de um resultado integral preservado pelo agente. | `RadIA.Core.AgentResultTools.pas` |
| `GetToolResultRange` | Recupera um intervalo limitado do resultado integral sem reexecutar a ferramenta original. | `RadIA.Core.AgentResultTools.pas` |

## Saúde do projeto

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetProjectHealth` | Consolida configuração, build, mensagens, testes e sinais de manutenção do projeto ativo. | `RadIA.Core.ProjectHealthTools.pas` |

## Saúde da instalação

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetInstallationHealth` | Diagnostica rota efetiva, provider, CLI, MCP, terminal, chat, tools e instalação. | `RadIA.Core.InstallationHealthTools.pas` |
| `RunInstallationDeepDiagnostic` | Executa probes sanitizados de versão e autenticação da CLI efetiva e handshakes temporários de MCP externo. | `RadIA.Core.InstallationHealthTools.pas` |
| `GetRadIAStatus` | Retorna um inventário sanitizado e filtrável da configuração, disponibilidade e prontidão atuais do RadIA. | `RadIA.Core.InstallationHealthTools.pas` |

## Navegação na IDE e grafo do projeto

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `ListProjectGroupProjects` | Lista os projetos carregados no project group atual. | `RadIA.Core.IDENavigationTools.pas` |
| `GetProjectDependencies` | Consulta as dependências reais do projeto ativo pela OTA. | `RadIA.Core.IDENavigationTools.pas` |
| `GetUnitSymbols` | Extrai classes, records, interfaces e rotinas do buffer ativo com suas linhas. | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToFile` | Abre um arquivo pertencente a um projeto carregado e posiciona o cursor. | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToSymbol` | Posiciona o editor em um símbolo da unit ativa. | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToDevelopmentSurface` | Ativa Code ou Design no arquivo do projeto. | `RadIA.Core.IDENavigationTools.pas` |
| `ListIDEActions` | Lista somente ações disponíveis na allowlist segura. | `RadIA.Core.IDENavigationTools.pas` |
| `ExecuteIDEAction` | Executa uma ação allowlisted após consentimento. | `RadIA.Core.IDENavigationTools.pas` |

## Patches

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PreparePatch` | Produz preview e hash-base para uma alteração em um arquivo. | `RadIA.Core.PatchTools.pas` |
| `ApplyPatch` | Revalida o preview e aplica o patch ao buffer ou arquivo correto. | `RadIA.Core.PatchTools.pas` |
| `RevertPatch` | Restaura o conteúdo anterior quando as precondições continuam válidas. | `RadIA.Core.PatchTools.pas` |

## Patches em múltiplos arquivos

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareMultiFilePatch` | Cria um preview único para alterações coordenadas em vários arquivos. | `RadIA.Core.MultiFilePatchTools.pas` |
| `ApplyMultiFilePatch` | Aplica o conjunto depois de validar todos os arquivos. | `RadIA.Core.MultiFilePatchTools.pas` |
| `RevertMultiFilePatch` | Reverte o conjunto de arquivos de forma coordenada. | `RadIA.Core.MultiFilePatchTools.pas` |

## Revisões por bloco

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `ListBlockReviews` | Lista blocos ligados ao arquivo e à revisão-base, incluindo a decisão atual. | `RadIA.Core.BlockReviewTools.pas` |
| `DecideBlockReview` | Registra aceitar, rejeitar ou editar sem alterar o buffer. | `RadIA.Core.BlockReviewTools.pas` |
| `ApplyBlockReviews` | Compõe as decisões e aplica os arquivos em uma transação. | `RadIA.Core.BlockReviewTools.pas` |
| `ClearBlockReviews` | Descarta a sessão e suas decisões sem alterar arquivos. | `RadIA.Core.BlockReviewTools.pas` |

## Transações de desenvolvimento

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareDevelopmentTransaction` | Monta uma transação com mudanças de código, projeto e Designer. | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `ApplyDevelopmentTransaction` | Executa as etapas da transação e preserva dados de reversão. | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `RevertDevelopmentTransaction` | Desfaz as etapas aplicadas em ordem segura. | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `RejectDevelopmentTransactionStep` | Rejeita uma etapa pendente. | `RadIA.Core.DevelopmentTransactionTools.pas` |
| `RevertDevelopmentTransactionStep` | Reverte a última etapa aplicada. | `RadIA.Core.DevelopmentTransactionTools.pas` |

## Templates de projeto

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PreviewProjectTemplate` | Renderiza a árvore e os arquivos de um template sem gravá-los. | `RadIA.Core.ProjectTemplateTools.pas` |
| `CreateProjectFromTemplate` | Publica o projeto preparado usando staging e validações. | `RadIA.Core.ProjectTemplateTools.pas` |
| `RevertCreatedProject` | Remove de forma controlada os arquivos criados pela operação. | `RadIA.Core.ProjectTemplateTools.pas` |
| `OpenCreatedProject` | Abre na IDE o projeto que acabou de ser criado. | `RadIA.Core.ProjectTemplateTools.pas` |
| `ValidateCreatedProject` | Compila e valida a estrutura do projeto gerado. | `RadIA.Core.ProjectTemplateTools.pas` |

## Arquivos de projeto

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareAddProjectFile` | Prepara a criação e inclusão de uma unit ou form. | `RadIA.Core.ProjectFileTools.pas` |
| `PrepareRemoveProjectFile` | Prepara a remoção de uma unit ou form. | `RadIA.Core.ProjectFileTools.pas` |
| `ApplyProjectFileChange` | Efetiva a inclusão ou remoção preparada. | `RadIA.Core.ProjectFileTools.pas` |
| `RevertProjectFileChange` | Restaura a estrutura e os arquivos anteriores. | `RadIA.Core.ProjectFileTools.pas` |

## Revisões inline

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PublishInlineReview` | Publica uma observação ancorada em arquivo, hash e linhas. | `RadIA.Core.InlineReviewTools.pas` |
| `ListInlineReviews` | Lista as revisões inline atuais. | `RadIA.Core.InlineReviewTools.pas` |
| `PrepareInlineReviewFix` | Converte a sugestão de uma revisão em preview de patch. | `RadIA.Core.InlineReviewTools.pas` |
| `ApplyInlineReviewFix` | Aplica uma sugestão ancorada na revisão atual e remove a marca resolvida. | `RadIA.Core.InlineReviewTools.pas` |
| `RejectInlineReview` | Rejeita uma sugestão e remove sua marca sem alterar o buffer. | `RadIA.Core.InlineReviewTools.pas` |
| `RemoveInlineReview` | Remove uma revisão específica sem alterar o código. | `RadIA.Core.InlineReviewTools.pas` |
| `ClearInlineReviews` | Limpa as revisões do escopo solicitado. | `RadIA.Core.InlineReviewTools.pas` |

## Build

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `BuildProject` | Executa `make`, `build`, `check` ou `clean` com diagnóstico estruturado. | `RadIA.Core.BuildTools.pas` |
| `CancelBuild` | Solicita o cancelamento cooperativo do build ativo. | `RadIA.Core.BuildTools.pas` |
| `GetBuildStatus` | Retorna estado, duração e resultado do build controlado. | `RadIA.Core.BuildTools.pas` |

## Inspeção do Form Designer

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetActiveForm` | Identifica o formulário ativo e seu contexto de design. | `RadIA.Core.DesignerTools.pas` |
| `ListFormComponents` | Lista componentes, classes, propriedades básicas e hierarquia. | `RadIA.Core.DesignerTools.pas` |

## Layout do Form Designer

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareComponentLayout` | Cria preview de posição, tamanho, alinhamento ou ancoragem. | `RadIA.Core.DesignerMutationTools.pas` |
| `ApplyComponentLayout` | Aplica o layout depois de revalidar form e componente. | `RadIA.Core.DesignerMutationTools.pas` |
| `RevertComponentLayout` | Restaura o layout anterior. | `RadIA.Core.DesignerMutationTools.pas` |

## Propriedades do Form Designer

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareComponentProperty` | Prepara a mudança de uma propriedade compatível. | `RadIA.Core.DesignerPropertyTools.pas` |
| `ApplyComponentProperty` | Define a propriedade no Designer vivo. | `RadIA.Core.DesignerPropertyTools.pas` |
| `RevertComponentProperty` | Restaura o valor anterior da propriedade. | `RadIA.Core.DesignerPropertyTools.pas` |

## Componentes do Form Designer

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareAddFormComponent` | Prepara classe, nome, parent e posição de um novo componente. | `RadIA.Core.DesignerComponentTools.pas` |
| `PrepareRemoveFormComponent` | Prepara a remoção e captura o estado necessário à reversão. | `RadIA.Core.DesignerComponentTools.pas` |
| `ApplyFormComponentChange` | Adiciona ou remove o componente preparado. | `RadIA.Core.DesignerComponentTools.pas` |
| `RevertFormComponentChange` | Reverte a inclusão ou remoção. | `RadIA.Core.DesignerComponentTools.pas` |

## Eventos do Form Designer

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareFormEventHandler` | Prepara método, assinatura, corpo e vínculo do evento. | `RadIA.Core.DesignerEventTools.pas` |
| `ApplyFormEventHandler` | Cria o método e conecta o evento de forma coordenada. | `RadIA.Core.DesignerEventTools.pas` |
| `RevertFormEventHandler` | Remove ou restaura o método e o vínculo anteriores. | `RadIA.Core.DesignerEventTools.pas` |

## Inspeção do debugger

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetDebuggerState` | Retorna estado, processo, thread e localização atuais. | `RadIA.Core.DebuggerTools.pas` |
| `ListBreakpoints` | Lista breakpoints conhecidos pela IDE. | `RadIA.Core.DebuggerTools.pas` |
| `GetCallStack` | Retorna a pilha do thread e frame atuais. | `RadIA.Core.DebuggerTools.pas` |

## Controle do debugger

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PauseDebugging` | Solicita a pausa da aplicação em execução. | `RadIA.Core.DebuggerControlTools.pas` |
| `ContinueDebugging` | Retoma uma sessão pausada. | `RadIA.Core.DebuggerControlTools.pas` |
| `StepInto` | Avança entrando na rotina chamada. | `RadIA.Core.DebuggerControlTools.pas` |
| `StepOver` | Executa a linha atual sem entrar nas chamadas. | `RadIA.Core.DebuggerControlTools.pas` |
| `StepOut` | Continua até sair da rotina atual. | `RadIA.Core.DebuggerControlTools.pas` |
| `StopDebugging` | Encerra a sessão de depuração. | `RadIA.Core.DebuggerControlTools.pas` |

## Breakpoints do debugger

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `AddBreakpoint` | Adiciona um breakpoint em arquivo e linha válidos. | `RadIA.Core.DebuggerBreakpointTools.pas` |
| `RemoveBreakpoint` | Remove um breakpoint existente. | `RadIA.Core.DebuggerBreakpointTools.pas` |

## Sessões do debugger e watches

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `EvaluateDebuggerExpression` | Avalia uma expressão segura no frame pausado. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `AddDebuggerWatch` | Adiciona uma expressão à lista controlada de watches. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `RemoveDebuggerWatch` | Remove um watch controlado. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `ListDebuggerWatches` | Lista os watches mantidos pelo RadIA. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `EvaluateDebuggerWatches` | Avalia os watches no frame atual. | `RadIA.Core.DebuggerInspectionTools.pas` |
| `StartDebugging` | Valida e enfileira a ação Run oficial da IDE sem bloquear o request MCP. | `RadIA.Core.DebuggerInspectionTools.pas` |

## Conhecimento do projeto

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `IndexProjectKnowledge` | Constrói ou atualiza o índice local do projeto. | `RadIA.Core.KnowledgeTools.pas` |
| `SearchProjectKnowledge` | Pesquisa arquivos e trechos e oferece abertura direta da origem no chat. | `RadIA.Core.KnowledgeTools.pas` |
| `GetKnowledgeStatus` | Informa estado, contagem e atualização do índice. | `RadIA.Core.KnowledgeTools.pas` |
| `GetKnowledgeDocument` | Recupera chunks e oferece abertura direta da origem no chat. | `RadIA.Core.KnowledgeTools.pas` |
| `ClearProjectKnowledge` | Remove o índice reconstruível do projeto. | `RadIA.Core.KnowledgeTools.pas` |

## Execução de testes DUnitX

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `RunDUnitXTests` | Executa o runner autorizado e interpreta o relatório NUnit XML. | `RadIA.Core.DUnitXTools.pas` |
| `CancelDUnitXTests` | Solicita o encerramento da execução de testes. | `RadIA.Core.DUnitXTools.pas` |
| `GetDUnitXStatus` | Retorna progresso, resultado e artefatos da execução. | `RadIA.Core.DUnitXTools.pas` |

## Evidências de cobertura de código

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetCoverageSummary` | Lê o bloco `stats` do relatório oficial do Delphi Code Coverage, confinado ao projeto ativo. | `RadIA.Core.CoverageTools.pas` |

## Linha do tempo de eventos do debugger

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetDebugTimeline` | Retorna eventos recentes de processo, estado, breakpoint e memória. | `RadIA.Core.DebugTimelineTools.pas` |

## Correlação do debugger em runtime

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetRuntimeDebugSession` | Retorna sessão, PID real, projeto, executável, build e última sequência correlacionados. | `RadIA.Core.RuntimeDebugTools.pas` |
| `WaitForDebuggerEvent` | Aguarda estados do processo sem busy-wait e inclui a pilha quando ocorre parada ou exceção. | `RadIA.Core.RuntimeDebugTools.pas` |
| `CancelDebuggerWait` | Interrompe imediatamente a espera ativa. | `RadIA.Core.RuntimeDebugTools.pas` |

## Descoberta de janelas em runtime

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetRuntimeWindows` | Lista janelas autorizadas com ID opaco, processo, classe, texto sanitizado, proprietário, estado e capacidades. No IDE64, a identidade permanece segura mesmo quando uma aplicação Win32 não expõe o texto. | `RadIA.Core.RuntimeDiscoveryTools.pas` |
| `GetRuntimeControlTree` | Retorna a hierarquia sanitizada dos controles com janela própria, sem aceitar ou expor `HWND`. | `RadIA.Core.RuntimeDiscoveryTools.pas` |

## Cenários limitados de runtime

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareRuntimeScenario` | Valida ações, alvos, capacidades, duração, repetições e cria um preview com fingerprint. Alvos que só aparecem após uma ação anterior são validados dinamicamente na execução. | `RadIA.Core.RuntimeScenarioTools.pas` |
| `RunRuntimeScenario` | Revalida a sessão e executa exatamente o preview aprovado, restringindo seletores à janela raiz visível e habilitada do processo correlacionado. | `RadIA.Core.RuntimeScenarioTools.pas` |
| `CancelRuntimeScenario` | Interrompe a execução ou uma espera ativa sem solicitar consentimento. | `RadIA.Core.RuntimeScenarioTools.pas` |
| `GetRuntimeScenarioStatus` | Retorna estado, repetição, ação atual, total concluído e eventual falha. | `RadIA.Core.RuntimeScenarioTools.pas` |

## Captura visual runtime

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `CaptureRuntimeVisual` | Captura um PNG limitado da janela visível e restaurada pertencente ao PID da sessão atual, mantém a imagem em memória e publica anterior/posterior no card local do chat. | `RadIA.Core.RuntimeVisualTools.pas` |

## Evidências de diagnóstico em runtime

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `CaptureRuntimeEvidence` | Registra sessão, build, cenário, último evento, pilha e até dez expressões em uma evidência sanitizada e identificada por fingerprint. | `RadIA.Core.RuntimeEvidenceTools.pas` |
| `CompareRuntimeEvidence` | Compara uma evidência de falha com outra de verificação e informa se são comparáveis e se a falha foi removida. | `RadIA.Core.RuntimeEvidenceTools.pas` |

## Regressões versionadas de runtime

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareRuntimeRegression` | Valida um cenário com seletores repetíveis, rejeita IDs ligados à sessão e cria o preview do artefato. | `RadIA.Core.RuntimeRegressionTools.pas` |
| `SaveRuntimeRegression` | Grava o preview em `.radia/runtime-scenarios/<id>.json` com schema, fingerprint e escrita atômica. | `RadIA.Core.RuntimeRegressionTools.pas` |
| `RevertRuntimeRegression` | Restaura o artefato anterior ou remove o arquivo criado pela aplicação correspondente. | `RadIA.Core.RuntimeRegressionTools.pas` |
| `ListRuntimeRegressions` | Lista os cenários versionados do projeto ativo. | `RadIA.Core.RuntimeRegressionTools.pas` |
| `PrepareSavedRuntimeScenario` | Valida a integridade do artefato, religa seletores persistidos à sessão atual e cria um preview executável. | `RadIA.Core.RuntimeRegressionTools.pas` |

## Commits Git locais revisáveis

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetGitStatus` | Consulta branch e alterações do repositório do projeto ativo. | `RadIA.Core.GitTools.pas` |
| `GetGitDiff` | Retorna o diff permitido para revisão. | `RadIA.Core.GitTools.pas` |
| `PreviewGitCommit` | Prepara mensagem, arquivos e fingerprint sem criar o commit. | `RadIA.Core.GitTools.pas` |
| `CommitChanges` | Revalida o preview e cria somente o commit local. | `RadIA.Core.GitTools.pas` |

## Diagnóstico de memória com FastMM5

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetMemoryDiagnosticsStatus` | Verifica diretório, versão, aceite de licença e DLL de diagnóstico do FastMM5 para a plataforma atual. | `RadIA.Core.FastMM5.pas` |
| `ConfigureMemoryDiagnostics` | Salva o diretório fornecido pelo usuário e o aceite explícito da licença do FastMM5, retornando a prontidão resultante. | `RadIA.Core.FastMM5.pas` |

## Instrumentação reversível de memória

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareMemoryInstrumentation` | Cria um preview com fingerprint para inserir o FastMM5 primeiro no projeto e habilitar diagnósticos somente em Debug. | `RadIA.Core.MemoryInstrumentation.pas` |
| `ApplyMemoryInstrumentation` | Revalida o fingerprint e aplica o preview ao buffer vivo do DPR com suporte ao Undo da IDE. | `RadIA.Core.MemoryInstrumentation.pas` |
| `RevertMemoryInstrumentation` | Restaura exatamente o conteúdo do DPR capturado antes da instrumentação. | `RadIA.Core.MemoryInstrumentation.pas` |

## Evidências de logs do FastMM5

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `ParseMemoryDiagnosticLog` | Interpreta um log FastMM5 limitado e autorizado, agrupando eventos, bytes, classes, stacks, linhas e fingerprints. | `RadIA.Core.FastMM5LogParser.pas` |

## Sessões compostas de diagnóstico de memória

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareMemoryDiagnosticSession` | Prepara um preview único com instrumentação, aquecimento, repetições e cenário runtime, sem executar o projeto. | `RadIA.Core.MemoryDiagnosticSession.pas` |
| `RunMemoryDiagnosticSession` | Instrumenta, compila, inicia somente o processo supervisionado, executa o cenário, coleta o log e restaura o DPR. | `RadIA.Core.MemoryDiagnosticSession.pas` |
| `CancelMemoryDiagnosticSession` | Cancela build, cenário e somente o processo supervisionado pela sessão de memória ativa. | `RadIA.Core.MemoryDiagnosticSession.pas` |
| `GetMemoryDiagnosticSessionStatus` | Informa a fase atual, mensagem operacional, preview e estado de cancelamento. | `RadIA.Core.MemoryDiagnosticSession.pas` |

## Correção orientada por evidências de memória

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `CompareMemoryDiagnosticEvidence` | Compara baseline e verificação de builds distintos sob o mesmo cenário e classifica como `fixed`, `improved`, `unchanged`, `regressed` ou `incomparable`. | `RadIA.Core.MemoryEvidence.pas` |
| `PrepareMemoryDiagnosticFix` | Escolhe o primeiro frame do projeto, informa arquivo, linha, rotina e número da alocação e encaminha a edição ao `PreparePatch`. | `RadIA.Core.MemoryEvidence.pas` |

## Resumo

- Grupos registrados: 38
- Ferramentas internas registradas: 132
- Extensões podem registrar ferramentas adicionais em runtime.
- O comando `/tools` permanece autoritativo para a instância ativa da IDE.
