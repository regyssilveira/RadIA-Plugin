# Curated Delphi guidance

RadIA includes a local, versioned Delphi rule catalog that complements the agent context with safeguards
applicable to the active IDE version, framework, and architecture. Rules are read-only, perform no
external requests, and use stable citations in the form
`[radia-delphi:<identifier>@<schema-version>]`.

## Usage

The chat service automatically appends up to six compatible rules to the system prompt. To query the
catalog directly, run:

```text
/tool GetDelphiGuidance
```

The tool accepts the optional `version`, `framework`, `architecture`, `topic`, and `id` filters.
`maxCount` limits the result to between 1 and 50 rules. Empty values and `any` do not restrict a query.

```json
{
  "version": "13",
  "framework": "vcl",
  "architecture": "ide64",
  "topic": "threads",
  "maxCount": 10
}
```

## Initial coverage

The catalog covers string indexing, object lifetime, threaded UI access, component ownership, FMX
platform services, Delphi 12 and 13 compatibility, IDE64 pointer safety, DFM and Pascal consistency,
imports, and parameter limits.

## Versioning, order, and precedence

- `schemaVersion` defines each rule contract; the initial version is `1`.
- Applicable rules are sorted by descending priority and then by identifier.
- An `id` query selects exactly one compatible rule.
- Version-, framework-, or architecture-specific rules complement general rules.
- The built-in catalog is authoritative in this version. Organization extensions are not loaded yet and
  must not reuse the built-in citation namespace.

When a rule affects an answer, the agent must preserve its citation. The citation identifies the rule and
contract version without exposing local paths.

## Recovery

If no rule is returned, inspect the selectors with `GetDelphiEnvironmentProfile` and repeat the query
without `topic` or `id`. A profile-building failure does not interrupt chat: the additional guidance is
omitted and the service records the event in its log.
