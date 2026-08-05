# Release 2.0.0 audit

This audit records reproducible security, privacy, accessibility, and documentation gates for the
RadIA 2.0.0 candidate. It complements but does not replace real IDE cycles.

| Area | Verified control | Automated evidence | Status |
|---|---|---|---|
| Security | Consent, confinement, sanitization, protected credentials, and signed extensions | DUnitX suite and SonarQube | Passed |
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

## Reproduce

```powershell
npm run test:web
npm run test:docs
npm run lint
powershell.exe -ExecutionPolicy Bypass -File run-sonar-analysis.ps1
powershell.exe -ExecutionPolicy Bypass -File scripts\Test-RadIA.SonarQualityGate.ps1
```

Visual keyboard and assistive-technology acceptance inside every supported IDE remains part of the
M8 real cycles and can only be recorded after the proven BPL is installed.
