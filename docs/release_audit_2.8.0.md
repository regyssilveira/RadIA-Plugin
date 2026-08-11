# Auditoria da release 2.8.0

> **Estado:** candidata validada; publicação pendente.

## Baseline funcional

- [x] Contexto semântico compartilhado por Ghost Text, ações contextuais e agente.
- [x] Inspeção somente leitura disponível no menu do editor e em Tools.
- [x] Tool `GetEditorSemanticContext` registrada e documentada.
- [x] Provider nativo do CodeInsight preservado.
- [x] Catálogo gerado com 133 ferramentas documentadas e sincronizadas.

## Gates finais

- [x] Delphi 12 Win32: 1061 testes instrumentados e 8 externos, sem vazamentos.
- [x] Delphi 13 Win32: 1061 testes instrumentados e 8 externos, sem vazamentos.
- [x] Delphi 13 IDE64: 1069 testes diretos, sem vazamentos.
- [x] Web 105/105, ESLint e documentação 41/41.
- [x] SonarQube: gate OK, cobertura 83,2%, duplicação 1,8% e zero issues.
- [ ] Pacotes, instalador, evidências, merge, tag e publicação.

## Evidências de publicação

Os links de proveniência, integridade e qualidade serão adicionados após a geração dos artefatos a
partir do commit limpo da release.
