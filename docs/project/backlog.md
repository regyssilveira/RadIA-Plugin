# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

## Ciclo ativo: eficiência observável do agente

**Resultado observável:** explicar, sem conteúdo sensível, por que cada execução consumiu decisões,
tools, tempo e tokens; reduzir trabalho repetido sem enfraquecer consentimento, validação ou rollback.

**Escopo em ordem de entrega:**

1. gates de desempenho pareados e relativos para duração, etapas, tokens e responsividade;
2. conhecimento operacional sanitizado, limitado, revisável e isolado por projeto;
3. orquestrador de publicação com `DryRun`, sem substituir os gates existentes.

**Ameaças:** baseline instável; memória local tratada como verdade; automação de publicação usando
artefato de outro commit.

**Validação:** DUnitX no Delphi 12 e 13, testes documentais, lint aplicável, SonarQube e cenário E2E
proporcional antes de encerrar cada incremento. Nenhuma release faz parte deste ciclo até autorização
explícita do mantenedor.

Novos ciclos devem entrar aqui somente depois de possuírem resultado observável, escopo, ameaças,
critérios de aceitação e plano de validação definidos.

Permanecem fora do escopo repositório público ou marketplace de extensões, C++Builder, Delphi 11,
Lazarus, GetIt, integrações exclusivas da Embarcadero e substituição do WebView atual.

## Definição de concluído para novos itens

Cada novo item deverá exigir:

- contrato e ameaça documentados antes da implementação;
- suporte comprovado no Delphi 12 e 13, com capacidade indisponível reportada explicitamente;
- testes unitários, integração OTA e cenário ponta a ponta proporcional ao risco;
- cenário automatizado de uso incluído na matriz de regressão para cada comportamento novo;
- preview, consentimento, fingerprint e rollback para qualquer mutação;
- atualização simultânea do manual, referências, hints, traduções e testes documentais;
- build local, DUnitX, lint aplicável e SonarQube aprovados;
- evidência observável do resultado, não apenas existência de classes ou tools.
