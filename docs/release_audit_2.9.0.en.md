# Release audit 2.9.0

> **Status:** approved and released on August 12, 2026.

## Functional baseline

- [x] Sanitized Delphi environment profile and curated guidance.
- [x] DFM/PAS audit and Designer visual diff.
- [x] Autonomous execution contract and safe resume.
- [x] Reversible legacy data access migration to FireDAC.
- [x] Delphi mentor, security brief, and reproducible benchmark.
- [x] Generated catalog with 148 documented and synchronized tools.

## Final gates

- [x] Delphi 12 Win32: 1103 instrumented and 8 external tests without leaks.
- [x] Delphi 13 Win32: 1103 instrumented and 8 external tests without leaks.
- [x] Delphi 13 IDE64: 1111 tests without leaks.
- [x] Web 106/106, ESLint, and documentation 42/42.
- [x] SonarQube: passing gate, 83.6% global coverage, 1.8% duplication, and zero issues.
- [x] Packages, installer, evidence, merge, tag, and publication.

## Final evidence

Artifacts were produced from commit `2d10e90917c27d9440d3a7040fc8e2b1afd19ff8`. The
`RadIA-v2.9.0-Setup.exe` installer is intentionally unsigned and has SHA-256
`C84414D4494FF4F2F30206404827014CEA373F647DF83F01815C54536225BCB6`.
