# Semantic intelligence in the editor

This page separates the semantic capabilities RadIA delivers today, how users invoke them, and the
boundaries that must not be confused with native Delphi features.

## Verifiable summary

| Capability | Current status | How to use it |
|---|---|---|
| Pascal/DFM semantic index | Available | RadIA starts it and semantic queries use it automatically. |
| Type context and inherited members | Available | Ask the agent to explain a type or use `/tool GetSemanticContext`. |
| Confirmed references | Available | Ask “find references to `TSymbol`” or use `/tool FindSymbolReferences`. |
| Type hierarchy | Available | Ask for ancestors or descendants or use `/tool GetTypeHierarchy`. |
| Missing interface members | Available with preview | Ask to implement missing contracts; the agent uses `PrepareMissingMembers`. |
| Local completion after `.` | Available in Ghost Text | Request Ghost Text after member access; an unambiguous continuation may be resolved locally. |
| Native CodeInsight popup | Not replaced | RadIA does not inject candidates into Delphi's native completion list. |
| Semantic refactorings | Available with preview | Ask for rename, change signature, extract method, or move type. |
| Navigate to an occurrence | Available | After a query, the agent uses `NavigateToFile` to open a file from a loaded project. |

“Available” means the capability is connected to the IDE and has dedicated tests. It does not mean
that every possible Pascal expression can be resolved. Ambiguous results are reported or use a safe
fallback; they are never presented as certainty.

## Local completion and Ghost Text

Inline assistance is different from the native CodeInsight popup:

1. RadIA captures the authorized editor context;
2. after member access such as `Form.Sa`, it queries the local index first;
3. it filters the prefix, considers inheritance, removes duplicates, and limits the list;
4. an unambiguous continuation is shown as Ghost Text without calling the provider;
5. an empty, ambiguous, or unavailable result uses the configured FIM route.

Local semantic completion therefore avoids AI calls in deterministic cases, but it does not extend
or replace the CodeInsight visual list. To enable it, open **Settings > Editor Assistance**, select
**Enable ghost text (inline completion)**, and use **Request suggestion** or its configured shortcut.
See [Inline assistance and FIM](../guides/inline_completion.en.md).

## Queries through chat or agent

Users may request each operation in natural language. The names below also support explicit `/tool`
execution and help identify consent cards and execution history.

| Goal | Suggested request | Main tool | Effect |
|---|---|---|---|
| Understand a type | “Explain `TMyClass`, including inherited members.” | `GetSemanticContext` | Read only. |
| Find usages | “Find every reference to `TMyClass`.” | `FindSymbolReferences` | Read only. |
| Inspect inheritance | “Show ancestors and descendants of `TMyClass`.” | `GetTypeHierarchy` | Read only. |
| Open an occurrence | “Open the second reference.” | `NavigateToFile` | Reversible IDE navigation. |
| Implement contracts | “Implement missing interface members in `TMyClass`.” | `PrepareMissingMembers` | Creates a preview; apply requires consent. |
| Rename a symbol | “Rename `OldName` to `NewName` with a preview.” | `PrepareRenameSymbol` | Multi-file preview and rollback. |
| Change a signature | “Add this parameter and update the calls.” | `PrepareChangeSignature` | Multi-file preview and rollback. |

Provide the unit when names are ambiguous. Candidate references are not presented as confirmed.
Comments, strings, and code disabled by conditional directives do not count as references.

## What `PrepareMissingMembers` covers

`PrepareMissingMembers` finds interface contracts that the target class has not implemented and
prepares idempotent declarations and method bodies. Preparation does not modify files. The patch is
applied only after review and consent and can be reverted.

The tool is not a generic generator for any method imagined by a model and does not replace the
compiler. Structural ambiguity, a file outside the workspace, a stale revision, or an already
satisfied contract produce distinct states instead of a silent write.

## Reproducible evidence and its scope

Public validation uses these commands from the repository root:

```powershell
npm run test:semantic-corpus:12
npm run test:semantic-corpus:13
npm run test:semantic-completion:12
npm run test:semantic-completion:13
npm run test:semantic-members:12
npm run test:semantic-members:13
```

The semantic corpus verifies parsing and exact token coverage over installed Delphi 12 and 13
RTL/VCL sources. The completion benchmark measures the local engine query by container and prefix.
It does not measure end-to-end UI, OTA capture, provider, network, or model latency. Member probes
compile language cases and VCL applications; they do not claim coverage of every third-party library.

In the baseline validated on August 16, 2026, the corpora processed 677 of 677 Delphi 12 files and
689 of 689 Delphi 13 files with exact token coverage. Queries resolved 2,000 of 2,000 sites on each
IDE with local p95 of 0.23 ms and 0.26 ms, respectively. These figures are evidence for the measured
environment, not a latency guarantee for every machine.

## Limits and diagnostics

- Delphi 12 Win32, Delphi 13 Win32, and Delphi 13 IDE64 are the supported matrix.
- Incomplete code, complex macros, unindexed external symbols, and ambiguous types may require more
  context or provider fallback.
- The semantic engine runs outside the IDE process; its unavailability must not block the editor.
- Read actions do not modify the project. Preparation creates a preview; application requires consent.
- Use `/doctor --deep` to inspect the semantic process and **Show Inline Completion Route Status** to
  understand the last Ghost Text route.

See [Internal tools](internal_tools_reference.en.md) for every tool and
[Semantic refactoring](../guides/semantic_refactoring.en.md) for transactional operations.
