# Notas de release — RadIA 2.3.1

Lançamento: 8 de agosto de 2026.

## Destaques

- Seletores separados de **Mode** e **Send with** para escolher Chat/Agent e RadIA native/CLI direto.
- Identidade efetiva visível no cabeçalho, compositor e respostas, com avatares próprios para nativo,
  CLI e MCP.
- **ChatGPT Pro via Codex CLI** restaurado: usa a sessão e a cota ChatGPT/Codex sem enviar o token
  legado para `api.openai.com`.
- **OpenAI API via API Key** permanece uma rota HTTP distinta, com cobrança e quota da plataforma API.
- Migração automática de configurações OpenAI OAuth antigas para `oauth_cli`, removendo tokens HTTP
  que não participam mais da execução.
- Botões de cópia em respostas, JSON, resultados de tools e demais textos copiáveis.
- Tela de configurações redimensionável e seleção de rotas com contraste consistente.
- Login do Codex CLI diagnosticável e independente do login nativo de providers por API key.

## Como escolher a rota

- Escolha **RadIA native + ChatGPT Pro via Codex CLI** para manter histórico, contexto, RTK e
  orquestração no RadIA e usar o CLI apenas como transporte autenticado.
- Escolha **Codex CLI direct** para entregar a execução completa ao cliente Codex.
- Escolha **OpenAI API via API Key** para usar a plataforma API e sua quota separada.

As duas rotas Codex compartilham o mesmo login. Em **Settings > CLI & MCP > Codex CLI**, execute
**Diagnose** e confirme `authentication: ready`.

## Correção da regressão

A versão 1.0 encaminhava o login ChatGPT pelo Codex CLI. Uma separação posterior passou a tratar o
estado `oauth` como transporte HTTP nativo, provocando 401/429 apesar de a conta Pro possuir cota.
A 2.3.1 restaura o transporte correto, impede o fallback silencioso para a API e torna a rota visível.

## Validação

- Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64 compilados e instalados.
- 888 testes DUnitX instrumentados aprovados, sem leaks.
- 6 testes de processos externos aprovados.
- 50 testes web e ESLint aprovados.
- Cobertura instrumentada de 78%.
- SonarQube aprovado com 83,1% de cobertura no código novo, 0,94% de duplicação nova e zero issues.

Consulte o [manual](user_manual.md), a [matriz de executores](cli_executors.md), a
[referência de configurações](settings_reference.md) e a [solução de problemas](troubleshooting_agentic_platform.md).
