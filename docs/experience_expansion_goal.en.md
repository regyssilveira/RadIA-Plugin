# Goal — expand RadIA's complete experience

> **Status:** complete and integrated into the product.
> **Scope:** Delphi 12 Win32 and Delphi 13 Win32/IDE64.
> **Out of scope:** C++Builder, marketplace, mandatory Authenticode signing, generic desktop
> automation, and replacement of the current WebView2 host.

## Objective

Turn already proven technical capabilities into a continuous, visible, and shareable experience.
Users should be able to follow agent activity, distribute knowledge and automation safely, and
understand every control without reading source code.

## Milestones

| Milestone | Delivery | Status |
|---|---|---|
| M1 | Panel with up to three completion alternatives, visual navigation, and configurable shortcuts | Complete and approved in the final integrated matrix |
| M2 | `.radiaext` references, knowledge, templates, and assets, including Addon Studio and rollback | Complete and approved in the final integrated matrix |
| M3 | Visual chat session with before/after captures, timeline, and validation driven by real events | Complete; real capture passed on all three supported targets |
| M4 | Consent resilient across surfaces with a consistent visual presentation | Complete; central dialog, bounded queue, redaction, and matrix approved |
| M5 | Advanced terminal matrix for Unicode, wide characters, reflow, and TUI applications | Complete; 1,013 tests on all three targets and Sonar approved |
| M6 | Incremental refinement of the current WebView without replacing its architecture | Complete; queue, 280–1,000 px layout, three targets, and Sonar approved |
| M7 | Complete documentation audit and Delphi 12/13 gate | Complete; documentation, matrix, and Sonar approved |

## Final M7 evidence

- 184 tracked Markdown documents in 92 complete pt-BR/en-US pairs;
- task navigation proven for every operational guide, with ADRs, plans, audits, and historical
  records kept outside the primary user flow;
- valid repository-relative local links, with no `file:///`, mojibake, or forbidden product
  references;
- 132/132 tools with purpose and activation guidance, every native command documented, and model
  fallbacks automatically synchronized with `RadIA.Core.Types.pas`;
- 83/83 Web and documentation tests plus a clean ESLint run;
- 1,013/1,013 tests on Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64, with no failures,
  errors, ignored tests, or leaks;
- SonarQube Quality Gate `OK`, 82.7% coverage, 1.7% duplication, and zero issues, bugs,
  vulnerabilities, hotspots, or code smells.

## Required contracts

- Animations cannot imply fake activity; the interface responds only to real events.
- Visual automation remains limited to the process started by the current debugger session.
- Captures are sanitized, have bounded retention, and never enter textual logs.
- An extension manifest and its resources install, update, and uninstall as one unit.
- Consent cannot become inaccessible because the chat, terminal, or panel was closed.
- Every visual action has a keyboard or command equivalent when applicable.
- Every visible change updates the central reference, guide, hints, translation, and documentation tests.
- Each milestone closes with tests, SonarQube, commit, and push; completion requires the full matrix.

## Definition of done

The goal ends only when every milestone is implemented, documented, and approved on Delphi 12
Win32, Delphi 13 Win32, and Delphi 13 IDE64, without regressions, leaks, Sonar issues, or guidance
that requires reading a roadmap or commit history to discover product behavior.
