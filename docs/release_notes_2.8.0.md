# Notas de release - RadIA 2.8.0

> **Estado:** candidata validada para publicação em 11 de agosto de 2026.

RadIA 2.8.0 integra assistência semântica limitada ao editor sem substituir o provider nativo do
Delphi. O catálogo desta versão documenta 133 ferramentas internas.

## Contexto semântico compartilhado

- Ghost Text, ações contextuais e agente usam o mesmo analisador de contexto;
- unit, símbolo no cursor, imports e declarações próximas são coletados diretamente do buffer vivo;
- **Show Semantic Editor Context** permite inspecionar os metadados em modo somente leitura;
- ações como explicar, gerar testes e localizar bugs recebem o mesmo contexto do editor;
- `GetEditorSemanticContext` disponibiliza o contexto ao agente com risco `readOnly`.

## Compatibilidade e segurança

- o CodeInsight nativo do Delphi permanece responsável pelo provider padrão do editor;
- o contexto é limitado, observável e não altera o buffer durante a inspeção;
- Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64 permanecem como os únicos alvos suportados;
- documentação, release gates e scripts de evidência foram sincronizados com 133 ferramentas.

## Evidência

A [auditoria da release](release_audit_2.8.0.md) registra os gates executados para publicação.
