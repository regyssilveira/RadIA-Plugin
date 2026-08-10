# 2.4.0 candidate audit

> **Status:** ready for release, without a tag, merge, or publication.

This audit closes the skill portability and high-fidelity terminal goal. Binaries were produced
from commit `7dce5ca5254243f843f43a1addc46f55fb231472` without signing, according to the open-source
project policy.

## Result

| Gate | Result |
|---|---|
| Delphi 12 Win32 | 1,024/1,024 tests, no failures, errors, ignored tests, or leaks |
| Delphi 13 Win32 | 1,024/1,024 tests, no failures, errors, ignored tests, or leaks |
| Delphi 13 IDE64 | 1,024/1,024 tests, no failures, errors, ignored tests, or leaks |
| Real terminal | ConPTY, streaming, continuous input, resize, and eight VT/TUI contracts passed |
| Installed visual matrix | Terminal passed on all three targets with 131 tools |
| Skill portability | Codex, Claude Code, Gemini CLI, and GitHub Copilot CLI passed |
| Web, documentation, and lint | 83/83 tests and ESLint passed |
| SonarQube | `OK`, 82.8% coverage, 1.7% duplication, and zero issues |
| Packages | Three internal ZIP files passed validation; not intended for normal public installation |
| Visual installer | Integrity passed; Authenticode `NotSigned` by project decision |

## Evidence

- [high-fidelity matrix](terminal_high_fidelity_evidence_2.4.0.json);
- [installed visual matrix](terminal_smoke_evidence_2.4.0.json);
- [packages and hashes](release_evidence_2.4.0.json);
- [visual installer](visual_installer_evidence_2.4.0.json);
- [SonarQube Quality Gate](sonar_quality_evidence_2.4.0.json).

## Prepared artifacts

| Artifact | SHA-256 |
|---|---|
| Delphi 12 Win32 ZIP | `7DD07F8DA6A01858EB584B5E2670F37E69F143E815DAF2D3B0E2CB3242FF834E` |
| Delphi 13 Win32 ZIP | `27946654F34DCE0881CE12B1130A8380E5B297317FA0D93201331C48FB843ABC` |
| Delphi 13 IDE64 ZIP | `33810DB5FF15942BBDC0A64BE6F955B0695DEF783333C7294D5162468DD9AF0A` |
| Visual installer | `C7FA1D9EA4ECAA4B1F03E8EBA8309D0850E6D7AF0C5594D317821450165FD9C6` |

The installer is the recommended public artifact. ZIP files exist for internal validation,
reproducibility, and diagnostics; they do not need to be attached to the public release.
