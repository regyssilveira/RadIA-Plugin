# Release notes — RadIA 2.4.1

## Fix

- Fixes the `EResNotFound` failure when opening **Settings** in Delphi 13.
- Embeds the required VCL resource for the external MCP server settings frame.
- Adds a regression test preventing programmatic frames from shipping without their DFM resource.

## Compatibility

- Delphi 12 Win32;
- Delphi 13 Win32;
- Delphi 13 IDE64.

The visual installer is the only artifact required by end users. This update preserves existing
settings, credentials, MCP servers, and local data.

## Validation

- 1,031 Delphi tests passed without failures or leaks;
- 89 web and documentation tests passed;
- all three supported targets compiled successfully;
- installed smoke passed on Delphi 13;
- runtime catalog validated with 132 tools;
- SonarQube Quality Gate `OK` with no issues.
