# Processo de release

Este guia define o processo permanente de publicação do RadIA. Notas, artefatos e evidências de uma
versão específica pertencem ao [GitHub Releases](https://github.com/regyssilveira/RadIA-Plugin/releases),
não à documentação do produto.

## 1. Preparar

1. Confirme que a branch de trabalho segue a [convenção de branches](branch_convention.md).
2. Atualize a versão em `RadIA.rc`, `package.json` e no registro da OTA.
3. Atualize somente documentação permanente afetada pela mudança.
4. Mantenha o [backlog](../project/backlog.md) restrito ao trabalho aberto e o
   [roadmap](../project/roadmap.md) restrito à direção futura.
5. Gere novamente o catálogo de ferramentas:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Update-RadIA.RuntimeToolCatalog.ps1
```

## 2. Validar

Execute as validações proporcionais à entrega. Uma release completa exige:

```powershell
npx eslint
node --test Tests/Web/RadIA.Documentation.test.js
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "37.0" -Test
```

Execute o scanner e exija o Quality Gate aprovado para a mesma revisão. Builds, testes, catálogo,
instalador e smokes devem apontar para o mesmo commit limpo. Nenhuma evidência deve ser editada
manualmente para contornar uma falha.

## 3. Empacotar

Gere o instalador visual pelo pipeline oficial. O pacote deve conter os binários suportados para Delphi
12 e 13, assets Web, bridge MCP, manifesto e hashes. O instalador é o único artefato público necessário;
arquivos de evidência permanecem como saída do pipeline e não são anexados à release.

Antes do smoke:

- feche todas as instâncias da IDE alvo;
- confirme versão, arquitetura e hash da BPL instalada;
- teste instalação limpa, atualização, reparo e desinstalação;
- valide Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64;
- confirme inicialização, docking, chat, agente, terminal e encerramento sem processos órfãos.

Os scripts em `scripts/` são a fonte executável dos parâmetros e critérios detalhados. Resultados ficam
em `Output/` ou em um diretório temporário ignorado pelo Git.

## 4. Publicar

1. Faça commit e push da branch validada conforme a [convenção de commits](commit_convention.md).
2. Integre a mesma revisão em `develop` e depois em `main`, sem reconstruir conteúdo manualmente.
3. Crie a tag anotada em `main`.
4. Publique o instalador e escreva as notas no GitHub Release.
5. Verifique atualização automática, download e hash pelo canal estável.

Não copie notas de versão, auditorias, goals, resultados ou evidências para `docs`. O histórico continua
disponível nas releases e no Git; `docs` deve explicar apenas o produto atual e como mantê-lo.
