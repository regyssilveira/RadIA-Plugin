# Referência operacional das ferramentas internas

Esta página explica as 187 ferramentas internas do RadIA: o que cada uma faz e em qual etapa
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

## Ambiente Delphi

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetDelphiEnvironmentProfile` | Retorna perfil sanitizado da IDE, projeto, paths, packages e bibliotecas. | Antes de sugerir APIs, componentes ou migrações dependentes do ambiente Delphi. |

## Geração semântica de código

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareMissingMembers` | Localiza contratos de interfaces ainda não implementados e prepara um patch idempotente com declarações e implementações. | Quando o agente precisa completar uma classe; depois da revisão, `ApplyPatch` solicita consentimento e aplica a mudança com undo. |

## Consultas ao índice semântico

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetSemanticContext` | Retorna declarações indexadas e membros resolvidos por herança para um símbolo Delphi. | Quando o agente precisa compreender um tipo além da unit atual; Ghost Text, navegação e auditoria DFM/PAS usam o mesmo serviço automaticamente e voltam ao contexto limitado se o motor estiver indisponível. |
| `FindSymbolReferences` | Localiza declarações e referências confirmadas de um símbolo em Pascal e DFM, com arquivo, linha e coluna. | Quando o usuário pede usos ou referências; homônimos exigem a unit e ocorrências ambíguas só aparecem quando solicitadas como candidatas. |
| `GetTypeHierarchy` | Retorna ancestrais e descendentes de um tipo Delphi indexado, com profundidade e indicação de tipos externos. | Quando o usuário ou o agente precisa compreender herança antes de navegar, refatorar ou avaliar impacto; homônimos exigem a unit. |
| `PrepareRenameSymbol` | Prepara uma renomeação semântica exata em Pascal e DFM, incluindo arquivos fechados e, opcionalmente, membros coordenados entre ancestrais e overrides. | Quando o usuário pede para renomear um símbolo; para hierarquias use `container`, `unit`, `includeHierarchy` e `signature` em overloads. Sempre produz preview para aplicação e rollback multiarquivo. |
| `PrepareChangeSignature` | Prepara uma alteração transacional da assinatura de uma rotina Delphi em declarações, implementação e chamadas comprovadas. | Quando parâmetros precisam ser adicionados, removidos, renomeados ou reordenados; exige mappings explícitos, bindings para novos argumentos e bloqueia referências ambíguas. |
| `PrepareExtractMethod` | Prepara a extração transacional da seleção ativa para um novo método Delphi, inferindo parâmetros e atualizando declaração, implementação e chamada. | Quando um bloco coeso de um método deve virar outro método; exige seleção estruturalmente segura, classe e identidade semântica não ambígua e produz preview reversível. |
| `PrepareMoveType` | Prepara a movimentação transacional de um tipo Delphi entre units do projeto, incluindo declaração, métodos, dependências e consumidores confirmados. | Quando uma classe, interface, record ou helper de nível superior deve mudar de unit; bloqueia DFM, recursos, dependências privadas, referências ambíguas e ciclos de interface antes do preview reversível. |

## Validação unificada de código Delphi

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `ValidateDelphiCode` | Normaliza regras nativas, Check opcional do compilador, DelphiLint isolado e Sonar; também retorna correções estruturadas disponíveis. | Quando o usuário pede para validar a unit ativa ou o projeto; cada fonte informa seu estado e a ação necessária. |

## Correções da validação de código

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareCodeValidationFix` | Converte uma correção sugerida pelo DelphiLint em preview limitado, com revisão e fingerprint do conteúdo atual. | Após `ValidateDelphiCode` retornar uma correção; apenas prepara a alteração. A aplicação continua exigindo consentimento por `ApplyPatch` e pode ser revertida. |

## Orientação Delphi curada

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetDelphiGuidance` | Retorna regras Delphi versionadas e citáveis filtradas pelo ambiente e tópico. | Antes de gerar ou revisar código cuja correção dependa de linguagem, memória, threads, VCL, FMX, Designer ou IDE64. |

## Consistência entre DFM e Pascal

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `AuditActiveDfmPasConsistency` | Audita componentes, campos, classes e eventos do form ativo sem alterar arquivos. | Antes de modificar um form ou ao investigar erros de streaming, handlers e campos divergentes. |
| `PrepareDfmPasAuditFix` | Prepara um patch revisável para um handler ou campo ausente suportado. | Depois da auditoria, somente quando o achado tem correção automática segura; aplicação e rollback usam as tools de patch existentes. |

## Diff visual do Designer

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `CaptureDesignerVisualSnapshot` | Captura em memória componentes, bounds, parent, seleção e propriedades permitidas do form ativo. | Antes e depois de uma proposta visual autorizada no Form Designer. |
| `CompareDesignerVisualSnapshots` | Produz uma comparação antes/depois pronta para a timeline, incluindo estrutura, layout e propriedades. | Depois das duas capturas, antes de decidir sobre a proposta visual. |
| `DecideDesignerVisualDiff` | Registra aceite ou rejeição final sem modificar o Designer. | Após revisar a comparação; a rejeição mantém o Designer intacto. |
| `ClearDesignerVisualDiffArtifacts` | Limpa snapshots e comparações mantidos somente em memória. | Ao encerrar a jornada ou quando artefatos visuais locais não forem mais necessários. |

## Recuperação de resultados compactados

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetToolResultSummary` | Retorna hash, tamanho e step de um resultado integral preservado pelo agente. | Quando uma etapa compactada informa um `artifactId` e o agente precisa conferir sua identidade antes de recuperar conteúdo. |
| `GetToolResultRange` | Recupera um intervalo limitado do resultado integral sem reexecutar a ferramenta original. | Quando o contexto compactado omitiu um trecho necessário de build, teste, diff ou outro resultado armazenado. |

## Saúde do projeto e da instalação

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetProjectHealth` | Consolida configuração, build, mensagens, testes e sinais de manutenção do projeto ativo. | No início de uma jornada, antes de propor melhorias ou para confirmar se o projeto está pronto para avançar. |
| `GetInstallationHealth` | Diagnostica rota efetiva, provider, CLI, MCP, terminal, chat, tools e instalação. | Depois de instalar ou atualizar, no onboarding ou quando uma capacidade não funciona. |
| `RunInstallationDeepDiagnostic` | Executa probes sanitizados de versão e autenticação da CLI efetiva e handshakes temporários de MCP externo. | Pelo comando `/doctor --deep`, após consentimento explícito, quando o diagnóstico local não explica uma falha real. |
| `GetRadIAStatus` | Retorna um inventário sanitizado e filtrável da configuração, disponibilidade e prontidão atuais do RadIA. | Pelo comando `/status`, ao conferir uma instalação ou antes de orientar configuração e suporte. |
| `GetMemoryDiagnosticsStatus` | Verifica diretório, versão, aceite de licença e DLL de diagnóstico do FastMM5 para a plataforma atual. | Antes de iniciar um diagnóstico de memória ou ao investigar por que o recurso não está pronto. |
| `ConfigureMemoryDiagnostics` | Salva o diretório fornecido pelo usuário e o aceite explícito da licença do FastMM5, retornando a prontidão resultante. | Pelo assistente de configuração ou por chamada direta após consentimento estrutural. |
| `PrepareMemoryInstrumentation` | Cria um preview com fingerprint para inserir o FastMM5 primeiro no projeto e habilitar diagnósticos somente em Debug. | Antes de alterar o DPR, depois de confirmar que FastMM5, plataforma e configuração estão prontos. |
| `ApplyMemoryInstrumentation` | Revalida o fingerprint e aplica o preview ao buffer vivo do DPR com suporte ao Undo da IDE. | Após revisão e consentimento estrutural do usuário, antes do build diagnóstico. |
| `RevertMemoryInstrumentation` | Restaura exatamente o conteúdo do DPR capturado antes da instrumentação. | No fim de uma sessão temporária, em cancelamentos e quando o usuário desfaz a instrumentação persistente. |

## Instrumentação VCL runtime reversível

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareRuntimeVclInstrumentation` | Analisa o projeto VCL ativo em Debug e prepara, sem alterar arquivos, a inclusão temporária do adaptador autenticado que enxerga controles VCL sem janela própria. | Antes de automatizar controles como `TLabel`, `TSpeedButton`, frames e componentes compostos que não aparecem na árvore Win32. |
| `ApplyRuntimeVclInstrumentation` | Aplica exatamente o preview revisado ao DPR e cria as quatro units isoladas em `.radia/runtime`. | Depois da revisão e do consentimento para escrita estrutural; a aplicação instrumentada passa a publicar um endpoint local limitado durante sua execução. |
| `RevertRuntimeVclInstrumentation` | Restaura o DPR original e remove somente as units geradas que continuam inalteradas. | Ao encerrar o diagnóstico, cancelar a automação ou retirar a instrumentação temporária do projeto. |

## Performance runtime comparável

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `BeginRuntimePerformanceMeasurement` | Inicia amostragem limitada de CPU, memória e responsividade da janela para a sessão e o cenário já preparados. | Imediatamente antes de executar o preview de `PrepareRuntimeScenario`, informando uma chave estável para o cenário. |
| `CompleteRuntimePerformanceMeasurement` | Encerra a amostragem e gera evidência somente se o mesmo cenário terminou com sucesso na mesma sessão e build. | Logo após `RunRuntimeScenario` concluir; medições insuficientes ou sessões trocadas são recusadas. |
| `CompareRuntimePerformanceEvidence` | Compara duração, CPU, picos de working set/private bytes e amostras sem resposta entre dois builds. | Depois de repetir a mesma chave de cenário em sessão e build novos; sinaliza regressão acima de 10% ou piora de responsividade. |
| `CancelRuntimePerformanceMeasurement` | Interrompe a amostragem ativa sem criar evidência. | Em cancelamentos, falhas do cenário ou quando o usuário decide abandonar a medição. |
| `InspectFireDACUsage` | Inventaria conexões, queries, parâmetros, transações e SQL potencialmente mutável sem executar comandos nem coletar valores de credenciais. | Ao revisar a camada de dados ou preparar uma máquina limpa. |
| `DiagnoseDelphiDependencies` | Verifica paths declarados no projeto e manifestos de dependências sem instalar componentes. | Antes de preparar uma máquina ou corrigir falhas de compilação por dependência. |
| `AuditDelphiLocalization` | Localiza textos visíveis em Pascal e DFM candidatos a `resourcestring`. | Antes de preparar uma extração revisável ou comparar idiomas. |
| `PrepareLocalizationExtraction` | Prepara um patch imutável que move um literal da unit ativa para `resourcestring`, sem aplicar alterações. | Após escolher um candidato; a aplicação usa `ApplyPatch` com consentimento e a reversão usa `RevertPatch`. |
| `ParseMemoryDiagnosticLog` | Interpreta um log FastMM5 limitado e autorizado, agrupando eventos, bytes, classes, stacks, linhas e fingerprints. | Depois de uma execução diagnóstica ou ao importar um log localizado dentro do workspace ativo. |
| `PrepareMemoryDiagnosticSession` | Prepara um preview único com instrumentação, aquecimento, repetições e cenário runtime, sem executar o projeto. | Quando o usuário solicita um diagnóstico completo de memória e antes do consentimento de execução. |
| `RunMemoryDiagnosticSession` | Instrumenta, compila, inicia somente o processo supervisionado, executa o cenário, coleta o log e restaura o DPR. | Depois da revisão do preview e do consentimento explícito para a sessão composta. |
| `CancelMemoryDiagnosticSession` | Cancela build, cenário e somente o processo supervisionado pela sessão de memória ativa. | Quando o usuário cancela ou quando o limite da execução é atingido. |
| `GetMemoryDiagnosticSessionStatus` | Informa a fase atual, mensagem operacional, preview e estado de cancelamento. | Durante uma sessão longa, pelo chat ou MCP, para acompanhar o progresso sem interferir na execução. |
| `CompareMemoryDiagnosticEvidence` | Compara baseline e verificação de builds distintos sob o mesmo cenário e classifica como `fixed`, `improved`, `unchanged`, `regressed` ou `incomparable`. | Depois de aplicar uma correção e repetir exatamente o cenário original. |
| `PrepareMemoryDiagnosticFix` | Escolhe o primeiro frame do projeto, informa arquivo, linha, rotina e número da alocação e encaminha a edição ao `PreparePatch`. | Depois de selecionar um grupo de leak ou erro cuja stack contenha código do projeto. |

## Navegação, símbolos e project groups

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `ListProjectGroupProjects` | Lista os projetos carregados no project group atual. | Para entender soluções com executável, packages, bibliotecas ou testes separados. |
| `GetProjectDependencies` | Consulta as dependências reais do projeto ativo pela OTA. | Antes de decidir ordem de build, impacto ou relacionamento entre projetos. |
| `GetUnitSymbols` | Extrai classes, records, interfaces e rotinas do buffer ativo com suas linhas. | Para localizar declarações sem pesquisar texto cegamente. |
| `GetEditorSemanticContext` | Resume a unit ativa, o símbolo atual, imports e declarações próximas. | Antes de explicar, corrigir, testar ou completar código no ponto atual do editor. |
| `NavigateToFile` | Abre um arquivo pertencente a um projeto carregado e posiciona o cursor. | Quando uma análise, erro ou plano aponta para arquivo, linha e coluna específicos. |
| `NavigateToSymbol` | Posiciona o editor em um símbolo da unit ativa. | Depois de `GetUnitSymbols` ou quando o usuário pede para mostrar uma declaração. |
| `NavigateToDevelopmentSurface` | Mapeia uma intenção ou superfície para Code ou Design. | Entre etapas Code/Design. |
| `ListIDEActions` | Lista somente ações disponíveis na allowlist segura. | Antes de oferecer uma ação visual da IDE. |
| `ExecuteIDEAction` | Executa uma ação allowlisted após consentimento. | Para abrir painéis ou buscas da IDE sem automação de UI frágil. |

Navegação de arquivo é confinada aos projetos abertos. A execução de ações usa uma allowlist fixa,
passa pela classificação `execution` e não aceita nomes arbitrários recebidos do agente ou MCP.

## Artefatos de produtividade seguros

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareApiDocumentation` | Prepara `API.md` determinístico com a API pública indexada do projeto. | Antes de criar documentação de API na raiz ou em subdiretório autorizado. |
| `PrepareMockUnit` | Prepara uma unit de mock isolada para uma interface indexada. | Quando um teste precisa de um double compilável sem alterar código existente. |
| `ApplyGeneratedArtifact` | Cria atomicamente o artefato revisado e registra a unit somente quando solicitado. | Depois da revisão do conteúdo, path, hash e consentimento de escrita. |
| `RevertGeneratedArtifact` | Remove o artefato criado se seu conteúdo permanecer inalterado. | Para desfazer com segurança a geração aplicada. |

## Diagnóstico de stack trace do projeto

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `AnalyzeProjectStackTrace` | Importa traces Delphi, MadExcept ou EurekaLog e resolve frames entre units do projeto. | Ao analisar um trace para obter arquivo, linha, método, confiança e destino navegável por frame. |

## Análise Clean Uses

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareCleanUses` | Prepara uma remoção conservadora de imports sem uso usando o índice semântico. | Antes de revisar e aplicar a limpeza pela infraestrutura reversível de patches. |

## Segurança de threads e PPL

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `AnalyzeThreadingRisks` | Detecta acesso VCL inseguro, ausência de cancelamento e tratamento de exceções. | Antes de modernizar trabalho executado em background. |
| `PrepareThreadModernization` | Valida as proteções e prepara um patch revisável e reversível. | Depois de corrigir todos os riscos apontados no trecho proposto. |

## Retrofit OpenAPI de APIs existentes

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `InventoryExistingApiRoutes` | Inventaria rotas DEXT minimalistas e atributos de controllers nas units existentes. | Antes de preparar Swagger sem recriar o projeto. |
| `PrepareOpenApiRetrofit` | Adiciona imports, metadados OpenAPI e middleware Swagger em um preview reversível da unit Startup. | Depois de revisar o inventário e abrir a unit Startup existente. |

## Modernização DEXT e de forms

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareDextFormModernization` | Exige migração validada, paridade, fronteira DEXT, responsabilidade extraída e consistência DFM/PAS antes do preview multiarquivo. | Ao executar um lote revisável de adoção DEXT e decomposição. |
| `RecordDextFormModernizationGate` | Registra evidências de build/testes e reverte o preview aplicado quando um gate falha. | Depois de aplicar e validar cada lote. |

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

## Revisão por bloco

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `ListBlockReviews` | Lista blocos ligados ao arquivo e à revisão-base, incluindo a decisão atual. | Depois que um preview simples ou multiarquivo publica uma sessão revisável. |
| `DecideBlockReview` | Registra aceitar, rejeitar, editar ou solicitar alterações com comentário sem mudar o buffer. | Pelo gutter, menu, agente, chat ou MCP durante a revisão. |
| `ApplyBlockReviews` | Compõe as decisões e aplica os arquivos em uma transação. | Quando nenhum bloco continua pendente e após consentimento de escrita. |
| `ClearBlockReviews` | Descarta a sessão e suas decisões sem alterar arquivos. | Para cancelar a revisão ou abandonar um preview obsoleto. |

## Transações de desenvolvimento

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareDevelopmentTransaction` | Monta uma transação com mudanças de código, projeto e Designer. | Quando um objetivo precisa alterar diferentes superfícies como uma única unidade. |
| `ApplyDevelopmentTransaction` | Executa as etapas da transação e preserva dados de reversão. | Depois da revisão da operação composta e das permissões necessárias. |
| `RejectDevelopmentTransactionStep` | Rejeita uma etapa pendente. | Antes do apply seletivo. |
| `RevertDevelopmentTransactionStep` | Reverte a última etapa aplicada. | No rollback gradual. |
| `RevertDevelopmentTransaction` | Desfaz as etapas aplicadas em ordem segura. | Quando uma transação composta precisa ser revertida. |

## Templates de projetos

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PreviewProjectTemplate` | Renderiza a árvore e os arquivos de um template sem gravá-los. | Ao criar Console, VCL, FMX, Library, Package, DUnitX ou servidor DEXT. |
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
| `ApplyInlineReviewFix` | Aplica uma sugestão ancorada na revisão atual e remove a marca resolvida. | Após revisar o bloco e consentir com a alteração do buffer. |
| `RejectInlineReview` | Rejeita uma sugestão e remove sua marca sem alterar o buffer. | Quando o usuário não deseja incorporar o bloco sugerido. |
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
| `GetAdvancedBreakpointCapabilities` | Informa quais recursos avançados de breakpoint estão realmente disponíveis no Delphi 12 e 13 e explica limitações da OTA. | Antes de configurar condição, hit count, logpoint, thread ou filtro de exceção, evitando tentativas incompatíveis. |
| `ConfigureBreakpoint` | Altera somente os campos informados de um breakpoint existente e devolve a configuração anterior para reversão. | Para criar breakpoint condicional, hit count ou logpoint; exige consentimento de escrita reversível e caminho dentro do projeto. |

## Sessão, expressões e watches

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `EvaluateDebuggerExpression` | Avalia uma expressão segura no frame pausado. | Para consultar variável, campo ou expressão sem chamar código com efeitos colaterais. |
| `AddDebuggerWatch` | Adiciona uma expressão à lista controlada de watches. | Quando um valor deve ser acompanhado ao longo de vários passos. |
| `RemoveDebuggerWatch` | Remove um watch controlado. | Quando a expressão não precisa mais ser monitorada. |
| `ListDebuggerWatches` | Lista os watches mantidos pelo RadIA. | Antes de avaliar ou reorganizar o conjunto acompanhado. |
| `EvaluateDebuggerWatches` | Avalia os watches no frame atual. | Após uma pausa ou step para comparar os valores observados. |
| `StartDebugging` | Valida e enfileira a ação Run oficial da IDE sem bloquear o request MCP. | Depois de consentimento específico; durante a execução, acompanhe com `GetRuntimeDebugSession` e `WaitForDebuggerEvent`. |

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
| `PlanImpactedDUnitXTests` | Calcula e explica o menor conjunto seguro de fixtures DUnitX afetadas por arquivos modificados. | Antes dos testes durante o desenvolvimento; usa dependências transitivas e cobertura disponível, com fallback para a suíte completa. |
| `RunImpactedDUnitXTests` | Planeja e executa as fixtures afetadas ou toda a suíte quando a seleção não pode ser provada. | Após uma alteração localizada; nunca substitui as suítes completas obrigatórias do gate de release. |

## Cobertura de código

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetCoverageSummary` | Lê o bloco `stats` do relatório oficial do Delphi Code Coverage, confinado ao projeto ativo. | Depois dos testes, quando `CodeCoverage_Summary.xml` está disponível para registrar percentual, linhas e arquivos cobertos. |

## Timeline de debug

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetDebugTimeline` | Retorna eventos recentes de processo, estado, breakpoint e memória. | Para acompanhar a sessão sem polling destrutivo e explicar a sequência do debug. |

## Correlação do depurador runtime

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetRuntimeDebugSession` | Retorna sessão, PID real, projeto, executável, build e última sequência correlacionados. | Depois de iniciar o debug e antes de observar ou automatizar a aplicação. |
| `WaitForDebuggerEvent` | Aguarda estados do processo sem busy-wait e inclui a pilha quando ocorre parada ou exceção. | Para sincronizar o agente com exceção, parada, término ou futura descoberta de janela. |
| `CancelDebuggerWait` | Interrompe imediatamente a espera ativa. | Ao cancelar o objetivo, trocar de projeto ou encerrar a depuração. |

## Descoberta segura da aplicação em execução

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetRuntimeWindows` | Lista janelas autorizadas com ID opaco, processo, classe, texto sanitizado, proprietário, estado e capacidades. No IDE64, a identidade permanece segura mesmo quando uma aplicação Win32 não expõe o texto. | Depois de confirmar a sessão runtime e antes de preparar um cenário visual. |
| `GetRuntimeControlTree` | Retorna a hierarquia sanitizada dos controles com janela própria, sem aceitar ou expor `HWND`. | Para localizar ações possíveis em uma janela retornada por `GetRuntimeWindows`. |

## Cenários runtime limitados

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareRuntimeScenario` | Valida ações, alvos, capacidades, duração, repetições e cria um preview com fingerprint. Alvos que só aparecem após uma ação anterior são validados dinamicamente na execução. | Depois da descoberta e antes de solicitar consentimento para interagir com a aplicação. |
| `RunRuntimeScenario` | Revalida a sessão e executa exatamente o preview aprovado, restringindo seletores à janela raiz visível e habilitada do processo correlacionado. | Após o usuário revisar o roteiro; exige novo consentimento em toda execução. |
| `CancelRuntimeScenario` | Interrompe a execução ou uma espera ativa sem solicitar consentimento. | Pelo botão ou comando de parada de emergência, pelo agente ou pelo MCP. |
| `GetRuntimeScenarioStatus` | Retorna estado, repetição, ação atual, total concluído e eventual falha. | Para acompanhar o roteiro e coletar seu resultado estruturado. |

## Captura visual runtime

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `CaptureRuntimeVisual` | Captura um PNG limitado da janela visível e restaurada pertencente ao PID da sessão atual, mantém a imagem em memória e publica anterior/posterior no card local do chat. | Depois de `GetRuntimeWindows`: use `phase=before` antes da interação e `phase=after` depois; exige consentimento em toda chamada. |

## Evidências de diagnóstico runtime

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `CaptureRuntimeEvidence` | Registra sessão, build, cenário, último evento, pilha e até dez expressões em uma evidência sanitizada e identificada por fingerprint. | Uma vez na reprodução da falha e novamente, com `phase=verification`, após aplicar a correção e recompilar. |
| `CompareRuntimeEvidence` | Compara uma evidência de falha com outra de verificação e informa se são comparáveis e se a falha foi removida. | Depois de repetir o mesmo cenário em uma nova sessão e em um build diferente; não altera código nem substitui a revisão humana. |

## Regressões runtime versionadas

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `PrepareRuntimeRegression` | Valida um cenário com seletores repetíveis, rejeita IDs ligados à sessão e cria o preview do artefato. | Depois de comprovar a correção e antes de gravar a regressão no projeto. |
| `SaveRuntimeRegression` | Grava o preview em `.radia/runtime-scenarios/<id>.json` com schema, fingerprint e escrita atômica. | Após revisão e consentimento para escrita reversível. |
| `RevertRuntimeRegression` | Restaura o artefato anterior ou remove o arquivo criado pela aplicação correspondente. | Quando o usuário desfaz a gravação ainda rastreada pelo runtime atual. |
| `ListRuntimeRegressions` | Lista os cenários versionados do projeto ativo. | Para descobrir regressões disponíveis sem executar a aplicação. |
| `PrepareSavedRuntimeScenario` | Valida a integridade do artefato, religa seletores persistidos à sessão atual e cria um preview executável. | Depois de iniciar nova sessão de debug; a execução continua em `RunRuntimeScenario` com consentimento próprio e pode repetir o roteiro até o limite versionado. |

## Git local

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `GetGitStatus` | Consulta branch e alterações do repositório do projeto ativo. | Antes de editar, revisar ou preparar um commit. |
| `GetGitDiff` | Retorna o diff permitido para revisão. | Para verificar o resultado das mudanças e selecionar caminhos. |
| `PreviewGitCommit` | Prepara mensagem, arquivos e fingerprint sem criar o commit. | Quando o objetivo solicita um commit local revisável. |
| `CommitChanges` | Revalida o preview e cria somente o commit local. | Depois da revisão, consentimento e confirmação do fingerprint. |

## Mentor Delphi

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `ExplainSelectedDelphiCode` | Monta uma explicação por nível, ancorada na seleção atual e em regras citadas. | No editor ou chat, quando o usuário pede ensino contextual de Delphi. |

O conteúdo selecionado é usado somente na resposta corrente. A ferramenta retorna `retained: false` e
não grava a seleção como material didático.

## Migração de acesso a dados legado

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `InventoryLegacyDataAccess` | Inventaria referências a BDE, ADO e dbExpress no projeto ativo. | Antes de planejar uma migração para FireDAC. |
| `PlanLegacyMigrationBatches` | Agrupa os achados por tecnologia e arquivo em lotes limitados. | Depois do inventário, sem iniciar uma reescrita total. |
| `PrepareLegacyMigrationBatch` | Prepara um preview reversível somente para substituições determinísticas. | Após revisar riscos e ações manuais do lote. |
| `RecordLegacyMigrationGate` | Registra evidências de build e testes e reverte o lote aplicado se um gate falhar. | Depois de aplicar e validar cada lote. |
| `GetLegacyMigrationReport` | Consolida compatibilidade, gates e ações manuais pendentes. | Durante e ao encerrar a migração. |
| `PlanDextAndFormModernization` | Planeja DEXT e decomposição de forms sem reescrita automática. | Depois de estabilizar os lotes FireDAC. |

## Inspeção segura de banco local

| Ferramenta | O que faz | Quando é acionada |
|---|---|---|
| `InspectLocalSQLiteDatabase` | Lê tabelas, views e colunas de um arquivo SQLite dentro do workspace sem executar SQL fornecido pelo usuário. | Quando o agente precisa conhecer o schema local antes de propor uma consulta. |
| `PreviewLocalSQLiteQuery` | Executa uma única consulta somente leitura, limita o resultado a 500 linhas e oculta colunas sensíveis no grid e no CSV. | Depois que o usuário revisa a consulta; exige consentimento em toda execução. |

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
[Integração MCP](../guides/mcp_integration_guide.md).

## Limites importantes

- A presença no catálogo não garante que a ferramenta seja válida no estado atual da IDE.
- Designer exige formulário e contexto de design compatíveis.
- Avaliação e call stack exigem debugger pausado e frame válido.
- Build, testes, execução, Git e mutações podem exigir consentimento.
- `Apply` e `Revert` dependem do identificador e das precondições produzidos pela etapa anterior.
- Paths fora do workspace, conteúdo desatualizado e operações não suportadas são recusados.
