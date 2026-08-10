# Goal — expansão da experiência completa do RadIA

> **Estado:** concluído no branch `feat/competitive-gap-closure`.
> **Escopo:** Delphi 12 Win32 e Delphi 13 Win32/IDE64.
> **Fora do escopo:** C++Builder, marketplace, assinatura Authenticode obrigatória, automação
> genérica do desktop e substituição do host WebView2 atual.

## Objetivo

Transformar capacidades técnicas já comprovadas em uma experiência contínua, visível e fácil de
compartilhar. O usuário deve conseguir acompanhar o que o agente está fazendo, distribuir
conhecimento e automações com segurança e entender cada controle sem consultar o código-fonte.

## Marcos

| Marco | Entrega | Estado |
|---|---|---|
| M1 | Painel de até três alternativas de completion, navegação visual e atalhos configuráveis | Concluído e aprovado na matriz final integrada |
| M2 | `.radiaext` com referências, conhecimento, templates e assets, incluindo Addon Studio e rollback | Concluído e aprovado na matriz final integrada |
| M3 | Sessão visual no chat com captura anterior/posterior, timeline e validação ligada a eventos reais | Concluído; captura real aprovada nos três targets suportados |
| M4 | Consentimento resiliente entre superfícies e apresentação visual uniforme | Concluído; diálogo central, fila limitada, redação e matriz aprovadas |
| M5 | Matriz avançada do terminal para Unicode, caracteres largos, reflow e aplicações TUI | Concluído; 1.013 testes nos três targets e Sonar aprovado |
| M6 | Refinamento incremental do WebView atual, sem trocar sua arquitetura | Concluído; fila, layout de 280–1000 px, três targets e Sonar aprovados |
| M7 | Auditoria integral da documentação e gate Delphi 12/13 | Concluído; documentação, matriz e Sonar aprovados |

## Evidência final do M7

- 184 documentos Markdown rastreados, em 92 pares completos pt-BR/en-US;
- navegação por tarefa comprovada para todo guia operacional; ADRs, planos, auditorias e históricos
  permanecem separados do fluxo principal;
- links locais válidos e relativos ao repositório, sem `file:///`, mojibake ou referências aos
  produtos proibidos;
- 132/132 ferramentas com finalidade e acionamento, comandos nativos documentados e fallbacks de
  modelos sincronizados automaticamente com `RadIA.Core.Types.pas`;
- 83/83 testes web e documentais e ESLint aprovados;
- 1.013/1.013 testes em Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64, sem falhas, erros,
  ignorados ou leaks;
- SonarQube com Quality Gate `OK`, cobertura 82,8%, duplicação 1,7% e zero issues, bugs,
  vulnerabilidades, hotspots ou code smells.

## Contratos obrigatórios

- Nenhuma animação pode fingir atividade: a interface reage somente a eventos reais.
- Automação visual permanece limitada ao processo iniciado pela sessão atual do debugger.
- Capturas são sanitizadas, possuem retenção limitada e nunca entram em logs textuais.
- Manifesto e recursos de uma extensão são instalados, atualizados e removidos como uma unidade.
- Consentimento nunca pode ficar inacessível porque chat, terminal ou painel foi fechado.
- Toda ação visual possui equivalente por teclado ou comando quando aplicável.
- Toda mudança visível atualiza referência central, guia, hints, tradução e testes documentais.
- Cada marco fecha com testes, SonarQube, commit e push; o encerramento exige a matriz completa.

## Definição de pronto

O goal termina somente quando todos os marcos estiverem implementados, documentados e aprovados no
Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64, sem regressões, vazamentos, issues do Sonar ou
instruções que dependam de roadmap e histórico para serem descobertas.
