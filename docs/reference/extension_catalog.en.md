# Remote extension catalog

RadIA includes a secure layer for discovering and downloading declarative extensions from a remote
catalog. A catalog provides metadata; it never grants publisher trust automatically. Every artifact
must remain a signed `.radiaext` package: envelope v2 for a manifest without resources or v3 when
it carries references, knowledge, templates, or assets.

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
2. limits the catalog to 1 MiB and packages to 20 MiB during streaming;
3. verifies declared size and SHA-256;
4. applies the complete `.radiaext` verifier, including closed entries, ZIP bomb and path defenses,
   manifest validation, and RSA-SHA256;
5. requires a signed version 2 or 3 package;
6. matches extension ID, version, publisher ID, and fingerprint against the catalog entry;
7. validates a temporary file before atomically replacing the destination;
8. preserves an existing file when download or validation fails.

An unknown publisher still goes through first-use consent after these checks. A tampered catalog
cannot turn an unknown key into a trusted key.

## Using the manager

1. Open **Tools > Rad IA Extensions...**.
2. Click **Browse catalog...**.
3. Enter the catalog HTTPS URL and click **Load catalog**.
4. Search by name, ID, description, or publisher.
5. Select an extension and click **Download**.
6. Review the publisher identity and fingerprint during first-use consent.

Catalogs and packages are downloaded in the background without blocking the IDE UI thread. The URL
is remembered in `%USERPROFILE%\RadIA\extension-catalog.json`; URL credentials are rejected and are
never stored. The package enters the shared installation flow only after every check succeeds, so
local and remote packages use the same trust policy.
