# Declarative extensions

RadIA 2.0 can load chat commands without recompiling the plugin or restarting Delphi. Each extension
is a `*.radia.json` manifest stored under:

```text
%USERPROFILE%\RadIA\extensions
```

When RadIA uses a custom data directory, `extensions` is created below it. Run
`/extensions reload` to reload files, refresh autocomplete, and view diagnostics. RadIA also reloads
before resolving a command, so adding or removing a manifest takes effect in the same session.

## Visual manager

Open **Tools > Rad IA Extensions...** to install or update a manifest, enable or disable it, reload
diagnostics, or remove it with explicit confirmation. Installs, updates, and status changes use an
atomic write. RadIA validates the candidate first, reloads the complete installed set, and restores
the previous file if validation or activation fails. An open chat refreshes its catalog, while
chats opened later load the current state directly.

The version 1 loader requires a unique PascalCase ID, semantic version, the single `chat.prompt`
permission, and between 1 and 100 valid commands. It rejects the complete manifest on collision or
invalid data. Diagnostics report `loaded`, `disabled`, or `rejected`.

Prompts may use `{code}`, `{argument}`, `{specification}`, and `{stacktrace}`. Version 1 does not run
scripts, tools, processes, writes, or OTA operations. Advanced tools remain available through the
BPL API documented in the [extension guide](tool_extension_guide.md) and remain subject to central
risk and consent policies.

The visual manager completes the local install, update, activation, diagnostics, and removal cycle.
Package signing, distribution, and remote catalog updates remain future M4 stages.
