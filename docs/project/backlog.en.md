# RadIA backlog

This file contains open work only. History, completed milestones, metrics, and release notes do not
belong in the backlog.

The backlog does not record versions, completed deliveries, evidence, or internal plans.

## Active goal: complete and deterministic Delphi experience

Turn common Delphi developer objectives into simple, safe, and verifiable flows, reusing existing
tools before expanding the catalog.

The only open workstream is consolidation of the automated usage platform. Internal engineering
plans remain separate from public documentation.

## Cross-cutting foundation — automated usage tests

- [ ] **Integration and end-to-end platform:** automate isolated installation, Delphi startup,
  sanitized configuration, chat, tools, editor, Designer, build, tests, debugger, terminal, consent,
  and failure recovery on Delphi 12 and 13 targets.

The platform must have three layers:

1. service and adapter integration without opening the IDE;
2. OTA integration loaded into a disposable Delphi instance;
3. end-to-end user journeys with fixture projects, real actions, and verifiable evidence.

Gate: a clean run must install RadIA in an isolated environment, open every supported IDE, execute
the critical matrix, collect logs, screenshots, and structured results, and restore the environment
without human intervention. Failures must identify the stage, IDE version, and diagnostic artifact
without exposing credentials.

This gate is mandatory for every release. Publication must run, through the same command and without
skip options, the complete integration and end-to-end suite, calculator creation plus its functional
and DUnitX tests, and immediate project creation, opening, and navigation. A missing, skipped, or
failed group blocks the release.

## Definition of done

Each item requires:

- a documented contract and threat model before implementation;
- proven Delphi 12 and 13 support, with unavailable capabilities reported explicitly;
- unit, OTA integration, and end-to-end tests proportional to risk;
- an automated usage scenario in the regression matrix for every new behavior;
- preview, consent, fingerprint, and rollback for every mutation;
- simultaneous updates to manuals, references, hints, translations, and documentation tests;
- passing local build, DUnitX, applicable lint, and SonarQube;
- observable outcome evidence, not merely the existence of classes or tools.
