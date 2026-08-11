# Release notes — RadIA 2.6.1

> **Status:** prepared on August 11, 2026 to fix issue #17.

RadIA 2.6.1 is a patch release focused on the Anthropic Claude provider. It removes sampling
parameters that are incompatible with Claude 5 models and aligns the settings screen with the real
API behavior.

## Fixes

- the native Claude provider no longer sends `temperature` in the API payload;
- the **Temperature** field on the Claude tab is now disabled as a legacy local value;
- the settings reference documents that Claude 5 does not receive `temperature`, `top_p`, or `top_k`;
- a regression test ensures Claude payloads do not include `temperature`.

## Compatibility

- Delphi 13 validated with build, coverage, and tests;
- operational catalog preserved with 132 tools;
- other providers are unchanged.

## Release validation

- `npm run test:docs`: 38 tests passed;
- `build.ps1 -DelphiVersion "37.0" -Test`: 1,039 instrumented tests and 8 external-process tests
  passed, totaling 1,047 tests.
