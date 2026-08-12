# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, métricas de versões concluídas e notas de
release não pertencem ao backlog.

## Em execução — motor semântico estrutural

| Marco | Resultado verificável | Estado |
|---|---|---|
| Perfil Delphi | defines, scopes, includes e paths da configuração ativa | Concluído |
| Processo e análise lexical | processo isolado, protocolo, supervisão, lexer e pré-processador | Concluído |
| Parser estrutural | declarações modernas, recuperação parcial e corpus RTL/VCL | Concluído |
| Índice incremental | projeto, grupo, RTL e VCL consultáveis com invalidação por unit | Em execução |
| Membros ausentes | preview idempotente, consentimento, undo e compilação | Pendente |
| Consumidores | agente, navegação, Ghost Text e DFM/PAS usam índice com fallback | Pendente |
| Completion e diagnóstico | resposta local cancelável, métricas e `/doctor --deep` | Pendente |
| Candidato de release | Delphi 12/13, testes, Sonar, instalador e documentação | Pendente |

O contrato técnico detalhado fica em
[`.planning/semantic_engine_goal.md`](../../.planning/semantic_engine_goal.md), fora da documentação
de uso. Ideias ainda não aprovadas não são backlog; a direção de longo prazo fica no
[roadmap](roadmap.md).
