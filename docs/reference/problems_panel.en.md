# Problems panel

The **Problems** panel gathers findings produced by RadIA tools in one list. Users do not need to
search long responses or know each internal tool name to find actionable diagnostics.

## When it is populated

The panel updates after a tool succeeds and returns an actionable finding. The currently normalized
sources are:

| Area | Example sources |
|---|---|
| Build | structured compiler errors, warnings, and messages |
| Tests | DUnitX cases whose state is `failed` or `error` |
| Coverage | diagnostics produced by coverage tools |
| Memory | FastMM5 events and leaks |
| DFM/PAS | inconsistencies among forms, components, events, and Pascal units |
| Threading | unsafe VCL access, cancellation, and exception handling |
| Review | static-analysis and code-review findings |
| General | risks and diagnostics outside the previous areas |

Passing DUnitX cases are not reported as problems. Repeated findings use a deterministic identifier
and update without duplicating the list. Each tool response is limited to 200 problems to keep the UI
responsive.

## How to use it

1. Select **Problems** in the chat header. Its badge reports the number of collected findings.
2. Filter by **Severity** or **Area** to narrow the list.
3. Select **Open source** when a finding includes a file. RadIA requests navigation through the safe
   IDE contract and validates that the file belongs to the open project.
4. Select **Review action** to place the recommended journey or command in the message field. The
   action remains visible for review and never runs automatically.
5. Select **Clear** to discard only the findings collected in the current chat.

The panel is a sidebar in wide windows and an overlay at smaller widths. Closing it preserves the
findings. Clearing the conversation or changing sessions clears the collection associated with the
previous conversation.

## Severities

| Severity | Meaning |
|---|---|
| Critical | a state that prevents safe progress, such as a fatal compiler message |
| Error | a confirmed failure, failed test, or leak |
| Warning | a risk or condition that deserves review |
| Information | a useful diagnostic without a confirmed failure |

The panel does not modify code, start a build, or grant consent on the user's behalf. Navigation
remains subject to tool policy; recommended commands are only prepared in the composer.

## Unified Delphi code validation

Ask RadIA to validate the active unit or project to invoke `ValidateDelphiCode`. The result separates
sources so missing configuration is never confused with a code defect:

- **RadIA native:** deterministic local rules with no network access;
- **Compiler:** messages already available in the IDE; use `buildBeforeValidation: true` to run a
  native **Check** before collecting them. The default is `false`, so old messages are never presented
  as evidence from a recent build;
- **DelphiLint:** detects the installation under `%APPDATA%\DelphiLint`, honors `delphilint.ini`
  overrides, locates Java through the override, `JAVA_HOME`, or `PATH`, and runs the server in an
  isolated process. The adapter consumes the real structured response, stops the process afterward,
  and does not reference the external BPL;
- **Sonar:** discovers the URL and project key from explicit arguments, environment variables,
  `sonar-project.properties`, or `.scannerwork/report-task.txt`, then queries `api/issues/search`.
  The token is sent only when `SONAR_HOST_URL` matches the effective URL, preventing credential
  forwarding to another host.

The default limit is 200 findings and the configurable maximum is 500. Each item preserves source,
rule, severity, message, file, line, and column and enters the panel under **Review**.
When DelphiLint provides a fix, the result includes a temporary identifier.
`PrepareCodeValidationFix` turns it into a preview against current content; only `ApplyPatch`, after
consent, changes the file. Later edits, expiration, invalid ranges, or overlap block the flow and
require another validation.
