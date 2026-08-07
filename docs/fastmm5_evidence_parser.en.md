# FastMM5 log collection and parsing

RadIA converts FastMM5 text into bounded JSON evidence suitable for chat and MCP. It recognizes
leaks, double free, use-after-free, header/footer corruption, allocation numbers, classes, sizes,
and source-resolved frames. Fingerprints exclude process addresses and remain stable across builds.

`ParseMemoryDiagnosticLog` accepts only logs inside the active workspace. Limits are enforced while
reading, before loading the complete file. File logs and `OutputDebugString` chunks share the same
collector and parser. Results are capped at 1,000 events and 100 frames per event.
