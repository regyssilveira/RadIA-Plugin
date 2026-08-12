# ADR 0001: Transport-independent internal tool registration

- Status: Accepted
- Date: 2026-08-02

## Context

RadIA needs to offer agentive capabilities to native chat and external clients. Implement
these capabilities directly in the chat or on the MCP server would duplicate schemas, validations, policies
and audit.

## Decision

An internal tool registry will be created in Core.

Chat, MCP and future adapters will be consumers of this record. Tools will be described
by RadIA's own contracts and will not know details of UI, WebView2 or transport.

The central executor will be responsible for:

- Resolve tool.
- Validate input.
- Check IDE capacity.
- Apply policies.
- Request consent.
- To execute.
- Sanitize result.
- Register audit.

## Consequences

### Positive

- A single implementation per tool.
- Consistent security.
- Testability without IDE or MCP.
- Evolution independent of providers.
- MCP can be added or removed without affecting the chat.

### Negatives

- Requires schemas and intermediate types.
- Adds a layer before OTA calls.
- Requires disciplined versioning of contracts.

## Rejected alternatives

### Tools implemented directly in MCP

Rejected because it couples the product to the protocol and prevents clean reuse via chat.

### OTA calls directly in Presenter

Rejected because it mixes UI, threading, security and workspace rules.
