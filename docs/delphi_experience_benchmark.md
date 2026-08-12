# Benchmark reproduzível da experiência Delphi

O benchmark mede localmente as capacidades do plano de experiência Delphi. Não chama providers, não envia
telemetria e não usa código de projetos do usuário. Schemas e cenários versionados ficam em
`benchmarks/delphi-experience`.

Os nove cenários cobrem DFM/PAS, Designer, memória, migração com rollback, DUnitX, retomada, confinamento,
Delphi 12 Win32 e Delphi 13 IDE64. As fixtures DUnitX são entradas e expectativas determinísticas.

```powershell
powershell.exe -ExecutionPolicy Bypass -File scripts/Invoke-RadIA.DelphiExperienceBenchmark.ps1 -ValidateOnly
powershell.exe -ExecutionPolicy Bypass -File scripts/Invoke-RadIA.DelphiExperienceBenchmark.ps1
```

Compile antes a suíte nos alvos desejados. Use `-ScenarioId <id>` para isolar um cenário. O relatório JSON
registra sucesso, duração, custo estimado, rollback esperado/observado e SHA-256 da saída, sem incorporar
stdout, código, prompts ou credenciais. `telemetrySent` é sempre `false`; custo zero indica execução local.
