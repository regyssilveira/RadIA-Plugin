# Notas de release — RadIA 2.3.0

Estado: publicada em 8 de agosto de 2026.

## Destaques

- RTK interno em Delphi para compactar resultados agentivos sem dependência de `rtk.exe`.
- Perfis `Off`, `Conservative` e `Balanced` em **General / Logs**.
- Orçamento global configurável do contexto de decisão.
- Artefatos integrais SHA-256 com quota, retenção e gravação atômica.
- Recuperação sem reexecução por `GetToolResultSummary` e `GetToolResultRange`.
- Regras para DUnitX, Git diff, build e conhecimento, com passthrough fail-open.
- Métricas sanitizadas em `/status agent` e snapshots de decisão.
- Catálogo ampliado de 124 para 126 ferramentas.

## Resultado de viabilidade

O corpus compilado mediu 96,71% de redução nos resultados e 96,55% no replay do contexto de decisão,
com 0% de aumento em chamadas repetidas. A matriz Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64
passou com 892 testes e zero leaks em cada target.

Consulte a [auditoria completa](result_compaction_release_audit_2.3.0.md).
Os números e a metodologia prontos para publicação estão no
[benchmark editorial](result_compaction_article_benchmark_2.3.0.md).

## Upgrade e rollback

O padrão é `Conservative`. Para rollback, selecione `Off` e salve; checkpoints e artefatos não
precisam ser apagados. Artefatos antigos expiram automaticamente após 14 dias.
