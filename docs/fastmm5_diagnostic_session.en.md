# Complete memory diagnostic session

RadIA can compose FastMM5 instrumentation, build, debugging, visual automation, and evidence parsing
into one reversible session. Chat, agent mode, and MCP share the same internal tools.

The recommended flow is:

1. Configure FastMM5 under **Tools > Options > Rad IA > Memory Diagnostics**.
2. Use Debug with Win32 or Win64.
3. Call `PrepareMemoryDiagnosticSession` with a bounded runtime scenario.
4. Review instrumentation, warmup, repetitions, limits, and actions.
5. Approve `RunMemoryDiagnosticSession`.
6. Track it with `GetMemoryDiagnosticSessionStatus` or stop it with
   `CancelMemoryDiagnosticSession`.

The approved run instruments the DPR, builds, starts the Delphi debugger, waits for the new process
identity, performs warmup and measured repetitions, captures process snapshots, stops the process,
parses `.radia/memory/latest-fastmm5.log`, and restores the original DPR in a finalization block.

Preparation is read-only. Running always requires consent. Restoration failures are reported and
never hidden. Snapshots contain Windows private-memory and working-set observations; detailed block,
class, and stack evidence comes from FastMM5.

