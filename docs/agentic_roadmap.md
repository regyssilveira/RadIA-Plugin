# Roadmap da Evolução Agentiva

> **Documento histórico da linha 1.x.** A matriz vigente da linha 2.0 contém somente Delphi 12
> Win32 e Delphi 13 Win32/IDE64. Referências ao Delphi 11 abaixo registram validações antigas.

## Goal

Evoluir o RadIA de assistente de chat multi-provider para uma plataforma agentiva segura e
integrada ao Delphi, preservando a estabilidade no shutdown
da IDE e implementação independente.

## Estado

| Fase | Escopo | Estado |
|---|---|---|
| 0 | Arquitetura, contratos e gates | Concluída |
| 1 | Workspace facade e ferramentas read-only | Implementada; smoke OTA D11/D12/D13 aprovado |
| 2 | Consentimento, políticas e auditoria | Implementada; fluxo real D13 aprovado |
| 3 | Patches revisáveis e ciclo de build | Implementada; fluxo real reversível aprovado |
| 4 | MCP local e providers CLI | Implementada; bridge e estresse do pipe aprovados |
| 5 | Designer vivo, debugger e revisão inline | Implementada; revisão real D13 aprovada |
| 6 | Conhecimento local incremental | Implementada; eventos do notifier cobertos por testes |
| 7 | Extensibilidade, hardening e release | Concluída |

## Próximos marcos priorizados

O goal agentivo foi concluído. Evoluções posteriores devem ser abertas como novos goals versionados.

Indicadores do goal:

- 100% dos tools mutáveis passam por consentimento e auditoria.
- 100% das alterações em código ou Designer possuem preview e precondições.
- Zero falha, erro ou vazamento na matriz DUnitX D11/D12/D13 Win32.
- Zero crash ou deadlock em dez ciclos consecutivos de instalação, uso e shutdown por IDE.
- Nenhuma leitura ou escrita fora do workspace autorizado.

## Fase 0: fundação documental

Entregas:

- [Arquitetura agentiva](agentic_architecture.md).
- [Catálogo de ferramentas](tool_catalog.md).
- [Modelo de segurança](tool_security_model.md).
- [Matriz de compatibilidade](delphi_compatibility_matrix.md).
- [Plano de validação](agentic_validation_plan.md).
- [ADR do registro de ferramentas](adr/0001-internal-tool-registry.md).
- [ADR da fachada de workspace](adr/0002-workspace-facade.md).

Gate:

- Contratos e fronteiras revisados contra o código atual.
- Primeiro slice de implementação definido.
- Baseline de build e testes registrado.

Resultado:

- Documentação e ADRs criados.
- Pacote compilado no Delphi 12.
- A suíte voltou a compilar após adoção de response file no `build.ps1`.
- Baseline DUnitX: 292 testes, 289 aprovados, três falhas dependentes do SonarQube local e zero
  vazamento, conforme o [plano de validação](agentic_validation_plan.md).

## Fase 1: primeiro slice implementável

Objetivo:

Criar o registro interno, o executor e uma fachada read-only mínima.

Ferramentas:

- `GetIDEState`
- `GetActiveProject`
- `GetActiveUnit`
- `ListOpenFiles`
- `ListProjectUnits`
- `GetEditorContent`
- `GetEditorSelection`
- `GetCursorPosition`
- `GetCompilerMessages`

Gate:

- Ferramentas testadas com facade fake.
- Integração OTA validada dentro da IDE.
- Nenhuma escrita disponível.
- Build e DUnitX aprovados nas IDEs disponíveis.

Resultado parcial:

- Tool Registry e executor implementados no Core.
- Fachada read-only implementada sobre OTA.
- Nove ferramentas read-only registradas no container.
- Catálogo, execução e resultados das ferramentas integrados visualmente ao chat.
- Comandos `/tools` e `/tool` disponíveis sem encaminhar a solicitação ao provedor de IA.
- 313 testes aprovados no Delphi 12, sem falhas ou vazamentos.
- Validação dentro da IDE e nas demais versões disponíveis ainda pendente para concluir a fase.

## Fase 2: segurança

Adicionar policy pipeline, consentimento, sanitização e auditoria antes de qualquer ferramenta
mutável.

Resultado parcial:

- Contexto de execução inclui origem, sessão, projeto e escopo.
- Executor de políticas centralizado entre os clientes e o executor concreto.
- Ferramentas read-only são permitidas sem prompt.
- Ferramentas mutáveis exigem decisão explícita; ferramentas sensíveis são negadas por padrão.
- Permissões de sessão são escopadas por sessão, projeto, ferramenta e escopo, além de revogáveis.
- Redação inicial cobre tokens Bearer, chaves AWS e campos JSON sensíveis.
- Auditoria estruturada em JSON Lines registra decisão, resultado, duração e argumentos sanitizados.
- UI nativa de consentimento oferece permitir uma vez, permitir na sessão, negar e cancelar.
- Diálogo possui timeout fail-safe e cancela automaticamente durante o shutdown.
- Comando `/revoke-tools` remove imediatamente todas as permissões da sessão.
- Workspace boundary rejeita raiz de volume, parent traversal, paths externos e reparse points.
- 327 testes aprovados no Delphi 11, 12 e 13 Win32, sem falhas ou vazamentos.
- Validação visual dentro da IDE e teste real com junction/reparse point ainda pendentes.

Gate:

- Negação sem efeitos.
- Permissão de sessão limitada.
- Secrets sanitizados.
- Shutdown seguro durante consentimento.

## Fase 3: edição e build

Aplicar patches com precondições, revisão, verificação e reversão.

Resultado parcial:

- Serviço de patches mantém previews imutáveis e temporários em memória.
- Preview exige arquivo ativo, hash-base, trecho original único e workspace autorizado.
- Aplicação e reversão revalidam arquivo, projeto, workspace e revisão imediatamente antes da escrita.
- Adapter OTA compara e altera o buffer de forma atômica na thread principal.
- `PreparePatch`, `ApplyPatch` e `RevertPatch` registrados com riscos apropriados.
- Chat apresenta comparação antes/depois e solicita consentimento para aplicar ou reverter.
- Buffers alterados após o preview são preservados e retornam `precondition_failed`.
- Limites de tamanho e quantidade protegem a memória do processo `bds.exe`.
- 340 testes aprovados no Delphi 11, 12 e 13 Win32, sem falhas ou vazamentos.
- Tools agora executam fora da thread principal e entregam resultados pela fila da UI com lifecycle guard.
- `BuildProject` suporta make, build, check e clean sem executar o binário produzido.
- Build usa serviço de compilação OTA, consentimento, timeout, cancelamento e exclusão mútua.
- `GetBuildStatus` e `CancelBuild` expõem acompanhamento e interrupção estruturados.
- Resultado inclui projeto, configuração, plataforma, duração e diagnósticos disponíveis.
- Encoding no adapter real, Undo OTA e smoke test dentro da IDE ainda pendentes.

Gate:

- Conflitos de buffer detectados.
- Diff aprovado antes da aplicação.
- Encoding preservado.
- Build estruturado.
- Reversão validada.

## Fase 4: MCP e CLIs

Expor o registry por named pipe e HTTP loopback opcional, integrando inicialmente Codex CLI.

Resultado parcial:

- Protocolo MCP `2025-06-18` implementado sobre JSON-RPC 2.0.
- Lifecycle, `ping`, `tools/list`, `tools/call` e notificações sem resposta implementados.
- O mesmo registry e o mesmo executor de políticas usados pelo chat atendem clientes MCP.
- Named pipe usa endpoint efêmero, ACL restrita ao owner e ao sistema, payload máximo de 1 MiB e
  uma sessão isolada por conexão.
- Bridge stdio permite integração com clientes MCP padrão sem expor listener de rede.
- O bridge aguarda até dez minutos por respostas para acomodar consentimento humano sem abandonar
  a chamada enquanto a IDE ainda executa a ferramenta.
- Cada processo publica `mcp.<pid>.json`, enquanto `mcp.json` preserva compatibilidade com clientes
  existentes e aponta para a instância iniciada mais recentemente.
- O shutdown remove sempre a descoberta da própria instância e só remove o arquivo legado quando
  ainda é seu proprietário, sem apagar o endpoint de outra IDE.
- O bridge aceita o caminho de um arquivo por instância e detecta ambiguidades quando não existe um
  proprietário legado entre múltiplas IDEs.
- Inicialização aguarda o endpoint ficar pronto e propaga falhas de criação do pipe.
- Teste automatizado cobre round-trip real pelo named pipe e sua limpeza.
- Smoke test no Delphi 13 confirmou handshake, `tools/list`, leitura do buffer vivo, consentimento
  nativo e auditoria pelo bridge stdio.
- HTTP loopback e integração dirigida com providers CLI foram mantidos como opcionais.
- Baseline registrada naquele marco no Delphi 11, 12 e 13 Win32: 442/442 testes, sem falhas ou vazamentos.

Gate:

- Segurança compartilhada com o chat.
- Autenticação local.
- Limites de payload.
- Shutdown sem processos ou listeners órfãos.

## Fase 5: integração profunda

Adicionar Form Designer vivo, debugger e revisão inline.

Resultado parcial:

- Facades independentes para Form Designer e debugger foram adicionadas ao Core.
- `GetActiveForm` retorna form, unit, DFM, classe, componentes e seleção do Designer vivo.
- `ListFormComponents` retorna componentes visuais e não visuais, hierarquia, seleção e geometria.
- `GetDebuggerState` retorna processo, estado, executável, localização, status, threads e breakpoints.
- `ListBreakpoints` retorna arquivo, linha, habilitação e validade de cada breakpoint.
- `GetCallStack` retorna frames, headers e posições de fonte da thread atual quando acessíveis.
- Pausar, continuar, step into/over/out e parar usam tools de execução não idempotentes.
- Cada comando valida o estado do processo e depende de consentimento e auditoria compartilhados.
- Breakpoints podem ser adicionados e removidos somente em fontes Pascal dentro do workspace.
- Adição é reversível; remoção é destrutiva e exige confirmação em cada chamada.
- As cinco ferramentas read-only usam o mesmo registry, política, auditoria, chat e MCP.
- Interfaces OTA são acessadas apenas na thread principal e convertidas imediatamente em snapshots.
- Nenhuma referência a componente, form editor, processo, thread, frame ou breakpoint é retida.
- Layout de componentes possui preview imutável e temporário, aplicação e reversão com precondições.
- `PrepareComponentLayout`, `ApplyComponentLayout` e `RevertComponentLayout` estão no registry.
- Aplicação e reversão exigem consentimento estrutural e são registradas na auditoria compartilhada.
- O adapter altera o componente vivo na thread principal, marca o Designer como modificado e tenta
  restaurar os bounds originais caso a aplicação falhe.
- O chat apresenta a comparação visual dos bounds e botões explícitos para aplicar e reverter.
- Propriedades escalares publicadas podem ser preparadas, aplicadas e revertidas com precondições.
- `Name`, eventos, objetos e outros tipos estruturais são recusados pelo adapter real.
- O chat apresenta comparação antes/depois e ações explícitas para propriedades do Designer.
- Criação e remoção de controles VCL allowlisted possuem preview, consentimento estrutural,
  precondições e reversão pela operação inversa.
- Handlers de evento possuem preview, geração de assinatura pelo `IDesigner`, vínculo no DFM vivo,
  snapshots pré/pós do buffer Pascal e reversão condicionada por precondições.
- Avaliação de locals/expressões usa o thread atual sem efeitos colaterais; watches são limitados,
  administrados pelo RadIA e avaliados pelo debugger nativo.
- `StartDebugging` compila e inicia exclusivamente o target do projeto ativo.
- Revisões inline são ancoradas à revisão do buffer, renderizadas por severidade e invalidadas por
  qualquer edição concorrente; sugestões reutilizam o ciclo de patches reversíveis.
- Baseline registrada naquele marco no Delphi 11, 12 e 13 Win32: 442/442 testes, sem falhas ou vazamentos.
- A BPL atual carregou automaticamente em três ciclos válidos por versão: Delphi 11 encerrou entre
  0,80 s e 0,86 s; Delphi 12, entre 1,52 s e 1,99 s; Delphi 13, entre 1,98 s e 2,63 s. Não houve
  crash ou deadlock.
- O smoke real da revisão inline no Delphi 13 confirmou decoração visual, consentimento, auditoria,
  aplicação no buffer, reversão ao SHA original, rejeição e limpeza sem alterar o arquivo em disco.
- O smoke revelou e corrigiu a identidade incorreta `.dproj` do buffer e a duplicação da quebra de
  linha terminal durante substituições completas pelo writer OTA.
- Delphi 13 IDE64 compilou pacote, bridge e suíte nativamente, com 442/442 testes aprovados. A BPL
  Win64 carregou em três ciclos no `bin64\bds.exe`, abriu o projeto e respondeu ao MCP como Win64.
  Os shutdowns normais concluíram entre 1,62 s e 1,88 s, sem processo ou descoberta MCP órfãos.

Gate:

- PAS e DFM consistentes.
- Event handler atômico.
- Operações de debugger consentidas.
- Smart Diff permanece como fallback.

## Fase 6: conhecimento

Criar parser estrutural, índice lexical e atualização incremental. Embeddings permanecem opcionais.

Resultado parcial:

- Serviço local mantém índices independentes por projeto sem depender de serviços externos.
- Chunking reconhece units, seções, classes, records, interfaces, métodos e rotinas Delphi.
- Cada chunk registra arquivo, símbolo, revisão, linha inicial, linha final e conteúdo.
- Arquivos inalterados são preservados; revisões alteradas substituem apenas o documento afetado.
- Arquivos removidos do projeto também são removidos do índice.
- A fonte OTA lê buffers abertos antes do disco e aplica workspace boundary.
- Arquivos fechados são limitados a 2 MiB e somente extensões Pascal suportadas são indexadas.
- `IndexProjectKnowledge`, `SearchProjectKnowledge` e `ClearProjectKnowledge` estão no registry.
- `GetKnowledgeStatus` expõe estado carregado e contagens de arquivos e chunks.
- `GetKnowledgeDocument` retorna chunks rastreáveis de um arquivo indexado com limite explícito de
  conteúdo e sinalização de truncamento.
- Resultados de busca possuem score lexical e conteúdo limitado a 4.000 caracteres por hit.
- Limpeza do índice derivado exige consentimento e ele pode ser reconstruído integralmente.
- Snapshots locais versionados são persistidos atomicamente por hash do projeto fora do workspace.
- Arquivos ausentes, incompatíveis ou corrompidos são ignorados e reconstruídos pela próxima indexação.
- Limpeza do projeto remove tanto o índice em memória quanto o snapshot persistido correspondente.
- Notifiers de módulos marcam o índice como sujo em edição, save, rename e fechamento.
- Um scheduler aplica debounce e executa a atualização incremental em background.
- O notifier não retém interfaces OTA e interrompe novos agendamentos durante o shutdown.
- Os eventos `Modified`, `AfterSave`, `ModuleRenamed` e `Destroyed` possuem testes de integração
  determinísticos que confirmam a marcação do índice como alterado.
- O smoke no Delphi 13 confirmou carregamento automático do pacote, handshake MCP, indexação local
  inicial e busca rastreável. A edição automatizada do buffer vivo permanece como validação manual.
- Baseline registrada naquele marco no Delphi 11, 12 e 13 Win32: 442/442 testes, sem falhas ou vazamentos.

Gate:

- Busca funciona offline.
- Fontes e revisões rastreáveis.
- Índice pode ser reconstruído e removido.

## Fase 7: consolidação

Adicionar pacotes de conhecimento, templates versionados, hardening e documentação de release.

Resultado parcial:

- API de extensões nível 1 publicada sem expor o container interno.
- Registro em lote é atômico e rejeita colisões sem deixar ferramentas parcialmente registradas.
- Prefixo declarado delimita o ownership das ferramentas de cada extensão.
- Token de registro remove as ferramentas antes do descarregamento da BPL externa.
- Ferramentas externas reutilizam o pipeline central de política, consentimento, auditoria e MCP.
- Pacote independente `RadIASampleExtension` compilado no Delphi 11, 12 e 13 Win32 e no Delphi 13
  Win64.
- Guia de extensão e exemplo externo publicados.
- `build.ps1 -Package` gera ZIP autocontido com manifesto SHA-256 e instalador validado por versão
  e arquitetura.
- O fluxo de instalação agora distribui a bridge MCP junto da BPL.
- Checklist de release separa gates automatizados concluídos das validações reais ainda pendentes.
- Versão pública centralizada evita divergência entre About, handshake MCP, recurso da BPL e pacote.
- Notas preparatórias de migração documentam dados locais, MCP, consentimento, extensões e rollback.

Gate:

- Matriz Delphi aprovada.
- Migrações testadas.
- Testes de stress e shutdown aprovados.
- Documentação de extensão publicada.
