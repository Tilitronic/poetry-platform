Telemetry re-entrancy guards
res003 — Telemetry re-entrancy guards
Date: 2026-08-08

Summary
This conspect synthesizes canonical guidance, community experience, and concrete failure modes for telemetry re-entrancy and self-observability guards. Sources (39) were archived locally and reviewed before synthesis. The conspect presents: (A) a concise taxonomy of guard patterns (P1–P4), (B) three hard-won engineering lessons, (C) a catalog of OpenCode-specific failure classes discovered in project issue history, and (D) a mapping to local plugins (opencode-telemetry, opencode-token-monitor, opencode-subagent-output) recommended as DIA-056(b) audit targets.

Taxonomy of guard patterns

P1 — Thread-local reentrancy flags / depth counters
- Mechanism: A per-thread or per-execution-context boolean flag or numeric depth counter prevents telemetry libraries from re-entering instrumentation paths while they are already executing. Implementations live in many ecosystems: logging handlers (Sentry's handler depth counter), tracing wrappers (tracing-opentelemetry's layer guards), and language-specific context objects.
- Tradeoffs: Simple and fast; protects against direct recursion. Fails when work migrates across threads/runtimes or when asynchronous re-entry crosses context boundaries.

P2 — Context-carried suppression flags
- Mechanism: Store an explicit suppression key in the execution context so downstream instrumentation can skip emitting. Examples: OpenTelemetry's _SUPPRESS_INSTRUMENTATION_KEY, SuppressInstrumentationScope helpers, or language-specific scoped APIs that set a suppression token propagated with context.
- Tradeoffs: Robust across synchronous call chains and explicit context propagation. Breaks if any library, thread-handoff, runtime boundary, or third-party layer fails to propagate context correctly.

P3 — Dedicated / isolated providers with allowlists
- Mechanism: Isolate telemetry emission into a separate provider or process and apply explicit allowlists for which events or views are permitted. This includes the self-observability guidance in OTel and Jaeger's ADR describing internal tracing via an isolated telemetry factory.
- Tradeoffs: Strong isolation and clearer security/performance boundaries. Requires upfront design and can increase operational complexity (separate exporter pipelines, filters).

P4 — Event deduplication and identity keying
- Mechanism: Deduplicate by stable identity keys (event ID, user-message-id) or use identity hashing to collapse repeated self-originating events. Implementations in product integrations (Copilot CLI session hooks, opencode-plugin-otel PRs) use identity keys to avoid session-loop noise.
- Tradeoffs: Effective for noisy duplicate symptoms and multi-layer emission. Requires stable, collision-resistant identity and care to avoid incorrectly dropping distinct events.

Three hard-won lessons

1) Never log or emit telemetry from inside your guard's drop path.
 - Rationale: A common anti-pattern is to attempt to report guard activity (e.g., "suppressed X"), which paradoxically invokes instrumentation and defeats the guard. Sentry's silent-drop rule and several community PRs demonstrate that guard-path logging creates infinite loops or silent drops.

2) Suppression only works if every layer participates or if you isolate the provider.
 - Rationale: Context-carried suppression is only as strong as the weakest library in the call chain. If any intermediary (thread-handoff, third-party runtime, native extension) fails to propagate the suppression token, instrumentation resumes. The practical alternatives are: (a) enforce suppression at all layers (difficult), or (b) use dedicated/isolated telemetry providers with allowlists or separate export paths.

3) Key events by stable identity — not ephemeral session IDs.
 - Rationale: Deduplication by session or ephemeral IDs is brittle: session-IDs change on rehydrate/restart, and reentrant loops often reuse session state. Use a stable event identity where possible (message-id, canonical request hash) to deduplicate safely across retries and replays.

OpenCode-specific failure classes (project evidence)

- Recursive subagent spawning (issue #25681): large-scale reentrancy where a subagent repeatedly spawns itself across sessions (observed: ~612 sessions) — symptom: runaway CPU and repeated telemetry emission.
- Session-loop DB rehydration (issue #31525): session rehydrate paths that replay queued messages and re-trigger instrumentation without suppression — symptom: duplicated traces/metrics on restore.
- Plugin log-during-init hang (issue #7741): plugin initialization emits logs that trigger instrumentation, which in turn calls into plugin initialization — symptom: startup hang.
- Missing suppression guards as accepted bug class (opentelemetry-rust #3494; python-contrib #476): libraries documenting suppression gaps and open issues where maintainers accept defensive workarounds as temporary.

Concrete mapping to local plugins (DIA-056(b) audit targets)

- opencode-subagent-output: audit for recursive emission during subagent spawn and ensure explicit suppression or isolation during spawn/init paths.
- opencode-telemetry: audit filter/allowlist rules and implement identity-keyed deduplication on high-volume events (message hooks, session rehydrates).
- opencode-token-monitor: audit telemetry emission during token accounting updates (ensure suppression when token updates are driven by plugin callbacks or rehydration loops).

Recommendations (short)

1) Apply a layered defense: thread-local guard (P1) + context suppression where possible (P2) + isolated provider for self-observability (P3). Do not rely on any single pattern.
2) Add a strict "no-emit-in-guard" policy: any guard code must be explicitly non-instrumenting and tested under simulated recursion.
3) Implement event identity keying on the hottest code paths (message delivery, session rehydrate) and use stable IDs for deduplication.
4) For OpenCode: implement runtime checks in subagent/init paths that assert suppression is active; instrument these checks out-of-band (developer-only traces) or log to a separate, non-instrumented sink.

Works Cited (selected MLA-style citations — archived sources)

OpenTelemetry Project. "Self-Observability Supplementary Guidelines." OpenTelemetry, https://opentelemetry.io/docs/specs/otel/self-observability-supplementary-guidelines/. Accessed 8 Aug. 2026.

OpenTelemetry Specification. "Self-Observability Supplementary Guidelines." GitHub, https://github.com/open-telemetry/opentelemetry-specification/blob/e1a96dc3/specification/self-observability-supplementary-guidelines.md. Accessed 8 Aug. 2026.

OpenTelemetry Contributors. "opentelemetry-python-contrib #4302". GitHub, https://github.com/open-telemetry/opentelemetry-python-contrib/pull/4302. Accessed 8 Aug. 2026.

K. (OpenTelemetry Rust). "opentelemetry-rust #3084." GitHub, https://github.com/open-telemetry/opentelemetry-rust/pull/3084. Accessed 8 Aug. 2026.

OpenTelemetry Rust community. "Issue #3494." GitHub, https://github.com/open-telemetry/opentelemetry-rust/issues/3494. Accessed 8 Aug. 2026.

OpenTelemetry Specification PR. "PR #1653." GitHub, https://github.com/open-telemetry/opentelemetry-specification/pull/1653. Accessed 8 Aug. 2026.

Jaegertracing. "ADR 006 — Internal tracing via otelcol telemetry factory." GitHub, https://github.com/jaegertracing/jaeger/blob/1a105f34/docs/adr/006-internal-tracing-via-otelcol-telemetry-factory.md. Accessed 8 Aug. 2026.

Sentry Project. "Sentry Java PR #5734 and related commits." GitHub, https://github.com/getsentry/sentry-java/pull/5734. Accessed 8 Aug. 2026.

Visual Studio Code Team. "Telemetry (Extensions)." Microsoft Docs, https://code.visualstudio.com/api/extension-guides/telemetry. Accessed 8 Aug. 2026.

GitHub Copilot CLI. "Issue #991." GitHub, https://github.com/github/copilot-cli/issues/991. Accessed 8 Aug. 2026.

AnomalyCo / OpenCode issues and PRs (example evidence of project failures): Issue #7741; Issue #25681; Issue #31525; PR #21762. GitHub, https://github.com/anomalyco/opencode/. Accessed 8 Aug. 2026.

DEVtheOPS. "opencode-plugin-otel PR #74." GitHub, https://github.com/DEVtheOPS/opencode-plugin-otel/pull/74. Accessed 8 Aug. 2026.

Additional community reports and forums (Cursor, Cursor Forum threads on agent loops and duplicate notifications) — representative threads archived and reviewed. Accessed 8 Aug. 2026.

Appendix — Local archive

All 39 source markdown files are stored in the sources/ subdirectory adjacent to this conspect; do not edit archived sources. This conspect was synthesized only from those local copies.

---
Generated by: conspecter (res003) — reviewed 2026-08-08
