# Deterministic competitive closure 2.7

This document freezes the criteria used to close the functional differences in the 2.7 line. An
approved capability cannot be reopened by opinion, renaming, or a new comparison. Reopening an item
requires a reproducible RadIA regression or a formally versioned new baseline.

## Frozen baseline

- RadIA: version 2.6.2, commit `1b2dd78`;
- CLI/IDE reference: commit `9e4416f`;
- extension reference: commit `26698ff`;
- knowledge reference: commit `f8b8f5d`;
- IDE-integrated reference: public documentation captured on August 11, 2026.

External reference names are deliberately omitted from product documentation. The commits and date
make the comparison reproducible without turning competitors into RadIA dependencies or operational
content.

## Permanent exclusions

- C++ and Lazarus;
- marketplace, signing, and commercial installation;
- replacement of the current WebView;
- mandatory CLI bundling;
- features exclusive to the IDE vendor.

These points are explicit product decisions and must never return as gaps in this baseline.

## Closed matrix

| ID | Requirement | Status | Required evidence |
|---|---|---|---|
| CC-01 | Generated projects | Passed | Delphi 12/13, 11 projects, and 5/5 tests |
| CC-02 | Prompt per template | Passed | PT/EN matrix through the real conversation |
| CC-03 | Intent and IDE view | Passed | Design, Code, error, and cancellation smoke |
| CC-04 | Review comment | Passed | Audited feedback without mutation |

## Approval rule

An item changes to **Passed** only when the same scope has:

1. current implementation;
2. unit tests;
3. integration tests;
4. a real IDE smoke when OTA or UI is involved;
5. evidence bound to a clean tracked commit;
6. Portuguese and English documentation;
7. a passing Quality Gate.

The release can close only with `open=0`, `failed=0`, and `unverified=0` in
`competitive_closure_baseline_2.7.json`.

## CC-01 evidence

The
[generated_project_templates_evidence_2.6.2.json](generated_project_templates_evidence_2.6.2.json)
matrix was produced from commit `58faee7` with `sourceDirty=false`. Delphi 12 and Delphi 13 built all
11 projects, exercised the calculator, and passed all five DUnitX tests with no failures, errors,
ignored tests, or leaks.

## CC-02 evidence

The [natural_project_prompts_evidence_2.7.0.json](natural_project_prompts_evidence_2.7.0.json) matrix
was produced from commit `5d217aa` with `sourceDirty=false`. All seven templates were requested with
natural Portuguese and English prompts through the real conversation, for 14 passing scenarios on
Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64.

## CC-03 evidence

The [ide_intent_navigation_evidence_2.7.0.json](ide_intent_navigation_evidence_2.7.0.json) matrix was
produced from commit `4604508` with `sourceDirty=false`. In a real IDE, all three targets mapped
intents to Design and Code, rejected an invalid intent, cancelled without execution, and shut down
without leaving MCP discovery active.

## CC-04 evidence

The [block_review_feedback_evidence_2.7.0.json](block_review_feedback_evidence_2.7.0.json) matrix was
produced from commit `2a13819` with `sourceDirty=false`. On all three real targets, review stored the
comment, exposed `changes-requested`, remained pending, did not mutate the buffer, and shut down the
IDE without leaving MCP discovery active.
