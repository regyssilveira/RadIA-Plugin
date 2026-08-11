# Catálogo Inicial de Ferramentas Agentivas

> Este documento descreve a arquitetura alvo e inclui itens de roadmap. Para a lista verificável
> das tools realmente registradas pelo package atual, consulte o
> [catálogo gerado do runtime](runtime_tool_catalog.md). Na IDE, `/tools` permanece a fonte final,
> pois extensões podem adicionar ferramentas dinamicamente.

## 1. Convenções

Os nomes públicos das ferramentas são estáveis, em inglês e usam `PascalCase`. Uma alteração
incompatível de argumentos ou resultado exige nova versão do contrato.

Cada ferramenta deve declarar:

- Categoria.
- Nível de risco.
- Capacidade exigida.
- Schema de entrada e saída.
- Limite de resposta.
- Idempotência.
- Timeout.
- Possíveis efeitos.

### Contrato de intenção visual

Toda execução bem-sucedida que retorna um objeto JSON recebe o campo reservado `_radiaView`. Esse
campo permite que chat, MCP e futuras superfícies visuais escolham a mesma apresentação sem
conhecer regras particulares de cada ferramenta:

```json
{
  "_radiaView": {
    "version": 1,
    "kind": "explorer",
    "action": "show_explorer",
    "sourceTool": "ListProjectUnits"
  }
}
```

Os tipos atuais são `details`, `explorer`, `editor_navigation`, `diff` e `activity`. Resultados de
erro, arrays e conteúdo truncado são preservados. Clientes que não implementam visualizações podem
ignorar `_radiaView`; o restante do contrato continua compatível.

| Família da ferramenta | Visualização sugerida |
|---|---|
| Navegação de arquivo ou símbolo | Editor |
| Preview, patch e Git diff | Diff |
| Build, teste, debug e timeline | Atividade |
| Projeto, units, símbolos e estado da IDE | Explorer |
| Demais ferramentas | Detalhes |

## 2. Slice inicial

Estas ferramentas formam o primeiro incremento somente leitura:

| Ferramenta | Resultado principal | Risco |
|---|---|---|
| `GetIDEState` | Versão, plataforma, estado de shutdown e capacidades | Somente leitura |
| `GetActiveProject` | Projeto, caminho, configuração e plataforma | Somente leitura |
| `ListProjectUnits` | Units do projeto ativo | Somente leitura |
| `GetActiveUnit` | Unit e arquivo ativos | Somente leitura |
| `ListOpenFiles` | Arquivos abertos na IDE | Somente leitura |
| `GetEditorContent` | Conteúdo vivo do editor | Somente leitura |
| `GetEditorSelection` | Seleção e posição | Somente leitura |
| `GetCursorPosition` | Linha e coluna | Somente leitura |
| `GetCompilerMessages` | Erros e warnings estruturados | Somente leitura |
| `FindInProject` | Ocorrências limitadas por escopo | Somente leitura |

O conteúdo retornado deve indicar truncamento, tamanho original e revisão/hash quando aplicável.

## 3. Editor

### Leitura

- `GetEditorContent`
- `GetEditorSelection`
- `GetCursorPosition`
- `GetEditorLine`
- `ListOpenFiles`
- `FindInEditor`
- `FindInProject`
- `GetUnitSymbols`
- `GetEditorSemanticContext`
- `NavigateToFile`
- `NavigateToSymbol`

### Escrita reversível

- `PreparePatch`
- `ApplyPatch`
- `RevertPatch`
- `InsertCodeAtCursor`
- `ReplaceEditorSelection`
- `ApplyTextPatch`
- `AddToUses`
- `RemoveFromUses`
- `SaveActiveFile`
- `SaveAllFiles`
- `UndoAgentChange`

Todas as escritas devem usar revisão do buffer como precondição.

O fluxo implementado usa `PreparePatch` para gerar um preview imutável sem efeitos,
`ApplyPatch` para aplicar somente após consentimento e revalidação atômica, e `RevertPatch`
para restaurar o conteúdo original quando a revisão produzida ainda estiver ativa.

### Revisão inline

- `PublishInlineReview`
- `ListInlineReviews`
- `PrepareInlineReviewFix`
- `ApplyInlineReviewFix`
- `RejectInlineReview`
- `RemoveInlineReview`
- `ClearInlineReviews`

Revisões são limitadas a 128 itens, ancoradas ao arquivo, hash completo do buffer e intervalo de
linhas. O notifier suportado no Delphi 12 e 13 sublinha as linhas conforme a severidade e
mostra a mensagem no status do editor. Se o buffer mudar, a revisão deixa de ser renderizada.
Sugestões não escrevem código diretamente: `PrepareInlineReviewFix` cria um preview no serviço de
patches, que continua sujeito a consentimento, precondições e reversão.
Aplicações diretas são limitadas a 20 linhas e 4.096 caracteres; acima disso, o resultado sinaliza
`requiresSmartDiff` e a decisão ocorre na superfície completa de diff. Alterações multiarquivo usam
as ferramentas transacionais `PrepareMultiFilePatch`, `ApplyMultiFilePatch` e
`RevertMultiFilePatch`.

## 4. Projeto e project group

### Leitura

- `GetActiveProject`
- `ListProjects`
- `ListProjectUnits`
- `GetProjectMetadata`
- `ListProjectConfigurations`
- `ListProjectPlatforms`
- `GetProjectSearchPath`
- `GetConditionalDefines`
- `GetProjectOutputPaths`
- `GetProjectDependencies`
- `ListProjectGroupProjects`

As tools acima agora usam diretamente o project group e o grafo de dependências da OTA. A navegação
por arquivo só aceita arquivos pertencentes a projetos abertos; a navegação por símbolo usa o buffer
vivo da unit ativa.

### Ações seguras da IDE

- `ListIDEActions`
- `ExecuteIDEAction`

`ListIDEActions` retorna apenas ações presentes em uma allowlist de navegação e visualização.
`ExecuteIDEAction` é classificada como execução, exige consentimento e recusa nomes fora dessa lista.

### Escrita estrutural

- `SetActiveConfiguration`
- `SetActivePlatform`
- `AddUnitToProject`
- `RemoveUnitFromProject`
- `CreateUnit`
- `CreateProjectFromTemplate`
- `SetProjectSearchPath`
- `SetConditionalDefines`
- `SetProjectOutputPath`

Alterações em `.dproj`, `.dpr` ou `.groupproj` devem produzir preview e backup lógico reversível.

## 5. Build e execução

- `CompileProject`
- `BuildProject`
- `CleanProject`
- `CancelBuild`
- `GetBuildStatus`
- `GetCompilerMessages`
- `RunWithDebugger`
- `RunWithoutDebugger`
- `StopRunningProject`

Build não equivale a autorização para executar binários. Execução possui consentimento próprio.

O `BuildProject` implementado aceita os modos `make`, `build`, `check` e `clean`, executa em
background pela OTA e não inicia o binário produzido. `CancelBuild` e timeout atuam somente sobre
a compilação em background atualmente controlada pelo RadIA.

## 6. Debugger

### Leitura

- `GetDebuggerState`
- `GetCallStack`
- `EvaluateDebuggerExpression`
- `ListDebuggerWatches`
- `EvaluateDebuggerWatches`
- `ListBreakpoints`
- `GetCurrentExecutionLocation`

Implementado: `GetDebuggerState`, `ListBreakpoints`, `GetCallStack`, `EvaluateDebuggerExpression`,
`ListDebuggerWatches` e `EvaluateDebuggerWatches`. As operações são somente
leitura, executadas na thread principal e devolvem snapshots sem reter interfaces do debugger.
A pilha só é consultada quando a OTA declara acesso seguro e a janela de acesso é encerrada em
`finally`.

Locals e outras expressões no frame atual são consultados pelo avaliador público da OTA com
`eseNone`, que proíbe chamadas, getters e outros efeitos colaterais. A OTA não publica uma API para
enumerar a janela interna Locals/Watch; por isso o RadIA mantém uma lista própria, limitada a 32
expressões de até 256 caracteres, e a reavalia pelo thread atual.

### Controle

- `StartDebugging`
- `PauseDebugging`
- `StepInto`
- `StepOver`
- `StepOut`
- `ContinueDebugging`
- `StopDebugging`
- `AddBreakpoint`
- `RemoveBreakpoint`
- `AddDebuggerWatch`
- `RemoveDebuggerWatch`

Implementado: `PauseDebugging`, `ContinueDebugging`, `StepInto`, `StepOver`, `StepOut` e
`StopDebugging`. Cada ação valida o estado atual, usa somente a OTA pública, é não idempotente e
exige consentimento e auditoria antes de alcançar o adapter. Pausa, continuação e steps possuem
risco `Execution`; encerramento possui risco `Destructive` e nunca reutiliza permissão de sessão.
`AddBreakpoint` aceita somente fontes Pascal dentro do workspace, rejeita duplicatas e informa
`RemoveBreakpoint` como operação inversa. `RemoveBreakpoint` exige confirmação destrutiva em toda
chamada. `StartDebugging` usa a ação oficial **Run** da IDE, que recompila quando necessário, e
inicia somente o `TargetName` produzido, sem aceitar caminho de executável arbitrário. A chamada
valida e enfileira a ação, retorna `starting` sem prender o request MCP ao loop do debugger, e deve
ser acompanhada por `GetRuntimeDebugSession` e `WaitForDebuggerEvent` durante a execução.
`GetDebuggerState` é indicado antes de iniciar ou depois de uma parada. A lista de watches é estado interno
limitado e suas alterações usam consentimento estrutural.

## 7. Form Designer

### Leitura

- `GetActiveForm`
- `ListFormComponents`
- `GetFormProperties`
- `GetComponentProperties`
- `CaptureActiveForm`
- `GetLiveFormText`

Implementado inicialmente: `GetActiveForm` e `ListFormComponents`. Ambos leem o Designer vivo
pela OTA, retornam snapshots e não retêm interfaces ou componentes da IDE.

O primeiro ciclo mutável está disponível por `PrepareComponentLayout`, `ApplyComponentLayout` e
`RevertComponentLayout`. O preview registra bounds originais e propostos; aplicação e reversão
revalidam form, componente e geometria imediatamente antes da alteração.

Propriedades escalares publicadas possuem o mesmo ciclo por `PrepareComponentProperty`,
`ApplyComponentProperty` e `RevertComponentProperty`. O adapter aceita somente propriedades
graváveis com tipos simples, recusa `Name`, eventos e referências a objetos, revalida valor e tipo
antes de escrever e tenta restaurar o valor original se a aplicação falhar. Nomes de propriedades
associados a senha, segredo, token, chave de API ou connection string também são recusados.

Criação e remoção usam `PrepareAddFormComponent`, `PrepareRemoveFormComponent`,
`ApplyFormComponentChange` e `RevertFormComponentChange`. O preview mantém classe, nome, parent e
geometria; a aplicação revalida o formulário vivo e a reversão executa a operação inversa. Esta
primeira versão aceita somente controles VCL de uma allowlist explícita e exige parent explícito.

### Mutação

- `OpenFormDesigner`
- `OpenCodeEditor`
- `AddFormComponent` (implementado pelo ciclo de preview)
- `RemoveFormComponent` (implementado pelo ciclo de preview)
- `SetFormProperty`
- `SetComponentProperty`
- `MoveFormComponent`
- `ResizeFormComponent`
- `AddEventHandler` (implementado pelo ciclo de preview)

`PrepareFormEventHandler`, `ApplyFormEventHandler` e `RevertFormEventHandler` formam uma transação
entre o buffer Pascal e o Form Designer vivo. A assinatura é criada pelo `IDesigner`, preservando o
tipo real do evento. Aplicação e reversão exigem que o vínculo e o snapshot completo do buffer ainda
coincidam com o preview; código concorrente do usuário nunca é sobrescrito silenciosamente.

## 8. Git

### Leitura

- `GetGitStatus`
- `GetGitDiff`
- `GetCurrentBranch`
- `GetRecentCommits`

### Mutação

- `PreviewGitCommit`
- `CommitChanges`

`GetGitStatus`, `GetGitDiff`, `PreviewGitCommit` e `CommitChanges` estão implementadas. O preview
não altera o index e congela paths, mensagem, diff e fingerprint. O commit exige index inicialmente
limpo, revalida o fingerprint e adiciona somente os paths revisados. Não são oferecidas ferramentas
de reset destrutivo, descarte irrestrito ou push.

## 9. Conhecimento

- `IndexProjectKnowledge`
- `SearchProjectKnowledge`
- `ClearProjectKnowledge`
- `GetKnowledgeStatus`
- `GetKnowledgeDocument`

As cinco ferramentas estão implementadas. A indexação é incremental e local; a busca retorna chunks
rastreáveis; o status expõe apenas contagens agregadas; a leitura de documento retorna conteúdo
limitado com arquivo, revisão e linhas; a limpeza remove somente dados derivados reconstruíveis.

O índice lexical agora possui persistência local opcional por projeto. O snapshot é versionado,
gravado atomicamente sob a pasta de dados do RadIA e identificado por hash SHA-256 do projeto.
Conteúdo inválido ou incompatível não é carregado; a indexação seguinte o reconstrói. A limpeza
remove memória e arquivo derivado sem alterar qualquer fonte do workspace.

Notificações de edição, save, rename e fechamento apenas marcam o projeto como alterado. Um
scheduler com debounce inicia a atualização incremental em background, mantém somente índices e
identidades escalares dos módulos e deixa de agendar trabalho assim que o shutdown é detectado.

Resultados devem citar arquivo, símbolo, revisão e intervalo relevante.

## 10. Auditoria

- `QueryAuditLog`
- `GetAgentChanges`
- `GetPendingReviews`

A auditoria não deve devolver secrets removidos durante a sanitização.

## 11. Ordem de implementação

1. Leitura de IDE, projeto e editor.
2. Leitura de build.
3. Pipeline de segurança.
4. Patches e revisão.
5. Build controlado.
6. MCP.
7. Designer.
8. Debugger.
9. Conhecimento.
10. Git mutável.
11. Extensões adicionais pelo contrato versionado.

## 12. Extensões locais

Pacotes confiáveis podem registrar ferramentas adicionais por `IRadIAToolExtension`. O host recebe
o lote por um registrar limitado, valida schemas, nomes, versão da API, prefixo e colisões, e publica
todas as ferramentas atomicamente.

Ferramentas externas não possuem um caminho alternativo de execução: chat e MCP continuam usando o
executor central de política, consentimento, auditoria e cancelamento. A liberação do token
`IRadIAToolExtensionRegistration` remove somente as ferramentas pertencentes à extensão.

Consulte `docs/tool_extension_guide.md` e o pacote em `Examples/ToolExtension`.

## 13. Critérios para adicionar uma ferramenta

Uma nova ferramenta somente entra no registry quando:

- Possuir contrato documentado.
- Possuir implementação fake testável.
- Declarar risco e efeitos.
- Validar todos os argumentos.
- Respeitar limites do workspace.
- Sanitizar resultado e erros.
- Possuir teste de cancelamento quando executar trabalho demorado.
- Possuir comportamento definido para shutdown.
- Indicar suporte por versão da IDE.
