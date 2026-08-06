# Exemplo de extensão declarativa

O arquivo `team-commands.radia.json` pode ser instalado diretamente em
**Tools > Rad IA Extensions... > Install / Update...**.

Para gerar o artefato distribuível com metadados e SHA-256:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeExtensionPackage.ps1 `
  -ManifestPath Examples\DeclarativeExtension\team-commands.radia.json
```

O arquivo `TeamCommands-1.0.0.radiaext` resultante também pode ser selecionado no gerenciador
visual. O importador verifica o envelope e o conteúdo antes de instalar o manifesto.

Os exemplos adicionais cobrem templates/skills (schema 2), aliases (schema 3), jornadas/políticas
(schema 4) e workflows auditados de tools (schema 5). O arquivo
`team-tool-workflow.radia.json` executa somente tools internas pelo consentimento e auditoria
centrais; ele não inicia scripts, shells ou binários arbitrários.
