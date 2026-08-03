# Local project knowledge guide

## Purpose

Local knowledge lets RadIA search project symbols and excerpts without depending on an external
service. The index is derived from the workspace and can be rebuilt.

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

Search and document reads enforce result and payload limits.

## Storage and privacy

Snapshots are stored under `%APPDATA%\RadIA\Knowledge`, separated by a derived project identity.
They are not authoritative source files and may be removed to force a rebuild.

The index remains local. Content is sent to a provider only when an authorized request includes it
as context.

## Rebuild and troubleshooting

- Save the document and request a rebuild if results are stale.
- Let RadIA create a new index identity after moving a project.
- If a snapshot is corrupt, close the IDE and remove only the affected snapshot folder.
- Files outside the authorized workspace are not indexed.
- Generated files, binaries, and unsupported formats may be ignored.

See also the [agentic tools guide](user_guide_agentic_tools.en.md).
