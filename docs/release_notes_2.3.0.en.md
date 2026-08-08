# Release notes — RadIA 2.3.0

Status: release candidate prepared; not published yet.

## Highlights

- Internal Delphi RTK for compacting agent results without an `rtk.exe` dependency.
- `Off`, `Conservative`, and `Balanced` profiles under **General / Logs**.
- Configurable global decision-context budget.
- Complete SHA-256 artifacts with quotas, retention, and atomic writes.
- Recovery without rerunning tools through `GetToolResultSummary` and `GetToolResultRange`.
- DUnitX, Git diff, build, and knowledge rules with fail-open passthrough.
- Sanitized metrics in `/status agent` and decision snapshots.
- Built-in catalog expanded from 124 to 126 tools.

## Viability result

The compiled corpus measured 96.71% result reduction and 96.55% decision-context replay reduction,
with a 0% increase in repeated calls. Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 each
passed 892 tests with zero leaks.

See the [complete audit](result_compaction_release_audit_2.3.0.en.md).
Publication-ready numbers and methodology are available in the
[editorial benchmark](result_compaction_article_benchmark_2.3.0.md).

## Upgrade and rollback

The default is `Conservative`. Select `Off` and save to roll back; checkpoints and artifacts do not
need deletion. Old artifacts expire automatically after 14 days.
