# RadIA backlog

This file contains open work only. History, completed-version metrics, and release notes do not
belong in the backlog.

## In progress — structural semantic engine

| Milestone | Verifiable outcome | Status |
|---|---|---|
| Delphi profile | active-configuration defines, scopes, includes, and paths | Complete |
| Process and lexical analysis | isolated process, protocol, supervision, lexer, and preprocessor | Complete |
| Structural parser | modern declarations, partial recovery, and RTL/VCL corpus | Completed |
| Incremental index | queryable project, group, RTL, and VCL with per-unit invalidation | Pending |
| Missing members | idempotent preview, consent, undo, and compilation | Pending |
| Consumers | agent, navigation, Ghost Text, and DFM/PAS use the index with fallback | Pending |
| Completion and diagnostics | cancellable local response, metrics, and `/doctor --deep` | Pending |
| Release candidate | Delphi 12/13, tests, Sonar, installer, and documentation | Pending |

The detailed engineering contract lives in
[`.planning/semantic_engine_goal.en.md`](../../.planning/semantic_engine_goal.en.md), outside user
documentation.

## No committed version

| Area | Items |
|---|---|
| Code assistance | review on save; Clean Uses; mock generator |
| Diagnostics | cross-unit trace; MadExcept/EurekaLog importers |
| APIs | OpenAPI/Swagger retrofit for existing projects |
| Modernization | residual DEXT migration; guided form decomposition |
| Operation | cache panel; threads/PPL assistant |
| Productivity | internationalization wizard; API documentation generation |

These items are opportunities, not promises. Lazarus, C++, Delphi 11, and marketplace work remain
outside the current scope.
