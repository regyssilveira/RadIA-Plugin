# RadIA Tool Extensions

## Objective

The Extensions API allows another Delphi package to publish tools to the agent registry without
access internal container, OTA or MCP transport. Every registered tool keeps passing
by the same policy executor, consent, audit, sanitization and cancellation of RadIA.

The current version of the API is returned by `GetRadIAToolExtensionApiVersion` and is also available at
constant `CRadIAToolExtensionApiVersion`.

## Public contracts

An extension implements `IRadIAToolExtension` and provides:

- `TRadIAToolExtensionDescriptor`, with ID, version, unique prefix and supported API range;
- one or more implementations of `IRadIATool`;
- `RegisterTools`, which delivers the tools to limited extension logging.

The host validates all descriptors before changing the registry. Batch registration is atomic: name
invalid, invalid schema, collision or duplicity rejects the entire batch.

The name of each tool must begin with the `ToolPrefix` declared by the extension. This delimits
ownership and prevents an extension from removing internal tools or tools belonging to another package.

## Mandatory life cycle

The return of `RegisterRadIAToolExtension` must remain in a global interface variable
external package:

```pascal
var
  GRegistration: IRadIAToolExtensionRegistration;

initialization
  GRegistration := RegisterRadIAToolExtension(
    TRadIASampleToolExtension.Create
  );

finalization
  GRegistration := nil;
```

When releasing the token, the host atomically removes only the tools for that extension. The token must
be released in the extension's `finalization`, before its BPL is downloaded. Maintain references to
Objects implemented by an already downloaded BPL are invalid in Delphi.

The external package must declare `RadIA` in `requires`. This ensures the host is booted
before the extension and that the completion of the extension occurs first.

## Security

- The extension does not receive access to the full registry and cannot call `Clear`.
- Risk and schemas are mandatory and validated by the registry.
- Mutable tools continue to require the RadIA consent policy.
- `ProjectId` and other context fields arrive via `TRadIAToolRequest`.
- Time-consuming operations must observe `ARequest.CancellationToken`.
- Secrets should not be included in results, error messages or descriptors.
- The external package must not retain OTA interfaces or VCL components beyond the cycle documented by
IDE's own API.

## Example

The `Examples/ToolExtension` directory contains a stand-alone package with the read-only tool
`SampleProjectInfo`. It only uses `RadIA.Core.Extensions` and `RadIA.Core.Tools`, registers the extension
on startup and releases the token on termination.

After installing the example BPL, `SampleProjectInfo` automatically appears in the agentive chat and
in `tools/list` of the MCP. When downloading the extension, the tool leaves the catalog without restarting the
MCP server.

## Compatibility

The extension must declare the lowest and highest level of the API it supports. Registration is refused when the
current version does not belong to the specified range. API Level 1 is supported in Delphi 12
and Delphi 13, for both the Win32 IDE and the IDE64 available in Delphi 13.
