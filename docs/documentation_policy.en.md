# Documentation policy

Documentation is part of the product. Every user-visible addition, removal, rename, or behavior
change must update in the same work: the affected central reference, applicable task guide, UI hints,
existing translation, and documentation tests. A feature is incomplete when users must inspect
source code, commit history, or a roadmap to learn how to use it.

`docs/README.md` is the task hub, `user_manual.md` the guided manual, `settings_reference.md` the
settings source of truth, `internal_tools_reference.md` the tool source of truth, and
`slash_commands.md` the command source of truth. Each option must document its visible name,
location, purpose, usage, effects, dependencies, valid values, security/network/cost/file impact,
defaults, recovery, and deeper reference. Run `npm run test:docs` before committing.

