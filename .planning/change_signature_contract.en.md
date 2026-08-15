# Semantic Change Signature contract

## Observable outcome

`PrepareChangeSignature` receives the unambiguous identity of a Delphi routine and the desired
signature, calculates every affected declaration, implementation, and call, and produces one
multi-file preview. Preparation never changes files. Application uses `ApplyMultiFilePatch`; rollback
uses `RevertMultiFilePatch`.

## Required Delphi scope

- procedures, functions, constructors, destructors, class methods, and operators;
- global routines and class, record, or interface methods with matching implementations;
- `const`, `var`, `out`, `[Ref]`, unmodified, and default-valued parameters;
- grouped parameters, open arrays, generics, and qualified types;
- parameter addition, removal, rename, and reorder operations;
- modifier, type, default value, return type, and calling-convention changes;
- positional, named, and inherited calls resolved through the semantic index;
- overloads, forward declarations, interface/implementation pairs, and interface implementations;
- DFM-bound handlers while preserving the event type contract.

## Input contract

- `symbol`: routine name.
- `unit`: required when homonyms exist.
- `container`: owning type when one unit contains homonymous methods.
- `signature`: complete desired Delphi declaration without a body.
- `argumentBindings`: explicit value for each new parameter that has no default.

The preview returns identity, old and new signatures, classified changes, rewritten calls, files,
diagnostics, capability, and the next action.

## Safety invariants

1. Identity comes from the semantic index; text search never chooses an overload.
2. Every occurrence must have confirmed offsets, revision, and classification.
3. Declaration and implementation remain equivalent after normalization.
4. A removed parameter with a side-effecting argument requires explicit confirmation.
5. A new parameter requires an applicable default or an explicit per-call binding.
6. Named arguments map through their previous identity rather than position.
7. Virtual, override, interface, and event-handler changes include the complete family or fail with
   actionable diagnostics.
8. Conditional directives, macros, generated code, assembly, and unsupported syntax stop preparation;
   partial edits are forbidden.
9. Content is checked against the indexed revision before preparation and application.
10. Application is atomic, requires structural-write consent, and supports verified rollback.

## Threat model

|Threat|Required treatment|
|---|---|
|Wrong overload|Complete identity including container, unit, and current signature|
|Dynamic or indirect call|Report as unproven and block automatic mutation|
|Removed side-effecting argument|Block or require an explicit preservation binding|
|Interface/implementation drift|Fail before creating a preview|
|Incomplete hierarchy|Query `GetTypeHierarchy` and block when an external member may participate|
|Incompatible DFM|Validate the event signature and include the DFM when required|
|File changed after indexing|Per-file fingerprint and guided reindexing|
|Conditional code|Require the same identity in every proven configuration|
|Encoding or binary DFM|Preserve encoding and require textual/editable DFM content|
|Partial application|Compensating multi-file transaction with rollback evidence|

## Completion evidence

- signature and argument parser tests, including nested generics and anonymous methods;
- headless integration across units, overloads, interfaces, inheritance, and DFM;
- OTA integration that prepares, applies, compiles, and reverts a fixture on Delphi 12 and 13;
- automated usage scenario included in the integrated gate;
- passing builds, DUnitX, documentation, catalog, and Sonar.
