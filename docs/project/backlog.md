# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

## Estado atual

Não há item ou goal aberto. O fechamento determinístico da experiência Delphi foi concluído e validado
pelos gates integrados da versão publicada. Novos trabalhos só entram neste arquivo quando possuírem
escopo executável e critérios de aceitação definidos.

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
