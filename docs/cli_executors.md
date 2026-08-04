# Executores de agente por CLI

O RadIA 2.0 oferece uma abstração única para manter o agente nativo como padrão e selecionar um
CLI externo quando esse executor estiver disponível. A preferência fica em **Configurações >
CLI & MCP > Chat executor** e não exige reiniciar a IDE.

## Perfis suportados

| Executor | Modo não interativo | Saída solicitada |
|---|---|---|
| Codex CLI | `exec` | JSONL |
| Claude Code | `-p` | JSON em streaming |
| Gemini CLI | `-p` | JSON em streaming |
| GitHub Copilot CLI | `-p` | JSONL |

O RadIA mantém os argumentos separados até a criação do processo e aplica o escape de argumentos
do Windows apenas na fronteira de execução. O prompt não é concatenado a um comando de shell.

## Seleção e segurança

- **RadIA native agent** permanece como padrão e usa as ferramentas, consentimentos e checkpoints
  internos.
- **Selected CLI** usa o cliente escolhido no mesmo painel e o caminho detectado ou configurado.
- Um identificador desconhecido ou uma configuração corrompida retorna automaticamente ao agente
  nativo.
- A seleção não habilita opções de aprovação automática dos CLIs.
- MCP continua sendo provisionado e diagnosticado separadamente.

Esta camada estabelece os perfis e a preferência persistente. O transporte de processos, streaming,
cancelamento da árvore de processos e renderização no terminal acoplável são a próxima parte do
mesmo fluxo antes do fechamento da versão 2.0.
