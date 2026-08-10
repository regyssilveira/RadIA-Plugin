# RadIA Doctor

O comando `/doctor` é o ponto inicial quando o RadIA está instalado, mas alguma capacidade não
funciona. Ele executa um diagnóstico local somente leitura, não envia credenciais ao modelo e não
altera a IDE, o projeto ou configurações.

## O que é avaliado

| Área | O que o doctor confirma | Quando exige atenção |
|---|---|---|
| Rota efetiva | Orquestração, transporte do provider, CLI efetiva e necessidade de MCP | A configuração visual não corresponde às dependências reais |
| Provider | Provider ativo e método de autenticação configurado | API key, URL local ou rota de autenticação ausente |
| CLI | Executável resolvido pelo mesmo catálogo usado pelo chat | A rota efetiva exige CLI e o arquivo não foi encontrado |
| MCP | Ponte e configuração do cliente | Somente quando o executor externo depende de MCP |
| Terminal | Disponibilidade do ConPTY | O Windows não oferece o transporte interativo |
| Chat | Presença de HTML, CSS e JavaScript instalados | Recursos web ausentes ou instalação incompleta |
| Tools | Catálogo interno e `GetIDEState` | O pacote não registrou a primeira tool somente leitura |
| MCP externo | Servidores habilitados, conexões, tools e erros | Um servidor habilitado não pode ser usado |

ChatGPT Pro via Codex CLI é tratado como uma rota composta: a orquestração pode continuar
**RadIA native**, mas o transporte exige o executável Codex. Isso não torna MCP obrigatório. O
doctor mostra esses três estados separadamente.

## Como interpretar o cartão

- **Score** resume os checks aplicáveis; um item opcional aparece como `not-required`.
- **Effective route** mostra o caminho que uma mensagem realmente seguirá.
- **Passed**, **failed** e **not-required** evitam confundir recurso opcional com falha.
- **Next action** prepara o comando ou abre o caminho mais útil; nada é executado automaticamente.
- Caminhos de executáveis podem aparecer para diagnóstico, mas tokens, chaves e argumentos
  sensíveis nunca são retornados.

## Projetos sem Git

O executor Codex informa o diretório do projeto explicitamente e aceita pastas Delphi sem
repositório Git, tanto em sessões novas quanto retomadas. Se uma versão antiga mostrar `Not inside
a trusted directory`, atualize o RadIA e execute `/cli new` antes de testar novamente.

## Limites atuais

O perfil `full-local` verifica instalação e configuração sem realizar chamadas externas. Portanto,
uma CLI detectada ainda pode precisar de login, acesso ao modelo ou conectividade. Use **Settings >
CLI & MCP > Diagnose** para o teste específico de versão e autenticação. Problemas do projeto
Delphi, build, testes e índice local pertencem ao comando `/health`.

## Comandos relacionados

| Necessidade | Comando |
|---|---|
| Diagnosticar por que algo não funciona | `/doctor` |
| Inventariar tudo que está configurado | `/status` |
| Isolar uma área | `/status provider`, `/status cli` ou `/status mcp` |
| Diagnosticar o projeto aberto | `/health` |
| Confirmar o catálogo desta IDE | `/tools` |

Consulte também [Executores nativo e CLI](cli_executors.md), [Solução de problemas](troubleshooting_agentic_platform.md)
e [Configurações](settings_reference.md).
