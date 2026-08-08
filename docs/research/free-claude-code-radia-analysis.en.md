# Audit of Free Claude Code ideas applicable to RadIA

## Executive summary

This audit compares RadIA 2.2.1 with Free Claude Code (FCC) 4.17.1, commit
`627c6d7417e764b7334e5b59643b6c7c872d5bbb`, viewed 7 August 2026. Not a dispute
between products. RadIA is a native RAD Studio extension, integrated with OTA, editor, compiler,
debugger and consent. The FCC is a local proxy that translates protocols and connects agent clients to
providers. Therefore, a feature is only recommended when it improves the journey within Delphi.

The biggest gains found are: uniform failure taxonomy, secure streaming recovery,
richer declarative catalog of providers, observable cache of models and test contracts by
capability. Next comes normalization of reasoning, competition control, internal events
standardized, diagnostic correlation and single CLI resolution contract.

RadIA already has local providers, OpenAI-compatible provider, JSON extensible registry, agent
native, CLI and MCP independent, consent, model update without restart, `/doctor` and
`/status`. Therefore, there is no benefit in importing the proxy, messaging, tray app or
an indiscriminate list of providers.

This deliverable is research and prioritization. No FCC codes were copied and no structural changes
has been implemented.

## Method and evidence

Code, tests, manifests, installers and architecture of both projects were read. At RadIA, the
analysis started with registries and went through providers, models, agent, CLI, MCP, context,
consent, streaming, diagnosis, knowledge and UI. At FCC, it ran through `application`, `api`,
`cli`, `config`, `core`, `providers`, `runtime`, `messaging`, tests and scripts.

Main external sources:

- [parsed review](https://github.com/Alishahryar1/free-claude-code/tree/627c6d7417e764b7334e5b59643b6c7c872d5bbb);
- [`ARCHITECTURE.md`](https://github.com/Alishahryar1/free-claude-code/blob/627c6d7417e764b7334e5b59643b6c7c872d5bbb/ARCHITECTURE.md);
- [provider catalog](https://github.com/Alishahryar1/free-claude-code/blob/627c6d7417e764b7334e5b59643b6c7c872d5bbb/src/free_claude_code/config/provider_catalog.py);
- [fault policy](https://github.com/Alishahryar1/free-claude-code/blob/627c6d7417e764b7334e5b59643b6c7c872d5bbb/src/free_claude_code/providers/failure_policy.py);
- [streaming recovery](https://github.com/Alishahryar1/free-claude-code/blob/627c6d7417e764b7334e5b59643b6c7c872d5bbb/src/free_claude_code/providers/stream_recovery.py).

Conclusions depict these commits, not future versions.

## Architectures

### RadIA

RadIA runs on `bds.exe`: UI VCL/WebView2, OTA for editor/project/build/test/designer/debugger,
native providers compatible with OpenAI, native agent with tools/consent/audit and bridge
External MCP. The advantage is to act within the real context of the IDE; the cost is to take care of UI thread, WebView2,
shutdown and process isolation.

### FCC

The FCC runs separately. FastAPI receives Anthropic Messages or OpenAI Responses, converts the protocol,
routes a provider and returns streaming in the client's contract. Launchers configure Claude Code,
Codex and Pi. An administrative UI manages provider, model, auth and diagnostics; Telegram/Discord
can trigger managed sessions.

### Architectural direction

RadIA should carry the standards for small Delphi interfaces — catalog, routing, faults,
recovery, discovery, and observability — without hosting an HTTP proxy. The MCP bridge already meets the
necessary external border.

## Analysis by domain

### Features and experience

FCC centralizes configuration and displays consistent status and failures. RadIA already covers a journey
deeper: create and change projects, compile, test, debug, diagnose memory, use Git and
terminal. The benefit is to show in the chat, `/doctor` and `/status` the origin of the model, health of the provider,
next action and recovery applied — do not create more screens.

### Providers, models and routing

The FCC catalog describes name, endpoint, credential URL, required fields, proxy, discovery
and factory. RadIA has `TProviderRegistry`, native providers, generic OpenAI-compatible, defaults
and JSON extensions. Quantity is not the gap. `TProviderMetadata` can evolve to declare auth,
discovery, reasoning, tools, streaming, capabilities and help, serving UI, doctor and runtime.

RadIA already reloads models without restarting and has fallback. It remains to be made explicit: origin
`live/cache/fallback`, time of discovery, age, previous error and validity.

### Authentication

The FCC specializes in OpenAI/Codex and Vertex, as well as keys. RadIA already separates API key, ChatGPT login via
Codex CLI, portable executable and external auth. Must maintain independent provider, CLI executor and MCP.
Each auth should declare prerequisites, verification, renewal, expiration and recovery.

### CLI and MCP

FCC launchers focus on environmental preparation and sanitation. RadIA already discovers, allows
override, install with consent, authenticate, revalidate, and record repairs. The applicable idea is a
single executable resolution contract, consumed by diagnosis, installation, login and execution.
MCP must remain independent of the executor.

### Agents and context

The FCC manages clients and conversation trees, but delegates agency. RadIA has a native composer
with plan, approval, pause, resume, history and IDE tools. Replacing it with CLI sessions would be
regression. It is useful, however, to normalize provider, CLI, tool, debugger, build and test events before
render them.

### Local AI

FCC supports LM Studio and OpenAI-compatible gateways; RadIA already supports Ollama, LM Studio and Generic.
The priority should be to diagnose endpoint, loaded models, tools, context and streaming. Adopt
more names without contract and real testing creates maintenance, not value.

### Installation and diagnosis

The FCC separates installation, update, removal, health and status. RadIA already offers an installer,
onboarding, supported CLI installation, `/doctor`, `/status` and MCP handshake. Can adopt results
types: stable code, summary, sanitized evidence, automatic action and full manual alternative.

### Security, privacy and observability

Applicable are: minimum logs by default, detailed payload by opt-in, key redaction, request ID,
limited retention and private network blocking on web fetch. RadIA is already stronger on consent
at risk. It must preserve this model and add uniform correlation and failures, without recording
prompts, tokens, sensitive arguments or responses by default.

## Opportunity matrix

|Idea|It exists at the FCC|It exists in RADIA|gap|Impact|Effort|Priority|
|---|---|---|---|---|---|---|
|Canonical taxonomy of failures|Yes|Partial|Messages/retry vary|High|Average|P0|
|Secure streaming recovery|Yes|Partial|Answer may be truncated|High|High|P0|
|Rich declarative catalog|Yes|Partial|Missing capabilities/auth|High|Average|P0|
|Observable model cache|Yes|Partial|Origin and age are unclear|High|Average|P0|
|Capability contracts|Yes|Partial|No uniform matrix|High|Average|P0|
|Reasoning normalization|Yes|Partial|Vocabulary varies|Average|Average|P1|
|Admission control by provider|Yes|Not central|No single policy|Average|Average|P1|
|Normalized execution events|Yes|Partial|UI knows different formats|Average|High|P1|
|Request/correlation ID|Yes|Partial|Incomplete correlation|Average|Average|P1|
|Single CLI Agreement|Yes|Partial|Flows may diverge|High|Average|P1|
|Local AI Probing|Yes|Partial|Capability not always tested|Average|Average|P1|
|Credential URL in Catalog|Yes|Partial|Scattered help|Average|Low|P1|
|Proxy Anthropic/Responses|Central|No|Out of the IDE journey|Low|High|P3|
|Launchers Claude/Codex/Pi|Yes|Another drawing|Would double management|Low|High|P3|
|Telegram/Discord|Yes|No|Out of Focus Delphi|Low|High|P3|
|Tray application|Yes|No|IDE is already the host|Low|Average|P3|
|Voice transcription|Yes|No|No validated case|Low|High|P3|

## Group decision

### Implement now

- canonical taxonomy of failures;
- catalog with operational metadata;
- origin, age and fallback of models;
- minimum matrix of contracts by provider/capability.

### Plan

- streaming transactional recovery;
- reasoning by provider/model;
- competition, backoff and circuit breaker;
- normalized events and end-to-end correlation;
- single CLI contract.

### Try

- local server capabilities probing;
- short holdback at the start of streaming;
- adaptation of reasoning and tool schema per model;
- healthcare vision by provider within existing surfaces.

### Do not implement

- mandatory multiprotocol proxy;
- Telegram/Discord, tray app and voice;
- Pi client and parallel launchers;
- mass import of providers without defined testing and maintenance.

## Top 10 prioritized

### 1. Canonical failure taxonomy — P0

1. **Problem:** adapters translate timeout, auth, limit and unavailability in different ways.
2. **Idea:** `TRadIAProviderFailure` with category, retry, code, message and action.
3. **FCC:** `ExecutionFailure` and `failure_policy.py` stabilize semantics after retries.
4. **Adaptation:** convert exceptions at the service boundary, keeping details sanitized.
5. **Impact:** high.
6. **Difficulty:** medium.
7. **Components:** providers, streaming, service, chat, doctor, logger and tests.
8. **Risk:** hide detail; preserve secure cause and correlation ID.
9. **Strategy:** migrate a remote and a local provider, then the others.
10. **Accept:** the same failure generates identical category and next action on all adapters.

### 2. Streaming transactional recovery — P0

1. **Problem:** Interrupted connection may leave text or tool call incomplete.
2. **Idea:** distinguish failure before visual commit, after text and after complete tool.
3. **FCC:** Short buffer allows invisible retry and specific policy in the middle of the stream.
4. **Adaptation:** event buffer without repeating tool or confirmed content.
5. **Impact:** high.
6. **Difficulty:** high.
7. **Components:** streaming, service, presenter and parser tools.
8. **Risk:** duplicate text/action and increase latency.
9. **Strategy:** state machine, idempotence, small limit and feature flag.
10. **Accept:** early/intermediate/tool ​​cuts do not duplicate content or effects.

### 3. Declarative catalog as a single source — P0

1. **Problem:** registration, UI, doctor and help may know different data.
2. **Idea:** metadata for auth, capabilities, discovery and documentation.
3. **FCC:** `ProviderDescriptor` guides configuration, status and construction.
4. **Adaptation:** expand `TProviderMetadata` and JSON schema, maintaining Delphi factories.
5. **Impact:** high.
6. **Difficulty:** medium.
7. **Components:** ProviderRegistry, ConfigFrame, factories, doctor and generated docs.
8. **Risk:** incompatibility with existing JSON.
9. **Strategy:** optional fields, version and defaults supported.
10. **Accept:** UI, doctor and runtime read the same description; test detects divergence.

### 4. Observable model discovery — P0

1. **Problem:** user does not know if the list came from the API, cache or fallback.
2. **Idea:** expose origin, instant, validity, error and refresh.
3. **FCC:** discovery and cache have explicit state.
4. **Adaptation:** immutable state and asynchronous refresh without restart.
5. **Impact:** high.
6. **Difficulty:** medium.
7. **Components:** providers, config, chat, doctor/status and tests.
8. **Risk:** concurrent refresh or obsolete UI.
9. **Strategy:** monotonic generation, cancellation on shutdown and publication on the UI thread.
10. **Accept:** provider change updates and shows `live/cache/fallback`, time and error.

### 5. Provider contract matrix — P0

1. **Issue:** Tests do not uniformly demonstrate streaming, tools, and failures.
2. **Idea:** suite shared by adapter and profile.
3. **FCC:** contracts cover protocols, catalogues, boundaries and streaming.
4. **Adaptation:** DUnitX fixtures and real opt-in smoke tests.
5. **Impact:** high.
6. **Difficulty:** medium.
7. **Components:** tests, HTTP and CI mocks.
8. **Risk:** live instability; separate from the deterministic suite.
9. **Strategy:** OpenAI, Claude, Gemini, Ollama and Generic first.
10. **Accept:** every declared capability has a corresponding deterministic contract.

### 6. Normalization of reasoning — P1

1. **Problem:** names and levels are not universal.
2. **Idea:** negotiate option per provider/model with clear fallback.
3. **FCC:** profiles translate vocabulary and reasoning details.
4. **Adaptation:** capability in the catalog and normalizer separate from the payload.
5. **Impact:** medium.
6. **Difficulty:** medium.
7. **Components:** config, providers, metadata and UI.
8. **Risk:** unexpected cost/latency.
9. **Strategy:** opt-in, conservative default and effective value diagnosis.
10. **Accept:** provider does not receive incompatible parameter and user sees the effective level.

### 7. Admission control and backoff — P1

1. **Issue:** Competing tasks may pressure limited endpoint.
2. **Idea:** limit, short queue, backoff with jitter and circuit breaker per provider.
3. **FCC:** admission and retry are explicit responsibilities.
4. **Adaptation:** shared service preserving cancellation.
5. **Impact:** medium.
6. **Difficulty:** medium.
7. **Components:** provider service, agent, chat and status.
8. **Risk:** hidden queue and appearance of a crash.
9. **Strategy:** visible status, queue timeout and immediate cancellation.
10. **Accepted:** concurrent test proves limit, cancellation and reopening.

### 8. Normalized events — P1

1. **Problem:** provider, CLI and tools deliver different formats for the presentation.
2. **Idea:** `started/delta/reasoning/tool/usage/failed/completed` events.
3. **FCC:** Conversions and pipelines isolate protocols from rendering.
4. **Adaptation:** internal Delphi records, without HTTP server.
5. **Impact:** medium.
6. **Difficulty:** high.
7. **Components:** service, agent, CLI adapters, presenter and chat.js.
8. **Risk:** transversal refactoring.
9. **Strategy:** parallel adapter and incremental migration.
10. **Accepted:** UI does not interpret provider/CLI specific payload.

### 9. Structured correlation — P1

1. **Problem:** failure between UI, provider, tool and process requires crossing logs.
2. **Idea:** correlation ID per turn/execution without sensitive payload.
3. **FCC:** request IDs and traces join the layers.
4. **Adaptation:** propagate ID in logger, audit, tool run and diagnosis.
5. **Impact:** medium.
6. **Difficulty:** medium.
7. **Components:** logger, service, runtime, security audit and doctor.
8. **Risk:** exposure; ID cannot contain user data.
9. **Strategy:** Random GUID and metadata allowlist.
10. **Accept:** an ID retrieves the sanitized string without prompt, token, or credential.

### 10. Single CLI executable agreement — P1

1. **Problem:** discovery, login and execution may diverge again.
2. **Idea:** resolve path, origin, version, auth and environment once.
3. **FCC:** launchers focus preparation and remove conflicting credentials.
4. **Adaptation:** single interface over the mechanism already corrected in RadIA.
5. **Impact:** high.
6. **Difficulty:** medium.
7. **Components:** CLI manager, config, agent executors, doctor and MCP provisioning.
8. **Risk:** breaking portable and WSL overrides.
9. **Strategy:** tests with PATH, override, spaces, missing and WSL.
10. **Accept:** diagnostics and execution display and use the same effective path.

## Quick wins

1. Display `live`, `cache`, or `fallback` next to the model and in `/status`.
2. Include official credential/help URL in metadata.
3. Standardize error category and next action in chat.
4. Add sanitized correlation ID to failures.
5. Generate provider × capability table and protect it by testing.
6. Show the CLI executable actually used in the doctor.

## Structural improvements

- separate metadata, factory, discovery and health without multiplying records;
- keep specific payload out of presenter and JavaScript;
- define commit and idempotence before implementing recovery;
- fail test when a declared capability does not have a contract;
- structure diagnostics before rendering them as text;
- preserve provider, native agent, CLI and MCP as independent axes.

## Suggested roadmap

1. **Basic reliability:** canonical faults, structured diagnosis, catalog and origin of models.
2. **Contracts:** capabilities matrix, shared tests and standardized reasoning.
3. **Resilience:** admission control, retry/backoff and holdback experiment.
4. **Unification:** normalized events, correlation ID and single CLI contract.

Steps 1 and 2 fit into a minor release. Recovery should only leave the feature flag after testing
tool idempotence.

## License, security and privacy

The FCC uses MIT license. It allows use and modification, but requires preserving copyright and license in
copies or substantial portions. This audit uses abstract ideas and patterns. If there is adaptation
material in the future, it must be isolated, reviewed and recorded in `THIRD_PARTY_NOTICES` or
equivalent before the merge.

Should not be automatically copied: Python code without lifecycle/threading redesign, flows
OAuth without threat model, proxy/admin/web fetch without auth/loopback/SSRF, payload logs and retries that
can repeat writing, debugging or tool calls. Consent, allowlists, redaction of secrets, limits
workspace and RadIA auditing remain mandatory.

## Risks

- excessively complex catalogue;
- holdback latency;
- duplication of tool calls;
- too many providers to maintain;
- payload leakage in observability;
- threads/timers surviving shutdown;
- new confusion between provider, auth, CLI and MCP.

Mitigations: small and versioned schema, conservative limits, idempotence, contracts, logs per
allowlist and cancellation integrated into shutdown.

## Next steps

1. Create ADR from `TRadIAProviderFailure` and discovery state.
2. Inventory real capabilities and their tests.
3. Prototype canonical failures on a remote and local provider.
4. Expose origin/age in `/status` and `/doctor`.
5. Define “visual commit” and “idempotent action” before recovery.
6. Measure sanitized failures to choose retry, concurrency, and cache.
7. Convert steps 1 and 2 into release goals with verifiable criteria.

## Conclusion

The FCC does not reveal a loophole that would require turning RadIA into a universal proxy or aggregator. He
provides mature benchmarks to make current infrastructure predictable, observable, and testable.
The right investment is to deepen your experience in Delphi and use catalog, failures, discovery,
recovery and contracts as multipliers of this experience.
