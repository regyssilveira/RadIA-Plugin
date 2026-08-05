# Declarative extensions

RadIA 2.0 can load chat commands, templates, skills, and safe tool aliases without rebuilding the
plugin or restarting Delphi. Each extension is a `*.radia.json` manifest stored under:

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

Schema 2 supports templates and skills. Schema 3 adds `tools`, which publish safe aliases for
existing internal tools. Permissions must exactly match the capabilities present: `chat.prompt`
for prompt capabilities and `tool.alias` for aliases. Schema 1 and 2 manifests remain compatible.
The combined total is limited to 100 capabilities.

```json
{
  "schemaVersion": 3,
  "id": "TeamTools",
  "version": "3.0.0",
  "permissions": ["tool.alias"],
  "tools": [
    {
      "name": "TeamToolsProjectHealth",
      "description": "Inspect project health under the team namespace.",
      "targetTool": "GetProjectHealth"
    }
  ]
}
```

An alias name must start with the extension ID and cannot target another declarative alias. It
inherits the target input/output schemas, risk, timeout, and idempotency. Execution therefore uses
the same consent and audit policy exposed to chat and MCP. Disabling, removing, or reloading the
extension unregisters the alias. Missing targets, collisions, and registration failures preserve
the previous alias set and appear as `runtime-rejected`. Schema 3 cannot execute arbitrary scripts
or binaries and cannot widen the target tool's permissions.

Prompts and skill instructions may use `{code}`, `{argument}`, `{specification}`, and
`{stacktrace}`. Declarative prompt capabilities do not run processes, writes, or OTA operations.
Advanced tools with custom implementations remain available through the
BPL API documented in the [extension guide](tool_extension_guide.md) and remain subject to central
risk and consent policies.

See `Examples/DeclarativeExtension/team-workflow.radia.json` for schema 2 and
`Examples/DeclarativeExtension/team-tools.radia.json` for a complete schema 3 tool alias.

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
should still verify the fingerprint through an independent channel. Distributed publication and
revocation remain a future M4 stage. The asynchronous visual browser, secure schema, HTTPS,
transactional download, and package verification are documented in
[Remote extension catalog](extension_catalog.en.md).
