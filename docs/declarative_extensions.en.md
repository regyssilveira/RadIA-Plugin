# Declarative extensions

RadIA 2.0 can load chat commands, templates, skills, journeys, policies, safe tool aliases, and
audited tool workflows without rebuilding the plugin or restarting Delphi. Each extension is a
`*.radia.json` manifest
stored under:

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

Use **Addon Studio...** in the same manager to create a command, skill, safe tool alias, journey,
or audited workflow without editing JSON. The form continuously validates the extension identity,
semantic version, names, slash commands, permissions, namespace rules, and workflow step JSON. It
shows the exact schema 5 manifest before installation. **Install** then sends that manifest through
the regular transactional validator, reserved-command checks, activation, diagnostics, and chat
reload path.

**Audit** shows the minimum permission, execution boundaries, credential restrictions, and central
consent policy before installation. **Export...** creates an unsigned `.radiaext`, calculates its
SHA-256, and reads the finished artifact through the same package verifier used during installation.
If verification fails, the partial output is removed. Unsigned packages still require explicit
install-time confirmation. RSA signing through the Windows Certificate Store remains available
through the packaging command documented below. The RadIA installer deploys that packager beside
the BPL, verifies its hash during `Install` and `Repair`, and removes it during `Uninstall`.

Use **Test** before installation to activate the manifest in an isolated temporary directory. The
sandbox runs the complete parser, permission rules, reserved-command collision checks, and
transactional reload. Its report shows the activated commands, aliases, and workflows. It never
changes installed extensions and removes the temporary directory afterward. The sandbox validates
activation; it does not execute prompts or side-effecting tools.

Schema 2 supports templates and skills. Schema 3 adds safe aliases, schema 4 adds team journeys and
policies, and schema 5 adds audited workflows of internal tools. Permissions must exactly match the
capabilities present: `chat.prompt`, `tool.alias`, and `tool.workflow`. Schemas 1–4 remain
compatible. The combined total is limited to 100 capabilities.

```json
{
  "schemaVersion": 4,
  "id": "TeamDelivery",
  "version": "4.0.0",
  "permissions": ["chat.prompt"],
  "journeys": [
    {
      "name": "Team release",
      "description": "Run the team's release gates.",
      "command": "/team-release",
      "objective": "Inspect health, validate targets, review the diff, and prepare a local commit preview."
    }
  ],
  "policies": [
    {
      "name": "Team architecture",
      "description": "Review using the shared architecture policy.",
      "command": "/team-architecture",
      "instructions": "Review API stability, ownership, thread safety, testability, and Delphi compatibility."
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

Schema 4 journeys start Agent Runtime with mandatory RadIA workspace inspection, plan review,
central consent, audit, preview, rollback, build, and test gates appended after the shared
objective. Policies expand only when the user explicitly selects their command. Optional
arguments are limited to 4,000 characters.

Schema 4 rejects fields named `apiKey`, `credential`, `password`, `secret`, or `token` at any
manifest depth. Credentials remain in each installation's protected settings and must never be
included in shared manifests or packages.

Schema 5 workflows register a tool whose name starts with the extension ID. Each workflow contains
1–16 fixed-argument steps that target existing internal tools. Declarative aliases and workflows
cannot be targets. The workflow inherits the highest risk, summed bounded timeout, and combined
idempotency from its steps. Every step re-enters the central policy executor, consent, and audit
flow; execution stops on the first failure, propagates cancellation and scope, and bounds aggregate
results to 1 MiB UTF-16. No manifest text is executed as PowerShell, shell code, or a binary.

The versioned functional matrix is available in
[`declarative_workflow_smoke_evidence_2.0.0.json`](declarative_workflow_smoke_evidence_2.0.0.json).
It proves hot-load, shared catalog registration, and audited two-step execution on Delphi 11, 12,
13 Win32, and Delphi 13 IDE64.

See `Examples/DeclarativeExtension/team-workflow.radia.json` for schema 2,
`Examples/DeclarativeExtension/team-tools.radia.json` for schema 3, and
`Examples/DeclarativeExtension/team-journeys.radia.json` for schema 4. See
`Examples/DeclarativeExtension/team-tool-workflow.radia.json` for schema 5.

The visual manager completes the local install, update, activation, diagnostics, and removal cycle.

## Distributable `.radiaext` package

Create a single-file package with:

```powershell
powershell.exe -ExecutionPolicy Bypass `
  -File scripts\New-RadIA.DeclarativeExtensionPackage.ps1 `
  -ManifestPath Examples\DeclarativeExtension\team-commands.radia.json
```

The packager accepts manifests from schemas 1 through 5, including aliases, journeys, policies,
and audited workflows.

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
