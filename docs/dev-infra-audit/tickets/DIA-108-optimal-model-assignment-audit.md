# DIA-108 - audit optimal model assignment across OpenCode agents (usage-driven)

<!-- Filed 2026-08-12 by developer request. Extends DIA-087 (CLOSED). Goal: optimize
     quality/speed/usage-efficiency/cost ratio for the actual development workload,
     not simply pick the strongest model. -->

---

id: DIA-108
title: "audit optimal model assignment across OpenCode agents (usage-driven)"
area: opencode-config
severity: Medium
status: CLOSED
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

Research phase completed 2026-08-12 (ai-specialist lane, web-fresh; 7 sources archived at knowledge/res013-opencode-model-pricing-audit/, conspect registered in memory-shelf shelf.conspects).

Key findings:

- Current model assignments are well-optimized (DIA-087 tiering sound); no primary model changes recommended.
- One config change was proposed: designer claude-sonnet-4.5 -> claude-sonnet-5 (Copilot, $2/$10 promo, 85.2% SWE-bench). DEVELOPER REJECTED: Claude Sonnet 5 is NOT in the actual Copilot Pro subscription model list. Recommendation withdrawn. No config change applied.
- New escalation option identified: Kimi K3 (93.4% SWE-bench Verified, best Go model; 490 req/mo cap - reserve for <5 escalations/mo). Not applied - informational.
- ai-assist-sources.yaml has 6+ stale entries + 8 missing new Go models (Kimi K3, Grok 4.5, GPT 5.6 Luna, MiniMax M3, Qwen3.8 Max, Hy3, MiMo-V2.5-Pro, GLM-5.2) + stale reviewer/observer role_mapping. Needs @resource-manager dispatch.
- Usage headroom MASSIVE: 2-5% utilization across all pools under stated workload (4-6h weekends + up to 2h weekdays); $10/mo Go + Copilot Pro provide ~40x headroom; no bottlenecks; no new subscriptions needed.

Quality lesson (developer disposition): pricing-page availability does NOT imply subscription availability - model availability MUST be validated against the actual subscription's model list before recommending a config change.

Status note: research + persistence complete; remaining work = ai-assist-sources.yaml refresh (resource-manager), R5 MiMo evaluation, optional Kimi K3 escalation adoption. Ticket stays OPEN until those or developer closes.

## Re-verify

Restart-verify PASS (2026-08-12) - Kimi K3 / GPT-5.6 Luna escalation
adoption (commit b0b3c76). Config checks 5/5 PASS: hidden:true in
.opencode/opencode.jsonc (coder-escalated line 293, analyzer-escalated line
239); task:deny on both escalated agents; model mappings S1-S4 consistent
(coder-escalated -> opencode-go/kimi-k3, analyzer-escalated ->
opencode-go/gpt-5.6-luna); orchestrator permission.task allow-list present
(lines 167/170); make test-config exit 0 with agent-name lockstep 24/0/0.
Live dispatch self-reports confirmed kimi-k3 (coder-escalated) and
gpt-5.6-luna (analyzer-escalated); both hidden, both task:deny.

Status stays OPEN.

CLOSED 2026-08-12 by developer decision (session S16). Research + persistence complete; Kimi K3 / GPT-5.6 Luna escalation adoption validated and re-verified live (commit b0b3c76, restart-verify PASS, ai-auditor APPROVE). Remaining follow-ups tracked separately: DIA-116 (Rung-3 benchmark), ai-assist-sources.yaml refresh (resource-manager lane).
