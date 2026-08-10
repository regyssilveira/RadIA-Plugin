# Release audit 2.4.2

| Gate | Result |
|---|---|
| Delphi 12 Win32 | Build and 1,032 tests passed, zero leaks |
| Delphi 13 Win32 | Build and 1,032 tests passed, zero leaks |
| Delphi 13 IDE64 | Build and 1,032 tests passed, zero leaks |
| Web, documentation, and lint | 91 + 36 tests and ESLint passed |
| Runtime catalog | 132 tools validated |
| SonarQube | Quality Gate `OK`, zero issues |
| Distribution | Only the visual installer will be published |

This release fixes the chat composer in narrow panes and turns model rejection caused by an outdated
Codex CLI into actionable guidance. The hybrid route between native orchestration and ChatGPT Pro
transport is explicit to prevent incorrect diagnosis.
