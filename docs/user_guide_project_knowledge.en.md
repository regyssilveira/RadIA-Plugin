# Local project knowledge guide

## Purpose

Local knowledge lets RadIA search project symbols and excerpts without depending on an external
service. The index is derived from the workspace, can be rebuilt, and combines lexical retrieval
with local vector similarity.

Indexed formats include Pascal (`.pas`, `.dpr`, `.dpk`, `.inc`), text forms (`.dfm`, `.fmx`),
projects (`.dproj`, `.groupproj`), and documentation (`.md`, `.txt`, `.adoc`, `.rst`). Form
companions are discovered with their units. Documentation is discovered at the root and under
`docs` and `doc`, including nested folders. Binary DFM data is never interpreted as text and is
safely skipped.

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

### Optional remote embeddings

Under **Settings > Security & Consent**, users can configure an OpenAI-compatible embedding
endpoint. Activation requires all of the following:

- **Use a remote OpenAI-compatible embedding provider**;
- **I consent to sending bounded project text to this endpoint**;
- an HTTPS endpoint, or HTTP only on `localhost`, `127.0.0.1`, or `::1`;
- a valid model, dimensions, timeout, and input limit.

Remote consent is independent from semantic search. Enabling **Enable local semantic project
knowledge** alone never authorizes network traffic. Without consent, when remote use is disabled,
or when settings are invalid, `local-hash-v1` remains active. Windows DPAPI protects the API key,
the key never enters JSON, and the transport does not follow redirects. The input limit bounds each
submitted excerpt; network failures preserve deterministic lexical fallback.

When the provider, model, dimensions, or semantic-search setting changes, RadIA detects
incompatible vectors and automatically rebuilds the affected files. **Rebuild knowledge** remains
available when the user requests a complete rebuild.

## Rebuild and troubleshooting

- Save the document and request a rebuild if results are stale.
- Let RadIA create a new index identity after moving a project.
- If a snapshot is corrupt, close the IDE and remove only the affected snapshot folder.
- Files outside the authorized workspace are not indexed.
- Use exclusions for generated folders, third-party code, or projects that must not enter the index.
- Generated files, binaries, and unsupported formats may be ignored.
- Discovery is limited to 5,000 files and every file is limited to 2 MiB.

See also the [agentic tools guide](user_guide_agentic_tools.en.md).
The reproducible validation across all three supported IDE targets is recorded in
[`knowledge_smoke_evidence_2.0.0.json`](knowledge_smoke_evidence_2.0.0.json).

## Approved agent run memory

**Include approved agent run summaries in local project knowledge** is disabled by default. When
enabled, it adds only summaries of runs that belong to the current project, had a user-approved
plan, and completed successfully.

The virtual document contains the objective, status, step count, and update time. Tool arguments,
results, and payloads are never copied. Runs from another project never enter the current index.
Disabling the option blocks persisted results immediately; the next refresh removes them physically.
