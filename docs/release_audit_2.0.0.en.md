# Release 2.0.0 audit

This audit records reproducible security, privacy, accessibility, and documentation gates for the
RadIA 2.0.0 candidate. It complements but does not replace real IDE cycles.

| Area | Verified control | Automated evidence | Status |
|---|---|---|---|
| Security | Consent, confinement, sanitization, protected credentials, and signed extensions | DUnitX suite and [Sonar evidence](sonar_quality_evidence_2.0.0.json) | Passed |
| Privacy | Web surfaces initiate no external connection; remote providers remain explicit | `npm run test:web` | Passed |
| Accessibility | Accessible names, live regions, ARIA state, visible focus, and keyboard activation | `npm run test:web` | Passed |
| Documentation | Existing local links and no common mojibake markers | `npm run test:docs` | Passed |

## Audit fixes

- Removed automatic Google-hosted Inter font loading during chat startup.
- Added semantic conversation, status, error, and selection regions to chat and diff views.
- Added accessible names to icon-only buttons.
- Synchronized ARIA state for Agent Mode, sessions, providers, models, and diff review.
- Added keyboard activation, Escape handling, and visible focus to custom selectors.
- The documentation audit scans README and every Markdown file under `docs` and fails on missing local links or
  common mojibake markers.
- The global Sonar gate fails on any issue, rating below A, coverage below 80%, or duplication above
  3%. Current evidence records zero issues, 82.3% coverage, and 2.3% duplication.
- The native terminal opened with controls, input, output, and nine keyboard tab stops in all four
  combinations, as recorded in
  [`terminal_smoke_evidence_2.0.0.json`](terminal_smoke_evidence_2.0.0.json).
- Terminal selectors, history, input, and output expose five associated VCL labels. The Delphi 13
  IDE64 UI Automation tree confirmed names, states, and descriptions for Web surfaces loaded by
  the same distributed BPL.

## Reproduce

```powershell
npm run test:web
npm run test:docs
npm run lint
powershell.exe -ExecutionPolicy Bypass -File run-sonar-analysis.ps1
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.SonarQualityGate.ps1
```

Visual, keyboard tab, and assistive-technology navigation are proven. The Web contract is
automatically tested and inspected through UI Automation on IDE64; the native terminal is
validated on all four combinations and requires associated labels plus nine tab stops.
