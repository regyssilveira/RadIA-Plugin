# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, métricas de versões concluídas e notas de
release não pertencem ao backlog.

## Em execução — motor semântico estrutural

| Marco | Resultado verificável | Estado |
|---|---|---|
| Perfil Delphi | defines, scopes, includes e paths da configuração ativa | Concluído |
| Processo e análise lexical | processo isolado, protocolo, supervisão, lexer e pré-processador | Concluído |
| Parser estrutural | declarações modernas e recuperação parcial de erros | Em execução |
| Índice incremental | projeto, grupo, RTL e VCL consultáveis com invalidação por unit | Pendente |
| Membros ausentes | preview idempotente, consentimento, undo e compilação | Pendente |
| Consumidores | agente, navegação, Ghost Text e DFM/PAS usam índice com fallback | Pendente |
| Completion e diagnóstico | resposta local cancelável, métricas e `/doctor --deep` | Pendente |
| Candidato de release | Delphi 12/13, testes, Sonar, instalador e documentação | Pendente |

O contrato técnico detalhado fica em
[`.planning/semantic_engine_goal.md`](../../.planning/semantic_engine_goal.md), fora da documentação
de uso.

## Sem versão comprometida

| Área | Itens |
|---|---|
| Assistência de código | revisão automática ao salvar; Clean Uses; gerador de mocks |
| Diagnóstico | trace multiarquivo; importadores MadExcept/EurekaLog |
| APIs | OpenAPI/Swagger para projetos existentes |
| Modernização | migração residual para DEXT; decomposição guiada de forms |
| Operação | painel de cache; assistente de threads/PPL |
| Produtividade | wizard de internacionalização; geração de documentação de API |

Esses itens são oportunidades, não promessas. Lazarus, C++, Delphi 11 e marketplace permanecem fora
do escopo atual.
