# Impact-based DUnitX tests

During development, RadIA can calculate and run the smallest DUnitX fixture set it can safely justify.
This shortens feedback. The release gate still runs complete suites on both compilers, while localized
E2E journeys use the usage matrix `targeted` profile.

## How selection works

`PlanImpactedDUnitXTests` accepts changed files, optional symbols, and an optional coverage report. It
builds the transitive `uses` graph, discovers fixtures registered through `RegisterTestFixture`, and
explains why each fixture was selected.

The result reports `selected` or `full` run mode and high, medium, or `fallback-full-suite` confidence.
Coverage raises confidence only when every changed unit appears in the report. Coverage does not map
individual tests to lines; the dependency graph remains responsible for fixture selection.

`RunImpactedDUnitXTests` creates the same plan and passes its fixture filters to the existing DUnitX
runner. An empty filter list means the complete suite, never no tests.

## Safety fallbacks

RadIA runs the complete suite for unknown file types, changes without a matching unit, missing affected
fixtures, a coverage report that omits a changed unit, more than 100 filters, or more than 2,000 Pascal
files. Files and reports outside the workspace are rejected.

Use impact selection for fast development feedback. Every release still runs the complete Delphi 12 and
13 suites and the critical E2E set. Use full regression under the conditions documented in
[Automated usage test matrix](../development/usage_test_matrix.en.md).
