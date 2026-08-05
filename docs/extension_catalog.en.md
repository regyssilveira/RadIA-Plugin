# Remote extension catalog

RadIA 2.0 includes a secure layer for discovering and downloading declarative extensions from a
remote catalog. A catalog provides metadata; it never grants publisher trust automatically. Every
artifact must remain a version 2 `.radiaext` package with a valid RSA-SHA256 signature.

## Schema version 1

```json
{
  "schemaVersion": 1,
  "name": "Team catalog",
  "extensions": [
    {
      "id": "TeamCommands",
      "name": "Team commands",
      "description": "Reviewed prompts maintained by the team.",
      "version": "1.2.0",
      "package": {
        "url": "https://extensions.example.com/TeamCommands-1.2.0.radiaext",
        "size": 2048,
        "sha256": "64_CHARACTER_SHA256_HASH"
      },
      "publisher": {
        "id": "company.team",
        "name": "Company — Delphi Team",
        "fingerprint": "64_CHARACTER_SHA256_FINGERPRINT"
      }
    }
  ]
}
```

The document is limited to 1 MiB and 500 extensions. IDs use PascalCase, versions use
`major.minor.patch`, hashes and fingerprints are hexadecimal SHA-256 values, and URLs must be
absolute HTTPS URLs without credentials or fragments. Duplicate IDs are rejected case-insensitively.

## Download and verification

The catalog client:

1. accepts HTTPS only and disables automatic redirects;
2. limits the catalog to 1 MiB and packages to 4 MiB during streaming;
3. verifies declared size and SHA-256;
4. applies the complete `.radiaext` verifier, including closed entries, ZIP bomb and path defenses,
   manifest validation, and RSA-SHA256;
5. requires a signed version 2 package;
6. matches extension ID, version, publisher ID, and fingerprint against the catalog entry;
7. validates a temporary file before atomically replacing the destination;
8. preserves an existing file when download or validation fails.

An unknown publisher still goes through first-use consent after these checks. A tampered catalog
cannot turn an unknown key into a trusted key.

## Integration status

The schema, HTTPS transport, parser, transactional download, and cross-verification are implemented
and covered by tests. The next M4 step connects this layer to the extension manager's asynchronous
visual browser while keeping network operations off the IDE main thread.
