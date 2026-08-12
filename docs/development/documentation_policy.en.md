# Documentation policy

Every maintained Markdown document under `docs` must have two complete, equivalent versions: the
base file in Brazilian Portuguese and the corresponding `.en.md` file in English.

Documentation is part of the product. Every user-visible addition, removal, rename, or behavior
change must update in the same work: the affected central reference, applicable task guide, UI hints,
existing translation, and documentation tests. A feature is incomplete when users must inspect
source code, commit history, or a roadmap to learn how to use it.

Claims about current behavior must be verified against the code, runtime catalog, or current
workflow. Preparatory infrastructure, plans, and historical records must be labeled as such and
never described as available capabilities. The backlog and hubs must explicitly state when no
execution goal is active.

`docs/README.md` is the task hub. `docs/getting-started/` contains installation and onboarding,
`docs/guides/` contains task flows, `docs/reference/` contains authoritative reference,
`docs/development/` contains contribution material, and `docs/project/` contains only future
direction and open work. Each option must document its visible name,
location, purpose, usage, effects, dependencies, valid values, security/network/cost/file impact,
defaults, recovery, and deeper reference. Run `npm run test:docs` before committing.

Internal links must be repository-relative and never use local `file:///` paths. Keep model fallback
lists synchronized with `RadIA.Core.Types.pas`, and derive current tool counts from
`runtime_tools.json` instead of copying historical evidence.

Release notes live exclusively in GitHub Releases. Evidence, audits, execution results, and internal
plans do not belong under `docs/`. Active engineering plans live under `.planning/` and are not user
manuals.

