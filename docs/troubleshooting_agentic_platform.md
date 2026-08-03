# Solução de problemas da plataforma agentiva

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

## Conhecimento, Designer e debugger

| Sintoma | Verificação e ação |
|---|---|
| Busca desatualizada | Salve o arquivo ou reconstrua o índice do projeto. |
| Designer indisponível | Abra um formulário compatível e torne-o o Designer ativo. |
| Componente mudou | Gere novo preview a partir do estado atual. |
| Avaliação indisponível | Pause o processo em um frame válido. |
| Controle recusado | Consulte o estado do debugger antes do próximo comando. |

## Logs e dados locais

- Auditoria: `%APPDATA%\RadIA\audit\tools.jsonl`.
- Conhecimento reconstruível: `%APPDATA%\RadIA\Knowledge`.
- Discovery MCP: `%APPDATA%\RadIA\mcp.json` e `mcp.<pid>.json`.
- Recursos web: `%APPDATA%\RadIA\Web`.
- Cache WebView2 descartável: `%APPDATA%\RadIA\WebView2`.

Antes de remover dados, feche todas as IDEs. Preserve `audit\tools.jsonl` quando houver requisito de
compliance. Nunca edite manualmente um discovery para apontar a outro pipe.
