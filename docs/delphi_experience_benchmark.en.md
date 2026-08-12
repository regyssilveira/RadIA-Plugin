# Reproducible Delphi experience benchmark

The benchmark locally measures the Delphi experience plan. It calls no provider, sends no telemetry, and
uses no user-project code. Versioned schemas and scenarios live under `benchmarks/delphi-experience`.

Nine scenarios cover DFM/PAS, Designer, memory, migration rollback, DUnitX, resume, confinement, Delphi 12
Win32, and Delphi 13 IDE64. DUnitX fixtures provide deterministic inputs and expectations.

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts/Invoke-RadIA.DelphiExperienceBenchmark.ps1 -ValidateOnly
powershell.exe -ExecutionPolicy Bypass -File scripts/Invoke-RadIA.DelphiExperienceBenchmark.ps1
```

Compile the suite for desired targets first. Use `-ScenarioId <id>` to isolate a scenario. The JSON report
records success, duration, estimated cost, expected/observed rollback, and output SHA-256 without embedding
stdout, code, prompts, or credentials. `telemetrySent` is always `false`; zero cost means local execution.
