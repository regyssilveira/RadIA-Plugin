# Release audit 2.4.1

| Gate | Result |
|---|---|
| Delphi 12 Win32 | Build passed |
| Delphi 13 Win32 | 1,031 tests passed, zero failures and leaks |
| Delphi 13 IDE64 | Build passed |
| Web, documentation, and lint | 89/89 tests and ESLint passed |
| Installed smoke | Delphi 13 loaded 132 tools |
| SonarQube | Quality Gate `OK`, zero issues |
| Distribution | Only the visual installer will be published |

The fix adds the minimal DFM required by `TCustomFrame.Create` to
`TRadIAExternalMcpFrame`. The documentation test verifies the resource presence and name.
