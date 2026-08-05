# Declarative extensions

RadIA 2.0 can load chat commands without recompiling the plugin or restarting Delphi. Each extension
is a `*.radia.json` manifest stored under:

```text
%USERPROFILE%\RadIA\extensions
```

When RadIA uses a custom data directory, `extensions` is created below it. Run
`/extensions reload` to reload files, refresh autocomplete, and view diagnostics. RadIA also reloads
before resolving a command, so adding or removing a manifest takes effect in the same session.

## Visual manager

Open **Tools > Rad IA Extensions...** to install or update a manifest, enable or disable it, reload
diagnostics, manage trusted publishers, or remove it with explicit confirmation. Installs, updates,
and status changes use an atomic write. RadIA validates the candidate first, reloads the complete
installed set, and restores the previous file if validation or activation fails. An open chat
refreshes its catalog, while chats opened later load the current state directly.

The version 1 loader requires a unique PascalCase ID, semantic version, the single `chat.prompt`
permission, and between 1 and 100 valid commands. It rejects the complete manifest on collision or
invalid data. Diagnostics report `loaded`, `disabled`, or `rejected`.

Prompts may use `{code}`, `{argument}`, `{specification}`, and `{stacktrace}`. Version 1 does not run
scripts, tools, processes, writes, or OTA operations. Advanced tools remain available through the
BPL API documented in the [extension guide](tool_extension_guide.md) and remain subject to central
risk and consent policies.

The visual manager completes the local install, update, activation, diagnostics, and removal cycle.

## Distributable `.radiaext` package

Create a single-file package with:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeExtensionPackage.ps1 `
  -ManifestPath Examples\DeclarativeExtension\team-commands.radia.json
```

The package contains exactly `package.json` and `<ExtensionId>.radia.json`. Metadata records the
schema, ID, version, closed file list, UTF-8 size, and SHA-256. The visual manager imports
`.radiaext` from **Install / Update...** and rejects extra or duplicate entries, unsafe paths,
oversized entries, identity mismatches, size mismatches, and tampered hashes before transactional
manifest validation and activation.

The command above creates an unsigned version 1 package. To create a signed version 2 package, use
an RSA certificate with at least 2,048 bits and a private key in `Cert:\CurrentUser\My`:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeExtensionPackage.ps1 `
  -ManifestPath Examples\DeclarativeExtension\team-commands.radia.json `
  -SigningCertificateThumbprint "CERTIFICATE_THUMBPRINT" `
  -PublisherId "company.product" `
  -PublisherName "Verifiable publisher name"
```

The script signs through the Windows certificate provider without exporting the private key.
Version 2 signs package identity, manifest size and hash, publisher identity, and the RSA public key.
RadIA verifies RSA-SHA256 through Windows CNG before consent. First use shows the publisher ID,
name, and SHA-256 key fingerprint. Approval stores trust in
`%USERPROFILE%\RadIA\trusted-extension-publishers.json`; later key changes require a new explicit
decision. Use **Trusted publishers...** to inspect fingerprints and revoke trust.

Version 1 remains compatible but is integrity-only and requires a one-time warning. The trust store
uses atomic writes, validates IDs and fingerprints, rejects duplicates and reparse points, and does
not silently replace invalid state. A signed package proves possession of its private key; users
should still verify the fingerprint through an independent channel. Trusted remote catalogs remain
a future M4 stage.
