# Delphi Compatibility Matrix

## Current matrix

|IDE|BDS|IDE architecture|State|
| :--- | :--- | :--- | :--- |
|Delphi 12 Athens| 23.0 |Win32|Supported|
|Delphi 13| 37.0 |Win32|Supported|
|Delphi 13| 37.0 |IDE64|Supported|

Delphi 11 and previous versions are not part of the current matrix. They do not receive new packages,
fixes, regression testing or operational support.

## Mandatory capabilities

|Capacity|Delphi 12 Win32|Delphi 13 Win32|Delphi 13 IDE64|
| :--- | :---: | :---: | :---: |
|Dockable Chat and WebView2|Yes|Yes|Yes|
|Agent mode and tools registry|Yes|Yes|Yes|
|MCP via local bridge|Yes|Yes|Yes|
|Integrated terminal|Yes|Yes|Yes|
|Ghost Text and Inline Proofreading|Yes|Yes|Yes|
|Workspace and OTA editor|Yes|Yes|Yes|
|Form Designer|Yes|Yes|Yes|
|DUnitX build and testing|Yes|Yes|Yes|
|Debugger and timeline|Yes|Yes|Yes|
|Project knowledge|Yes|Yes|Yes|
|Declarative extensions|Yes|Yes|Yes|
|Installation, repair and removal|Yes|Yes|Yes|

A shared functionality cannot be declared complete while there is regression in
any of the three targets.

## Validation Commands

Delphi 12 Win32:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "23.0" -Release -Test -NoCoverage
```

Delphi 13 Win32:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "37.0" -Release -Test -NoCoverage
```

Delphi 13 IDE64:

```powershell
powershell.exe -ExecutionPolicy Bypass -File build.ps1 `
  -DelphiVersion "37.0" -IDE64 -Release -Test -NoCoverage
```

## Compatibility gates

1. The build rejects versions other than BDS 23.0 and BDS 37.0.
2. The installer only accepts the three targets in the matrix.
3. The release contains three packages with manifest, hash and source commit.
4. Each target compiles the BPL, the sample extension, the MCP bridge, and the DUnitX suite.
5. Tests cannot fail, error, ignore or leak.
6. Smokes in real IDE must confirm docking, tool catalog and shutdown without orphaned process.
