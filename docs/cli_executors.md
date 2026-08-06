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

## Instalação opcional pelo canal oficial

Em **Configurações > CLI & MCP**, o botão **Install** ou **Update** apresenta o comando completo e
os pré-requisitos antes de solicitar confirmação. Depois da aprovação, a instalação roda fora da
thread da IDE, mostra stdout e stderr no painel e possui timeout e encerramento da árvore de
processos.

| Executor | Canal usado pelo Rad IA | Pacote oficial |
|---|---|---|
| Codex CLI | npm | `@openai/codex` |
| Claude Code | npm | `@anthropic-ai/claude-code` |
| Gemini CLI | npm | `@google/gemini-cli` |
| GitHub Copilot CLI | WinGet | `GitHub.Copilot` |

Os identificadores vêm de um catálogo interno e são validados contra metacaracteres antes da
execução. O Rad IA não baixa, empacota ou redistribui binários desses fornecedores. A autenticação
continua sendo feita pelo próprio CLI depois da instalação.

## Detecção e versão instalada

Ao abrir o painel **CLI & MCP**, trocar o cliente ou usar **Refresh**, o RadIA procura primeiro o
caminho configurado e depois o `PATH` do Windows. Quando encontra o executável, chama
`--version` em segundo plano, com timeout de dez segundos, e apresenta na própria tela:

- nome e versão informados pelo CLI;
- caminho efetivamente usado;
- falha do diagnóstico, sem impedir a configuração ou atualização.

Uma resposta atrasada é descartada se o usuário trocar de cliente durante a verificação. Esse
diagnóstico não autentica, não altera arquivos e não inicia uma sessão de agente. O login continua
sendo controlado pelo próprio CLI.

### Diagnóstico de autenticação

Depois da versão, o RadIA executa um probe somente-leitura quando o fornecedor disponibiliza um
comando não interativo estável:

| Executor | Probe automático | Orientação de login |
|---|---|---|
| Codex CLI | `codex login status` | `codex login` |
| Claude Code | `claude auth status` | `claude auth login` |
| Gemini CLI | Não disponível | iniciar `gemini` e usar `/auth` |
| GitHub Copilot CLI | Não disponível | `copilot login` |

O painel mostra **authentication: ready** quando o probe termina com sucesso. Caso contrário,
mostra **authentication: required** e o comando de correção. Para os clientes sem probe oficial,
o estado é apresentado como verificação manual, sem tentar inferir login pela existência de
arquivos ou variáveis de ambiente.

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

O terminal acoplável reutiliza o mesmo transporte, streaming, timeout e cancelamento em cascata.
Veja [Terminal](terminal.md).
