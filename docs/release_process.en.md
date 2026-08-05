# Release Finalization Process

This document describes the recommended flow to finalize a **Rad IA** release with `develop`, `main`,
and tags synchronized.

> [!IMPORTANT]
> Create the tag only after `main` is updated to the same validated commit that reached `develop`.

---

## 1. Check Initial State

Before preparing the release, confirm that the working branch is clean and synchronized:

```powershell
git status --short --branch
git fetch --all --tags
git tag --sort=-v:refname
```

Use the latest published tag to define the next version. Example: if the latest tag is `v0.0.17`, the
next release is `v0.0.18`.

Working branches must follow the [Branch Naming Convention](branch_convention.en.md).

---

## 2. Update Version and Documentation

Update every public and technical place that displays the release version:

* `RadIA.rc`: `FILEVERSION`, `PRODUCTVERSION`, `FileVersion`, and `ProductVersion`.
* `Source/Integration/RadIA.OTA.Register.pas`: version displayed in the IDE About dialog.
* `package.json`: `version` field.
* `README.md` and `README.en.md`: summary of relevant features.
* `docs/features.md` and `docs/features.en.md`: feature catalog.
* `docs/backlog.md` and `docs/backlog.en.md`: technical release history.
* `docs/roadmap.md` and `docs/roadmap.en.md`: delivered release value.

Backlog and roadmap entries should be added above the latest published version, keeping descending order.

---

## 3. Validate Build and Frontend

Run validations before any merge:

```powershell
npx eslint
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0"
```

When unit tests need to be validated:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test
```

Run the analysis and wait for the Quality Gate of that exact analysis:

```powershell
powershell.exe -ExecutionPolicy Bypass -File run-sonar-analysis.ps1 `
  -Test `
  -DelphiVersion "22.0" `
  -QualityGate
```

The command fails when SonarQube processing fails, times out, or any Quality Gate condition is
rejected. Do not prepare a merge, tag, or release package in that state.

The `SonarQube release gate` workflow repeats this barrier for pull requests targeting `develop` and
`main`, pushes to those branches, and every `v*` tag. The self-hosted Windows runner must have the
`radia-delphi` label, Delphi 11, and `sonar-scanner`; configure `SONAR_TOKEN` as a repository secret
and `SONAR_HOST_URL` as a repository variable. Require the job as a status check in the `develop`
and `main` branch protection rules.

Known warnings may be accepted only when they are not a rejected Quality Gate condition, and they
should be mentioned in the final summary.

---

## 4. Commit and Publish the Working Branch

After validations pass, create the release preparation commit and publish the branch:

```powershell
git add README.md README.en.md RadIA.rc package.json docs
git add Source/Integration/RadIA.OTA.Register.pas
git commit -m "chore: Prepare v0.0.18 release"
git push origin <working-branch>
```

Adjust the message and version according to the real release. Commit messages must follow the
[Commit Message Convention](commit_convention.en.md).

---

## 5. Merge into Develop

Update `develop` from the working branch:

```powershell
git checkout develop
git pull --ff-only origin develop
git merge --ff-only <working-branch>
git push origin develop
```

If fast-forward is not possible, investigate before continuing. Do not create a tag while `develop`
and the working branch are divergent.

---

## 6. Merge Develop into Main

After `develop` is published, advance `main`:

```powershell
git checkout main
git pull --ff-only origin main
git merge --ff-only develop
git push origin main
```

At this point, `main`, `develop`, and the working branch should point to the same release commit.

---

## 7. Create and Publish the Tag

Create an annotated tag from `main`:

```powershell
git tag -a v0.0.18 -m "v0.0.18"
git push origin v0.0.18
```

Confirm the result:

```powershell
git status --short --branch
git log --oneline --decorate -5
git ls-remote --tags origin v0.0.18
```

---

## 8. Clean Up the Working Branch

Remove the working branch only when it is merged and synchronized locally/remotely:

```powershell
git merge-base --is-ancestor <working-branch> develop
git merge-base --is-ancestor <working-branch> main
git branch -d <working-branch>
git push origin --delete <working-branch>
git checkout develop
```

---

## Reproducible package evidence

Every package records a 40-character Git `sourceCommit` and `sourceDirty: false` in its
`manifest.json`. Packaging fails while tracked worktree changes exist, preventing an artifact from
claiming a source revision different from the code that was packaged.

After generating all four ZIPs, run:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseEvidence.ps1
```

The command requires the four packages for the version in `package.json`, expands and validates
each archive, confirms one version and source commit, checks clean-source evidence, computes
independent SHA-256 hashes, and writes `Output\ReleaseEvidence.json`.

---

## Final Checklist

* Version updated in code, metadata, and documentation.
* `npx eslint` executed.
* Delphi build executed successfully.
* The exact analysis passed the SonarQube Quality Gate.
* Required `Build, analyze, and enforce Quality Gate` status check passed.
* Release packages generated for Delphi 11, 12, 13 Win32, and Delphi 13 IDE64.
* Positive and negative validation completed for every package.
* `SHA256SUMS.txt` published with the four ZIPs generated from the same commit.
* No MCP process or discovery file left after smoke tests.
* Working branch published.
* `develop` updated and published.
* `main` updated and published.
* Annotated tag created from `main` and published.
* Working branch removed locally/remotely after merge.
