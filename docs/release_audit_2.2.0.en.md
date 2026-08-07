# Release 2.2.0 audit

This audit records the gates executed for version 2.2.0. Binaries were produced from commit
`42a7f0b8be34521c628fbab012bbfced7533006c` without signing, according to the open-source project
policy.

## Results

| Gate | Result |
|---|---|
| Delphi 12 Win32 build | Passed |
| Delphi 13 Win32 build | Passed |
| Delphi 13 IDE64 build | Passed |
| Delphi 12/13 Win32 tests | 832 unit tests + 6 external tests, zero failures and zero leaks |
| Delphi 13 IDE64 tests | 838/838, zero failures and zero leaks |
| Web, documentation, and lint | 15/15 Web, 3/3 documentation, ESLint passed |
| SonarQube | Quality Gate `OK`, 83.2% global coverage, 2.0% duplication, zero issues |
| Operational catalog | 123/123 tools with purpose and activation guidance |
| FastMM5 diagnostics | Leak located on all targets and fixed control returned zero groups |
| FastMM5 repeatability | 10/10 cycles on all targets and 10/10 clean-control cycles |
| Interruptions | Cancellation, timeout, recovery, and edit-conflict tests passed |
| Packages | Three Release ZIPs and adversarial package tests passed |
| Real installation | BPL 2.2.0.0, hashes, and registry entries passed on all targets |
| Final IDE smoke | 1/1 per target with 123 tools in every IDE |
| Visual installer | Integrity passed; Authenticode `NotSigned` |

## Artifacts

Package provenance and hashes are recorded in
[`release_evidence_2.2.0.json`](release_evidence_2.2.0.json). The unified installer is recorded in
[`visual_installer_evidence_2.2.0.json`](visual_installer_evidence_2.2.0.json).

The [FastMM5 session guide](fastmm5_diagnostic_session.en.md) documents configuration, consent,
reversible instrumentation, supervised process execution, scenarios, evidence, fix preparation,
allocation breakpoint, and comparison.
