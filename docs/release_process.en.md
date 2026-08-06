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
  -DelphiVersion "37.0" `
  -QualityGate
```

The command fails when SonarQube processing fails, times out, or any Quality Gate condition is
rejected. Do not prepare a merge, tag, or release package in that state.

The `SonarQube release gate` workflow repeats this barrier for pull requests targeting `develop` and
`main`, pushes to those branches, and every `v*` tag. The self-hosted Windows runner must have the
`radia-delphi` label, Delphi 13, and `sonar-scanner`; configure `SONAR_TOKEN` as a repository secret
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

After generating all three ZIPs, run:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseEvidence.ps1
```

The command requires the three packages for the version in `package.json`, expands and validates
each archive, confirms one version and source commit, checks clean-source evidence, computes
independent SHA-256 hashes, and writes `Output\ReleaseEvidence.json`.

## IDE smoke evidence

Run every smoke with `-EvidencePath` to bind real cycles to the published ZIP, its `sourceCommit`,
and the installed BPL:

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

Add `-IDE64` for Delphi 13 IDE64. Evidence generation is fail-closed: it rejects
`-SkipPackageHashCheck`, a missing package, a hash mismatch, dirty-source manifest evidence, or an
installed BPL that differs from the BPL in the proven ZIP. Close every IDE instance before
installation and smoke testing; the script also refuses to run when the target is already open.

`-ExercisePackageLifecycle` runs `Uninstall`, `Install`, and `Repair` from the proven ZIP before
each IDE launch while preserving user data. A cycle proceeds only after the installer revalidates
the manifest, hashes, registry, BPL, DCP, bridge, and Web assets.

`-UpgradeFromPackagePath` adds a real cross-version migration. The smoke validates the source
package, installs the previous version, applies the current ZIP, repairs it, and records the source
version and SHA-256 in evidence. The parameter requires `-ExercisePackageLifecycle`.

The versioned 2.0.0 matrix summary is stored in `ide_smoke_evidence_2.0.0.json`. It records ZIP and
BPL hashes, 10 passing cycles per target, duration range, the 95-tool catalog, native docking,
desktop restoration, and the absence of orphan processes.

After generating all three files under `Output\Validation`, consolidate the official proof with:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.IDESmokeEvidence.ps1
```

The consolidator fails when any target, cycle, upgrade, lifecycle mode, hash, commit, docking result,
or tool count diverges from the packages and release evidence. Never assemble or adjust the
versioned JSON manually.

### Terminal visual evidence

Use `-TerminalEvidencePath` with `-ExerciseTerminal` to open the real VCL surface and validate
geometry, required controls, profiles, the command palette, input, output, and keyboard tab navigation:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseTerminal `
  -SkipPackageHashCheck `
  -TerminalEvidencePath "Output\Validation\Terminal\Delphi13-Win32.json"
```

After all three supported targets, consolidate the fail-closed matrix:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.TerminalEvidence.ps1
```

The versioned result is stored in `terminal_smoke_evidence_2.0.0.json`.

### Ghost Text visual evidence

Use `-InlineCompletionEvidencePath` with `-ExerciseInlineCompletion` to prove real-unit capture,
local preparation, and OTA painting separately. This evidence requires clean tracked source but
may use `-SkipPackageHashCheck`, because it does not replace package provenance:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseInlineCompletion `
  -SkipPackageHashCheck `
  -InlineCompletionEvidencePath `
    "Output\Validation\InlineCompletion\Delphi13-Win32.json"
```

After all three supported targets, consolidate the fail-closed visual matrix:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.InlineCompletionEvidence.ps1
```

The versioned result is stored in `inline_completion_smoke_evidence_2.0.0.json`.

### Agent runtime journey evidence

Use `-ExerciseAgentRuntime` to execute approval, a read-only tool, pause, persistence,
new-instance resume, and completion without an external provider:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseAgentRuntime `
  -SkipPackageHashCheck `
  -AgentRuntimeEvidencePath `
    "Output\Validation\AgentRuntime\Delphi13-Win32.json"
```

Consolidate all three supported targets with:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.AgentRuntimeEvidence.ps1
```

The versioned result is stored in `agent_runtime_smoke_evidence_2.0.0.json`.

### Declarative workflow evidence

Use `-ExerciseDeclarativeWorkflow` to load a schema 5 manifest inside the IDE, register its
workflow in the shared catalog, and execute two steps through the policy executor:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseDeclarativeWorkflow `
  -SkipPackageHashCheck `
  -DeclarativeWorkflowEvidencePath `
    "Output\Validation\DeclarativeWorkflow\Delphi13-Win32.json"
```

After all three supported targets, consolidate the fail-closed matrix:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeWorkflowEvidence.ps1
```

The versioned result is stored in `declarative_workflow_smoke_evidence_2.0.0.json`.
The gate requires exactly three supported targets, 95 tools, and the
`RadIADiagnosticInspection` workflow loaded, registered, and executed through hot reload. The
evidence also confirms its `readOnly` classification and the completion of both workflow steps.

### Semantic knowledge evidence

Use `-ExerciseKnowledge` to open a real project, index it with the local provider, and validate
search, provenance, navigation, metrics, document retrieval, and isolation:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseKnowledge `
  -SkipPackageHashCheck `
  -KnowledgeEvidencePath "Output\Validation\Knowledge\Delphi13-Win32.json"
```

After all three supported targets, consolidate the fail-closed matrix:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.KnowledgeEvidence.ps1
```

The versioned result is stored in `knowledge_smoke_evidence_2.0.0.json`.

### Installation and first-value evidence

Use `-ExerciseFirstValue` to query the post-install diagnostic and execute the first tool:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.IDESmoke.ps1 `
  -DelphiVersion "37.0" `
  -Cycles 1 `
  -ExerciseFirstValue `
  -SkipPackageHashCheck `
  -FirstValueEvidencePath "Output\Validation\FirstValue\Delphi13-Win32.json"
```

After all three supported targets, consolidate the fail-closed matrix:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.FirstValueEvidence.ps1
```

The versioned result is stored in `first_value_smoke_evidence_2.0.0.json`.

### Visual installer and signed channel

After all three ZIP files pass validation, build the single installer:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.VisualInstaller.ps1 `
  -CertificateThumbprint "<THUMBPRINT>"

powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.VisualInstaller.ps1 `
  -RequireSignature
```

Publish the catalog only after the signed executable is available through HTTPS:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseChannel.ps1 `
  -InstallerPath Output\Installer\RadIA-v2.0.0-Setup.exe `
  -DownloadUrl "https://downloads.example.com/RadIA-v2.0.0-Setup.exe"
```

The `stable` catalog rejects missing or invalid signatures. See
[Visual installer and release channel](visual_installer.en.md) for the complete flow.

The `Signed RadIA release` workflow automates the same sequence for `v*` tags. Configure the
`RADIA_SIGNING_PFX_BASE64` and `RADIA_SIGNING_PFX_PASSWORD` secrets before enabling publication.
Production environment approval is recommended.

---

## Final Checklist

* Version updated in code, metadata, and documentation.
* `npx eslint` executed.
* `npm run test:web` and `npm run test:docs` executed.
* Delphi build executed successfully.
* The exact analysis passed the SonarQube Quality Gate.
* Required `Build, analyze, and enforce Quality Gate` status check passed.
* Release packages generated for Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64.
* Signed visual installer, validated timestamp, and stable HTTPS catalog published.
* Positive and negative validation completed for every package.
* `SHA256SUMS.txt` published with the three ZIPs generated from the same commit.
* JSON evidence for ten real cycles generated for every supported combination.
* No MCP process or discovery file left after smoke tests.
* Working branch published.
* `develop` updated and published.
* `main` updated and published.
* Annotated tag created from `main` and published.
* Working branch removed locally/remotely after merge.
