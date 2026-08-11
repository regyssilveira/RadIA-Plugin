# Release audit 2.7.0

> **Status:** approved and released on August 11, 2026.

## Functional baseline

- [x] Generated projects certified.
- [x] Natural PT/EN prompts certified for every template.
- [x] Code/Design intents, error, and cancellation certified in a real IDE.
- [x] Commented change request without mutation certified in a real IDE.
- [x] Generated catalog with 132 tools documented and synchronized.

## Final gates

- [x] Delphi 12 Win32 Release and DUnitX.
- [x] Delphi 13 Win32 Release and DUnitX.
- [x] Delphi 13 IDE64 Release and DUnitX: 1065/1065 without leaks.
- [x] Web 105/105, ESLint, and documentation 38/38.
- [x] SonarQube: gate OK, 83.2% coverage, 1.8% duplication, and zero issues.
- [x] Packages, installer, and final installation on all three targets.

## Final evidence

- [SonarQube quality](sonar_quality_evidence_2.7.0.json);
- [package provenance](release_evidence_2.7.0.json);
- [installer integrity](visual_installer_evidence_2.7.0.json).

Artifacts were produced from commit `b6b6a2c` with a clean tracked tree. The installer is unsigned
by project decision, and its SHA-256 is
`92EA4A6599736F348394CE22872672A27314A51FDF574BFEC7117045BFB980EB`.
