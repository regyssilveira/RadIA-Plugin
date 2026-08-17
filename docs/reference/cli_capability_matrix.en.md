# CLI executor contractual capability matrix

> **Nature:** technical implementation and test contract. A capability declared by a CLI does not
> mean RadIA already exposes it in the UI.

## How to read it

- **CLI contract** records the vendor-published capability represented by
  `TRadIAExecutorContractCatalog`.
- **Current RadIA use** describes behavior available in the product.
- Future execution must confirm capabilities against the detected executable. An incompatible
  version produces an explicit diagnostic rather than a silent fallback.
- FIM is a completion contract separate from chat. None of the four CLIs is assumed to support FIM
  merely because it accepts model selection.

## Current matrix

| Executor | Structured output | Session ID | Stable resume | Model | MCP | Dedicated FIM | RadIA 2.17.2 use |
|---|---:|---:|---:|---:|---:|---:|---|
| Codex CLI | Yes, JSONL | Structured event | `exec resume <id>` | Yes | Yes | Not declared | New execution per message |
| Claude Code | Yes, stream JSON | Structured event | `--resume <id>` | Yes | Yes | Not declared | New execution per message |
| Gemini CLI | Yes, stream JSON | `init` event | `--resume <id>` | Yes | Yes | Not declared | New execution per message |
| GitHub Copilot CLI | Yes, JSONL | Exit hint | `--resume=<id>` | Yes | Yes | Not declared | New execution per message |

## Primary contract sources

- [Codex CLI](https://learn.chatgpt.com/docs/developer-commands?surface=cli) — JSON execution and ID resume.
- [Claude Code CLI](https://code.claude.com/docs/en/cli-usage) — structured output,
  model, MCP, and `--resume`.
- [Gemini CLI](https://geminicli.com/docs/reference/configuration/) and
  [headless mode](https://geminicli.com/docs/cli/headless/) — JSON stream, `init` event, model, and
  `--resume`.
- [GitHub Copilot CLI](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference)
  — JSONL, model, MCP, and the identifier reported after programmatic execution.

Sources describe the expected contract. The runtime probe planned for Phase 6 must compare it with
the installed version before enabling optional capabilities.

## Identities and isolation

`TRadIAAgentScopeIdentity` defines five boundaries that must not be inferred from one another:

| Identity | Purpose |
|---|---|
| Journey | Correlate one task across multiple surfaces |
| Conversation | Represent the logical history visible to the user |
| Session | Represent an agent or CLI execution |
| Project | Prevent context from crossing workspaces |
| Request | Reject late callbacks and responses |

An identity is complete only when every boundary is present. Two requests belong to the same
journey only when both `JourneyId` and `ProjectId` match.

## Measurable baseline

| Risk | Initial evidence | Future gate |
|---|---|---|
| Timeout and cancellation | External process has a timeout and Job Object termination | No child process after cancellation |
| Stale response | Provider/executor switch rejects old callbacks | Correlation also includes journey and CLI session |
| Resume | Implemented by ID for all four clients | Validate version before optional capabilities |
| Latency | Execution Center records duration | Separate startup, first event, and completion |
| FIM | Ghost Text uses general completion | Runtime probe and prefix/suffix assembly |

## Next phase

Phase 1 consumes this contract to capture IDs, persist only non-secret metadata, and build the
executor-specific resume syntax.
