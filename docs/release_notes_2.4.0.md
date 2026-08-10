# Notas de release — RadIA 2.4.0

> **Estado:** candidata preparada no branch de trabalho. Ainda não publicada.

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

- 1.024/1.024 testes DUnitX aprovados em cada um dos três targets, sem falhas, erros ou leaks;
- ConPTY real aprovado com streaming, entrada contínua e resize nos três targets;
- Codex CLI 0.147.0, Claude Code 2.1.226, Gemini CLI 0.54.4 e GitHub Copilot CLI 1.0.78 reconhecidos;
- 83/83 testes web e documentais aprovados, incluindo links, pares bilíngues, navegação, mojibake e
  ausência de referências proibidas;
- ESLint aprovado;
- SonarQube aprovado com 82,8% de cobertura global e zero issues.
- smoke visual instalado aprovado no Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64, com 131
  ferramentas, controles, entrada, saída, paleta, perfis e navegação por teclado.

Consulte a [evidência reproduzível do terminal](terminal_high_fidelity_evidence_2.4.0.json) e a
[matriz visual instalada](terminal_smoke_evidence_2.4.0.json).

Tag, merge e publicação dependem de autorização explícita.
