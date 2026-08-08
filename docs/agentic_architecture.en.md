# RadIA Agentive Architecture

## 1. Objective

This document defines the target architecture to evolve RadIA from a multi-provider chat to a
secure agentive platform integrated with the Delphi IDE.

The architecture must allow native chat and external clients to use the same capabilities
of the workspace, without duplicating Open Tools API (OTA) access rules, consent or auditing.

This specification is implementation independent. No code, feature, text or contract
of products analyzed as reference must be copied.

## 2. Principles

1. The internal registration of tools is independent of MCP, UI and providers.
2. The MCP is a transport adapter, not the core of the product.
3. All dependencies on `ToolsAPI`, `DesignIntf` or internal IDE interfaces are in `Source/Integration`.
4. Core only works with RadIA contracts and types.
5. Readings and mutations go through the same policy chain.
6. A mutation must have preconditions, consent, audit and verifiable result.
7. OTA and VCL operations execute on the main thread.
8. Networking, indexing, heavy parsing and external processes run in the background.
9. Every operation must accept cancellation and respect the wizard's life cycle.
10. Features not supported by a given IDE must fail explicitly and predictably.

## 3. Component view

```text
Chat Presenter ----------------------+
                                      |
CLI Provider -> MCP Transport --------+--> Tool Registry
                                      |         |
Future Automation Adapter ------------+         v
                                           Policy Pipeline
                                               |
                             +-----------------+-----------------+
                             |                                   |
                             v                                   v
                      Workspace Facade                     Knowledge Search
                             |
                   Integration/OTA Adapters
                             |
                         Delphi IDE

Policy Pipeline --> Consent Service
Policy Pipeline --> Audit Log
Policy Pipeline --> Sensitive Data Redactor
```

## 4. Layers

### 4.1 Core

Responsibilities:

- Tool descriptors and schemas.
- Tool registration and discovery.
- Execution context.
- Policy chain.
- Abstract consent.
- Abstract audit.
- Workspace facade types.
- Representation of patches and preconditions.
- Types of knowledge and search.

The Core must not import `ToolsAPI`, `Vcl.*`, WebView2, or transport implementations.

### 4.2 Integration

Responsibilities:

- Implement the workspace facade using OTA.
- Marshaling to the main thread.
- Resolve project, module, source editor, edit view and form editor.
- Detect capabilities available in the current version of the IDE.
- Integrate build, debugger, project group and designer.
- Preserve live buffers and unsaved changes.

### 4.3 UI

Responsibilities:

- Show tool calls.
- Request consent.
- View progress, result, affected files and audit.
- Present diff and allow accept or reject.
- Never run OTA directly.

### 4.4 Transport

Responsibilities:

- Translate MCP to internal registry.
- Authenticate the local instance.
- Apply payload and timeout limits.
- Close with the plugin lifecycle.

Current implementation:

- `TRadIAMcpProtocol` translates JSON-RPC/MCP to the registry without duplicating tools.
- `TRadIANamedPipeMcpServer` maintains local transport outside of the Core and creates one session per client.
- The ephemeral endpoint uses Windows ACL limited to the owner and the system.
- `RadIAMcpBridge.exe` adapts the private pipe to MCP's standard stdio transport.
- External requests pass through the policy enforcer with origin, session and project.
- `notifications/cancelled` signals cooperative tokens while the call continues in the background.
- Each connection accepts one in-flight call; Excessive competition returns JSON-RPC error `-32003`.
- During the splash, trading and catalog are still available, but `tools/call` returns `-32004`
until there is a `TAppBuilder` main window visible. The customer must wait and repeat.
- `radia/metrics` returns only sanitized counters and does not include prompts, arguments, or code.
- Each process publishes its own discovery by PID; the legacy file is only removed by the instance
which also proves ownership of the endpoint.
- Shutdown stops the worker before releasing logger, container and OTA integration.

### 4.5 Knowledge

Responsibilities:

- Extract symbols and chunks from the project.
- Maintain incremental index per workspace.
- Perform lexical and, in the future, vector search.
- Return traceable sources.
- Do not decide on your own which mutations to perform.

## 5. Initial contracts

The names below are proposals. The definitive Pascal declaration must be created only in the first
implementation slice.

### 5.1 Tools

- `IRadIATool`
- `IRadIAToolRegistry`
- `IRadIAToolPolicy`
- `IRadIAToolExecutor`
- `TRadIAToolDescriptor`
- `TRadIAToolRequest`
- `TRadIAToolResult`
- `TRadIAToolContext`
- `TRadIAToolError`

A descriptor must contain:

- Stable name.
- Contract version.
- Description in English for consumption by models.
- Input schema.
- Output schema.
- Risk level.
- Required capacity of the IDE.
- Default timeout.
- Indication of idempotency.

### 5.2 Workspace

- `IRadIAWorkspaceFacade`
- `IRadIAEditorReadService`
- `IRadIAEditorWriteService`
- `IRadIAProjectReadService`
- `IRadIAProjectWriteService`
- `IRadIABuildService`
- `IRadIADebugService`
- `IRadIALiveFormService`
- `IRadIAIDEStateService`

The facade coordinates services, but should not become a monolithic class. Each service has
single responsibility and can be replaced by fake in tests.

### 5.3 Security

- `IRadIAConsentService`
- `IRadIAAuditLog`
- `IRadIASensitiveDataRedactor`
- `IRadIAWorkspaceBoundary`
- `TRadIAToolRisk`
- `TRadIAConsentDecision`
- `TRadIAAuditEvent`

### 5.4 Extensions

- `IRadIAToolExtension`
- `IRadIAToolExtensionRegistrar`
- `IRadIAToolExtensionHost`
- `IRadIAToolExtensionRegistration`
- `TRadIAToolExtensionDescriptor`

The versioned API provides trusted extensions with only a limited registrar. The tools are
validated and published atomically in the shared registry, therefore they remain subject to the same
policies, consent, audit and MCP limits. Each extension declares a prefix
ownership and maintains a token that removes its tools prior to BPL offloading.

## 6. Execution flow

### 6.1 Reading

1. Consumer creates a request with correlation identifier.
2. Registry resolves the tool.
3. Executor validates schema, capacity and lifecycle.
4. Policy classifies the action.
5. Facade query tool.
6. Result is limited and sanitized.
7. Audit records metadata, without sensitive content.

### 6.2 Mutation

1. Tool reads the alive state and calculates preconditions.
2. Tool produces a plan or patch without changing the IDE.
3. UI presents summary and diff.
4. Consent is requested.
5. Preconditions are checked again.
6. Mutation is applied on the main thread.
7. Final state is re-read and compared to expected.
8. Audit records results and affected artifacts.
9. A rollback identifier is returned when applicable.

### 6.3 Agentive Build

1. Approved change is applied.
2. Build is requested separately.
3. Messages are collected structuredly.
4. Errors can feed a new proposal.
5. Each new mutation requires review according to policy.
6. The number of iterations is limited.
7. Running the application requires consent other than the build.

## 7. Thread safety

- OTA and VCL calls must use a single main thread dispatcher abstraction.
- The tool should never keep OTA references after the call ends.
- Queued callbacks check `IRadIALifecycleGuard`.
- Cancellation prevents further steps, but does not interrupt an OTA operation in the middle of writing.
- Writes should be small, deterministic and verified.
- No dialog should be created by a secondary thread.

## 8. Shutdown

Secure termination is an architectural requirement:

1. Invalidate the lifecycle guard.
2. Decline new calls.
3. Cancel network operations, indexing, and child processes.
4. Terminate MCP listeners.
5. Drain safe callbacks only.
6. Disassociate WebView2 according to the existing policy.
7. Do not actively release WebView2 when `GIsShuttingDown` is active.
8. Avoid unloading the BPL while callbacks can still execute.

## 9. Persistence

In the first phase, tool registration does not require persistence.

Audit and knowledge must use abstract stores. SQLite can be adopted later,
provided that:

- Have versioned migrations.
- Use transactions.
- Do not store credentials.
- Allow exporting portable data.
- Have a clear retention and deletion policy.

## 10. Implementation boundaries

### Included

- Native chat using internal tools.
- MCP consuming the same registry.
- Read-only and changeable OTA tools.
- Consent and audit.
- Patches, build, designer, debugger and knowledge.
- Local extension packages using the public versioned API.

### Not initially included

- Generic desktop automation.
- Complete terminal.
- Automatic execution without consent.
- Remote extension catalog.
- Mandatory vector bank.
- Mandatory Python dependency.

## 11. Architectural criteria

The architecture will be implemented when:

- Chat does not call OTA directly to run tools.
- MCP can be removed without affecting chat or the registry.
- Tools can be tested with a fake facade.
- Every mutation goes through policy, consent and audit.
- Unsupported capabilities fail without crashing.
- Shutdown terminate transports and tasks without deadlock.
- The applicable Delphi matrix is ​​green.
