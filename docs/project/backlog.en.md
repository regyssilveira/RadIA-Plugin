# RadIA backlog

This file contains open work only. History, completed milestones, metrics, and release notes do not
belong in the backlog.

## Active goal: deterministic Delphi experience closure

Close every actionable difference in the current experience with reproducible evidence, reusing
existing capabilities before implementing any new infrastructure.

- [ ] prove semantic-engine isolation, recovery, and metrics;
- [ ] close every workstream in the same ledger, commit, and integrated gate.

The scope excludes a public extension repository or marketplace, C++Builder, Delphi 11, Lazarus,
GetIt, Embarcadero-exclusive integrations, and replacement of the current WebView.

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
