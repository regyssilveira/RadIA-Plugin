# Migração incremental de acesso a dados legado

O RadIA inventaria referências a BDE, ADO e dbExpress no projeto ativo, classifica o risco e mapeia
equivalentes FireDAC. A jornada trabalha por tecnologia e arquivo: não realiza reescrita total automática.

## Fluxo recomendado

1. Execute `InventoryLegacyDataAccess` para ler o `.dproj`, as units e os forms do projeto ativo.
2. Revise tecnologia, risco, equivalente FireDAC e ação manual de cada achado.
3. Execute `PlanLegacyMigrationBatches`; cada lote fica limitado a uma tecnologia e um arquivo.
4. Use `PrepareLegacyMigrationBatch` para gerar o preview reversível de um lote elegível.
5. Revise o diff e aplique o `previewId` com `ApplyMultiFilePatch`.
6. Execute `BuildProject` e `RunDUnitXTests`.
7. Registre os dois resultados com `RecordLegacyMigrationGate`.
8. Consulte `GetLegacyMigrationReport` para acompanhar compatibilidade e pendências manuais.

Se build ou testes falharem, o registro do gate reverte o lote aplicado. Evidências textuais de ambos os
gates são obrigatórias. Conexões, drivers, aliases, transações e parâmetros permanecem manuais porque
suas semânticas não podem ser inferidas com segurança apenas pela classe do componente.

## DEXT e decomposição de forms

`PlanDextAndFormModernization` produz um plano posterior à estabilização FireDAC: extrair interfaces de
acesso a dados, comprovar paridade de comportamento, introduzir a fronteira DEXT e só então decompor
forms por responsabilidades de dados, ações e navegação. A ferramenta não altera código nem Designer.

## Limites

- até 500 arquivos, 2 MiB por arquivo e 2.000 achados por inventário;
- preview de um arquivo por lote, sujeito aos limites normais de patches;
- o agente deve aplicar e validar um lote antes de preparar o seguinte;
- arquivos fora do projeto ativo não entram no inventário.
