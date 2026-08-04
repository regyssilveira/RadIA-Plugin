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

Essa configuração estabelece os perfis e a preferência persistente usados pelo transporte descrito
a seguir.

## Execução integrada ao chat

Quando **Selected CLI** está ativo e existe um projeto Delphi aberto, o modo agente encaminha o
objetivo ao CLI detectado usando a pasta do projeto como diretório de trabalho. O processo:

- roda fora da thread da interface;
- captura stdout e stderr incrementalmente, com limite de memória;
- normaliza a resposta final de JSON ou JSONL para a conversa;
- possui timeout de 15 minutos;
- entra em um Job Object do Windows;
- encerra toda a árvore de processos ao cancelar, exceder o timeout ou fechar o RadIA.

Se o executável não estiver disponível, o RadIA não inicia uma execução parcial: ele informa o
problema e direciona o usuário ao diagnóstico em **CLI & MCP**. A seleção pode ser alterada para o
agente nativo e vale na próxima solicitação, sem reiniciar a IDE.

O terminal acoplável reutilizará o mesmo transporte e callbacks incrementais; sua interface visual,
histórico e snippets ainda fazem parte do gate da versão 2.0.
