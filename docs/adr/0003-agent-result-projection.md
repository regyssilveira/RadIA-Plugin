# ADR 0003 — Resultado integral e projeção compactada do agente

## Status

Aceito para a versão 2.3.0.

## Contexto

Resultados extensos de build, testes, Git e conhecimento consumiam a janela de decisão do modelo.
Truncar o único resultado disponível eliminaria evidência e poderia forçar a repetição da ferramenta.

## Decisão

O resultado integral é persistido por sessão e step como artefato SHA-256. Checkpoint, replay, UI e
validation gates continuam usando esse resultado. Apenas a fronteira que monta o próximo contexto do
modelo usa uma projeção determinística e descartável.

Conteúdo omitido deve apontar para um `artifactId` recuperável por `GetToolResultSummary` e
`GetToolResultRange`. Falha de parsing, regra desconhecida ou projeção maior resulta em passthrough.
Métricas contêm apenas perfil, regra, caracteres e duração.

## Consequências

- O modelo recebe menos contexto sem perder a possibilidade de inspeção detalhada.
- O armazenamento precisa de quota, retenção, boundary de sessão e limpeza.
- Novas regras exigem fixtures sanitizadas, fidelidade e benchmark.
- `Off` preserva rollback imediato sem apagar checkpoints ou artefatos.
