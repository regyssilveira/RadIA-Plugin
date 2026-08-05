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

Search results and document chunks show an **Open source** action in chat. It uses `NavigateToFile`
to open the file at the first line of the excerpt. Navigation is read-only and remains subject to
the active workspace boundary and the normal tool policy.

The tools also expose local metrics without telemetry: indexing and search report `durationMs`,
each result retains its relevance scores, and `GetKnowledgeStatus` reports
`estimatedIndexBytes`. Every response includes the project identifier so workspace isolation can
be verified. The size is an estimate of indexed content, metadata, and vectors in memory, not the
exact persisted JSON file size.

## Storage and privacy

Snapshots are stored under `%APPDATA%\RadIA\Knowledge`, separated by a derived project identity.
Format 2 persists vectors with chunks and remains compatible with lexical format 1 snapshots. They
are not authoritative source files and may be removed to force a rebuild.

**Enable local semantic project knowledge (no network)** is disabled by default. When users enable
it under **Settings > Security & Consent**, the `local-hash-v1` provider calculates vectors entirely
inside the IDE process without HTTP, tokens, or code transmission. The preference takes effect
immediately without restarting the IDE. Disabling it stops vector calculation for new indexing and
search operations while deterministic lexical retrieval remains available.

**Knowledge excluded file fragments** and **Knowledge excluded project name or path fragments**
accept semicolon-separated items. Matching is case-insensitive and searches the complete path. A
new exclusion immediately blocks search and document reads for content already indexed. The next
refresh also removes matching files from the persisted snapshot. Removing a pattern allows content
to be indexed again.

The architecture accepts optional providers through a contract, but no remote provider is enabled
implicitly. Content is sent to an AI provider only when an authorized request includes it as context.

## Rebuild and troubleshooting

- Save the document and request a rebuild if results are stale.
- Let RadIA create a new index identity after moving a project.
- If a snapshot is corrupt, close the IDE and remove only the affected snapshot folder.
- Files outside the authorized workspace are not indexed.
- Use exclusions for generated folders, third-party code, or projects that must not enter the index.
- Generated files, binaries, and unsupported formats may be ignored.

See also the [agentic tools guide](user_guide_agentic_tools.en.md).
