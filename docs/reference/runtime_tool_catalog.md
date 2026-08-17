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

## Ambiente Delphi

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetDelphiEnvironmentProfile` | Retorna perfil sanitizado da IDE, projeto, paths, packages e bibliotecas. | `RadIA.Core.DelphiEnvironmentTools.pas` |

## Geração semântica de código

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareMissingMembers` | Localiza contratos de interfaces ainda não implementados e prepara um patch idempotente com declarações e implementações. | `RadIA.Core.SemanticMemberTools.pas` |

## Consultas ao índice semântico

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetSemanticContext` | Retorna declarações indexadas e membros resolvidos por herança para um símbolo Delphi. | `RadIA.Core.SemanticQueryTools.pas` |
| `FindSymbolReferences` | Localiza declarações e referências confirmadas de um símbolo em Pascal e DFM, com arquivo, linha e coluna. | `RadIA.Core.SemanticQueryTools.pas` |

## Hierarquia semântica de tipos

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetTypeHierarchy` | Retorna ancestrais e descendentes de um tipo Delphi indexado, com profundidade e indicação de tipos externos. | `RadIA.Core.SemanticHierarchyTools.pas` |

## Refatoração semântica

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareRenameSymbol` | Prepara uma renomeação semântica exata em Pascal e DFM, incluindo arquivos fechados e, opcionalmente, membros coordenados entre ancestrais e overrides. | `RadIA.Core.SemanticRefactoringTools.pas` |

## Refatoração semântica de assinaturas

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareChangeSignature` | Prepara uma alteração transacional da assinatura de uma rotina Delphi em declarações, implementação e chamadas comprovadas. | `RadIA.Core.SemanticChangeSignatureTools.pas` |

## Extração semântica de métodos

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareExtractMethod` | Prepara a extração transacional da seleção ativa para um novo método Delphi, inferindo parâmetros e atualizando declaração, implementação e chamada. | `RadIA.Core.SemanticExtractMethodTools.pas` |

## Movimentação semântica de tipos

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareMoveType` | Prepara a movimentação transacional de um tipo Delphi entre units do projeto, incluindo declaração, métodos, dependências e consumidores confirmados. | `RadIA.Core.SemanticMoveTypeTools.pas` |

## Validação unificada de código Delphi

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `ValidateDelphiCode` | Normaliza regras nativas, Check opcional do compilador, DelphiLint isolado e Sonar; também retorna correções estruturadas disponíveis. | `RadIA.Core.CodeValidationTools.pas` |

## Correções da validação de código

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareCodeValidationFix` | Converte uma correção sugerida pelo DelphiLint em preview limitado, com revisão e fingerprint do conteúdo atual. | `RadIA.Core.CodeValidationFixes.pas` |

## Orientação Delphi curada

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GetDelphiGuidance` | Retorna regras Delphi versionadas e citáveis filtradas pelo ambiente e tópico. | `RadIA.Core.DelphiGuidanceTools.pas` |

## Consistência entre DFM e Pascal

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `AuditActiveDfmPasConsistency` | Audita componentes, campos, classes e eventos do form ativo sem alterar arquivos. | `RadIA.Core.DfmPasAuditTools.pas` |
| `PrepareDfmPasAuditFix` | Prepara um patch revisável para um handler ou campo ausente suportado. | `RadIA.Core.DfmPasAuditTools.pas` |

## Diff visual do Designer

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `CaptureDesignerVisualSnapshot` | Captura em memória componentes, bounds, parent, seleção e propriedades permitidas do form ativo. | `RadIA.Core.DesignerVisualDiffTools.pas` |
| `CompareDesignerVisualSnapshots` | Produz uma comparação antes/depois pronta para a timeline, incluindo estrutura, layout e propriedades. | `RadIA.Core.DesignerVisualDiffTools.pas` |
| `DecideDesignerVisualDiff` | Registra aceite ou rejeição final sem modificar o Designer. | `RadIA.Core.DesignerVisualDiffTools.pas` |
| `ClearDesignerVisualDiffArtifacts` | Limpa snapshots e comparações mantidos somente em memória. | `RadIA.Core.DesignerVisualDiffTools.pas` |

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
| `GetEditorSemanticContext` | Resume a unit ativa, o símbolo atual, imports e declarações próximas. | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToFile` | Abre um arquivo pertencente a um projeto carregado e posiciona o cursor. | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToSymbol` | Posiciona o editor em um símbolo da unit ativa. | `RadIA.Core.IDENavigationTools.pas` |
| `NavigateToDevelopmentSurface` | Mapeia uma intenção ou superfície para Code ou Design. | `RadIA.Core.IDENavigationTools.pas` |
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
| `DecideBlockReview` | Registra aceitar, rejeitar, editar ou solicitar alterações com comentário sem mudar o buffer. | `RadIA.Core.BlockReviewTools.pas` |
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

## Artefatos de produtividade seguros

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareApiDocumentation` | Prepara `API.md` determinístico com a API pública indexada do projeto. | `RadIA.Core.ProductivityGenerationTools.pas` |
| `PrepareMockUnit` | Prepara uma unit de mock isolada para uma interface indexada. | `RadIA.Core.ProductivityGenerationTools.pas` |
| `ApplyGeneratedArtifact` | Cria atomicamente o artefato revisado e registra a unit somente quando solicitado. | `RadIA.Core.ProductivityGenerationTools.pas` |
| `RevertGeneratedArtifact` | Remove o artefato criado se seu conteúdo permanecer inalterado. | `RadIA.Core.ProductivityGenerationTools.pas` |

## Diagnóstico de stack trace do projeto

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `AnalyzeProjectStackTrace` | Importa traces Delphi, MadExcept ou EurekaLog e resolve frames entre units do projeto. | `RadIA.Core.StackTraceTools.pas` |

## Análise Clean Uses

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareCleanUses` | Prepara uma remoção conservadora de imports sem uso usando o índice semântico. | `RadIA.Core.CleanUsesTools.pas` |

## Segurança de threads e PPL

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `AnalyzeThreadingRisks` | Detecta acesso VCL inseguro, ausência de cancelamento e tratamento de exceções. | `RadIA.Core.ThreadingAssistantTools.pas` |
| `PrepareThreadModernization` | Valida as proteções e prepara um patch revisável e reversível. | `RadIA.Core.ThreadingAssistantTools.pas` |

## Retrofit OpenAPI de APIs existentes

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `InventoryExistingApiRoutes` | Inventaria rotas DEXT minimalistas e atributos de controllers nas units existentes. | `RadIA.Core.OpenApiRetrofitTools.pas` |
| `PrepareOpenApiRetrofit` | Adiciona imports, metadados OpenAPI e middleware Swagger em um preview reversível da unit Startup. | `RadIA.Core.OpenApiRetrofitTools.pas` |

## Modernização DEXT e de forms

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareDextFormModernization` | Exige migração validada, paridade, fronteira DEXT, responsabilidade extraída e consistência DFM/PAS antes do preview multiarquivo. | `RadIA.Core.DextFormModernizationTools.pas` |
| `RecordDextFormModernizationGate` | Registra evidências de build/testes e reverte o preview aplicado quando um gate falha. | `RadIA.Core.DextFormModernizationTools.pas` |

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
| `GetAdvancedBreakpointCapabilities` | Informa quais recursos avançados de breakpoint estão realmente disponíveis no Delphi 12 e 13 e explica limitações da OTA. | `RadIA.Core.DebuggerBreakpointTools.pas` |
| `ConfigureBreakpoint` | Altera somente os campos informados de um breakpoint existente e devolve a configuração anterior para reversão. | `RadIA.Core.DebuggerBreakpointTools.pas` |

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

## Testes DUnitX selecionados por impacto

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PlanImpactedDUnitXTests` | Calcula e explica o menor conjunto seguro de fixtures DUnitX afetadas por arquivos modificados. | `RadIA.Core.TestImpactTools.pas` |
| `RunImpactedDUnitXTests` | Planeja e executa as fixtures afetadas ou toda a suíte quando a seleção não pode ser provada. | `RadIA.Core.TestImpactTools.pas` |

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

## Instrumentação VCL runtime reversível

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareRuntimeVclInstrumentation` | Analisa o projeto VCL ativo em Debug e prepara, sem alterar arquivos, a inclusão temporária do adaptador autenticado que enxerga controles VCL sem janela própria. | `RadIA.Core.RuntimeVclInstrumentation.pas` |
| `ApplyRuntimeVclInstrumentation` | Aplica exatamente o preview revisado ao DPR e cria as quatro units isoladas em `.radia/runtime`. | `RadIA.Core.RuntimeVclInstrumentation.pas` |
| `RevertRuntimeVclInstrumentation` | Restaura o DPR original e remove somente as units geradas que continuam inalteradas. | `RadIA.Core.RuntimeVclInstrumentation.pas` |

## Performance runtime comparável

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `BeginRuntimePerformanceMeasurement` | Inicia amostragem limitada de CPU, memória e responsividade da janela para a sessão e o cenário já preparados. | `RadIA.Core.RuntimePerformance.pas` |
| `CompleteRuntimePerformanceMeasurement` | Encerra a amostragem e gera evidência somente se o mesmo cenário terminou com sucesso na mesma sessão e build. | `RadIA.Core.RuntimePerformance.pas` |
| `CompareRuntimePerformanceEvidence` | Compara duração, CPU, picos de working set/private bytes e amostras sem resposta entre dois builds. | `RadIA.Core.RuntimePerformance.pas` |
| `CancelRuntimePerformanceMeasurement` | Interrompe a amostragem ativa sem criar evidência. | `RadIA.Core.RuntimePerformance.pas` |

## Diagnóstico de consultas FireDAC

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `AnalyzeFireDACQuery` | Analisa SQL limitado, statements e placeholders sem executar ou devolver o texto da consulta. | `RadIA.Core.FireDAC.Tools.pas` |
| `ValidateFireDACParameters` | Valida nomes, tipos, direção, tamanho e estado null dos bindings sem executar SQL. | `RadIA.Core.FireDAC.Tools.pas` |
| `ExplainFireDACQuery` | Estrutura fatos, hipóteses e limitações para explicação por IA sem ecoar o SQL. | `RadIA.Core.FireDAC.Tools.pas` |
| `ExplainFireDACFinding` | Estrutura um finding para explicação por IA sem aceitar evidência livre ou segredos. | `RadIA.Core.FireDAC.Tools.pas` |

## Previews seguros de artefatos FireDAC

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `GenerateFireDACRepositoryPreview` | Prepara uma unit de repository FireDAC determinística sem criar arquivos. | `RadIA.Core.FireDAC.Generation.pas` |
| `GenerateFireDACDataModulePreview` | Prepara uma unit de DataModule com conexão FireDAC de ownership explícito. | `RadIA.Core.FireDAC.Generation.pas` |
| `GenerateFireDACQueryPreview` | Prepara uma unit isolada de configuração de `TFDQuery` sem executar SQL. | `RadIA.Core.FireDAC.Generation.pas` |
| `GenerateFireDACDTOPreview` | Prepara uma unit DTO mínima e determinística. | `RadIA.Core.FireDAC.Generation.pas` |
| `GenerateFireDACTests` | Prepara uma fixture DUnitX para o artefato FireDAC sem gravá-la. | `RadIA.Core.FireDAC.Generation.pas` |

## Planos FireDAC orientados por evidências

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareFireDACQueryOptimization` | Prepara um plano de otimização sem executar SQL e mantém ganhos sem plano de execução como hipóteses. | `RadIA.Core.FireDAC.Plans.pas` |
| `PrepareFireDACThreadSafetyPlan` | Prepara um plano de isolamento de conexão, dataset, transação e UI por worker. | `RadIA.Core.FireDAC.Plans.pas` |

## Correções FireDAC reversíveis

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `PrepareFireDACParameterFix` | Prepara uma troca determinística de accessor de parâmetro para um finding comprovado. | `RadIA.Core.FireDAC.Fixes.pas` |
| `PrepareFireDACTransactionFix` | Prepara a inclusão determinística de rollback para um finding comprovado. | `RadIA.Core.FireDAC.Fixes.pas` |
| `PrepareFireDACFix` | Encaminha uma regra FireDAC suportada e comprovada ao preparador determinístico correspondente. | `RadIA.Core.FireDAC.Fixes.pas` |
| `ApplyFireDACFix` | Aplica somente preview pertencente ao Advisor e com fingerprint ainda válido. | `RadIA.Core.FireDAC.Fixes.pas` |
| `RevertFireDACFix` | Reverte somente uma correção FireDAC aplicada e ainda sem alterações posteriores. | `RadIA.Core.FireDAC.Fixes.pas` |

## Diagnóstico do ecossistema Delphi

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `InspectFireDACUsage` | Mantém as contagens legadas e retorna o mesmo inventário estruturado da inspeção de projeto. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `InspectFireDACProject` | Inventaria componentes e relações FireDAC em PAS e DFM limitados, sem executar SQL nem coletar credenciais. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `GetFireDACProjectReport` | Agrega inventário e análise sanitizada do SQL FireDAC embutido. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `AuditFireDACTransactions` | Audita fluxos transacionais em arquivos Pascal limitados, sem executar SQL ou conectar ao banco. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `InspectFireDACConfiguration` | Inspeciona configuração FireDAC limitada, descartando credenciais e paths absolutos. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `DiagnoseFireDACEnvironment` | Diagnostica estaticamente DriverID e driver links sem conectar nem instalar componentes. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `AnalyzeFireDACThreadSafety` | Localiza componentes FireDAC compartilhados e acesso inseguro à UI em workers limitados. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `DiagnoseDelphiDependencies` | Verifica paths declarados no projeto e manifestos de dependências sem instalar componentes. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `AuditDelphiLocalization` | Localiza textos visíveis em Pascal e DFM candidatos a `resourcestring`. | `RadIA.Core.DelphiEcosystemTools.pas` |
| `PrepareLocalizationExtraction` | Prepara um patch imutável que move um literal da unit ativa para `resourcestring`, sem aplicar alterações. | `RadIA.Core.DelphiEcosystemTools.pas` |

## Inspeção segura de banco local

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `InspectLocalSQLiteDatabase` | Lê tabelas, views e colunas de um arquivo SQLite dentro do workspace sem executar SQL fornecido pelo usuário. | `RadIA.Core.LocalDatabaseTools.pas` |
| `PreviewLocalSQLiteQuery` | Executa uma única consulta somente leitura, limita o resultado a 500 linhas e oculta colunas sensíveis no grid e no CSV. | `RadIA.Core.LocalDatabaseTools.pas` |
| `CompareFireDACCodeWithSchema` | Compara expectativas FireDAC tipadas com um schema SQLite local autorizado e read-only. | `RadIA.Core.LocalDatabaseTools.pas` |
| `GenerateFireDACSchemaReport` | Gera um relatório FireDAC sanitizado do schema SQLite local sem consultar linhas. | `RadIA.Core.LocalDatabaseTools.pas` |

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

## Mentor Delphi

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `ExplainSelectedDelphiCode` | Monta uma explicação por nível, ancorada na seleção atual e em regras citadas. | `RadIA.Core.DelphiMentor.pas` |

## Migração de acesso a dados legado

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `InventoryLegacyDataAccess` | Inventaria referências a BDE, ADO e dbExpress no projeto ativo. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `PlanLegacyMigrationBatches` | Agrupa os achados por tecnologia e arquivo em lotes limitados. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `PrepareLegacyMigrationBatch` | Prepara um preview reversível somente para substituições determinísticas. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `RecordLegacyMigrationGate` | Registra evidências de build e testes e reverte o lote aplicado se um gate falhar. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `GetLegacyMigrationReport` | Consolida compatibilidade, gates e ações manuais pendentes. | `RadIA.Core.LegacyDataMigrationTools.pas` |
| `PlanDextAndFormModernization` | Planeja DEXT e decomposição de forms sem reescrita automática. | `RadIA.Core.LegacyDataMigrationTools.pas` |

## Correção orientada por evidências de memória

| Ferramenta | O que faz | Unit de origem |
|---|---|---|
| `CompareMemoryDiagnosticEvidence` | Compara baseline e verificação de builds distintos sob o mesmo cenário e classifica como `fixed`, `improved`, `unchanged`, `regressed` ou `incomparable`. | `RadIA.Core.MemoryEvidence.pas` |
| `PrepareMemoryDiagnosticFix` | Escolhe o primeiro frame do projeto, informa arquivo, linha, rotina e número da alocação e encaminha a edição ao `PreparePatch`. | `RadIA.Core.MemoryEvidence.pas` |

## Resumo

- Grupos registrados: 68
- Ferramentas internas registradas: 211
- Extensões podem registrar ferramentas adicionais em runtime.
- O comando `/tools` permanece autoritativo para a instância ativa da IDE.
