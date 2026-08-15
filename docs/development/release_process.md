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
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.ReleaseUsage.ps1
```

`Test-RadIA.ReleaseUsage.ps1` é obrigatório em toda release e executa, como um único gate indivisível,
as suítes DUnitX completas no Delphi 12 e 13, toda a suíte registrada de integração e ponta a ponta, a
criação e os testes funcionais e DUnitX da calculadora, a criação e abertura imediata de projetos e a
matriz automatizada de uso no Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64. O gate produz evidência
sanitizada em `Output/Validation/ReleaseUsage` e qualquer grupo, alvo ou cenário ausente, ignorado ou
reprovado bloqueia a publicação. Não execute nem aprove esses grupos isoladamente para autorizar uma
release.

Execute o scanner **localmente** e exija o Quality Gate aprovado para a mesma revisão. Builds, testes,
catálogo, instalador e smokes devem apontar para o mesmo commit limpo. Nenhuma evidência deve ser
editada manualmente para contornar uma falha.

O workflow `SonarQube release gate` do GitHub Actions é uma repetição manual opcional, dependente de um
runner Windows `self-hosted` registrado e disponível. Ele não é disparado por push, pull request ou tag,
não substitui o gate local e nunca deve bloquear uma release enquanto aguarda infraestrutura externa.

## 3. Empacotar

Gere e valide o instalador visual **localmente**, antes de criar a tag. O pacote deve conter os
binários suportados para Delphi 12 e 13, assets Web, bridge MCP, manifesto e hashes. O instalador é o
único artefato público necessário;
arquivos de evidência permanecem em `Output/` e não são anexados à release. O GitHub Actions é apenas
uma validação manual opcional: ele não gera o artefato oficial e nunca deve bloquear a publicação.

Antes do smoke:

- feche todas as instâncias da IDE alvo;
- confirme versão, arquitetura e hash da BPL instalada;
- teste instalação limpa, atualização, reparo e desinstalação;
- valide Delphi 12 Win32, Delphi 13 Win32 e Delphi 13 IDE64;
- execute `Test-RadIA.ProjectCreationNavigation.ps1` no Delphi 12 e 13 para provar que um projeto
  recém-criado pode ser aberto e navegado imediatamente, sem corrida de inicialização;
- execute `Test-RadIA.KnowledgeProjectTransition.ps1` no Delphi 12 e 13; o gate deve fechar um projeto,
  abrir outro e navegar em sua unit com o `KnowledgeNotifier` ativo;
- confirme inicialização, docking, chat, agente, terminal e encerramento sem processos órfãos.

Os scripts em `scripts/` são a fonte executável dos parâmetros e critérios detalhados. Resultados ficam
em `Output/` ou em um diretório temporário ignorado pelo Git.

## 4. Publicar

1. Faça commit e push da branch validada conforme a [convenção de commits](commit_convention.md).
2. Integre a mesma revisão em `develop` e depois em `main`, sem reconstruir conteúdo manualmente.
3. Confirme que o instalador local e sua evidência pertencem exatamente ao commit de `main`.
4. Crie e envie a tag anotada em `main`. O envio da tag não deve iniciar o workflow de release.
5. Publique imediatamente o instalador local com `gh release create`; não aguarde o GitHub gerar artefatos.
6. Baixe o instalador publicado e confirme que seu SHA-256 é igual ao da evidência local.
7. Confirme que a release contém somente o instalador e verifique a atualização automática pelo canal estável.

Exemplo de publicação do artefato já validado:

```powershell
gh release create v<VERSAO> `
  ".\Output\Installer\RadIA-v<VERSAO>-Setup.exe" `
  --verify-tag `
  --title "RadIA <VERSAO>" `
  --notes-file ".\Output\Installer\release-notes-<VERSAO>.md" `
  --latest
```

O workflow `RadIA release` só pode ser acionado manualmente. Ele serve para uma validação independente
quando desejada, não para o caminho normal da release.

Não copie notas de versão, auditorias, goals, resultados ou evidências para `docs`. O histórico continua
disponível nas releases e no Git; `docs` deve explicar apenas o produto atual e como mantê-lo.
