# Goal RadIA 2.0: jornada completa de desenvolvimento

> **Estado da release:** em desenvolvimento e validação. A versão 2.0.0 ainda não foi lançada.
> Evidências registradas neste documento comprovam o baseline já implementado, mas não substituem
> os gates adicionais definidos na seção "Expansão competitiva antes da release".

## Objetivo

Permitir que o usuário descreva uma aplicação Delphi e, sem sair da IDE, acompanhe sua criação,
edição segura de código e Form Designer, build, testes DUnitX, depuração, correção validada e commit
revisável.

O fluxo deve ser observável, cancelável, persistente e protegido por preview, consentimento,
auditoria e confinamento ao workspace. A entrega final será validada no Delphi 11, 12 e 13.

## Fonte de verdade

- O comando `/tools` representa a instância ativa, incluindo extensões.
- O [catálogo gerado](runtime_tool_catalog.md) registra as tools internas verificadas no código.
- O [catálogo arquitetural](tool_catalog.md) descreve contratos existentes e capacidades alvo.
- Este documento registra os critérios de conclusão do goal 2.0.

## Baseline de agosto de 2026

| Capacidade | Evidência atual | Estado para o goal |
|---|---|---|
| Registry e segurança | 80 tools internas, política, consentimento e auditoria | Pronto |
| Chat | Providers, streaming, sessões, Agent Mode e loop observável | Pronto |
| Projeto novo | Wizard visual e seis templates determinísticos | Pronto |
| Projeto vivo | Leitura e operações estruturais transacionais | Pronto |
| Editor | Buffer vivo, patches e transação multi-arquivo | Pronto |
| Form Designer | Transação composta Design/Code | Pronto |
| Build | Gate autocorretivo com rebuild obrigatório | Pronto |
| Testes | Runner DUnitX estruturado e cancelável | Pronto |
| Debugger | Estado, controle e timeline orientada a eventos | Pronto |
| Git e entrega | Preview, diff e commit local revisável | Pronto |
| Compatibilidade | Delphi 11/12/13 Win32 e Delphi 13 IDE64 | Manter a matriz verde |

## Capacidades incorporadas ao runtime

As lacunas originais agora aparecem no catálogo interno registrado:

- criação de unit e form como operações estruturais;
- adição e remoção de arquivo no projeto;
- seleção de configuração e plataforma;
- execução e análise estruturada de DUnitX;
- notificações e timeline do debugger;
- transações de edição multi-arquivo;
- operações Git;
- loop agentivo nativo.

O catálogo gerado contém 80 tools. Os fluxos possuem testes proporcionais ao risco e permanecem
sujeitos à validação E2E na IDE antes da release 2.0.

## Marcos

### M0 — Baseline verificável

- Manter catálogo interno gerado e validado no build.
- Corrigir divergências entre runtime e documentação.
- Definir cenário E2E e evidências exigidas.
- Preservar build e testes na matriz suportada.

### M1 — Agent Runtime

- Planejar, executar tools, observar resultados e prosseguir até a conclusão.
- Limitar passos, tokens, custo, tempo e repetição.
- Permitir pausa, cancelamento, checkpoint e retomada.
- Exibir plano, etapa, tool, consentimento e resultado.

Estado: concluído. O núcleo executa decisões e tools, registra observações, limita passos e
chamadas repetidas e oferece pausa, cancelamento, checkpoint e retomada. O adaptador de providers,
controlador assíncrono e cartão vivo do chat já estão conectados por `/agent run`. O plano exige
aprovação antes da primeira tool, e limites persistentes de tokens, tempo e custo são aplicados.
O custo usa tarifas locais configuráveis por provider/modelo e nunca presume preços desconhecidos.

### M2 — New Project Wizard

- Oferecer templates determinísticos para Console, VCL, FMX, Library, Package e DUnitX.
- Criar em staging confinado ao destino.
- Exibir preview da árvore e opções de plataforma.
- Abrir, compilar e reverter integralmente em caso de falha.

Estado: concluído. O engine determinístico dos seis templates, preview com SHA-256, transação
staging/commit/rollback, abertura OTA e build inicial com rollback automático estão implementados e
expostos como tools. O wizard visual permite escolher uma pasta autorizada sem projeto ativo. Os
seis projetos gerados compilam via `.dproj` no Delphi 11, 12 e 13.

### M3 — Edição e Designer transacionais

- Tratar o buffer da IDE como fonte primária.
- Aplicar ou reverter uma mudança multi-arquivo como unidade.
- Integrar diff inline e Undo.
- Encerrar mutações visuais em Design e mutações de código em Code.

Estado: concluído. A transação multi-arquivo oferece preview único, preflight de todos os
buffers, commit compensável e reversão integral pelas tools `PrepareMultiFilePatch`,
`ApplyMultiFilePatch` e `RevertMultiFilePatch`. A fachada OTA lê e escreve qualquer buffer aberto,
sem depender do editor ativo. Criação e retirada de units/forms também seguem preview, publicação
atômica, registro OTA e reversão, sem apagar arquivos preexistentes. A transação superior agora
compõe código, estrutura, componentes, layout, propriedades e eventos, com compensação simétrica.
A jornada E2E no Delphi 13 validou patch do buffer vivo, propriedade e componente no Form Designer,
consentimento, reversão e persistência do estado revertido.

### M4 — Build e testes

- Executar o ciclo alteração, build, diagnóstico, correção e rebuild.
- Descobrir e executar testes DUnitX.
- Interpretar falhas e repetir somente testes afetados.
- Incorporar cobertura e detecção de leaks às evidências.

Estado: concluído e validado no Delphi 13. O runtime impede conclusão depois de uma mutação enquanto
um `BuildProject` bem-sucedido não ocorrer. O build salva os buffers pela OTA e executa o MSBuild
oficial do Delphi fora da thread da IDE, com timeout, cancelamento e diagnósticos estruturados. O
smoke confirmou erro intencional, retorno do diagnóstico, reversão do patch revisado, rebuild e
DUnitX aprovados. O runner interpreta NUnit XML e confina artefatos em `.radia/test-results`.

### M5 — Debug Agent

- Receber eventos de processo, pausa, breakpoint, exceção e encerramento.
- Manter timeline, threads, frames, stack e watches limitados.
- Diagnosticar, preparar correção e validar novamente com autorização.

Estado: concluído e validado na IDE. A integração OTA publica eventos de processo, estado, breakpoint
e memória em uma timeline limitada e persistida em `.radia/debug/timeline.jsonl`. O smoke real no
Delphi 13 confirmou build, criação do breakpoint, início pela ação nativa de Run da IDE, parada,
leitura do call stack e da timeline, encerramento da sessão e remoção do breakpoint. Stack, frames,
watches e controles permanecem disponíveis pelas tools do debugger.

### M6 — Git e entrega

- Expor status, diff, branch, stage e commit revisáveis.
- Separar mudanças do usuário das mudanças do agente.
- Executar quality gates antes da entrega.

Estado: concluído e validado em repositório descartável. A jornada real confirmou status, diff
limitado ao path selecionado, preview com fingerprint, consentimento e commit local. O commit
`c503ae2` incluiu somente a unit revisada; arquivos produzidos depois permaneceram fora do commit.
O RadIA não executa push.

Estado: concluído. O workflow local expõe status, diff, preview e commit de caminhos selecionados.
O preview usa fingerprint, rejeita índice previamente staged e detecta alterações concorrentes.
Não existem tools de push, reset ou descarte, e o commit permanece sujeito a consentimento e
auditoria.

### M7 — Release 2.0

- Aprovar o cenário E2E nas versões suportadas.
- Validar dock, WebView2, shutdown, retomada e ausência de processos órfãos.
- Publicar instalador, migração, manual e evidências de release.

Estado: baseline pré-release validado. A build atual foi instalada no Delphi 13 Win32 e IDE64. O smoke
confirmou o
SHA-256 da BPL instalada, versão, catálogo de 80 tools, remoção do discovery e ausência de processos
descendentes após o shutdown. O painel de chat também foi criado como `TOTADockForm` pela API nativa
`INTACustomDockableForm` e renderizado em uma IDE real sem a tela em branco. O hardening adicional
eliminou acesso tardio a objetos VCL já destruídos. A retenção do `bds.exe` foi eliminada ao
desregistrar os hooks OTA de editor e debug antes de abandonar seus objetos no shutdown, sem liberar
VCL/WebView2. Três ciclos consecutivos da build instalada encerraram sem processo órfão. O drop
lateral permanece como aceite visual manual porque a IDE elevada bloqueia entrada sintética entre
processos; criação, visibilidade e persistência do host são automatizadas. A jornada E2E contínua
abaixo foi aprovada no Delphi 13.

## Evidências de validação — 3 de agosto de 2026

- Delphi 11, 12 e 13 Win32 após hardening dos notifiers: 511 testes com cobertura e quatro testes
  externos por versão, sem falhas ou leaks.
- Smoke real Win32: Delphi 11 e 12 passaram um ciclo de carga, catálogo MCP com 80 tools e shutdown
  limpo; Delphi 13 passou três ciclos consecutivos sob a asserção endurecida de processo raiz.
- Delphi 13 IDE64: 515 testes diretos, sem falhas ou leaks.
- Candidatos 2.0.0: pacotes validados para Delphi 11/12/13 Win32 e Delphi 13 IDE64, manual completo e
  guia de migração 1.x→2.0 publicados na documentação.
- Delphi 13 Win32: três ciclos reais de carga e shutdown com 80 tools e nenhum processo órfão.
- Delphi 13 Form Designer: `TButton` criado, listado e revertido no designer vivo com preview e
  consentimento.
- Delphi 13 build de template: removido o diálogo modal de grupo de projeto não persistido.
- Delphi 13 IDE64: três ciclos reais de carga e shutdown com 80 tools e nenhum processo órfão.
- Chat/WebView2: host nativo `TOTADockForm` e painel renderizados em uma IDE real, sem tela branca,
  com o controle visual do modo agente presente.
- Desktop da IDE: dois ciclos reais confirmaram visibilidade e restauração da geometria do
  `TOTADockForm`; o drop lateral permanece como aceite visual manual devido ao bloqueio de entrada
  sintética entre processos imposto pela IDE elevada.
- Integração MCP/IDE no Delphi 13: abertura de projeto descartável, leitura e patch do buffer vivo,
  consentimento visual, save, build pela tool, 513 testes pela tool DUnitX, rename, reindexação e
  shutdown limpo.
- Template VCL no Delphi 13: preview determinístico, consentimento visual, criação transacional,
  abertura real, build pela OTA, rollback, fechamento do módulo e reativação do projeto anterior.
- Form Designer no Delphi 13: detecção do form vivo, preview da propriedade `Caption`, consentimento
  visual, aplicação, reversão e persistência do estado revertido antes do rollback do projeto.
- Qualidade: ESLint, catálogo runtime e `git diff --check` aprovados.

O diagnóstico CDB confirmou que a retenção acontece antes de `ExitProcess`, durante notificações de
arquivo da IDE. O MMX apareceu na cadeia de uma AV envolvendo uma BPL DevExpress já descarregada,
mas a retenção também ocorreu com o MMX temporariamente desabilitado. O RadIA agora neutraliza seus
notifiers de conhecimento no shutdown sem liberar objetos VCL/WebView2. A correlação da pilha com
`IdeservicesFileNotification` levou à remoção explícita dos hooks OTA de editor e debug; três ciclos
consecutivos do smoke endurecido confirmaram a correção, entre 16,41 e 30,94 segundos.

Essas evidências validam instalação, carga, catálogo, renderização, edição, build, testes e
encerramento, além de criação por template e edição segura do Designer. A jornada contínua com
debug, correção validada e commit Git revisável também foi aprovada no Delphi 13.

## Expansão competitiva antes da release

Os itens abaixo pertencem à versão 2.0.0 e reabrem o gate de release:

1. ampliar a superfície OTA para navegação, símbolos, project groups, dependências e ações da IDE;
2. tornar intenção → visualização um contrato uniforme das ferramentas;
3. concluir o diff inline com aceite e rejeição por bloco;
4. implementar CLI Manager para Codex, Claude Code, Gemini CLI e GitHub Copilot CLI;
5. provisionar MCP com detecção, backup, merge, teste, reparação e remoção segura;
6. integrar terminal acoplável com perfis, histórico, snippets e encerramento da árvore de processos;
7. permitir escolher entre agente nativo e executores CLI sem reiniciar a IDE;
8. oferecer instalação opcional pelos canais oficiais, diagnóstico e onboarding;
9. validar novamente Delphi 11, 12 e 13 antes de publicar os artefatos finais.

CLIs não serão redistribuídos dentro do package. O instalador deverá detectar instalações existentes
e, mediante consentimento, delegar a instalação ou atualização aos canais oficiais de cada
fornecedor.

## Cenário E2E obrigatório

1. Criar uma aplicação VCL de cadastro a partir de uma descrição.
2. Abrir o projeto criado e concluir o primeiro build.
3. Criar domínio, persistência, form e eventos.
4. Mostrar e aplicar uma revisão multi-arquivo.
5. Gerar e executar testes DUnitX.
6. Iniciar o debugger e aguardar um breakpoint.
7. Inspecionar stack e valores seguros.
8. Preparar e aplicar uma correção.
9. Recompilar e executar novamente os testes.
10. Apresentar e criar um commit revisável.

## Definition of Done

- Nenhum buffer não salvo é perdido.
- Toda mutação relevante possui preview, consentimento ou ambos.
- O agente pode ser pausado, cancelado e retomado.
- Build e testes terminam verdes no cenário de referência.
- O debugger é acompanhado por eventos, não por espera bloqueante.
- O diff final corresponde ao commit proposto.
- Auditoria não contém secrets.
- Não há leak, deadlock, discovery ou processo órfão.
- As evidências cobrem Delphi 11, 12 e 13 conforme a matriz oficial.
