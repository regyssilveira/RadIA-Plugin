# Delphi environment profile

`GetDelphiEnvironmentProfile` provides the agent with a read-only, sanitized inventory of the active
IDE and project. Use the tool before suggesting components, APIs, or migrations that depend on the
available version, architecture, framework, or libraries.

## How to use it

Run this command in chat:

```text
/tool GetDelphiEnvironmentProfile
```

Agent mode may also call the tool when an objective depends on the Delphi environment.

## Returned data

- IDE version, architecture, and edition when Delphi publishes it in the Registry;
- available OTA capabilities;
- project, framework, configuration, and target platform;
- search paths declared in the `.dproj`;
- runtime packages declared in the `.dproj`;
- libraries recognized from project content.

Version, architecture, edition, and capabilities come from the OTA and the official IDE base key.
Other fields combine the workspace snapshot with a bounded read of the active `.dproj`.

## Privacy and limits

The tool does not send data by itself, modify the project, or read files beyond the active `.dproj`.
Absolute search paths inside the project are replaced with `{workspace}`. External absolute paths
are represented by `<external>`, avoiding disclosure of user names or private directories. MSBuild
variables such as `$(BDS)` remain visible because they do not reveal the expanded machine path.

The project file is limited to 2 MiB and each collection returns at most 100 unique items. An edition
not published by Delphi appears as `unknown`; this value must not be interpreted as a specific SKU.

## Recovery

If the profile is incomplete:

1. confirm that an active, saved Delphi project exists;
2. check that its `.dproj` contains the expected `FrameworkType`, search paths, and packages;
3. run `/doctor` to verify the workspace and tool catalog;
4. use `/status project` to inspect the active snapshot.
