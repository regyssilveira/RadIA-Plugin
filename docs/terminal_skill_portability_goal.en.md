# Goal — skill portability and high-fidelity terminal

> **Status:** in progress on branch `feat/competitive-gap-closure`.
> **Delivery version:** determined by the public behavior actually completed.

## Objective

Eliminate the two remaining technical gaps in the complete RadIA experience:

1. publish one declarative skill in native formats for supported CLIs without manual duplication;
2. run shells, CLIs, and TUI applications in the dockable terminal with high-fidelity VT emulation.

This goal only prepares the release. Publishing, tagging, merging, or creating a release requires a
later explicit authorization.

## Official scope

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64;
- Codex, Claude Code, Gemini CLI, and GitHub Copilot CLI;
- CMD, Windows PowerShell, PowerShell 7, Git Bash, and WSL when available;
- local declarative extensions and `.radiaext` packages;
- ConPTY with a documented fallback when unavailable.

Marketplace installation, commercial signing, C++Builder, and older Delphi versions are outside
this goal.

## Milestones

| Milestone | Delivery | Status |
|---|---|---|
| M0 | Baseline, contracts, acceptance matrix, and documentation audit | Complete |
| M1 | Canonical model and CLI-specific skill adapters | Complete |
| M2 | Preview, consent, synchronization, and removal in Addon Studio | Pending |
| M3 | Real format validation and portability documentation | Pending |
| M4 | Decoupled interface and selected VT core | Pending |
| M5 | Alternate screen, colors, input, mouse, paste, OSC 8, and renderer | Pending |
| M6 | Real shell, CLI, and TUI matrix on all three targets | Pending |
| M7 | Final audit, documentation, Sonar, and release preparation | Pending |

## Skill portability contract

- The RadIA manifest is canonical; CLI files are derived replicas.
- Each adapter declares its name, format, destination, and supported capability.
- The user sees destination, files, conflicts, and impact before any write.
- The operation uses central consent and transactional writes with rollback.
- RadIA keeps an ownership manifest with hashes so it updates and removes only replicas it created.
- Manually modified files are never overwritten or removed silently.
- Credentials, tokens, unnecessary private paths, and content outside the package are not exported.
- Diagnostics distinguish missing CLI, incompatible format, conflict, divergence, and success.
- Changes are discovered without restarting Delphi.

M1 introduced the validated canonical model and four isolated adapters. They produce `SKILL.md`
with shared frontmatter and project-specific paths: `.agents/skills`, `.claude/skills`,
`.gemini/skills`, and `.github/skills`. Writes, synchronization, and visual experience belong to M2
and are not exposed to users yet.

## Terminal contract

- Transport, emulation, and rendering have independent interfaces.
- The VT core exposes no third-party types through public RadIA APIs.
- The terminal preserves current history, profiles, shared journey, consent, and cancellation.
- Alternate screen restores the primary screen on exit.
- ANSI, 256-color, and true-color modes preserve foreground, background, and attributes.
- Bracketed paste, keyboard, and mouse protocols emit sequences only when enabled by the process.
- OSC 8 exposes identifiable hyperlinks and opening remains subject to the security policy.
- Resize preserves cursor, regions, wide characters, combining marks, and explicit line breaks.
- Closing a tab, panel, or IDE leaves no child process, deadlock, or late UI access.

## Acceptance matrix

| Journey | Required evidence |
|---|---|
| Create a skill and export it to one CLI | preview, consent, valid files, and recognition without restart |
| Update a replica without conflict | previous hash, atomic replacement, and new recognition |
| Find a manually changed replica | visible divergence and preserved file |
| Remove an extension | only RadIA-owned replicas are removed |
| Open and close a TUI | restored primary screen and stopped process |
| Resize a TUI | valid layout, cursor, Unicode, and regions |
| Use paste, mouse, and hyperlink | negotiated modes, applicable consent, and no spurious input |
| Close Delphi with an active terminal | no deadlock, crash, or orphan process |

## Required gates for every milestone

1. unit tests for the changed area;
2. web and documentation tests when UI or documentation changes;
3. Delphi builds and tests proportional to the milestone;
4. SonarQube query through its REST API;
5. trailing whitespace, line-length, and Delphi literal review;
6. simultaneous update of central reference, guide, hints, and translation;
7. English commit message and push for each proven milestone.

## Completion criterion

The goal ends only when one skill can be created once and used in all four CLIs without manual
duplication, and when the terminal runs the defined matrix with fidelity and stability on all three
Delphi targets. An absence of failures does not replace positive evidence for every contract.
