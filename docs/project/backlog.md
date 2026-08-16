# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

## Estado atual

Não existe goal ativo nem item aberto aprovado no backlog público.

A plataforma determinística de integração e ponta a ponta que constava anteriormente como pendente
foi concluída. O gate obrigatório `Test-RadIA.ReleaseUsage.ps1` reúne as suítes DUnitX do Delphi 12
e 13, os cenários registrados de integração e uso, a calculadora, a geração e abertura de projetos e
a matriz automatizada nos três alvos suportados. O contrato vigente está na
[matriz automatizada de testes de uso](../development/usage_test_matrix.md).

Novas propostas somente entram neste arquivo depois de aprovadas como trabalho executável, com
resultado observável e critérios de aceitação. Ideias ainda não aprovadas não são apresentadas como
compromisso do produto.

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
