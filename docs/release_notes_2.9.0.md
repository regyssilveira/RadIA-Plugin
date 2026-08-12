# Notas de release - RadIA 2.9.0

> **Estado:** candidata à publicação em 12 de agosto de 2026.

O RadIA 2.9.0 torna a experiência Delphi mais contextual, segura e verificável. O catálogo desta
versão documenta 148 ferramentas internas.

## Contexto e conhecimento Delphi

- perfil sanitizado da IDE, arquitetura, projeto, framework, configuração, packages e bibliotecas;
- orientação Delphi curada, versionada, filtrável e citável;
- mentor que explica o código selecionado para perfis iniciante, migrante e experiente.

## Designer, auditoria e modernização

- auditoria bidirecional de DFM/PAS para componentes, declarações e eventos órfãos;
- snapshots e comparação visual antes/depois do Form Designer, com decisão explícita;
- migração reversível de BDE, ADO e dbExpress para FireDAC em lotes com gates de build e testes;
- planejamento posterior de DEXT e decomposição de forms sem reescrita automática arriscada.

## Governança e evidência

- contrato de execução autônoma com limites, pausa, retomada, checkpoints e rollback;
- ficha corporativa de segurança para comparar fluxos locais e remotos e os limites das garantias;
- benchmark local determinístico para medir sucesso, tempo, custo e rollback sem telemetria.

## Compatibilidade

- Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64 continuam como os alvos suportados;
- documentação operacional bilíngue e catálogo de 148 ferramentas sincronizados.

Consulte a [auditoria da release](release_audit_2.9.0.md) para os gates e evidências finais.
