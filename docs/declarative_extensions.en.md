# Declarative extensions

RadIA 2.0 can load chat commands without recompiling the plugin or restarting Delphi. Each extension
is a `*.radia.json` manifest stored under:

```text
%USERPROFILE%\RadIA\extensions
```

When RadIA uses a custom data directory, `extensions` is created below it. Run
`/extensions reload` to reload files, refresh autocomplete, and view diagnostics. RadIA also reloads
before resolving a command, so adding or removing a manifest takes effect in the same session.

The version 1 loader requires a unique PascalCase ID, semantic version, the single `chat.prompt`
permission, and between 1 and 100 valid commands. It rejects the complete manifest on collision or
invalid data. Diagnostics report `loaded`, `disabled`, or `rejected`.

Prompts may use `{code}`, `{argument}`, `{specification}`, and `{stacktrace}`. Version 1 does not run
scripts, tools, processes, writes, or OTA operations. Advanced tools remain available through the
BPL API documented in the [extension guide](tool_extension_guide.md) and remain subject to central
risk and consent policies.

This is the first M4 delivery. Visual installation, package signatures, guided updates, and removal
remain future extension-manager stages.
