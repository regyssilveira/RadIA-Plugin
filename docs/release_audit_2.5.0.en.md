# Release audit 2.5.0

| Gate | Result |
|---|---|
| Delphi 12 Win32 | Build and 1,037 tests passed, zero leaks |
| Delphi 13 Win32 | Build and 1,037 tests passed, zero leaks |
| Delphi 13 IDE64 | Build passed |
| Web, documentation, and lint | 93 + 36 tests and ESLint passed |
| Runtime catalog | 132 tools validated |
| SonarQube | Quality Gate `OK`, zero issues |
| Distribution | Only the visual installer will be published |

This release improves composer responsiveness and removes the mandatory npm dependency for Codex
CLI and Claude Code installation. External channels remain explicit, consented, and obtained from
official sources; no third-party CLI is bundled into the installer. Agent mode also remains usable
without an open project and keeps plan approval visible and actionable.
