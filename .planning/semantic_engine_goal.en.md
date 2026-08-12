# RadIA 2.10.0 Goal — Structural Semantic Engine

> **Status:** in progress. **Baseline:** RadIA 2.9.0. **Matrix:** Delphi 12 Win32 and Delphi 13
> Win32/IDE64, with compilation of applicable Win64 targets.

## Expected outcome

RadIA must understand declarations, symbols, types, inheritance, interfaces, and visibility across
project units, RTL, and VCL. The engine complements CodeInsight; it does not replace it. The current
bounded context remains the fallback when the helper process is unavailable.

## Reused 2.9.0 foundation

- sanitized Delphi environment profile and basic search paths;
- shared editor context and Ghost Text;
- preview, consent, undo, rollback, and agent evidence;
- DFM/PAS audit, Delphi Mentor, and `/doctor --deep` as future consumers.

The DFM/PAS audit remains specialized. Its line-oriented parser is not treated as a general Pascal
parser or as proof of cross-unit resolution.

## Mandatory architecture

1. The engine runs outside `bds.exe` in a supervised process.
2. OTA integration captures buffers and applies edits but does not decide symbol meaning.
3. The local protocol is versioned and supports cancellation, timeout, and controlled restart.
4. Tokens and nodes preserve offsets from the original buffer.
5. Unresolved conditions are diagnosed; the engine never silently chooses a branch.
6. Every mutation uses preview, consent, and optimistic buffer validation.

## Stages and gates

| Milestone | Delivery | Completion gate |
| :--- | :--- | :--- |
| M0 | contract, protocol, metrics, and planning | bilingual backlog and documentation approved |
| M1 | effective Delphi 12/13 profile | reproducible defines, scopes, includes, library and search paths |
| M2 | external process, lexer, and preprocessor | isolated crash, cancellation, and exact corpus offsets |
| M3 | structural parser | modern declarations and partial errors without silent unit loss |
| M4 | incremental index | project, group, RTL, and VCL queries with per-unit invalidation |
| M5 | implement missing members | idempotent preview, single undo, and Delphi 12/13 compilation |
| M6 | existing consumers | agent, navigation, Ghost Text, and DFM/PAS use the index with fallback |
| M7 | resolved completion and diagnostics | cancellable local response and actionable `/doctor --deep` |
| M8 | release candidate | matrix, DUnitX, corpus, Sonar, installer, and documentation approved |

## Minimum metrics

- no engine failure crashes or blocks the IDE;
- 100% of corpus tokens preserve coverage and offsets of the original text;
- at least 99% of supported RTL/VCL units parse without a fatal structural error;
- warmed symbol and member queries target at most 50 ms;
- the missing-member action is idempotent and generates compilable code on both Delphis;
- a corrupt cache is discarded and rebuilt without manual intervention.

## Out of scope

- Delphi 11, C++, Lazarus, and DCU reading;
- full replacement of CodeInsight;
- a complete type checker or deep interpretation of every routine body;
- universal refactorings and marketplace work.

## Completion condition

The goal completes only when a user can index a real project, navigate and complete with structural
resolution, implement a missing interface with compilable code, and diagnose the engine on Delphi
12 and 13. Build, tests, corpus, Sonar, documentation, and installation must produce reproducible
evidence.
