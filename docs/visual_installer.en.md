# Visual installer and release channel

RadIA 2.0.0 provides one visual installer for Delphi 11 Win32, Delphi 12 Win32, Delphi 13 Win32,
and Delphi 13 IDE64. The wizard detects installed IDEs, preselects available targets, and allows a
custom selection.

Each component contains the package for its exact combination and reuses
`Install-RadIA.Package.ps1`. The visual flow therefore preserves the guarantees used by the real
matrix: complete manifest and hash validation plus install, repair, and uninstall operations that
preserve user data by default.

## Build the installer

Install Inno Setup 6 and first build all four Release ZIP files from the same commit. Then run:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.VisualInstaller.ps1
```

The result is `Output\Installer\RadIA-v2.0.0-Setup.exe`.
`VisualInstallerEvidence.json` records version, size, SHA-256, Authenticode status, certificate,
and timestamp.

The proven development build is recorded in
[`visual_installer_evidence_2.0.0.json`](visual_installer_evidence_2.0.0.json). Its `NotSigned`
state remains intentionally visible and keeps the production gate closed.

Pass the thumbprint of a code-signing certificate with a private key for a production build:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.VisualInstaller.ps1 `
  -CertificateThumbprint "<THUMBPRINT>"
```

The generator uses SHA-256 and an RFC 3161 timestamp and fails unless `SignTool` produces a valid
Authenticode signature.

## Validate

Development mode validates identity, version, size, hash, and signature status:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.VisualInstaller.ps1
```

The production gate also requires a valid signature and timestamp:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.VisualInstaller.ps1 `
  -RequireSignature
```

## Publish the channel

The stable catalog is fail-closed: it requires HTTPS and rejects an installer without valid
Authenticode.

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.ReleaseChannel.ps1 `
  -InstallerPath Output\Installer\RadIA-v2.0.0-Setup.exe `
  -DownloadUrl "https://downloads.example.com/RadIA-v2.0.0-Setup.exe"
```

Only local tests may use `-AllowUnsignedDevelopment`. That switch explicitly changes the channel
name to `development`; it cannot produce a `stable` catalog.

## Signed release pipeline

The `.github/workflows/signed-release.yml` workflow runs the complete chain on a Windows Delphi
runner:

1. confirms that the tag is exactly `v` plus the `package.json` version;
2. runs lint, Web tests, and the documentation audit;
3. temporarily imports the PFX and validates its private key, code-signing EKU, and validity;
4. rebuilds all four Release packages from the tag commit;
5. confirms that packages share a clean version and commit with valid hashes;
6. builds and validates the installer with mandatory Authenticode and timestamp;
7. creates the `stable` catalog with the GitHub Release HTTPS URL;
8. publishes artifacts and removes the certificate and PFX under `always()`.

Configure these repository values:

- `RADIA_SIGNING_PFX_BASE64` secret: Base64-encoded PFX;
- `RADIA_SIGNING_PFX_PASSWORD` secret: PFX password;
- optional `RADIA_TIMESTAMP_URL` variable: RFC 3161 server.

Restrict secret access and require production-environment approval. The workflow can run manually
without publication to validate the distribution; a `v*` tag publishes the release. Audit its
fail-closed contract locally with:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\Test-RadIA.ReleasePipeline.ps1
```

## Remaining external gate

The code, installer, and catalog are prepared, but production publication can be approved only
after a trusted code-signing certificate is available. Do not use a self-signed certificate or
manually alter the catalog to bypass this gate.
