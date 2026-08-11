# DIA-108 - audit optimal model assignment across OpenCode agents (usage-driven)

<!-- Filed 2026-08-12 by developer request. Extends DIA-087 (CLOSED). Goal: optimize
     quality/speed/usage-efficiency/cost ratio for the actual development workload,
     not simply pick the strongest model. -->

---

id: DIA-108
title: "audit optimal model assignment across OpenCode agents (usage-driven)"
area: opencode-config
severity: Medium
status: OPEN
blocked_by: []
discovered: 2026-08-12
source: fix-lane
date: 2026-08-12
created: 2026-08-12
updated: 2026-08-12

# --- Session Attribution (v2 schema, optional) ---

session_id: ""
lane_id: ""
agent: ""
model: ""
parent_session_id: ""
attempts: 0
lease_expires_at: ""
files_touched: ["docs/dev-infra-audit/tickets/DIA-108-optimal-model-assignment-audit.md"]
artifacts: []
evidence: []

---

## Description

Determine the OPTIMAL assignment of models and model variants to different
OpenCode agents, maximizing development productivity from available usage.

Usage context (expected development workload):

- 4-6 hours on weekends
- Up to 2 hours on weekdays, irregularly

Goal is NOT simply the strongest model: optimize the overall
quality / speed / usage-efficiency / cost ratio for this workload pattern.

## Scope

1. Research CURRENT models available for coding agents (fresh data at audit
   time, not stale benchmarks): coding benchmarks; agentic benchmarks; SWE /
   terminal / tool-use benchmarks; reasoning performance; context window;
   speed; other characteristics relevant to OpenCode.
2. Verify and update CURRENT OpenCode Go pricing and usage limits: available
   models; request / usage limits; usage multipliers (1x, 2x, ...); current
   temporary promotions or other relevant changes.
3. Analyze model VARIANTS / MODES where applicable (reasoning/thinking levels,
   fast/normal/high effort, etc.).
4. Determine the optimal model per agent type: primary coding agent;
   planning / architecture agent; debugging agent; code review agent;
   research agent; lightweight / fast agent; fallback / escalation agent.
5. Evaluate a model ROUTING / ESCALATION strategy: when to use a cheaper /
   faster model, when to escalate to a stronger model.
6. Estimate expected usage under the actual workload (4-6h weekends + up to 2
   irregular weekday hours) and whether current OpenCode Go limits suffice.

## Verification

- [ ] Enumerate every configured agent and its current model + variant across
      .opencode config and all presets (post-DIA-087 state).
- [ ] Collect fresh benchmark + pricing data (web-verified, dated).
- [ ] Produce Agent -> recommended model -> variant/reasoning level -> fallback table.
- [ ] Produce model ranking for coding-agent workloads + rationale per recommendation.
- [ ] Estimate usage and identify bottlenecks under the stated workload.
- [ ] Deliver final recommendation: maximum development value from the
      OpenCode Go subscription given the usage pattern.

## Fix

> To be filled at fix time.

## Re-verify

> To be filled at re-verify time.
