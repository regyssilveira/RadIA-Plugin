# 2.4.0 candidate audit

> **Status:** current audit for release 2.4.0.

This audit closes skill portability, high-fidelity terminal, Doctor 2.0, and chat preflight. The
pipeline records the exact binary commit and hashes in reproducible evidence. The installer remains
unsigned according to the open-source project policy.

## Result

| Gate | Result |
|---|---|
| Delphi 12 Win32 | 1,031/1,031 tests, no failures, errors, ignored tests, or leaks |
| Delphi 13 Win32 | 1,031/1,031 tests, no failures, errors, ignored tests, or leaks |
| Delphi 13 IDE64 | 1,031/1,031 tests, no failures, errors, ignored tests, or leaks |
| Real terminal | ConPTY, streaming, continuous input, resize, and eight VT/TUI contracts passed |
| Installed visual matrix | Terminal passed on all three targets with 132 tools |
| Skill portability | Codex, Claude Code, Gemini CLI, and GitHub Copilot CLI passed |
| Web, documentation, and lint | 88/88 tests and ESLint passed |
| SonarQube | `OK`, 82.7% coverage, 1.7% duplication, and zero issues |
| Packages | Three internal ZIP files passed validation; not intended for normal public installation |
| Visual installer | Integrity passed; Authenticode `NotSigned` by project decision |

## Evidence

- [high-fidelity matrix](terminal_high_fidelity_evidence_2.4.0.json);
- [installed visual matrix](terminal_smoke_evidence_2.4.0.json);
- [packages and hashes](release_evidence_2.4.0.json);
- [visual installer](visual_installer_evidence_2.4.0.json);
- [SonarQube Quality Gate](sonar_quality_evidence_2.4.0.json).

Hashes and the source commit are read directly from `release_evidence_2.4.0.json` and
`visual_installer_evidence_2.4.0.json`, avoiding duplicated values that may drift.

The installer is the recommended public artifact. ZIP files exist for internal validation,
reproducibility, and diagnostics; they do not need to be attached to the public release.
