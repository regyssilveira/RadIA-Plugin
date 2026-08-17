# RadIA backlog

This file contains open work only. History, completed milestones, metrics, and release notes do not
belong in the backlog.

## Current state

There is no active engineering item in this backlog. FireDAC Advisor completed its functional and
security contract, bilingual documentation, Delphi 12 and 13 builds, unit and integration tests,
and the 16-scenario E2E matrix on all three supported targets. Its public surface and usage are
recorded in the product references and guide.

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
