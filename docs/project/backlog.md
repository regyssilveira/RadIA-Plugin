# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

## Goal ativo: fechamento determinístico da experiência Delphi

Encerrar com evidência reproduzível todas as diferenças acionáveis da experiência atual, reutilizando
as capacidades existentes antes de implementar qualquer nova infraestrutura.

- [ ] integrar terminal, chat e jornadas com navegação de erros;
- [ ] provar estabilidade do WebView atual em dock, undock, resize e recuperação;
- [ ] tornar o conhecimento local explicável e verificável;
- [ ] eliminar consentimentos redundantes sem ampliar permissões;
- [ ] provar isolamento, recuperação e métricas do motor semântico;
- [ ] fechar todas as frentes no mesmo ledger, commit e gate integrado.

O escopo exclui repositório público ou marketplace de extensões, C++Builder, Delphi 11, Lazarus,
GetIt, integrações exclusivas da Embarcadero e substituição do WebView atual.

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
