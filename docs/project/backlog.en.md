# RadIA backlog

This file contains open work only. History, completed milestones, metrics, and release notes do not
belong in the backlog.

## Current status

There is no active goal or approved open item in the public backlog.

The deterministic integration and end-to-end platform previously recorded as pending is complete.
The mandatory `Test-RadIA.ReleaseUsage.ps1` gate brings together the Delphi 12 and 13 DUnitX suites,
registered integration and usage scenarios, the calculator, project generation and opening, and the
automated matrix on all three supported targets. Its current contract is documented in the
[automated usage test matrix](../development/usage_test_matrix.en.md).

New proposals enter this file only after they are approved as executable work with an observable
outcome and acceptance criteria. Ideas that have not been approved are not presented as product
commitments.

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
