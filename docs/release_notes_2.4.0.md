# Notas de release — RadIA 2.4.0

> **Estado:** release 2.4.0 validada para publicação.

## Destaques

- Uma definição de skill pode ser publicada para Codex, Claude Code, Gemini CLI e GitHub Copilot
  CLI pelo Addon Studio.
- O preview mostra destinos, criação, atualização, ausência de mudança e conflitos antes da escrita.
- Consentimento central, troca atômica, rollback e hashes de propriedade protegem o workspace.
- Réplicas alteradas manualmente não são sobrescritas nem removidas silenciosamente.
- O terminal separa transporte ConPTY, emulação VT e renderer VCL por contrato próprio.
- Cores ANSI, 256 cores e true color são preservadas no texto e no fundo.
- Negrito, itálico, sublinhado, vídeo inverso e reset seletivo são renderizados.
- Alternate screen restaura a tela principal; bracketed paste e mouse SGR só operam após negociação.
- Hyperlinks OSC 8 aceitam somente `http`, `https` e `mailto`, exigem duplo clique e consentimento em
  toda abertura.
- Codex CLI direto aceita projetos Delphi sem Git em conversas novas e retomadas, sempre com
  diretório de trabalho explícito.
- ChatGPT Pro preserva o erro real do Codex em vez de convertê-lo em resposta vazia ou falha JSON
  genérica.
- Respostas sem conteúdo causadas por modelo incompatível agora são classificadas como erro de
  transporte acionável, com atualização de modelos e `/doctor --deep` como recuperação.
- O chat agora valida a rota antes do envio, preserva a mensagem e encaminha máquinas sem CLI para
  configurações ou `/doctor`, sempre oferecendo executável portátil sem tornar npm obrigatório.
- `/doctor` 2.0 mostra rota efetiva, dependências distintas de CLI e MCP, checks classificados e
  próxima ação em um cartão visual.
- `/doctor --deep` solicita consentimento e executa probes reais de versão/autenticação da CLI e
  handshakes temporários nos servidores MCP externos habilitados, sem alterar configurações.

## Como usar

Para publicar uma skill, abra **Tools > Rad IA Addon Studio**, selecione uma extensão que contenha
skills e clique em **Publish skill to CLIs...**. Escolha os destinos, revise os caminhos completos e
autorize a operação. Consulte [Portabilidade de skills](skill_portability.md).

Abra o terminal pelo botão **>_ Terminal**, por `/terminal`, pelo menu ou pelo atalho configurável.
Aplicações habilitam automaticamente os modos VT de que precisam. Consulte [Terminal](terminal.md).

## Compatibilidade e atualização

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64.

Não existe migração manual. Extensões antigas continuam válidas, e as réplicas de CLI somente são
criadas após ação explícita. A instalação para o usuário final continua concentrada no instalador
visual; o ZIP não é necessário para o fluxo normal.

## Validação da candidata

- 1.031/1.031 testes DUnitX aprovados em cada um dos três targets, sem falhas, erros ou leaks;
- ConPTY real aprovado com streaming, entrada contínua e resize nos três targets;
- Codex CLI 0.147.0, Claude Code 2.1.226, Gemini CLI 0.54.4 e GitHub Copilot CLI 1.0.78 reconhecidos;
- 88/88 testes web e documentais aprovados, incluindo links, pares bilíngues, navegação, mojibake e
  ausência de referências proibidas;
- ESLint aprovado;
- SonarQube aprovado com 82,8% de cobertura global e zero issues.
- smoke visual instalado aprovado no Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64, com 132
  ferramentas, controles, entrada, saída, paleta, perfis e navegação por teclado.

Consulte a [evidência reproduzível do terminal](terminal_high_fidelity_evidence_2.4.0.json) e a
[matriz visual instalada](terminal_smoke_evidence_2.4.0.json).

O instalador visual é o único artefato necessário para o usuário final. Os ZIPs da matriz permanecem
internos ao pipeline para validação, reprodutibilidade e composição do instalador.
