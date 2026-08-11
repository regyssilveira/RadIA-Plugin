# Notas de release - RadIA 2.6.2

> **Estado:** preparada em 11 de agosto de 2026 para estabilizar a experiencia de teste em Delphi
> 12 e 13.

RadIA 2.6.2 e uma release patch focada em usabilidade do chat, criacao de projetos por agente e
diagnostico de versao instalado.

## Correcoes

- o menu contextual do editor voltou a exibir as acoes do RadIA no topo, sem depender da ordem de
  inicializacao de menus de terceiros;
- listas e seletores longos do chat agora exibem scrollbars mais largas e clicaveis;
- prompts enviados pelo menu do editor preservam blocos fenced Markdown com realce Pascal;
- janelas principais mostram a versao no caption, como `Rad IA Chat v2.6.2`;
- a criacao de projetos por prompt natural reconhece pedidos como "faca uma calculadora basica";
- projetos gerados usam `$(BDS)\lib\$(Platform)\release` e incluem DUnitX quando necessario,
  evitando `F1027 unit System not found` em instalacoes limpas;
- o smoke de projetos gerados usa as opcoes atuais do runner DUnitX.

## Compatibilidade

- Delphi 12 Win32 instalado para teste local;
- Delphi 13 Win32 instalado para teste local;
- Delphi 13 IDE64 instalado para teste local;
- catalogo operacional preservado com 132 ferramentas.

## Validacao da release

- `npm run test:web`: 101 testes aprovados;
- `npm run lint`: sem erros;
- `scripts\Test-RadIA.GeneratedProjects.ps1 -DelphiVersion "37.0" -SkipDext`: 11 projetos
  gerados aprovados e 5 testes DUnitX da calculadora aprovados;
- `build.ps1 -DelphiVersion "37.0" -Release -Test`: build, cobertura e testes aprovados.
