# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

## Ciclo ativo: eficiência observável do agente

**Resultado observável:** explicar, sem conteúdo sensível, por que cada execução consumiu decisões,
tools, tempo e tokens; reduzir trabalho repetido sem enfraquecer consentimento, validação ou rollback.

**Escopo em ordem de entrega:**

1. resumo sanitizado por execução, com motivo normalizado de parada e uso desconhecido explícito;
2. matrizes de regressão com caso válido, ausente, vazio, inválido, parcial, repetido e cancelado;
3. eliminação de decisões, tools e contexto repetidos, medida contra um baseline reproduzível;
4. diagnóstico contextual cancelável no editor, sem varrer a unit a cada movimento do cursor;
5. projeção opcional de achados na Message View, mantendo Problems como fonte de verdade;
6. gates de desempenho pareados e relativos para duração, etapas, tokens e responsividade;
7. conhecimento operacional sanitizado, limitado, revisável e isolado por projeto;
8. orquestrador de publicação com `DryRun`, sem substituir os gates existentes.

**Ameaças:** vazamento de prompt ou código em métricas; falsa economia por remover validação; resposta
obsoleta aplicada ao cursor; referências OTA sobrevivendo ao unload; baseline instável; memória local
tratada como verdade; automação de publicação usando artefato de outro commit.

**Aceitação do primeiro incremento:** o log diferencia conclusão, aprovação, pausa, cancelamento e cada
limite conhecido; agrega decisões, tools, falhas, repetições, recuperações, validações e duração; informa
tokens somente quando reportados; testes provam que objetivo, argumentos, resultados, caminhos e IDs
originais não aparecem.

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
