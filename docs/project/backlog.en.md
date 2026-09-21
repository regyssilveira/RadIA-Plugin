# RadIA backlog

This file contains open work only. History, completed milestones, metrics, and release notes do not
belong in the backlog.

## Active cycle: observable agent efficiency

**Observable outcome:** explain, without sensitive content, why each run consumed decisions, tools,
time, and tokens; reduce repeated work without weakening consent, validation, or rollback.

**Ordered delivery scope:**

1. sanitized run summary with normalized stop reason and explicit unknown usage;
2. regression matrices covering valid, absent, empty, invalid, partial, repeated, and cancelled cases;
3. removal of repeated decisions, tools, and context, measured against a reproducible baseline;
4. cancellable contextual editor diagnostics without scanning the unit on every caret movement;
5. optional Message View projection while Problems remains the source of truth;
6. paired relative performance gates for duration, steps, tokens, and responsiveness;
7. sanitized, bounded, reviewable operational knowledge isolated by project;
8. a release orchestrator with `DryRun` that does not replace existing gates.

**Threats:** prompt or code leakage through metrics; false savings caused by dropping validation; stale
caret responses; OTA references surviving unload; unstable baselines; local memory treated as truth;
release automation using artifacts from another commit.

**First increment acceptance:** logs distinguish completion, approval, pause, cancellation, and every
known limit; aggregate decisions, tools, failures, repetitions, recoveries, validation, and duration;
report tokens only when supplied; tests prove that objectives, arguments, results, paths, and original
identifiers are absent.

**Validation:** DUnitX on Delphi 12 and 13, documentation tests, applicable lint, SonarQube, and a
proportional E2E scenario before each increment closes. This cycle includes no release until the
maintainer explicitly authorizes one.

New cycles must enter this file only after defining an observable outcome, scope, threats,
acceptance criteria, and validation plan.

A public extension repository or marketplace, C++Builder, Delphi 11, Lazarus, GetIt,
Embarcadero-exclusive integrations, and replacement of the current WebView remain out of scope.

## Definition of done for new items

Every new item must require:

- a documented contract and threat model before implementation;
- proven Delphi 12 and 13 support, with unavailable capabilities reported explicitly;
- unit, OTA integration, and end-to-end tests proportional to risk;
- an automated usage scenario in the regression matrix for every new behavior;
- preview, consent, fingerprint, and rollback for every mutation;
- simultaneous updates to manuals, references, hints, translations, and documentation tests;
- passing local build, DUnitX, applicable lint, and SonarQube;
- observable outcome evidence, not merely the existence of classes or tools.
