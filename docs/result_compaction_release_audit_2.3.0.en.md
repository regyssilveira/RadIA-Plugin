# Internal RTK viability audit — RadIA 2.3.0

Date: August 8, 2026. Status: **technical go; candidate prepared and unpublished**.

## Measured result

| Gate | Result | Status |
|---|---:|---|
| Result characters | 1,145,022 → 37,630 | 96.71% reduction |
| Estimated tokens | 286,256 → 9,408 | four-character token estimate |
| Median eligible reduction | 98.65% | passed, minimum 30% |
| A/B decision context | 1,152,074 → 39,750 | 96.55%, minimum 20% |
| Repeated calls | 7 Off / 7 Conservative | 0%, maximum 5% |
| Compaction P95 | 47,779 µs | passed, maximum 50,000 µs for 1 MiB |
| Delphi suite | 892/892 | zero failures, errors, or leaks |

Full sanitized evidence is in
[`result_compaction_evidence_2.3.0.json`](result_compaction_evidence_2.3.0.json), SHA-256
`039969BEB7D068A8041F11BC1F5FEC1D8C418D28417950761BBB26EE2B001992`.

## Compiled matrix

- Delphi 12 Athens, Win32 Release: 892/892 tests, zero leaks.
- Delphi 13, Win32 Release: 892/892 tests, zero leaks.
- Delphi 13 IDE64 Win64 Release: 892/892 tests, zero leaks.
- Delphi 13 IDE64: automated smoke passed with 126 tools and a complete agent runtime cycle.
- ESLint, 40 web tests, and 14 documentation tests: passed.
- SonarQube: quality gate passed, 83.0% new-code coverage, and zero issues.

## Security and recovery

Complete results use SHA-256, atomic writes, session boundaries, a 100-artifact and 64 Mi-character
session quota, an 8 Mi-character artifact limit, and 14-day retention. Ranges are limited to 65,536
characters with Unicode-safe boundaries. Tests cover traversal, session spoofing, quotas, expiration,
concurrency, and reopening.

## Rollout decision

Savings, fidelity, recovery, performance, compatibility, security, and operation gates passed. The
2.3.0 candidate remains local and must not be published without explicit authorization.
