# Processo de Finalização de Release

Este documento descreve o fluxo recomendado para finalizar uma release do **Rad IA** com `develop`, `main` e tags sincronizadas.

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

Use a última tag publicada para definir a próxima versão. Exemplo: se a última tag for `v0.0.17`, a próxima release será `v0.0.18`.

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

Warnings conhecidos podem ser aceitos quando não bloqueiam a release, mas devem ser citados no resumo final.

---

## 4. Commitar e Publicar a Branch de Trabalho

Com as validações concluídas, crie o commit de preparação da release e publique a branch:

```powershell
git add README.md README.en.md RadIA.rc package.json docs
git add Source/Integration/RadIA.OTA.Register.pas
git commit -m "chore: Prepare v0.0.18 release"
git push origin <branch-de-trabalho>
```

Ajuste a mensagem e a versão conforme a release real. Mensagens de commit devem seguir a [Convenção de Mensagens de Commit](commit_convention.md).

---

## 5. Merge em Develop

Atualize `develop` a partir da branch de trabalho:

```powershell
git checkout develop
git pull --ff-only origin develop
git merge --ff-only <branch-de-trabalho>
git push origin develop
```

Se o fast-forward não for possível, investigue antes de continuar. Não crie tag enquanto `develop` e a branch de trabalho estiverem divergentes.

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

## Checklist Final

* Versão atualizada em código, metadados e documentação.
* `npx eslint` executado.
* Build Delphi executado com sucesso.
* Pacotes Release gerados para Delphi 11, 12, 13 Win32 e Delphi 13 IDE64.
* Validação positiva e negativa executada para cada pacote.
* `SHA256SUMS.txt` publicado com os quatro ZIPs gerados pelo mesmo commit.
* Nenhum processo ou discovery MCP órfão após os smokes.
* Branch de trabalho publicada.
* `develop` atualizado e publicado.
* `main` atualizado e publicado.
* Tag anotada criada a partir de `main` e publicada.
* Branch de trabalho removida local/remoto depois do merge.
