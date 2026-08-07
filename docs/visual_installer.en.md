# Visual installer and release channel

RadIA has one visual installer for Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64.
The wizard detects installed IDEs, preselects matching targets, and lets users customize the
selection.

Each component contains the package for that combination and reuses `Install-RadIA.Package.ps1`.
The flow preserves manifest validation, hashes, installation, repair, and removal with user data
preserved by default.

## Build the installer

Install Inno Setup 6 and generate the three Release ZIP files from the same commit. Then run:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.VisualInstaller.ps1
```

The result uses the version from `package.json`. To obtain its current path:

```powershell
$version = (Get-Content package.json -Raw | ConvertFrom-Json).version
$installer = "Output\Installer\RadIA-v$version-Setup.exe"
```
`VisualInstallerEvidence.json` records version, size, SHA-256, and informational Authenticode
status.

Each release records `visual_installer_evidence_<version>.json`. For example, see
[`visual_installer_evidence_2.2.0.json`](visual_installer_evidence_2.2.0.json). Its `NotSigned`
status is intentional: RadIA is open source, can be built by users, and does not require a
certificate for publication.

## Validate

The gate validates identity, version, size, hash, and Authenticode state consistency:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.VisualInstaller.ps1
```

## Publish the channel

The stable catalog requires HTTPS and publishes size, SHA-256, and Authenticode state for
verification:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseChannel.ps1 `
  -InstallerPath $installer `
  -DownloadUrl (
    "https://github.com/regyssilveira/RadIA-Plugin/releases/" +
    "download/v$version/RadIA-v$version-Setup.exe"
  )
```

## Release pipeline

The `.github/workflows/release.yml` workflow runs the complete chain on a Windows Delphi runner:

1. verifies that the tag is exactly `v` plus the `package.json` version;
2. runs lint, Web tests, and the documentation audit;
3. rebuilds the three Release packages from the tag commit;
4. verifies that all packages share the version, clean commit, and valid hashes;
5. builds and validates the installer without a certificate dependency;
6. creates the `stable` catalog with the GitHub Release HTTPS URL;
7. publishes the installer, ZIPs, `SHA256SUMS.txt`, catalog, and evidence.

The workflow can run manually without publishing to validate the distribution; a `v*` tag
publishes the release. Audit the pipeline contract locally with:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleasePipeline.ps1
```

Certificate and marketplace are not gates for the current channel. SHA-256 and release origin
remain mandatory for artifact verification.
