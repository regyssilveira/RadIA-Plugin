# Intent routing

RadIA uses a local deterministic classifier to recognize common objectives without sending text to
another service or executing tools. Its initial coverage recommends journeys for:

- creating a complete Delphi project;
- diagnosing and repairing a build failure;
- running and interpreting tests;
- reproducing and diagnosing a runtime failure.

The result includes intent, confidence (`high` or `medium`), route, command, and explanation. It is
displayed as a recommendation, never as authorization. The user chooses among:

1. **Use recommended route:** confirms the command stored by the host;
2. **Review command:** copies the command to the composer, where it can be changed;
3. **Continue as chat:** discards the recommendation and uses the current conversation route.

A new prompt invalidates the previous recommendation. The WebView cannot select another command
during confirmation: the host accepts only the pending command it classified. Slash commands,
ordinary questions, and ambiguous requests are not intercepted.

## Bounds and security

- Classification does not enable Agent mode, switch provider or executor, or start a tool.
- User text remains subject to journey bounds and validation after confirmation.
- Plan review, consent, workspace boundary, fingerprint, and rollback remain mandatory.
- Confidence describes only the intent match. It does not prove that the action will succeed or
  replace prerequisite diagnostics.
- No prompt or decision telemetry is sent remotely.

## Local counters and privacy

RadIA records only five routing decisions locally: `recommended`, `accepted`, `reviewed`,
`chat-fallback`, and `superseded`. Each line contains the UTC date, intent name, and confidence
level. The recording API does not accept prompts, code, commands, projects, providers, models,
credentials, or responses. Intent and confidence use allowlists; unknown values become `Unknown`
instead of being persisted literally.

The file is `%LOCALAPPDATA%\RadIA\Telemetry\intent-routing.jsonl` and resets when it reaches 1 MiB.
A read or write failure never blocks chat. Use `/status intent` to inspect only sanitized aggregate
counters. To reset them, close Delphi and delete this file; it is recreated after a new
recommendation.

The automated matrix exercises sixteen natural Portuguese and English requests across project
creation, build repair, tests, and diagnostics. Educational or ambiguous questions remain in chat.
These tests execute the real Pascal classifier in the Delphi 12 and 13 DUnitX suites and belong to
the indivisible release gate.

See [Delphi journeys](../guides/user_guide_journeys.en.md) for available workflows and the
[security model](tool_security_model.en.md) for protections applied after confirmation.
