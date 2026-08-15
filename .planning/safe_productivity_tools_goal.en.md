# Goal — Safe Productivity Tools

> **Status:** completed. **Baseline:** RadIA 2.12.3. **Matrix:** Delphi 12 Win32 and Delphi 13
> Win32/IDE64, including compilation of applicable Win64 targets.

## Expected outcome

RadIA must generate API documentation and test mocks without silently changing existing code. Every
output must begin as a reviewable preview, remain confined to the active project, and apply only
after explicit consent.

## Reused foundation

- structural semantic index and authorized workspace reads;
- previews, fingerprints, consent, transactional application, and reversal;
- internal tool catalog shared by chat and MCP;
- safe project file generation and registration;
- Delphi build and DUnitX runner as verifiable gates.

## Low-risk principles

1. No step overwrites existing files by default.
2. Generation and application are separate operations.
3. The preview reports paths, content, origin, and fingerprint.
4. Paths remain inside the active project root.
5. Analysis failure does not produce partial output treated as valid.
6. Users explicitly choose whether a generated file is registered in the project.
7. Reapplying the same operation does not duplicate files, declarations, or project entries.

## Milestones and gates

| Milestone | Delivery | Completion gate |
| :--- | :--- | :--- |
| M0 | contract, backlog, and architecture tests | bilingual documentation and limits protected by tests |
| M1 | public API inventory | exported public symbols include origin, signature, and visibility |
| M2 | `API.md` preview | deterministic Markdown, confined paths, and no writes |
| M3 | `API.md` application | consented creation, explicit conflicts, and verifiable reversal |
| M4 | mockable contract inventory | supported interfaces and methods with limitation diagnostics |
| M5 | mock preview | deterministic, isolated Pascal unit without automatic registration |
| M6 | optional mock application | consent, optional registration, build, and DUnitX approved |
| M7 | documentation and experience | complete bilingual catalog, guides, hints, and examples |
| M8 | final validation | Delphi 12/13, tests, Sonar, and documentation approved |

## Out of scope

- changing existing signatures or implementations;
- heuristically mocking classes without stable contracts or non-virtual methods;
- overwriting `API.md` or mock units without explicit review;
- running tests or builds without a request or previously approved gate;
- automatic review on save, Clean Uses, and other recovered backlog items.

## Completion condition

The goal ends when users can select a scope, review and create deterministic `API.md` output, and
generate compilable mocks for supported contracts, without any mutation before consent. Conflicts,
unsupported symbols, and existing files must produce actionable diagnostics while preserving the
original project.
