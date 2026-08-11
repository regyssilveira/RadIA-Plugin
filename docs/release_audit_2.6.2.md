# Auditoria da release 2.6.2

> **Estado:** aprovada em 11 de agosto de 2026 para estabilizar os testes em Delphi 12 e 13.

## Gates funcionais

- [x] O menu contextual do editor inclui as acoes do RadIA no topo.
- [x] Seletores e listas longas do chat oferecem scrollbar visivel e mais larga.
- [x] Prompts gerados pelo menu do editor preservam formatacao de codigo.
- [x] Janelas principais exibem a versao instalada no caption.
- [x] A jornada de criacao reconhece pedidos naturais de calculadora.
- [x] Projetos gerados resolvem a RTL por `$(BDS)` e incluem DUnitX quando necessario.
- [x] O catalogo operacional permanece sincronizado com as 132 ferramentas registradas.

## Gates de regressao e qualidade

- [x] `npm run test:web`: 101 testes aprovados.
- [x] `npm run lint`: sem erros.
- [x] `scripts\Test-RadIA.GeneratedProjects.ps1 -DelphiVersion "37.0" -SkipDext`: 11 projetos
  gerados aprovados.
- [x] `build.ps1 -DelphiVersion "37.0" -Release -Test`: build, cobertura e testes aprovados.

## Gate documental

- [x] `project_wizard.md` e `project_wizard.en.md` documentam o search path dos projetos gerados.
- [x] As notas de release e esta auditoria existem em portugues e ingles.
- [x] Os hubs principais apontam para a release 2.6.2.
