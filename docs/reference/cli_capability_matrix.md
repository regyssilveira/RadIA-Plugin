# Matriz contratual de capacidades dos executores CLI

> **Natureza:** contrato técnico para implementação e testes. Uma capacidade declarada pelo CLI
> não significa que o RadIA já a exponha na interface.

## Como interpretar

- **Contrato do CLI** registra a capacidade publicada pelo fornecedor e representada por
  `TRadIAExecutorContractCatalog`.
- **Uso atual no RadIA** descreve o comportamento disponível no produto.
- Toda execução futura deve confirmar a capacidade contra o executável detectado. Uma versão
  incompatível deve produzir diagnóstico explícito, nunca fallback silencioso.
- FIM é um contrato de completion separado do chat. Nenhum dos quatro CLIs é presumido como FIM
  apenas por aceitar um modelo configurável.

## Matriz atual

| Executor | Saída estruturada | ID de sessão | Retomada estável | Modelo | MCP | FIM dedicado | Uso no RadIA 2.17.12 |
|---|---:|---:|---:|---:|---:|---:|---|
| Codex CLI | Sim, JSONL | Evento estruturado | `exec resume <id>` | Sim | Sim | Não declarado | Nova execução por mensagem |
| Claude Code | Sim, stream JSON | Evento estruturado | `--resume <id>` | Sim | Sim | Não declarado | Nova execução por mensagem |
| Gemini CLI | Sim, stream JSON | Evento `init` | `--resume <id>` | Sim | Sim | Não declarado | Nova execução por mensagem |
| GitHub Copilot CLI | Sim, JSONL | Hint de encerramento | `--resume=<id>` | Sim | Sim | Não declarado | Nova execução por mensagem |

## Fontes primárias do contrato

- [Codex CLI](https://learn.chatgpt.com/docs/developer-commands?surface=cli) — execução JSON e retomada por ID.
- [Claude Code CLI](https://code.claude.com/docs/en/cli-usage) — saída estruturada,
  modelo, MCP e `--resume`.
- [Gemini CLI](https://geminicli.com/docs/reference/configuration/) e
  [modo headless](https://geminicli.com/docs/cli/headless/) — stream JSON, evento `init`, modelo e
  `--resume`.
- [GitHub Copilot CLI](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference)
  — JSONL, modelo, MCP e identificador informado ao encerrar uma execução programática.

As fontes registram o contrato esperado; o probe de runtime previsto para a Fase 6 deverá confrontar
esse contrato com a versão local antes de habilitar capacidades opcionais.

## Identidades e isolamento

`TRadIAAgentScopeIdentity` delimita cinco fronteiras que não podem ser inferidas umas das outras:

| Identidade | Finalidade |
|---|---|
| Jornada | Correlacionar uma tarefa que atravessa mais de uma superfície |
| Conversa | Representar o histórico lógico visto pelo usuário |
| Sessão | Representar a execução do agente ou CLI |
| Projeto | Impedir mistura de contexto entre workspaces |
| Solicitação | Rejeitar callbacks e respostas tardias |

Uma identidade só é completa quando todas as fronteiras estão presentes. Duas solicitações
pertencem à mesma jornada somente quando `JourneyId` e `ProjectId` coincidem.

## Baseline mensurável

| Risco | Evidência inicial | Gate futuro |
|---|---|---|
| Timeout e cancelamento | Processo externo possui timeout e encerramento em Job Object | Nenhum processo filho após cancelar |
| Resposta obsoleta | Troca de provider/executor descarta callbacks antigos | Correlação também inclui jornada e sessão CLI |
| Retomada | Implementada por ID para os quatro clientes | Validar versão antes de capacidades opcionais |
| Latência | Duração é registrada na central de execução | Separar startup, primeiro evento e conclusão |
| FIM | Ghost Text usa completion geral | Probe de runtime e montagem prefixo/sufixo |

## Próxima fase

A Fase 1 deve consumir este contrato para capturar IDs, persistir somente metadados não secretos e
montar a sintaxe de retomada específica de cada executor.
