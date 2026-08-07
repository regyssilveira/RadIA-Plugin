# Release 2.1.0 audit

This audit records the gates executed for version 2.1.0. The binaries were produced from commit
`cede55fdb6fd008316963d5dacef51367735a498` without signing, according to the current open-source
project policy.

## Result

| Gate | Result |
|---|---|
| Delphi 12 Win32 build | Passed |
| Delphi 13 Win32 build | Passed |
| Delphi 13 IDE64 build | Passed |
| DUnitX tests | 806/806 per target, no failures or leaks |
| Web, documentation, and lint | Passed |
| SonarQube | Quality Gate `OK`, 82.9% coverage, 2.1% duplication, and zero issues |
| Operational catalog | 111/111 tools with purpose and activation guidance |
| Runtime diagnostics | Failure, fix, `fixed` comparison, and 10/10 regression on all targets |
| Real installation | `Uninstall`, `Install`, and `Repair` passed on all targets |
| IDE smoke | 2/2 cycles per target, 6/6 overall |
| Surfaces | Docking, restoration, terminal, keyboard, and first value passed |
| Visual installer | Integrity passed; Authenticode `NotSigned` |

## Artifacts

The provenance and hashes of all three ZIP files are recorded in
[`release_evidence_2.1.0.json`](release_evidence_2.1.0.json). The unified installer is recorded in
[`visual_installer_evidence_2.1.0.json`](visual_installer_evidence_2.1.0.json).

## Documentation

The [runtime diagnostics guide](runtime_debug_automation.en.md) explains the complete reproduction,
capture, fix, and regression workflow. The [operational reference](internal_tools_reference.md)
documents all 111 tools individually, including what each one does and when it may be invoked. An
automated test compares this reference with the runtime manifest and blocks undocumented tools.
