# Backlog do RadIA

Este arquivo contém somente trabalho aberto. Histórico, marcos concluídos, métricas e notas de
release não pertencem ao backlog.

## Estado atual

O goal ativo é o **FireDAC Advisor**. O trabalho abrange inventário, SQL, parâmetros, transações,
configuração, drivers, thread safety, schema, assistência por IA, geração, correções reversíveis,
migração, documentação e validação nas IDEs suportadas. O contrato executável interno mantém os
limites de segurança, a matriz de testes e a definição de pronto deste ciclo.

O goal não pode ser encerrado por uma entrega parcial. A conclusão exige todas as tools planejadas,
os testes unitários, de contrato, segurança e integração, os 16 cenários E2E, builds Delphi 12 e 13,
documentação bilíngue e auditoria requisito por requisito.

A fundação já disponível cobre inventário, análise de SQL selecionado e embutido, parâmetros,
transações, configuração, thread safety, comparação com schema SQLite local e contexto estruturado
para explicações por IA. Também estão disponíveis previews determinísticos e sem escrita para
repository, DataModule, query, DTO e fixture DUnitX, além de planos orientados por evidências para
otimização de query e thread safety. Permanecem abertos os fluxos de aplicação e reversão desses
artefatos. Correções reversíveis já cobrem mismatch comprovado de accessor de parâmetro e rollback
ausente, com ownership do preview e fingerprint. Permanecem abertos os gates compostos de build e
teste para correções isoladas. A migração legado agora possui aplicação própria e gates FireDAC,
build e DUnitX com rollback. O contrato da matriz E2E já enumera 16 cenários em Delphi 12 Win32,
Delphi 13 Win32 e Delphi 13 IDE64, totalizando 48 execuções determinísticas. Permanecem abertos a
conexão completa desse plano ao runner MCP/IDE real e a coleta das evidências runtime. Os cinco
cenários read-only iniciais já estão conectados e aprovados no Delphi 12 e 13 Win32: inventário,
análise sanitizada de SQL, redação de credenciais, transação sem rollback e compartilhamento em
thread. No IDE64, quatro estão aprovados; a auditoria de transação produz o resultado correto, mas
o `bds.exe` não encerra limpo depois da tool, falha reproduzida três vezes e ainda aberta. Também
faltam conectar os outros onze cenários e substituir a entrada SQL controlada do smoke pela captura
real da seleção no editor.

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
