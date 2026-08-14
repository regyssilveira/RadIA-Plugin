# RadIA backlog

This file contains open work only. History, completed milestones, metrics, and release notes do not
belong in the backlog.

## Recovered and revalidated pending work

The items below existed before the August 12, 2026 documentation reorganization and remain open
after auditing the current code. They have no committed version; execution order must be selected
from verifiable value, effort, and dependencies.

| Area | Open outcome | Current verifiable state | Completion criterion |
|---|---|---|---|
| Existing APIs | OpenAPI/Swagger retrofit | Swagger is generated for new DEXT projects, but existing projects have no retrofit journey. | The journey inventories existing routes, prepares the specification, and applies reviewable integration without recreating the project. |
| Modernization | DEXT adoption and form decomposition | FireDAC migration and the follow-up plan exist; the tool does not execute DEXT adoption or decomposition. | A journey applies reversible steps, proves parity, and separates responsibilities without breaking DFM/PAS. |
| Concurrency | Thread and PPL assistant | Generic guidance exists, without a dedicated audit or journey for modernizing synchronous routines. | The journey detects risks, prepares safe changes, and validates VCL access, cancellation, and exception handling. |
| Productivity | Internationalization wizard | Internal localization infrastructure exists, but no wizard targets user projects. | The wizard inventories strings, prepares reviewable resources and changes, and preserves the default language. |

The DFM/Pascal audit and deterministic BDE, ADO, and dbExpress migration to FireDAC do not return to
this list because they are implemented. The modernization item records only the residual DEXT
adoption and effective form decomposition work.

The backlog does not record versions, completed deliveries, evidence, or unapproved ideas.
Long-term direction stays in the [roadmap](roadmap.en.md).
