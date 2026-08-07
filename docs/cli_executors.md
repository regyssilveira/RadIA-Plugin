# Orquestração nativa e executores por CLI

O RadIA oferece duas escolhas independentes: a **orquestração do agente** e o **transporte de
autenticação do provider**. A preferência de orquestração fica em **Configurações > CLI & MCP >
Chat executor** e não exige reiniciar a IDE.

- **RadIA native orchestration** executa o loop, as ferramentas, os consentimentos e os checkpoints
  dentro do RadIA. Ele não troca silenciosamente para um executor externo.
- **External CLI orchestration** entrega o objetivo diretamente ao CLI selecionado.
- O botão **Agent** do chat liga ou desliga o comportamento agente; ele não escolhe o executor nem
  muda a autenticação do provider.

Providers com API key e providers locais funcionam sem CLI. A opção **Sign in with ChatGPT (OAuth
via Codex CLI)** é uma exceção explícita: nesse tipo de autenticação, o Codex CLI é o transporte do
provider mesmo quando a orquestração é nativa. Para operar totalmente sem CLIs, use uma API key ou
outro provider que ofereça transporte HTTP/local nativo.

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

Em **Configurações > CLI & MCP**, o botão **Install channel** ou **Update channel** apresenta o
comando completo e
os pré-requisitos antes de solicitar confirmação. Depois da aprovação, a instalação roda fora da
thread da IDE, mostra stdout e stderr no painel e possui timeout e encerramento da árvore de
processos. Esse canal é opcional: o botão **Browse...** permite selecionar um `.exe`, `.cmd` ou
`.bat` já existente. Nesse caso, Node.js e npm não são necessários para o RadIA usar o executável.

| Executor | Canal usado pelo Rad IA | Pacote oficial |
|---|---|---|
| Codex CLI | npm | `@openai/codex` |
| Claude Code | npm | `@anthropic-ai/claude-code` |
| Gemini CLI | npm | `@google/gemini-cli` |
| GitHub Copilot CLI | WinGet | `GitHub.Copilot` |

Os identificadores vêm de um catálogo interno e são validados contra metacaracteres antes da
execução. O Rad IA não baixa, empacota ou redistribui binários desses fornecedores. A autenticação
continua sendo feita pelo próprio CLI depois da instalação.

### Assistente guiado de instalação e recuperação

Antes de executar qualquer comando, o RadIA verifica o gerenciador exigido pelo canal oficial. Se
uma CLI baseada em npm não encontrar Node.js/npm, ele oferece instalar o Node.js LTS por `winget`
como uma etapa independente, mostrando o comando e pedindo consentimento. A instalação da CLI possui
uma segunda confirmação. Se `winget` também não existir, nenhuma tentativa cega é feita: o RadIA abre
a página oficial e mostra a ação necessária.

**Manual steps** copia e exibe a URL oficial, o comando completo, os nomes esperados do executável e
a alternativa de selecionar um `.exe`, `.cmd` ou `.bat` portátil. **Start login** abre o comando de
autenticação do cliente em um terminal visível; ao fechar esse terminal, o diagnóstico de versão e
autenticação é repetido automaticamente.

Depois de instalar, o resolver pesquisa o `PATH` e também os diretórios conhecidos do npm, Node.js e
WinGet. Assim, um executável recém-instalado pode ser usado pela IDE atual sem reiniciar o Delphi. O
botão de instalação vira **Cancel** durante uma etapa em andamento.

Instalações, atualizações e conexões/reparos MCP gravam somente metadados sanitizados em
`%USERPROFILE%\RadIA\cli-mcp-setup-history.jsonl`; comandos de autenticação, tokens e saída bruta não
são persistidos.

## Detecção e versão instalada

Ao abrir o painel **CLI & MCP**, trocar o cliente ou usar **Diagnose**, o RadIA procura primeiro o
caminho configurado e depois o `PATH` do Windows. Diagnóstico, ChatGPT OAuth e execução externa
usam o mesmo resolvedor e, portanto, o mesmo caminho efetivo. Quando encontra o executável, chama
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

- **RadIA native orchestration** permanece como padrão e usa as ferramentas, consentimentos e checkpoints
  internos.
- **External CLI orchestration** usa o cliente escolhido no mesmo painel e o caminho detectado ou configurado.
- Um identificador desconhecido ou uma configuração corrompida retorna automaticamente ao agente
  nativo.
- A seleção não habilita opções de aprovação automática dos CLIs.
- MCP continua sendo provisionado e diagnosticado separadamente.

Essa configuração estabelece os perfis e a preferência persistente usados pelo transporte descrito
a seguir.

## Execução integrada ao chat

No agente nativo, o seletor do chat apresenta os modelos disponibilizados pelo provider ativo. Ao
salvar uma troca de provider ou executor, o RadIA recarrega essa lista de forma assíncrona e aplica
a mudança imediatamente, sem reiniciar o Delphi. Respostas atrasadas do provider anterior são
descartadas.

No executor externo, o modelo é administrado pelo próprio CLI. Como os clientes suportados não
oferecem um contrato uniforme e estável para descobrir e selecionar modelos, o seletor do chat fica
desabilitado e informa **Model managed by &lt;CLI&gt;**. Configure o modelo pelos mecanismos do CLI
escolhido; ao retornar ao agente nativo, o seletor volta a usar os modelos do provider.

Quando **External CLI orchestration** está ativo e existe um projeto Delphi aberto, o modo agente encaminha o
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

## Cenários de configuração

| Cenário | Configuração | Exige Node.js/npm no Windows? |
|---|---|---|
| Agente nativo com API key | Orquestração nativa + provider por API | Não |
| Agente nativo com provider local | Orquestração nativa + Ollama/LM Studio | Não |
| ChatGPT OAuth | Qualquer orquestração + caminho do Codex CLI | Não, se um executável existente for selecionado |
| Agente externo | Orquestração externa + CLI selecionado | Não, se um executável existente for selecionado |
| Instalação assistida do Codex/Claude/Gemini | Canal opcional de instalação | Sim |

CLIs instalados apenas dentro do WSL não aparecem no `PATH` do Windows e não são tratados como um
`codex.exe` nativo. Até existir um executor WSL dedicado, use um executável Windows apontado pelo
campo de override ou selecione um provider que não dependa de CLI.

O terminal acoplável reutiliza o mesmo transporte, streaming, timeout e cancelamento em cascata.
Veja [Terminal](terminal.md).
