# Local project knowledge guide

## Purpose

Local knowledge lets RadIA search project symbols and excerpts without depending on an external
service. The index is derived from the workspace, can be rebuilt, and combines lexical retrieval
with local vector similarity.

## Index lifecycle

RadIA maintains an independent index for each project. OTA notifications update a document when it
is edited, saved, or renamed and remove its active identity when it is closed.

An edit may appear in search before save. After a rename, results use the new file identity.

## Usage

Typical chat or MCP requests include:

- “Index the active project.”
- “Show local knowledge status.”
- “Find references to `TRadIAWizard`.”
- “Read the indexed excerpt for this unit.”
- “Rebuild the index for this project.”

Search results include file, position, excerpt, total score, lexical contribution, vector
contribution, and a ranking explanation. If the embedding provider fails or is disabled under
**Settings > Security & Consent**, retrieval automatically uses the deterministic lexical fallback. Search
and document reads enforce result and payload limits.

## Storage and privacy

Snapshots are stored under `%APPDATA%\RadIA\Knowledge`, separated by a derived project identity.
Format 2 persists vectors with chunks and remains compatible with lexical format 1 snapshots. They
are not authoritative source files and may be removed to force a rebuild.

**Enable local semantic project knowledge (no network)** is disabled by default. When users enable
it under **Settings > Security & Consent**, the `local-hash-v1` provider calculates vectors entirely
inside the IDE process without HTTP, tokens, or code transmission. The preference takes effect
immediately without restarting the IDE. Disabling it stops vector calculation for new indexing and
search operations while deterministic lexical retrieval remains available.

The architecture accepts optional providers through a contract, but no remote provider is enabled
implicitly. Content is sent to an AI provider only when an authorized request includes it as context.

## Rebuild and troubleshooting

- Save the document and request a rebuild if results are stale.
- Let RadIA create a new index identity after moving a project.
- If a snapshot is corrupt, close the IDE and remove only the affected snapshot folder.
- Files outside the authorized workspace are not indexed.
- Generated files, binaries, and unsupported formats may be ignored.

See also the [agentic tools guide](user_guide_agentic_tools.en.md).
