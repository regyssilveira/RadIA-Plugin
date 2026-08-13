# Release process

This guide defines RadIA's permanent publication process. Version-specific notes, artifacts, and evidence
belong in [GitHub Releases](https://github.com/regyssilveira/RadIA-Plugin/releases), not in product
documentation.

## 1. Prepare

1. Confirm that the working branch follows the [branch convention](branch_convention.en.md).
2. Update the version in `RadIA.rc`, `package.json`, and OTA registration.
3. Update only permanent documentation affected by the change.
4. Keep the [backlog](../project/backlog.en.md) limited to open work and the
   [roadmap](../project/roadmap.en.md) limited to future direction.
5. Regenerate the tool catalog:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Update-RadIA.RuntimeToolCatalog.ps1
```

## 2. Validate

Run validations proportional to the delivery. A complete release requires:

```powershell
npx eslint
node --test Tests/Web/RadIA.Documentation.test.js
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "23.0" -Test
powershell.exe -ExecutionPolicy Bypass -File build.ps1 -DelphiVersion "37.0" -Test
```

Run the scanner **locally** and require a passing Quality Gate for the same revision. Builds, tests,
catalog, installer, and smoke tests must point to the same clean commit. Evidence must never be edited
manually to bypass a failure.

The GitHub Actions `SonarQube release gate` workflow is an optional manual repetition that depends on an
available registered Windows `self-hosted` runner. Pushes, pull requests, and tags do not start it. It
does not replace the local gate and must never block a release while waiting for external infrastructure.

## 3. Package

Build and validate the visual installer **locally**, before creating the tag. The package must include supported Delphi 12
and 13 binaries, Web assets, the MCP bridge, manifest, and hashes. The installer is the only required
public artifact; evidence files remain under `Output/` and are not attached to the release. GitHub Actions
is only an optional manual validation: it does not generate the official artifact and must never block publication.

Before smoke testing:

- close every instance of the target IDE;
- confirm the version, architecture, and installed BPL hash;
- test clean installation, upgrade, repair, and uninstall;
- validate Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64;
- confirm startup, docking, chat, agent, terminal, and shutdown without orphan processes.

Scripts under `scripts/` are the executable source for detailed parameters and criteria. Results belong
under `Output/` or a temporary Git-ignored directory.

## 4. Publish

1. Commit and push the validated branch according to the [commit convention](commit_convention.en.md).
2. Integrate the same revision into `develop` and then `main` without rebuilding content manually.
3. Confirm that the local installer and its evidence belong to the exact `main` commit.
4. Create and push the annotated tag from `main`. Pushing the tag must not start the release workflow.
5. Immediately publish the local installer with `gh release create`; do not wait for GitHub to build artifacts.
6. Download the published installer and confirm that its SHA-256 matches the local evidence.
7. Confirm that the release contains only the installer and verify automatic update through the stable channel.

Example for publishing the already validated artifact:

```powershell
gh release create v<VERSION> `
  ".\Output\Installer\RadIA-v<VERSION>-Setup.exe" `
  --verify-tag `
  --title "RadIA <VERSION>" `
  --notes-file ".\Output\Installer\release-notes-<VERSION>.md" `
  --latest
```

The `RadIA release` workflow can only be started manually. It provides independent validation when desired,
not the normal release path.

Do not copy release notes, audits, goals, results, or evidence into `docs`. History remains available in
releases and Git; `docs` must explain only the current product and how to maintain it.
