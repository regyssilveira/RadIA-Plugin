# Goal — expand RadIA's complete experience

> **Status:** active on `feat/competitive-gap-closure`.
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
| M1 | Panel with up to three completion alternatives, visual navigation, and configurable shortcuts | Complete; final integrated matrix pending |
| M2 | `.radiaext` references, knowledge, templates, and assets, including Addon Studio and rollback | Completed; integrated final matrix pending |
| M3 | Visual chat session with before/after captures, timeline, and validation driven by real events | Pending |
| M4 | Consent resilient across surfaces with a consistent visual presentation | Pending |
| M5 | Advanced terminal matrix for Unicode, wide characters, reflow, and TUI applications | Pending |
| M6 | Incremental refinement of the current WebView without replacing its architecture | Pending |
| M7 | Complete documentation audit and Delphi 12/13 gate | Continuous work in progress; final gate pending |

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
