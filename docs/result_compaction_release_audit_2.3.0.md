# Auditoria de viabilidade do RTK interno — RadIA 2.3.0

Data: 8 de agosto de 2026. Estado: **go técnico; candidata preparada e não publicada**.

## Resultado mensurado

| Gate | Resultado | Situação |
|---|---:|---|
| Caracteres dos resultados | 1.145.022 → 37.630 | 96,71% de redução |
| Tokens estimados | 286.256 → 9.408 | estimativa de 4 caracteres/token |
| Redução mediana elegível | 98,65% | aprovado, mínimo 30% |
| Contexto de decisão A/B | 1.152.074 → 39.750 | 96,55%, mínimo 20% |
| Chamadas repetidas | 7 Off / 7 Conservative | 0%, máximo 5% |
| P95 de compactação | 47.779 µs | aprovado, máximo 50.000 µs para 1 MiB |
| Suíte Delphi | 892/892 | zero falha, erro ou leak |

A evidência completa e sanitizada está em
[`result_compaction_evidence_2.3.0.json`](result_compaction_evidence_2.3.0.json), SHA-256
`039969BEB7D068A8041F11BC1F5FEC1D8C418D28417950761BBB26EE2B001992`.

## Matriz compilada

- Delphi 12 Athens, Win32 Release: 892/892 testes, zero leak.
- Delphi 13, Win32 Release: 892/892 testes, zero leak.
- Delphi 13, IDE64 Win64 Release: 892/892 testes, zero leak.
- Delphi 13 IDE64: smoke automatizado aprovado com 126 ferramentas e ciclo do runtime agentivo completo.
- ESLint, 40 testes web e 14 testes documentais: aprovados.
- SonarQube: quality gate aprovado, 83,0% de cobertura em código novo e zero issues.

## Segurança e recuperação

O resultado integral usa hash SHA-256, escrita atômica, boundary de sessão, quota de 100 artefatos e
64 Mi caracteres por sessão, 8 Mi por artefato e retenção de 14 dias. Range é limitado a 65.536
caracteres e respeita boundary Unicode. Testes cobrem traversal, spoofing de sessão, quota,
expiração, concorrência e reabertura.

## Decisão de rollout

Os gates de economia, fidelidade, recuperação, desempenho, compatibilidade, segurança e operação
foram aprovados. A candidata 2.3.0 permanece local e não deve ser publicada até autorização expressa.
