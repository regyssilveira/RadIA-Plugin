# ADR 0002: Workspace facade with segregated services

- Status: Accepted
- Date: 2026-08-02

## Context

The current contract `IRadIAIDEAdapter` serves existing editorial operations, but the agentive evolution
needs to cover project, editor, build, debugger and Form Designer. Indefinitely expand a single
interface would produce a monolithic and difficult-to-test abstraction.

## Decision

A workspace facade will be created that coordinates services segregated by responsibility:

- Status of FDI.
- Editor's reading and writing.
- Reading and writing the project.
- Build and execution.
- Debugger.
- Form Designer alive.

OTA implementations will be at `Source/Integration`. Core will only depend on interfaces.

The current contract will be preserved during the migration and adapted gradually. There will not be a
comprehensive replacement in a single delivery.

## Consequences

### Positive

- Reduces coupling with OTA.
- Allows small and deterministic fakes.
- Makes it easier to detect capabilities by version.
- Avoid an interface with excessive responsibilities.
- Allows incremental migration.

### Negatives

- More contracts and wiring in the container.
- Some operations will require coordination between services.
- There will be a period of coexistence with the current adapter.

## Rejected alternatives

### Expand `IRadIAIDEAdapter`

Rejected for violating interface segregation and concentrating responsibilities.

### Expose OTA interfaces directly to tools

Rejected for contaminating the Core, making testing difficult and spreading differences between IDE versions.
