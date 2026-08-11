# Auditoria da release 2.7.0

> **Estado:** aprovada e liberada em 11 de agosto de 2026.

## Baseline funcional

- [x] Projetos gerados certificados.
- [x] Prompts naturais PT/EN certificados para todos os templates.
- [x] Intenções Code/Design, erro e cancelamento certificados em IDE real.
- [x] Solicitação de alterações comentada, sem mutação, certificada em IDE real.
- [x] Catálogo gerado com 132 ferramentas documentadas e sincronizadas.

## Gates finais

- [x] Delphi 12 Win32 Release e DUnitX.
- [x] Delphi 13 Win32 Release e DUnitX.
- [x] Delphi 13 IDE64 Release e DUnitX: 1065/1065, sem vazamentos.
- [x] Web 105/105, ESLint e documentação 38/38.
- [x] SonarQube: gate OK, cobertura 83,2%, duplicação 1,8% e zero issues.
- [x] Pacotes, instalador e instalação final nas três metas.

## Evidências finais

- [qualidade SonarQube](sonar_quality_evidence_2.7.0.json);
- [proveniência dos pacotes](release_evidence_2.7.0.json);
- [integridade do instalador](visual_installer_evidence_2.7.0.json).

Os artefatos foram produzidos do commit `b6b6a2c`, com árvore rastreada limpa. O instalador não é
assinado por decisão do projeto e seu SHA-256 é
`92EA4A6599736F348394CE22872672A27314A51FDF574BFEC7117045BFB980EB`.
