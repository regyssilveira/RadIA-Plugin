# FastMM5 configuration

RadIA uses a user-supplied FastMM5 installation and does not redistribute FastMM5 files. The
integration supports Delphi 12/Win32, Delphi 13/Win32, and Delphi 13/IDE64.

## Settings screen

1. Open **RadIA > Settings > Memory Diagnostics**.
2. Enter the FastMM5 root, such as `D:\Delphi\FastMM5`.
3. Acknowledge that the dependency is user-supplied and governed by its own license.
4. Select **Validate installation**.
5. Save the settings.

RadIA checks `FastMM5.pas`, identifies the declared version, and locates the FullDebugMode library
for the current architecture. The screen reports the exact reason when the backend is not ready.

## Chat, agent mode, or MCP

- `/tool GetMemoryDiagnosticsStatus {}` reads readiness without changing configuration.
- `/tool ConfigureMemoryDiagnostics {"rootPath":"D:\\Delphi\\FastMM5","licenseAcknowledged":true}`
  prepares the setting change. Consent may be requested because this is a structural configuration
  write.

The agent checks readiness before proposing a diagnostic session. This check never instruments a
project.

## Stored values

RadIA stores only the user-provided root, explicit license acknowledgement, and bounded execution
limits. Source and runtime libraries remain in the user's directory. Defaults are 120 seconds,
50 MiB of log output, and 10 repetitions.

See the [complete memory diagnostics plan](fastmm5_memory_diagnostics_plan.en.md).
