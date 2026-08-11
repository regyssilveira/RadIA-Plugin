# Release audit 2.6.1

> **Status:** approved on August 11, 2026 for the issue #17 fix.

## Functional gates

- [x] The native Claude provider omits `temperature` from payloads sent to the Anthropic API.
- [x] The Claude tab shows the **Temperature** field disabled to avoid misleading configuration.
- [x] The settings documentation explains that Claude 5 rejects non-default sampling parameters.
- [x] The operational catalog remains synchronized with all 132 tools registered at runtime.

## Regression and quality gates

- [x] `npm run test:docs`: 38 documentation tests passed.
- [x] `build.ps1 -DelphiVersion "37.0" -Test`: build, coverage, and 1,047 tests passed.
- [x] A regression test covers the absence of `temperature` in Claude payloads.
- [x] No contract was changed for Gemini, OpenAI, Ollama, or OpenAI-compatible providers.

## Documentation gate

- [x] `settings_reference.md` and `settings_reference.en.md` describe the Claude 5 behavior.
- [x] Release notes and this audit exist in Portuguese and English.
- [x] The main hubs point to release 2.6.1.
