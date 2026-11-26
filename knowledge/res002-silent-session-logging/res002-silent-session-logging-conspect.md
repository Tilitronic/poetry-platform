# Conspect: Silent Session Logging

## Sources

### OpenCode — "Plugins"
- URL: https://opencode.ai/docs/plugins
- Type: web page
- File: sources/opencode-plugins.md
- MLA Citation: OpenCode. "Plugins." OpenCode, 6 Aug. 2026, https://opencode.ai/docs/plugins.
- Key Points:
  - Plugins provide event hooks (tool.execute.before/after, event, message.updated) and can perform filesystem writes via appendFileSync (silent to the chat transcript).
  - Plugins can register custom tools and hooks; exec vs shell form controls how commands run and environment placeholders are substituted.
  - Plugin lifecycle and load order determine silent write behaviour; local plugin fs writes do not appear in transcript.

### Claude / Anthropic — "Hooks (Reference)"
- URL: https://code.claude.com/docs/en/hooks
- Type: web page
- File: sources/claude-hooks.md
- MLA Citation: Anthropic. "Hooks Reference." Claude Code Docs, https://code.claude.com/docs/en/hooks.
- Key Points:
  - Hook events (PreToolUse, PostToolUse, message.updated, session.created, etc.) fire deterministically and supply JSON input to hook handlers.
  - Hooks can be command, http, mcp_tool, prompt, or agent types; command hooks run shell commands and can append logs silently to disk.
  - Matchers and `if` conditions control when hooks run; background async hooks and timeouts are supported for non-blocking instrumentation.

### Claude / Anthropic — "Persist sessions to external storage" (Agent SDK)
- URL: https://code.claude.com/docs/en/agent-sdk/session-storage
- Type: web page
- File: sources/claude-session-storage.md
- MLA Citation: Anthropic. "Persist Sessions to External Storage." Claude Agent SDK, https://code.claude.com/docs/en/agent-sdk/session-storage.
- Key Points:
  - SDK SessionStore interface (append/load) enables mirrors (append-only NDJSON) and supports dual-write mirror pattern: local disk + append() to external store.
  - Dual-write is best-effort; mirror failures emit mirror_error but do not interrupt agent; adapters must deduplicate by entry.uuid.
  - Behavior notes explicitly discuss the dual-write architecture and mirror retries, reinforcing canonical-NDJSON as primary storage for machine consumption.

### Anthropic — "Building Effective Agents"
- URL: https://www.anthropic.com/engineering/building-effective-agents
- Type: article
- File: sources/anthropic-building-effective-agents.md
- MLA Citation: Anthropic. "Building Effective Agents." Anthropic Engineering, 19 Dec. 2024, https://www.anthropic.com/engineering/building-effective-agents.
- Key Points:
  - Agents should be simple, composable, and transparent about tool use; tools and their prompt engineering are critical to reliable agent behaviour.
  - Distinction between workflows and agentic systems — instrumentation should capture tool calls and decisions for observability without polluting human-facing transcripts.

### OpenTelemetry — GenAI semantic conventions
- URL: https://github.com/open-telemetry/semantic-conventions-genai
- Type: repository / spec
- File: sources/opentelemetry-genai.md
- MLA Citation: OpenTelemetry. "Semantic Conventions for Generative AI (GenAI)." GitHub, https://github.com/open-telemetry/semantic-conventions-genai.
- Key Points:
  - Defines span and attribute conventions for GenAI: invoke_agent / execute_tool spans, attributes for agent id, model, tool, and invocation metadata.
  - Provides schema alignment useful for NDJSON event shape and OTel-compatible fields to unify traces and logs for delegated events.

### Stripe — "Canonical Log Lines"
- URL: https://stripe.com/blog/canonical-log-lines
- Type: blog post
- File: sources/stripe-canonical-log-lines.md
- MLA Citation: Leach, Brandur. "Fast and Flexible Observability with Canonical Log Lines." Stripe Blog, 30 July 2019, https://stripe.com/blog/canonical-log-lines.
- Key Points:
  - Canonical log lines: one dense structured line per request that collocates key telemetry for fast queries and warehousing.
  - Practical pattern: emit an append-only canonical record (NDJSON) per unit-of-work and archive to warehouse/Kafka for analytics — reduces parsing and query complexity.

### LibreDevOps — "Logging Standards"
- URL: https://libredevops.org/docs/documents/logging-standards/
- Type: standards document
- File: sources/libredevops-logging-standards.md
- MLA Citation: Libre DevOps. "Logging Standards." Libre DevOps, https://libredevops.org/docs/documents/logging-standards/.
- Key Points:
  - Prescribes NDJSON (one JSON object per line) as canonical, machines-first format; stamp ISO-8601 UTC timestamps; correlate with trace_id/span_id.
  - Anti-patterns: human-only strings, hand-built JSON, logging secrets, and using logs as data stores — all align with ana007's critique of dual-maintained MD+JSONL.

### Microsoft Azure — "Event Sourcing Pattern"
- URL: https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing
- Type: architecture pattern guidance
- File: sources/azure-event-sourcing.md
- MLA Citation: Microsoft. "Event Sourcing Pattern." Microsoft Azure Architecture Center, 28 Mar. 2026, https://learn.microsoft.com/en-us/azure/architecture/patterns/event-sourcing.
- Key Points:
  - Event sourcing: append-only event store as system of record; materialized views / derived projections for human queries and UI.
  - Immutability, idempotency, optimistic concurrency, snapshots, and handling schema evolution are core operational constraints — directly applicable to messages.jsonl design.

### LangChain / LangSmith — "Observability Concepts"
- URL: https://docs.langchain.com/langsmith/observability-concepts
- Type: documentation
- File: sources/langsmith-observability.md
- MLA Citation: LangChain. "Observability Concepts." LangSmith Docs, https://docs.langchain.com/langsmith/observability-concepts.
- Key Points:
  - LangSmith defines runs/traces/threads/trajectories; trajectories are derived, flattened views (messages) over traces — precedent for NDJSON canonical + derived Markdown/trajectory views.
  - Emphasises trace enrichment (tags/metadata) and integrations that auto-capture runs, supporting a single canonical machine-format with multiple derived visualizations.

### Context Foundry — "Why Your AI Agents Won't Shut Up"
- URL: https://contextfoundry.dev/quiet-agents.html
- Type: blog / guide
- File: sources/contextfoundry-quiet-agents.md
- MLA Citation: Context Foundry. "Why Your AI Agents Won't Shut Up." ContextFoundry, https://contextfoundry.dev/quiet-agents.html.
- Key Points:
  - Recommends 'Silent Execution' directives to suppress narration and token waste; separate orchestration channel from human narration.
  - Replacing large context reads (CLAUDE.md) with short system prompt injections reduces token cost and keeps the execution channel compact.

## Synthesis

1) The dual-maintained-log anti-pattern
- Multiple independent sources (messages.md human view + messages.jsonl machine NDJSON) written in parallel by the same orchestrator cause:
  - Drift and integrity loss (ana007 evidence: rows 1–131 present only in .md) — aligns with LibreDevOps warnings about hand-maintained duplicate artifacts.
  - Double token & cost overhead (two visible edit tool calls per event) and transcript pollution; Context Foundry quantifies narration/token waste and ana007 records 1,170 visible edit calls per 585-row session.
  - Loss of single-source auditing and retrievability; Stripe's canonical-log-lines recommends one canonical record per unit-of-work for fast queries and warehousing.

  Cited: Leach (Stripe), Libre DevOps, Microsoft Event Sourcing, ana007 report.

2) Single canonical store + derived views
- Principle: maintain a single append-only NDJSON (messages.jsonl) as canonical machine-readable record; generate human Markdown/trajectory views on demand from that NDJSON.
  - LangSmith trajectories = derived, flattened views over traces; mirrors our messages.md-as-derived-view approach.
  - Event sourcing pattern (Azure) prescribes append-only store + materialized projections for query/UX — operational rules: idempotent IDs, monotonic row_id, snapshots/compaction.
  - Stripe 'canonical lines' and LibreDevOps recommend NDJSON and a single-line-per-unit representation for warehousing and analytics.

  Cited: LangChain (LangSmith), Microsoft, Stripe, LibreDevOps, ana007.

3) Instrumentation placement and execution model
- Deterministic out-of-loop hooks/plugins (tool.execute.before/after, event, message.updated) produce near-100% mechanical coverage; hook-driven instrumentation is reliable and silent when implemented in plugin fs writes.
  - Hooks (Claude) supply structured JSON inputs and can be command/http/agent hooks; plugin command hooks can run appendFileSync silently.
  - LLM-judgment logging (orchestrator manual edits / semantic events) is probabilistic and should be minimized; instead use a compact log_decision tool for semantic events (ana007 Option E).
  - Separation: interaction channel (transcript visible to humans) vs instrumentation channel (plugin fs / NDJSON) avoids pollution — Context Foundry's Silent Execution and OpenCode plugins examples support this.

  Cited: Claude hooks & agent-sdk, OpenCode plugins, Context Foundry, ana007.

4) OpenCode plugin specifics (implementation notes)
- Plugins can register hooks and custom tools; local plugin filesystem writes (appendFileSync) do not appear in the transcript — proven by registry.jsonl evidence in ana007.
  - Use tool registration for compact semantic events (log_decision tool) that generates a single-line compact record in the transcript when needed.
  - Lifecycle hooks to observe task() delegations: tool.execute.before/after capture agent/model/prompt/task_id; event hooks observe session.created/idle/error. message.updated captures tokens/cost at cycle boundaries.
  - Respect exec vs shell forms, path placeholders, and plugin data dirs for deterministic writes and persistence across plugin updates.

  Cited: OpenCode plugins doc, ana007 report.

5) Failure & consistency patterns (operational rules)
- Design messages.jsonl as append-only WAL-like store with these guarantees:
  - Atomic append (appendFileSync) per entry, monotonic row_id seeded from existing jsonl (last_row_id + 1), idempotent event UUID per entry.
  - Single-writer-per-file or per-session writer to avoid interleaving; plugin should tail-verify last row on startup and use per-session lock / monotonic counter.
  - Tail-verify on resume to detect gaps; on failed append, allow retry/backoff but never corrupt prior entries; mirror errors (mirror_error) must be monitored but local-disk copy is authoritative (Claude SDK dual-write notes).
  - Use idempotency checks in append handler to deduplicate retries (SessionStore appendix and OTel guidance on idempotency).

  Cited: Microsoft Event Sourcing, Anthropic SessionStore docs, OpenTelemetry GenAI semantics.

6) OpenTelemetry GenAI alignment
- Map messages.jsonl entries to OTel GenAI semconv: represent delegation events as spans (invoke_agent / execute_tool), include attributes: gen_ai.agent.id, gen_ai.operation.name/tool, model.name, task_ref, lane_id, cycle_id, writer provenance, row_id, event_uuid.
  - This alignment enables traces ↔ logs correlation by trace_id/span_id and supports downstream observability tools (LangSmith, OTEL Collector, warehouses).

  Cited: OpenTelemetry GenAI, LangSmith, Anthropic Agent SDK.

## Key Takeaways
- Stop dual-maintenance. Make messages.jsonl the canonical append-only NDJSON; regenerate messages.md from it on demand.
- Use plugin hook-driven appendFileSync as the silent mechanical event writer; reserve compact log_decision tool calls for semantic events only.
- Implement WAL-like atomic append, monotonic row_id, idempotent UUIDs, and tail-verify on plugin init/resume.
- Align event fields with OTel GenAI semconv so delegation events are first-class spans for observability.
- Follow Stripe / LibreDevOps guidance: machine-first NDJSON, one canonical record per unit-of-work, archive canonical lines for analytics.
