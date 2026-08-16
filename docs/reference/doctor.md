# RadIA Doctor

O comando `/doctor` é o ponto inicial quando o RadIA está instalado, mas alguma capacidade não
funciona. Ele executa um diagnóstico local somente leitura, não envia credenciais ao modelo e não
altera a IDE, o projeto ou configurações.

Antes de uma mensagem comum ser enviada, o chat também executa um preflight local da rota efetiva.
Se faltar provider, autenticação ou uma CLI realmente exigida pela rota, o envio é interrompido e o
RadIA mostra **Open Settings** e **Run /doctor**. O texto original permanece no campo para nova
tentativa. Nenhuma instalação começa nesse diagnóstico.

O npm nunca é requisito geral do RadIA. Quando uma rota exige uma CLI ausente, o usuário pode
selecionar um executável portátil completo com **Browse**, aceitar opcionalmente a instalação guiada
e seus pré-requisitos, ou escolher uma rota nativa por API que não dependa de CLI, npm ou MCP.

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
| Motor semântico | Executável, protocolo, índice, consulta e métricas da completion | O processo está ausente, incompatível ou não responde |

ChatGPT Pro via Codex CLI é tratado como uma rota composta: a orquestração pode continuar
**RadIA native**, mas o transporte exige o executável Codex. Isso não torna MCP obrigatório. O
doctor mostra esses três estados separadamente.

No diagnóstico profundo, a versão do Codex também é comparada com o requisito da família de modelo
selecionada. Para os modelos `gpt-5.6-*`, versões anteriores a `0.144.4` recebem estado de falha,
reduzem o score e direcionam para atualização do CLI antes do primeiro envio.

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

## Diagnóstico profundo com consentimento

Use `/doctor --deep` quando o diagnóstico local estiver correto, mas a execução ainda falhar. Antes
de começar, o RadIA mostra o consentimento de execução. Se autorizado, o perfil `deep-active`:

- executa `--version` na CLI efetivamente selecionada;
- usa o comando não interativo de status de autenticação quando a CLI o oferece;
- abre um handshake temporário com cada servidor MCP externo habilitado;
- valida o executável e o protocolo do motor semântico;
- consulta o índice semântico real e apresenta estado, motivo de resolução e unit de origem;
- mostra perfil de compilador/plataforma, tamanho do corpus, memória estimada, versão do cache,
  latência, requisições, falhas e reinicializações do motor semântico;
- informa quando o circuit breaker semântico está aberto; nesse estado, o editor usa o fallback
  limitado e o doctor preserva o último erro sanitizado para orientar a correção;
- verifica jar, Java e versão do adaptador isolado do DelphiLint e informa o caminho exato de correção;
- verifica a configuração-base do Sonar e explica a descoberta por projeto quando a variável não existe;
- encerra as sessões de teste e apresenta cada resultado no mesmo cartão do doctor.

O diagnóstico não instala, autentica, repara ou altera configurações. Também não envia uma mensagem
faturável ao modelo apenas para testar o provider. CLIs sem comando não interativo de autenticação
aparecem como `not-supported`, com a ação manual correta. O resultado é sanitizado: não inclui
tokens, chaves, argumentos de servidores ou a saída bruta do comando de autenticação.

## Comandos relacionados

| Necessidade | Comando |
|---|---|
| Diagnosticar por que algo não funciona | `/doctor` |
| Validar CLI e MCP por execução real | `/doctor --deep` |
| Inventariar tudo que está configurado | `/status` |
| Isolar uma área | `/status provider`, `/status cli` ou `/status mcp` |
| Diagnosticar o projeto aberto | `/health` |
| Confirmar o catálogo desta IDE | `/tools` |

Consulte também [Executores nativo e CLI](../guides/cli_executors.md), [Solução de problemas](../guides/troubleshooting_agentic_platform.md)
e [Configurações](settings_reference.md).
