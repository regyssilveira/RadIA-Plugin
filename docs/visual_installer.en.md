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

## Remaining external gate

The code, installer, and catalog are prepared, but production publication can be approved only
after a trusted code-signing certificate is available. Do not use a self-signed certificate or
manually alter the catalog to bypass this gate.
