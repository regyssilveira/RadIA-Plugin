# Release audit 2.8.0

> **Status:** approved and released on August 11, 2026.

## Functional baseline

- [x] Semantic context shared by Ghost Text, contextual actions, and agent.
- [x] Read-only inspection available from the editor menu and Tools.
- [x] `GetEditorSemanticContext` tool registered and documented.
- [x] Native CodeInsight provider preserved.
- [x] Generated catalog with 133 tools documented and synchronized.

## Final gates

- [x] Delphi 12 Win32: 1061 instrumented tests and 8 external tests without leaks.
- [x] Delphi 13 Win32: 1061 instrumented tests and 8 external tests without leaks.
- [x] Delphi 13 IDE64: 1069 direct tests without leaks.
- [x] Web 105/105, ESLint, and documentation 41/41.
- [x] SonarQube: gate OK, 83.2% coverage, 1.8% duplication, and zero issues.
- [x] Packages, installer, evidence, merge, tag, and publication.

## Final evidence

- [SonarQube quality](sonar_quality_evidence_2.8.0.json);
- [package provenance](release_evidence_2.8.0.json);
- [installer integrity](visual_installer_evidence_2.8.0.json).

Artifacts were produced from commit `2a22c46` with a clean tracked tree. The installer is unsigned
by project decision, and its SHA-256 is
`7F651E049977E0E84125380CC2346420848FAE99EFFF66B671CE52F722914967`.
