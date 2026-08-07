# Complete memory diagnostic session

RadIA can compose FastMM5 instrumentation, build, a supervised process, visual automation, and
evidence parsing into one reversible session. Chat, agent mode, and MCP share the same internal
tools.

The recommended flow is:

1. Configure FastMM5 under **Tools > Options > Rad IA > Memory Diagnostics**.
2. Use Debug with Win32 or Win64.
3. Call `PrepareMemoryDiagnosticSession` with a bounded runtime scenario.
4. Review instrumentation, warmup, repetitions, limits, and actions.
5. Approve `RunMemoryDiagnosticSession`.
6. Track it with `GetMemoryDiagnosticSessionStatus` or stop it with
   `CancelMemoryDiagnosticSession`.

The approved run instruments the DPR, builds, starts and correlates only a new supervised process,
performs warmup and measured repetitions, captures process snapshots, waits for natural process
termination, parses `.radia/memory/latest-fastmm5.log`, and restores the original DPR in a
finalization block.

Preparation is read-only. Running always requires consent. Restoration failures are reported and
never hidden. Snapshots contain Windows private-memory and working-set observations; detailed block,
class, and stack evidence comes from FastMM5.

`PrepareMemoryDiagnosticFix` selects the first project frame and returns its file, line, routine,
and allocation number. A follow-up session may break on that allocation.
`CompareMemoryDiagnosticEvidence` compares distinct builds under the same scenario and returns
`fixed`, `improved`, `unchanged`, `regressed`, or `incomparable`.

The global session duration also caps the currently running action. Abrupt interruption is covered
by a local recovery journal; conflicting user edits are preserved.
