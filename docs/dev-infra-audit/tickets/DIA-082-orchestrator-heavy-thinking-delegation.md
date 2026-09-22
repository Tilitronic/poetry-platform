# DIA-082 — orchestrator must not perform heavy thinking/analysis itself — delegate to @analyzer; @analyzer may propose council dispatch when warranted

<!-- Filed by the docs lane (code-executor re-route) 2026-08-10. Correlates DIA-080
     (orchestrator frequent stops) — context bloat / step-budget exhaustion. -->

---

id: DIA-082
title: "orchestrator must not perform heavy thinking/analysis itself — delegate to @analyzer; @analyzer may propose council dispatch when warranted"
area: opencode-config
severity: Major
status: CLOSED
blocked_by: [] # DIA-NNN refs, or empty
discovered: 2026-08-10
source: test-lane
date: 2026-08-10
created: 2026-08-10
updated: 2026-08-11

# --- Session Attribution (v2 schema, optional) ---

session_id: "ses_0133de7fdffeKc3ClhE6fqFy0X"
lane_id: "docs"
agent: "code-executor"
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-082-orchestrator-heavy-thinking-delegation.md"]
artifacts: []
evidence: []

---

## Description

The orchestrator must not perform heavy thinking/analysis itself; for
thinking/analysis it must delegate to @analyzer, and @analyzer may propose a
council dispatch (multi-model consensus) when warranted.

Rationale: prevents orchestrator context bloat and step-budget exhaustion
(correlates DIA-080 — orchestrator halts/stops mid-work repeatedly across
sessions).

## Verification

- [ ] Observe orchestrator behavior on a thinking/analysis-heavy task; confirm it delegates to @analyzer instead of performing the analysis inline.
- [ ] Confirm @analyzer is empowered to propose a council dispatch when the analysis warrants multi-model consensus.
- [ ] Confirm orchestrator context_usage stays within budget on analysis-heavy sessions (no bloat → no DIA-080 stop).

## Fix

May be §10-routed if it touches .opencode/ prompts or config.

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.

## Resolution (2026-08-11): subsumed by DIA-097 (orchestrator role consolidation) per batch-brief disposition - heavy-thinking-delegation requirements are tracked under DIA-097.
