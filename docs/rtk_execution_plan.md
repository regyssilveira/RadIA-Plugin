# Plano de execução do RTK interno

## 1. Goal

Entregar um compactador interno de resultados agentivos que reduza de forma mensurável o contexto
enviado aos modelos, preserve integralmente as evidências e permita recuperar qualquer trecho
omitido sem repetir a operação original.

Neste documento, **RTK viável** significa uma capacidade nativa do RadIA, implementada em Delphi e
sem dependência obrigatória do executável externo `rtk.exe`.

## Resultado da execução na versão 2.3.0

Todas as fases e gates deste plano foram concluídos. A implementação interna obteve 96,71% de
redução no corpus, 96,55% no contexto de decisão e 0% de aumento em chamadas repetidas. A matriz
Release passou com 892/892 testes e zero leaks nos três alvos, o smoke IDE64 carregou 126 ferramentas
e o quality gate do SonarQube foi aprovado sem issues. A versão 2.3.0 foi publicada em 8 de agosto
de 2026.

Consulte a [auditoria de viabilidade](result_compaction_release_audit_2.3.0.md) e a
[evidência mensurada](result_compaction_evidence_2.3.0.json).

## 2. Estado inicial

O primeiro slice já está disponível:

- `TRadIAResultCompactor` atua no contexto da próxima decisão do agente;
- `RunDUnitXTests.output` e `GetGitDiff.diff` removem ANSI, agrupam linhas consecutivas repetidas e
  preservam início e fim quando o texto ultrapassa o limite;
- a transformação só é usada quando o JSON final fica menor;
- o checkpoint, o replay, a UI e os validation gates continuam recebendo o resultado integral;
- cada compactação informa contagens de caracteres original e final;
- testes protegem compactação, fallback e preservação do checkpoint.

Essa base ainda não constitui um RTK viável porque o agente não consegue recuperar diretamente um
trecho omitido, não existe orçamento global de contexto nem medição agregada por sessão.

## 3. Definição de pronto

O goal estará concluído somente quando todos os gates abaixo forem comprovados:

| Dimensão | Critério mínimo |
|---|---|
| Economia | Redução mediana de pelo menos 30% nos caracteres de resultados elegíveis. |
| Contexto total | Redução mediana de pelo menos 20% no contexto de decisão dos cenários benchmark. |
| Fidelidade | 100% de paths, linhas, exit codes, errors, failures e validation gates preservados. |
| Recuperação | Todo conteúdo omitido pode ser consultado por step e range sem reexecutar a tool. |
| Comportamento | Aumento menor que 5% em chamadas repetidas nos benchmarks com compactação. |
| Desempenho | P95 inferior a 10 ms para 100 KiB e inferior a 50 ms para 1 MiB em máquina de referência. |
| Memória | Nenhum leak DUnitX e pico adicional limitado e documentado para payload de 1 MiB. |
| Compatibilidade | Build e testes aprovados na matriz Delphi vigente. |
| Segurança | Métricas e auditoria não armazenam código, prompts, argumentos ou secrets. |
| Operação | Configuração, diagnóstico, fallback, documentação e rollback estão disponíveis. |

## 4. Princípios de implementação

1. O resultado integral é a fonte de verdade; a forma compactada é uma projeção descartável.
2. Compactação nunca altera o resultado retornado por MCP, UI, replay ou validation gates.
3. Regras determinísticas têm prioridade sobre sumarização por LLM.
4. Erros, failures, paths, posições, fingerprints, status e exit codes possuem prioridade máxima.
5. Falha de parsing, timeout, falta de memória ou ganho não positivo resulta em passthrough.
6. Orçamentos são aplicados na fronteira do contexto do modelo, não na execução da ferramenta.
7. Nenhuma telemetria contém conteúdo; apenas contagens, duração, categoria e resultado da regra.
8. Cada nova regra exige fixtures reais, testes de fidelidade e benchmark antes de ser habilitada.

## 5. Sequência de execução

### Fase 0 — baseline e contratos

Objetivo: congelar o comportamento atual e tornar ganho e fidelidade mensuráveis.

Entregáveis:

- `IRadIAResultCompactor` para desacoplar o runtime da implementação;
- records versionados de política, resultado e métricas;
- fixtures sanitizadas de DUnitX, Git diff, build, conhecimento, debugger e FastMM5;
- benchmark A/B que execute os mesmos snapshots com compactação ligada e desligada;
- relatório baseline com tamanho, tempo, economia e evidências críticas preservadas;
- ADR da fronteira entre resultado integral, artefato e projeção compactada.

Gate F0:

- baseline reproduzível por um único comando;
- nenhuma fixture contém credenciais ou código proprietário;
- métricas atuais registradas sem alterar o contexto produzido;
- contratos aprovados nos testes Delphi.

Dependências: nenhuma. Estimativa: 3 a 5 dias úteis.

### Fase 1 — armazenamento e recuperação integral

Objetivo: permitir compactação agressiva sem forçar reexecução da ferramenta.

Entregáveis:

- `IRadIAAgentResultStore` confinado ao diretório da sessão;
- artefato integral identificado por session, step e hash SHA-256;
- gravação atômica, limite por sessão, expiração e limpeza no lifecycle correto;
- tools `GetToolResultSummary` e `GetToolResultRange` somente leitura;
- range baseado em caracteres com boundary Unicode seguro;
- metadados `fullResultAvailable`, `artifactId`, tamanho e hash no contexto compactado;
- recuperação coberta pela mesma policy pipeline, boundary e auditoria das demais tools.

Gate F1:

- qualquer trecho omitido é recuperável sem executar novamente build, teste ou Git;
- hash do artefato recuperado corresponde ao resultado original;
- traversal, session spoofing, range inválido e artefato expirado são rejeitados;
- cancelamento, concorrência e shutdown não deixam escrita parcial;
- resultado integral não é duplicado dentro do contexto enviado ao modelo.

Dependências: F0. Estimativa: 5 a 8 dias úteis.

### Fase 2 — orçamento global do contexto

Objetivo: impedir que o acúmulo de etapas esgote a janela mesmo quando cada resultado respeita seu
limite individual.

Entregáveis:

- `TRadIAAgentContextBudget` com limite total e reservas por categoria;
- estimativa comum de tokens, identificada explicitamente como estimativa;
- prioridade para etapa atual, failures, errors, validation gates e mutações recentes;
- compactação progressiva de etapas antigas;
- garantia de espaço para objetivo, plano, estado de validação e próxima decisão;
- metadados de orçamento no snapshot de decisão, sem poluir o checkpoint integral.

Política inicial:

1. Reservar contexto fixo para objetivo, plano e validação.
2. Preservar integralmente a etapa mais recente quando couber.
3. Preservar todos os erros e failures estruturados.
4. Compactar resultados elegíveis das etapas anteriores.
5. Substituir etapas estabilizadas por envelopes semânticos.
6. Omitir somente conteúdo recuperável pelo result store.

Gate F2:

- o snapshot de decisão nunca ultrapassa o orçamento configurado;
- os validation gates continuam tomando a mesma decisão com compactação ligada ou desligada;
- todo item omitido aponta para um artefato recuperável;
- testes cobrem 1, 10, 50 e 100 etapas.

Dependências: F1. Estimativa: 5 a 7 dias úteis.

### Fase 3 — compactadores Delphi especializados

Objetivo: substituir truncamento genérico por regras que conheçam os contratos do RadIA.

Ordem de implementação:

| Prioridade | Superfície | Regra principal |
|---|---|---|
| P0 | Build/compilador | Preservar errors; agrupar warnings e hints por código, arquivo e mensagem. |
| P0 | DUnitX | Preservar failures, errors e stacks; resumir testes aprovados por fixture. |
| P0 | Git diff | Orçamento por arquivo e hunk; preservar headers, mudanças e estatísticas. |
| P1 | Knowledge | Deduplicar chunks e limitar por score, arquivo e símbolo com proveniência. |
| P1 | Workspace/símbolos | Resumir listas e preservar itens referenciados pelo plano ou etapa atual. |
| P1 | Debugger | Deduplicar frames/watches e preservar exceção, thread e frames do projeto. |
| P2 | FastMM5 | Agrupar leaks por fingerprint, classe, tamanho e primeiro frame do projeto. |
| P2 | Runtime evidence | Deduplicar eventos e preservar falha, screenshot metadata e correlação. |

Para cada compactador:

- declarar schema/versão e campos críticos;
- manter fixtures de sucesso, falha, cancelamento, timeout e payload extremo;
- comparar automaticamente os campos críticos antes e depois;
- recusar a projeção quando o ganho for nulo ou a validação de fidelidade falhar.

Gate F3:

- P0 e P1 implementados e aprovados;
- redução mínima de 30% em cada corpus elegível ou passthrough justificado;
- nenhum campo crítico perdido em todas as fixtures;
- compactadores desconhecidos continuam em passthrough.

Dependências: F0 e F1; pode avançar em paralelo com F2 após estabilizar os contratos. Estimativa:
10 a 15 dias úteis.

### Fase 4 — compactação semântica do histórico

Objetivo: reduzir etapas antigas a envelopes determinísticos, mantendo rastreabilidade.

Entregáveis:

- envelope com tool, status, duração, risco, arquivos afetados, resumo e artifact id;
- regras distintas para leitura, mutação, build, teste, execução e debugger;
- retenção integral das etapas posteriores à mutação ainda não validada;
- reidratação da etapa por range quando a decisão exigir detalhe;
- schema versionado e migração compatível de checkpoints anteriores.

Gate F4:

- retomada e replay de checkpoints antigos continuam funcionando;
- uma mutação nunca perde sua relação com build/teste posteriores;
- redução mínima de 40% em sessões benchmark de 20 ou mais etapas;
- nenhum aumento acima de 5% em chamadas repetidas.

Dependências: F1 e F2. Estimativa: 5 a 8 dias úteis.

### Fase 5 — configuração e observabilidade

Objetivo: tornar o recurso operável, diagnosticável e reversível.

Entregáveis:

- configuração `Off`, `Conservative` e `Balanced`, com `Conservative` como primeiro default;
- limites de contexto, artefatos e retenção validados;
- seção sanitizada em `/status` e `GetRadIAStatus`;
- métricas por sessão: chamadas elegíveis, compactações, passthrough, caracteres e tempo;
- diagnóstico que identifique regra, versão e motivo do fallback;
- UI e documentação para desativar o recurso sem reiniciar a IDE quando possível.

Gate F5:

- alternar para `Off` reproduz o comportamento integral anterior;
- configuração inválida volta a defaults seguros;
- status e logs não contêm payload, prompt, path sensível ou argumentos;
- documentação pt-BR/en-US, hints e testes documentais aprovados.

Dependências: F2 e F3. Estimativa: 4 a 6 dias úteis.

### Fase 6 — hardening e benchmark de viabilidade

Objetivo: provar segurança, desempenho e benefício antes de habilitar por padrão.

Entregáveis:

- fuzz tests para JSON inválido, ANSI incompleto, Unicode, linhas gigantes e nesting extremo;
- testes de carga para 100 KiB, 1 MiB e limite máximo aceito;
- teste concorrente de múltiplas sessões e cancelamento;
- testes de shutdown com compactação e gravação de artefato em andamento;
- benchmark A/B de jornadas reais: fix-build, geração/teste, Git e diagnóstico runtime;
- relatório com mediana, P95, regressões, chamadas repetidas e decisão go/no-go;
- validação na matriz Delphi vigente e análise SonarQube exclusivamente pela API REST local.

Gate F6 — viabilidade:

- todos os critérios da seção **Definição de pronto** atendidos;
- zero falha e zero leak nas suítes exigidas;
- zero corrupção ou artefato parcial em testes de cancelamento/shutdown;
- nenhuma regressão funcional nos benchmarks A/B;
- relatório de evidência revisável armazenado em `docs/`.

Dependências: F0 a F5. Estimativa: 5 a 8 dias úteis.

### Fase 7 — rollout controlado

Objetivo: habilitar o RTK interno com recuperação simples e rollback imediato.

Etapas:

1. Publicar como opt-in em `Conservative`.
2. Coletar somente métricas locais sanitizadas e feedback explícito.
3. Corrigir regressões e congelar schemas.
4. Tornar `Conservative` padrão apenas após o Gate F6.
5. Manter `Off` e rollback de configuração durante pelo menos uma linha minor.

Gate F7:

- release checklist, manual, changelog e troubleshooting atualizados;
- smoke dentro da IDE cobre ativação, compactação, recuperação e desativação;
- upgrade e downgrade preservam checkpoints compatíveis;
- rollback não exige apagar sessões ou artefatos manualmente.

Dependências: F6. Estimativa: 3 a 5 dias úteis, além da janela de observação.

## 6. Caminho crítico e paralelização

```text
F0 Contracts
  -> F1 Result Store
      -> F2 Context Budget
          -> F4 History Compaction
              -> F5 Operations
                  -> F6 Viability
                      -> F7 Rollout

F0 Contracts
  -> F3 Specialized Compactors
      -> F5 Operations
```

O caminho crítico é F0 → F1 → F2 → F4 → F5 → F6 → F7. Depois de F1, F3 pode avançar em paralelo
com F2. A estimativa bruta para uma pessoa é de 40 a 62 dias úteis, sem contar a janela de observação
do rollout. A estimativa deve ser recalibrada no final de F0 com os benchmarks e contratos reais.

## 7. Backlog executável

| ID | Item | Fase | Dependência | Evidência de conclusão |
|---|---|---|---|---|
| RTK-001 | Introduzir contratos e injeção do compactador | F0 | — | Testes com fake e runtime desacoplado. |
| RTK-002 | Criar corpus sanitizado e runner A/B | F0 | RTK-001 | Relatório baseline reproduzível. |
| RTK-003 | Registrar ADR da projeção compactada | F0 | RTK-001 | ADR revisado e linkado. |
| RTK-010 | Implementar result store atômico | F1 | RTK-001 | Hash, lifecycle e concorrência testados. |
| RTK-011 | Implementar consulta de summary/range | F1 | RTK-010 | Recuperação sem reexecução comprovada. |
| RTK-012 | Aplicar boundary, auditoria e expiração | F1 | RTK-010 | Casos de abuso rejeitados. |
| RTK-020 | Implementar orçamento global | F2 | RTK-011 | Snapshots sempre dentro do limite. |
| RTK-021 | Implementar prioridade de evidências | F2 | RTK-020 | Campos críticos preservados. |
| RTK-030 | Compactador de build | F3 | RTK-002 | Corpus e fidelidade aprovados. |
| RTK-031 | Compactador DUnitX estruturado | F3 | RTK-002 | Failures e stacks preservados. |
| RTK-032 | Compactador Git por arquivo/hunk | F3 | RTK-002 | Mudanças e headers preservados. |
| RTK-033 | Compactadores Knowledge/Workspace | F3 | RTK-002 | Proveniência e símbolos preservados. |
| RTK-034 | Compactadores Debug/FastMM/Runtime | F3 | RTK-002 | Evidências críticas preservadas. |
| RTK-040 | Envelope semântico de etapas antigas | F4 | RTK-020 | Redução e reidratação comprovadas. |
| RTK-041 | Versionar/migrar checkpoints | F4 | RTK-040 | Retomada de fixtures antigas aprovada. |
| RTK-050 | Configuração e status sanitizado | F5 | RTK-020, RTK-030 | Off/Conservative/Balanced testados. |
| RTK-051 | Documentação, hints e troubleshooting | F5 | RTK-050 | Testes documentais aprovados. |
| RTK-060 | Fuzz, carga, concorrência e shutdown | F6 | RTK-041, RTK-050 | Relatório sem corrupção ou leak. |
| RTK-061 | Benchmark final e go/no-go | F6 | RTK-060 | Todos os critérios mensurados. |
| RTK-070 | Rollout opt-in e smoke IDE | F7 | RTK-061 | Checklist e evidência real aprovados. |

## 8. Validação por fase

Toda fase que altera código deve executar, no mínimo:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test
npm run lint
npm run test:docs
```

Quando a matriz vigente exigir outras versões ou arquiteturas, executar também os comandos de
`docs/delphi_compatibility_matrix.md`. Alterações web executam `npm run test:web`. Consultas ao
SonarQube usam somente a API REST local, conforme `AGENTS.md`.

Cada gate deve armazenar evidência contendo:

- commit e versão dos schemas;
- ambiente e versão do Delphi;
- corpus/fixtures usados;
- resultados com compactação ligada e desligada;
- economia, duração, P95, chamadas repetidas e falhas;
- confirmação de fidelidade dos campos críticos;
- resultado de build, testes, leaks, lint e documentação.

## 9. Riscos e respostas

| Risco | Resposta obrigatória |
|---|---|
| Omissão esconde a causa real | Result store, recuperação por range e prioridade para errors/failures. |
| Métricas superestimam tokens | Separar caracteres de tokens estimados e medir ambos no benchmark. |
| Contexto compactado causa loops | Medir chamadas repetidas e bloquear rollout acima do limite de 5%. |
| Checkpoint cresce indefinidamente | Quota, retenção, expiração e limpeza por sessão. |
| Payload extremo afeta a IDE | Limites, parsing em background, cancelamento e testes de shutdown. |
| Regra quebra schema de uma tool | Versionamento, fixtures contratuais e passthrough fail-open. |
| Conteúdo vaza em logs | Métricas apenas numéricas e testes de sanitização. |
| Configuração dificulta suporte | Três perfis, defaults seguros e diagnóstico explícito. |

## 10. Próxima ação

Iniciar F0 por `RTK-001`, `RTK-002` e `RTK-003`. Não ampliar o truncamento para novas tools antes de
existirem o contrato de fidelidade e o benchmark baseline. A primeira decisão go/no-go ocorre no fim
de F0; o recurso só pode ser considerado viável após F6.
