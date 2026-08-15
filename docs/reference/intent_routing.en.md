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
- No prompt or decision telemetry is sent remotely. Future versions may record only sanitized,
  optional local counters.

See [Delphi journeys](../guides/user_guide_journeys.en.md) for available workflows and the
[security model](tool_security_model.en.md) for protections applied after confirmation.
