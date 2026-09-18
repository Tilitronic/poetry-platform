# DIA-132: coder-escalated hardening research - no native timeout, steps cap only (2026-08-13)

- **Date:** 2026-08-13
- **Source:** DIA-132 hardening research - ai-specialist gate research (web-fresh sources fetched 2026-08-13), developer decision (practice-protected, AGENTS.md section 10 Phase 2). Registered per AGENTS.md section 10 Phase 6; cross-referenced with the DIA-130 escalated-lane silent-failure pattern (same escalation lane, same root class of failure: no runtime guard on the escalated lane).
- **Status:** APPLIED - Tier 1 approved by developer 2026-08-13 and implemented 2026-08-13 (steps:50 on both escalated lanes); restart-verify pending at next session boot.
- **Ticket:** DIA-132 (OPEN) - "coder-escalated silent failure - hardening research: watchdog, timeout, empty-result detection" (docs/dev-infra-audit/tickets/DIA-132-coder-escalated-silent-failure.md).

## Finding: OpenCode has NO native per-agent wall-clock timeout; only the 'steps' iteration cap; plugin can alert but not auto-cancel

- OpenCode config schema (https://opencode.ai/config.json) AgentConfig fields: model, variant, temperature, top_p, prompt, tools (deprecated), disable, description, mode, hidden, options, color, steps (integer > 0, "Max agentic iterations before forcing text-only response"), maxSteps (deprecated, use steps), permission. NO per-agent timeout/heartbeat/watchdog field exists.
- coder-escalated (opencode-go/kimi-k3) currently has NO steps set (.opencode/opencode.jsonc lines 302-316; .opencode/oh-my-opencode-slim.jsonc lines 310-325). A runaway escalated lane is therefore bounded only by the model's own completion, not by any configuration.
- OpenCode has NO native handling for empty/blank subagent results (no retry/warning/error; doom_loop covers only 3x-identical tool calls). Detection is external only (orchestrator + plugin hooks) - confirmed by the DIA-130 silent-failure incident.
- delegation-observer plugin (.opencode/plugins/delegation-observer.ts, 1736 lines) CAN extend: (a) real-time empty-result detection in tool.execute.after (parse <task_result> body, write empty_result_alert registry row + ctx.client.app.log warn), (b) post-hoc elapsed-time alert on session.idle for escalated lanes > 15 min (watchdog_slow_dispatch row). CANNOT auto-cancel: no timer/interval mechanism (purely event-driven); ctx.client.session.abort() from plugin bypasses cancel_task tool tracking (.opencode/oh-my-opencode-slim/src/tools/cancel-task.ts lines 44-48) - undocumented/unsupported.
- Hardening tiers: Tier 1 (config-only, low risk) set "steps": 50 on coder-escalated + analyzer-escalated; Tier 2 (plugin, medium risk) empty-result alert + elapsed-time alert, ALERT-ONLY never auto-retry (490 req/mo kimi-k3 cap); Tier 3 (deferred) proactive timeout + auto-cancel requires upstream OpenCode feature (per-agent wall-clock timeout) or sidecar watchdog process.
- Sources: https://opencode.ai/config.json, https://opencode.ai/docs/agents, https://opencode.ai/docs/plugins (fetched 2026-08-13).

## Decision (developer, 2026-08-13)

- Section-10 Phase 2: implement Tier 1 ONLY ("steps": 50 on both escalated lanes). Tier 2/3 documented for future.
- Rationale: Tier 1 is config-only and low risk; it bounds the runaway-iteration failure mode with zero plugin surface. Tier 2 is deferred because the alert-only plugin adds medium-risk surface (1736-line plugin) for a notification that the orchestrator already detects post-hoc; Tier 3 requires an upstream OpenCode feature or a sidecar watchdog process (not in scope).
- Research persistence: learnings (this file) + conspect (res020).

## Outcome field

- Tier 1 implemented 2026-08-13: `"steps": 50` added to analyzer-escalated (.opencode/opencode.jsonc line 265) and coder-escalated (line 321), each with a DIA-132 comment noting the only native AgentConfig execution limit and the res020 research reference. make test-config exit 0; diff +8/-2 (2 comments x 2 lines + 2 steps lines); only opencode.jsonc touched.
- Independent review: ai-auditor CONFORMANT-WITH-NOTES (session ses_0044b7ffcffeew3wpsQwDhP4BE) - placement/semantics PASS; [MAJOR] registration stale (closed by this lane); [MINOR] monitor for forced text-only cutoffs on complex escalations + track kimi-k3 per-dispatch iteration usage vs 490 req/mo budget.
- Restart-verify PENDING (DIA-123 pattern): config takes effect on next OpenCode restart; steps cap behavior verified at next session boot. DIA-132 stays OPEN until then.
- Monitoring notes: (1) a complex escalation that hits the 50-step cap forces a text-only response (not a timeout) - watch for degraded-result reports on long tasks; (2) track per-dispatch iteration usage against the kimi-k3 490 req/mo budget since steps:50 raises the per-dispatch ceiling.

## Tags

DIA-132, coder-escalated, kimi-k3, opencode-config, agent-config, steps-cap, watchdog, empty-result, plugin-hooks, section-10
