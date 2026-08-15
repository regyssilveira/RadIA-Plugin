# Solução de problemas da plataforma agentiva

## Comece pelo comando certo

- Execute `/doctor` quando algo não funciona: ele testa a prontidão e indica a próxima ação.
- Execute `/status` para conferir toda a configuração e disponibilidade sem revelar credenciais.
- Use `/status cli` ou `/status mcp` para isolar essas integrações.
- Use `/health` quando o problema está no projeto Delphi aberto, build, testes ou conhecimento local.
- Use `/tools` para confirmar se uma ferramenta existe na instância atual da IDE.

A [referência de comandos](../reference/slash_commands.md#qual-diagnóstico-usar) detalha as diferenças e filtros.
O [guia do RadIA Doctor](../reference/doctor.md) explica a rota efetiva e cada check.

## Ferramentas e consentimento

| Sintoma | Verificação e ação |
|---|---|
| Ferramenta não aparece | Atualize o catálogo, confirme projeto/contexto ativo e extensões carregadas. |
| Consentimento não aparece | Traga a IDE para frente e verifique se existe outro diálogo modal. |
| Consentimento expirou | Repita a solicitação e responda dentro do timeout. |
| Operação foi negada | Revise escopo e risco; a negação não altera o workspace. |
| Cancelamento demorou | Aguarde o ponto cooperativo; não finalize `bds.exe` durante uma escrita. |

## Editor e workspace

| Sintoma | Verificação e ação |
|---|---|
| Path recusado | Use um arquivo do projeto dentro do workspace autorizado. |
| Patch em conflito | Reabra o preview sobre o conteúdo atual; não force um hash antigo. |
| Arquivo não encontrado | Confirme rename, projeto ativo e identidade retornada pela OTA. |
| Build ocupado | Aguarde ou cancele o build atual antes de iniciar outro. |

## MCP

| Sintoma | Verificação e ação |
|---|---|
| Bridge encerra | Confirme IDE carregada e `%APPDATA%\RadIA\mcp.json`. |
| IDE errada | Passe o arquivo `mcp.<pid>.json` da instância desejada. |
| Named pipe ausente | Verifique se o PID existe e reinicie a bridge. |
| Tool call pendente | Procure consentimento aberto na IDE. |
| Erro de protocolo | Envie `initialize` antes de `tools/list` ou `tools/call`. |

## Provider e rota de execução

| Sintoma | Verificação e ação |
|---|---|
| ChatGPT Pro retorna 401 ou 429 | Confirme **ChatGPT Pro via Codex CLI**, abra **Configure Codex CLI login** e execute **Diagnose**. Não use API Key esperando consumir a cota Pro. |
| O modelo exige uma versão mais nova do Codex | Mesmo com **RadIA native**, a opção **ChatGPT Pro via Codex CLI** usa o Codex como transporte. Abra **Configurações > CLI & MCP**, selecione Codex CLI, use **Update channel** ou escolha um executável mais novo, execute **Diagnose**, atualize a lista de modelos e tente novamente. |
| Codex informa que não gerou resposta | Atualize a lista de modelos e selecione um modelo atual. O RadIA trata essa saída como erro de transporte, preserva a causa e recomenda `/doctor --deep`, em vez de encaminhá-la ao agente como uma decisão JSON. |
| Login concluído, mas o chat não reconhece | Feche as configurações, reabra e confirme `authentication: ready`; o RadIA recarrega a sessão antes do envio. |
| Não sei qual rota está ativa | Confira **Send with** e o indicador no cabeçalho da resposta: **RadIA native** mantém a orquestração interna; **CLI direct** delega ao cliente. |
| Codex informa que o diretório não é confiável | Atualize o RadIA. O executor informa o diretório explicitamente e aceita projetos Delphi sem Git em sessões novas e retomadas. Execute `/doctor` para confirmar a rota e o executável. |
| Quero usar a OpenAI API | Selecione **API Key (BYOK)** e configure uma chave com quota da plataforma API, separada do ChatGPT Pro. |

## Conhecimento, Designer e debugger

| Sintoma | Verificação e ação |
|---|---|
| Busca desatualizada | Salve o arquivo ou reconstrua o índice do projeto. |
| Designer indisponível | Abra um formulário compatível e torne-o o Designer ativo. |
| Componente mudou | Gere novo preview a partir do estado atual. |
| Avaliação indisponível | Pause o processo em um frame válido. |
| Controle recusado | Consulte o estado do debugger antes do próximo comando. |
| `Debug process not initialized` ao usar F9 | Atualize o Rad IA e reinicie a IDE. O observador de timeline ignora estados transitórios da OTA e nunca deve bloquear um debug manual. Se persistir, desabilite temporariamente o package e preserve `%APPDATA%\RadIA\Logs` para diagnóstico. |

## Logs e dados locais

- Auditoria: `%APPDATA%\RadIA\audit\tools.jsonl`.
- Conhecimento reconstruível: `%APPDATA%\RadIA\Knowledge`.
- Discovery MCP: `%APPDATA%\RadIA\mcp.json` e `mcp.<pid>.json`.
- Recursos web: `%APPDATA%\RadIA\Web`.
- Cache WebView2 descartável: `%APPDATA%\RadIA\WebView2`.

Antes de remover dados, feche todas as IDEs. Preserve `audit\tools.jsonl` quando houver requisito de
compliance. Nunca edite manualmente um discovery para apontar a outro pipe.
