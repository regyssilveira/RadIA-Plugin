# Auditoria da release 2.8.0

> **Estado:** aprovada e liberada em 11 de agosto de 2026.

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
- [x] Pacotes, instalador, evidências, merge, tag e publicação.

## Evidências finais

- [qualidade SonarQube](sonar_quality_evidence_2.8.0.json);
- [proveniência dos pacotes](release_evidence_2.8.0.json);
- [integridade do instalador](visual_installer_evidence_2.8.0.json).

Os artefatos foram produzidos do commit `2a22c46`, com árvore rastreada limpa. O instalador não é
assinado por decisão do projeto e seu SHA-256 é
`7F651E049977E0E84125380CC2346420848FAE99EFFF66B671CE52F722914967`.
