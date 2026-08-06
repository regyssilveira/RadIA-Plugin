# M4 — Diagnose, fix, and replay

## Delivery

`/journey debug` now explicitly guides the complete cycle: build, start debugging, prepare and
authorize a runtime scenario, reproduce the failure, capture evidence, review the correction,
rebuild, replay the same scenario, and compare both results.

Two tools close the evidence trail:

- `CaptureRuntimeEvidence` records session, project, executable, build, scenario result, last
  correlated event, call stack, and up to ten expressions;
- `CompareRuntimeEvidence` requires failure and verification evidence from the same project but
  different sessions and builds.

Evidence receives an opaque identifier, a SHA-256 fingerprint, and sensitive-data redaction.
It remains in memory at this milestone. Versioned persistence and ten-cycle replay belong to M5.

## Comparison rule

The `fixed` outcome is emitted only when:

1. the first record has the `failure` phase and contains an exception;
2. the second record has the `verification` phase;
3. both use the same project but different sessions and builds;
4. the verification scenario succeeds;
5. verification contains no new exception.

When these preconditions are not met, the outcome is `notComparable`; when they are met but the
failure remains, the outcome is `stillFailing`.

## Security and consent

- capture and comparison are read-only;
- every scenario execution still requires consent;
- correction still uses preview and consent through the existing patch tools;
- no evidence reads password fields, and expression results pass through the secret redactor;
- comparison never applies or approves a change automatically.

## Automated evidence

- verifiable catalog with 106 tools;
- tests for sanitized capture, stack, expressions, and cross-build comparison;
- test for access to the last correlated event;
- evidence integration into the agent validation snapshot;
- Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64: 798/798 tests per target, with no failures,
  errors, ignored tests, or leaks;
- SonarQube: approved quality gate, 82.3% new-code coverage, 0.99504% new-code duplication, and
  zero issues; global metrics report 82.7% coverage, 2.1% duplication, and A ratings.

## Acceptance pending

The M4 contract and orchestration are implemented. Operational acceptance still requires running
the laboratory in each real host — Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 —,
applying a reviewed correction, and obtaining `fixed` by replaying the exact same scenario.

After that acceptance, M5 versions the regression, runs ten cycles per target, and closes the gate.
