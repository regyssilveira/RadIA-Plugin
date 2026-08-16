# Goal de fechamento determinístico dos gaps competitivos

## Objetivo

Encerrar, com evidência reproduzível, todas as diferenças acionáveis identificadas na experiência
Delphi do RadIA. O trabalho deve produzir ganhos percebidos pelo usuário e impedir que capacidades
já entregues voltem a ser classificadas como pendentes sem uma regressão comprovada.

## Resultado observável

Um usuário com conhecimento mínimo do RadIA consegue escrever código com completion semântica,
implementar contratos, navegar, criar e alterar forms, acompanhar o agente, trabalhar com banco de
dados, usar o terminal, autorizar jornadas e compreender as fontes usadas pelo assistente. Esses
fluxos permanecem estáveis no Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64.

## Regra de fechamento definitivo

Cada frente terá uma ficha versionada em `Output/Validation/CompetitiveClosure` contendo baseline,
cenários, métricas, resultado e revisão Git. Uma frente passa a `closed` somente quando todos os seus
critérios forem aprovados no mesmo commit limpo. Depois disso, ela somente pode ser reaberta por:

1. teste de regressão reproduzível;
2. cenário de usuário com resultado esperado e resultado real;
3. benchmark executado no mesmo ambiente e com diferença material;
4. capacidade externa nova, disponível publicamente e comparável ao escopo do RadIA.

Listas de marketing, integração exclusiva do fabricante e afirmações sem cenário reproduzível não
reabrem uma frente. Toda comparação futura deve consumir o último ledger aprovado antes de declarar
um novo gap.

## Escopo fechado

1. completion semântica, membros ausentes, navegação e Ghost Text;
2. jornada orientada à intenção entre Designer, Code, Problems, testes e debugger;
3. chat simplificado e progresso observável do agente e das CLIs;
4. experiência visual segura para banco de dados;
5. terminal integrado às jornadas;
6. robustez do WebView atual em dock, undock, resize e recuperação;
7. conhecimento local explicável;
8. consentimento orientado à jornada;
9. isolamento, recuperação e métricas do motor semântico.

## Fora do escopo

- repositório público, marketplace ou registry remoto de extensões;
- C++Builder, Delphi 11, Lazarus ou leitura de DCU;
- GetIt, assinatura comercial ou integração exclusiva da Embarcadero;
- substituição do WebView2 atual ou criação de componente por DirectComposition;
- reprodução de capacidades proprietárias sem contrato público verificável.

## Fase 0 — baseline e ledger

### Entregas

- criar manifesto versionado das nove frentes e seus cenários;
- registrar capacidades já existentes, ferramentas, UI, testes e documentação que as comprovam;
- executar o baseline nos três alvos suportados;
- classificar cada critério como `passed`, `failed`, `not-supported` ou `not-applicable`;
- proibir status baseado apenas em existência de classe, tool ou texto documental.

### Gate

O relatório deve distinguir claramente ausência, regressão, melhoria de UX e capacidade já entregue.
Nenhuma implementação começa antes desse baseline ser aprovado.

### Comandos do gate

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts/New-RadIA.CompetitiveClosureBaseline.ps1
powershell.exe -ExecutionPolicy Bypass -File scripts/Test-RadIA.CompetitiveClosureLedger.ps1 `
  -LedgerPath Output/Validation/CompetitiveClosure/CurrentBaseline.json
```

O manifesto versionado fica em `.planning/competitive_closure_manifest.json`. O validador recusa
worktree sujo, versão ou commit divergente, frentes ou checks ausentes, duplicidades, evidência sem
comando e artefato e qualquer fechamento que não cubra os três alvos suportados.

## Fase 1 — inteligência de código comprovada

Completion, membros ausentes e navegação já existem. Esta fase mede, corrige e fecha a diferença sem
criar um segundo motor.

### Cenários obrigatórios

- completion após `.` para local, parâmetro, campo, propriedade, `Self`, `Result` e variável global;
- cadeias com no mínimo quatro segmentos, herança, generics, aliases e units com shadowing;
- perfis independentes Delphi 12 e 13, incluindo defines e código inativo;
- implementação idempotente de interfaces, abstratos, overloads, calling conventions e generics;
- navegação entre declaração, implementação, ancestral, override, referência Pascal e referência DFM;
- fallback limitado quando o processo semântico estiver indisponível.

### Métricas e gate

- pelo menos 99% das units RTL/VCL do corpus sem falha estrutural fatal;
- zero divergência silenciosa de spans no corpus-oráculo;
- p95 aquecido de completion e navegação de até 50 ms;
- 100% dos fixtures de membros ausentes compilando no Delphi 12 e 13;
- segunda execução de implementação sem produzir alterações;
- crash, timeout e cache corrompido recuperados sem reiniciar a IDE;
- Ghost Text mostra até três alternativas ordenadas, com latência e origem diagnosticáveis.

## Fase 2 — intenção, Designer e superfície correta

### Entregas

- centralizar a política `intent -> surface` no host;
- mutação visual termina no Designer e seleciona o componente afetado;
- código ou evento termina no editor e destaca o intervalo alterado;
- build termina em Problems quando houver achados;
- teste termina no resultado DUnitX e debugger termina na localização de execução;
- cada transição preserva chat, journey, foco recuperável e detalhes de auditoria.

### Gate

Criar uma aplicação VCL por prompt, alterar layout, criar evento, compilar, executar testes e iniciar
debug sem o usuário escolher manualmente a superfície. O cenário deve passar nos três alvos.

## Fase 3 — chat e progresso operacional

### Entregas

- recomendar uma rota válida e ocultar combinações incompatíveis;
- explicar modo, executor, transporte, credencial e dependência em linguagem de tarefa;
- exibir etapa, atividade atual, duração, saída resumida e próxima ação durante CLI e agente nativo;
- projetar consentimento pendente dentro do chat com ação visual para localizar o diálogo nativo;
- manter detalhes técnicos recolhidos, sem esconder falhas ou bloquear cancelamento.

### Gate

Usuários de teste devem concluir criação, correção e diagnóstico sem conhecer MCP, provider transport
ou nomes de tools. Nenhum período ativo superior a dois segundos pode ficar apenas em “pensando” sem
estado observável.

## Fase 4 — banco de dados como jornada segura

### Entregas

- explorer de conexões FireDAC sem persistir credenciais em texto claro;
- inspeção somente leitura de schema, tabelas, campos, índices e relacionamentos;
- associação explícita entre conexão e projeto;
- chat contextual, preparação de SQL e explicação do plano;
- execução padrão somente leitura, consentimento por jornada e bloqueio de múltiplos comandos;
- grid virtualizado com limite, paginação, cancelamento, cópia e exportação sanitizada;
- mutações somente em modo explícito, com transação, preview e rollback quando suportado.

### Gate

Em uma fixture local, o usuário deve descobrir o schema, gerar e revisar uma consulta, executá-la,
visualizar e exportar o resultado. Tentativas destrutivas, secrets e resultados sem limite devem ser
bloqueados pelos testes.

## Fase 5 — terminal ligado à jornada

### Entregas

- command palette pesquisável, favoritos, perfis e busca reversa persistente;
- links seguros entre saída, arquivo e linha;
- envio de seleção ou erro ao chat sem copiar secrets;
- vínculo visível com projeto, journey e execução do agente;
- restauração limitada de sessões e encerramento sem processos órfãos.

### Gate

Executar build por perfil, navegar de um erro até o editor, enviá-lo ao chat e retomar o terminal nos
três alvos, preservando Unicode, TUI, cancelamento e consentimento existentes.

## Fase 6 — dock e ciclo de vida do WebView atual

### Entregas

- estado explícito para criação, navegação, docking, undocking, resize, falha e recuperação;
- preservação de conversa, scroll, composer, seletores e foco recuperável;
- recuperação limitada após falha do processo WebView2;
- telemetria local sanitizada de falhas de lifecycle.

### Gate

Vinte e cinco ciclos automatizados de dock/undock/resize por alvo, alternando tema e foco, sem tela
branca persistente, perda de conteúdo, deadlock, Access Violation ou processo órfão.

## Fase 7 — conhecimento explicável

### Entregas

- cada resposta derivada do índice mostra arquivo, linhas, revisão e motivo da seleção;
- painel de cobertura, atualização, exclusões, embeddings e fallback;
- rebuild total ou seletivo por fonte;
- perfil separado para projeto, RTL, VCL e bibliotecas configuradas;
- comparação sanitizada da cobertura entre revisões.

### Gate

Consultas fixture devem retornar fontes determinísticas e explicar ausência ou fallback. Conteúdo
excluído, stale ou pertencente a outro projeto nunca pode aparecer.

## Fase 8 — consentimento por jornada

### Entregas

- agrupar operações previstas por journey, risco, escopo e recurso afetado;
- tornar `Allow session` disponível quando a policy permitir e explicar quando não permitir;
- permitir revogação imediata e mostrar autorizações ativas;
- impedir prompts repetidos para operação equivalente já autorizada;
- nunca propagar autorização para risco, projeto ou origem diferente.

### Gate

A jornada da calculadora deve concluir sem consentimentos redundantes, preservando confirmação
individual para ações destrutivas. Testes cobrem expiração, revogação, conflito e troca de projeto.

## Fase 9 — supervisão do motor semântico

### Entregas

- health, versão de protocolo, perfil, corpus, cache, memória e latência no `/doctor --deep`;
- restart com backoff e limite, circuit breaker e fallback explícito;
- cache versionado por compilador, plataforma, defines e revisão;
- métricas agregadas locais sem conteúdo do código;
- limpeza determinística no shutdown.

### Gate

Fault injection de crash, hang, resposta incompatível e cache inválido não pode travar o `bds.exe`,
perder o buffer ou exigir reinício da IDE.

## Fase 10 — fechamento integrado

### Gate indivisível

1. lint, testes web e testes documentais;
2. DUnitX completo no Delphi 12 e 13;
3. corpus semântico e benchmarks nos dois compiladores;
4. matriz OTA e E2E nos três alvos;
5. calculadora e todos os templates de projeto;
6. banco, terminal, Designer/Code, conhecimento, consentimento e fault injection;
7. SonarQube aprovado e zero issues;
8. documentação PT/EN, hints e catálogo runtime sincronizados;
9. instalador local validado a partir do mesmo commit limpo;
10. ledger com todas as frentes em `closed` e nenhum critério `failed`.

## Ordem de execução

`F0 -> F1 -> F2 -> F3 -> F4 -> F5 -> F6 -> F7 -> F8 -> F9 -> F10`.

F1 fecha a base semântica usada pelas demais fases. F2 e F3 estabilizam a experiência principal.
Banco e terminal entram depois da navegação e do progresso. Lifecycle, conhecimento, consentimento e
supervisão consolidam a plataforma antes do gate final.

## Condição de conclusão do goal

O goal somente termina quando as nove frentes estiverem `closed` no ledger do mesmo commit aprovado.
Não haverá release parcial nem nova comparação competitiva usada como substituto desse gate.
