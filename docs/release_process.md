# Processo de Finalização de Release

Este documento descreve o fluxo recomendado para finalizar uma release do **Rad IA** com `develop`,
`main` e tags sincronizadas.

> [!IMPORTANT]
> A tag deve ser criada somente depois que `main` estiver atualizado com o mesmo commit validado em `develop`.

---

## 1. Conferir Estado Inicial

Antes de preparar a release, confirme que a branch de trabalho está limpa e sincronizada:

```powershell
git status --short --branch
git fetch --all --tags
git tag --sort=-v:refname
```

Use a última tag publicada para definir a próxima versão. Exemplo: se a última tag for `v0.0.17`, a
próxima release será `v0.0.18`.

Branches de trabalho devem seguir a [Convenção de Nomes de Branch](branch_convention.md).

---

## 2. Atualizar Versão e Documentação

Atualize todos os pontos públicos e técnicos que exibem a versão da release:

* `RadIA.rc`: `FILEVERSION`, `PRODUCTVERSION`, `FileVersion` e `ProductVersion`.
* `Source/Integration/RadIA.OTA.Register.pas`: versão exibida no About da IDE.
* `package.json`: campo `version`.
* `README.md` e `README.en.md`: resumo das funcionalidades relevantes.
* `docs/features.md` e `docs/features.en.md`: catálogo de recursos.
* `docs/backlog.md` e `docs/backlog.en.md`: histórico técnico da release.
* `docs/roadmap.md` e `docs/roadmap.en.md`: valor entregue na release.

As entradas de backlog e roadmap devem ser adicionadas acima da última versão publicada, mantendo a ordem decrescente.

---

## 3. Validar Build e Frontend

Execute as validações antes de qualquer merge:

```powershell
npx eslint
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0"
```

Quando houver necessidade de validar testes unitários:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test
```

Execute também a análise e aguarde o resultado do Quality Gate da análise exata:

```powershell
powershell.exe -ExecutionPolicy Bypass -File run-sonar-analysis.ps1 `
  -Test `
  -DelphiVersion "22.0" `
  -QualityGate
```

O comando termina com erro se o processamento do SonarQube falhar, exceder o timeout ou se qualquer
condição do Quality Gate estiver reprovada. Não prepare merge, tag ou pacote de release nesse estado.

O workflow `SonarQube release gate` repete essa barreira em pull requests para `develop` e `main`, nos
pushes dessas branches e em toda tag `v*`. O runner Windows self-hosted deve possuir o label
`radia-delphi`, Delphi 11 e `sonar-scanner`; configure `SONAR_TOKEN` como secret e `SONAR_HOST_URL`
como variável do repositório. Configure o job como status check obrigatório nas regras de proteção de
`develop` e `main`.

Warnings conhecidos podem ser aceitos somente quando não correspondem a uma condição reprovada do
Quality Gate e devem ser citados no resumo final.

---

## 4. Commitar e Publicar a Branch de Trabalho

Com as validações concluídas, crie o commit de preparação da release e publique a branch:

```powershell
git add README.md README.en.md RadIA.rc package.json docs
git add Source/Integration/RadIA.OTA.Register.pas
git commit -m "chore: Prepare v0.0.18 release"
git push origin <branch-de-trabalho>
```

Ajuste a mensagem e a versão conforme a release real. Mensagens de commit devem seguir a
[Convenção de Mensagens de Commit](commit_convention.md).

---

## 5. Merge em Develop

Atualize `develop` a partir da branch de trabalho:

```powershell
git checkout develop
git pull --ff-only origin develop
git merge --ff-only <branch-de-trabalho>
git push origin develop
```

Se o fast-forward não for possível, investigue antes de continuar. Não crie tag enquanto `develop` e
a branch de trabalho estiverem divergentes.

---

## 6. Merge de Develop em Main

Depois de `develop` publicado, avance `main`:

```powershell
git checkout main
git pull --ff-only origin main
git merge --ff-only develop
git push origin main
```

Neste ponto, `main`, `develop` e a branch de trabalho devem apontar para o mesmo commit de release.

---

## 7. Criar e Publicar a Tag

Crie uma tag anotada a partir de `main`:

```powershell
git tag -a v0.0.18 -m "v0.0.18"
git push origin v0.0.18
```

Confirme o resultado:

```powershell
git status --short --branch
git log --oneline --decorate -5
git ls-remote --tags origin v0.0.18
```

---

## 8. Limpar Branch de Trabalho

Somente remova a branch de trabalho quando ela estiver mergeada e sincronizada local/remoto:

```powershell
git merge-base --is-ancestor <branch-de-trabalho> develop
git merge-base --is-ancestor <branch-de-trabalho> main
git branch -d <branch-de-trabalho>
git push origin --delete <branch-de-trabalho>
git checkout develop
```

---

## Evidência reproduzível dos pacotes

Cada pacote registra no `manifest.json` o `sourceCommit` Git de 40 caracteres e
`sourceDirty: false`. O build com `-Package` falha se houver alteração rastreada ainda não
commitada. Isso impede atribuir um artefato a um commit diferente do código empacotado.

Depois de gerar os quatro ZIPs, execute:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseEvidence.ps1
```

O comando exige os quatro pacotes da versão declarada em `package.json`, expande e valida cada um,
confirma versão, configuração, plataforma, commit comum e árvore limpa, calcula hashes SHA-256
independentes e grava `Output\ReleaseEvidence.json`.

## Evidência do smoke na IDE

Execute cada smoke com `-EvidencePath` para vincular os ciclos reais ao ZIP publicado, ao
`sourceCommit` e à BPL instalada:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 10 `
  -ExerciseDocking `
  -ExercisePackageLifecycle `
  -UpgradeFromPackagePath `
    "Output\Packages\RadIA-v1.0.0-Delphi-37.0-Win32-Release.zip" `
  -EvidencePath "Output\Validation\Delphi13-Win32.json"
```

Acrescente `-IDE64` para o Delphi 13 IDE64. A geração da evidência é *fail-closed*: o comando
recusa `-SkipPackageHashCheck`, pacote ausente, hash divergente, árvore suja no manifesto ou BPL
instalada diferente da BPL contida no ZIP comprovado. Feche todas as instâncias da IDE antes da
instalação e do smoke; o script também recusa executar quando o target já está aberto.

`-ExercisePackageLifecycle` executa `Uninstall`, `Install` e `Repair` a partir do ZIP comprovado
antes de cada abertura da IDE, preservando os dados do usuário. O ciclo só prossegue quando o
instalador valida novamente manifesto, hashes, registro, BPL, DCP, bridge e assets Web.

`-UpgradeFromPackagePath` acrescenta uma migração real entre versões. O smoke valida o pacote de
origem, instala a versão anterior, aplica o ZIP atual, executa o reparo e registra versão e SHA-256
de origem na evidência. O parâmetro exige `-ExercisePackageLifecycle`.

O resumo versionado da matriz 2.0.0 está em `ide_smoke_evidence_2.0.0.json`. Ele registra os hashes
dos ZIPs e BPLs, os 10 ciclos aprovados por target, a faixa de duração, o catálogo de 90 tools,
docking nativo, restauração do desktop e ausência de processos órfãos.

---

## Checklist Final

* Versão atualizada em código, metadados e documentação.
* `npx eslint` executado.
* `npm run test:web` e `npm run test:docs` executados.
* Build Delphi executado com sucesso.
* Análise exata aprovada pelo SonarQube Quality Gate.
* Status check `Build, analyze, and enforce Quality Gate` obrigatório e aprovado.
* Pacotes Release gerados para Delphi 11, 12, 13 Win32 e Delphi 13 IDE64.
* Validação positiva e negativa executada para cada pacote.
* `SHA256SUMS.txt` publicado com os quatro ZIPs gerados pelo mesmo commit.
* Evidência JSON de dez ciclos reais gerada para cada combinação suportada.
* Nenhum processo ou discovery MCP órfão após os smokes.
* Branch de trabalho publicada.
* `develop` atualizado e publicado.
* `main` atualizado e publicado.
* Tag anotada criada a partir de `main` e publicada.
* Branch de trabalho removida local/remoto depois do merge.
