# Release audit 2.8.0

> **Status:** validated candidate; publication pending.

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
- [ ] Packages, installer, evidence, merge, tag, and publication.

## Publication evidence

Provenance, integrity, and quality links will be added after artifacts are generated from the clean
release commit.
