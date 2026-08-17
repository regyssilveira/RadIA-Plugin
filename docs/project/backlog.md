# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

## Estado atual

Não há item de engenharia ativo neste backlog. O FireDAC Advisor concluiu seu contrato funcional,
de segurança, documentação bilíngue, builds Delphi 12 e 13, testes unitários e de integração e a
matriz E2E de 16 cenários nos três targets suportados. Sua superfície pública e seu modo de uso estão
registrados nas referências e no guia do produto.

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
