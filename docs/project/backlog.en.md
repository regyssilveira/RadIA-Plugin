# RadIA backlog

This file contains open work only. History, completed milestones, metrics, and release notes do not
belong in the backlog.

## In progress

No approved item is in progress. New items must state an open outcome and a verifiable completion
criterion before work begins.

## Recovered and revalidated pending work

The items below existed before the August 12, 2026 documentation reorganization and remain open
after auditing the current code. They have no committed version; execution order must be selected
from verifiable value, effort, and dependencies.

| Area | Open outcome | Current verifiable state | Completion criterion |
|---|---|---|---|
| Code assistance | Automatic review on save | The save event exists, but there is no dedicated background review flow. | Users can enable review, receive findings without blocking the IDE, and review or discard the result. |
| Code assistance | Clean Uses | No dedicated analyzer detects and safely prepares removal of unused units. | A preview accounts for symbols, conditionals, and project scopes, applies with consent, and preserves the build. |
| Testing | Mock generator | The test suite contains internal mocks, but no journey generates mocks for user projects. | The journey generates doubles compatible with selected interfaces or classes and produces compilable tests. |
| Diagnostics | Cross-unit traces and MadExcept/EurekaLog importers | `/stacktrace` analyzes text with the active unit; it has no structural cross-unit correlation or dedicated importer. | Diagnostics import supported formats, resolve project frames, and show navigation and confidence per frame. |
| Existing APIs | OpenAPI/Swagger retrofit | Swagger is generated for new DEXT projects, but existing projects have no retrofit journey. | The journey inventories existing routes, prepares the specification, and applies reviewable integration without recreating the project. |
| Modernization | DEXT adoption and form decomposition | FireDAC migration and the follow-up plan exist; the tool does not execute DEXT adoption or decomposition. | A journey applies reversible steps, proves parity, and separates responsibilities without breaking DFM/PAS. |
| Operations | Cache management panel | Cache infrastructure exists, but there is no dedicated visual experience for inspection and selective cleanup. | The panel shows usage and origin, supports confined cleanup, and explains what will be rebuilt. |
| Concurrency | Thread and PPL assistant | Generic guidance exists, without a dedicated audit or journey for modernizing synchronous routines. | The journey detects risks, prepares safe changes, and validates VCL access, cancellation, and exception handling. |
| Productivity | Internationalization wizard | Internal localization infrastructure exists, but no wizard targets user projects. | The wizard inventories strings, prepares reviewable resources and changes, and preserves the default language. |
| Documentation | `API.md` generation | No dedicated generator exists in the runtime catalog. | The tool generates reproducible documentation from the public API and updates only authorized content. |

The DFM/Pascal audit and deterministic BDE, ADO, and dbExpress migration to FireDAC do not return to
this list because they are implemented. The modernization item records only the residual DEXT
adoption and effective form decomposition work.

The backlog does not record versions, completed deliveries, evidence, or unapproved ideas.
Long-term direction stays in the [roadmap](roadmap.en.md).
