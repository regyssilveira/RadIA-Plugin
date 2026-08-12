# Structured DUnitX runner

RadIA runs DUnitX tests without interpreting console formatting. The executable writes a native
NUnit XML report, which RadIA converts to structured JSON for chat, agent mode, and MCP clients.

## Tools

- `RunDUnitXTests` accepts `executablePath`, optional `timeoutMs`, and optional `tests`.
- `GetDUnitXStatus` returns the current execution state.
- `CancelDUnitXTests` cancels the active process.

The active Delphi project defines the authorized workspace. Only `.exe` files inside that boundary
are accepted, and paths containing reparse points are rejected. A single process may run at once;
timeout and cancellation terminate it. XML and captured output remain under
`.radia/test-results` for diagnostics and audit.

The executable must call `TDUnitX.CheckCommandLine` and register
`TDUnitXXMLNUnitFileLogger` with `TDUnitX.Options.XMLOutputFile`. RadIA-generated DUnitX projects
include this contract by default.

The parser, tools, and executor are validated on Delphi 12 and 13, including the Delphi 13
Win64 IDE package and test suite.
