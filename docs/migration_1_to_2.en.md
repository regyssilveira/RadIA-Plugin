# Migrating RadIA 1.x to 2.0

RadIA 2.0 preserves provider and session settings from version 1.x. The update replaces the IDE
package, MCP bridge, and Web assets; it does not automatically modify Delphi projects.

## Before upgrading

1. Close every Delphi instance.
2. Back up `%APPDATA%\RadIA` if sessions and audit records must be retained beyond the normal
   retention policy.
3. Confirm that no build, test, debugging session, or agent run is active.

## Upgrade

Run from the repository root:

```powershell
powershell -ExecutionPolicy Bypass -File .\build.ps1 `
  -DelphiVersion "37.0" -Release -Install
```

Use `22.0` for Delphi 11, `23.0` for Delphi 12, or `37.0` for Delphi 13. Add `-IDE64` for the
Delphi 13 64-bit IDE.

## Relevant changes

- The panel uses the native `TOTADockForm` host and is restored by the IDE desktop.
- Agent mode exposes visual control, cancellation, pause, resume, and persistent checkpoints.
- Mutating tools require preview and consent according to the configured policy.
- Operations remain workspace-confined and are recorded in the local audit log.
- The journey covers templates, code, Form Designer, build, DUnitX, debugger, and reviewable Git
  commits.
- The public MCP catalog contains 88 tools and negotiates public version `2.0.0`.

## Verification

1. Open Delphi and confirm `Tools > Rad IA Chat Panel`.
2. Confirm that the panel renders chat, status, and the agent-mode control.
3. Run `initialize` and `tools/list` through the MCP bridge; the version must be `2.0.0` and the
   catalog must contain 88 tools.
4. Run a simple build and test before resuming an older agent run.

Incompatible or incomplete checkpoints must be discarded and recreated. RadIA never converts or
executes a pending mutation automatically during migration.
